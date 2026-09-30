import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import QAbilityStage from '../qabilitystage/QAbilityStage';
import UIAbility from '@ohos.app.ability.UIAbility';
import Want from '@ohos.app.ability.Want';
import Window from '@ohos.window'
import display from '@ohos.display';
import hilog from '@ohos.hilog';
import qpa from 'libqohos.so';
import { command } from 'libentry.so';
import { notifyLifecycle } from '../common/StellariumLifecycle';
import {LOG_DOMAIN, LOG_TAG, APP_ICP_FILING_NUMBER, APP_ICP_FILING_URL} from '../common/QtAppConstants';
import { hasCurrentPrivacyConsent } from './PrivacyConsent';
import { writeClipboardText } from './ClipboardService';
import QtWindowStageAdapter from './QtWindowStageAdapter';
import { setConsentAcceptedListener, setStartupCanvasReadyListener } from '../common/PrivacyStartup';
import { scheduleDeepSkyImageExtraction, setDeepSkyImageExtractionForeground } from './StellariumResourceBootstrap';
import { AstronomyNotificationService, AstronomyNotificationPayload } from './AstronomyNotificationService';
import { AstronomyReminderService, AstronomyReminderRequest } from './AstronomyReminderService';
import { CollaborationSessionOptions, collaborationNativeState, collaborationPreview, createCollaborationSession } from './CollaborationSessionService';

interface StellariumCliRequest {
  commandName: string;
  payload: string;
  requestId: string;
  attempts: number;
}

interface WindowAvoidAreaChange {
  type: Window.AvoidAreaType;
  area: Window.AvoidArea;
}

interface AstronomyReminderResponse {
  ok: boolean;
  reminderId?: number;
  error?: string;
  code?: number;
  notificationEnabled?: boolean;
  reminderCount?: number;
  event?: SolarTermCandidate;
}

interface SolarTermCandidate {
  date: string;
  jd: number;
  label: string;
  key: string;
}

export default class QAbility extends UIAbility {

  private pendingWant: Want | null = null;
  private pendingLaunchParam: AbilityConstant.LaunchParam | null = null;
  private pendingWindowStage: Window.WindowStage | null = null;
  private privacyRequestStarted: boolean = false;
  private privacyAccepted: boolean = false;
  private pendingPrivacyWindowRestore: boolean = false;

  private restoreWindowAfterConsent(): void {
    if (!this.pendingPrivacyWindowRestore || !this.rootContentLoaded ||
      this.qtWindowStage === undefined || !hasCurrentPrivacyConsent()) return;
    qpa.handleAbilityOnWindowStageRestore(this, this.qtWindowStage);
    this.pendingPrivacyWindowRestore = false;
    AppStorage.setOrCreate('stellariumPrivacyNativeStartupAllowed', true);
  }

  private rootContentLoaded: boolean = false;
  private rootContentLoading: Promise<boolean> | undefined = undefined;
  private rootStorage: LocalStorage = new LocalStorage();
  private qtWindowStage: QtWindowStageAdapter | undefined = undefined;
  private qtAbilityCreated: boolean = false;
  private qtInitialized: boolean = false;
  private qtStartupInProgress: boolean = false;
  private desktopWindowRepairAttempts: number = 0;
  private inputStallProbeTimer: number = -1;

  private stopInputStallProbe(): void {
    if (this.inputStallProbeTimer >= 0) {
      clearInterval(this.inputStallProbeTimer);
      this.inputStallProbeTimer = -1;
    }
  }

  private startInputStallProbe(): void {
    if (!this.privacyAccepted || !this.isForeground || this.inputStallProbeTimer >= 0) return;
    let previousTick = Date.now();
    this.inputStallProbeTimer = setInterval(() => {
      const now = Date.now();
      const delayedMs = now - previousTick - 500;
      previousTick = now;
      if (this.isForeground && delayedMs > 1000) {
        hilog.warn(LOG_DOMAIN, LOG_TAG,
          `[input-stall-probe] delayMs=${delayedMs}; starting=${this.qtStartupInProgress}; qtReady=${this.qtInitialized}`);
      }
    }, 500);
  }
  private isForeground: boolean = true;
  private qtWindowPrepared: boolean = false;
  private privacyProbeStartedAt: number = 0;
  private privacyProbeSequence: number = 0;
  private cliRequests: StellariumCliRequest[] = [];
  private safeAreaWindow: Window.Window | null = null;
  private safeAreaTopPixels: number = 0;

  private readonly avoidAreaChangeCallback = (data: WindowAvoidAreaChange): void => {
    if (data.type === Window.AvoidAreaType.TYPE_SYSTEM || data.type === Window.AvoidAreaType.TYPE_CUTOUT) {
      this.publishScreenSafeArea(data.area.topRect.height);
    } else if (data.type === Window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
      this.publishNavigationSafeArea(data.area.bottomRect.height);
    }
  };

  private isCliCommandName(value: string): boolean {
    return /^[A-Za-z][A-Za-z0-9_]*$/.test(value) && value.length <= 96;
  }

  private readCliString(parameters: Record<string, Object> | undefined, key: string): string {
    if (parameters === undefined) {
      return '';
    }
    const value = parameters[key];
    return typeof value === 'string' ? value : '';
  }

  private routeCardWant(want: Want): void {
    const parameters = want.parameters as Record<string, Object> | undefined;
    if (parameters === undefined) return;
    let panel = this.readCliString(parameters, 'panel').trim();
    let tab = this.readCliString(parameters, 'tab').trim();
    const nested = parameters['params'];
    if (panel.length === 0 && typeof nested === 'string') {
      try {
        const parsed = JSON.parse(nested) as Record<string, Object>;
        panel = typeof parsed['panel'] === 'string' ? String(parsed['panel']).trim() : '';
        tab = typeof parsed['tab'] === 'string' ? String(parsed['tab']).trim() : tab;
      } catch (error) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, '[form-route] ignored malformed card params');
      }
    } else if (panel.length === 0 && nested !== undefined && typeof nested === 'object') {
      const parsed = nested as Record<string, Object>;
      panel = typeof parsed['panel'] === 'string' ? String(parsed['panel']).trim() : '';
      tab = typeof parsed['tab'] === 'string' ? String(parsed['tab']).trim() : tab;
    }
    if (panel.length === 0) return;
    AppStorage.setOrCreate('stellariumCardRoute', JSON.stringify({
      panel: panel,
      tab: tab,
      routeId: Date.now().toString()
    }));
  }

  private queueCliRequest(want: Want): void {
    const parameters = want.parameters as Record<string, Object> | undefined;
    const commandName = this.readCliString(parameters, 'skyinstrument.cli.command').trim();
    if (commandName.length === 0) {
      return;
    }
    if (!this.isCliCommandName(commandName)) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, '[cli] rejected invalid command name');
      return;
    }
    const encodedPayload = this.readCliString(parameters, 'skyinstrument.cli.payload');
    let payload = encodedPayload;
    if (encodedPayload.startsWith('__STEL_CLI_PAYLOAD_URI__')) {
      try {
        payload = decodeURIComponent(encodedPayload.substring('__STEL_CLI_PAYLOAD_URI__'.length));
      } catch (error) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, '[cli] rejected malformed percent-encoded payload');
        return;
      }
    } else if (encodedPayload.startsWith('__STEL_CLI_PAYLOAD__')) {
      payload = encodedPayload.substring('__STEL_CLI_PAYLOAD__'.length);
    }
    if (payload.length > 32768) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, '[cli] rejected payload larger than 32768 bytes');
      return;
    }
    let requestId = this.readCliString(parameters, 'skyinstrument.cli.requestId').trim();
    if (!/^[A-Za-z0-9_.:-]{1,80}$/.test(requestId)) {
      requestId = `cli-${Date.now()}`;
    }
    if (this.cliRequests.some((request: StellariumCliRequest) => request.requestId === requestId)) {
      return;
    }
    if (commandName === 'getPrivacyConsentState') {
      this.finishCliRequest({ commandName, payload, requestId, attempts: 0 }, JSON.stringify({
        ok: true, currentAgreementsAccepted: hasCurrentPrivacyConsent(),
        nativeInitialized: this.qtInitialized,
        foreground: this.isForeground
      }));
      return;
    }
    if (commandName === 'getUiLayout') {
      this.finishCliRequest({ commandName, payload, requestId, attempts: 0 },
        AppStorage.get<string>('stellariumUiLayoutState') ?? JSON.stringify({
          ok: true, ready: false, mode: 'unknown', override: 'auto'
        }));
      return;
    }
    if (commandName === 'getLocationMapState') {
      this.finishCliRequest({ commandName, payload, requestId, attempts: 0 },
        AppStorage.get<string>('stellariumLocationMapState') ?? JSON.stringify({
          ok: true, provider: 'offline', phase: 'ready', observerCoordinateSystem: 'WGS84'
        }));
      return;
    }
    this.cliRequests.push({ commandName: commandName, payload: payload, requestId: requestId, attempts: 0 });
    hilog.info(LOG_DOMAIN, LOG_TAG, '[cli] queued requestId=%{public}s command=%{public}s', requestId, commandName);
    this.drainCliRequests();
  }

  private isCliFireAndForget(commandName: string): boolean {
    return commandName === 'dragView' || commandName === 'zoomBy' || commandName === 'zoomStep' ||
      commandName === 'endPinch' || commandName === 'beginSkyGesture' || commandName === 'panBy' || commandName === 'moveToAltAz' ||
      commandName === 'setGyroView' || commandName === 'gyroDiagnostic' ||
      commandName === 'startPanInertia' || commandName === 'stopPanInertia' || commandName === 'playScript';
  }

  private isUiCliCommand(commandName: string): boolean {
    if (commandName === 'startGuide' || commandName === 'guideAction') return true;
    if (commandName === 'setSearchBrowserPage' || commandName === 'selectSearchCategory' || commandName === 'setSearchBrowserFilter') return true;
    if (commandName === 'setAstroTab' || commandName === 'setAstroGroup' || commandName === 'setAstroFilter' || commandName === 'setAstroScroll') return true;
    if (commandName === 'setSatellitePanelGroup' || commandName === 'setSatellitePanelScroll') return true;
    if (commandName === 'setObjectDetailTab') return true;
    if (commandName === 'setObjectModelView') return true;
    return commandName === 'openUiPanel' || commandName === 'openPluginFeature' || commandName === 'closeUiPanel' || commandName === 'backUiPanel' ||
      commandName === 'setLayerTab' || commandName === 'setSkyCultureMakerTab' || commandName === 'setGyroscopeEnabled' || commandName === 'setTelescopeLivePosition' || commandName === 'setLocationMapProvider' || commandName === 'setUiLayoutMode';
  }

  private async createCollaborationCli(request: StellariumCliRequest): Promise<void> {
    try {
      let options: CollaborationSessionOptions = {};
      if (request.payload.trim().length > 0) options = JSON.parse(request.payload) as CollaborationSessionOptions;
      const session = createCollaborationSession(command('getSessionState', ''), options);
      const response: Record<string, Object> = {};
      response['ok'] = true;
      response['session'] = session;
      response['preview'] = collaborationPreview(JSON.stringify(session));
      if (request.commandName === 'exportCollaborationSession' && options.copy === true) {
        response['clipboard'] = await writeClipboardText(JSON.stringify(session, null, 2));
      }
      this.finishCliRequest(request, JSON.stringify(response));
    } catch (error) {
      this.finishCliRequest(request, JSON.stringify({ ok: false, error: String(error) }));
    }
  }

  private async applyCollaborationCli(request: StellariumCliRequest): Promise<void> {
    try {
      const nativeState = collaborationNativeState(request.payload);
      const result = JSON.parse(command('applySessionState', nativeState)) as Record<string, Object>;
      result['sessionPreview'] = collaborationPreview(request.payload);
      this.finishCliRequest(request, JSON.stringify(result));
    } catch (error) {
      this.finishCliRequest(request, JSON.stringify({ ok: false, error: String(error) }));
    }
  }

  private drainCliRequests(): void {
    if (!this.qtInitialized || this.cliRequests.length === 0) {
      return;
    }
    const request = this.cliRequests[0];
    request.attempts += 1;
    if (request.commandName.includes('Collaboration') && (!hasCurrentPrivacyConsent() || !this.isForeground)) {
      this.finishCliRequest(request, JSON.stringify({ ok: false, error: 'privacy consent and foreground are required' }));
      return;
    }
    if (request.commandName === 'getNotificationStatus') {
      AstronomyNotificationService.isEnabled().then((enabled: boolean) => {
        this.finishCliRequest(request, JSON.stringify({ ok: true, enabled: enabled }));
      });
      return;
    }
    if (request.commandName === 'requestNotificationAuthorization') {
      AstronomyNotificationService.requestAuthorization(this.context).then((enabled: boolean) => {
        this.finishCliRequest(request, JSON.stringify({ ok: true, enabled: enabled }));
      });
      return;
    }
    if (request.commandName === 'publishAstronomyNotification') {
      let payload: AstronomyNotificationPayload;
      try {
        payload = JSON.parse(request.payload) as AstronomyNotificationPayload;
      } catch (error) {
        this.finishCliRequest(request, JSON.stringify({ ok: false, error: 'payload must be notification JSON' }));
        return;
      }
      if (!Number.isInteger(payload.id) || payload.id <= 0 || payload.title.length === 0 || payload.text.length === 0) {
        this.finishCliRequest(request, JSON.stringify({ ok: false, error: 'id, title and text are required' }));
        return;
      }
      AstronomyNotificationService.publish(payload).then((published: boolean) => {
        this.finishCliRequest(request, JSON.stringify({ ok: published, published: published }));
      });
      return;
    }
    if (request.commandName === 'cancelAstronomyNotification') {
      const id = Number(request.payload.trim());
      if (!Number.isInteger(id) || id <= 0) {
        this.finishCliRequest(request, JSON.stringify({ ok: false, error: 'notification id must be a positive integer' }));
        return;
      }
      AstronomyNotificationService.cancel(id);
      this.finishCliRequest(request, JSON.stringify({ ok: true, cancelled: id }));
      return;
    }
    if (request.commandName === 'getAstronomyReminderStatus') {
      AstronomyReminderService.status().then((status) => {
        this.finishCliRequest(request, JSON.stringify(status));
      });
      return;
    }
    if (request.commandName === 'getAstronomyReminders') {
      AstronomyReminderService.list().then((result) => {
        this.finishCliRequest(request, JSON.stringify(result));
      });
      return;
    }
    if (request.commandName === 'scheduleAstronomyReminder') {
      let payload: AstronomyReminderRequest;
      try {
        payload = JSON.parse(request.payload) as AstronomyReminderRequest;
      } catch (error) {
        this.finishCliRequest(request, JSON.stringify({ ok: false, error: 'payload must be reminder JSON' }));
        return;
      }
      AstronomyReminderService.schedule(payload).then((result) => {
        this.finishCliRequest(request, JSON.stringify(result));
      });
      return;
    }
    if (request.commandName === 'scheduleNextSolarTermReminder') {
      let nativeResponse: Record<string, Object>;
      try {
        nativeResponse = JSON.parse(command('getAlmanac', '')) as Record<string, Object>;
      } catch (error) {
        this.finishCliRequest(request, JSON.stringify({ ok: false, error: 'almanac is not ready' }));
        return;
      }
      if (nativeResponse['pending'] === true) {
        if (request.attempts < 120) {
          setTimeout(() => this.drainCliRequests(), 80);
          return;
        }
        this.finishCliRequest(request, JSON.stringify({ ok: false, error: 'almanac command timed out', pending: true }));
        return;
      }
      const nestedResult = nativeResponse['result'] as Record<string, Object> | undefined;
      const nestedAlmanac = nestedResult?.['almanac'] as Record<string, Object> | undefined;
      const almanac = (nativeResponse['almanac'] as Record<string, Object> | undefined)
        ?? nestedAlmanac
        ?? nativeResponse;
      const rawTerms = almanac['solarTerms'] ?? nativeResponse['solarTerms'] ?? nestedResult?.['solarTerms'];
      const terms = Array.isArray(rawTerms) ? rawTerms as Array<SolarTermCandidate> : [];
      const rawCurrentJD = almanac['currentJD'] ?? nativeResponse['currentJD'] ?? nestedResult?.['currentJD'];
      const currentJD = Number(String(rawCurrentJD ?? ''));
      const directNextDate = String(almanac['nextSolarTermDate'] ?? nativeResponse['nextSolarTermDate'] ?? nestedResult?.['nextSolarTermDate'] ?? '');
      const directNextJD = Number(String(almanac['nextSolarTermJD'] ?? nativeResponse['nextSolarTermJD'] ?? nestedResult?.['nextSolarTermJD'] ?? ''));
      const directNextLabel = String(almanac['nextSolarTermLabel'] ?? nativeResponse['nextSolarTermLabel'] ?? nestedResult?.['nextSolarTermLabel'] ?? '下一节气');
      const directNext: SolarTermCandidate | undefined = directNextDate.length > 0
        ? { date: directNextDate, jd: directNextJD, label: directNextLabel, key: directNextLabel }
        : undefined;
      const next = directNext ?? terms.find((term) => {
        const termJD = Number(String(term['jd'] ?? ''));
        if (Number.isFinite(currentJD) && Number.isFinite(termJD)) {
          return termJD > currentJD + (30 / 86400);
        }
        const rawDate = String(term['date'] ?? '');
        const dateParts = rawDate.split('T');
        const dayParts = dateParts[0].split('-');
        const timeParts = (dateParts[1] ?? '00:00:00').split(':');
        const date = dayParts.length === 3 && timeParts.length >= 2
          ? new Date(Number(dayParts[0]), Number(dayParts[1]) - 1, Number(dayParts[2]), Number(timeParts[0]), Number(timeParts[1]), Number(timeParts[2] ?? 0))
          : new Date(rawDate);
        return Number.isFinite(date.getTime()) && date.getTime() > Date.now() + 30 * 1000;
      });
      if (next === undefined) {
        this.finishCliRequest(request, JSON.stringify({ ok: false, error: 'no upcoming solar term in the current almanac' }));
        return;
      }
      const label = String(next['label'] ?? '下一节气');
      AstronomyReminderService.schedule({
        at: String(next['date']),
        title: '星象仪 · 下一节气',
        content: `${label} 即将到来，打开星象仪查看年历和观测信息。`,
        eventId: String(next['key'] ?? label),
        kind: 'solar-term',
        panel: 'astro',
        tab: 8
      }).then((result) => {
        const response: AstronomyReminderResponse = { ok: result.ok };
        if (result.reminderId !== undefined) response['reminderId'] = result.reminderId;
        if (result.error !== undefined) response['error'] = result.error;
        if (result.code !== undefined) response['code'] = result.code;
        if (result.notificationEnabled !== undefined) response['notificationEnabled'] = result.notificationEnabled;
        if (result.reminderCount !== undefined) response['reminderCount'] = result.reminderCount;
        response.event = next;
        this.finishCliRequest(request, JSON.stringify(response));
      });
      return;
    }
    if (request.commandName === 'cancelAstronomyReminder') {
      const reminderId = Number(request.payload.trim());
      AstronomyReminderService.cancel(reminderId).then((result) => {
        this.finishCliRequest(request, JSON.stringify(result));
      });
      return;
    }
    if (request.commandName === 'clearAstronomyReminders') {
      AstronomyReminderService.cancelAll().then((result) => {
        this.finishCliRequest(request, JSON.stringify(result));
      });
      return;
    }
    if (request.commandName === 'copyTextToClipboard') {
      if (request.attempts > 1) return;
      writeClipboardText(request.payload).then((result) => {
        this.finishCliRequest(request, JSON.stringify(result));
      });
      return;
    }
    if (request.commandName === 'getCollaborationState') {
      this.finishCliRequest(request, JSON.stringify({
        ok: true, systemContinuation: false, cloudSync: false, liveCollaboration: false,
        fileTransfer: true, sessionSchemaVersion: 2,
        ui: AppStorage.get<string>('stellariumCollaborationUi') ?? '{}'
      }));
      return;
    }
    if (request.commandName === 'createCollaborationSession' || request.commandName === 'exportCollaborationSession') {
      if (request.attempts > 1) return;
      void this.createCollaborationCli(request);
      return;
    }
    if (request.commandName === 'previewCollaborationSession' || request.commandName === 'importCollaborationSession') {
      this.finishCliRequest(request, JSON.stringify(collaborationPreview(request.payload)));
      return;
    }
    if (request.commandName === 'applyCollaborationSession') {
      if (request.attempts > 1) return;
      void this.applyCollaborationCli(request);
      return;
    }
    if (request.commandName === 'getAppFilingInfo') {
      this.finishCliRequest(request, JSON.stringify({ ok: true, type: 'app', number: APP_ICP_FILING_NUMBER, verificationUrl: APP_ICP_FILING_URL }));
      return;
    }
    if (request.commandName === 'getGuideState') {
      this.finishCliRequest(request, AppStorage.get<string>('stellariumGuideState') ??
        '{"ok":true,"state":{"active":false,"phase":"idle"},"initialized":false}');
      return;
    }
    if (request.commandName === 'getSearchBrowserState') {
      const state = JSON.parse(AppStorage.get<string>('stellariumSearchBrowserState') ??
        JSON.stringify({ ok: false, error: 'search browser has not loaded' })) as Record<string, Object>;
      state['scrollY'] = AppStorage.get<number>('stellariumSearchBrowserScrollY') ?? 0;
      this.finishCliRequest(request, JSON.stringify(state));
      return;
    }
    if (request.commandName === 'getAstroPanelState') {
      this.finishCliRequest(request, AppStorage.get<string>('stellariumAstroPanelState') ??
        JSON.stringify({ ok: false, error: 'astronomy panel has not loaded' }));
      return;
    }
    if (request.commandName === 'getSatellitePanelState') {
      this.finishCliRequest(request, AppStorage.get<string>('stellariumSatellitePanelState') ??
        JSON.stringify({ ok: false, error: 'satellite panel has not loaded' }));
      return;
    }
    if (request.commandName === 'getObjectModelView') {
      const model = JSON.parse(AppStorage.get<string>('stellariumObjectModelView') ??
        JSON.stringify({ ok: false, error: 'model has not rendered' })) as Record<string, Object>;
      model['detailScrollY'] = AppStorage.get<number>('stellariumObjectDetailScrollY') ?? 0;
      this.finishCliRequest(request, JSON.stringify(model));
      return;
    }
    if (this.isUiCliCommand(request.commandName)) {
      const value = request.payload.trim();
      if (request.commandName === 'setSearchBrowserPage' && !['browse', 'categories', 'root', 'visibility', 'instrument'].includes(value)) {
        this.finishCliRequest(request, JSON.stringify({ ok: false, error: 'expected browse, categories, root, visibility, instrument' }));
        return;
      }
      if (request.commandName === 'selectSearchCategory') {
        const state = JSON.parse(AppStorage.get<string>('stellariumSearchBrowserState') ?? '{}') as Record<string, Object>;
        const categories = state['categories'] as Array<Record<string, Object>> | undefined;
        if (!categories?.some((category: Record<string, Object>) => category['code'] === value)) {
          this.finishCliRequest(request, JSON.stringify({ ok: false, error: 'unknown category; open search browser first' }));
          return;
        }
      }
      if (request.commandName === 'setSearchBrowserFilter' &&
        !/^(visibility\|(all|above|good)|instrument\|(all|naked|binocular|telescope))$/.test(value)) {
        this.finishCliRequest(request, JSON.stringify({ ok: false, error: 'invalid search filter' }));
        return;
      }
      if (request.commandName === 'setAstroScroll' &&
        (value.length === 0 || !Number.isFinite(Number(value)) || Number(value) < 0)) {
        this.finishCliRequest(request, JSON.stringify({ ok: false, error: 'expected non-negative scroll offset' }));
        return;
      }
      if (request.commandName === 'setAstroFilter' &&
        !/^(period\|(evening|midnight|morning|night)|altitude\|(0|10|20|30|45)|magnitude\|(4|6|8|10)|direction\|(all|north|east|south|west))$/.test(value)) {
        this.finishCliRequest(request, JSON.stringify({ ok: false, error: 'invalid tonight filter key or value' }));
        return;
      }
      if ((request.commandName === 'setAstroTab' && !/^[0-9]$/.test(value)) ||
        (request.commandName === 'setAstroGroup' && !/^[0-2]$/.test(value))) {
        this.finishCliRequest(request, JSON.stringify({ ok: false, error: 'expected tab 0..9 or group 0..2' }));
        return;
      }
      if (request.commandName === 'setSatellitePanelScroll' &&
        (value.length === 0 || !Number.isFinite(Number(value)) || Number(value) < 0)) {
        this.finishCliRequest(request, JSON.stringify({ ok: false, error: 'expected non-negative scroll offset' }));
        return;
      }
      if (request.commandName === 'setObjectDetailTab' && !['0', '1', '2', '3'].includes(value)) {
        this.finishCliRequest(request, JSON.stringify({ ok: false, error: 'expected tab index 0..3' }));
        return;
      }
      if (request.commandName === 'setObjectModelView' && !['reset', 'open', 'immersive', 'close'].includes(value)) {
        const parts = value.split('|');
        if (parts.length !== 2 || parts.some((part: string) => part.trim().length === 0 ||
          !Number.isFinite(Number(part)) || Math.abs(Number(part)) > 1000)) {
          this.finishCliRequest(request, JSON.stringify({ ok: false, error: 'expected open, immersive, close, reset, or dx|dy (finite, <=1000)' }));
          return;
        }
      }
      const response = request.commandName === 'openUiPanel' && value.length === 0
        ? JSON.stringify({ ok: false, error: 'panel name is required' })
        : request.commandName === 'setTelescopeLivePosition' && !['1', 'true', 'on', '0', 'false', 'off'].includes(value.toLowerCase())
          ? JSON.stringify({ ok: false, error: 'expected on or off' })
          : request.commandName === 'setTelescopeLivePosition'
            ? JSON.stringify({ ok: true, accepted: true, enabled: ['1', 'true', 'on'].includes(value.toLowerCase()) })
            : JSON.stringify({ ok: true, accepted: true, panel: value });
      this.finishCliRequest(request, response);
      return;
    }
    let rawResponse = '';
    try {
      rawResponse = command(request.commandName, request.payload);
    } catch (err) {
      this.finishCliRequest(request, JSON.stringify({ ok: false, error: String(err) }));
      return;
    }
    let response: Record<string, Object> = {};
    try {
      response = JSON.parse(rawResponse) as Record<string, Object>;
    } catch (err) {
      this.finishCliRequest(request, JSON.stringify({ ok: false, error: 'invalid native response' }));
      return;
    }
    if (response['pending'] === true) {
      if (this.isCliFireAndForget(request.commandName)) {
        this.finishCliRequest(request, JSON.stringify({ ok: true, accepted: true, pending: true }));
        return;
      }
      if (request.attempts < 120) {
        setTimeout(() => this.drainCliRequests(), 80);
        return;
      }
      this.finishCliRequest(request, JSON.stringify({ ok: false, error: 'command timeout', pending: true }));
      return;
    }
    this.finishCliRequest(request, rawResponse);
  }

  private finishCliRequest(request: StellariumCliRequest, response: string): void {
    if (this.cliRequests.length > 0 && this.cliRequests[0].requestId === request.requestId) {
      this.cliRequests.shift();
    } else {
      this.cliRequests = this.cliRequests.filter((item: StellariumCliRequest) => item.requestId !== request.requestId);
    }
    this.publishCliUiEvent(request, response);
    const responseText = String(response);
    const chunkSize = 600;
    const chunkCount = Math.max(1, Math.ceil(responseText.length / chunkSize));
    for (let chunkIndex = 0; chunkIndex < chunkCount; chunkIndex += 1) {
      const chunk = responseText.substring(chunkIndex * chunkSize, (chunkIndex + 1) * chunkSize);
      hilog.info(LOG_DOMAIN, LOG_TAG,
        '[cli-response] requestId=%{public}s command=%{public}s chunkIndex=%{public}d chunkCount=%{public}d responseChunk=%{public}s',
        request.requestId, request.commandName, chunkIndex, chunkCount, chunk);
    }
    this.drainCliRequests();
  }

  private publishCliUiEvent(request: StellariumCliRequest, response: string): void {
    if (this.isUiCliCommand(request.commandName)) {
      try {
        const parsed = JSON.parse(response) as Record<string, Object>;
        if (parsed['ok'] !== true) {
          return;
        }
        AppStorage.setOrCreate('stellariumCliUiEvent', JSON.stringify({
          requestId: request.requestId,
          commandName: request.commandName,
          payload: request.payload,
          response: parsed,
        }));
      } catch (err) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, '[cli] UI event publish failed: %{public}s', JSON.stringify(err));
      }
      return;
    }
    if (request.commandName !== 'searchObject' && request.commandName !== 'selectAt' &&
      request.commandName !== 'clearSelection' && request.commandName !== 'getSelectedObjectInfo' &&
      request.commandName !== 'setSkyCulture' && request.commandName !== 'setLanguage' && request.commandName !== 'setSatellitesFlag' &&
      request.commandName !== 'setInformationSetting' && request.commandName !== 'getInformationSettings' &&
      request.commandName !== 'setTimeSetting' && request.commandName !== 'getTimeSettings' &&
      request.commandName !== 'setMosaicCamera' && request.commandName !== 'getMosaicCamera' &&
      request.commandName !== 'getNebulaTextureStatus' && request.commandName !== 'setNebulaTexturesVisible' &&
      request.commandName !== 'setNebulaTextureConflictAvoidance' &&
      request.commandName !== 'setDateFormat' && request.commandName !== 'setTimeFormat' && request.commandName !== 'playScript' &&
      request.commandName !== 'continueScript' && request.commandName !== 'stopScript' &&
      request.commandName !== 'setScriptRate') {
      if (request.commandName !== 'setObjectDetailConnector' && request.commandName !== 'getObjectDetailConnector') {
        return;
      }
    }
    try {
      const parsed = JSON.parse(response) as Record<string, Object>;
      if (parsed['pending'] === true && request.commandName !== 'playScript') {
        return;
      }
      AppStorage.setOrCreate('stellariumCliUiEvent', JSON.stringify({
        requestId: request.requestId,
        commandName: request.commandName,
        payload: request.payload,
        response: parsed,
      }));
    } catch (err) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, '[cli] UI event publish failed: %{public}s', JSON.stringify(err));
    }
  }

  private logPrivacyGate(stage: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG,
      `[privacy-gate] ${stage}; accepted=${this.privacyAccepted}; qtAbilityCreated=${this.qtAbilityCreated}; qtInitialized=${this.qtInitialized}`);
  }

  private logPrivacyProbe(phase: string, detail: string = ''): void {
    if (this.privacyProbeStartedAt === 0) {
      this.privacyProbeStartedAt = Date.now();
    }
    this.privacyProbeSequence += 1;
    const suffix = detail.length > 0 ? `; ${detail}` : '';
    hilog.info(LOG_DOMAIN, LOG_TAG,
      `[privacy-probe] seq=${this.privacyProbeSequence}; phase=${phase}; elapsedMs=${Date.now() - this.privacyProbeStartedAt}; ` +
      `foreground=${this.isForeground}; accepted=${this.privacyAccepted}; qtAbilityCreated=${this.qtAbilityCreated}; ` +
      `qtInitialized=${this.qtInitialized}; windowPrepared=${this.qtWindowPrepared}${suffix}`);
  }

  private async preparePrivacyHostPage(windowStage: Window.WindowStage): Promise<boolean> {
    if (this.rootContentLoaded) {
      return true;
    }
    if (this.rootContentLoading !== undefined) {
      this.logPrivacyProbe('privacy-window-prepare-joined');
      return this.rootContentLoading;
    }
    this.rootContentLoading = this.loadPrivacyHostPage(windowStage);
    try {
      return await this.rootContentLoading;
    } finally {
      this.rootContentLoading = undefined;
    }
  }

  private async loadPrivacyHostPage(windowStage: Window.WindowStage): Promise<boolean> {
    try {
      this.logPrivacyProbe('privacy-window-prepare-start');
      AppStorage.setOrCreate('stellariumPrivacyNativeStartupAllowed', false);
      AppStorage.setOrCreate('stellariumPrivacyConsentVerifiedUi', false);
      AppStorage.setOrCreate('stellariumStartupSkyReady', false);
      AppStorage.setOrCreate('stellariumStartupArtComplete', false);
      AppStorage.setOrCreate('stellariumQtContentReady', false);
      AppStorage.setOrCreate('stellariumPrivacyHostReady', false);
      await windowStage.getMainWindow();
      this.qtWindowStage = new QtWindowStageAdapter(windowStage, this.rootStorage);
      await windowStage.loadContent('pages/ApplicationRoot', this.rootStorage);
      this.rootContentLoaded = true;
      await this.enterImmersive(windowStage);
      this.logPrivacyProbe('privacy-window-ready', 'Qt context and resource preparation remain blocked');
      return true;
    } catch (err) {
      this.logPrivacyProbe('final-page-prepare-failed', `error=${JSON.stringify(err)}`);
      hilog.error(LOG_DOMAIN, LOG_TAG, `Privacy host page preparation failed: ${JSON.stringify(err)}`);
      return false;
    }
  }

  private async requestPrivacyThenStart(): Promise<void> {
    if (this.qtInitialized) {
      if (this.isForeground) this.restoreWindowAfterConsent();
      return;
    }
    if (this.privacyRequestStarted || this.privacyAccepted || this.qtInitialized || this.pendingWindowStage === null) {
      return;
    }

    if (!hasCurrentPrivacyConsent()) return;

    this.privacyRequestStarted = true;
    this.logPrivacyProbe('privacy-verification-start');
    this.logPrivacyGate('verifying current hosted agreements');
    this.privacyRequestStarted = false;
    if (!hasCurrentPrivacyConsent()) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Privacy consent was not accepted; Qt startup remains blocked');
      return;
    }

    this.privacyAccepted = true;
    this.logPrivacyGate('system privacy consent accepted');
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Privacy consent accepted; starting Qt');
    void this.startQtIfReady();
  }

  private async requestPrivacyAfterWindowReady(windowStage: Window.WindowStage): Promise<void> {
    if (!await this.preparePrivacyHostPage(windowStage)) {
      return;
    }
    this.logPrivacyProbe('privacy-host-ready', 'single ApplicationRoot loaded; Qt content will bind in place');
    this.logPrivacyGate('privacy host page is ready; observing system-managed privacy consent without an automatic request');
    AppStorage.setOrCreate('stellariumPrivacyHostReady', true);
  }

  private async initializeQtAbilityIfNeeded(): Promise<void> {
    if (!this.privacyAccepted || !hasCurrentPrivacyConsent()) {
      throw new Error('Qt ability initialization requires current privacy consent');
    }
    if (this.qtAbilityCreated || this.pendingWant === null || this.pendingLaunchParam === null) {
      return;
    }

    // setupQtApplication() enters Qt's Harmony bridge. Keep both this call and
    // the deferred AbilityStage callback behind the Privacy Manager decision.
    QAbilityStage.releasePrivacyGate();
    await QAbilityStage.initQtAppContextIfNeeded(this.context.getApplicationContext());
    qpa.handleAbilityOnCreate(this, this.pendingWant, this.pendingLaunchParam);
    this.qtAbilityCreated = true;
  }

  private async startQtIfReady(): Promise<void> {
    if (!this.privacyAccepted || this.qtInitialized || this.qtStartupInProgress || this.pendingWant === null ||
      this.pendingLaunchParam === null || this.pendingWindowStage === null || !this.isForeground) {
      return;
    }

    this.qtStartupInProgress = true;
    this.startInputStallProbe();
    try {
      AppStorage.setOrCreate('stellariumStartupPreparing', true);
      this.logPrivacyProbe('qt-start-transfer-start');
      const contextInitializationStartedAt = Date.now();
      await this.initializeQtAbilityIfNeeded();
      if (!this.isForeground || !hasCurrentPrivacyConsent()) {
        return;
      }
      if (!this.qtWindowPrepared) {
        if (this.qtWindowStage === undefined) throw new Error('Qt single-window adapter is missing');
        qpa.handleAbilityOnWindowStageCreate(this, this.qtWindowStage);
        this.qtWindowPrepared = true;
        this.logPrivacyProbe('final-page-requested', 'Qt content bound into the existing root after consent');
      }
      hilog.info(LOG_DOMAIN, LOG_TAG,
        `[startup] Qt application context initialized in ${Date.now() - contextInitializationStartedAt} ms`);
      await this.enterImmersive(this.pendingWindowStage);
      await new Promise<void>((resolve) => setTimeout(resolve, 160));
      if (!this.isForeground || !hasCurrentPrivacyConsent()) {
        return;
      }
      AppStorage.setOrCreate('stellariumStartupPreparing', false);
      AppStorage.setOrCreate('stellariumPrivacyNativeStartupAllowed', true);
      this.qtInitialized = true;
      this.logPrivacyProbe('native-node-gate-released');
      hilog.info(LOG_DOMAIN, LOG_TAG, '[startup] released Qt native-node gate');
      qpa.handleAbilityOnForeground(this);
      this.logPrivacyProbe('qt-foreground-requested');
    } catch (err) {
      // Keep the ability alive if the native bridge reports a synchronous
      // startup error, so the consent page does not turn into a home-screen flash.
      this.qtInitialized = false;
      AppStorage.setOrCreate('stellariumStartupPreparing', false);
      hilog.error(LOG_DOMAIN, LOG_TAG, `Qt startup hand-off failed: ${(err as Error).message}; ${JSON.stringify(err)}`);
      return;
    } finally {
      this.qtStartupInProgress = false;
      if (!this.qtInitialized) {
        AppStorage.setOrCreate('stellariumStartupPreparing', false);
      }
    }
    notifyLifecycle(true);
    try {
      command('setApplicationForeground', '1');
    } catch (err) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'QAbility::startQtIfReady lifecycle bridge unavailable');
    }
    this.enterImmersive(this.pendingWindowStage);
    // Optional deep-sky images are intentionally not part of the synchronous
    // bootstrap. Start their resumable installation only after consent and the
    // Qt foreground hand-off; completion reloads the existing collection.
    setDeepSkyImageExtractionForeground(true);
    setTimeout(() => {
      scheduleDeepSkyImageExtraction(this.context.getApplicationContext(), () => {
        try {
          command('triggerAction', 'actionShow_DSO_Textures_Reload');
          hilog.info(LOG_DOMAIN, LOG_TAG, 'Reload requested after deep-sky image installation');
        } catch (err) {
          hilog.warn(LOG_DOMAIN, LOG_TAG, `Unable to reload deep-sky images: ${JSON.stringify(err)}`);
        }
      });
    }, 1200);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'Qt startup completed after privacy consent');
    this.logPrivacyProbe('qt-start-transfer-finish');
    this.drainCliRequests();
  }

  private async enterImmersive(windowStage: Window.WindowStage): Promise<void> {
    try {
      const mainWindow = await windowStage.getMainWindow();
      // Qt replaces the ArkUI content asynchronously after consent. Keep the
      // native window opaque during that hand-off so the launcher cannot flash.
      mainWindow.setWindowBackgroundColor('#070b12');
      await mainWindow.setWindowLayoutFullScreen(true);
      await mainWindow.setWindowSystemBarEnable([]);
      if (canIUse('SystemCapability.Window.SessionManager')) {
        await mainWindow.setSpecificSystemBarEnabled('navigationIndicator', false);
      }
      await this.repairSmallFreeformWindow(windowStage);
      if (this.qtAbilityCreated && hasCurrentPrivacyConsent()) this.registerScreenSafeArea(mainWindow);
      hilog.info(LOG_DOMAIN, LOG_TAG, 'QAbility::enterImmersive() success');
    } catch (err) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'QAbility::enterImmersive() failed: ' + JSON.stringify(err));
    }
  }

  private async repairSmallFreeformWindow(windowStage: Window.WindowStage): Promise<void> {
    if (this.desktopWindowRepairAttempts >= 3) return;
    this.desktopWindowRepairAttempts += 1;
    try {
      const mainWindow = await windowStage.getMainWindow();
      const status = mainWindow.getWindowStatus();
      const properties = mainWindow.getWindowProperties();
      const rect = properties.windowRect;
      const globalRect = mainWindow.getGlobalRect();
      const displayInfo = display.getDefaultDisplaySync();
      const displayWidth = Number(displayInfo.width);
      const displayHeight = Number(displayInfo.height);
      const sessionManagerAvailable = canIUse('SystemCapability.Window.SessionManager');
      const left = Number.isFinite(globalRect.left) ? globalRect.left : rect.left;
      const top = Number.isFinite(globalRect.top) ? globalRect.top : rect.top;
      hilog.info(LOG_DOMAIN, LOG_TAG,
        '[window-probe] attempt=%{public}d capability=%{public}s status=%{public}s rect=%{public}s global=%{public}s display=%{public}s',
        this.desktopWindowRepairAttempts, String(sessionManagerAvailable), String(status),
        `${rect.left},${rect.top},${rect.width}x${rect.height}`,
        `${globalRect.left},${globalRect.top},${globalRect.width}x${globalRect.height}`,
        `${displayWidth}x${displayHeight}`);
      if (status !== Window.WindowStatusType.FLOATING) {
        this.desktopWindowRepairAttempts = 3;
        return;
      }
      if (rect.width <= 0 || rect.height <= 0) {
        setTimeout(() => { void this.repairSmallFreeformWindow(windowStage); }, 350);
        return;
      }
      const smallerThanDisplay = displayWidth > 0 && displayHeight > 0 &&
        (rect.width < displayWidth * 0.9 || rect.height < displayHeight * 0.9);
      const needsInitialMaximize = smallerThanDisplay || (rect.width < 800 && rect.height < 600 && left <= 32 && top <= 32);
      if (!needsInitialMaximize) {
        this.desktopWindowRepairAttempts = 3;
        return;
      }
      hilog.warn(LOG_DOMAIN, LOG_TAG,
        '[window-probe] undersized freeform startup window detected; requesting maximize');
      await mainWindow.maximize(Window.MaximizePresentation.FOLLOW_APP_IMMERSIVE_SETTING);
      hilog.info(LOG_DOMAIN, LOG_TAG, '[window-probe] maximize requested for stale freeform window');
      this.desktopWindowRepairAttempts = 3;
    } catch (err) {
      hilog.warn(LOG_DOMAIN, LOG_TAG,
        '[window-probe] repair unavailable: %{public}s', JSON.stringify(err));
      if (this.desktopWindowRepairAttempts < 3) {
        setTimeout(() => { void this.repairSmallFreeformWindow(windowStage); }, 350);
      }
    }
  }

  private publishScreenSafeArea(topPixels: number): void {
    const measuredTop = Number.isFinite(topPixels) ? Math.max(0, Math.round(topPixels)) : 0;
    this.safeAreaTopPixels = Math.max(this.safeAreaTopPixels, measuredTop);
    const top = this.safeAreaTopPixels;
    AppStorage.setOrCreate<number>('stellariumScreenSafeTopPixels', top);
    try {
      const result = command('setScreenSafeArea', top.toString());
      hilog.info(LOG_DOMAIN, LOG_TAG, '[safe-area] topPixels=%{public}s native=%{public}s', top.toString(), result);
    } catch (err) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, '[safe-area] native update failed: %{public}s', JSON.stringify(err));
    }
  }

  private publishNavigationSafeArea(bottomPixels: number): void {
    const bottom = Number.isFinite(bottomPixels) ? Math.max(0, bottomPixels) : 0;
    AppStorage.setOrCreate<number>('stellariumScreenSafeBottomPixels', bottom);
  }

  private registerScreenSafeArea(mainWindow: Window.Window): void {
    if (this.safeAreaWindow !== null && this.safeAreaWindow !== mainWindow) {
      try {
        this.safeAreaWindow.off('avoidAreaChange', this.avoidAreaChangeCallback);
      } catch (err) {
        hilog.warn(LOG_DOMAIN, LOG_TAG, '[safe-area] previous listener removal failed');
      }
    }
    this.safeAreaWindow = mainWindow;
    try {
      const navigationArea = mainWindow.getWindowAvoidArea(Window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      this.publishNavigationSafeArea(navigationArea.bottomRect.height);
    } catch (err) {
      this.publishNavigationSafeArea(0);
      hilog.warn(LOG_DOMAIN, LOG_TAG, '[safe-area] navigation area unavailable');
    }
    try {
      const systemArea = mainWindow.getWindowAvoidArea(Window.AvoidAreaType.TYPE_SYSTEM);
      const cutoutArea = mainWindow.getWindowAvoidArea(Window.AvoidAreaType.TYPE_CUTOUT);
      this.publishScreenSafeArea(Math.max(systemArea.topRect.height, cutoutArea.topRect.height));
      mainWindow.off('avoidAreaChange', this.avoidAreaChangeCallback);
      mainWindow.on('avoidAreaChange', this.avoidAreaChangeCallback);
      hilog.info(LOG_DOMAIN, LOG_TAG, '[safe-area] avoidAreaChange listener registered');
    } catch (err) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, '[safe-area] avoid area unavailable: %{public}s', JSON.stringify(err));
      this.publishScreenSafeArea(0);
    }
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    this.privacyProbeStartedAt = Date.now();
    this.logPrivacyProbe('ability-create');
    hilog.info(LOG_DOMAIN, LOG_TAG, '[privacy-gate] ability created; Qt initialization is blocked pending consent');
    AppStorage.setOrCreate('stellariumStartupPreparing', false);
    setConsentAcceptedListener(() => { void this.requestPrivacyThenStart(); });
    setStartupCanvasReadyListener(() => {
      if (this.pendingWindowStage === null) return;
      void this.pendingWindowStage.removeStartingWindow().then(() => {
        this.logPrivacyProbe('startup-cover-removed');
      }).catch((error: Error) => {
        hilog.warn(LOG_DOMAIN, LOG_TAG, `Startup cover removal failed: ${error.message}`);
      });
    });
    this.pendingWant = want;
    this.pendingLaunchParam = launchParam;
    this.routeCardWant(want);
    this.queueCliRequest(want);
  }

  onDestroy(): void | Promise<void> {
    setConsentAcceptedListener(undefined);
    setStartupCanvasReadyListener(undefined);
    this.stopInputStallProbe();
    hilog.info(LOG_DOMAIN, LOG_TAG, 'QAbility::onDestroy()');
    if (this.qtAbilityCreated) {
      return qpa.handleAbilityOnDestroy(this);
    }
  }

  onPrepareToTerminate(): boolean {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'QAbility::onPrepareToTerminate()');
    return this.qtAbilityCreated ? qpa.handleAbilityOnPrepareToTerminate(this) : false;
  }

  onPrepareToTerminateAsync(): Promise<boolean> {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'QAbility::onPrepareToTerminateAsync()');
    return this.qtAbilityCreated ? qpa.handleAbilityOnPrepareToTerminateAsync(this) : Promise.resolve(false);
  }

  onWindowStageCreate(windowStage: Window.WindowStage) {
    this.pendingWindowStage = windowStage;
    this.logPrivacyProbe('window-stage-create');
    void this.requestPrivacyAfterWindowReady(windowStage);
  }

  onWindowStageRestore(windowStage: Window.WindowStage): void {
    this.pendingWindowStage = windowStage;
    this.logPrivacyProbe('window-stage-restore');
    if (this.qtInitialized) {
      this.pendingPrivacyWindowRestore = true;
      void this.preparePrivacyHostPage(windowStage).then((ready: boolean) => {
        if (!ready) return;
        AppStorage.setOrCreate('stellariumPrivacyHostReady', true);
        this.restoreWindowAfterConsent();
        void this.enterImmersive(windowStage);
      });
    } else {
      void this.requestPrivacyAfterWindowReady(windowStage);
    }
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'QAbility::onNewWant()');
    this.pendingWant = want;
    this.pendingLaunchParam = launchParam;
    this.routeCardWant(want);
    this.queueCliRequest(want);
    if (this.qtAbilityCreated) {
      qpa.handleAbilityOnNewWant(this, want, launchParam);
      this.drainCliRequests();
    }
  }

  onForeground() {
    AppStorage.setOrCreate('stellariumStartupForeground', true);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'QAbility::onForeground()');
    this.isForeground = true;
    this.restoreWindowAfterConsent();
    this.startInputStallProbe();
    this.logPrivacyProbe('ability-foreground');
    setDeepSkyImageExtractionForeground(true);
    if (!this.qtInitialized) {
      void this.startQtIfReady();
      return;
    }
    qpa.handleAbilityOnForeground(this);
    notifyLifecycle(true);
    try {
      command('setApplicationForeground', '1');
    } catch (err) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'QAbility::onForeground lifecycle bridge unavailable');
    }
    if (this.context.windowStage) {
      this.enterImmersive(this.context.windowStage);
    }
  }

  onBackground() {
    AppStorage.setOrCreate('stellariumStartupForeground', false);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'QAbility::onBackground()');
    this.isForeground = false;
    this.stopInputStallProbe();
    this.logPrivacyProbe('ability-background');
    setDeepSkyImageExtractionForeground(false);
    if (!this.qtInitialized) {
      return;
    }
    // Release page-owned sensor subscriptions before Qt transitions hidden.
    notifyLifecycle(false);
    try {
      command('setApplicationForeground', '0');
    } catch (err) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'QAbility::onBackground lifecycle bridge unavailable');
    }
    qpa.handleAbilityOnBackground(this);
  }

  onWindowStageDestroy() {
    this.rootContentLoaded = false;
    this.qtWindowStage = undefined;
    hilog.info(LOG_DOMAIN, LOG_TAG, 'QAbility::onStageDestroy()');
    this.logPrivacyProbe('window-stage-destroy');
    if (this.qtAbilityCreated) {
      qpa.handleAbilityOnWindowStageDestroy(this);
    }
  }

  onContinue(wantParam: Record<string, Object>): AbilityConstant.OnContinueResult | Promise<AbilityConstant.OnContinueResult> {
    return AbilityConstant.OnContinueResult.REJECT;
  }
}
