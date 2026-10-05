// 设置面板选项行为控制器（PLAN §15.12 E 轨道 E3，2026-10-05）。
//
// 原宿主 MainWindowNativeNode 的设置 / 配置行为整体下沉，共 18 个方法 + 1 个保留回注：
//   - 纯谓词 / 分派：settingsChoiceSelected / selectSettingsChoice；
//   - 信息窗：setInformationMode / setInformationField / applyCustomInformationMask；
//   - 配置项：setConfigurationDateFormat / setConfigurationDithering / setDistanceUnit /
//     setFovMarkerSetting / setProjection；
//   - 导航：setNavigationBoolean / setNavigationMaxFov；
//   - 星历：setEphemerisEnabled；
//   - 整包：saveAllCoreSettings / restoreCoreDefaults / exportConfig / importConfig /
//     applyAtmosphereResponse。
// applySelectedInfoMode 属 SelectionService 保留族（PLAN §15.6-6）：本体留宿主，本控制器
// 只迁其调用方（setInformationMode），经 SettingsHostHooks.applySelectedInfoMode 回注。
//
// **不 import NAPI/UI**（§15.7 规则 1）：桥经 CommandPort；可观测状态写 InfoWindowStore /
// TimeSettingsStore / NavigationSettingsStore / ViewSettingsStore / EphemerisStore /
// ObjectDetailStore / ToolsStore / AtmosphereStore。
// 宿主保留动作经 SettingsHostHooks 回注（§15.7 规则 4）：applySelectedInfoMode /
// refreshSelectedObject（SelectionService 保留族）、setCurrentProjection（宿主 @State）、
// saveAppSettings、时间设置写回（TimeController 本体留宿主）、导出配置剪贴板落点。
import hilog from '@ohos.hilog'
import { I18n } from '../pages/I18n'
import { StellariumBridgeResponse, ObjectDetailField } from '../pages/StellariumTypes'
import { ExportConfigResponse, ImportConfigResponse } from '../pages/MainWindowModels'
import { CommandPort } from '../bridge/CommandPort'
import { InfoWindowStore } from '../state/InfoWindowStore'
import { TimeSettingsStore } from '../state/TimeSettingsStore'
import { NavigationSettingsStore } from '../state/NavigationSettingsStore'
import { ViewSettingsStore } from '../state/ViewSettingsStore'
import { EphemerisStore } from '../state/EphemerisStore'
import { ObjectDetailStore } from '../state/ObjectDetailStore'
import { ToolsStore } from '../state/ToolsStore'
import { AtmosphereStore } from '../state/AtmosphereStore'
import { informationMaskBit } from '../common/derive/skycult'
import { BehaviorHostHooks } from './ControllerHooks'

// 宿主 → 控制器回注（§13.1 规则 6 / §15.7 规则 4）。
export interface SettingsHostHooks extends BehaviorHostHooks {
  // SelectionService 保留族（§15.6-6）：信息模式派生级别 / 选中详情刷新本体留宿主。
  applySelectedInfoMode(mode: string): void
  refreshSelectedObject(): void
  // 宿主 @State，StartupBridge 亦经 hooks 写（§15.7 规则 2）。
  setCurrentProjection(value: string): void
  // 宿主既有持久化动作（saveAllCoreSettings 调用）。
  saveAppSettings(): void
  // 时间设置写回：TimeController 本体留宿主；项目无控制器互调先例，故用具名 hook 回注。
  saveTimePreference(command: string, payload: string, message: string): void
  setConfigurationTimeFormat(value: string): void
  setStartupTimeSetting(key: string, value: string): void
  // 导出配置的剪贴板落点（PlatformPort 适配器留宿主）。
  copyConfigExportText(text: string, successHint: ResourceStr): void
}

export class SettingsController {
  private port: CommandPort
  private infoWindowStore: InfoWindowStore
  private timeSettingsStore: TimeSettingsStore
  private navigationStore: NavigationSettingsStore
  private viewSettingsStore: ViewSettingsStore
  private ephemerisStore: EphemerisStore
  private objectDetailStore: ObjectDetailStore
  private tools: ToolsStore
  private atmosphereStore: AtmosphereStore
  private hooks: SettingsHostHooks

  constructor(
    port: CommandPort,
    infoWindowStore: InfoWindowStore,
    timeSettingsStore: TimeSettingsStore,
    navigationStore: NavigationSettingsStore,
    viewSettingsStore: ViewSettingsStore,
    ephemerisStore: EphemerisStore,
    objectDetailStore: ObjectDetailStore,
    tools: ToolsStore,
    atmosphereStore: AtmosphereStore,
    hooks: SettingsHostHooks
  ) {
    this.port = port
    this.infoWindowStore = infoWindowStore
    this.timeSettingsStore = timeSettingsStore
    this.navigationStore = navigationStore
    this.viewSettingsStore = viewSettingsStore
    this.ephemerisStore = ephemerisStore
    this.objectDetailStore = objectDetailStore
    this.tools = tools
    this.atmosphereStore = atmosphereStore
    this.hooks = hooks
  }

  // 原宿主 settingsChoiceSelected()：纯 store 读，无副作用。
  settingsChoiceSelected(group: string, value: string): boolean {
    if (group === 'information') return this.infoWindowStore.informationMode === value
    if (group === 'date') return this.timeSettingsStore.configDateFormat === value
    if (group === 'time') return this.timeSettingsStore.configTimeFormat === value
    if (group === 'startup') return this.timeSettingsStore.startupTimeMode === value
    return false
  }

  // 原宿主 selectSettingsChoice()：按分组分派到各 set*。
  selectSettingsChoice(group: string, value: string): void {
    if (this.settingsChoiceSelected(group, value)) return
    if (group === 'information') this.setInformationMode(value)
    else if (group === 'date') this.setConfigurationDateFormat(value)
    else if (group === 'time') this.hooks.setConfigurationTimeFormat(value)
    else if (group === 'startup') this.hooks.setStartupTimeSetting('startupMode', value)
  }

  // 原宿主 setInformationMode()。
  setInformationMode(mode: string): void {
    if (this.infoWindowStore.informationSettingPending || mode === this.infoWindowStore.informationMode) return
    this.infoWindowStore.informationSettingPending = true
    this.port.requestInteractive('setInformationSetting', 'mode|' + mode, (r: StellariumBridgeResponse) => {
      this.infoWindowStore.informationSettingPending = false
      if (r.ok !== true) { this.hooks.flashHint(r.error ?? I18n.t('msg_apply_failed')); return }
      this.infoWindowStore.informationMode = r.infoMode ?? mode
      if (r.customInfoMask !== undefined) this.infoWindowStore.informationCustomMask = Number(r.customInfoMask)
      this.hooks.applySelectedInfoMode(this.infoWindowStore.informationMode)
      this.objectDetailStore.selectedDetailLoaded = false
      this.hooks.refreshSelectedObject()
    }, () => {
      this.infoWindowStore.informationSettingPending = false
      this.hooks.flashHint(I18n.t('msg_apply_failed'))
    })
  }

  // 原宿主 setInformationField()。
  setInformationField(key: string, enabled: boolean): void {
    if (this.infoWindowStore.informationSettingPending || this.infoWindowStore.informationMode !== 'custom' || this.infoWindowStore.informationMaskHas(key) === enabled) return
    const bit = informationMaskBit(key)
    if (bit === 0) return
    const nextMask = enabled ? (this.infoWindowStore.informationCustomMask | bit) : (this.infoWindowStore.informationCustomMask & ~bit)
    this.infoWindowStore.informationSettingPending = true
    this.port.requestInteractive('setInformationSetting', 'mask|' + nextMask.toString(), (r: StellariumBridgeResponse) => {
      this.infoWindowStore.informationSettingPending = false
      if (r.ok !== true) { this.hooks.flashHint(r.error ?? I18n.t('msg_apply_failed')); return }
      this.infoWindowStore.informationMode = 'custom'
      this.infoWindowStore.informationCustomMask = r.customInfoMask !== undefined ? Number(r.customInfoMask) : nextMask
      this.infoWindowStore.infoLevel = 0
      this.objectDetailStore.selectedDetailLoaded = false
      this.hooks.refreshSelectedObject()
    }, () => {
      this.infoWindowStore.informationSettingPending = false
      this.hooks.flashHint(I18n.t('msg_apply_failed'))
    })
  }

  // 原宿主 applyCustomInformationMask()：自定义模式按位掩码清空明细字段。
  applyCustomInformationMask(): void {
    if (this.infoWindowStore.informationMode !== 'custom') return
    if (!this.infoWindowStore.informationMaskHas('magnitude')) {
      this.objectDetailStore.selectedMagnitude = ''
      this.objectDetailStore.selectedApparentMagnitude = ''
      this.objectDetailStore.selectedAirmass = ''
      this.objectDetailStore.selectedExtinction = ''
    }
    if (!this.infoWindowStore.informationMaskHas('raOfDate')) this.objectDetailStore.selectedCoordEq = ''
    if (!this.infoWindowStore.informationMaskHas('raJ2000')) this.objectDetailStore.selectedCoordEqJ2000 = ''
    if (!this.infoWindowStore.informationMaskHas('altAz')) {
      this.objectDetailStore.selectedCoordAlt = ''
      this.objectDetailStore.selectedCoordApparentAltAz = ''
      this.objectDetailStore.selectedCoordGeometricAltAz = ''
    }
    if (!this.infoWindowStore.informationMaskHas('eclipticOfDate')) this.objectDetailStore.selectedCoordEcliptic = ''
    if (!this.infoWindowStore.informationMaskHas('eclipticJ2000')) this.objectDetailStore.selectedCoordEclipticJ2000 = ''
    if (!this.infoWindowStore.informationMaskHas('galactic')) this.objectDetailStore.selectedCoordGalactic = ''
    if (!this.infoWindowStore.informationMaskHas('supergalactic')) this.objectDetailStore.selectedCoordSupergalactic = ''
    if (!this.infoWindowStore.informationMaskHas('otherCoordinates')) this.objectDetailStore.selectedCoordParallactic = ''
    if (!this.infoWindowStore.informationMaskHas('hourAngle')) this.objectDetailStore.selectedHourAngle = ''
    if (!this.infoWindowStore.informationMaskHas('constellation')) this.objectDetailStore.selectedConstellation = ''
    if (!this.infoWindowStore.informationMaskHas('distance')) this.objectDetailStore.selectedDistance = ''
    if (!this.infoWindowStore.informationMaskHas('size')) this.objectDetailStore.selectedSize = ''
    if (!this.infoWindowStore.informationMaskHas('siderealTime')) {
      this.objectDetailStore.selectedMeanSiderealTime = ''
      this.objectDetailStore.selectedApparentSiderealTime = ''
    }
    if (!this.infoWindowStore.informationMaskHas('riseTransitSet')) {
      this.objectDetailStore.selectedRise = ''
      this.objectDetailStore.selectedSet = ''
      this.objectDetailStore.selectedTransit = ''
    }
    if (!this.infoWindowStore.informationMaskHas('elongation')) {
      this.objectDetailStore.selectedPhase = ''
      this.objectDetailStore.selectedElongation = ''
    }
    const groups = new Map<string, string>([
      ['designations', 'catalog'], ['designation', 'catalog'], ['catalogNumber', 'catalog'], ['internationalDesignator', 'catalog'], ['culturalNames', 'name'],
      ['hourAngle', 'hourAngle'], ['meanSiderealTime', 'siderealTime'], ['apparentSiderealTime', 'siderealTime'],
      ['equatorialOfDate', 'raOfDate'], ['equatorialJ2000', 'raJ2000'], ['apparentAltAz', 'altAz'], ['geometricAltAz', 'altAz'],
      ['eclipticCurrent', 'eclipticOfDate'], ['eclipticJ2000', 'eclipticJ2000'], ['galactic', 'galactic'], ['supergalactic', 'supergalactic'],
      ['parallacticAngle', 'otherCoordinates'], ['blueMagnitude', 'magnitude'], ['surfaceBrightness', 'magnitude'], ['colorIndex', 'magnitude'],
      ['angularAxes', 'size'], ['positionAngle', 'size']
    ])
    this.objectDetailStore.selectedDetailFields = this.objectDetailStore.selectedDetailFields.filter((field: ObjectDetailField) =>
      this.infoWindowStore.informationMaskHas(groups.get(field.key) ?? 'extra'))
  }

  // 原宿主 setConfigurationDateFormat()：写回时间日期格式（TimeController.saveTimePreference 经 hooks）。
  setConfigurationDateFormat(value: string): void {
    this.hooks.saveTimePreference('setDateFormat', value, 'time_settings_applied')
  }

  // 原宿主 setConfigurationDithering()。
  setConfigurationDithering(value: string): void {
    this.port.requestInteractive('setDitheringMode', value.toLowerCase(), (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.viewSettingsStore.configDitheringMode = value
        this.hooks.flashHint('渲染质量已更新')
      } else {
        this.hooks.flashHint(r.error ?? I18n.t('msg_apply_failed'))
        this.timeSettingsStore.loadConfigurationSettings()
      }
    })
  }

  // 原宿主 setDistanceUnit()。
  setDistanceUnit(useMetric: boolean): void {
    this.port.requestInteractive('setConfigString', 'astronomy/flag_use_km_for_distance=' + (useMetric ? 'true' : 'false'), (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.viewSettingsStore.useMetricUnits = useMetric
      } else {
        this.hooks.flashHint(r.error ?? I18n.t('msg_apply_failed'))
        this.timeSettingsStore.loadConfigurationSettings()
      }
    })
  }

  // 原宿主 setFovMarkerSetting()。
  setFovMarkerSetting(setting: string, value: number): void {
    this.port.requestInteractive('setFovMarkerSetting', setting + '|' + value.toFixed(1), () => {})
  }

  // 原宿主 setProjection()：回包成功后写宿主 @State（经 hooks）并提示。
  setProjection(name: string): void {
    this.port.requestInteractive('setProjectionType', name, (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.hooks.setCurrentProjection(name)
        this.hooks.flashHint(I18n.projectionName(name))
      } else {
        hilog.error(0x0000, 'StellariumArkUI', 'setProjectionType rejected %{public}s err=%{public}s', name, r.error ?? '')
        this.hooks.flashHint(I18n.t('msg_apply_failed'))
      }
    })
  }

  // 原宿主 setEphemerisEnabled()。
  setEphemerisEnabled(key: string, available: boolean, enabled: boolean): void {
    if (!available && enabled) {
      this.hooks.flashHint('该星历文件未安装，无法启用')
      return
    }
    this.port.requestInteractive('setEphemerisSetting', key + '|' + (enabled ? '1' : '0'), (r: StellariumBridgeResponse) => {
      if (r.ok !== true) { this.hooks.flashHint(r.error ?? I18n.t('msg_apply_failed')); return }
      if (key === 'de430') this.ephemerisStore.ephemerisDe430Active = enabled
      else if (key === 'de431') this.ephemerisStore.ephemerisDe431Active = enabled
      else if (key === 'de440') this.ephemerisStore.ephemerisDe440Active = enabled
      else if (key === 'de441') this.ephemerisStore.ephemerisDe441Active = enabled
    })
  }

  // 原宿主 setNavigationBoolean()。
  setNavigationBoolean(setting: string, enabled: boolean): void {
    this.port.requestInteractive('setNavigationSetting', setting + '|' + (enabled ? '1' : '0'), (r: StellariumBridgeResponse) => {
      if (r.ok !== true) {
        this.hooks.flashHint(I18n.t('msg_apply_failed'))
        return
      }
      if (setting === 'mouseNavigation') this.navigationStore.navigationMouseEnabled = enabled
      else if (setting === 'mouseZooming') this.navigationStore.navigationMouseZoomEnabled = enabled
      else if (setting === 'moveKeys') this.navigationStore.navigationMoveKeysEnabled = enabled
      else if (setting === 'zoomKeys') this.navigationStore.navigationZoomKeysEnabled = enabled
      else if (setting === 'gravityLabels') this.navigationStore.navigationGravityLabelsEnabled = enabled
      else if (setting === 'autoZoomResets') this.viewSettingsStore.autoZoomResets = enabled
    })
  }

  // 原宿主 setNavigationMaxFov()。
  setNavigationMaxFov(value: number): void {
    const maxFov = Math.max(1, Math.min(360, Math.round(value)))
    this.port.requestInteractive('setNavigationSetting', 'maxFov|' + maxFov.toString(), (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.navigationStore.navigationMaxFov = maxFov
        this.hooks.flashHint(I18n.t('settings_view_max_fov_updated'))
      } else {
        this.hooks.flashHint(I18n.t('msg_apply_failed'))
      }
    })
  }

  // 原宿主 saveAllCoreSettings()。
  saveAllCoreSettings(): void {
    this.hooks.saveAppSettings()
    this.port.requestInteractive('saveAllSettings', '', (r: StellariumBridgeResponse) => {
      this.hooks.flashHint(r.ok === true ? I18n.t('settings_saved') : I18n.t('msg_apply_failed'))
    })
  }

  // 原宿主 restoreCoreDefaults()。
  restoreCoreDefaults(): void {
    this.port.requestInteractive('restoreDefaultSettings', '', (r: StellariumBridgeResponse) => {
      if (r.ok !== true) {
        this.hooks.flashHint(I18n.t('msg_apply_failed'))
        return
      }
      this.hooks.flashHint(I18n.t('settings_defaults_restart'))
    })
  }

  // 原宿主 exportConfig()：导出文本落 ToolsStore，剪贴板经 hooks（PlatformPort 适配器留宿主）。
  exportConfig(): void {
    this.port.requestWhenReady('exportConfig', '', (r: StellariumBridgeResponse) => {
      const resp = r as ExportConfigResponse
      if (resp.ok !== true) {
        this.hooks.flashHint(I18n.t('config_export_failed'))
        return
      }
      this.tools.configExportText = resp.content ?? ''
      this.tools.configExportVisible = true
      this.hooks.copyConfigExportText(this.tools.configExportText, I18n.t('config_export_copied'))
    })
  }

  // 原宿主 importConfig()。
  importConfig(): void {
    const text = this.tools.configImportText.trim()
    if (text.length === 0) {
      this.hooks.flashHint(I18n.t('msg_paste_config_first'))
      return
    }
    this.tools.configImportMsg = '正在导入…'
    this.port.requestWhenReady('importConfig', text, (r: StellariumBridgeResponse) => {
      const resp = r as ImportConfigResponse
      if (resp.ok === true) {
        this.tools.configImportText = ''
        this.tools.configImportMsg = '已导入 ' + (resp.applied ?? 0) + ' 项配置'
        this.hooks.flashHint(this.tools.configImportMsg)
      } else {
        this.tools.configImportMsg = '导入失败：' + (resp.error ?? '未知错误')
      }
    })
  }

  // 原宿主 applyAtmosphereResponse()：大气参数回包写入 AtmosphereStore。
  applyAtmosphereResponse(r: StellariumBridgeResponse): void {
    if (r.ok !== true) return
    if (r.pressure !== undefined) this.atmosphereStore.atmoPressure = r.pressure
    if (r.temperature !== undefined) this.atmosphereStore.atmoTemperature = r.temperature
    if (r.extinction !== undefined) this.atmosphereStore.atmoExtinction = r.extinction
    this.atmosphereStore.refractionOn = (r.refractionOn === true)
  }
}
