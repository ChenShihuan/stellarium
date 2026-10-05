import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'
import { geoLocationManager } from '@kit.LocationKit'
import { sensor } from '@kit.SensorServiceKit'
import { curves } from '@kit.ArkUI'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { media } from '@kit.MediaKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { systemShare } from '@kit.ShareKit'
import { privacyManager } from '@kit.AppGalleryKit'
import { hasCurrentPrivacyConsent } from '../qability/PrivacyConsent'
import { writeClipboardText } from '../qability/ClipboardService'
import { fileIo, fileUri, picker } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { image } from '@kit.ImageKit'
import hilog from '@ohos.hilog'
import display from '@ohos.display'
import preferences from '@ohos.data.preferences'
import { LOCATION_HIERARCHY } from './location_hierarchy'
import { LOCATION_COUNTRY_NAMES } from './location_countries'
import { LOCATION_ZH_NAMES } from './location_names_zh'
import { proceduralModelKind, proceduralParticles } from './ProceduralDetailModel'
import { ASTRONOMY_GUIDES, AstronomyGuide, GuideState, GuideStep } from './AstronomyGuide'

import { StellariumBridgeResponse, SessionSnapshot, TonightEvents, TonightPlanet, TonightShower, WutTarget, EphemerisRow, AstroCalcContext, RtsCalendarDay, AltAzPoint, AnnualElevationPoint, ObservabilityDay, LunarElongationPoint, PlanetTimeSeriesPoint, PlanetPairDistancePoint, PlanetCalcItem, PhenomenonItem, EclipseItem, PlanetaryTransitItem, MoonPhaseItem, SeasonEvent, LangOption, HierCity, CatOption, NameItem, SearchSug, WindowNativeNodeCreateInfo, TabItem, ChipItem, LandscapeItem, ScriptMetadata, PlanetPosition, HeliocentricPosition, CelestialPosition, ObjectInfo, SkyCultureItem, SkyCultureRawItem, SkyCultureArtItem, SkyCultureDescriptionBlock, SkyCultureTerritoryEntry, SkyCultureTerritoryPolygon, PluginItem, Scenery3dItem, ShellAction, LocSearchItem, SavedLocation, ObjectDetailField, ObjectDetailModel, SatellitePass } from './StellariumTypes'
import { setLifecycleListener } from '../common/StellariumLifecycle'
import { AudioEngine } from './StellariumAudio'
import { I18n, LANGUAGE_DISPLAY, PROJECTION_KEYS } from './I18n'
import { DeepSkyWarmupStatus, getDeepSkyResourceWarmupStatus, isStellariumDetailMediaPreparationFailed, resolveStellariumDetailMediaAsset } from '../qability/StellariumResourceBootstrap'
import { UI_RADIUS_CONTROL, UI_RADIUS_PANEL, UI_RADIUS_SHEET, UI_RADIUS_PILL, UI_OPTION_ANIMATION_MS } from '../common/ui/UiTokens'
import { getIcon } from '../common/ui/ShellIcons'
import {
  CHROME_ZOOM_BUTTON_SIZE,
  chromeZoomButtonLeft,
  chromeZoomButtonTop
} from '../common/ui/ChromeGeometry'
import { gyroRotateAboutAxis, gyroMultiplyQuaternions, gyroFilterDeviceVector, gyroCross, gyroRotateAboutVertical, gyroScreenAxisForDisplay, shortestGyroAzimuthDelta, wrapGyroAzimuth, gyroNormalizeVector, gyroNormalizeQuaternion, gyroConjugateQuaternion, gyroDot, gyroMagneticHeadingFromDeviceVectors } from '../common/derive/gyro'
import { dateToJD, jdToLocalTimeText, astroTabItemsForGroup, astroGroupForTab, graphModeLabel, graphStartOptionLabel, planetMetricUnit, planetPairBodyName, phenomenonCaption, hecPointColor, hecLayoutPositions, hecPointLeft, hecPointTop, messierNumberOf, minorPlanetNumberOf, fmtDegMin, clamp, distance } from '../common/derive/astro'
import { resourceText, describeDecodeError, zhNameOf, zhType, planetZh, sensZh, scriptZh, scriptDesc, pluginZh, pluginDesc, pluginHostName, pluginFeatureRoute, approximateTimeZoneDisplay, panelTitleFor, celestialTitle } from '../common/derive/labels'
import { isSafeSkyCultureArtPath, cleanSkyCultureDescription, cleanSkyCultureNarration, isCliPanelName, parseObservingList, formatRate, configDitheringLabel, informationMaskBit, isRecordable } from '../common/derive/skycult'
import { primaryDockActions, moreActions, observingHubActions, skyDataHubActions, automationHubActions, getCityPreset, telescopeUpdateTime, telescopeErrorText, validationFromResponse, officialLocationAliases, panelRouteParent, inferredPanelRouteDirection, locationSearchMatchScore } from '../common/derive/actions'
import { pointInsideRect, pointOverlapsUiObstacle, touchScreenX, touchScreenY, touchWindowX, touchWindowY, azBarHeight, compactTopQuickY, baseCompactObjectPeekY, expandedDetailSummaryHeight, isPhoneDetailPeek, useTabletObjectInspector, useExpandedDetailSummary, railTop, expandedMainPanelLeft, panelTop, panelLeft, panelRight, baseExpandedDetailSummaryX, baseExpandedDetailSummaryY, baseTabletInspectorX, baseTabletInspectorY, tabletInspectorHeight, baseBottomCardX, baseBottomCardY, expandedDockWidth, expandedDockLeft, dockWidthPixels, dockLeft, chromeRowPosXLeft, chromeRowPosXRight, guideCardHeight, guideCardX, guideCardY, scriptControlWidth, scriptControlX, scriptControlY, isPanelBackPoint, isDockPoint, objectActionBarY, isObjectDetailCardPoint, canShowExpandedDetailSummary, expandedDetailSummaryWidth } from '../common/derive/geometry'
import { catalogIconForModule, catalogIconForObjectType, wutCategoryOptions, wutCategoryKey, wutDirectionLabel } from '../common/derive/catalog'
import { objectInspectorPlanetTexturePath, objectInspectorPlanetRingSpec, objectInspectorDeepSkyImageName, objectInspectorFallbackVisualKind, objectInspectorStarColor } from '../common/derive/media'
import { BridgeClient } from '../bridge/BridgeClient'
import { CommandPort } from '../bridge/CommandPort'
import { MediaPort, MediaSaveResult, ScreenCaptureState } from '../bridge/MediaPort'
import { PlatformPort } from '../bridge/PlatformPort'
import { SensorPort, SensorProbeInfo } from '../bridge/SensorPort'
import { LocationPort, LocationFix } from '../bridge/LocationPort'
import { LocationController, LocationHostHooks } from '../capability/LocationController'
import { LocationStoreHostHooks, LocationDraft } from '../state/LocationStore'
import { decodeLocalImage, releaseDecodedImage } from '../common/media/ImageDecoder'
import { copyTextToClipboard } from '../common/platform/Clipboard'
import { shareFile } from '../common/platform/Share'
import { saveScreenshot, exportScreenshotToUserStorage } from '../common/platform/Screenshot'
import { speakSelectedObject } from '../common/SpeechService'
import { StartupBridge, StartupHooks } from '../capability/StartupBridge'
import { SensorController, GyroGuideLayout, SensorHostHooks } from '../capability/SensorController'
import { RecordingController, RecordingHostHooks } from '../capability/RecordingController'
import { ObjectModelRenderer, ObjectModelRendererHostHooks } from '../capability/ObjectModelRenderer'
import { SkyInputController, SkyInputHostHooks } from '../capability/SkyInputController'
import { TimeStore } from '../state/TimeStore'
import { SatelliteStore } from '../state/SatelliteStore'
import { ScriptStore } from '../state/ScriptStore'
import { SceneryStore } from '../state/SceneryStore'
import { CatalogStore } from '../state/CatalogStore'
import { MeteorStore } from '../state/MeteorStore'
import { CommandStore } from '../state/CommandStore'
import { TimeSpeedChips } from '../panels/time/TimeSpeedChips'
import { JulianDateStore } from '../state/JulianDateStore'
import { JulianDateControls } from '../panels/time/JulianDateControls'
import { SiderealTimeRow } from '../panels/time/SiderealTimeRow'
import { EquationOfTimeBlock } from '../panels/time/EquationOfTimeBlock'
import { EquationOfTimeStore } from '../state/EquationOfTimeStore'
import { DeltaTStore } from '../state/DeltaTStore'
import { TimeSettingsStore } from '../state/TimeSettingsStore'
import { SettingsChoiceButton } from '../common/ui/SettingsChoiceButton'
import { NightModeStore } from '../state/NightModeStore'
import { TimeWheelController } from '../state/TimeWheelController'
import { BookmarkStore } from '../state/BookmarkStore'
import { BookmarkPanel } from '../panels/BookmarkPanel'
import { SearchStore } from '../state/SearchStore'
import { ObjectDetailStore } from '../state/ObjectDetailStore'
import { GyroStore } from '../state/GyroStore'
import { WutStore } from '../state/WutStore'
import { AstroStore } from '../state/AstroStore'
import { LocationStore } from '../state/LocationStore'
import { CityChipsRow } from '../panels/location/CityChipsRow'
import { LocationPickerPanel } from '../panels/location/LocationPickerPanel'
import { LocationPickerStore } from '../state/LocationPickerStore'
import { LayerStore } from '../state/LayerStore'
import { LayerSwitchRow } from '../panels/layers/LayerSwitchRow'
import { LayerPresetBar } from '../panels/layers/LayerPresetBar'
import { LayerTabs } from '../panels/layers/LayerTabs'
import { LayerViewStore } from '../state/LayerViewStore'
import { LayerSkyTab, LayerSsoTab, LayerDsoTab, LayerMarkingsTab, LayerLandscapeTab, LayerSurveysTab } from '../panels/layers/LayerViewTabs'
import { TelescopeStore } from '../state/TelescopeStore'
import { OcularSelector } from '../panels/telescope/OcularSelector'
import { OcularMetric } from '../panels/telescope/OcularMetric'
import { Lx200Panel } from '../panels/telescope/Lx200Panel'
import { Lx200ObjectControls } from '../panels/telescope/Lx200ObjectControls'
import { SkyCultureMakerStore } from '../state/SkyCultureMakerStore'
import { SkyCultureViewStore } from '../state/SkyCultureViewStore'
import { SkyCultureSettingsStore } from '../state/SkyCultureSettingsStore'
import { AstroSelectionGuide, PhenomenonRelationMark } from '../panels/astro/AstroGuides'
import { ContinuationSection } from '../panels/astro/ContinuationSection'
import { WutTargetCard } from '../panels/astro/WutTargetCard'
import { AstroPanel } from '../panels/astro/AstroPanel'
import { GraphLoadingRow, RtsSelectionGuide, GraphSelectionGuide } from '../panels/astro/GraphGuides'
import { InfoRow } from '../common/ui/InfoRow'
import { ObjectMediaStore } from '../state/ObjectMediaStore'
import { ObjectDataRow, StructuredDetailRow, DetailSectionTitle } from '../panels/object/DetailRows'
import { TabletInspectorMediaCard, TabletInspectorNoticeRow, TabletInspectorModelBlock, TabletInspectorProgressRow, TabletInspectorFallbackVisual } from '../panels/object/TabletInspectorMedia'
import { ObjectDataTile, ObjectMetric, ObjectScheduleTile, ObjectDetailTab, ObjectCompactMetric } from '../panels/object/DetailTiles'
import { ObjectDistanceNotice, SelectedLiveInfoRows, SelectedCoordinateRow, SelectedCoordinateRows } from '../panels/object/DetailLiveRows'
import { StructuredDetailRows } from '../panels/object/StructuredDetailRows'
import { SatellitePassDetails } from '../panels/object/SatellitePassDetails'
import { TabletInspectorMediaGroup } from '../panels/object/TabletInspectorMediaGroup'
import { PanelHeader } from '../panels/shell/PanelHeader'
import { DockButton } from '../panels/shell/DockButton'
import { CompactTopQuickControls } from '../panels/shell/CompactTopQuickControls'
import { HubActionList } from '../panels/shell/HubActionList'
import { ConstellationCultureView } from '../panels/object/ConstellationCultureView'
import { SkyCultureDescriptionBlockView } from '../panels/skyculture/SkyCultureDescriptionBlockView'
import { SkyCultureMakerTabs } from '../panels/skyculture/SkyCultureMakerTabs'
import { SkyCultureMakerOverview } from '../panels/skyculture/SkyCultureMakerOverview'
import { SkyCultureMakerConstellationEditor } from '../panels/skyculture/SkyCultureMakerConstellationEditor'
import { SkyCultureMakerValidationPanel } from '../panels/skyculture/SkyCultureMakerValidationPanel'
import { SearchBar } from '../panels/search/SearchBar'
import { SearchSuggestions } from '../panels/search/SearchSuggestions'
import { SearchFilterMenu } from '../panels/search/SearchFilterMenu'
import { SearchFilterChips } from '../panels/search/SearchFilterChips'
import { SearchCategoryBrowse } from '../panels/search/SearchCategoryBrowse'
import { SearchConstellationChips } from '../panels/search/SearchConstellationChips'
import { SearchCoordinateInput } from '../panels/search/SearchCoordinateInput'
import { NightModeToggleRow } from '../common/ui/NightModeToggleRow'
import { ObservationAidBlock } from '../panels/time/ObservationAidBlock'
import { TimeJumpActions } from '../panels/time/TimeJumpActions'
import { ManualTimeBlock } from '../panels/time/ManualTimeBlock'
import { TimeWheelStore } from '../state/TimeWheelStore'
import { TimeWheelScrubber } from '../panels/time/TimeWheelScrubber'
import { OverlayStore } from '../state/OverlayStore'
import { PolarScopeStore } from '../state/PolarScopeStore'
import { ArchaeoStore } from '../state/ArchaeoStore'
import { NavStarsStore } from '../state/NavStarsStore'
import { MosaicStore } from '../state/MosaicStore'
import { ObservingListStore } from '../state/ObservingListStore'
import { AudioStore } from '../state/AudioStore'
import { EphemerisStore } from '../state/EphemerisStore'
import { NebulaTextureStore } from '../state/NebulaTextureStore'
import { PluginStore } from '../state/PluginStore'
import { NavigationSettingsStore } from '../state/NavigationSettingsStore'
import { ViewSettingsStore } from '../state/ViewSettingsStore'
import { InfoWindowStore } from '../state/InfoWindowStore'
import { LanguageStore } from '../state/LanguageStore'
import { AtmosphereStore } from '../state/AtmosphereStore'
import { GuideStore } from '../state/GuideStore'
import { PointerCoordinatesPanel } from '../panels/view/PointerCoordinatesPanel'
import { ViewCenterCoordinateOverlay } from '../panels/overlay/ViewCenterCoordinateOverlay'
import { PolarScopeOverlay } from '../panels/overlay/PolarScopeOverlay'
import { ObjectInspectorMediaPreviewOverlay } from '../panels/overlay/ObjectInspectorMediaPreviewOverlay'
import { SkyCultureArtPreviewOverlay } from '../panels/overlay/SkyCultureArtPreviewOverlay'
import { ObjectInspectorModelOverlay } from '../panels/overlay/ObjectInspectorModelOverlay'
import { ToolsStore } from '../state/ToolsStore'
import { ToolsPanel } from '../panels/tools/ToolsPanel'
import { RecordingControlBar } from '../panels/tools/RecordingControlBar'
import { RecordingFocusShell } from '../panels/tools/RecordingFocusShell'
import { SessionToolStore } from '../state/SessionToolStore'
import { ObserverPlanetSection, PointingTestSection, WatchGyroSection, TonightEventsSection } from '../panels/astro/SessionToolSections'
import { GyroTargetGuide } from '../panels/astro/GyroTargetGuide'
import { SkyCultureMakerPanel } from '../panels/skyculture/SkyCultureMakerPanel'
import { SkyCultureViewTab } from '../panels/skyculture/SkyCultureViewTab'
import { PadPanelHandle, PanelHandle } from '../panels/shell/PanelChromeExtras'
import { ScriptFocusShell } from '../panels/shell/ScriptFocusShell'
import { CompactShell } from '../panels/shell/CompactShell'
import { HarmonyShell } from '../panels/shell/HarmonyShell'
import { HoverObservatoryShell } from '../panels/shell/HoverObservatoryShell'
import { ExpandedShell } from '../panels/shell/ExpandedShell'
import { ScriptKeyButton } from '../panels/tools/ScriptKeyButton'
import { GuideLibrary } from '../panels/guide/GuideLibrary'
import { InteractiveGuideShell } from '../panels/shell/InteractiveGuideShell'
import { AngleMeasurePanel } from '../panels/panels/AngleMeasurePanel'
import { AudioPanel } from '../panels/panels/AudioPanel'
import { Scenery3dPanel } from '../panels/panels/Scenery3dPanel'
import { CatalogsPanel } from '../panels/panels/CatalogsPanel'
import { PlacePanel } from '../panels/panels/PlacePanel'
import { CommandsPanel } from '../panels/panels/CommandsPanel'
import { NavStarsPanel } from '../panels/panels/NavStarsPanel'
import { ArchaeoLinesPanel } from '../panels/panels/ArchaeoLinesPanel'
import { MosaicCameraPanel } from '../panels/panels/MosaicCameraPanel'
import { MorePanel } from '../panels/panels/MorePanel'
import { TimePanel } from '../panels/panels/TimePanel'
import { HelpPanel } from '../panels/panels/HelpPanel'
import { MeteorShowersPanel } from '../panels/panels/MeteorShowersPanel'
import { NebulaTexturesPanel } from '../panels/panels/NebulaTexturesPanel'
import { ScriptsPanel } from '../panels/panels/ScriptsPanel'
import { LayersPanel } from '../panels/panels/LayersPanel'
import { ObservingPanel } from '../panels/panels/ObservingPanel'
import { SearchPanel } from '../panels/panels/SearchPanel'
import { ObjectPanel } from '../panels/panels/ObjectPanel'
import { SatellitesPanel } from '../panels/panels/SatellitesPanel'
import { TelescopePanel } from '../panels/panels/TelescopePanel'
import { OcularsPanel } from '../panels/panels/OcularsPanel'
import { SettingsQuickLegacyPanel } from '../panels/panels/SettingsQuickLegacyPanel'
import { SettingsPanel } from '../panels/panels/SettingsPanel'
import { ConfigFallbackPanel } from '../panels/panels/ConfigFallbackPanel'
import { SkyCultureSectionHeader, SkyCultureMetaItem, SkyCultureLabelSettingCard, SkyCultureFilterPicker } from '../panels/skyculture/SkyCultureViewParts'
import { SatelliteGroupSelector } from '../panels/satellite/SatelliteGroupSelector'
import {
  ImageDecodeSize, HeliocentricPositionOptions, ConstellationNavigationItem, PluginFeatureRoute,
  NebulaTextureItem, NebulaTextureStatus, NebulaTextureRefreshResponse, SkyCultureMakerArtworkAnchor, SkyCultureMakerArtwork, SkyCultureMakerConstellation,
  SkyCultureMakerDraft, SkyCultureMakerIssue, TelescopeControlResponse, TelescopeProfile, TelescopeProfilesResponse,
  TELESCOPE_SIMULATOR_MODEL, HeliocentricOrbit, ConfigurationOption, SkyCultureVisualColors, CelestialPositionOptions,
  CelestialPositionCategory, PhenomenaOptions, PhenomenaStartOption, EphemerisOptions, RtsCalendarOptions, EclipseOptions,
  LayerPresetState, MARKING_LAYER_ACTION_IDS, CONTENT_LAYER_ACTION_IDS, AstroCsvExport, CELESTIAL_POSITION_CATEGORIES, HELIOCENTRIC_PLANET_ORBITS,
  HELIOCENTRIC_DISTANCE_GUIDES, PHENOMENA_START_OPTIONS, TonightPlanetRow,
  StarCatalogStatusResponse, GyroGuideProjection, SkyUiObstacle, BookmarkItem,
  BookmarkRaw, BookmarksResponse, BOOKMARK_STORE, SEARCH_HISTORY_STORE, OBSERVING_STORE, LOCATION_STORE, ObserverLocationRecord, OFFLINE_APPGALLERY_BUILD,
  OcularsData, OcularsResponse, OcularModeResponse, PointerCoordinatesData, PointerCoordinatesResponse,
  EquationOfTimeData, ArchaeoLinesData, ArchaeoPlanetOption, SatellitesData, SatelliteListItem,
  SatelliteSource, SatelliteSourceInput, SatelliteUpdateSettings, SatelliteSourcesResponse, CatalogHealthEntry,
  MeteorShowersData, LogResponse,
  ExportConfigResponse, ScreenshotResponse, ImportConfigResponse, SpokenTextResponse, RecordCmd,
  RecordingEntry, RecordingsResponse, RecordingDetailResponse, ScriptStatusResponse, ScriptCaption, ScriptCaptionsResponse,
  CommandCatalogEntry
} from './MainWindowModels'

// Sky-texture status banner. Its visibility is driven purely by the live
// deep-sky texture state reported by getDeepSkyImageStatus: pending>0 or a
// "loading" status shows "N 项待完成", an error status shows a retry action,
// and a ready view hides it immediately. It is never retracted on a timer while
// textures are still loading. A view that keeps reporting pending textures far
// beyond any plausible load is escalated to an actionable retry state instead of
// a silent hide, so the note can never stick forever without an affordance.
const SKY_TEXTURE_STATUS_FAST_POLLS: number = 24
const SKY_TEXTURE_STATUS_SLOW_INTERVAL_MS: number = 2000
const SKY_TEXTURE_STATUS_STALL_POLLS: number = 90
// The seven planets (without Earth) plus the Moon and the Sun: the bodies whose
// detail textures are worth resolving before the user opens their cards.
const BODY_DETAIL_TEXTURE_PATHS: Array<string> = [
  'textures/sun.png', 'textures/mercury.png', 'textures/venus.png', 'textures/mars.png',
  'textures/jupiter.png', 'textures/saturn.png', 'textures/uranus.png', 'textures/neptune.png',
  'textures/moon.png',
]

// 宿主 → CommandPort 的具名适配器（§14.1 AB-0）。把宿主既有的桥方法逐字转发给注入端口，
// 使域 store 能在不 import NAPI 的前提下调用桥；行为与直接调用宿主方法完全一致
// （callNativeWhenReady 仍走宿主的录制记录，默认重试参数 200ms × 60 显式传入）。
// 用具名 class 实现接口，避免 ArkTS 匿名对象字面量越界；先例 state/TimeWheelController.ets。
class HostCommandPort implements CommandPort {
  private readonly requestFn: (name: string, payload: string) => StellariumBridgeResponse
  private readonly whenReadyFn: (name: string, payload: string, onOk: (r: StellariumBridgeResponse) => void, onFailure?: (r: StellariumBridgeResponse) => void, attempt?: number, intervalMs?: number, maxAttempts?: number) => void
  private readonly interactiveFn: (name: string, payload: string, onOk: (r: StellariumBridgeResponse) => void, onFailure?: (r: StellariumBridgeResponse) => void) => void
  private readonly longRunningFn: (name: string, payload: string, onOk: (r: StellariumBridgeResponse) => void, onFailure?: (r: StellariumBridgeResponse) => void, onProgress?: (r: StellariumBridgeResponse) => void, maxAttempts?: number, isCancelled?: () => boolean) => void
  private readonly fireFn: (name: string, payload: string) => void

  constructor(
    requestFn: (name: string, payload: string) => StellariumBridgeResponse,
    whenReadyFn: (name: string, payload: string, onOk: (r: StellariumBridgeResponse) => void, onFailure?: (r: StellariumBridgeResponse) => void, attempt?: number, intervalMs?: number, maxAttempts?: number) => void,
    interactiveFn: (name: string, payload: string, onOk: (r: StellariumBridgeResponse) => void, onFailure?: (r: StellariumBridgeResponse) => void) => void,
    longRunningFn: (name: string, payload: string, onOk: (r: StellariumBridgeResponse) => void, onFailure?: (r: StellariumBridgeResponse) => void, onProgress?: (r: StellariumBridgeResponse) => void, maxAttempts?: number, isCancelled?: () => boolean) => void,
    fireFn: (name: string, payload: string) => void
  ) {
    this.requestFn = requestFn
    this.whenReadyFn = whenReadyFn
    this.interactiveFn = interactiveFn
    this.longRunningFn = longRunningFn
    this.fireFn = fireFn
  }

  request(name: string, payload: string = ''): StellariumBridgeResponse {
    return this.requestFn(name, payload)
  }

  requestWhenReady(name: string, payload: string, onOk: (r: StellariumBridgeResponse) => void, onFailure?: (r: StellariumBridgeResponse) => void, attempt?: number, intervalMs?: number, maxAttempts?: number): void {
    this.whenReadyFn(name, payload, onOk, onFailure, attempt, intervalMs, maxAttempts)
  }

  requestInteractive(name: string, payload: string, onOk: (r: StellariumBridgeResponse) => void, onFailure?: (r: StellariumBridgeResponse) => void): void {
    this.interactiveFn(name, payload, onOk, onFailure)
  }

  requestLongRunning(name: string, payload: string, onOk: (r: StellariumBridgeResponse) => void, onFailure?: (r: StellariumBridgeResponse) => void, onProgress?: (r: StellariumBridgeResponse) => void, maxAttempts?: number, isCancelled?: () => boolean): void {
    this.longRunningFn(name, payload, onOk, onFailure, onProgress, maxAttempts, isCancelled)
  }

  fire(name: string, payload: string = ''): void {
    this.fireFn(name, payload)
  }
}

// 宿主 → MediaPort 的具名适配器（PLAN §15.1 AB2-0a / M1-A）。把 fileIo / image / picker 调用
// 逐字转发给媒体服务（common/media、common/platform），使服务不 import NAPI。用具名 class 实现接口，
// 避免 ArkTS 匿名对象字面量越界；先例 HostCommandPort。
class HostMediaPort implements MediaPort {
  // 宿主 UI 上下文工厂经 configure 惰性注入（适配器在字段初始化时构造，此时 getUIContext 尚不可用）。
  private contextFactory: (() => common.UIAbilityContext) | null = null

  configure(contextFactory: () => common.UIAbilityContext): void {
    this.contextFactory = contextFactory
  }

  fileExists(path: string): boolean {
    return fileIo.accessSync(path)
  }

  openReadOnlyFile(path: string, label: string): number {
    const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
    hilog.info(0x0000, 'StellariumArkUI',
      '[detail-media] create image source kind=%{public}s path=%{public}s fd=%{public}s',
      label, path, file.fd.toString())
    return file.fd
  }

  closeFile(fd: number, label: string): void {
    try {
      fileIo.closeSync(fd)
    } catch (err) {
      hilog.warn(0x0000, 'StellariumArkUI', '[detail-media] file close failed kind=%{public}s error=%{public}s',
        label, JSON.stringify(err))
    }
  }

  createImageSource(fd: number, label: string): image.ImageSource {
    return image.createImageSource(fd)
  }

  createPixelMap(source: image.ImageSource, label: string, desiredSize?: ImageDecodeSize): Promise<image.PixelMap> {
    const pixelMapPromise = label === 'model'
      ? (desiredSize === undefined
        ? source.createPixelMapUsingAllocator({
          desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
          desiredDynamicRange: image.DecodingDynamicRange.SDR
        }, image.AllocatorType.SHARE_MEMORY)
        : source.createPixelMapUsingAllocator({
          desiredSize: desiredSize,
          desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
          desiredDynamicRange: image.DecodingDynamicRange.SDR
        }, image.AllocatorType.SHARE_MEMORY))
      : (desiredSize === undefined
        ? source.createPixelMap()
        : source.createPixelMap({ desiredSize: desiredSize }))
    if (label === 'model') {
      return pixelMapPromise.then((pixelMap: image.PixelMap) => {
        hilog.info(0x0000, 'StellariumArkUI',
          '[detail-media] decode promise settled kind=%{public}s bytes=%{public}s',
          label, pixelMap.getPixelBytesNumber().toString())
        return pixelMap
      })
    }
    return pixelMapPromise
  }

  releaseImageSource(source: image.ImageSource, label: string): void {
    source.release().catch((err: Error) => {
      hilog.warn(0x0000, 'StellariumArkUI', '[detail-media] image source release failed kind=%{public}s error=%{public}s',
        label, JSON.stringify(err))
    })
  }

  releasePixelMap(pixelMap: image.PixelMap | undefined, label: string): void {
    if (pixelMap === undefined) {
      return
    }
    pixelMap.release().then(() => {
      hilog.info(0x0000, 'StellariumArkUI', '[detail-media] released pixel map kind=%{public}s', label)
    }).catch((err: Error) => {
      hilog.warn(0x0000, 'StellariumArkUI', '[detail-media] pixel map release failed kind=%{public}s error=%{public}s',
        label, JSON.stringify(err))
    })
  }

  saveFileAs(sourcePath: string, fileName: string, suffixLabel: string, onDone: (result: MediaSaveResult) => void): void {
    const factory = this.contextFactory
    if (factory === null) {
      onDone(MediaSaveResult.Failed)
      return
    }
    const run = async (): Promise<void> => {
      try {
        const context = factory()
        const saveOptions = new picker.DocumentSaveOptions()
        saveOptions.newFileNames = [fileName]
        saveOptions.fileSuffixChoices = [suffixLabel]
        const selectedUris = await new picker.DocumentViewPicker(context).save(saveOptions)
        if (selectedUris.length === 0 || selectedUris[0].length === 0) {
          onDone(MediaSaveResult.Cancelled)
          return
        }
        await fileIo.copy(fileUri.getUriFromPath(sourcePath), selectedUris[0])
        onDone(MediaSaveResult.Saved)
      } catch (error) {
        hilog.error(0x0000, 'StellariumArkUI', 'Export file failed: %{public}s', String(error))
        onDone(MediaSaveResult.Failed)
      }
    }
    void run()
  }

  deleteFile(path: string): void {
    try {
      fileIo.unlinkSync(path)
    } catch (error) {
    }
  }

  // ── 对象模型渲染（M2-A）：worker 光栅化结果的像素图创建与 PNG 回退读回。 ──
  createPixelMapFromRgba(pixels: ArrayBuffer, width: number, height: number, label: string): Promise<image.PixelMap> {
    return image.createPixelMap(pixels, {
      size: { width: width, height: height },
      srcPixelFormat: image.PixelMapFormat.RGBA_8888,
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      alphaType: image.AlphaType.UNPREMUL,
      editable: false
    }).then((pixelMap: image.PixelMap) => {
      hilog.info(0x0000, 'StellariumArkUI',
        '[detail-model] render pixel map created kind=%{public}s bytes=%{public}s',
        label, pixelMap.getPixelBytesNumber().toString())
      return pixelMap
    })
  }

  readPixelMapPixels(pixelMap: image.PixelMap, buffer: ArrayBuffer, label: string): void {
    try {
      pixelMap.readPixelsToBufferSync(buffer)
    } catch (err) {
      hilog.warn(0x0000, 'StellariumArkUI', '[detail-model] pixel readback failed kind=%{public}s error=%{public}s',
        label, JSON.stringify(err))
      throw err as Error
    }
  }

  // ── 屏幕录制（M1-B 子组②）：NAPI 细节收在本具名适配器，控制器只依赖端口。 ──
  private screenCapture?: media.AVScreenCaptureRecorder
  private screenCaptureFile?: fileIo.File

  screenVideoDir(): string {
    const factory = this.contextFactory
    if (factory === null) {
      return ''
    }
    return factory().filesDir + '/recordings/videos'
  }

  makeDir(path: string): void {
    // 目标目录已存在时 fileIo.mkdirSync(path, true) 仍会抛 EEXIST("File exists")，
    // 未捕获会中断整个屏幕录制启动（表现为“没有生成有效视频”）。建目录只需 best-effort。
    try { fileIo.mkdirSync(path, true) } catch (error) {
      hilog.warn(0x0000, 'StellariumArkUI', 'makeDir failed path=%{public}s err=%{public}s', path, String(error))
    }
  }

  fileSize(path: string): number {
    try {
      return fileIo.statSync(path).size
    } catch (error) {
      return 0
    }
  }

  hasActiveScreenCapture(): boolean {
    return this.screenCapture !== undefined
  }

  private closeScreenCaptureFile(): void {
    if (this.screenCaptureFile !== undefined) {
      try { fileIo.closeSync(this.screenCaptureFile.fd) } catch (error) {}
      this.screenCaptureFile = undefined
    }
  }

  async beginScreenCapture(filePath: string, onState: (state: ScreenCaptureState) => void, onError: (message: string) => void): Promise<void> {
    this.screenCaptureFile = fileIo.openSync(filePath,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
    const displayInfo = display.getDefaultDisplaySync()
    const frameWidth = Math.max(64, Math.floor(displayInfo.width / 64) * 64)
    const frameHeight = Math.max(2, Math.floor(displayInfo.height / 2) * 2)
    const recorder = await media.createAVScreenCaptureRecorder()
    this.screenCapture = recorder
    recorder.on('stateChange', (state: media.AVScreenCaptureStateCode) => {
      if (state === media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_STARTED) {
        onState(ScreenCaptureState.Started)
      } else if (state === media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_CANCELED) {
        onState(ScreenCaptureState.Canceled)
      } else if (state === media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_STOPPED_BY_USER) {
        onState(ScreenCaptureState.StoppedByUser)
      } else if (state === media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_INTERRUPTED_BY_OTHER ||
        state === media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_STOPPED_BY_CALL ||
        state === media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_STOPPED_BY_USER_SWITCHES) {
        onState(ScreenCaptureState.Interrupted)
      }
    })
    recorder.on('error', (error) => {
      hilog.error(0x0000, 'StellariumArkUI', 'Screen capture error: %{public}s', String(error))
      onError('录屏失败')
    })
    const file = this.screenCaptureFile
    const config: media.AVScreenCaptureRecordConfig = {
      fd: file.fd,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      videoBitrate: 10000000,
      displayId: displayInfo.id,
      fillMode: media.AVScreenCaptureFillMode.PRESERVE_ASPECT_RATIO,
      preset: media.AVScreenCaptureRecordPreset.SCREEN_RECORD_PRESET_H264_AAC_MP4
    }
    await recorder.init(config)
    await recorder.startRecording()
  }

  async stopScreenCapture(): Promise<void> {
    const recorder = this.screenCapture
    this.screenCapture = undefined
    if (recorder !== undefined) {
      try { recorder.off('stateChange') } catch (error) {}
      try { recorder.off('error') } catch (error) {}
      try { await recorder.stopRecording() } catch (error) {}
      try { await recorder.release() } catch (error) {}
    }
    this.closeScreenCaptureFile()
  }

  async releaseScreenCapture(): Promise<void> {
    const recorder = this.screenCapture
    this.screenCapture = undefined
    if (recorder !== undefined) {
      try { recorder.off('stateChange') } catch (error) {}
      try { recorder.off('error') } catch (error) {}
      try { await recorder.release() } catch (error) {}
    }
    this.closeScreenCaptureFile()
  }

  async saveVideoToGallery(path: string): Promise<boolean> {
    const factory = this.contextFactory
    if (factory === null) {
      return false
    }
    try {
      const context = factory()
      const helper = photoAccessHelper.getPhotoAccessHelper(context)
      const request = photoAccessHelper.MediaAssetChangeRequest.createVideoAssetRequest(
        context, fileUri.getUriFromPath(path))
      await helper.applyChanges(request)
      return true
    } catch (error) {
      hilog.error(0x0000, 'StellariumArkUI', 'Save video to gallery failed: %{public}s', String(error))
      return false
    }
  }
}

// 宿主 → PlatformPort 的具名适配器（PLAN §15.1 AB2-0c / M1-A）。把 systemShare / pasteboard / TTS
// 逐字转发给平台服务。TTS 当前 SDK 未集成语音合成，speak 实现为不发声（与宿主原注释一致）。
class HostPlatformPort implements PlatformPort {
  private contextFactory: (() => common.UIAbilityContext) | null = null
  private expandedFactory: (() => boolean) | null = null

  configure(contextFactory: () => common.UIAbilityContext, expandedFactory: () => boolean): void {
    this.contextFactory = contextFactory
    this.expandedFactory = expandedFactory
  }

  async writeClipboardText(text: string): Promise<boolean> {
    const result = await writeClipboardText(text)
    return result.ok
  }

  shareFile(
    path: string,
    utdType: string,
    title: string,
    description: string,
    anchorId: string,
    expanded: boolean,
    onDone: (ok: boolean) => void,
  ): void {
    const factory = this.contextFactory
    if (factory === null) {
      onDone(false)
      return
    }
    const run = async (): Promise<void> => {
      try {
        const context = factory()
        const data = new systemShare.SharedData({
          utd: utdType,
          uri: fileUri.getUriFromPath(path),
          title: title,
          description: description
        })
        const controller = new systemShare.ShareController(data)
        const options: systemShare.ShareControllerOptions = expanded ? { anchor: anchorId } : {}
        await controller.show(context, options)
        onDone(true)
      } catch (error) {
        hilog.error(0x0000, 'StellariumArkUI', 'Share failed: %{public}s', String(error))
        onDone(false)
      }
    }
    void run()
  }

  speak(text: string): void {
    // 基础 SDK 无 @kit.CoreSpeechKit；此处保留槽位，暂不发声（朗读文本由 SpeechService 生成后显示）。
  }
}

// 宿主 → SensorPort 的具名适配器（PLAN §15.1 AB2-0b / M1-A）。转发 sensor.* 查询/订阅/退订。
class HostSensorPort implements SensorPort {
  // 控制器只给 label（不 import sensor 命名空间），适配器在此映射到 SensorId。
  private static sensorIdForLabel(label: string): sensor.SensorId {
    if (label === 'gravity') return sensor.SensorId.GRAVITY
    if (label === 'magnetic-field') return sensor.SensorId.MAGNETIC_FIELD
    if (label === 'orientation-fallback') return sensor.SensorId.ORIENTATION
    return sensor.SensorId.ROTATION_VECTOR
  }

  probeSensor(label: string): SensorProbeInfo | undefined {
    const sensorType = HostSensorPort.sensorIdForLabel(label)
    try {
      const info = sensor.getSingleSensorSync(sensorType)
      hilog.info(0x0000, 'StellariumArkUI', '[gyro-probe] sensor=%{public}s supported=true name=%{public}s vendor=%{public}s',
        label, info.sensorName, info.vendorName)
      return { sensorName: info.sensorName, vendorName: info.vendorName }
    } catch (error) {
      hilog.warn(0x0000, 'StellariumArkUI', '[gyro-probe] sensor=%{public}s supported=false error=%{public}s', label, JSON.stringify(error))
      return undefined
    }
  }

  subscribeRotationVector(callback: (data: sensor.RotationVectorResponse) => void, intervalNs: number): void {
    sensor.on(sensor.SensorId.ROTATION_VECTOR, callback, { interval: intervalNs })
  }

  unsubscribeRotationVector(callback: (data: sensor.RotationVectorResponse) => void): void {
    sensor.off(sensor.SensorId.ROTATION_VECTOR, callback)
  }

  subscribeOrientation(callback: (data: sensor.OrientationResponse) => void, intervalNs: number): void {
    sensor.on(sensor.SensorId.ORIENTATION, callback, { interval: intervalNs })
  }

  unsubscribeOrientation(callback: (data: sensor.OrientationResponse) => void): void {
    sensor.off(sensor.SensorId.ORIENTATION, callback)
  }

  subscribeGravity(callback: (data: sensor.GravityResponse) => void, intervalNs: number): void {
    sensor.on(sensor.SensorId.GRAVITY, callback, { interval: intervalNs })
  }

  unsubscribeGravity(callback: (data: sensor.GravityResponse) => void): void {
    sensor.off(sensor.SensorId.GRAVITY, callback)
  }

  subscribeMagneticField(callback: (data: sensor.MagneticFieldResponse) => void, intervalNs: number): void {
    sensor.on(sensor.SensorId.MAGNETIC_FIELD, callback, { interval: intervalNs })
  }

  unsubscribeMagneticField(callback: (data: sensor.MagneticFieldResponse) => void): void {
    sensor.off(sensor.SensorId.MAGNETIC_FIELD, callback)
  }
}

// 宿主 → LocationPort 的具名适配器（PLAN §15.12）。承载 abilityAccessCtrl / geoLocationManager /
// @ohos.data.preferences 三处 NAPI，使 LocationController 不 import NAPI（§15.7 规则 1）。
// UI 上下文工厂经 configure 惰性注入（适配器在字段初始化时构造，此时 getUIContext 尚不可用）。
class HostLocationPort implements LocationPort {
  private contextFactory: (() => common.UIAbilityContext) | null = null

  configure(contextFactory: () => common.UIAbilityContext): void {
    this.contextFactory = contextFactory
  }

  private context(): common.UIAbilityContext {
    const factory = this.contextFactory
    if (factory === null) {
      throw new Error('HostLocationPort not configured')
    }
    return factory()
  }

  async requestLocationPermissions(): Promise<boolean> {
    const context = this.context()
    const atManager = abilityAccessCtrl.createAtManager()
    const permissions: Array<Permissions> = [
      'ohos.permission.APPROXIMATELY_LOCATION',
      'ohos.permission.LOCATION'
    ]
    const permissionResult = await atManager.requestPermissionsFromUser(context, permissions)
    return permissionResult.authResults.some((result: number) => result === 0)
  }

  async getCurrentLocation(): Promise<LocationFix> {
    const current = await geoLocationManager.getCurrentLocation({
      priority: geoLocationManager.LocationRequestPriority.ACCURACY,
      scenario: geoLocationManager.LocationRequestScenario.DAILY_LIFE_SERVICE,
      maxAccuracy: 2000,
      timeoutMs: 5000
    })
    return {
      latitude: current.latitude,
      longitude: current.longitude,
      altitude: Number.isFinite(current.altitude) ? current.altitude : 0
    }
  }

  async readObserverLocation(): Promise<string> {
    try {
      const store = await preferences.getPreferences(this.context(), LOCATION_STORE)
      return (await store.get('location', '')) as string
    } catch (e) {
      return ''
    }
  }

  async writeObserverLocation(json: string): Promise<void> {
    try {
      const store = await preferences.getPreferences(this.context(), LOCATION_STORE)
      await store.put('location', json)
      await store.flush()
    } catch (e) {
      hilog.warn(0xD002, 'Stellarium', 'save observer location failed: %{public}s', String(e))
    }
  }
}

@Component
export struct WindowNativeNode {
  @State private createInfo: WindowNativeNodeCreateInfo | undefined = undefined
  @Watch('onPrivacyNativeStartupAllowedChanged')
  @StorageLink('stellariumPrivacyNativeStartupAllowed')
  private privacyNativeStartupAllowed: boolean = false
  @StorageLink('stellariumScreenSafeTopPixels')
  private screenSafeTopPixels: number = 0
  @Watch('onCliUiEventChanged')
  @StorageLink('stellariumCliUiEvent')
  private cliUiEvent: string = ''
  private privacyPageStartupStarted: boolean = false
  private lastCliUiEventId: string = ''
  @State private isExpandedLayout: boolean = false
  @State private isFoldHoverLayout: boolean = false
  @State private isFoldableDevice: boolean = false
  @State private isFoldTabletLayout: boolean = false
  @State private foldStatusValue: number = 0
  @State private foldDisplayModeValue: number = 0
  @State private foldAngleValue: number = 180
  // Some emulator and device transitions report a fold status before the first
  // usable angle sample. Keep that stale 180-degree startup value from forcing
  // a half-folded device back into the tablet shell.
  @State private hasUsableFoldAngle: boolean = false
  @State private responsiveLayoutMode: string = 'compact'
  @State private activePanel: string = 'object'
  @State private panelVisible: boolean = false
  @State private panelNavigationDepth: number = 0
  private panelNavigationStack: string[] = []
  private lastPanelBackAt: number = 0
  @State private searchStore: SearchStore = new SearchStore()
  @State private objectDetailStore: ObjectDetailStore = new ObjectDetailStore()
  @State private gyroStore: GyroStore = new GyroStore()
  @State private wutStore: WutStore = new WutStore()
  @State private astroStore: AstroStore = new AstroStore()
  @State private objectMediaStore: ObjectMediaStore = new ObjectMediaStore()
  @State private tools: ToolsStore = new ToolsStore()
  // searchHistory 已下沉 state/SearchStore.ets（§14 B3-3，单一持有者）。
  private searchPanelScroller: Scroller = new Scroller()
  // PLAN §15.1 / M1-A 端口适配器（宿主具名实现，aboutToAppear 里 configure 后注入服务层）。
  private hostCommandPort: HostCommandPort | null = null
  private hostMediaPort: HostMediaPort = new HostMediaPort()
  private hostPlatformPort: HostPlatformPort = new HostPlatformPort()
  private hostSensorPort: HostSensorPort = new HostSensorPort()
  // PLAN §15.12：位置域端口适配器（aboutToAppear 里 configure UI 上下文）。
  private hostLocationPort: HostLocationPort = new HostLocationPort()
  // §15.12：位置域控制器（惰性构造；NAPI 经 LocationPort，跨域写经 LocationHostHooks）。
  private locationControllerImpl: LocationController | null = null
  // M1-A：启动桥服务（惰性构造，持有跨域 store 引用与宿主生命周期 hooks）。
  private startupBridgeImpl: StartupBridge | null = null
  // M1-B 子组①：传感器/陀螺仪控制器（惰性构造；注入 SensorPort/CommandPort/store 与宿主 hooks）。
  private sensorControllerImpl: SensorController | null = null
  // M1-B 子组②：录制/回放/录屏控制器（惰性构造；recordBuffer 属 §2.7.1 保留字段，经 hooks 读写）。
  private recordingControllerImpl: RecordingController | null = null
  // M2-A：对象检查器三维模型渲染器（惰性构造；逐帧/草稿字段留控制器，可观测子集在 ObjectMediaStore）。
  private objectModelRendererImpl: ObjectModelRenderer | null = null
  // M3-1：天空输入控制器骨架（惰性构造；鼠标/键盘/滚轮轴/点按序列/惯性方法 + 16 个草稿字段）。
  private skyInputControllerImpl: SkyInputController | null = null
  // 陀螺仪观测时，若已选目标落在视场外，在安全边缘给出方向提示。
  // 坐标本身不参与渲染，只有这三个 @State 会驱动提示箭头刷新。
  // The compact phone quick controls are tapped through a transparent layer
  // above Qt, so keep their pressed appearance in explicit ArkUI state.
  @State private compactQuickPressed: string = ''
  // 富化的天体详情（独立浮动窗口，不切换当前菜单；默认收起，可展开）
  // infoWinVisible / infoWinExpanded / informationMode / informationCustomMask /
  // informationSettingPending / infoLevel 已下沉 state/InfoWindowStore.ets（review §2.7）。
  @State private infoWindowStore: InfoWindowStore = new InfoWindowStore()
  @State private fullInspectorRequested: boolean = false
  // bottomCardIndex 已并入 state/ObjectDetailStore.ets（review §2.7，2026-10-04）。
  @State private compactPanelSnapRatio: number = 0.6
  @State private compactPanelDragOffsetY: number = 0
  private lastInfoWinCloseMs: number = 0
  private dismissedObjectName: string = ''
  @State private panelContentKey: number = 0
  // languageRefreshSerial 已随 §14 B3-1 搬入 state/LanguageStore.ets（语言刷新代际单一持有者）。
  private languageSwitchTimer: number = -1
  @State private cardOffsetX: number = 0
  @State private cardOffsetY: number = 0
  @State private objectDetailConnectorX: number = 0
  @State private objectDetailConnectorY: number = 0
  @State private objectDetailConnectorLength: number = 0
  @State private objectDetailConnectorAngle: number = 0
  @State private objectDetailConnectorEndX: number = 0
  @State private objectDetailConnectorEndY: number = 0
  @State private objectDetailConnectorTargetX: number = 0
  @State private objectDetailConnectorTargetY: number = 0
  @State private objectDetailConnectorTargetOnScreen: boolean = false
  @State private objectDetailContentOpacity: number = 1
  @State private objectDetailContentTranslateX: number = 0
  private objectCardDragging: boolean = false
  private objectCardPlacementPending: boolean = false
  private objectDetailTabTransitionId: number = 0
  private objectCardDragStartX: number = 0
  private objectCardDragStartY: number = 0
  private objectCardDragStartOffsetX: number = 0
  private objectCardDragStartOffsetY: number = 0
  private objectInspectorMediaRequestPath: string = ''
  private objectInspectorMediaResolvedRequestPath: string = ''
  private objectInspectorMediaResolvedPath: string = ''
  private objectInspectorMediaResolutionComplete: boolean = false
  private objectInspectorMediaWarmupTimer: number = 0
  private objectInspectorMediaDecodeGeneration: number = 0
  private bodyDetailWarmupTimer: number = 0
  private bodyDetailWarmupIndex: number = 0
  private bodyDetailWarmupPending: Array<string> = []
  private skyTextureStatusTimer: number = 0
  private skyTextureStatusDelayTimer: number = 0
  private skyTextureStatusPolls: number = 0
  private skyTextureStatusSlow: boolean = false
  private objectInspectorProceduralKey: string = ''
  private objectInspectorProceduralParticles: number[][] = []
  // objectInspectorModel* 的 22 个逐帧/草稿字段（纹理三量 + 环纹理三量、旋转/缩放采样、
  // 渲染代际/挂起/播放中标志、一次性防抖定时器）已随 M2-A 搬入 capability/ObjectModelRenderer.ets，
  // 刻意不入被观察 store（§13.3：逐帧写入入 store 会造成重渲染风暴）。
  private objectDetailScroller: Scroller = new Scroller()
  // 音频域状态已下沉 state/AudioStore.ets（review §2.7：Prop 风格 → Store 风格）。
  // 程序化音乐默认开（打开应用即播放），可静音并持久化。
  @State private audioStore: AudioStore = new AudioStore()
  private fpsTimer: number = 0
  private stateRefreshTimer: number = -1
  private stateRefreshRequestPending: boolean = false
  private stateRefreshQueued: boolean = false
  private lastMusicToggle: number = 0
  /** 主界面 Dock 右上的常驻时钟文本（HH:mm），面板未打开时显示。 */
  @State private dockClockText: string = ''
  /** Dock 时钟的独立轻量刷新定时器（1s），不并入时间面板 125ms 高频刷新。 */
  private dockClockTimer: number = 0
  /** Current speed-step index into TIME_SPEED_STEPS. */
  @State private timeStore: TimeStore = new TimeStore()
  // 原生命令在下一渲染帧才生效。此窗口内忽略轮询到的旧速率，避免按钮
  // 刚显示“-2x”又被上一帧的“-10x”短暂盖回去而产生闪烁。
  /** 时间轴相对真实当前时刻的偏移秒数（0=此刻，负=过去，正=未来）*/
  // 时间轴的中心 JD。它不是系统时间的固定快照：模拟时间接近边界时会
  // 重新定锚到当前模拟时间，避免快进后游标永远卡在两端。
  // 时间转轴：顶部选择要调整的字段，底部同一条刻度轴只控制该字段。
  @State private timeWheelStore: TimeWheelStore = new TimeWheelStore()

  // JD/MJD are edited explicitly, so the periodic native time poll does not
  // replace a partially typed number while the user is still entering it.
  @State private julianStore: JulianDateStore = new JulianDateStore()
  private julianDateApplyInFlight: boolean = false
  private timeMarkLoading: boolean = false
  // manualYear/Month/Day/Hour/Minute 已并入 state/TimeStore.ets（review §2.7）。
  // selectedLanguage / languageRevision 已下沉 state/LanguageStore.ets（review §2.7）。
  @State private languageStore: LanguageStore = new LanguageStore()
  @StorageLink('i18nLang') private i18nLang: string = I18n.systemLanguage()
  @State private bridgeSyncStarted: boolean = false
  @State private nightModeStore: NightModeStore = new NightModeStore()
  private pendingNightMode: boolean | undefined = undefined
  private pendingNightModeUntilMs: number = 0
  @State private pickedDate: Date = new Date()
  @State private locationText: string = '--'
  @State private coordinateText: string = '--'
  @State private altitudeText: string = '--'
  // 位置选择器状态簇（picker 坐标/名称/状态、层级选择、地图渲染尺寸、时区、选点方式 + 层级翻译纯计算）
  // 随 locationPickerPanel 组件化迁移到 LocationPickerStore（Phase 3aj）。
  @State private locationPickerStore: LocationPickerStore = new LocationPickerStore()
  // mapTouchStartX/Y/Moved 已随 §15.12 地图触摸下沉 panels/location/LocationPickerPanel.ets。
  // 观测/会话工具区块状态（观测星球切换、指星笔、手表陀螺仪模拟、今晚天象）—— Phase 3as 组件化。
  @State private sessionToolStore: SessionToolStore = new SessionToolStore()
  @State private watchLastSend: number = 0
  // sessionJson / sessionExportSig / sessionHint 已并入 state/SessionToolStore.ets（review §2.7）。
  @State private canUseDistributed: boolean = false

  @State private locationStore: LocationStore = new LocationStore()
  @State private layerStore: LayerStore = new LayerStore()
  @State private layerViewStore: LayerViewStore = new LayerViewStore()
  @State private fovText: string = '--'
  @State private trackingText: string = 'Off'
  @State private trackingRequestPending: boolean = false
  private trackingRequestSerial: number = 0
  private trackingStateIgnoreUntilMs: number = 0
  @State private skyWidth: number = 1
  @State private skyHeight: number = 1
  @State private panelWidth: number = 336
  @State private panelMaxHeight: number = 660
  // 离屏幕边框的安全留白(vp)：约 0.7cm，避免 UI 贴边
  private readonly EDGE_MARGIN: number = 44
  // 观测列表域状态已下沉 state/ObservingListStore.ets（review §2.7：Prop 风格 → Store 风格）。
  @State private obsListStore: ObservingListStore = new ObservingListStore()
  @State private isLoading: boolean = true
  @State private splashGone: boolean = false
  private startupViewportCheckedAt: number = 0
  @State private viewTab: number = 0  // View面板子标签索引
  @State private configTab: number = 0  // 统一设置面板子标签索引；默认显示主设置
  @State private timeSettingsStore: TimeSettingsStore = new TimeSettingsStore()
  // configDitheringMode 已并入 state/ViewSettingsStore.ets（review §2.7）。
  @State private ephemerisStore: EphemerisStore = new EphemerisStore()
  // informationMode / informationCustomMask / informationSettingPending 已下沉 state/InfoWindowStore.ets（review §2.7）。
  @State private timeSettingsPending: boolean = false
  @State private deltaTStore: DeltaTStore = new DeltaTStore()
  // presetSkyTime 已并入 state/TimeSettingsStore.ets（review §2.7）。
  // 视图导航设置（9 字段）已下沉 state/NavigationSettingsStore.ets（review §2.7）。
  @State private navigationStore: NavigationSettingsStore = new NavigationSettingsStore()
  // Open AstroCalc on the observation-first view: it needs no selected object
  // and immediately gives a useful answer for the current location and date.
  private astroTransitionId: number = 0
  private astroRequestedTab: number = -1
  private astroPanelScroller: Scroller = new Scroller()
  // 视图交互偏好（autoZoomResets / useMetricUnits / viewLock / verticalClamp / flatHorizon，
  // 共 5 字段）已下沉 state/ViewSettingsStore.ets（review §2.7）。
  // 说明：竖直限位默认开（天顶↔天底间拖动不翻转）；viewLock 开启后仍可自由拖动、松手记录位置；
  // flatHorizon 限制最大视场角、保持地平线平直。
  @State private viewSettingsStore: ViewSettingsStore = new ViewSettingsStore()
  // 桥接数据
  // rtsCalendarStartYear/Month/Day 已并入 state/AstroStore.ets（review §2.7）。
  private planetPositionsRequestSequence: number = 0
  // graphStartYear/Month/Day 已并入 state/AstroStore.ets（review §2.7）。
  private graphTargetPickerActive: boolean = false
  private rtsTargetPickerActive: boolean = false
  private ephemerisTargetPickerActive: boolean = false
  // eclipseStartYear/Month/Day 已并入 state/AstroStore.ets（review §2.7，食相属天文派生域）。
  private astroContextTimer: number = 0
  // 月相 / 天文计算上下文的请求态（moonPhaseRequestId / moonPhaseLoadingDays /
  // astroContextRequestId / astroContextRequestPending）随加载器下沉 state/AstroStore.ets（§14 B3-2）。
  // 大气观测辅助（atmoPressure / atmoTemperature / atmoExtinction / refractionOn，共 4 字段）
  // 已下沉 state/AtmosphereStore.ets（review §2.7）。
  @State private atmosphereStore: AtmosphereStore = new AtmosphereStore()
  // 星文化制作器向导状态（Phase 3am，见 state/SkyCultureMakerStore.ets）
  @State private skyCultureMakerStore: SkyCultureMakerStore = new SkyCultureMakerStore()
  private skyCultureMakerArtworkPreviewPath: string = ''
  private skyCultureMakerArtworkDecodeGeneration: number = 0
  private skyCultureMakerArtworkTouchStartX: number = 0
  private skyCultureMakerArtworkTouchStartY: number = 0
  private skyCultureMakerArtworkTouchMoved: boolean = false
  private skyCultureMakerSaveTimer: number = 0
  // 星文化只读详情视图状态（Phase 3am，见 state/SkyCultureViewStore.ets）
  @State private skyCultureViewStore: SkyCultureViewStore = new SkyCultureViewStore()
  @State private skyCultureArtStates: Record<string, string> = {}
  @State private skyCultureArtThumbnailPixelMaps: Record<string, image.PixelMap> = {}
  private skyCultureArtDecodeGeneration: number = 0
  private skyCultureArtThumbnailGeneration: number = 0
  private skyCultureArtDecodeTimer: number = 0
  private skyCultureArtStatusFlushTimer: number = 0
  private skyCultureArtPendingStatuses: Record<string, string> = {}
  // 星空文化面板设置状态簇（Phase 4g，见 state/SkyCultureSettingsStore.ets）
  @State private skyCultureSettingsStore: SkyCultureSettingsStore = new SkyCultureSettingsStore()
  private skyCultureMapContextSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private skyCultureMapContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.skyCultureMapContextSettings)
  private skyCultureMapRenderWidth: number = 0
  private skyCultureMapRenderHeight: number = 0
  // 极轴镜域状态已下沉 state/PolarScopeStore.ets（review §2.7：Prop 风格 → Store 风格）。
  // 极轴镜几何与引擎/定时器字段（polarScopeRestoreState / Transition* / RequestPending / Timer /
  // DataRequestId）仍留在宿主。
  @State private polarScopeStore: PolarScopeStore = new PolarScopeStore()
  private polarScopeRestoreState: string = ''
  private polarScopeTransitionPending: boolean = false
  private polarScopeTransitionId: number = 0
  @State private pluginStore: PluginStore = new PluginStore()
  private pluginFeatureLoading: string[] = []
  @State private nebulaTextureStore: NebulaTextureStore = new NebulaTextureStore()
  // angleMeasureRequestId 已随 §14 B3-1 搬入 ToolsStore 的 `seq`（与 toggleAngleMeasure 同片）。
  // 航海星域状态已下沉 state/NavStarsStore.ets（review §2.7：Prop 风格 → Store 风格）。
  // §14 B3-1：loadNavStars / setNavStarsSetting（含 applyNavStarsSetting）及其请求序号
  // navStarsLoadRequestId / navStarsMutationId 已同片搬入 NavStarsStore（宿主零副本）。
  @State private navStarsStore: NavStarsStore = new NavStarsStore()
  @State private landscapeDetailOpen: boolean = false
  // infoLevel 已下沉 state/InfoWindowStore.ets（review §2.7）。
  // 新增面板控制
  @State private planetLabels: boolean = false
  private applicationInForeground: boolean = true
  // gyroPausedForBackground 已随 M1-B 子组① 搬入 capability/SensorController.ets。
  // The gyro control itself becomes a live compass while it is enabled.
  // liveMode 已并入 state/ViewSettingsStore.ets（review §2.7）。
  @State private currentFovText: string = '--'
  @State private viewCoordinatePrimaryText: string = '--'
  @State private viewCoordinateSecondaryText: string = '--'
  @State private viewCoordinateOffsetX: number = 0
  @State private viewCoordinateOffsetY: number = 0
  private viewCoordinateDragging: boolean = false
  private viewCoordinateDragStartX: number = 0
  private viewCoordinateDragStartY: number = 0
  private viewCoordinateDragStartOffsetX: number = 0
  private viewCoordinateDragStartOffsetY: number = 0
  private viewCoordinateSnapshot: StellariumBridgeResponse = {}
  private viewCoordinateTimer: number = 0
  private viewCoordinateRequestPending: boolean = false
  /** 观测地 UTC 偏移（小时），由 getState 的 timeText-jd 差值校准，供轻量时间刷新使用 */
  private utcOffsetHours: number = 8
  @State private fovSliderValue: number = 60
  @State private currentProjection: string = 'ProjectionPerspective'
  // uiLocked 已并入 state/ViewSettingsStore.ets（review §2.7，2026-10-04）。
  @State private panelIdleOpacity: number = 1.0
  @State private panelIdleGlass: boolean = false
  @State private panelRouteOpacity: number = 1.0
  @State private panelRouteOffsetX: number = 0
  @State private panelPresentationOpacity: number = 1.0
  @State private panelPresentationOffsetY: number = 0
  @State private viewTabContentOpacity: number = 1.0
  @State private viewTabContentOffsetX: number = 0
  @State private configTabContentOpacity: number = 1.0
  @State private configTabContentOffsetX: number = 0
  @State private panelOffsetX: number = 0
  @State private panelOffsetY: number = 0
  private panelDataLoadTimer: number = -1
  private viewTabTransitionId: number = 0
  private configTabTransitionId: number = 0
  private panelRouteDirection: number = 1
  private widePanelScroller: Scroller = new Scroller()
  private compactPanelScroller: Scroller = new Scroller()
  private scriptListScroller: Scroller = new Scroller()
  @State private bookmarkStore: BookmarkStore = new BookmarkStore()
  // 望远镜/目镜配置（Oculars）：状态与加载请求序号（seq）均已迁入 TelescopeStore（Phase 3al / §14 B1-1）
  @State private telescopeStore: TelescopeStore = new TelescopeStore()
  // 视图/叠层域（指针坐标插件 + 视图中心坐标叠层 + 天体详情指向线）：状态已迁入 OverlayStore（Phase 3an）
  @State private overlayStore: OverlayStore = new OverlayStore()
  // 相机拼接视场域状态已下沉 state/MosaicStore.ets（review §2.7：Prop 风格 → Store 风格）。
  // 加载器 loadMosaicCamera（§14 B1-4）已随桥注入搬入 store；写回动作 setMosaicCamera 仍在宿主。
  @State private mosaicStore: MosaicStore = new MosaicStore()
  @State private equationOfTimeStore: EquationOfTimeStore = new EquationOfTimeStore()
  // 古天文辅助线域状态已下沉 state/ArchaeoStore.ets（review §2.7：Prop 风格 → Store 风格）。
  // 加载器 loadArchaeoLines（§14 B1-4）已随桥注入搬入 store；写回请求序号 archaeoMutationId 仍由宿主自持（见下方）。
  @State private archaeoStore: ArchaeoStore = new ArchaeoStore()
  // 卫星（Satellites）
  // 卫星域状态已下沉 state/SatelliteStore.ets（review §2.7：Prop 风格 → Store 风格）。
  // SatellitesPanel 改为 @ObjectLink 订阅该 store，刷新粒度不再落在宿主整棵树上。
  // 下面两个"资源目录健康"字段与星表域共用、且不是卫星面板的入参，故仍留在宿主。
  @State private satelliteStore: SatelliteStore = new SatelliteStore()
  // 脚本/录制/视频导出域的面板可见状态同样已下沉（review §2.7 第二片）。
  // recordBuffer 与脚本播放引擎字段刻意留在宿主，理由见 state/ScriptStore.ets 头注。
  @State private scriptStore: ScriptStore = new ScriptStore()
  // 小簇批处理（review §2.7 第三批）：scenery3d / catalogs / meteorShowers / commandConsole。
  // 各簇的非面板字段（scenery3dCurrentId、catalogHealthLoaded、catalogManifestPresent）留宿主。
  @State private sceneryStore: SceneryStore = new SceneryStore()
  @State private catalogStore: CatalogStore = new CatalogStore()
  @State private meteorStore: MeteorStore = new MeteorStore()
  @State private commandStore: CommandStore = new CommandStore()
  @State private catalogHealthLoaded: boolean = false
  @State private catalogManifestPresent: boolean = false
  // starCatalogHealth 与 objectCatalogCategories 已并入 state/CatalogStore.ets（review §2.7）；
  // catalogHealthLoaded / catalogManifestPresent 仍留宿主（与卫星面板共用）。
  // §14 B3-4：satelliteListRequestId / satelliteLoadTimer / satelliteLoadIncludeSources /
  // satelliteFlagMutationId / satelliteListElapsedMs 已随 loadSatellites 搬入 SatelliteStore。
  private satellitePanelScroller: Scroller = new Scroller()
  private satelliteGroupScroller: Scroller = new Scroller()
  private equationOfTimeMutationId: number = 0
  private archaeoMutationId: number = 0
  // 流星雨（MeteorShowers）请求序号 meteorShowersLoadRequestId 已随 §14 B3-1 搬入 MeteorStore 的 `seq`。
  // 三维地景：直接读取原版 scenery3d.ini 与语言描述文件
  @State private scenery3dCurrentId: string = ''
  @State private skyTouchFeedback: boolean = false
  @State private skyTouchX: number = 0   // 触摸点窗口坐标(px)，供反馈圈跟随手指
  @State private skyTouchY: number = 0
  @State private skyTouchFeedbackMulti: boolean = false
  @State private skyTouchX2: number = 0
  @State private skyTouchY2: number = 0
  // §14 B3-4：lx200LivePositionTimer / lx200LivePositionRequestPending /
  // lx200LivePositionRequestId 已随 live-position 定时器簇整体搬入 TelescopeStore。
  @State private actionHint: ResourceStr = ''
  // ===== 脚本录制 / 回放（39）=====
  @State private recordBuffer: Array<RecordCmd> = []
  // speechStatus / guideState 已并入 state/GuideStore.ets（review §2.7，2026-10-04）。
  // M1-A 子组④：guidePlayer / guideTimer / guideGyroWasEnabled / guidePanelWasVisible /
  // guideLastRequest / guideLastResult 随 executeGuideRequest 一并迁入 GuideStore（自持定时器）。
  @State private guideStore: GuideStore = new GuideStore()
  // ===== 视频帧序列录制（#40）=====
  // lastRecordKey / lastRecordTime / recordStartedAt / recordPausedAt / recordPausedTotal 已随
  // M1-B 子组② 搬入 capability/RecordingController.ets。
  private scriptStatusTimer: number = -1
  private scriptStatusRequestPending: boolean = false
  private scriptCaptionsRequestPending: boolean = false
  private scriptStartGraceUntil: number = 0
  // replayTimer / replayStartedAt / replayPauseStartedAt / replayPausedTotal / replayIndex /
  // replayCommands / recordViewCheckpointTimer 已随 M1-B 子组② 搬入 RecordingController。
  // §14 B3-4：videoStateTimer 已随影片状态轮询收口搬入 ScriptStore。
  // screenCapture / screenCaptureFile 已随 M1-B 子组② 移入顶层 HostMediaPort 适配器。
  private scriptControlDragging: boolean = false
  private scriptControlDragStartX: number = 0
  private scriptControlDragStartY: number = 0
  private scriptControlDragStartOffsetX: number = 0
  private scriptControlDragStartOffsetY: number = 0

  private hintTimer: number = 0
  // 离线搜索分块扫描草稿（locSearchRequestId / locationSearchScan* / locationSearchLastPublishMs）
  // 已随 §15.12 离线搜索三法下沉 state/LocationStore.ets。
  private searchSuggestionTimer: number = -1
  private panelIdleTimer: number = -1
  private lastOverlayActivityMs: number = 0

  private resetPanelIdle(): void {
    if (this.panelIdleTimer >= 0) {
      clearTimeout(this.panelIdleTimer)
    }
    this.panelIdleOpacity = 1.0
    this.panelIdleGlass = false
    this.panelIdleTimer = setTimeout(() => {
      if (!this.viewSettingsStore.uiLocked) {
        this.panelIdleOpacity = 0.88
        this.panelIdleGlass = true
      }
      this.panelIdleTimer = -1
    }, 5000)
  }

  private notePanelTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down || event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.resetPanelIdle()
    }
  }

  // 目标详情自动刷新：选中天体后每 180ms 重新拉一次坐标，让“地平坐标”随地球自转实时变化。
  // detailTimer 为 setInterval 句柄；detailRefreshing 防重入；detailRefreshGuard 是兜底定时器，
  // 因为 callNativeWhenReady 在放弃轮询时【不】回调 onOk，必须靠它复位，否则会卡死不再刷新。
  private detailTimer: number = 0
  private detailRefreshing: boolean = false
  private detailRefreshGuard: number = 0
  private objectDetailConnectorTimer: number = 0
  @State private objectDetailConnectorAnimateGeometry: boolean = false
  private objectDetailConnectorAnimationTimer: number = 0
  private objectDetailConnectorLastPanelVisible: boolean = false
  private objectDetailConnectorLastActivePanel: string = ''
  private objectDetailConnectorLastClippedByUi: boolean = false
  private foregroundRefreshPaused: boolean = false
  // Structured details are loaded after a new target is drawn. Keeping this
  // timer separate from the live-value poll prevents it from delaying panning.
  private lastSafeNavigationPayload: string = ''
  private lastSafeNavigationAt: number = 0
  // categoryOffset / categoryRequestSerial / satelliteCatalogReady / CATEGORY_PAGE_SIZE 已随
  // loadCategoryObjects / loadMoreCategoryObjects 下沉 state/SearchStore.ets（§14 B3-3）。
  // 时间面板打开时，每 1s 拉一次 getState，让"时间"字段像走动的钟一样实时更新
  // （否则只在打开瞬间刷新一次，点按钮/时间流逝都不会再更新，永远显示 --）
  private timePanelTimer: number = 0
  /** 时间面板低频全量状态兜底定时器（3s），与高频轻量时间刷新配合使用 */
  private timePanelFullTimer: number = 0
  private skyCultureTimeFollowTimer: number = 0
  private skyCultureTimeFollowRequestPending: boolean = false
  private polarScopeTimer: number = 0
  // 极轴镜在途请求态（polarScopeRequestPending / polarScopeDataRequestId）随加载器下沉
  // state/PolarScopeStore.ets（§14 B3-2）。
  private skyCultureDetailsRequestId: number = 0
  private skyCultureRowY: Record<string, number> = {}
  private skyCultureAnchorId: string = ''
  private skyCultureAnchorY: number = 0
  private skyCultureAnchorRequestId: number = 0
  private skyCultureAnchorArmed: boolean = false
  // 触屏主路径草稿字段（touchStart*/touchLast*/touchMoved/pinch*/dragFiltered*/dragLast*/
  // nativeDragActive/skyDragging 的写侧/panelDragging/panelDragStart*）已随 M3-2 搬入
  // capability/SkyInputController.ets（§15.7 规则 2）；下列跨 handler 共用标志留宿主，
  // 控制器经 SkyInputHostHooks 读写。
  private skyTouchActive: boolean = false
  private skyDragging: boolean = false
  // gyro* 订阅/姿态/引导字段已随 M1-B 子组① 搬入 capability/SensorController.ets
  // （M1-B 子组「可观测子集入 GyroStore、逐帧草稿留控制器」，§15.7 规则 2）。
  private touchStartedOnUi: boolean = false
  private skySelectionRequestSerial: number = 0
  private lastCenterKeyAt: number = 0
  private lastDockActionAt: number = 0
  private lastDockActionPanel: string = ''
  private dockTouchActive: boolean = false

  // 所有设备共享同一动作模型。布局只决定面板如何呈现，不改变入口和语义。

  private moreActionStartsSection(item: ShellAction, index: number): boolean {
    if (index === 0) return true
    const actions = moreActions()
    return actions[index - 1].section !== item.section
  }

  private SELFTEST: boolean = false  // 开发自检：启动即对全部开关跑一次 findAction，验证无死开关。发布前改 false。

  // 城市快速定位预设数据: id -> "lat|lon|alt"

  private readonly SELFTEST_ACTION_IDS: string[] = [
    "actionHorizontal_Flip",
    "actionShow_Antisolar_Point",
    "actionShow_Apex_Points",
    "actionShow_Asterism_Labels",
    "actionShow_Asterism_Lines",
    "actionShow_Atmosphere",
    "actionShow_Azimuthal_Grid",
    "actionShow_Celestial_J2000_Poles",
    "actionShow_Celestial_Poles",
    "actionShow_Circumpolar_Circles",
    "actionShow_Colure_Lines",
    "actionShow_Compass_Marks",
    "actionShow_Constellation_Hulls",
    "actionShow_Constellation_Art",
    "actionShow_Constellation_Boundaries",
    "actionShow_Constellation_Labels",
    "actionShow_Constellation_Lines",
    "actionShow_Current_Vertical_Line",
    "actionShow_DSO_Textures",
    "actionShow_Ecliptic_Grid",
    "actionShow_Ecliptic_J2000_Grid",
    "actionShow_Ecliptic_J2000_Line",
    "actionShow_Ecliptic_J2000_Poles",
    "actionShow_Ecliptic_Line",
    "actionShow_Ecliptic_Poles",
    "actionShow_Equator_J2000_Line",
    "actionShow_Equator_Line",
    "actionShow_Equatorial_Grid",
    "actionShow_Equatorial_J2000_Grid",
    "actionShow_Equinox_J2000_Points",
    "actionShow_Equinox_Points",
    "actionShow_FOV_Center_Marker",
    "actionShow_Gridlines",
    "actionShow_Fixed_Equator_Line",
    "actionShow_Fixed_Equatorial_Grid",
    "actionShow_Fog",
    "actionShow_Galactic_Center",
    "actionShow_Galactic_Equator_Line",
    "actionShow_Galactic_Grid",
    "actionShow_Galactic_Poles",
    "actionShow_Ground",
    "actionShow_MistHorizon",
    "actionShow_Hips_Surveys",
    "actionShow_Horizon_Line",
    "actionShow_Intercardinal_Points",
    "actionShow_Invariable_Plane_Line",
    "actionShow_LandscapeIllumination",
    "actionShow_LandscapeLabels",
    "actionShow_Longitude_Line",
    "actionShow_LunarSystem",
    "actionShow_Meridian_Line",
    "actionShow_MilkyWay",
    "actionShow_Nebulas",
    "actionShow_Night_Mode",
    "actionShow_Penumbra_Circle",
    "actionShow_Planets",
    "actionShow_Planets_EnlargeMoon",
    "actionShow_Planets_EnlargePlanets",
    "actionShow_Planets_EnlargeSun",
    "actionShow_Planets_Hints",
    "actionShow_Planets_Nomenclature",
    "actionShow_Planets_Orbits",
    "actionShow_Planets_ShowMinorBodyMarkers",
    "actionShow_Planets_Trails",
    "actionShow_Precession_Circles",
    "actionShow_Prime_Vertical_Line",
    "actionShow_Quadrature_Line",
    "actionShow_Ray_Helpers",
    "actionShow_Solar_Equator_Line",
    "actionShow_Solstice_J2000_Points",
    "actionShow_Solstice_Points",
    "actionShow_Stars",
    "actionShow_Stars_Labels",
    "actionShow_Supergalactic_Equator_Line",
    "actionShow_Supergalactic_Grid",
    "actionShow_Supergalactic_Poles",
    "actionShow_Toast_Survey",
    "actionShow_Umbra_Center_Point",
    "actionShow_Umbra_Circle",
    "actionShow_Zenith_Nadir",
    "actionShow_Zodiac",
    "actionSwitch_Equatorial_Mount",
    "actionVertical_Flip"
  ]

  private dismissSplash(): void {
    if (this.splashGone) return
    if (this.skyWidth < 2 || this.skyHeight < 2 || Date.now() - this.startupViewportCheckedAt < 80) return
    this.startupViewportCheckedAt = Date.now()
    const viewport = this.callNative('getPresentationState', '')
    if (viewport.ok !== true || (viewport as Record<string, Object>)['ready'] !== true) return
    const viewportWidth = Number((viewport as Record<string, Object>)['width'])
    const viewportHeight = Number((viewport as Record<string, Object>)['height'])
    const matching = viewport.ok === true && viewportWidth > 0 && viewportHeight > 0 &&
      Math.abs(viewportWidth / viewportHeight / (this.skyWidth / this.skyHeight) - 1) < 0.008
    if (!matching) return
    this.isLoading = false
    this.splashGone = true
    this.stopTwinkle()
    hilog.info(0, 'StellariumArkUI', '[startup] presented-frame-ready width=%{public}d height=%{public}d',
      viewportWidth, viewportHeight)
    AppStorage.setOrCreate('stellariumStartupSkyReady', true)
    this.startBodyDetailWarmup()
  }

  private startTwinkle(): void {
    if (this.fpsTimer !== 0) { return }
    this.fpsTimer = setInterval(() => {
      try {
        this.dismissSplash()
      } catch (e) {
      }
    }, 100) as number
  }

  private stopTwinkle(): void {
    if (this.fpsTimer !== 0) { clearInterval(this.fpsTimer); this.fpsTimer = 0 }
  }

  private foldStatusChanged = (status: display.FoldStatus): void => {
    this.foldStatusValue = status as number
    const halfFolded = this.foldStatusValue === 3 || this.foldStatusValue === 13 || this.foldStatusValue === 21 || this.foldStatusValue === 22 || this.foldStatusValue === 23
    if (halfFolded && (this.foldAngleValue >= 155 || this.foldAngleValue <= 0)) {
      this.hasUsableFoldAngle = false
    }
    this.updateResponsiveLayout('foldStatusChange')
  }

  private foldDisplayModeChanged = (mode: display.FoldDisplayMode): void => {
    this.foldDisplayModeValue = mode as number
    this.updateResponsiveLayout('foldDisplayModeChange')
  }

  private foldAngleChanged = (angles: Array<number>): void => {
    if (angles.length > 0 && Number.isFinite(angles[0])) {
      this.foldAngleValue = clamp(angles[0], 0, 180)
      this.hasUsableFoldAngle = this.foldAngleValue > 0 && this.foldAngleValue < 180
      this.updateResponsiveLayout('foldAngleChange')
    }
  }

  private isHalfFoldedStatus(): boolean {
    return this.foldStatusValue === 3 || this.foldStatusValue === 13 || this.foldStatusValue === 21 || this.foldStatusValue === 22 || this.foldStatusValue === 23
  }

  private responsiveFoldAngle(): number {
    if (this.isFoldableDevice && this.isHalfFoldedStatus() && !this.hasUsableFoldAngle) {
      // HALF_FOLD is sufficient to select the observatory layout. 110 degrees
      // is a neutral visual split until the sensor delivers a live value.
      return 110
    }
    return clamp(this.foldAngleValue, 0, 180)
  }

  private refreshFoldState(source: string): void {
    try {
      this.isFoldableDevice = display.isFoldable()
      if (this.isFoldableDevice) {
        this.foldStatusValue = display.getFoldStatus() as number
        this.foldDisplayModeValue = display.getFoldDisplayMode() as number
      }
      hilog.info(0x0000, 'StellariumArkUI', 'foldState source=%{public}s foldable=%{public}s status=%{public}s mode=%{public}s angle=%{public}s', source, this.isFoldableDevice.toString(), this.foldStatusValue.toString(), this.foldDisplayModeValue.toString(), this.foldAngleValue.toString())
    } catch (e) {
      this.isFoldableDevice = false
      hilog.warn(0x0000, 'StellariumArkUI', 'foldState unavailable source=%{public}s', source)
    }
  }

  private registerFoldListeners(): void {
    this.refreshFoldState('aboutToAppear')
    try {
      display.on('foldStatusChange', this.foldStatusChanged)
      display.on('foldDisplayModeChange', this.foldDisplayModeChanged)
      display.on('foldAngleChange', this.foldAngleChanged)
    } catch (e) {
      hilog.warn(0x0000, 'StellariumArkUI', 'fold listeners unavailable')
    }
  }

  private unregisterFoldListeners(): void {
    try {
      display.off('foldStatusChange', this.foldStatusChanged)
      display.off('foldDisplayModeChange', this.foldDisplayModeChanged)
      display.off('foldAngleChange', this.foldAngleChanged)
    } catch (e) { }
  }

  private updateResponsiveLayout(source: string): void {
    const width = this.skyWidth > 1 ? this.skyWidth : 1
    const height = this.skyHeight > 1 ? this.skyHeight : 1
    const shortSide = Math.min(width, height)
    const longSide = Math.max(width, height)
    const aspect = shortSide > 0 ? longSide / shortSide : 1
    const halfFolded = this.isHalfFoldedStatus()
    const folded = this.foldStatusValue === 2
    const explicitlyExpanded = this.foldStatusValue === 1 || this.foldStatusValue === 11 || this.foldDisplayModeValue === 1
    // Fold state describes the physical device, not this window. In floating
    // mode API 22 can still report an expanded fold state after the app window
    // has become phone-sized, so the actual content bounds take precedence.
    const compactWindow = shortSide < 520
    const largeFoldCanvas = this.isFoldableDevice && shortSide >= 620 && aspect <= 1.55
    const tabletCanvas = shortSide >= 700 || (shortSide >= 620 && longSide >= 1000 && aspect <= 1.75)
    const desktopCanvas = width >= 900 && height >= 520
    const angle = this.responsiveFoldAngle()
    const prevMode = this.responsiveLayoutMode
    let nextMode = prevMode

    if (compactWindow) {
      nextMode = 'compact'
    } else if (this.isFoldableDevice && folded && !halfFolded) {
      nextMode = 'compact'
    } else if (this.isFoldableDevice && halfFolded) {
      if (prevMode === 'expanded') {
        nextMode = angle <= 140 ? 'hover' : 'expanded'
      } else if (prevMode === 'hover') {
        if (angle >= 158 && (explicitlyExpanded || largeFoldCanvas || tabletCanvas || desktopCanvas)) {
          nextMode = 'expanded'
        } else if (angle <= 55) {
          nextMode = 'compact'
        } else {
          nextMode = 'hover'
        }
      } else {
        if (angle >= 158 && (explicitlyExpanded || largeFoldCanvas || tabletCanvas || desktopCanvas)) {
          nextMode = 'expanded'
        } else if (angle >= 68) {
          nextMode = 'hover'
        } else {
          nextMode = 'compact'
        }
      }
    } else if (!folded && (explicitlyExpanded || largeFoldCanvas || tabletCanvas || desktopCanvas)) {
      nextMode = 'expanded'
    } else {
      nextMode = 'compact'
    }

    const applyLayout = (): void => {
      this.responsiveLayoutMode = nextMode
      this.isFoldHoverLayout = nextMode === 'hover'
      this.isFoldTabletLayout = this.isFoldableDevice && nextMode === 'expanded' && shortSide < 760
      this.isExpandedLayout = nextMode === 'expanded'
    }
    if (nextMode !== prevMode) {
      try {
        this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, applyLayout)
      } catch (e) {
        applyLayout()
      }
    } else {
      applyLayout()
    }
    hilog.info(0x0000, 'StellariumArkUI', 'layout source=%{public}s w=%{public}s h=%{public}s foldable=%{public}s status=%{public}s displayMode=%{public}s angle=%{public}s uiMode=%{public}s hover=%{public}s foldTablet=%{public}s expanded=%{public}s', source, width.toString(), height.toString(), this.isFoldableDevice.toString(), this.foldStatusValue.toString(), this.foldDisplayModeValue.toString(), angle.toString(), nextMode, this.isFoldHoverLayout.toString(), this.isFoldTabletLayout.toString(), this.isExpandedLayout.toString())
  }

  // PLAN §14.1 / M1-A：宿主桥端口的惰性单例。首次调用构造 HostCommandPort 并缓存，
  // 之后 aboutToAppear 里的各 store 与 UI 回调共用同一实例（行为与原先的局部 const 一致）。
  private commandPort(): CommandPort {
    if (this.hostCommandPort === null) {
      this.hostCommandPort = new HostCommandPort(
        (name: string, payload: string) => this.callNative(name, payload),
        (name: string, payload: string, onOk: (r: StellariumBridgeResponse) => void, onFailure?: (r: StellariumBridgeResponse) => void, attempt?: number, intervalMs?: number, maxAttempts?: number) => {
          this.callNativeWhenReady(name, payload, onOk, attempt ?? 0, intervalMs ?? 200, maxAttempts ?? 60, onFailure)
        },
        (name: string, payload: string, onOk: (r: StellariumBridgeResponse) => void, onFailure?: (r: StellariumBridgeResponse) => void) => {
          this.callInteractive(name, payload, onOk, onFailure)
        },
        (name: string, payload: string, onOk: (r: StellariumBridgeResponse) => void, onFailure?: (r: StellariumBridgeResponse) => void, onProgress?: (r: StellariumBridgeResponse) => void, maxAttempts?: number, isCancelled?: () => boolean) => {
          this.callLongRunningInteractive(name, payload, onOk, onFailure, onProgress, maxAttempts, isCancelled)
        },
        (name: string, payload: string) => { this.callNativeFire(name, payload) }
      )
    }
    return this.hostCommandPort
  }

  // PLAN §15.2 P1-4 / M1-A：启动桥服务的惰性单例。持有各域 store 实例与宿主生命周期 hooks，
  // 在首次调用（aboutToAppear 末尾或 onAreaChange）时构造。
  private startupBridge(): StartupBridge {
    if (this.startupBridgeImpl === null) {
      this.startupBridgeImpl = new StartupBridge(
        this.commandPort(),
        {
          flashHint: (text: ResourceStr): void => this.flashHint(text),
          dismissSplash: (): void => this.dismissSplash(),
          setLanguage: (language: string): void => this.setLanguage(language),
          syncViewCoordinateTimer: (): void => this.syncViewCoordinateTimer(),
          syncDockClockTimer: (): void => this.syncDockClockTimer(),
          setCurrentProjection: (value: string): void => { this.currentProjection = value },
          bridgeSyncStarted: (): boolean => this.bridgeSyncStarted,
          setBridgeSyncStarted: (value: boolean): void => { this.bridgeSyncStarted = value },
          selftestEnabled: (): boolean => this.SELFTEST,
          runSelftest: (): void => this.selfTestAllActions(),
          restoreObserverLocation: (): void => { this.locationCtl().restoreObserverLocation() }
        },
        this.skyCultureViewStore, this.pluginStore, this.nightModeStore, this.telescopeStore,
        this.gyroStore, this.languageStore, this.audioStore, this.viewSettingsStore,
        this.overlayStore, this.astroStore, this.layerViewStore, this.scriptStore,
        this.layerStore, this.timeSettingsStore
      )
    }
    return this.startupBridgeImpl
  }

  // M1-B 子组①：传感器/陀螺仪控制器惰性构造。端口/桥/store 与宿主 hooks 在此注入，
  // 控制器不 import NAPI/UI（§15.7 规则 1）。watchLastSend 属 §2.7.1 保留字段，经 hooks 读写。
  private gyroCtl(): SensorController {
    if (this.sensorControllerImpl === null) {
      const hooks: SensorHostHooks = {
        canUseSensors: (): boolean => this.privacyNativeStartupAllowed && this.applicationInForeground && hasCurrentPrivacyConsent(),
        flashHint: (text: ResourceStr): void => this.flashHint(text),
        displayRotation: (): number => {
          try {
            return Number(display.getDefaultDisplaySync().rotation)
          } catch (error) {
            hilog.warn(0x0000, 'StellariumArkUI', '[gyro-probe] displayRotation unavailable')
            return -1
          }
        },
        objectSelected: (): boolean => this.objectDetailStore.selectedStatus === 'Selected',
        guideLayout: (): GyroGuideLayout => {
          const layout: GyroGuideLayout = {
            isExpandedLayout: this.isExpandedLayout,
            panelVisible: this.panelVisible,
            panelOffsetX: this.panelOffsetX,
            panelWidth: this.panelWidth,
            edgeMargin: this.EDGE_MARGIN,
            skyWidth: this.skyWidth,
            skyHeight: this.skyHeight,
            isFoldHoverLayout: this.isFoldHoverLayout,
            fovSliderValue: this.fovSliderValue
          }
          return layout
        },
        guideProjection: (): GyroGuideProjection | undefined => {
          const projection = this.callNative('getGyroGuidePosition') as GyroGuideProjection
          return projection
        },
        watchLastSend: (): number => this.watchLastSend,
        setWatchLastSend: (value: number): void => { this.watchLastSend = value }
      }
      this.sensorControllerImpl = new SensorController(
        this.gyroStore, this.hostSensorPort, this.commandPort(), this.sessionToolStore, hooks
      )
    }
    return this.sensorControllerImpl
  }

  // M1-B 子组②：录制/回放/录屏控制器惰性构造。状态已在 ScriptStore（只搬行为与定时器）；
  // recordBuffer 属 §2.7.1 保留字段，经 hooks 读写（§15.7 规则 6）。
  private recordingCtl(): RecordingController {
    if (this.recordingControllerImpl === null) {
      const hooks: RecordingHostHooks = {
        flashHint: (text: ResourceStr): void => this.flashHint(text),
        sessionBusy: (): boolean => this.scriptStore.scriptSessionActive(this.tools.recording, this.guideStore.guideState.active),
        hidePanelAndInfo: (): void => {
          this.panelVisible = false
          this.infoWindowStore.infoWinVisible = false
        },
        openScriptsPanel: (): void => { this.setPanel('scripts') },
        changeScriptRate: (direction: number): void => { this.changeScriptRate(direction) },
        recordBufferLength: (): number => this.recordBuffer.length,
        recordBufferSnapshot: (): Array<RecordCmd> => this.recordBuffer,
        recordBufferPush: (cmd: RecordCmd): void => { this.recordBuffer.push(cmd) },
        recordBufferClear: (): void => { this.recordBuffer = [] }
      }
      this.recordingControllerImpl = new RecordingController(
        this.scriptStore, this.tools, this.commandPort(), this.hostMediaPort, hooks
      )
    }
    return this.recordingControllerImpl
  }

  // M2-A：对象检查器三维模型渲染器惰性构造。MediaPort / 三个 store / UI 与媒体管线保留字段
  // 经 hooks 注入，控制器不 import NAPI/UI（§15.7 规则 1）。
  private objectModelRendererCtl(): ObjectModelRenderer {
    if (this.objectModelRendererImpl === null) {
      const hooks: ObjectModelRendererHostHooks = {
        publishModelView: (json: string): void => { AppStorage.setOrCreate('stellariumObjectModelView', json) },
        animateOverlay: (open: boolean, body: () => void, onFinish: () => void): void => {
          this.getUIContext().animateTo(open
            ? { duration: 220, curve: Curve.EaseOut }
            : { duration: 180, curve: Curve.EaseIn, onFinish: onFinish }, body)
        },
        mediaDecodeGeneration: (): number => this.objectInspectorMediaDecodeGeneration,
        proceduralParticles: (): number[][] => this.objectInspectorProceduralParticles,
        resetProcedural: (): void => {
          this.objectInspectorProceduralKey = ''
          this.objectInspectorProceduralParticles = []
        }
      }
      this.objectModelRendererImpl = new ObjectModelRenderer(
        this.objectMediaStore, this.objectDetailStore, this.infoWindowStore, this.hostMediaPort, hooks
      )
    }
    return this.objectModelRendererImpl
  }

  // M3-1/M3-2：天空输入控制器惰性构造。桥 fire 经同一 HostCommandPort；宿主保留动作（isUiPoint /
  // skyZoomButtonAt / dockActionAt 热路径、路由/选中/缩放/详情刷新收放/Dock/陀螺退出/面板拖动落盘）
  // 经 SkyInputHostHooks 具名回注，控制器不 import NAPI/UI。
  private skyInputCtl(): SkyInputController {
    if (this.skyInputControllerImpl === null) {
      const hooks: SkyInputHostHooks = {
        isUiPoint: (x: number, y: number): boolean => this.isUiPoint(x, y),
        flashHint: (text: string): void => this.flashHint(text),
        skyWidth: (): number => this.skyWidth,
        skyHeight: (): number => this.skyHeight,
        gyroscopeEnabled: (): boolean => this.gyroStore.gyroscopeEnabled,
        stopGyroscope: (updateStatus: boolean): void => this.gyroCtl().stopGyroscope(updateStatus),
        angleMeasureEnabled: (): boolean => this.tools.angleMeasureEnabled,
        measureAngleAt: (x: number, y: number): void => this.measureAngleAt(x, y),
        requestSkySelection: (x: number, y: number): void => this.requestSkySelection(x, y),
        clearSkySelectionFromDoubleTap: (x: number, y: number): void => this.clearSkySelectionFromDoubleTap(x, y),
        zoomStep: (factor: number): void => this.zoomStep(factor),
        setPanel: (panel: string): void => this.setPanel(panel),
        closePanel: (): void => this.closePanel(),
        moveToSelectedObject: (): void => this.moveToSelectedObject(),
        centerSelectedObjectFromKeyboard: (): void => this.centerSelectedObjectFromKeyboard(),
        persistNightMode: (): void => this.persistNightMode(),
        modelImmersive: (): boolean => this.objectMediaStore.objectInspectorModelImmersive,
        setModelImmersive: (value: boolean): void => this.objectModelRendererCtl().setObjectInspectorModelImmersive(value),
        // ── M3-2：触屏主路径（handleSkyTouch / emitFluidDrag）hooks ──
        isExpandedLayout: (): boolean => this.isExpandedLayout,
        isFoldHoverLayout: (): boolean => this.isFoldHoverLayout,
        isFoldTabletLayout: (): boolean => this.isFoldTabletLayout,
        panelVisible: (): boolean => this.panelVisible,
        panelWidth: (): number => this.panelWidth,
        panelOffsetX: (): number => this.panelOffsetX,
        panelOffsetY: (): number => this.panelOffsetY,
        edgeMargin: (): number => this.EDGE_MARGIN,
        fovSliderValue: (): number => this.fovSliderValue,
        setFovSliderValue: (value: number): void => { this.fovSliderValue = value },
        polarScopeVisible: (): boolean => this.polarScopeStore.polarScopeVisible,
        compactDockWidthPercent: (): number => this.compactDockWidthPercent(),
        dockTop: (): number => this.dockTop(),
        compactTopQuickX: (): number => this.compactTopQuickX(),
        isCompactTopQuickPoint: (x: number, y: number): boolean => this.isCompactTopQuickPoint(x, y),
        lastInfoWinCloseMs: (): number => this.lastInfoWinCloseMs,
        touchStartedOnUi: (): boolean => this.touchStartedOnUi,
        setTouchStartedOnUi: (value: boolean): void => { this.touchStartedOnUi = value },
        skyTouchActive: (): boolean => this.skyTouchActive,
        setSkyTouchActive: (value: boolean): void => { this.skyTouchActive = value },
        setSkyDragging: (value: boolean): void => { this.skyDragging = value },
        dockTouchActive: (): boolean => this.dockTouchActive,
        setDockTouchActive: (value: boolean): void => { this.dockTouchActive = value },
        skyTouchFeedback: (): boolean => this.skyTouchFeedback,
        setSkyTouchFeedback: (value: boolean): void => { this.skyTouchFeedback = value },
        setSkyTouchPoint: (x: number, y: number): void => { this.skyTouchX = x; this.skyTouchY = y },
        setSkyTouchPoint2: (x: number, y: number): void => { this.skyTouchX2 = x; this.skyTouchY2 = y },
        skyTouchX2: (): number => this.skyTouchX2,
        skyTouchY2: (): number => this.skyTouchY2,
        setSkyTouchFeedbackMulti: (value: boolean): void => { this.skyTouchFeedbackMulti = value },
        setCurrentFovText: (text: string): void => { this.currentFovText = text },
        setPanelOffset: (offsetX: number, offsetY: number): void => { this.panelOffsetX = offsetX; this.panelOffsetY = offsetY },
        cancelSelectedObjectUiChange: (): void => this.cancelSelectedObjectUiChange(),
        pauseDetailRefreshForSkyDrag: (): void => this.pauseDetailRefreshForSkyDrag(),
        resumeDetailRefreshAfterSkyDrag: (): void => this.resumeDetailRefreshAfterSkyDrag(),
        scheduleSelectedObjectForUiChange: (delay: number): void => this.scheduleSelectedObjectForUiChange(delay),
        scheduleSkyTextureStatusCheck: (): void => this.scheduleSkyTextureStatusCheck(),
        scheduleRecordingViewCheckpoint: (delay: number): void => this.recordingCtl().scheduleRecordingViewCheckpoint(delay),
        resetPanelIdle: (): void => this.resetPanelIdle(),
        toggleMusic: (): void => this.toggleMusic(),
        musicHintText: (): string => this.audioStore.musicEnabled ? I18n.t('music_on_hint') : I18n.t('music_off_hint'),
        toggleGyroscope: (value: boolean): void => this.gyroCtl().toggleGyroscope(value),
        skyZoomButtonAt: (x: number, y: number): string => this.skyZoomButtonAt(x, y),
        dockActionAt: (x: number, y: number): ShellAction | null => this.dockActionAt(x, y),
        activateDockAction: (item: ShellAction): void => this.activateDockAction(item),
        requestFieldOfView: (onResult: (fov: number) => void): void => {
          this.callInteractive('getFieldOfView', '', (r: StellariumBridgeResponse) => {
            if (r.ok === true && r.fov !== undefined) { onResult(r.fov) }
          })
        }
      }
      this.skyInputControllerImpl = new SkyInputController(this.commandPort(), this.nightModeStore, hooks)
    }
    return this.skyInputControllerImpl
  }

  // §15.12 位置域控制器惰性构造。NAPI（权限/定位/preferences）经 HostLocationPort；跨域写
  // （SessionToolStore.observerPlanet、位置头部三 @State）与 GPS 门禁经 LocationHostHooks 回注。
  private locationCtl(): LocationController {
    if (this.locationControllerImpl === null) {
      const hooks: LocationHostHooks = {
        flashHint: (text: ResourceStr): void => this.flashHint(text),
        refreshState: (): void => { this.refreshState() },
        loadObserverInfo: (): void => { this.locationPickerStore.loadObserverInfo(true) },
        setObserverPlanetCrossStore: (name: string): void => { this.sessionToolStore.observerPlanet = name },
        setLocationTexts: (location: string, coordinate: string, altitude: string): void => {
          this.locationText = location
          this.coordinateText = coordinate
          this.altitudeText = altitude
        },
        privacyAllowed: (): boolean => this.privacyNativeStartupAllowed,
        inForeground: (): boolean => this.applicationInForeground,
        hasPrivacyConsent: (): boolean => hasCurrentPrivacyConsent()
      }
      this.locationControllerImpl = new LocationController(
        this.commandPort(), this.hostLocationPort, this.locationPickerStore, this.locationStore, this.sessionToolStore, hooks
      )
    }
    return this.locationControllerImpl
  }

  aboutToAppear(): void {
    hilog.info(0x0000, 'StellariumArkUI', '[privacy-probe] phase=main-page-appear')
    const localStorage = this.getUIContext().getSharedLocalStorage()
    if (localStorage) {
      this.createInfo = localStorage.get<WindowNativeNodeCreateInfo>('createInfo')
    }
    // §15.1 / M1-A：配置媒体 / 平台 / 传感器三个端口适配器（服务层经它们调用 NAPI，不直接 import）。
    this.hostMediaPort.configure((): common.UIAbilityContext => this.getUIContext().getHostContext() as common.UIAbilityContext)
    this.hostPlatformPort.configure(
      (): common.UIAbilityContext => this.getUIContext().getHostContext() as common.UIAbilityContext,
      (): boolean => this.isExpandedLayout
    )
    // §15.12：配置位置端口适配器（权限/定位/preferences NAPI 在此收口）。
    this.hostLocationPort.configure((): common.UIAbilityContext => this.getUIContext().getHostContext() as common.UIAbilityContext)
    // §14.1：把宿主桥注入 ToolsStore。ToolsStore 消费方均为 @ObjectLink，字段赋值即刷新，
    // 故此处 onChanged 注入等价空实现（该域无 publish* 发布点）。
    const hostPort = this.commandPort()
    this.tools.attachPort(hostPort, () => {})
    // §14 B3-1：角度测量加载器 loadAngleMeasure 与动作 toggleAngleMeasure 同片搬入 ToolsStore；
    // 动作回包后的 UI 提示经 ToolsHostHooks.flashHint 回注（store 不触碰 UI）。
    this.tools.attachHooks({
      flashHint: (text: ResourceStr): void => { this.flashHint(text) }
    })
    // §14 B1-1：望远镜/目镜域复用同一个 HostCommandPort 实例。其消费方均为 @ObjectLink，
    // 字段赋值即刷新，且该域无 publish* 发布点，故 onChanged 传空实现。
    this.telescopeStore.attachPort(hostPort, () => {})
    // §14 B3-4：live-position 定时器簇随加载器/动作整体下沉 TelescopeStore，store 自持 start/stop；
    // 「是否应刷新」谓词读宿主 applicationInForeground / panelVisible / activePanel，故宿主保留
    // shouldRefreshTelescopePosition 并经 TelescopeHostHooks 注入（store 不触碰 UI 生命周期）。
    this.telescopeStore.attachHooks({
      shouldRefreshTelescopePosition: (): boolean => this.shouldRefreshTelescopePosition()
    })
    // §14 B1-2：图层视图域（地景列表 / 行星轨道 / 行星轨迹）复用同一实例；消费方均为
    // @ObjectLink，字段赋值即刷新，该域无 publish* 发布点，onChanged 传空实现。
    this.layerViewStore.attachPort(hostPort, () => {})
    // §14 B1-3：星表下载域复用同一 HostCommandPort 实例。其消费方（CatalogsPanel）为
    // @ObjectLink，字段赋值即刷新，该域无 publish* 发布点，故 onChanged 传空实现。
    this.catalogStore.attachPort(hostPort, () => {})
    // §14 B2R-4：目录分类加载器 loadObjectCatalogCategories 下沉 CatalogStore。它只读语言刷新
    // 代际 languageRefreshSerial（§14 B3-1 起单一持有者为 LanguageStore）、读写 SearchStore 的
    // pendingPluginCatalogId / searchCategory / categoryModuleId，并调用搜索域动作 loadCategoryObjects
    //（§14 B3-3 起为 SearchStore 方法）与 CLI 发布点 publishSearchBrowserState —— 全部经
    // CatalogHostHooks 具名回注。
    this.catalogStore.attachHooks({
      languageSerial: (): number => this.languageStore.languageRefreshSerial,
      pendingPluginCatalogId: (): string => this.searchStore.pendingPluginCatalogId,
      clearPendingPluginCatalogId: (): void => { this.searchStore.pendingPluginCatalogId = '' },
      searchCategory: (): string => this.searchStore.searchCategory,
      categoryModuleId: (): string => this.searchStore.categoryModuleId,
      loadCategoryObjects: (category: string, moduleIdOverride: string): void => { this.searchStore.loadCategoryObjects(category, moduleIdOverride) },
      publishSearchBrowserState: (): void => { this.publishSearchBrowserState() },
      // §14 B3-5：目录健康加载器 loadCatalogHealth 下沉 CatalogStore；两条 §2.7.1 保留的
      // 「跨域共用」标志（catalogHealthLoaded / catalogManifestPresent）仍留宿主、经 setter 回注，
      // satelliteCatalogHealth 归属 SatelliteStore 亦经 setter 回注（store 不 import 他 store）。
      setCatalogHealthLoaded: (loaded: boolean): void => { this.catalogHealthLoaded = loaded },
      setCatalogManifestPresent: (present: boolean): void => { this.catalogManifestPresent = present },
      setSatelliteCatalogHealth: (health: CatalogHealthEntry): void => { this.satelliteStore.satelliteCatalogHealth = health }
    })
    // §14 B3-5：3D 场景加载器 loadScenery3d 下沉 SceneryStore，复用同一 HostCommandPort。
    // §2.7.1 登记的「引擎自用 / 已登记约定」字段 scenery3dCurrentId 仍留宿主，加载器经
    // SceneryHostHooks.setScenery3dCurrentId 回注（宿主保留字段本身）。
    this.sceneryStore.attachPort(hostPort)
    this.sceneryStore.attachHooks({
      setScenery3dCurrentId: (id: string): void => { this.scenery3dCurrentId = id }
    })
    // §14 B1-4：相机拼接（MosaicCamera）与古天文辅助线（ArchaeoLines）两域复用同一实例。
    // 两者消费方均为 @ObjectLink，字段赋值即刷新，该域无 publish* 发布点，onChanged 传空实现。
    this.mosaicStore.attachPort(hostPort, () => {})
    this.archaeoStore.attachPort(hostPort, () => {})
    // §14 B1-5：插件管理 / 命令控制台 / 均时差 / 星云贴图四域复用同一实例。其消费方均为
    // @ObjectLink，字段赋值即刷新，四个域都无 publish* 发布点，故 onChanged 传空实现。
    this.pluginStore.attachPort(hostPort, () => {})
    this.commandStore.attachPort(hostPort, () => {})
    this.equationOfTimeStore.attachPort(hostPort, () => {})
    this.nebulaTextureStore.attachPort(hostPort, () => {})
    // §14 B1-6：脚本录制 / 观测星球 / 星空文化标志 / 天体资料 / 指针坐标五域复用同一实例，
    // 其消费方均为 @ObjectLink，字段赋值即刷新，五个域都无 publish* 发布点，故 onChanged 传空实现。
    this.scriptStore.attachPort(hostPort, () => {})
    // §14 B2R-4：脚本列表 / 资源元数据 / 录制载入加载器下沉 ScriptStore。loadRecordingByName
    // 回包后的 UI 提示经 ScriptHostHooks.flashHint 回注（store 不触碰 UI）。
    this.scriptStore.attachHooks({
      flashHint: (text: ResourceStr): void => { this.flashHint(text) },
      // §14 B3-4：视频状态轮询收口时调用的宿主 stopVideoRecording（store 不触碰桥/UI）。
      stopVideoRecording: (): void => { this.recordingCtl().stopVideoRecording() }
    })
    // M1-A 子组④：原生脚本播放的跨域/UI/定时器动作经具名注入（store 不触碰 UI/他 store）。
    this.scriptStore.attachPlaybackHooks({
      flashHint: (text: ResourceStr): void => { this.flashHint(text) },
      sessionBusy: (): boolean => this.scriptStore.scriptSessionActive(this.tools.recording, this.guideStore.guideState.active),
      guideActive: (): boolean => this.guideStore.guideState.active,
      requestStopGuide: (): void => { this.guideStore.executeGuideRequest('guideAction', 'stop') },
      finishReplay: (message: string): void => this.recordingCtl().finishRecordingReplay(message),
      finishNativeScriptUi: (message: string): void => this.finishNativeScriptUi(message),
      dismissScriptOverlays: (): void => {
        this.panelVisible = false
        this.infoWindowStore.infoWinVisible = false
        this.gyroStore.gyroCalibPanelOpen = false
      },
      stopBackgroundTimers: (): void => {
        this.stopTimePanelTimers()
        this.stopSkyCultureTimeFollowTimer()
        this.stopPolarScopeTimer()
      },
      startStatusPolling: (): void => this.startScriptStatusPolling(),
      stopStatusPolling: (): void => this.stopScriptStatusPolling(),
      refreshStatus: (): void => { this.refreshScriptStatus() },
      runWaitingAnimation: (action: () => void): void => {
        this.getUIContext().animateTo({ duration: 160, curve: Curve.EaseOut }, action)
      },
      logScriptError: (filename: string, error: string): void => {
        hilog.error(0x0000, 'StellariumArkUI', 'playScript failed %{public}s err=%{public}s', filename, error)
      }
    })
    this.sessionToolStore.attachPort(hostPort, () => {})
    // M1-A：会话导出/应用/迁移的 UI 提示、剪贴板、ToolsStore 文本框与分布式能力经具名注入。
    this.sessionToolStore.attachHooks({
      flashHint: (text: ResourceStr): void => this.flashHint(text),
      copySessionJson: (text: string, successHint: ResourceStr): void => {
        copyTextToClipboard(this.hostPlatformPort, text, successHint, { flashHint: (hint: ResourceStr): void => this.flashHint(hint) })
      },
      sessionImportText: (): string => this.tools.sessionImportText,
      setSessionExportText: (text: string): void => { this.tools.sessionExportText = text },
      canUseDistributed: (): boolean => this.canUseDistributed
    })
    // M1-A 子组④：交互导览的引擎/请求/定时器并入 GuideStore（定时器 store 自持 start/stop）；
    // 跨域/UI/引擎动作经具名 hooks 回注（store 不 import UI/他 store）。
    this.guideStore.attachPort(hostPort)
    this.guideStore.attachHooks({
      flashHint: (text: ResourceStr): void => this.flashHint(text),
      publishGuideState: (): void => this.publishGuideState(),
      sessionBusy: (): boolean => this.scriptStore.scriptSessionActive(this.tools.recording, this.guideStore.guideState.active),
      polarScopeVisible: (): boolean => this.polarScopeStore.polarScopeVisible,
      panelVisible: (): boolean => this.panelVisible,
      setPanelVisible: (value: boolean): void => { this.panelVisible = value },
      hideInfoWindow: (): void => { this.infoWindowStore.infoWinVisible = false },
      applicationInForeground: (): boolean => this.applicationInForeground,
      gyroscopeEnabled: (): boolean => this.gyroStore.gyroscopeEnabled,
      setGyroscopeEnabled: (value: boolean): void => { this.gyroStore.gyroscopeEnabled = value },
      startGyroscope: (): void => this.gyroCtl().startGyroscope(),
      stopGyroscope: (updateStatus: boolean): void => this.gyroCtl().stopGyroscope(updateStatus),
      stopSkyInertia: (): void => this.skyInputCtl().stopSkyInertia(),
      stopCompetingTasks: (): void => {
        this.stopDetailAutoRefresh()
        this.stopTimePanelTimers()
        this.stopSkyCultureTimeFollowTimer()
        this.stopAstroCalcContextTimer()
        this.telescopeStore.stopTelescopeLivePosition(false)
      },
      refreshState: (): void => { this.refreshState() },
      reloadObserverInfo: (): void => { this.locationPickerStore.loadObserverInfo(true) },
      animateTo: (action: () => void): void => {
        this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseInOut }, action)
      }
    })
    this.skyCultureSettingsStore.attachPort(hostPort, () => {})
    this.objectDetailStore.attachPort(hostPort, () => {})
    // §14 B2R-4：卫星过境加载器 loadSelectedSatellitePasses 下沉 ObjectDetailStore，复用未随本片
    // 下沉的宿主助手 selectedObjectIsArtificialSatellite / requestSatellitePasses（经 hooks 回注）。
    this.objectDetailStore.attachHooks({
      requestSatellitePasses: (expectedName: string): void => { this.requestSatellitePasses(expectedName) }
    })
    // §14 B2R-4：书签加载器 loadBookmarks / loadBookmarksFromStorage 下沉 BookmarkStore。
    // Preferences 读写（原 getUIContext + @ohos.data.preferences）与持久化助手经 hooks 回注
    //（store 不 import NAPI/UI 上下文，§14.8 规则 2）。
    this.bookmarkStore.attachPort(hostPort)
    this.bookmarkStore.attachHooks({
      readBookmarksStorage: (): Promise<string> => this.readBookmarksStorage(),
      saveBookmarksToStorage: (): void => { this.saveBookmarksToStorage() }
    })
    // §14 B2R-4：观测列表首次载入下沉 ObservingListStore；Preferences 读写经 hooks 回注。
    this.obsListStore.attachHooks({
      readObservingListStorage: (): Promise<string> => this.readObservingListStorage(),
      writeObservingListStorage: (json: string): Promise<void> => this.writeObservingListStorage(json)
    })
    this.overlayStore.attachPort(hostPort, () => {})
    // §14 B2R-3：星空文化域四加载器下沉。skyCultureSettingsStore 复用既有 HostCommandPort
    // （其 loadSkyCultureConstellationSelectionFlags 已在 B1-6 自持）；SkyCultureViewStore /
    // SkyCultureMakerStore 新增同一端口。三域消费方均为 @ObjectLink，字段赋值即刷新，无 publish*
    // 发布点，onChanged 传空实现。loadSkyCultureDetails（详情，写 §2.7.1 保留的 skyCultureArtStates
    // 渐进字段）仍留宿主、登记 B3，只经 hooks 注入调用；skyCultureActiveColorTarget /
    // drawSkyCultureTerritoryMap / skyCultureCurrentId / applySkyCultureMakerDraft / ensurePluginLoaded /
    // skyCultureMakerDraftFromResponse 同经具名 hooks 回注（store 不 import 桥/UI/他 store）。
    this.skyCultureSettingsStore.attachHooks({
      skyCultureActiveColorTarget: (): string => this.skyCultureActiveColorTarget(),
      drawSkyCultureTerritoryMap: (): void => { this.drawSkyCultureTerritoryMap() },
      skyCultureCurrentId: (): string => this.skyCultureViewStore.currentSkyCultureId
    })
    this.skyCultureViewStore.attachPort(hostPort, () => {})
    this.skyCultureViewStore.attachHooks({
      invalidateSkyCultureDetails: (): void => { ++this.skyCultureDetailsRequestId },
      loadSkyCultureDetails: (): void => { this.loadSkyCultureDetails() }
    })
    this.skyCultureMakerStore.attachPort(hostPort, () => {})
    this.skyCultureMakerStore.attachHooks({
      applySkyCultureMakerDraft: (draft: SkyCultureMakerDraft): void => this.applySkyCultureMakerDraft(draft),
      ensurePluginLoaded: (pluginName: string, callback: () => void, failureCallback?: () => void): void => this.ensurePluginLoaded(pluginName, callback, failureCallback),
      skyCultureMakerDraftFromResponse: (response: StellariumBridgeResponse): SkyCultureMakerDraft | undefined => this.skyCultureMakerDraftFromResponse(response)
    })
    // §14 B1-6：卫星域有 publish* CLI 发布点（publishSatellitePanelState），
    // 故 onChanged 用它，保持 CLI 侧 satellitePanelState 与 store 同步。
    this.satelliteStore.attachPort(hostPort, (error: string) => { this.publishSatellitePanelState(error) })
    // §14 B1-6：位置域的 loadSavedLocations 读 AppStorage 而非桥，port 暂未使用（预留）。
    this.locationStore.attachPort(hostPort, () => {})
    // §15.12：离线搜索 / 保存点的跨域读（LocationPickerStore 助手 + SessionToolStore.observerPlanet）
    // 与跨 store 动作（setLocation / pickerMode）经具名 hooks 回注，store 不 import 他 store。
    this.locationStore.attachHooks({
      flashHint: (text: ResourceStr): void => { this.flashHint(text) },
      currentDraft: (): LocationDraft => {
        return {
          name: this.locationPickerStore.locationPickerName,
          latitude: this.locationPickerStore.locationPickerLatitude,
          longitude: this.locationPickerStore.locationPickerLongitude,
          altitude: this.locationPickerStore.locationPickerAltitude,
          planet: this.sessionToolStore.observerPlanet
        }
      },
      observerPlanet: (): string => this.sessionToolStore.observerPlanet,
      quickLocationSearch: (query: string, observerPlanet: string): Array<LocSearchItem> => this.locationPickerStore.quickLocationSearch(query, observerPlanet),
      isCurrentObserverPlanet: (city: HierCity, observerPlanet: string): boolean => this.locationPickerStore.isCurrentObserverPlanet(city, observerPlanet),
      locationDisplayName: (name: string): string => this.locationPickerStore.locationDisplayName(name),
      locationSearchCountryName: (countryCode: string, observerPlanet: string): string => this.locationPickerStore.locationSearchCountryName(countryCode, observerPlanet),
      translateProvince: (name: string): string => this.locationPickerStore.translateProvince(name),
      locationPlanet: (city: HierCity): string => this.locationPickerStore.locationPlanet(city),
      applyLocation: (name: string, lat: number, lon: number, alt: number, planet: string): void => { this.locationCtl().setLocation(name, lat, lon, alt, planet) },
      setPickerMode: (mode: string): void => { this.locationPickerStore.locationPickMode = mode }
    })
    // §14 B2A：Astro 簇加载器下沉。astroStore 复用同一 HostCommandPort；onChanged 走
    // publishAstroPanelState，保持 CLI 侧 stellariumAstroPanelState 同步；跨 store
    // （objectDetailStore / wutStore / ephemerisStore）与未随本片下沉的宿主加载器
    // （loadPlanetPositions）经 AstroHostHooks 具名注入（月相 / 天文计算上下文加载器已于 B3-2 下沉）。
    this.astroStore.attachPort(hostPort, () => { this.publishAstroPanelState() })
    this.astroStore.attachHooks({
      hasSelectedObject: () => this.objectDetailStore.hasSelectedObject(),
      selectedObjectName: () => this.objectDetailStore.selectedName,
      wutCategory: () => this.wutStore.wutCategory,
      wutObservationTime: () => this.wutStore.wutObservationTime,
      loadWutTargets: () => { this.wutStore.loadWutTargets() },
      ephemerisCustomStartJD: () => dateToJD(this.ephemerisStore.ephemerisStartYear, this.ephemerisStore.ephemerisStartMonth, this.ephemerisStore.ephemerisStartDay, 0, 0),
      fmtDateTime: (s: string | undefined) => this.fmtDateTime(s),
      hecLayoutPositions: (positions: Array<HeliocentricPosition>) => hecLayoutPositions(positions),
      loadPlanetPositions: () => { this.loadPlanetPositions() }
    })
    // §14 B3-2：极轴镜加载器下沉 PolarScopeStore；「是否应刷新」谓词仍归宿主经具名 hooks 注入，
    // 每 1s 计时器与面板开合只调用 store 的 loadPolarScopeData / cancelPolarScopeRequest。
    this.polarScopeStore.attachPort(hostPort)
    this.polarScopeStore.attachHooks({
      shouldRefreshPolarScope: () => this.shouldRefreshPolarScope()
    })
    // §14 B2A：今晚观测目标（WUT）簇的 loadWutTargets 下沉 state/WutStore.ets；onChanged 走
    // publishAstroPanelState，保持 CLI 侧 astroPanelState 的 wut 字段同步。
    this.wutStore.attachPort(hostPort, () => { this.publishAstroPanelState() })
    // §14 B2R-1：对象检查器原始模型纹理加载器 loadObjectInspectorModelRawTexture 下沉
    // ObjectMediaStore；其侧车读取（fileIo）经 readRawSidecar 回注，而 image / decodeLocalImage
    // 相关的三个下游（PNG 回退解码 / 纹理提交 / 失败上报）已随 M2-A 移入 capability/ObjectModelRenderer.ets，
    // 故此处三个 hooks 转发给控制器（store 仍不 import NAPI/UI，不走桥、无 publish*，不注入 CommandPort）。
    this.objectMediaStore.attachHooks({
      readRawSidecar: (path: string, expectedBytes: number, label: string): ArrayBuffer => this.readRawSidecar(path, expectedBytes, label),
      decodeObjectInspectorModelTextureFromPng: (pngFilePath: string, ringPngFilePath: string, mediaGeneration: number, expectedSelection: string, expectedPath: string): void =>
        this.objectModelRendererCtl().decodeObjectInspectorModelTextureFromPng(pngFilePath, ringPngFilePath, mediaGeneration, expectedSelection, expectedPath),
      commitObjectInspectorModelTexture: (texture: ArrayBuffer, ringTexture: ArrayBuffer | undefined, mediaGeneration: number, expectedSelection: string, expectedPath: string, sourceLabel: string): void =>
        this.objectModelRendererCtl().commitObjectInspectorModelTexture(texture, ringTexture, mediaGeneration, expectedSelection, expectedPath, sourceLabel),
      failObjectInspectorModelTexture: (mediaGeneration: number, reason: string): void => this.objectModelRendererCtl().failObjectInspectorModelTexture(mediaGeneration, reason)
    })
    // §14 B2R-2：设置 / 观测点 / 时间附加三个加载器分别下沉 TimeSettingsStore / LocationPickerStore /
    // TimeStore，均复用同一 HostCommandPort 实例。三者消费方均为 @ObjectLink（字段赋值即刷新），
    // 且无 publish* 发布点，故 onChanged 传空实现。跨 store 写入的字段与两个与宿主动作共享的
    // 助手（applySelectedInfoMode / applyTimeSettings / applyAtmosphereResponse / syncNightModeFromEngine）
    // 按 §14.5「额外注入」经具名 hooks 回注。
    this.locationPickerStore.attachPort(hostPort, () => {})
    this.locationPickerStore.attachHooks({
      setSkyCultureObserverLatitude: (value: number): void => { this.skyCultureSettingsStore.skyCultureObserverLatitude = value },
      setObserverPlanet: (value: string): void => { this.sessionToolStore.observerPlanet = value }
    })
    // 启动恢复上次观测点（含 GPS 定点）：不再每次重启回退引擎默认北京。引擎未就绪由
    // setLocation 内的 callNativeWhenReady 重试兜底（§15.12 起经位置控制器）。
    this.locationCtl().restoreObserverLocation()
    this.timeStore.attachPort(hostPort, () => {})
    this.timeStore.attachHooks({
      syncNightModeFromEngine: (engineNight: boolean): void => this.syncNightModeFromEngine(engineNight),
      applyAtmosphereResponse: (response: StellariumBridgeResponse): void => this.applyAtmosphereResponse(response)
    })
    this.timeSettingsStore.attachPort(hostPort, () => {})
    this.timeSettingsStore.attachHooks({
      setUseMetricUnits: (value: boolean): void => { this.viewSettingsStore.useMetricUnits = value },
      setConfigDitheringMode: (mode: string): void => { this.viewSettingsStore.configDitheringMode = mode },
      setAutoZoomResets: (value: boolean): void => { this.viewSettingsStore.autoZoomResets = value },
      setNavigationMouseEnabled: (value: boolean): void => { this.navigationStore.navigationMouseEnabled = value },
      setNavigationMouseZoomEnabled: (value: boolean): void => { this.navigationStore.navigationMouseZoomEnabled = value },
      setNavigationMoveKeysEnabled: (value: boolean): void => { this.navigationStore.navigationMoveKeysEnabled = value },
      setNavigationZoomKeysEnabled: (value: boolean): void => { this.navigationStore.navigationZoomKeysEnabled = value },
      setNavigationGravityLabelsEnabled: (value: boolean): void => { this.navigationStore.navigationGravityLabelsEnabled = value },
      setNavigationStartupFov: (value: number): void => { this.navigationStore.navigationStartupFov = value },
      setNavigationStartupAzimuth: (value: number): void => { this.navigationStore.navigationStartupAzimuth = value },
      setNavigationStartupAltitude: (value: number): void => { this.navigationStore.navigationStartupAltitude = value },
      setNavigationMaxFov: (value: number): void => { this.navigationStore.navigationMaxFov = value },
      setEphemerisAvailability: (de430Available: boolean, de431Available: boolean, de440Available: boolean, de441Available: boolean): void => {
        this.ephemerisStore.ephemerisDe430Available = de430Available
        this.ephemerisStore.ephemerisDe431Available = de431Available
        this.ephemerisStore.ephemerisDe440Available = de440Available
        this.ephemerisStore.ephemerisDe441Available = de441Available
      },
      setEphemerisActive: (de430Active: boolean, de431Active: boolean, de440Active: boolean, de441Active: boolean): void => {
        this.ephemerisStore.ephemerisDe430Active = de430Active
        this.ephemerisStore.ephemerisDe431Active = de431Active
        this.ephemerisStore.ephemerisDe440Active = de440Active
        this.ephemerisStore.ephemerisDe441Active = de441Active
      },
      informationMode: (): string => this.infoWindowStore.informationMode,
      setInformationMode: (mode: string): void => { this.infoWindowStore.informationMode = mode },
      setInformationCustomMask: (mask: number): void => { this.infoWindowStore.informationCustomMask = mask },
      applySelectedInfoMode: (mode: string): void => this.applySelectedInfoMode(mode),
      applyTimeSettings: (response: StellariumBridgeResponse): void => this.applyTimeSettings(response)
    })
    // §14 B3-1：航海星 / 流星雨 / 搜索三域分别自持加载器（loadNavStars / loadMeteorShowers /
    // loadConstellationNavigation）与其配对写方；三者复用同一 HostCommandPort 实例，消费方均为
    // @ObjectLink（字段赋值即刷新），无 publish* 发布点，故 onChanged 传空实现。
    // SearchStore 的 loadConstellationNavigation 经 SearchHostHooks.languageSerial 只读 LanguageStore
    // 的语言刷新代际（§14.8 规则 3：单一持有者，宿主不留副本）。
    this.navStarsStore.attachPort(hostPort, () => {})
    this.meteorStore.attachPort(hostPort, () => {})
    this.searchStore.attachPort(hostPort, () => {})
    // §14 B3-3：分类浏览加载器（loadCategoryObjects / loadMoreCategoryObjects）与搜索历史加载器
    // （loadSearchHistoryFromStorage）下沉 SearchStore。分类加载器调用的宿主助手 / CLI 发布点 /
    // 插件加载器与搜索历史 Preferences 读写经 SearchHostHooks 具名回注（store 不 import 桥/UI/
    // NAPI）；语言刷新代际仍只读 LanguageStore（§14 B3-1）。
    this.searchStore.attachHooks({
      languageSerial: (): number => this.languageStore.languageRefreshSerial,
      publishSearchBrowserState: (): void => { this.publishSearchBrowserState() },
      categoryModuleIdFor: (category: string): string => this.catalogStore.categoryModuleIdFor(category),
      ensurePluginLoaded: (pluginName: string, callback: () => void, failureCallback?: () => void): void => this.ensurePluginLoaded(pluginName, callback, failureCallback),
        celestialTitle: (nativeName: string, englishName: string): string => celestialTitle(nativeName, englishName),
      readSearchHistoryStorage: (): Promise<string> => this.readSearchHistoryStorage(),
      writeSearchHistoryStorage: (json: string): Promise<void> => this.writeSearchHistoryStorage(json)
    })
    this.startPageAfterPrivacyIfNeeded()
  }

  private onQtNativeNodeAttach(): void {
    hilog.info(0x0000, 'StellariumArkUI', '[privacy-probe] phase=qt-native-node-attach')
    if (this.createInfo !== undefined) {
      this.createInfo.onAttach()
    }
  }

  private onQtNativeNodeAppear(): void {
    hilog.info(0x0000, 'StellariumArkUI', '[privacy-probe] phase=qt-native-node-appear')
    if (this.createInfo !== undefined) {
      this.createInfo.onAppear()
    }
  }

  private onQtNativeNodeDisappear(): void {
    hilog.info(0x0000, 'StellariumArkUI', '[privacy-probe] phase=qt-native-node-disappear')
    if (this.createInfo !== undefined) {
      this.createInfo.onDisAppear()
    }
  }

  private onQtSurfaceAppear(): void {
    hilog.info(0x0000, 'StellariumArkUI', '[privacy-probe] phase=qt-surface-appear')
  }

  private onPrivacyNativeStartupAllowedChanged(): void {
    hilog.info(0x0000, 'StellariumArkUI',
      '[privacy-probe] phase=native-node-gate-observed allowed=%{public}s', this.privacyNativeStartupAllowed.toString())
    this.startPageAfterPrivacyIfNeeded()
  }

  private onCliUiEventChanged(): void {
    if (this.cliUiEvent.length === 0) {
      return
    }
    try {
      const event = JSON.parse(this.cliUiEvent) as Record<string, Object>
      const requestId = event['requestId'] as string
      if (requestId === undefined || requestId.length === 0 || requestId === this.lastCliUiEventId) {
        return
      }
      this.lastCliUiEventId = requestId
      const commandName = event['commandName'] as string
      const response = event['response'] as StellariumBridgeResponse
      if (commandName === 'startGuide' || commandName === 'guideAction') {
        this.guideStore.executeGuideRequest(commandName, String(event['payload'] ?? ''), requestId)
        return
      }
      if (commandName === 'setSatellitesFlag' && response.ok === true) {
        const parts = String(event['payload'] ?? '').split(':')
        const enabled = parts[1] === '1' || parts[1] === 'true'
        this.satelliteStore.satelliteFlagMutationId++
        if (parts[0] === 'labels') this.satelliteStore.satLabels = enabled
        else if (parts[0] === 'orbitLines') this.satelliteStore.satOrbitLines = enabled
        else if (parts[0] === 'hints') this.satelliteStore.satHints = enabled
        else if (parts[0] === 'iconicMode') this.satelliteStore.satIconicMode = enabled
        else if (parts[0] === 'hideInvisible') this.satelliteStore.satHideInvisible = enabled
        this.publishSatellitePanelState()
        return
      }
      if (commandName === 'setSatellitePanelGroup') {
        this.selectSatelliteGroup(String(event['payload'] ?? '').trim())
        return
      }
      if (commandName === 'setSearchBrowserPage' || commandName === 'selectSearchCategory') {
        if (!this.panelVisible || this.activePanel !== 'search') this.openPanelFromCli('search')
        this.searchStore.searchText = ''
        const value = String(event['payload'] ?? '').trim()
        if (commandName === 'selectSearchCategory') this.selectSearchFilterCategory(value)
        else this.setSearchFilterPage(value === 'browse' ? '' : value)
        this.publishSearchBrowserState()
        return
      }
      if (commandName === 'setSearchBrowserFilter') {
        if (!this.panelVisible || this.activePanel !== 'search') this.openPanelFromCli('search')
        const parts = String(event['payload'] ?? '').split('|')
        if (parts[0] === 'visibility') this.selectSearchVisibilityFilter(parts[1])
        else this.selectSearchInstrumentFilter(parts[1])
        this.publishSearchBrowserState()
        return
      }
      if (commandName === 'setAstroTab' || commandName === 'setAstroGroup') {
        if (this.panelVisible && this.activePanel === 'astro') {
          if (commandName === 'setAstroTab') this.selectAstroTab(Number(event['payload']))
          else this.selectAstroGroup(Number(event['payload']))
        }
        this.publishAstroPanelState()
        return
      }
      if (commandName === 'setAstroFilter') {
        const parts = String(event['payload'] ?? '').split('|')
        this.selectAstroFilter(parts[0], parts[1])
        return
      }
      if (commandName === 'setAstroScroll') {
        this.astroPanelScroller.scrollTo({ xOffset: 0, yOffset: Number(event['payload']), animation: false })
        this.publishAstroPanelState()
        return
      }
      if (commandName === 'setSatellitePanelScroll') {
        const offset = Number(event['payload'])
        if (Number.isFinite(offset) && offset >= 0) {
          this.satellitePanelScroller.scrollTo({ xOffset: 0, yOffset: offset, animation: false })
        }
        this.publishSatellitePanelState()
        return
      }
      if (commandName === 'setObjectDetailTab') {
        if (this.objectDetailStore.selectedName.length > 0) {
          this.infoWindowStore.infoWinVisible = true
          this.selectObjectDetailTab(Number(event['payload']))
        }
        return
      }
      if (commandName === 'setObjectModelView') {
        const value = String(event['payload'] ?? '').trim()
        if (this.objectMediaStore.objectInspectorMediaKind !== 'model') {
          AppStorage.setOrCreate('stellariumObjectModelView', JSON.stringify({
            ok: false, requestId: requestId, error: 'selected object has no 3D model'
          }))
          return
        }
        if (value === 'open') {
          this.infoWindowStore.infoWinVisible = true
          this.selectObjectDetailTab(2)
        } else if (value === 'immersive') {
          this.objectModelRendererCtl().setObjectInspectorModelImmersive(true)
        } else if (value === 'close') {
          this.objectModelRendererCtl().setObjectInspectorModelImmersive(false)
        } else if (value === 'reset') {
          this.objectModelRendererCtl().resetObjectInspectorModelView()
        } else {
          const parts = value.split('|')
          this.objectModelRendererCtl().rotateObjectInspectorModel(Number(parts[0]), Number(parts[1]))
          this.objectModelRendererCtl().requestObjectInspectorModelRender(true)
        }
        return
      }
      if (commandName === 'setMosaicCamera' || commandName === 'getMosaicCamera') {
        if (response.ok === true) this.mosaicStore.loadMosaicCamera(false)
        return
      }
      if (commandName === 'getNebulaTextureStatus' || commandName === 'setNebulaTexturesVisible' ||
        commandName === 'setNebulaTextureConflictAvoidance') {
        if (response.ok === true) this.nebulaTextureStore.nebulaTextureStatus = response as NebulaTextureStatus
        return
      }
      if (commandName === 'setTimeSetting' || commandName === 'getTimeSettings' ||
        commandName === 'setDateFormat' || commandName === 'setTimeFormat') {
        this.applyTimeSettings(response)
        return
      }
      if (commandName === 'setInformationSetting' || commandName === 'getInformationSettings') {
        if (response.ok !== true) return
        this.infoWindowStore.informationMode = response.infoMode ?? this.infoWindowStore.informationMode
        if (response.customInfoMask !== undefined) this.infoWindowStore.informationCustomMask = Number(response.customInfoMask)
        this.applySelectedInfoMode(this.infoWindowStore.informationMode)
        this.objectDetailStore.selectedDetailLoaded = false
        this.refreshSelectedObject()
        return
      }
      if (commandName === 'setLanguage' && response.ok === true) {
        const language = String(event['payload'] ?? '').trim()
        if (language.length > 0) this.setLanguage(language)
        return
      }
      if (commandName === 'openUiPanel') {
        const panel = String(event['payload'] ?? '').trim()
        if (isCliPanelName(panel)) {
          this.openPanelFromCli(panel)
          hilog.info(0x0000, 'StellariumArkUI', '[cli-ui] opened panel=%{public}s', panel)
        } else {
          hilog.warn(0x0000, 'StellariumArkUI', '[cli-ui] rejected panel=%{public}s', panel)
        }
        return
      }
      if (commandName === 'openPluginFeature') {
        const pluginId = String(event['payload'] ?? '').trim()
        if (pluginId.length > 0) {
          this.openPluginFeature(pluginId)
          hilog.info(0x0000, 'StellariumArkUI', '[cli-ui] opened plugin feature=%{public}s', pluginId)
        } else {
          hilog.warn(0x0000, 'StellariumArkUI', '[cli-ui] rejected empty plugin feature')
        }
        return
      }
      if (commandName === 'setLayerTab') {
        const tabId = Number(String(event['payload'] ?? '').trim())
        if (this.activePanel === 'layers' && this.panelVisible && Number.isInteger(tabId) && tabId >= 0 && tabId <= 6) {
          this.selectViewTab(tabId)
          hilog.info(0x0000, 'StellariumArkUI', '[cli-ui] layer tab=%{public}d', tabId)
        } else {
          hilog.warn(0x0000, 'StellariumArkUI', '[cli-ui] rejected layer tab=%{public}s', String(event['payload'] ?? ''))
        }
        return
      }
      if (commandName === 'setSkyCultureMakerTab') {
        const tabId = Number(String(event['payload'] ?? '').trim())
        if (this.activePanel === 'skyCultureMaker' && this.panelVisible && Number.isInteger(tabId) && tabId >= 0 && tabId <= 2) {
          this.skyCultureMakerStore.tab = tabId
          hilog.info(0x0000, 'StellariumArkUI', '[cli-ui] sky culture maker tab=%{public}d', tabId)
        } else {
          hilog.warn(0x0000, 'StellariumArkUI', '[cli-ui] rejected sky culture maker tab=%{public}s', String(event['payload'] ?? ''))
        }
        return
      }
      if (commandName === 'setGyroscopeEnabled') {
        const value = String(event['payload'] ?? '').trim().toLowerCase()
        if (value === '1' || value === 'true' || value === 'on') {
          this.gyroCtl().toggleGyroscope(true)
          hilog.info(0x0000, 'StellariumArkUI', '[cli-ui] gyroscope enabled=true')
        } else if (value === '0' || value === 'false' || value === 'off') {
          this.gyroCtl().toggleGyroscope(false)
          hilog.info(0x0000, 'StellariumArkUI', '[cli-ui] gyroscope enabled=false')
        } else {
          hilog.warn(0x0000, 'StellariumArkUI', '[cli-ui] rejected gyroscope value=%{public}s', value)
        }
        return
      }
      if (commandName === 'setTelescopeLivePosition') {
        const value = String(event['payload'] ?? '').trim().toLowerCase()
        const enabled = value === '1' || value === 'true' || value === 'on'
        this.telescopeStore.setTelescopeLivePosition(enabled)
        hilog.info(0x0000, 'StellariumArkUI', '[cli-ui] telescope live position enabled=%{public}s', enabled.toString())
        return
      }
      if (commandName === 'setSkyCulture' && response.ok === true) {
        const cultureId = response.cultureId !== undefined
          ? String(response.cultureId)
          : String(event['payload'] ?? '').trim()
        if (cultureId.length > 0) {
          this.captureSkyCultureAnchor(cultureId)
          this.skyCultureViewStore.pendingId = cultureId
          this.skyCultureViewStore.currentSkyCultureId = cultureId
          this.loadSkyCultureDetails()
          hilog.info(0x0000, 'StellariumArkUI', '[cli-ui] sky culture=%{public}s', cultureId)
        }
        return
      }
      if (commandName === 'closeUiPanel') {
        this.closePanel(true)
        hilog.info(0x0000, 'StellariumArkUI', '[cli-ui] closed panel')
        return
      }
      if (commandName === 'playScript' && response.ok === true) {
        this.scriptStore.scriptFocusActive = true
        this.scriptStore.scriptLaunching = false
        this.scriptStore.scriptLaunchingName = ''
        this.scriptStore.scriptId = String(event['payload'] ?? '')
        this.scriptStore.scriptStartGraceUntil = Date.now() + 2500
        this.panelVisible = false
        this.infoWindowStore.infoWinVisible = false
        this.startScriptStatusPolling()
        return
      }
      if (commandName === 'continueScript' && response.ok === true) {
        this.getUIContext().animateTo({ duration: 160, curve: Curve.EaseOut }, () => {
          this.scriptStore.scriptWaiting = false
          this.scriptStore.scriptWaitMessage = ''
        })
        return
      }
      if (commandName === 'setScriptRate' && response.ok === true) {
        const rate = Number(String(event['payload'] ?? '').trim())
        if (Number.isFinite(rate) && rate > 0) {
          this.scriptStore.scriptRate = rate
        }
        return
      }
      if (commandName === 'stopScript' && response.ok === true && this.scriptStore.scriptSessionActive(this.tools.recording, this.guideStore.guideState.active)) {
        this.finishNativeScriptUi(I18n.t('script_stopped'))
        return
      }
      if (commandName === 'backUiPanel') {
        this.goBackPanel()
        hilog.info(0x0000, 'StellariumArkUI', '[cli-ui] navigated back')
        return
      }
      if ((commandName === 'setObjectDetailConnector' || commandName === 'getObjectDetailConnector') &&
        (response as Record<string, Object>)['enabled'] !== undefined) {
        const enabled = (response as Record<string, Object>)['enabled'] as boolean
        this.setObjectDetailConnector(enabled, false)
        hilog.info(0x0000, 'StellariumArkUI', '[cli-ui] detail connector=%{public}s', enabled.toString())
        return
      }
      if (commandName === 'clearSelection' || response.found !== true) {
        this.applySelectedObject(response)
        return
      }
      this.applySelectedObject(response, false, 'center')
      hilog.info(0x0000, 'StellariumArkUI',
        '[cli-ui] selection synchronized command=%{public}s name=%{public}s',
        commandName, this.objectDetailStore.selectedName)
    } catch (err) {
      hilog.warn(0x0000, 'StellariumArkUI', '[cli-ui] event ignored: %{public}s', JSON.stringify(err))
    }
  }

  private startPageAfterPrivacyIfNeeded(): void {
    if (!this.privacyNativeStartupAllowed || this.privacyPageStartupStarted) {
      return
    }
    this.privacyPageStartupStarted = true
    this.startTwinkle()
    // Keep the old AppStorage value as a migration fallback while the durable
    // preferences store is opened asynchronously.
    const stored = AppStorage.get<string>("observingList")
    if (stored) this.obsListStore.observingList = parseObservingList(stored)
    this.obsListStore.loadObservingListFromStorage()
    this.searchStore.loadSearchHistoryFromStorage()
    this.bookmarkStore.loadBookmarksFromStorage()
    this.registerFoldListeners()
    this.subscribeApplicationLifecycle()
    this.startupBridge().startupBridgeSync()
  }

  private saveAppSettings(): void {
    AppStorage.setOrCreate("stellariumSettings", JSON.stringify({
      nightMode: this.nightModeStore.nightMode,
      equatorialMount: this.telescopeStore.equatorialMount,
      gyroscopeEnabled: this.gyroStore.gyroscopeEnabled,
      gyroscopeSensitivityText: this.gyroStore.gyroscopeSensitivityText,
      selectedLanguage: this.languageStore.selectedLanguage,
      useMetricUnits: this.viewSettingsStore.useMetricUnits,
      musicEnabled: this.audioStore.musicEnabled,
      viewCoordinatesVisible: this.overlayStore.viewCoordinatesVisible,
      viewCoordinateFamily: this.overlayStore.viewCoordinateFamily,
      viewEquatorialEpoch: this.overlayStore.viewEquatorialEpoch,
      objectDetailConnectorVisible: this.overlayStore.objectDetailConnectorVisible,
      astroTab: this.astroStore.astroTab.toString(),
      astroGroup: this.astroStore.astroGroup.toString(),
      positionMode: this.astroStore.positionMode.toString(),
      celestialPositionCategory: this.astroStore.celestialPositionCategory,
      celestialPositionMagnitude: this.astroStore.celestialPositionMagnitude.toString(),
      celestialPositionHorizontal: this.astroStore.celestialPositionHorizontal.toString(),
      ephemerisMode: this.astroStore.ephemerisMode.toString(),
      ephemerisDays: this.astroStore.ephemerisDays.toString(),
      ephemerisStepHours: this.astroStore.ephemerisStepHours.toString(),
      rtsCalendarDays: this.astroStore.rtsCalendarDays.toString(),
      graphMode: this.astroStore.graphMode.toString(),
      eclipseMonths: this.astroStore.eclipseMonths.toString(),
      moonPhaseDays: this.astroStore.moonPhaseDays.toString()
    }))
  }

  // 启动期自动定位（只触发一次）。GPS 可用时更新为真实位置，不可用时回退到已保存/默认位置。
  aboutToDisappear(): void {
    this.guideStore.stopGuideTimer()
    this.guideStore.guideGyroWasEnabled = false
    this.guideStore.guidePanelWasVisible = false
    this.guideStore.stopPlayer()
    if (this.skyCultureMakerSaveTimer > 0) {
      clearTimeout(this.skyCultureMakerSaveTimer)
      this.skyCultureMakerSaveTimer = 0
      this.saveSkyCultureMakerDraft(true)
    }
    if (this.searchSuggestionTimer >= 0) {
      clearTimeout(this.searchSuggestionTimer)
      this.searchSuggestionTimer = -1
    }
    this.saveAppSettings()
    this.skyInputCtl().stop()
    this.gyroCtl().stopGyroscope(false)
    this.stopDetailAutoRefresh()
    this.stopObjectDetailConnectorRefresh()
    this.stopObjectInspectorMediaWarmup()
    this.stopBodyDetailWarmup()
    this.clearObjectInspectorDecodedImage()
    this.skyCultureArtDecodeGeneration++
    this.clearSkyCultureArtThumbnails()
    if (this.stateRefreshTimer >= 0) {
      clearTimeout(this.stateRefreshTimer)
      this.stateRefreshTimer = -1
    }
    if (this.panelDataLoadTimer >= 0) {
      clearTimeout(this.panelDataLoadTimer)
      this.panelDataLoadTimer = -1
    }
    this.stateRefreshRequestPending = false
    this.stateRefreshQueued = false
    const skyCulturePixelMap = this.skyCultureViewStore.artPreviewPixelMap
    this.skyCultureViewStore.artPreviewPixelMap = undefined
    releaseDecodedImage(this.hostMediaPort, skyCulturePixelMap, 'disappear-sky-culture-art')
    this.clearSkyCultureMakerArtworkPreview('disappear-sky-culture-maker-artwork')
    this.stopSkyTextureStatusObserver()
    this.stopTimePanelTimers()
    this.stopViewCoordinateTimer()
    this.stopDockClockTimer()
    if (this.timeWheelController !== undefined) { this.timeWheelController.stop() }
    this.stopSkyCultureTimeFollowTimer()
    this.stopPolarScopeTimer()
    this.stopAstroCalcContextTimer()
    this.telescopeStore.stopTelescopeLivePosition(false)
    this.stopScriptStatusPolling()
    this.recordingCtl().stop()
    this.unregisterFoldListeners()
    this.unsubscribeApplicationLifecycle()
  }

  private handleApplicationLifecycle = (foreground: boolean): void => {
    this.applicationInForeground = foreground
    if (!foreground && this.guideStore.guideState.phase === 'observing') this.guideStore.pausePlayer()
    this.objectModelRendererCtl().setForeground(foreground)
    if (foreground) {
      if (this.foregroundRefreshPaused) {
        this.foregroundRefreshPaused = false
        if (this.activePanel === 'time' && this.panelVisible) {
          this.timeStore.loadTimeExtras()
          this.timePanelTimer = setInterval(() => { this.refreshSimTimeLight() }, 125)
          this.timePanelFullTimer = setInterval(() => {
            this.refreshState()
            this.timeStore.loadTimeExtras()
          }, 3000)
        }
        if (this.objectDetailStore.selectedStatus === 'Selected' && ((this.activePanel === 'object' && this.panelVisible) || this.infoWindowStore.infoWinVisible)) {
          this.startDetailAutoRefresh()
        }
      }
      if (this.audioStore.musicEnabled) {
        void AudioEngine.getInstance().start()
      }
      this.gyroCtl().resumeAfterForeground()
      this.syncViewCoordinateTimer()
      this.syncDockClockTimer()
      this.syncSkyCultureTimeFollowTimer()
      this.syncPolarScopeTimer()
      this.syncAstroCalcContextTimer()
      this.telescopeStore.syncTelescopeLivePosition()
      return
    }

    // This app declares no background task. Stop ArkUI polling and audio
    // rendering as soon as the Ability leaves the foreground.
    this.foregroundRefreshPaused = this.timePanelTimer !== 0 || this.detailTimer !== 0
    this.stopTimePanelTimers()
    this.stopViewCoordinateTimer()
    this.stopDockClockTimer()
    if (this.timeWheelController !== undefined) { this.timeWheelController.stop() }
    this.stopSkyCultureTimeFollowTimer()
    this.stopPolarScopeTimer()
    this.stopAstroCalcContextTimer()
    this.telescopeStore.stopTelescopeLivePosition(false)
    this.stopDetailAutoRefresh()
    this.skyInputCtl().stop()
    void AudioEngine.getInstance().stop()
    this.gyroCtl().pauseForBackground()
  }

  private subscribeApplicationLifecycle(): void {
    setLifecycleListener(this.handleApplicationLifecycle)
  }

  private unsubscribeApplicationLifecycle(): void {
    setLifecycleListener(undefined)
  }

  /** 停掉时间面板的高频/低频两个刷新定时器 */
  private stopTimePanelTimers(): void {
    if (this.timePanelTimer !== 0) {
      clearInterval(this.timePanelTimer)
      this.timePanelTimer = 0
    }
    if (this.timePanelFullTimer !== 0) {
      clearInterval(this.timePanelFullTimer)
      this.timePanelFullTimer = 0
    }
  }

  private shouldFollowSkyCultureSimulationTime(): boolean {
    return this.applicationInForeground && this.activePanel === 'layers' && this.panelVisible &&
      this.viewTab === 5 && this.skyCultureSettingsStore.skyCultureTimeFiltering && !this.skyCultureSettingsStore.skyCultureRangeFiltering && this.skyCultureSettingsStore.skyCultureTimeFollowSimulation
  }

  private stopSkyCultureTimeFollowTimer(): void {
    if (this.skyCultureTimeFollowTimer !== 0) {
      clearInterval(this.skyCultureTimeFollowTimer)
      this.skyCultureTimeFollowTimer = 0
    }
    this.skyCultureTimeFollowRequestPending = false
  }

  private syncSkyCultureTimeFollowTimer(): void {
    if (!this.shouldFollowSkyCultureSimulationTime()) {
      this.stopSkyCultureTimeFollowTimer()
      return
    }
    if (this.skyCultureTimeFollowTimer !== 0) return
    this.refreshSkyCultureSimulationYear()
    this.skyCultureTimeFollowTimer = setInterval(() => {
      this.refreshSkyCultureSimulationYear()
    }, 500)
  }

  private shouldRefreshPolarScope(): boolean {
    return this.applicationInForeground && this.polarScopeStore.polarScopeVisible
  }

  private stopPolarScopeTimer(): void {
    if (this.polarScopeTimer !== 0) {
      clearInterval(this.polarScopeTimer)
      this.polarScopeTimer = 0
    }
    this.polarScopeStore.cancelPolarScopeRequest()
  }

  private syncPolarScopeTimer(): void {
    if (!this.shouldRefreshPolarScope()) {
      this.stopPolarScopeTimer()
      return
    }
    this.polarScopeStore.loadPolarScopeData()
    if (this.polarScopeTimer === 0) {
      this.polarScopeTimer = setInterval(() => { this.polarScopeStore.loadPolarScopeData(false) }, 1000)
    }
  }

  private shouldRefreshAstroCalcContext(): boolean {
    return this.applicationInForeground && this.activePanel === 'astro' && this.panelVisible
  }

  private stopAstroCalcContextTimer(): void {
    if (this.astroContextTimer !== 0) {
      clearInterval(this.astroContextTimer)
      this.astroContextTimer = 0
    }
    this.astroStore.cancelAstroCalcContext()
  }

  private syncAstroCalcContextTimer(): void {
    if (!this.shouldRefreshAstroCalcContext()) {
      this.stopAstroCalcContextTimer()
      return
    }
    if (this.astroContextTimer !== 0) return
    this.astroStore.loadAstroCalcContext()
    this.astroContextTimer = setInterval(() => { this.astroStore.loadAstroCalcContext() }, 1000)
  }

  private shouldRefreshTelescopePosition(): boolean {
    return this.telescopeStore.lx200LivePositionEnabled && this.applicationInForeground && this.panelVisible &&
      this.activePanel === 'telescope' && !this.telescopeStore.lx200EditingNew
  }

  // §14 B3-4：stopTelescopeLivePosition / scheduleTelescopeLivePosition / refreshTelescopeLivePosition /
  // syncTelescopeLivePosition / setTelescopeLivePosition（及其 timer / pending / requestId 三字段）
  // 已整体搬入 state/TelescopeStore.ets（store 自持 start/stop）；宿主保留上面的生命周期谓词
  // shouldRefreshTelescopePosition 经 TelescopeHostHooks 注入。

  private enterPolarScope(): void {
    if (this.polarScopeStore.polarScopeVisible) {
      this.closePolarScope()
      return
    }
    if (this.polarScopeTransitionPending) return
    const transitionId = ++this.polarScopeTransitionId
    this.polarScopeTransitionPending = true
    this.polarScopeStore.polarScopeLoading = true
    this.polarScopeStore.polarScopeError = ''
    this.polarScopeStore.polarScopeData = undefined
    this.activePanel = 'polarScope'
    this.panelVisible = false
    this.polarScopeStore.polarScopeVisible = true
    this.syncNativePolarScopeOverlay(false)
    this.callNativeWhenReady('getSessionState', '', (response: StellariumBridgeResponse) => {
      if (transitionId !== this.polarScopeTransitionId) return
      const snapshot: SessionSnapshot = {
        viewJ2000: response.viewJ2000,
        fovDeg: response.fovDeg,
        jd: response.jd,
        location: response.location,
        selected: response.selected,
        flags: response.flags
      }
      this.polarScopeRestoreState = JSON.stringify(snapshot)
      const flags = response.flags as Record<string, Object>
      this.polarScopeStore.polarScopeHorizontalFlip = flags !== undefined && flags['flipHorz'] === true
      this.polarScopeStore.polarScopeVerticalFlip = flags !== undefined && flags['flipVert'] === true
      const location = response.location as Record<string, Object>
      const planetName = response.location && location['planetName'] !== undefined
        ? String(location['planetName']) : 'Earth'
      if (planetName !== 'Earth') {
        this.polarScopeTransitionPending = false
        this.polarScopeStore.polarScopeLoading = false
        this.polarScopeStore.polarScopeError = I18n.t('polar_scope_earth_only')
        return
      }
      this.callNativeWhenReady('centerPolarScope', '', () => {
        if (transitionId !== this.polarScopeTransitionId) return
        this.callNativeWhenReady('setFOV', '4', () => {
          if (transitionId !== this.polarScopeTransitionId) return
          this.polarScopeTransitionPending = false
          this.syncNativePolarScopeOverlay(true)
          this.syncPolarScopeTimer()
        }, 0, 100, 15, () => {
          if (transitionId !== this.polarScopeTransitionId) return
          this.polarScopeTransitionPending = false
          this.polarScopeStore.polarScopeLoading = false
          this.polarScopeStore.polarScopeError = I18n.t('polar_scope_open_failed')
        })
      }, 0, 100, 15, () => {
        if (transitionId !== this.polarScopeTransitionId) return
        this.polarScopeTransitionPending = false
        this.polarScopeStore.polarScopeLoading = false
        this.polarScopeStore.polarScopeError = I18n.t('polar_scope_open_failed')
      })
    }, 0, 120, 20, () => {
      if (transitionId !== this.polarScopeTransitionId) return
      this.polarScopeTransitionPending = false
      this.polarScopeStore.polarScopeLoading = false
      this.polarScopeStore.polarScopeError = I18n.t('polar_scope_open_failed')
      this.syncNativePolarScopeOverlay(false)
    })
  }

  private closePolarScope(): void {
    if (!this.polarScopeStore.polarScopeVisible && !this.polarScopeTransitionPending) return
    ++this.polarScopeTransitionId
    this.polarScopeStore.polarScopeVisible = false
    this.stopPolarScopeTimer()
    this.polarScopeStore.polarScopeLoading = false
    this.syncNativePolarScopeOverlay(false)
    this.polarScopeTransitionPending = false
    const restoreState = this.polarScopeRestoreState
    this.polarScopeRestoreState = ''
    if (restoreState.length === 0) return
    this.polarScopeTransitionPending = true
    const restoreTransitionId = this.polarScopeTransitionId
    this.callNativeWhenReady('applySessionState', restoreState, () => {
      if (restoreTransitionId !== this.polarScopeTransitionId) return
      this.polarScopeTransitionPending = false
      this.refreshState()
    }, 0, 120, 20, () => {
      if (restoreTransitionId !== this.polarScopeTransitionId) return
      this.polarScopeTransitionPending = false
      this.flashHint(I18n.t('polar_scope_restore_failed'))
    })
  }

  private syncNativePolarScopeOverlay(active: boolean): void {
    const height = Math.max(1, this.skyHeight)
    const safeTopRatio = (this.polarScopeTopInset() + 68) / height
    const safeBottomRatio = (this.polarScopeFooterHeight() + 20) / height
    const payload = (active ? '1' : '0') + '|' + (this.polarScopeStore.polarScopeHorizontalFlip ? '1' : '0') + '|' +
      (this.polarScopeStore.polarScopeVerticalFlip ? '1' : '0') + '|' + safeTopRatio.toString() + '|' + safeBottomRatio.toString() +
      '|' + Math.max(0, Math.round(this.screenSafeTopPixels)).toString()
    this.callNativeWhenReady('setPolarScopeOverlay', payload, () => {})
  }

  private polarScopeTopInset(): number {
    const safeTop = this.getUIContext().px2vp(Math.max(0, this.screenSafeTopPixels))
    return Math.max(8, safeTop + 8)
  }

  private polarScopeControlWidth(): number {
    return Math.max(0, Math.min(520, this.skyWidth - 32))
  }

  private polarScopeFooterHeight(): number {
    return this.isExpandedLayout ? 148 : 176
  }

  private recenterPolarScope(): void {
    if (this.polarScopeTransitionPending) return
    this.callInteractive('centerPolarScope', '', () => {
      this.callInteractive('setFOV', '4', () => { this.polarScopeStore.loadPolarScopeData(false) })
    })
  }

  private setPolarScopeHorizontalFlip(value: boolean): void {
    if (value === this.polarScopeStore.polarScopeHorizontalFlip) return
    this.polarScopeStore.polarScopeHorizontalFlip = value
    this.syncNativePolarScopeOverlay(true)
    this.callInteractive('setActionChecked', 'actionHorizontal_Flip|' + (value ? '1' : '0'), () => {
      this.polarScopeStore.loadPolarScopeData(false)
    }, () => {
      this.polarScopeStore.polarScopeHorizontalFlip = !value
    })
  }

  private setPolarScopeVerticalFlip(value: boolean): void {
    if (value === this.polarScopeStore.polarScopeVerticalFlip) return
    this.polarScopeStore.polarScopeVerticalFlip = value
    this.syncNativePolarScopeOverlay(true)
    this.callInteractive('setActionChecked', 'actionVertical_Flip|' + (value ? '1' : '0'), () => {
      this.polarScopeStore.loadPolarScopeData(false)
    }, () => {
      this.polarScopeStore.polarScopeVerticalFlip = !value
    })
  }

  private mediaPreviewTopInset(): number {
    const safeTop = this.getUIContext().px2vp(Math.max(0, this.screenSafeTopPixels))
    return Math.max(18, safeTop + 12)
  }

  private refreshSkyCultureSimulationYear(force: boolean = false): void {
    if ((!force && !this.shouldFollowSkyCultureSimulationTime()) || this.skyCultureTimeFollowRequestPending) return
    this.skyCultureTimeFollowRequestPending = true
    this.callInteractive('getSimulationTime', '', (r: StellariumBridgeResponse) => {
      this.skyCultureTimeFollowRequestPending = false
      if (r.ok !== true || r.year === undefined) return
      this.skyCultureSettingsStore.skyCultureSimulationYear = Math.round(r.year)
      if (force || this.shouldFollowSkyCultureSimulationTime()) {
        this.skyCultureSettingsStore.setSkyCultureTimeYear(this.skyCultureSettingsStore.skyCultureSimulationYear)
      }
    }, () => {
      this.skyCultureTimeFollowRequestPending = false
    })
  }

  private openPanelFromCli(panel: string): void {
    if (panel === 'settingsInformation' || panel === 'settingsTime' || panel === 'settingsPrivacy') {
      this.openPanelFromCli('settings')
      this.selectConfigTab(panel === 'settingsInformation' ? 1 : (panel === 'settingsTime' ? 3 : -1))
      return
    }
    const parent = panelRouteParent(panel)
    this.panelNavigationStack = parent.length > 0 ? [parent] : []
    this.panelNavigationDepth = this.panelNavigationStack.length
    this.setPanel(panel, true, true)
  }

  private setPanel(panel: string, preserveHistory: boolean = false, forceVisible: boolean = false, routeDirection: number = 0): void {
    if (!preserveHistory) {
      this.panelNavigationStack = []
      this.panelNavigationDepth = 0
    }
    // “应用配置”已并入“设置”；保留旧面板名兼容历史命令和书签。
    if (panel === 'config') panel = 'settings'
    // 天体详情是跨设备的独立浮动卡片，不再打开第二个“对象”面板。
    if (panel === 'object') {
      this.toggleObjectInspector()
      return
    }
    // 插件管理和设置共用同一套界面，直达入口只负责选中对应标签。
    if (panel === 'pluginManager') {
      this.configTab = 6
      panel = 'settings'
    } else if (panel === 'settings' && this.configTab >= 4 && this.configTab <= 6) {
      this.configTab = 0
    }
    if (panel === 'polarScope') {
      this.enterPolarScope()
      return
    }
    const currentPanel = this.activePanel
    const resolvedRouteDirection = routeDirection === 0
      ? inferredPanelRouteDirection(currentPanel, panel)
      : (routeDirection < 0 ? -1 : 1)
    hilog.info(0x0000, 'StellariumArkUI', 'setPanel ' + panel)
    const nextVisible = forceVisible ? true : (this.activePanel === panel ? !this.panelVisible : true)
    const switchingPanel = this.panelVisible && nextVisible && this.activePanel !== panel
    this.panelRouteDirection = resolvedRouteDirection
    if (switchingPanel) {
      hilog.info(0x0000, 'StellariumArkUI', '[panel-transition] direction=%{public}d from=%{public}s to=%{public}s',
        resolvedRouteDirection, currentPanel, panel)
    }
    const routeSerial = nextVisible ? this.beginPanelRouteTransition(switchingPanel) : 0
    if (panel !== 'object') {
      this.fullInspectorRequested = false
      this.infoWindowStore.infoWinExpanded = false
    }
    this.stopTimePanelTimers()
    this.stopSkyCultureTimeFollowTimer()
    this.stopPolarScopeTimer()
    this.stopAstroCalcContextTimer()
    this.telescopeStore.stopTelescopeLivePosition(false)
    if (!nextVisible) {
      this.schedulePanelDataLoad(panel, false)
      const closeSerial = ++this.panelContentKey
      const closeDirection = this.panelRouteDirection
      this.getUIContext().animateTo({ duration: 170, curve: Curve.EaseIn, onFinish: () => {
        if (this.panelContentKey !== closeSerial) return
        this.panelVisible = false
        this.panelRouteOpacity = 1
        this.panelRouteOffsetX = 0
        this.panelPresentationOpacity = 1
        this.panelPresentationOffsetY = 0
        if (panel === 'object') {
          this.fullInspectorRequested = false
          this.infoWindowStore.infoWinExpanded = false
        }
      } }, () => {
        this.panelRouteOpacity = 0
        this.panelRouteOffsetX = -closeDirection * 18
        this.panelPresentationOpacity = 0
        this.panelPresentationOffsetY = this.isExpandedLayout ? 0 : 18
      })
      this.scheduleSelectedObjectForUiChange(220)
      return
    }
    if (switchingPanel) {
      const direction = this.panelRouteDirection
      this.schedulePanelDataLoad(panel, false)
      this.getUIContext().animateTo({ duration: 145, curve: Curve.EaseIn, onFinish: () => {
        if (this.panelContentKey !== routeSerial) return
        this.activePanel = panel
        this.panelVisible = true
        this.panelRouteOpacity = 0
        this.panelRouteOffsetX = direction * 10
        this.resetPanelIdle()
        this.schedulePanelDataLoad(panel, true)
        this.scheduleSelectedObjectForUiChange(380)
        this.finishPanelRouteTransition(routeSerial)
      } }, () => {
        if (this.panelContentKey !== routeSerial) return
        this.panelRouteOpacity = 0
        this.panelRouteOffsetX = -direction * 18
      })
      return
    }
    this.activePanel = panel
    this.panelVisible = true
    this.resetPanelIdle()
    this.schedulePanelDataLoad(panel, true)
    this.scheduleSelectedObjectForUiChange(380)
    this.finishPanelRouteTransition(routeSerial)
  }

  private schedulePanelDataLoad(panel: string, visible: boolean): void {
    if (this.panelDataLoadTimer >= 0) {
      clearTimeout(this.panelDataLoadTimer)
      this.panelDataLoadTimer = -1
    }
    if (!visible) return
    this.panelDataLoadTimer = setTimeout(() => {
      this.panelDataLoadTimer = -1
      if (!this.panelVisible || this.activePanel !== panel) return
      this.syncSkyCultureTimeFollowTimer()
      this.syncPolarScopeTimer()
      if (panel === 'place') {
        this.refreshTonight()
      }
      if (panel === 'observing' && !this.wutStore.wutHasResult && !this.wutStore.wutLoading) {
        this.wutStore.loadWutTargets()
      }
      if (panel === 'search') {
        this.catalogStore.loadObjectCatalogCategories(this.languageStore.languageRefreshSerial)
        this.searchStore.loadConstellationNavigation(this.languageStore.languageRefreshSerial)
        if (this.searchStore.categoryObjects.length === 0) this.searchStore.loadCategoryObjects(this.searchStore.searchCategory)
      }
      if (panel === 'time') {
        this.timeStore.loadTimeExtras()
        this.ensurePluginLoaded('EquationOfTime', () => { this.equationOfTimeStore.loadEquationOfTime() })
        this.timePanelTimer = setInterval(() => { this.refreshSimTimeLight() }, 125)
        this.timePanelFullTimer = setInterval(() => {
          this.refreshState()
          this.timeStore.loadTimeExtras()
        }, 3000)
      }
      if (panel === 'astro') {
        this.publishAstroPanelState()
        this.astroStore.loadAstroTab(this.astroStore.astroTab)
      } else if (panel === 'layers') {
        this.refreshState()
        if (this.viewTab === 4) this.layerViewStore.loadLandscapeList()
      } else if (panel === 'settings') {
        this.refreshState()
        this.catalogStore.loadCatalogHealth()
        this.timeSettingsStore.loadConfigurationSettings()
        if (this.configTab === 6) this.pluginStore.loadPluginList()
      } else if (panel === 'place') {
        this.refreshState()
        this.sessionToolStore.loadPlanetList()
        this.locationPickerStore.loadObserverInfo()
        this.locationStore.loadSavedLocations()
      } else if (panel === 'catalogs' && !OFFLINE_APPGALLERY_BUILD) {
        if (this.catalogStore.catalogList.length === 0) this.catalogStore.loadStarCatalogs()
      } else if (panel === 'bookmarks') {
        this.bookmarkStore.loadBookmarks()
      } else if (panel === 'oculars') {
        this.ensurePluginLoaded('Oculars', () => { this.telescopeStore.loadOculars(false) })
      } else if (panel === 'mosaicCamera') {
      this.ensurePluginLoaded('MosaicCamera', () => { this.mosaicStore.loadMosaicCamera() })
    } else if (panel === 'archaeoLines') {
      this.ensurePluginLoaded('ArchaeoLines', () => { this.archaeoStore.loadArchaeoLines() })
      } else if (panel === 'angleMeasure') {
        this.ensurePluginLoaded('AngleMeasure', () => { this.tools.loadAngleMeasure() })
      } else if (panel === 'navStars') {
        this.ensurePluginLoaded('NavStars', () => { this.navStarsStore.loadNavStars(false) })
      } else if (panel === 'satellites') {
        this.catalogStore.loadCatalogHealth()
        this.ensurePluginLoaded('Satellites', () => { this.satelliteStore.loadSatellites(true, true) })
      } else if (panel === 'meteorshowers') {
        this.ensurePluginLoaded('MeteorShowers', () => { this.meteorStore.loadMeteorShowers() })
      } else if (panel === 'scenery3d') {
        this.ensurePluginLoaded('Scenery3d', () => { this.sceneryStore.loadScenery3d() })
      } else if (panel === 'nebulaTextures') {
        this.ensurePluginLoaded('NebulaTextures', () => { this.nebulaTextureStore.loadNebulaTextureStatus() })
      } else if (panel === 'skyCultureMaker') {
        this.skyCultureMakerStore.loadSkyCultureMakerDraft()
      } else if (panel === 'pointerCoordinates') {
        this.ensurePluginLoaded('PointerCoordinates', () => { this.overlayStore.loadPointerCoordinates() })
      } else if (panel === 'observing') {
      } else if (panel === 'commands') {
        this.commandStore.loadCommandCatalog()
      } else if (panel === 'help') {
        this.tools.loadAboutInfo()
      } else if (panel === 'scripts') {
        this.scriptStore.loadScriptList()
        this.scriptStore.loadRecordings()
        this.scriptStore.loadVideoRecordingState()
      } else if (panel === 'telescope') {
        this.telescopeStore.loadTelescopeControlStatus()
      }
    }, 280) as number
  }

  private beginPanelRouteTransition(switchingPanel: boolean): number {
    const serial = this.panelContentKey + 1
    this.panelContentKey = serial
    this.panelRouteOpacity = switchingPanel ? 1 : 0
    this.panelRouteOffsetX = 0
    if (!switchingPanel) {
      this.panelPresentationOpacity = 0
      this.panelPresentationOffsetY = this.isExpandedLayout ? 0 : 24
    }
    hilog.info(0x0000, 'StellariumArkUI', '[panel-transition] begin serial=%{public}d switching=%{public}s', serial, switchingPanel.toString())
    return serial
  }

  private finishPanelRouteTransition(serial: number): void {
    if (serial <= 0) return
    setTimeout(() => {
      if (this.panelContentKey !== serial) return
      this.resetPanelScroll(this.isExpandedLayout ? this.widePanelScroller : this.compactPanelScroller)
      this.getUIContext().animateTo({ duration: 320, curve: curves.springMotion(0.46, 0.86) }, () => {
        if (this.panelContentKey !== serial) return
        this.panelRouteOpacity = 1
        this.panelRouteOffsetX = 0
        this.panelPresentationOpacity = 1
        this.panelPresentationOffsetY = 0
        hilog.info(0x0000, 'StellariumArkUI', '[panel-transition] finish serial=%{public}d panel=%{public}s', serial, this.activePanel)
      })
    }, 16)
  }

  private resetPanelScroll(scroller: Scroller): void {
    try {
      scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false })
    } catch (error) {
      hilog.warn(0x0000, 'StellariumArkUI', 'reset panel scroll failed: %{public}s', String(error))
    }
  }

  private openSubPanel(panel: string): void {
    if (this.activePanel !== panel && this.panelVisible) {
      this.panelNavigationStack = this.panelNavigationStack.concat([this.activePanel])
      this.panelNavigationDepth = this.panelNavigationStack.length
    }
    this.setPanel(panel, true, true)
  }

  private canGoBackPanel(): boolean {
    return this.panelNavigationStack.length > 0 || panelRouteParent(this.activePanel).length > 0
  }

  private handlePanelBackTap(): void {
    const now = Date.now()
    if (now - this.lastPanelBackAt < 240) return
    this.lastPanelBackAt = now
    hilog.info(0x0000, 'StellariumArkUI', '[panel-back] panel=%{public}s stack=%{public}d parent=%{public}s',
      this.activePanel, this.panelNavigationStack.length, panelRouteParent(this.activePanel))
    this.goBackPanel()
  }


  private goBackPanel(): void {
    let previous = ''
    if (this.panelNavigationStack.length > 0) {
      previous = this.panelNavigationStack[this.panelNavigationStack.length - 1]
      this.panelNavigationStack = this.panelNavigationStack.slice(0, this.panelNavigationStack.length - 1)
    } else {
      previous = panelRouteParent(this.activePanel)
    }
    if (previous.length === 0) {
      this.closePanel(true)
      return
    }
    this.panelNavigationDepth = this.panelNavigationStack.length
    this.setPanel(previous, true, true, -1)
  }

  private closePanel(force: boolean = false): void {
    if (this.viewSettingsStore.uiLocked && !force) {
      return
    }
    if (this.polarScopeStore.polarScopeVisible) {
      this.closePolarScope()
      return
    }
    // 关面板时停掉时间面板定时器，避免后台空转
    this.stopTimePanelTimers()
    this.stopSkyCultureTimeFollowTimer()
    this.stopPolarScopeTimer()
    this.stopAstroCalcContextTimer()
    this.telescopeStore.stopTelescopeLivePosition(false)
    if (this.panelDataLoadTimer >= 0) {
      clearTimeout(this.panelDataLoadTimer)
      this.panelDataLoadTimer = -1
    }
    if (this.activePanel === 'search') {
      this.graphTargetPickerActive = false
      this.rtsTargetPickerActive = false
      this.ephemerisTargetPickerActive = false
    }
    const closingObjectPanel = this.activePanel === 'object'
    this.panelNavigationStack = []
    this.panelNavigationDepth = 0
    const closeSerial = ++this.panelContentKey
    const closeDirection = this.panelRouteDirection
    this.getUIContext().animateTo({ duration: 170, curve: Curve.EaseIn, onFinish: () => {
      if (this.panelContentKey !== closeSerial) return
      this.panelVisible = false
      this.panelRouteOpacity = 1
      this.panelRouteOffsetX = 0
      this.panelPresentationOpacity = 1
      this.panelPresentationOffsetY = 0
      if (closingObjectPanel) {
        this.fullInspectorRequested = false
        this.infoWindowStore.infoWinExpanded = false
      }
    } }, () => {
      this.panelRouteOpacity = 0
      this.panelRouteOffsetX = -closeDirection * 18
      this.panelPresentationOpacity = 0
      this.panelPresentationOffsetY = this.isExpandedLayout ? 0 : 18
    })
    this.scheduleSelectedObjectForUiChange(220)
  }

  private callNative(name: string, payload: string = ''): StellariumBridgeResponse {
    const r = BridgeClient.request(name, payload)
    // 录制：仅在录制开启、非回放、且命令可录制时记录，并对短时重试用去重窗口避免重复。
    if (r.ok === true) { this.recordingCtl().recordAcceptedCommand(name, payload) }
    return r
  }

  // Fire-and-forget: 调用 C++ 桥但不解析返回的 JSON，减少拖动时的 GC 压力。
  // 用于 dragView / zoomBy / panBy 等不需要返回值的连续命令。
  private callNativeFire(name: string, payload: string = ''): void {
    const raw = BridgeClient.send(name, payload)
    if (raw.length === 0) { return }
    if (this.tools.recording && !this.tools.recordingPaused && !this.scriptStore.replaying && isRecordable(name)) {
      let accepted = false
      try {
        accepted = (JSON.parse(raw) as StellariumBridgeResponse).ok === true
      } catch (err) {
        accepted = false
      }
      if (accepted) { this.recordingCtl().recordAcceptedCommand(name, payload) }
    }
  }

  // Retry a native command until the Stellarium core is initialized.
  // At startup the ArkUI thread may call the bridge before Qt has finished
  // bootstrapping; those calls return ok:false and are retried on a short
  // backoff instead of crashing the process.
  private callNativeWhenReady(name: string, payload: string = '', onOk?: (r: StellariumBridgeResponse) => void, attempt: number = 0, intervalMs: number = 200, maxAttempts: number = 60, onFailure?: (r: StellariumBridgeResponse) => void): void {
    BridgeClient.requestWhenReady(name, payload, (r: StellariumBridgeResponse) => {
      // 录制：仅在录制开启、非回放、且命令可录制时记录，并对短时重试用去重窗口避免重复。
      this.recordingCtl().recordAcceptedCommand(name, payload)
      if (onOk) onOk(r)
    }, attempt, intervalMs, maxAttempts, onFailure)
  }

  // Interactive commands (tap-select, search, get-info, move-to) run on the
  // OHOS render pump one frame later and are delivered via a consume-on-read
  // store on the C++ side, so the first call returns {pending}. Poll fast
  // (50ms x 40 = 2s) so a single tap/search resolves without a visible delay
  // and WITHOUT blocking the render thread. onOk receives the FRESH result.
  private callInteractive(name: string, payload: string, onOk: (r: StellariumBridgeResponse) => void, onFailure?: (r: StellariumBridgeResponse) => void): void {
    this.callNativeWhenReady(name, payload, onOk, 0, 100, 15, onFailure)
  }

  private refreshViewCenterCoordinates(): void {
    if (!this.overlayStore.viewCoordinatesVisible || !this.applicationInForeground || this.viewCoordinateRequestPending) {
      return
    }
    this.viewCoordinateRequestPending = true
    this.callNativeWhenReady('getViewCenterCoordinates', '', (result: StellariumBridgeResponse) => {
      this.viewCoordinateRequestPending = false
      if (!this.overlayStore.viewCoordinatesVisible || !this.applicationInForeground) { return }
      this.viewCoordinateSnapshot = result
      this.applyViewCoordinateSnapshot()
    }, 0, 34, 8, () => {
      this.viewCoordinateRequestPending = false
    })
  }

  private applyViewCoordinateSnapshot(): void {
    const snapshot = this.viewCoordinateSnapshot
    if (this.overlayStore.viewCoordinateFamily === 'horizontal') {
      this.viewCoordinatePrimaryText = snapshot.azimuthText ?? '--'
      this.viewCoordinateSecondaryText = snapshot.altitudeText ?? '--'
    } else if (this.overlayStore.viewCoordinateFamily === 'galactic') {
      this.viewCoordinatePrimaryText = snapshot.galacticLongitude ?? '--'
      this.viewCoordinateSecondaryText = snapshot.galacticLatitude ?? '--'
    } else if (this.overlayStore.viewEquatorialEpoch === 'ofDate') {
      this.viewCoordinatePrimaryText = snapshot.ofDateRa ?? '--'
      this.viewCoordinateSecondaryText = snapshot.ofDateDec ?? '--'
    } else {
      this.viewCoordinatePrimaryText = snapshot.j2000Ra ?? '--'
      this.viewCoordinateSecondaryText = snapshot.j2000Dec ?? '--'
    }
  }

  private stopViewCoordinateTimer(): void {
    if (this.viewCoordinateTimer !== 0) {
      clearInterval(this.viewCoordinateTimer)
      this.viewCoordinateTimer = 0
    }
  }

  private syncViewCoordinateTimer(): void {
    this.stopViewCoordinateTimer()
    if (!this.overlayStore.viewCoordinatesVisible || !this.applicationInForeground) { return }
    this.refreshViewCenterCoordinates()
    this.viewCoordinateTimer = setInterval(() => {
      this.refreshViewCenterCoordinates()
    }, 50)
  }

  private stopDockClockTimer(): void {
    if (this.dockClockTimer !== 0) {
      clearInterval(this.dockClockTimer)
      this.dockClockTimer = 0
    }
  }

  /** Dock 常驻时钟：1s 轮询 getSimulationTime，只写 dockClockText 一个 @State。 */
  private syncDockClockTimer(): void {
    this.stopDockClockTimer()
    if (this.timeWheelController !== undefined) { this.timeWheelController.stop() }
    if (!this.applicationInForeground) { return }
    this.refreshDockClock()
    this.dockClockTimer = setInterval(() => {
      this.refreshDockClock()
    }, 1000)
  }

  private refreshDockClock(): void {
    this.callInteractive('getSimulationTime', '', (r: StellariumBridgeResponse) => {
      if (r.ok !== true || r.jd === undefined) { return }
      const jd: number = r.jd as number
      // 固定走本地 jd 格式化：jdToLocalTimeText 返回定长 'YYYY-MM-DD HH:mm:ss'，截取后 5 位为 HH:mm
      const text: string = jdToLocalTimeText(jd + this.utcOffsetHours / 24.0).substring(11, 16)
      if (text !== this.dockClockText) {
        this.dockClockText = text
      }
    })
    // The FOV chip above the dock reads the same @State the zoom paths write, but
    // a programmatic view change (restoring the saved view, safe-area recentring)
    // never goes through changeFovBySlider/zoomStep, so the chip could sit on a
    // stale value. Refresh it on the same 1 s tick as the clock and only write on
    // change, so an unchanged FOV costs no re-render.
    this.callInteractive('getFieldOfView', '', (f: StellariumBridgeResponse) => {
      if (f.ok !== true || f.fov === undefined) { return }
      const fovText: string = (f.fov as number).toFixed(1) + '°'
      if (fovText !== this.currentFovText) { this.currentFovText = fovText }
    })
  }

  private setViewCoordinatesVisible(visible: boolean): void {
    this.overlayStore.viewCoordinatesVisible = visible
    this.saveAppSettings()
    this.syncViewCoordinateTimer()
  }

  private setViewCoordinateFamily(family: string): void {
    this.overlayStore.viewCoordinateFamily = family
    this.applyViewCoordinateSnapshot()
    this.saveAppSettings()
  }

  private setViewEquatorialEpoch(epoch: string): void {
    this.overlayStore.viewEquatorialEpoch = epoch
    this.applyViewCoordinateSnapshot()
    this.saveAppSettings()
  }

  private viewCoordinateOverlayWidth(): number {
    return Math.min(this.isExpandedLayout ? 310 : 270, Math.max(210, this.skyWidth - 32))
  }

  private viewCoordinateOverlayLeft(): number {
    const base = Math.max(16, (this.skyWidth - this.viewCoordinateOverlayWidth()) / 2)
    return base + this.clampedViewCoordinateOffsetX(base)
  }

  private viewCoordinateOverlayTop(): number {
    const base = this.isFoldHoverLayout ? 52 : (this.isExpandedLayout ? 64 : 102)
    return base + this.clampedViewCoordinateOffsetY(base)
  }

  private clampedViewCoordinateOffsetX(base: number): number {
    const width = this.viewCoordinateOverlayWidth()
    return clamp(this.viewCoordinateOffsetX, 8 - base, this.skyWidth - width - 8 - base)
  }

  private clampedViewCoordinateOffsetY(base: number): number {
    const height = 92
    return clamp(this.viewCoordinateOffsetY, 8 - base, this.skyHeight - height - 8 - base)
  }

  private handleViewCoordinateTouch(event: TouchEvent): void {
    const points = event.touches.length > 0 ? event.touches : event.changedTouches
    if (points.length === 0) { return }
    const point = points[0]
    const x = touchScreenX(point)
    const y = touchScreenY(point)
    if (event.type === TouchType.Down) {
      this.viewCoordinateDragging = true
      this.viewCoordinateDragStartX = x
      this.viewCoordinateDragStartY = y
      this.viewCoordinateDragStartOffsetX = this.viewCoordinateOffsetX
      this.viewCoordinateDragStartOffsetY = this.viewCoordinateOffsetY
      this.skyInputCtl().stopSkyInertia()
      return
    }
    if (event.type === TouchType.Move && this.viewCoordinateDragging) {
      this.viewCoordinateOffsetX = this.viewCoordinateDragStartOffsetX + x - this.viewCoordinateDragStartX
      this.viewCoordinateOffsetY = this.viewCoordinateDragStartOffsetY + y - this.viewCoordinateDragStartY
      return
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.viewCoordinateDragging = false
      this.viewCoordinateOffsetX = this.clampedViewCoordinateOffsetX(
        Math.max(16, (this.skyWidth - this.viewCoordinateOverlayWidth()) / 2))
      this.viewCoordinateOffsetY = this.clampedViewCoordinateOffsetY(
        this.isFoldHoverLayout ? 52 : (this.isExpandedLayout ? 64 : 102))
    }
  }

  private callLongRunningInteractive(name: string, payload: string, onOk: (r: StellariumBridgeResponse) => void, onFailure?: (r: StellariumBridgeResponse) => void, onProgress?: (r: StellariumBridgeResponse) => void, maxAttempts: number = 240, isCancelled?: () => boolean): void {
    let attempt = 0
    const poll = (): void => {
      // A superseded request must stop re-issuing its payload. The engine keeps a
      // single long-running job, so a stale loop used to cancel the newest job on
      // every tick and neither side ever produced a result.
      if (isCancelled !== undefined && isCancelled()) { return }
      const response = this.callNative(name, payload)
      if (response.ok === true) {
        onOk(response)
        return
      }
      if (response.pending === true && attempt < maxAttempts) {
        if (onProgress) onProgress(response)
        ++attempt
        setTimeout(poll, 100)
        return
      }
      // A panel can be opened by CLI during the short window between ArkUI
      // creation and Qt bridge readiness. Treat only these startup errors as
      // transient; real calculation errors still reach the failure state.
      const transientStartupError = response.error === 'bridge not available' ||
        response.error === 'bridge parse failed' || response.error === 'command timeout'
      if (transientStartupError && attempt < maxAttempts) {
        if (onProgress) onProgress(response)
        ++attempt
        setTimeout(poll, 100)
        return
      }
      if (onFailure) onFailure(response)
    }
    poll()
  }

  // ===== 星表下载（C++ 桥：getStarCatalogs / downloadStarCatalog / getStarCatalogStatus）=====
  private startCatalogDownload(id: string): void {
    if (this.catalogStore.catalogBusy) {
      this.flashHint(I18n.t('msg_catalog_downloading'))
      return
    }
    this.catalogStore.catalogBusy = true
    this.catalogStore.catalogDownloadingId = id
    this.catalogStore.catalogMsg = '开始下载 ' + id + ' …'
    this.flashHint('开始下载 ' + id)
    const r = this.callNative('downloadStarCatalog', id)
    if (!r || !r.ok) {
      this.catalogStore.catalogBusy = false
      this.catalogStore.catalogDownloadingId = ''
      this.catalogStore.catalogMsg = '下载启动失败'
      this.flashHint(I18n.t('msg_download_failed'))
      return
    }
    this.pollCatalogStatus(id)
  }

  private pollCatalogStatus(id: string): void {
    const timer = setInterval(() => {
      const r = this.callNative('getStarCatalogStatus', '') as StarCatalogStatusResponse
      if (!r || !r.ok) {
        clearInterval(timer)
        this.catalogStore.catalogBusy = false
        this.catalogStore.catalogDownloadingId = ''
        return
      }
      const state = r.state ?? 'downloading'
      const bytes = r.bytes ?? 0
      if (state === 'done') {
        clearInterval(timer)
        const md5ok = r.md5ok === true
        this.catalogStore.catalogMsg = md5ok ? ('「' + id + '」下载完成并已加载') : ('「' + id + '」下载完成，校验未通过')
        this.flashHint(this.catalogStore.catalogMsg)
        this.catalogStore.catalogBusy = false
        this.catalogStore.catalogDownloadingId = ''
        this.catalogStore.loadStarCatalogs()
      } else if (state === 'error') {
        clearInterval(timer)
        const err = r.error ?? '未知错误'
        this.catalogStore.catalogMsg = '下载失败：' + err
        this.flashHint('下载失败：' + err)
        this.catalogStore.catalogBusy = false
        this.catalogStore.catalogDownloadingId = ''
      } else {
        const mb = (bytes / (1024 * 1024)).toFixed(1)
        this.catalogStore.catalogMsg = '下载中 ' + id + '：' + mb + ' MB'
      }
    }, 600)
  }

  // ===== 书签本地持久化（@ohos.data.preferences）=====
  private async saveObservingListToStorage(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
      const store = await preferences.getPreferences(ctx, OBSERVING_STORE)
      await store.put('observingList', JSON.stringify(this.obsListStore.observingList))
      await store.flush()
    } catch (e) {
      hilog.warn(0xD002, 'Stellarium', 'save observing list failed: %{public}s', String(e))
    }
  }

  private persistObservingList(): void {
    AppStorage.setOrCreate('observingList', JSON.stringify(this.obsListStore.observingList))
    this.saveObservingListToStorage()
  }

  // Preferences 原始读取助手：供 ObservingListStore.loadObservingListFromStorage 经 hooks 调用
  //（store 不 import NAPI/UI 上下文，§14.8 规则 2）。
  private async readObservingListStorage(): Promise<string> {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
    const store = await preferences.getPreferences(ctx, OBSERVING_STORE)
    const jsonStr: Object = await store.get('observingList', '')
    return typeof jsonStr === 'string' ? jsonStr : ''
  }

  // Preferences 迁移写回助手：供 store 首次读取到空库时把内存值写回。
  private async writeObservingListStorage(json: string): Promise<void> {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
    const store = await preferences.getPreferences(ctx, OBSERVING_STORE)
    await store.put('observingList', json)
    await store.flush()
  }

  // ===== 书签本地持久化（@ohos.data.preferences）=====
  private async saveBookmarksToStorage(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
      const store = await preferences.getPreferences(ctx, BOOKMARK_STORE)
      const jsonStr: string = JSON.stringify(this.bookmarkStore.list)
      await store.put('bookmarks', jsonStr)
      await store.flush()
    } catch (e) {
      hilog.warn(0xD002, 'Stellarium', 'save bookmarks failed: %{public}s', String(e))
    }
  }

  // Preferences 原始读取助手：供 BookmarkStore.loadBookmarksFromStorage 经 hooks 调用。
  private async readBookmarksStorage(): Promise<string> {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
    const store = await preferences.getPreferences(ctx, BOOKMARK_STORE)
    return (await store.get('bookmarks', '[]')) as string
  }

  // Preferences 原始读写助手：供 SearchStore.loadSearchHistoryFromStorage / saveSearchHistoryToStorage
  // 经 hooks 调用（§14 B3-3；与 readBookmarksStorage 同型，承载 getUIContext + @ohos.data.preferences）。
  private async readSearchHistoryStorage(): Promise<string> {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
    const store = await preferences.getPreferences(ctx, SEARCH_HISTORY_STORE)
    return (await store.get('history', '[]')) as string
  }

  private async writeSearchHistoryStorage(json: string): Promise<void> {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
    const store = await preferences.getPreferences(ctx, SEARCH_HISTORY_STORE)
    await store.put('history', json)
    await store.flush()
  }

  // ===== 观测点持久化：saveObserverLocationToStorage / readObserverLocationStorage /
  // restoreObserverLocation 已随 §15.12 下沉 capability/LocationController.ets（preferences NAPI 收在
  // 顶层 HostLocationPort 适配器）。

  // ===== 书签（C++ 桥：addBookmark / getBookmarks / deleteBookmark / gotoBookmark）=====
  // loadBookmarks 已下沉 BookmarkStore（§14 B2R-4）。

  // 保存当前视图为书签。C++ 端读取当前 J2000 视方向 + 视场 + 选中天体，名称由 payload 传入。
  private addCurrentBookmark(): void {
    const name = this.bookmarkStore.draftName.trim()
    this.callNativeWhenReady('addBookmark', name, (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.bookmarkStore.draftName = ''
        this.flashHint(I18n.t('msg_bookmark_saved'))
        this.bookmarkStore.loadBookmarks()
      } else {
        this.flashHint(I18n.t('msg_bookmark_save_failed'))
      }
    })
  }

  private gotoBookmark(id: string): void {
    this.callInteractive('gotoBookmark', id, (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.flashHint(I18n.t('msg_navigated'))
      } else {
        this.flashHint(I18n.t('msg_navigation_failed'))
      }
    })
  }

  private deleteBookmark(id: string): void {
    this.callNativeWhenReady('deleteBookmark', id, (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.flashHint(I18n.t('msg_bookmark_deleted'))
        this.bookmarkStore.loadBookmarks()
      }
    })
  }

  // ===== 脚本录制 / 回放（#39）=====
  private toggleRecordingUi(): void {
    this.tools.recordingUiExpanded = !this.tools.recordingUiExpanded
    if (!this.tools.recordingUiExpanded) {
      this.panelVisible = false
      this.infoWindowStore.infoWinVisible = false
      this.gyroStore.gyroCalibPanelOpen = false
    }
  }








  private scriptControlSafeTop(): number {
    const safeTop = this.getUIContext().px2vp(Math.max(0, this.screenSafeTopPixels))
    return Math.max(this.EDGE_MARGIN, safeTop + 12)
  }



  private handleScriptControlDragTouch(event: TouchEvent): void {
    const points = event.touches.length > 0 ? event.touches : event.changedTouches
    if (points.length === 0) return
    const x = touchScreenX(points[0])
    const y = touchScreenY(points[0])
    if (event.type === TouchType.Down) {
      this.scriptControlDragging = true
      this.scriptControlDragStartX = x
      this.scriptControlDragStartY = y
      this.scriptControlDragStartOffsetX = this.scriptStore.scriptControlOffsetX
      this.scriptControlDragStartOffsetY = this.scriptStore.scriptControlOffsetY
      this.skyInputCtl().stopSkyInertia()
      return
    }
    if (event.type === TouchType.Move && this.scriptControlDragging) {
      this.scriptStore.scriptControlOffsetX = this.scriptControlDragStartOffsetX + x - this.scriptControlDragStartX
      this.scriptStore.scriptControlOffsetY = this.scriptControlDragStartOffsetY + y - this.scriptControlDragStartY
      return
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.scriptControlDragging = false
      if (this.guideStore.guideState.active) {
        this.scriptStore.scriptControlOffsetX = guideCardX(this.isExpandedLayout, this.skyWidth, this.guideCardWidth(), this.scriptStore.scriptControlOffsetX) - (this.isExpandedLayout ? 12 : (this.skyWidth - this.guideCardWidth()) / 2)
        this.scriptStore.scriptControlOffsetY = guideCardY(this.skyHeight, guideCardHeight(this.skyHeight, this.scriptControlSafeTop()), this.scriptControlSafeTop(), this.scriptStore.scriptControlOffsetY) - (this.skyHeight - guideCardHeight(this.skyHeight, this.scriptControlSafeTop()) - 16)
      } else {
        this.scriptStore.scriptControlOffsetX = scriptControlX(this.skyWidth, this.scriptStore.replaying, this.scriptStore.scriptControlOffsetX) - 12
        this.scriptStore.scriptControlOffsetY = scriptControlY(this.skyHeight, this.scriptControlSafeTop(), this.scriptStore.scriptControlHeight(), this.scriptStore.scriptControlOffsetY) - this.scriptControlSafeTop()
      }
    }
  }

  private startScriptStatusPolling(): void {
    if (this.scriptStatusTimer >= 0) { return }
    this.refreshScriptStatus()
    this.scriptStatusTimer = setInterval(() => {
      this.refreshScriptStatus()
    }, 250) as number
  }

  private stopScriptStatusPolling(): void {
    if (this.scriptStatusTimer >= 0) {
      clearInterval(this.scriptStatusTimer)
      this.scriptStatusTimer = -1
    }
    this.scriptStatusRequestPending = false
    this.scriptCaptionsRequestPending = false
    this.scriptStore.scriptCaptions = []
  }

  private finishNativeScriptUi(message: string): void {
    this.scriptStore.scriptRunning = false
    this.scriptStore.scriptWaiting = false
    this.scriptStore.scriptWaitMessage = ''
    this.scriptStore.scriptId = ''
    this.scriptStore.scriptFocusActive = false
    this.scriptStore.scriptLaunching = false
    this.scriptStore.scriptLaunchingName = ''
    this.scriptStore.scriptStartGraceUntil = 0
    this.tools.recordingUiExpanded = true
    this.stopScriptStatusPolling()
    this.flashHint(message)
    // Native restoration is applied immediately and again after the nested
    // script event loop drains. Refresh ArkTS after that second pass so the
    // location/time controls never retain the script's temporary state.
    setTimeout(() => {
      this.refreshState()
      this.locationPickerStore.loadObserverInfo(true)
      this.sessionToolStore.loadPlanetList()
    }, 220)
  }

  private refreshScriptStatus(): void {
    if (this.guideStore.guideState.active || this.scriptStatusRequestPending || !this.scriptStore.scriptPlaybackVisible(this.guideStore.guideState.active)) { return }
    this.scriptStatusRequestPending = true
    this.callInteractive('getScriptStatus', '', (r: StellariumBridgeResponse) => {
      this.scriptStatusRequestPending = false
      const status = r as ScriptStatusResponse
      if (status.ok !== true) { return }
      const running = status.running === true
      const waiting = running && status.waiting === true
      const waitMessage = waiting && typeof status.waitMessage === 'string' ? status.waitMessage : ''
      this.scriptStore.scriptRunning = running
      if (waiting !== this.scriptStore.scriptWaiting || waitMessage !== this.scriptStore.scriptWaitMessage) {
        this.getUIContext().animateTo({ duration: 180, curve: curves.springMotion(0.55, 0.90) }, () => {
          this.scriptStore.scriptWaiting = waiting
          this.scriptStore.scriptWaitMessage = waitMessage
        })
      }
      this.scriptStore.scriptId = typeof status.scriptId === 'string' ? status.scriptId : ''
      this.refreshScriptCaptions()
      if (typeof status.scriptRate === 'number' && Number.isFinite(status.scriptRate)) {
        this.scriptStore.scriptRate = status.scriptRate
      }
      if (!running && !this.scriptStore.scriptLaunching && !this.scriptStore.replaying && Date.now() >= this.scriptStore.scriptStartGraceUntil) {
        this.finishNativeScriptUi(I18n.t('script_finished'))
      }
    }, () => {
      this.scriptStatusRequestPending = false
    })
  }

  private refreshScriptCaptions(): void {
    if (this.scriptCaptionsRequestPending || !this.scriptStore.scriptPlaybackVisible(this.guideStore.guideState.active)) return
    this.scriptCaptionsRequestPending = true
    this.callInteractive('getScriptCaptions', '', (r: StellariumBridgeResponse) => {
      this.scriptCaptionsRequestPending = false
      const response = r as ScriptCaptionsResponse
      if (response.ok !== true || !Array.isArray(response.captions)) {
        this.scriptStore.scriptCaptions = []
        return
      }
      const captions = response.captions
        .filter((item) => item.visible === true && typeof item.text === 'string' && item.text.length > 0)
        .map((item) => item.text)
        .slice(-3)
      if (captions.join('\n') !== this.scriptStore.scriptCaptions.join('\n')) {
        this.getUIContext().animateTo({ duration: 160, curve: Curve.EaseOut }, () => {
          this.scriptStore.scriptCaptions = captions
        })
      }
    }, () => {
      this.scriptCaptionsRequestPending = false
    })
  }

  private changeScriptRate(direction: number): void {
    const next = Math.max(0.25, Math.min(16, this.scriptStore.scriptRate * (direction > 0 ? 2 : 0.5)))
    this.callInteractive('setScriptRate', next.toString(), (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.scriptStore.scriptRate = next
      } else {
        this.flashHint('调整脚本速度失败')
      }
    })
  }






  // loadScriptList / setScriptMetadata 已下沉 ScriptStore（§14 B2R-4）。

  private pluginMetaLine(plugin: PluginItem): string {
    const values: string[] = []
    if (plugin.version && plugin.version.trim().length > 0) { values.push(I18n.t('resource_version') + ': ' + plugin.version.trim()) }
    if (plugin.contact && plugin.contact.trim().length > 0) { values.push(I18n.t('resource_contact') + ': ' + plugin.contact.trim()) }
    if (plugin.acknowledgements && plugin.acknowledgements.trim().length > 0) { values.push(I18n.t('resource_acknowledgements') + ': ' + plugin.acknowledgements.trim()) }
    if (plugin.source && plugin.source.trim().length > 0) { values.push(I18n.t('resource_source') + ': ' + plugin.source.trim()) }
    return values.join(' · ')
  }

  private scriptImportFileName(uri: string): string {
    let name = uri.substring(uri.lastIndexOf('/') + 1)
    const queryIndex = name.indexOf('?')
    if (queryIndex >= 0) name = name.substring(0, queryIndex)
    try {
      name = decodeURIComponent(name)
    } catch (_error) {
    }
    name = name.trim().replace(/[\\/:*?"<>|\u0000-\u001F]/g, '_')
    if (name.length === 0 || !name.toLowerCase().endsWith('.ssc')) {
      name = 'imported-' + Date.now().toString() + '.ssc'
    }
    if (name.length > 120) {
      name = name.substring(0, 116) + '.ssc'
    }
    return name
  }

  private async importScriptFile(): Promise<void> {
    if (this.scriptStore.scriptImporting) return
    this.scriptStore.scriptImporting = true
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const options = new picker.DocumentSelectOptions()
      options.fileSuffixFilters = ['Stellarium 脚本|.ssc']
      options.maxSelectNumber = 1
      const viewPicker = new picker.DocumentViewPicker(context)
      const selectedUris = await viewPicker.select(options)
      if (selectedUris.length === 0 || selectedUris[0].length === 0) {
        this.flashHint(I18n.t('script_import_cancelled'))
        return
      }
      const scriptDir = context.filesDir + '/stellarium_userdir/scripts'
      fileIo.mkdirSync(scriptDir, true)
      const baseName = this.scriptImportFileName(selectedUris[0])
      let fileName = baseName
      let destinationPath = scriptDir + '/' + fileName
      if (fileIo.accessSync(destinationPath)) {
        fileName = baseName.replace(/\.ssc$/i, '') + '-' + Date.now().toString() + '.ssc'
        destinationPath = scriptDir + '/' + fileName
      }
      await fileIo.copy(selectedUris[0], fileUri.getUriFromPath(destinationPath))
      this.flashHint(I18n.format('script_import_success', [fileName]))
      hilog.info(0x0000, 'StellariumArkUI', 'Imported offline script %{public}s', fileName)
      this.scriptStore.loadScriptList()
    } catch (error) {
      hilog.error(0x0000, 'StellariumArkUI', 'Script import failed: %{public}s', String(error))
      this.flashHint(I18n.t('script_import_failed'))
    } finally {
      this.scriptStore.scriptImporting = false
    }
  }

  // loadRecordingByName 已下沉 ScriptStore（§14 B2R-4）。

  private landscapeImportFileName(uri: string): string {
    let name = uri.substring(uri.lastIndexOf('/') + 1)
    const queryIndex = name.indexOf('?')
    if (queryIndex >= 0) name = name.substring(0, queryIndex)
    try { name = decodeURIComponent(name) } catch (_error) {}
    name = name.trim().replace(/[\\/:*?"<>|\u0000-\u001F]/g, '_')
    if (name.length === 0 || !name.toLowerCase().endsWith('.zip')) name = 'imported-landscape-' + Date.now().toString() + '.zip'
    if (name.length > 120) name = name.substring(0, 116) + '.zip'
    return name
  }

  private async importLandscapeFile(): Promise<void> {
    if (this.layerViewStore.landscapeImporting) return
    this.layerViewStore.landscapeImporting = true
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const options = new picker.DocumentSelectOptions()
      options.fileSuffixFilters = ['Stellarium 地景 ZIP|.zip']
      options.maxSelectNumber = 1
      const selectedUris = await new picker.DocumentViewPicker(context).select(options)
      if (selectedUris.length === 0 || selectedUris[0].length === 0) {
        this.flashHint(I18n.t('landscape_import_cancelled'))
        this.layerViewStore.landscapeImporting = false
        return
      }
      const importDir = context.filesDir + '/stellarium_userdir/landscape-imports'
      fileIo.mkdirSync(importDir, true)
      const baseName = this.landscapeImportFileName(selectedUris[0])
      let fileName = baseName
      let destinationPath = importDir + '/' + fileName
      if (fileIo.accessSync(destinationPath)) {
        fileName = baseName.replace(/\.zip$/i, '') + '-' + Date.now().toString() + '.zip'
        destinationPath = importDir + '/' + fileName
      }
      await fileIo.copy(selectedUris[0], fileUri.getUriFromPath(destinationPath))
      this.callInteractive('importLandscape', destinationPath, (r: StellariumBridgeResponse) => {
        if (r.ok === true) {
          this.flashHint(I18n.format('landscape_import_success', [String(r.id ?? fileName)]))
          this.layerViewStore.loadLandscapeList()
        } else {
          this.flashHint(I18n.t('landscape_import_failed'))
        }
        this.layerViewStore.landscapeImporting = false
      }, () => {
        this.flashHint(I18n.t('landscape_import_failed'))
        this.layerViewStore.landscapeImporting = false
      })
    } catch (error) {
      hilog.error(0x0000, 'StellariumArkUI', 'Landscape import failed: %{public}s', String(error))
      this.flashHint(I18n.t('landscape_import_failed'))
      this.layerViewStore.landscapeImporting = false
    }
  }

  private async saveFileAs(path: string, fileName: string, suffixLabel: string): Promise<void> {
    if (path.length === 0 || !this.hostMediaPort.fileExists(path)) {
      this.flashHint('没有可导出的文件')
      return
    }
    this.hostMediaPort.saveFileAs(path, fileName, suffixLabel, (result: MediaSaveResult) => {
      if (result === MediaSaveResult.Saved) {
        this.flashHint('文件已导出')
      } else if (result === MediaSaveResult.Failed) {
        this.flashHint('导出失败')
      }
    })
  }

  // closeScreenCaptureFile / finalizeScreenVideo / startScreenVideoRecording / stopScreenVideoRecording /
  // saveScreenVideoToGallery 已随 M1-B 子组② 搬入 capability/RecordingController.ets
  // （NAPI 细节收在顶层 HostMediaPort 适配器）。

  private setOcularMode(v: boolean): void {
    this.telescopeStore.ocularMode = v
    this.callNativeWhenReady('setOcularMode', v ? '1' : '0', (r: StellariumBridgeResponse) => {
      const response = r as OcularModeResponse
      this.telescopeStore.ocularMode = response.applied === true
      if (v && response.selectionRequired === true) {
        this.telescopeStore.ocularStatusMessage = I18n.t('ocular_status_select_target')
      }
      this.telescopeStore.loadOculars(false)
    })
  }

  private setMosaicCamera(setting: string, value: string = ''): void {
    if (this.mosaicStore.mosaicCameraPending || this.mosaicStore.mosaicCameraLoading) return
    if (setting === 'enabled' && (value === '1') === this.mosaicStore.mosaicCameraEnabled) return
    if (setting === 'visible' && (value === '1') === this.mosaicStore.mosaicCameraVisible) return
    if (setting === 'camera' && value === this.mosaicStore.mosaicCameraCurrent) return
    this.mosaicStore.mosaicCameraPending = true
    this.callInteractive('setMosaicCamera', setting + (value.length > 0 ? '|' + value : ''), (result: StellariumBridgeResponse) => {
      if (result.ok !== true) {
        this.mosaicStore.mosaicCameraPending = false
        this.mosaicStore.mosaicCameraStatus = result.error ?? I18n.t('plugin_action_failed')
        return
      }
      this.mosaicStore.loadMosaicCamera(false)
    }, () => {
      this.mosaicStore.mosaicCameraPending = false
      this.mosaicStore.mosaicCameraStatus = I18n.t('plugin_action_failed')
    })
  }

  private setEquationOfTime(setting: string, enabled: boolean): void {
    const mutationId = ++this.equationOfTimeMutationId
    let previous: boolean | undefined
    if (setting === 'enabled') { previous = this.equationOfTimeStore.equationOfTimeEnabled; this.equationOfTimeStore.equationOfTimeEnabled = enabled }
    else if (setting === 'msFormat') { previous = this.equationOfTimeStore.equationOfTimeMsFormat; this.equationOfTimeStore.equationOfTimeMsFormat = enabled }
    else if (setting === 'inverted') { previous = this.equationOfTimeStore.equationOfTimeInverted; this.equationOfTimeStore.equationOfTimeInverted = enabled }
    else if (setting === 'enableAtStartup') { previous = this.equationOfTimeStore.equationOfTimeStartup; this.equationOfTimeStore.equationOfTimeStartup = enabled }
    this.equationOfTimeStore.equationOfTimeStatus = ''
    this.callInteractive('setEquationOfTime', setting + '|' + (enabled ? '1' : '0'), () => {}, () => {
      if (mutationId !== this.equationOfTimeMutationId) return
      if (previous !== undefined) {
        if (setting === 'enabled') this.equationOfTimeStore.equationOfTimeEnabled = previous
        else if (setting === 'msFormat') this.equationOfTimeStore.equationOfTimeMsFormat = previous
        else if (setting === 'inverted') this.equationOfTimeStore.equationOfTimeInverted = previous
        else if (setting === 'enableAtStartup') this.equationOfTimeStore.equationOfTimeStartup = previous
      }
      this.equationOfTimeStore.equationOfTimeStatus = I18n.t('plugin_action_failed')
    })
  }


  private setArchaeoLineSetting(setting: string, value: string): void {
    const mutationId = ++this.archaeoMutationId
    const previous = this.archaeoStore.archaeoLineSettingValue(setting)
    this.applyArchaeoLineSetting(setting, value)
    this.archaeoStore.archaeoStatus = ''
    this.callInteractive('setArchaeoLineSetting', setting + '|' + value, () => {}, () => {
      if (mutationId !== this.archaeoMutationId) return
      this.applyArchaeoLineSetting(setting, previous)
      this.archaeoStore.archaeoStatus = I18n.t('plugin_action_failed')
    })
  }

  private applyArchaeoLineSetting(setting: string, value: string): void {
    const enabled = value === '1' || value === 'true'
    switch (setting) {
      case 'enabled': this.archaeoStore.archaeoLinesEnabled = enabled; break
      case 'equinox': this.archaeoStore.archaeoEquinox = enabled; break
      case 'solstices': this.archaeoStore.archaeoSolstices = enabled; break
      case 'crossquarters': this.archaeoStore.archaeoCrossquarters = enabled; break
      case 'majorStandstills': this.archaeoStore.archaeoMajorStandstills = enabled; break
      case 'minorStandstills': this.archaeoStore.archaeoMinorStandstills = enabled; break
      case 'polarCircles': this.archaeoStore.archaeoPolarCircles = enabled; break
      case 'zenithPassage': this.archaeoStore.archaeoZenithPassage = enabled; break
      case 'nadirPassage': this.archaeoStore.archaeoNadirPassage = enabled; break
      case 'selectedObject': this.archaeoStore.archaeoSelectedObject = enabled; break
      case 'selectedObjectAzimuth': this.archaeoStore.archaeoSelectedObjectAzimuth = enabled; break
      case 'selectedObjectHourAngle': this.archaeoStore.archaeoSelectedObjectHourAngle = enabled; break
      case 'currentSun': this.archaeoStore.archaeoCurrentSun = enabled; break
      case 'currentMoon': this.archaeoStore.archaeoCurrentMoon = enabled; break
      case 'currentPlanet': this.archaeoStore.archaeoCurrentPlanet = ['none', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn'].indexOf(value); break
      case 'lineWidth': this.archaeoStore.archaeoLineWidth = Math.round(Number(value)); break
    }
  }

  private setTelrad(v: boolean): void {
    this.telescopeStore.telradOn = v
    this.callNativeWhenReady('setTelrad', v ? '1' : '0', () => { this.telescopeStore.loadOculars(false) })
  }
  private setCrosshairs(v: boolean): void {
    this.telescopeStore.crosshairsOn = v
    this.callNativeWhenReady('setCrosshairs', v ? '1' : '0', () => { this.telescopeStore.loadOculars(false) })
  }
  private setCCD(v: boolean): void {
    this.telescopeStore.ccdOn = v
    this.callNativeWhenReady('setCCD', v ? '1' : '0', () => { this.telescopeStore.loadOculars(false) })
  }
  private selectOcularInstrument(kind: string, index: number): void {
    this.callNativeWhenReady('selectOcularInstrument', kind.toLowerCase() + '|' + index.toString(), () => {
      this.telescopeStore.loadOculars(false)
    })
  }
  private setOcularSetting(name: string, enabled: boolean): void {
    this.callNativeWhenReady('setOcularSetting', name + '|' + (enabled ? '1' : '0'), () => {
      this.telescopeStore.loadOculars(false)
    })
  }
  private changeOcularCcdRotation(value: number, mode: SliderChangeMode): void {
    this.telescopeStore.ocularCcdRotation = value
    if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
      this.callNativeWhenReady('setOcularSetting', 'ccdRotation|' + value.toFixed(1), () => {
        this.telescopeStore.loadOculars(false)
      })
    }
  }
  private changeOcularMaskOpacity(value: number, mode: SliderChangeMode): void {
    this.telescopeStore.ocularMaskOpacity = Math.round(value)
    if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
      this.callNativeWhenReady('setOcularSetting', 'maskOpacity|' + this.telescopeStore.ocularMaskOpacity.toString(), () => {
        this.telescopeStore.loadOculars(false)
      })
    }
  }
  private changeOcularPrismRotation(value: number, mode: SliderChangeMode): void {
    this.telescopeStore.ocularCcdPrismRotation = value
    if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
      this.callNativeWhenReady('setOcularSetting', 'prismRotation|' + value.toFixed(1), () => { this.telescopeStore.loadOculars(false) })
    }
  }
  private changeOcularCropSize(setting: string, value: number, mode: SliderChangeMode): void {
    const size = Math.round(value)
    if (setting === 'ccdCropHSize') this.telescopeStore.ocularCcdCropHSize = size
    else this.telescopeStore.ocularCcdCropVSize = size
    if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
      this.callNativeWhenReady('setOcularSetting', setting + '|' + size.toString(), () => { this.telescopeStore.loadOculars(false) })
    }
  }
  private rotateOcularReticle(direction: string): void {
    this.callNativeWhenReady('rotateOcularReticle', direction, () => { this.telescopeStore.loadOculars(false) })
  }
  private resetOcularInstrument(kind: string): void {
    this.callNativeWhenReady('resetOcularInstrument', kind, () => { this.telescopeStore.loadOculars(false) })
  }
  private setPointerCoordinates(setting: string, value: string): void {
    this.callNativeWhenReady('setPointerCoordinates', setting + '|' + value, (r: StellariumBridgeResponse) => {
      if (r.ok !== true) this.overlayStore.pointerCoordinatesStatus = I18n.t('plugin_action_failed')
      this.overlayStore.loadPointerCoordinates()
    }, 0, 100, 15, () => { this.overlayStore.pointerCoordinatesStatus = I18n.t('plugin_action_failed') })
  }

  // ===== 卫星（Satellites 插件桥）=====
  private publishSatellitePanelState(error: string = ''): void {
    AppStorage.setOrCreate('stellariumSatellitePanelState', JSON.stringify({
      ok: error.length === 0, error: error, panel: this.activePanel, group: this.satelliteStore.activeSatGroup,
      loading: this.satelliteStore.satelliteListLoading, matchedCount: this.satelliteStore.satMatchedCount,
      ids: this.satelliteStore.satItems.map((item: SatelliteListItem) => item.id),
      groups: this.satelliteStore.satGroups, requestId: this.satelliteStore.satelliteListRequestId,
      orbitLines: this.satelliteStore.satOrbitLines, hints: this.satelliteStore.satHints,
      elapsedMs: this.satelliteStore.satelliteListElapsedMs,
      scrollY: this.satellitePanelScroller.currentOffset()?.yOffset ?? 0,
      groupScrollY: this.satelliteGroupScroller.currentOffset()?.yOffset ?? 0
    }))
  }
  private selectSatelliteGroup(group: string): void {
    if (group.length > 0 && !this.satelliteStore.satGroups.includes(group)) {
      this.publishSatellitePanelState('unknown satellite group')
      return
    }
    if (this.satelliteStore.activeSatGroup === group) {
      this.publishSatellitePanelState()
      return
    }
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.satelliteStore.activeSatGroup = group
    })
    this.satelliteStore.loadSatellites()
  }
  // §14 B3-4：loadSatellites 及其 satelliteListRequestId / satelliteLoadTimer /
  // satelliteLoadIncludeSources / satelliteFlagMutationId / satelliteListElapsedMs 已整体搬入
  // state/SatelliteStore.ets（90ms 去抖、请求序号并发抑制、includeSources 合并逐字保留）。
  private setSatelliteUpdateSetting(key: string, value: boolean | number): void {
    const payload: Record<string, boolean | number> = {}
    payload[key] = value
    this.callInteractive('setSatelliteUpdateSetting', JSON.stringify(payload), () => {
      this.satelliteStore.loadSatelliteSources()
    }, (failure: StellariumBridgeResponse) => { this.satelliteStore.satSourceStatus = failure.error ?? I18n.t('sat_source_invalid') })
  }
  private addSatelliteSource(): void {
    const url = this.satelliteStore.satSourceInput.trim()
    if (url.length === 0) { this.satelliteStore.satSourceStatus = I18n.t('sat_source_empty'); return }
    const sources: SatelliteSourceInput[] = []
    for (const source of this.satelliteStore.satSources) sources.push({ url: source.url, addNew: source.addNew })
    sources.push({ url: url, addNew: this.satelliteStore.satSourceAddNew })
    this.callInteractive('setSatelliteSources', JSON.stringify({ sources: sources }), (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.satelliteStore.satSourceInput = ''
        this.satelliteStore.satSourceStatus = I18n.t('sat_source_saved')
        this.satelliteStore.loadSatelliteSources()
      } else this.satelliteStore.satSourceStatus = r.error ?? I18n.t('sat_source_invalid')
    }, (failure: StellariumBridgeResponse) => { this.satelliteStore.satSourceStatus = failure.error ?? I18n.t('sat_source_invalid') })
  }
  private deleteSatelliteSource(index: number): void {
    const sources: SatelliteSourceInput[] = []
    for (let sourceIndex = 0; sourceIndex < this.satelliteStore.satSources.length; sourceIndex++) {
      if (sourceIndex !== index) {
        const source = this.satelliteStore.satSources[sourceIndex]
        sources.push({ url: source.url, addNew: source.addNew })
      }
    }
    this.callInteractive('setSatelliteSources', JSON.stringify({ sources: sources }), (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.satelliteStore.satSourceStatus = I18n.t('sat_source_deleted')
        this.satelliteStore.loadSatelliteSources()
      } else this.satelliteStore.satSourceStatus = r.error ?? I18n.t('sat_source_invalid')
    }, (failure: StellariumBridgeResponse) => { this.satelliteStore.satSourceStatus = failure.error ?? I18n.t('sat_source_invalid') })
  }
  private importSatelliteTleFile(): void {
    const path = this.satelliteStore.satTleFileInput.trim()
    if (path.length === 0) { this.satelliteStore.satSourceStatus = I18n.t('sat_tle_path_empty'); return }
    this.callInteractive('importSatelliteTle', JSON.stringify({ paths: [path] }), (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.satelliteStore.satTleFileInput = ''
        this.satelliteStore.satSourceStatus = I18n.t('sat_tle_imported')
        this.satelliteStore.loadSatellites(true, true)
      } else this.satelliteStore.satSourceStatus = r.error ?? I18n.t('sat_tle_import_failed')
    }, (failure: StellariumBridgeResponse) => { this.satelliteStore.satSourceStatus = failure.error ?? I18n.t('sat_tle_import_failed') })
  }
  private refreshSatelliteCatalog(): void {
    this.callInteractive('refreshSatelliteCatalog', '', (r: StellariumBridgeResponse) => {
      this.satelliteStore.satSourceStatus = r.ok === true ? I18n.t('sat_refresh_started') : (r.error ?? I18n.t('sat_refresh_offline'))
      this.satelliteStore.loadSatelliteSources()
    }, (failure: StellariumBridgeResponse) => { this.satelliteStore.satSourceStatus = failure.error ?? I18n.t('sat_refresh_offline') })
  }
  private setSatelliteFlag(name: string, v: boolean): void {
    if ((name === 'labels' && this.satelliteStore.satLabels === v) ||
      (name === 'orbitLines' && this.satelliteStore.satOrbitLines === v) ||
      (name === 'hints' && this.satelliteStore.satHints === v) ||
      (name === 'iconicMode' && this.satelliteStore.satIconicMode === v) ||
      (name === 'hideInvisible' && this.satelliteStore.satHideInvisible === v)) return
    const mutationId = ++this.satelliteStore.satelliteFlagMutationId
    let previous: boolean | undefined
    if (name == 'labels') { previous = this.satelliteStore.satLabels; this.satelliteStore.satLabels = v }
    else if (name == 'orbitLines') { previous = this.satelliteStore.satOrbitLines; this.satelliteStore.satOrbitLines = v }
    else if (name == 'hints') { previous = this.satelliteStore.satHints; this.satelliteStore.satHints = v }
    else if (name == 'iconicMode') { previous = this.satelliteStore.satIconicMode; this.satelliteStore.satIconicMode = v }
    else if (name == 'hideInvisible') { previous = this.satelliteStore.satHideInvisible; this.satelliteStore.satHideInvisible = v }
    this.callNativeWhenReady('setSatellitesFlag', name + ':' + (v ? '1' : '0'), () => {}, 0, 100, 15, () => {
      if (mutationId !== this.satelliteStore.satelliteFlagMutationId || previous === undefined) return
      if (name == 'labels') this.satelliteStore.satLabels = previous
      else if (name == 'orbitLines') this.satelliteStore.satOrbitLines = previous
      else if (name == 'hints') this.satelliteStore.satHints = previous
      else if (name == 'iconicMode') this.satelliteStore.satIconicMode = previous
      else if (name == 'hideInvisible') this.satelliteStore.satHideInvisible = previous
    })
  }
  private catalogHealthText(title: string, health: CatalogHealthEntry): string {
    if (!this.catalogHealthLoaded) return title + '状态检查中'
    if (!this.catalogManifestPresent || health.status === 'unknown') return title + '状态不可用'
    const checkedAt = health.checkedAt ? health.checkedAt.replace('T', ' ').replace('Z', ' UTC') : '未记录'
    if (health.status === 'stale') return title + '已过期，请在下次发布前更新或复核（上次：' + checkedAt + '）'
    if (health.status === 'attention') return title + '部分更新，建议下次发布前完整复核（上次：' + checkedAt + '）'
    return title + '已核验（' + checkedAt + '）'
  }
  private catalogHealthColor(health: CatalogHealthEntry): string {
    if (!this.catalogHealthLoaded || !this.catalogManifestPresent || health.status === 'unknown') return '#99FFFFFF'
    if (health.status === 'stale' || health.status === 'attention') return '#FFE1A6'
    return '#B7D8F0'
  }

  // 确保插件已加载，未加载时先 loadPlugin 再回调
  private ensurePluginLoaded(pluginName: string, callback: () => void, failureCallback?: () => void): void {
    if (this.pluginFeatureLoading.indexOf(pluginName) >= 0) {
      hilog.info(0x0000, 'StellariumArkUI', 'Plugin feature load already pending: ' + pluginName)
      return
    }
    this.pluginFeatureLoading = this.pluginFeatureLoading.concat([pluginName])
    const finish = (): void => {
      this.pluginFeatureLoading = this.pluginFeatureLoading.filter((id: string) => id !== pluginName)
    }
    this.callNativeWhenReady('getPluginList', '', (r: StellariumBridgeResponse) => {
      const items = r.items as Array<PluginItem> | undefined
      let loaded = false
      if (items) {
        for (let index = 0; index < items.length; index++) {
          if (items[index].id === pluginName && items[index].loaded) {
            loaded = true
            break
          }
        }
      }
      if (loaded) {
        finish()
        callback()
      } else {
        hilog.info(0x0000, 'StellariumArkUI', 'Auto-loading plugin: ' + pluginName)
        this.callInteractive('loadPlugin', pluginName, (loadResult: StellariumBridgeResponse) => {
          finish()
          if (loadResult.ok === true) {
            this.updatePluginLoadedItem(pluginName, true)
            // Loading a feature plugin must not rebuild unrelated panels. The
            // catalog chips only need refreshing while the search panel is
            // visible; doing it for every plugin caused a full-shell flash.
            if (this.activePanel === 'search') this.catalogStore.loadObjectCatalogCategories(this.languageStore.languageRefreshSerial)
            callback()
          }
          else {
            this.flashHint(I18n.t('plugin_load_failed'))
            if (failureCallback !== undefined) failureCallback()
          }
        }, () => {
          finish()
          this.flashHint(I18n.t('plugin_load_failed'))
          if (failureCallback !== undefined) failureCallback()
        })
      }
    }, 0, 100, 15, () => {
      finish()
      if (failureCallback !== undefined) failureCallback()
    })
  }

  // ===== 流星雨（MeteorShowers 插件桥）=====
  // loadMeteorShowers / setMeteorShowersFlag 已随 §14 B3-1 同片搬入 state/MeteorStore.ets。

  private setScenery3dScene(id: string): void {
    this.sceneryStore.scenery3dLoadingId = id
    this.callInteractive('setScenery3dScene', id, (r: StellariumBridgeResponse) => {
      if (r.ok !== true) {
        this.sceneryStore.scenery3dLoadingId = ''
        this.flashHint('三维地景加载失败')
        return
      }
      this.sceneryStore.loadScenery3d()
    }, () => { this.sceneryStore.scenery3dLoadingId = '' })
  }

  private setScenery3dEnabled(enabled: boolean): void {
    this.sceneryStore.scenery3dEnabled = enabled
    this.callInteractive('setScenery3dEnabled', enabled ? '1' : '0', (r: StellariumBridgeResponse) => {
      if (r.ok !== true) this.sceneryStore.scenery3dEnabled = !enabled
      this.sceneryStore.loadScenery3d()
    }, () => { this.sceneryStore.scenery3dEnabled = !enabled })
  }

  // ===== 帮助面板：关于 / 日志 / 配置导入导出 =====
  private exportConfig(): void {
    this.callNativeWhenReady('exportConfig', '', (r: StellariumBridgeResponse) => {
      const resp = r as ExportConfigResponse
      if (resp.ok !== true) {
        this.flashHint(I18n.t('config_export_failed'))
        return
      }
      this.tools.configExportText = resp.content ?? ''
      this.tools.configExportVisible = true
      copyTextToClipboard(this.hostPlatformPort, this.tools.configExportText, I18n.t('config_export_copied'), { flashHint: (text: ResourceStr): void => this.flashHint(text) })
    })
  }

  private importConfig(): void {
    const text = this.tools.configImportText.trim()
    if (text.length === 0) {
      this.flashHint(I18n.t('msg_paste_config_first'))
      return
    }
    this.tools.configImportMsg = '正在导入…'
    this.callNativeWhenReady('importConfig', text, (r: StellariumBridgeResponse) => {
      const resp = r as ImportConfigResponse
      if (resp.ok === true) {
        this.tools.configImportText = ''
        this.tools.configImportMsg = '已导入 ' + (resp.applied ?? 0) + ' 项配置'
        this.flashHint(this.tools.configImportMsg)
      } else {
        this.tools.configImportMsg = '导入失败：' + (resp.error ?? '未知错误')
      }
    })
  }

  // ===== 朗读 / 语音播报 =====
  // 说明：当前构建基于 OpenHarmony 基础 SDK（API 24），其 kit 列表不含
  // @kit.CoreSpeechKit（语音合成仅存在于华为 HarmonyOS 的 HMS SDK），因此
  // 无法在此环境做真正的 TTS 音频播报。这里保留 C++ 侧生成的"可读中文描述"
  // （getObjectSpokenText 命令），点按按钮即在面板中显示该文本，验证命令通道，
  // 待切换到含 CoreSpeechKit 的 SDK 后即可接真实语音合成。
  private refreshState(): void {
    if (this.stateRefreshRequestPending) {
      this.stateRefreshQueued = true
      return
    }
    if (this.stateRefreshTimer >= 0) return
    this.stateRefreshTimer = setTimeout(() => {
      this.stateRefreshTimer = -1
      this.refreshStateNow()
    }, 48) as number
  }

  private refreshStateNow(): void {
    if (this.stateRefreshRequestPending) {
      this.stateRefreshQueued = true
      return
    }
    this.stateRefreshRequestPending = true
    this.callInteractive('getState', '', (result) => {
    if (result.selectedInfoMode !== undefined) {
      this.applySelectedInfoMode(result.selectedInfoMode)
    }
    this.layerStore.stars = result.actionShow_Stars === true
    this.layerStore.planets = result.actionShow_Planets === true
    this.layerStore.planetOrbits = result.actionShow_Planets_Orbits === true
    this.layerStore.planetHints = result.actionShow_Planets_Hints === true
    if (result.actionShow_Planets_Trails !== undefined) this.layerStore.planetTrails = result.actionShow_Planets_Trails === true
    if (result.actionShow_Planets_EnlargeMoon !== undefined) this.layerStore.enlargeMoon = result.actionShow_Planets_EnlargeMoon === true
    this.layerStore.nebulae = result.actionShow_Nebulas === true
    this.layerStore.milkyWay = result.actionShow_MilkyWay === true
    this.layerStore.ground = result.actionShow_Ground === true
    this.layerStore.mistHorizon = result.actionShow_MistHorizon === true
    this.layerStore.constellationLines = result.actionShow_Constellation_Lines === true
    this.layerStore.constellationLabels = result.actionShow_Constellation_Labels === true
    this.layerStore.constellationBoundaries = result.actionShow_Constellation_Boundaries === true
    this.layerStore.constellationArt = result.actionShow_Constellation_Art === true
    this.layerStore.constellationHulls = result.actionShow_Constellation_Hulls === true
    this.layerStore.atmosphere = result.actionShow_Atmosphere === true
    this.layerStore.cardinalPoints = result.actionShow_Cardinal_Points === true
    this.layerStore.intercardinalPts = result.actionShow_Intercardinal_Points === true
    this.layerStore.secondaryIntercardinalPts = result.actionShow_Secondary_Intercardinal_Points === true
    this.layerStore.tertiaryIntercardinalPts = result.actionShow_Tertiary_Intercardinal_Points === true
    this.layerStore.compassMarks = result.actionShow_Compass_Marks === true
    this.layerStore.gridlinesMaster = result.actionShow_Gridlines === true
    this.layerStore.fovMarker = result.actionShow_FOV_Center_Marker === true
    this.layerStore.fovCircularMarker = result.actionShow_FOV_Circular_Marker === true
    this.layerStore.fovRectangularMarker = result.actionShow_FOV_Rectangular_Marker === true
    if (result.fovCircularMarkerSize !== undefined) this.layerViewStore.fovCircularMarkerSize = result.fovCircularMarkerSize
    if (result.fovRectangularMarkerWidth !== undefined) this.layerViewStore.fovRectangularMarkerWidth = result.fovRectangularMarkerWidth
    if (result.fovRectangularMarkerHeight !== undefined) this.layerViewStore.fovRectangularMarkerHeight = result.fovRectangularMarkerHeight
    if (result.fovRectangularMarkerRotation !== undefined) this.layerViewStore.fovRectangularMarkerRotation = result.fovRectangularMarkerRotation
    this.layerStore.azimuthGrid = result.actionShow_Azimuthal_Grid === true
    this.layerStore.equatorialGrid = result.actionShow_Equatorial_Grid === true
    this.layerStore.equatorialJ2000Grid = result.actionShow_Equatorial_J2000_Grid === true
    this.layerStore.eclipticGrid = result.actionShow_Ecliptic_Grid === true
    this.layerStore.meridianLine = result.actionShow_Meridian_Line === true
    this.layerStore.horizonLine = result.actionShow_Horizon_Line === true
    this.planetLabels = result.actionShow_Planets_Labels === true
    this.layerStore.starLabels = result.actionShow_Stars_Labels === true
    this.layerStore.dsoLabels = result.dsoLabels === true
    this.layerStore.dsoTextures = result.actionShow_DSO_Textures === true
    this.layerStore.enlargePlanets = result.actionShow_Planets_EnlargePlanets === true
    this.layerStore.enlargeSun = result.actionShow_Planets_EnlargeSun === true
    this.layerStore.minorBodyMarkers = result.actionShow_Planets_ShowMinorBodyMarkers === true
    this.layerStore.planetNomenclature = result.actionShow_Planets_Nomenclature === true
    this.layerStore.fogEffect = result.actionShow_Fog === true
    if (result.actionShow_Ecliptic_Line !== undefined) this.layerStore.eclipticLine = result.actionShow_Ecliptic_Line === true
    if (result.actionShow_Equator_Line !== undefined) this.layerStore.equatorLine = result.actionShow_Equator_Line === true
    if (result.actionShow_Galactic_Grid !== undefined) this.layerStore.galacticGrid = result.actionShow_Galactic_Grid === true
    if (result.actionShow_Galactic_Equator_Line !== undefined) this.layerStore.galacticEquator = result.actionShow_Galactic_Equator_Line === true
    if (result.actionShow_Supergalactic_Equator_Line !== undefined) this.layerStore.supergalacticEq = result.actionShow_Supergalactic_Equator_Line === true
    if (result.actionShow_Equator_J2000_Line !== undefined) this.layerStore.equJ2000Line = result.actionShow_Equator_J2000_Line === true
    if (result.actionShow_Ecliptic_J2000_Line !== undefined) this.layerStore.eclJ2000Line = result.actionShow_Ecliptic_J2000_Line === true
    if (result.actionShow_Celestial_Poles !== undefined) this.layerStore.celestialPoles = result.actionShow_Celestial_Poles === true
    if (result.actionShow_Ecliptic_Poles !== undefined) this.layerStore.eclipticPoles = result.actionShow_Ecliptic_Poles === true
    if (result.actionShow_Galactic_Poles !== undefined) this.layerStore.galacticPoles = result.actionShow_Galactic_Poles === true
    if (result.actionShow_Equinox_Points !== undefined) this.layerStore.equinoxPoints = result.actionShow_Equinox_Points === true
    if (result.actionShow_Solstice_Points !== undefined) this.layerStore.solsticePoints = result.actionShow_Solstice_Points === true
    if (result.actionShow_Antisolar_Point !== undefined) this.layerStore.antisolarPoint = result.actionShow_Antisolar_Point === true
    if (result.actionShow_Umbra_Circle !== undefined) this.layerStore.umbraCircle = result.actionShow_Umbra_Circle === true
    if (result.actionShow_Penumbra_Circle !== undefined) this.layerStore.penumbraCircle = result.actionShow_Penumbra_Circle === true
    if (result.actionShow_Compass_Marks !== undefined) this.layerStore.compassMarks = result.actionShow_Compass_Marks === true
    if (result.actionShow_FOV_Center_Marker !== undefined) this.layerStore.fovMarker = result.actionShow_FOV_Center_Marker === true
    if (result.actionShow_FOV_Circular_Marker !== undefined) this.layerStore.fovCircularMarker = result.actionShow_FOV_Circular_Marker === true
    if (result.actionShow_FOV_Rectangular_Marker !== undefined) this.layerStore.fovRectangularMarker = result.actionShow_FOV_Rectangular_Marker === true
    if (result.actionShow_Intercardinal_Points !== undefined) this.layerStore.intercardinalPts = result.actionShow_Intercardinal_Points === true
    if (result.actionShow_Secondary_Intercardinal_Points !== undefined) this.layerStore.secondaryIntercardinalPts = result.actionShow_Secondary_Intercardinal_Points === true
    if (result.actionShow_Tertiary_Intercardinal_Points !== undefined) this.layerStore.tertiaryIntercardinalPts = result.actionShow_Tertiary_Intercardinal_Points === true
    if (result.actionShow_Prime_Vertical_Line !== undefined) this.layerStore.primeVerticalLine = result.actionShow_Prime_Vertical_Line === true
    if (result.actionShow_Current_Vertical_Line !== undefined) this.layerStore.currentVerticalLine = result.actionShow_Current_Vertical_Line === true
    if (result.actionShow_Colure_Lines !== undefined) this.layerStore.colureLines = result.actionShow_Colure_Lines === true
    if (result.actionShow_Precession_Circles !== undefined) this.layerStore.precessionCircles = result.actionShow_Precession_Circles === true
    if (result.actionShow_Circumpolar_Circles !== undefined) this.layerStore.circumpolarCircles = result.actionShow_Circumpolar_Circles === true
    if (result.actionShow_Invariable_Plane_Line !== undefined) this.layerStore.invariantPlaneLine = result.actionShow_Invariable_Plane_Line === true
    if (result.actionShow_Solar_Equator_Line !== undefined) this.layerStore.solarEquatorLine = result.actionShow_Solar_Equator_Line === true
    if (result.actionShow_Ecliptic_J2000_Grid !== undefined) this.layerStore.eclipticJ2000Grid = result.actionShow_Ecliptic_J2000_Grid === true
    if (result.actionShow_Supergalactic_Grid !== undefined) this.layerStore.supergalacticGrid = result.actionShow_Supergalactic_Grid === true
    if (result.actionShow_Fixed_Equatorial_Grid !== undefined) this.layerStore.fixedEquatorialGrid = result.actionShow_Fixed_Equatorial_Grid === true
    if (result.actionShow_Fixed_Equator_Line !== undefined) this.layerStore.fixedEquatorLine = result.actionShow_Fixed_Equator_Line === true
    if (result.actionShow_Zenith_Nadir !== undefined) this.layerStore.zenithNadir = result.actionShow_Zenith_Nadir === true
    if (result.actionShow_Celestial_J2000_Poles !== undefined) this.layerStore.celestialJ2000Poles = result.actionShow_Celestial_J2000_Poles === true
    if (result.actionShow_Ecliptic_J2000_Poles !== undefined) this.layerStore.eclipticJ2000Poles = result.actionShow_Ecliptic_J2000_Poles === true
    if (result.actionShow_Equinox_J2000_Points !== undefined) this.layerStore.equinoxJ2000Pts = result.actionShow_Equinox_J2000_Points === true
    if (result.actionShow_Solstice_J2000_Points !== undefined) this.layerStore.solsticeJ2000Pts = result.actionShow_Solstice_J2000_Points === true
    if (result.actionShow_Galactic_Center !== undefined) this.layerStore.galacticCenter = result.actionShow_Galactic_Center === true
    if (result.actionShow_Supergalactic_Poles !== undefined) this.layerStore.supergalacticPoles = result.actionShow_Supergalactic_Poles === true
    if (result.actionShow_Apex_Points !== undefined) this.layerStore.apexPoints = result.actionShow_Apex_Points === true
    if (result.actionShow_Umbra_Center_Point !== undefined) this.layerStore.umbraCenter = result.actionShow_Umbra_Center_Point === true
    if (result.actionShow_Longitude_Line !== undefined) this.layerStore.longitudeLine = result.actionShow_Longitude_Line === true
    if (result.actionShow_Quadrature_Line !== undefined) this.layerStore.quadratureLine = result.actionShow_Quadrature_Line === true
    if (result.actionShow_Ray_Helpers !== undefined) this.layerStore.rayHelpers = result.actionShow_Ray_Helpers === true
    if (result.actionShow_LandscapeIllumination !== undefined) this.layerStore.landscapeIllum = result.actionShow_LandscapeIllumination === true
    if (result.actionShow_LandscapeLabels !== undefined) this.layerStore.landscapeLabels = result.actionShow_LandscapeLabels === true
    if (result.actionShow_Zodiac !== undefined) this.layerStore.zodiac = result.actionShow_Zodiac === true
    if (result.actionShow_LunarSystem !== undefined) this.layerStore.lunarSystem = result.actionShow_LunarSystem === true
    if (result.actionShow_Asterism_Lines !== undefined) this.layerStore.asterismLines = result.actionShow_Asterism_Lines === true
    if (result.actionShow_Asterism_Labels !== undefined) this.layerStore.asterismLabels = result.actionShow_Asterism_Labels === true
    if (result.actionShow_Hips_Surveys !== undefined) this.layerStore.hipsSurveys = result.actionShow_Hips_Surveys === true
    if (result.actionShow_Toast_Survey !== undefined) this.layerStore.toastSurvey = result.actionShow_Toast_Survey === true
    this.layerStore.meteors = result.meteors === true
    if (result.bortleScale !== undefined) this.layerViewStore.bortleScale = Math.round(result.bortleScale as number)
    if (result.milkyWayIntensity !== undefined) this.layerViewStore.milkyWayBright = Math.max(0, Math.min(6, Math.round((result.milkyWayIntensity as number) * 3)))
    if (result.luminanceAdaptation !== undefined) this.layerStore.luminanceAdaptation = result.luminanceAdaptation === true
    if (result.starTwinkle !== undefined) this.layerStore.starTwinkle = result.starTwinkle === true
    if (result.forcedStarTwinkle !== undefined) this.layerStore.forcedStarTwinkle = result.forcedStarTwinkle === true
    if (result.bigStarHalo !== undefined) this.layerStore.bigStarHalo = result.bigStarHalo === true
    if (result.starSpiky !== undefined) this.layerStore.starSpiky = result.starSpiky === true
    if (result.meteorZhr !== undefined) this.layerViewStore.meteorZhr = Math.round(result.meteorZhr as number)
    if (result.meteorZhrMax !== undefined) this.layerViewStore.meteorZhrMax = Math.max(1000, Math.round(result.meteorZhrMax as number))
    if (result.zodiacalLight !== undefined) this.layerStore.zodiacalLight = result.zodiacalLight === true
    if (result.zodiacalIntensity !== undefined) this.layerViewStore.zodiacalIntensity = result.zodiacalIntensity as number
    this.viewSettingsStore.autoZoomResets = result.autoZoomResets === true
    // The native Stellarium property is authoritative. The QAction is not
    // guaranteed to update when the time-panel uses the direct bridge command.
    if (result.nightMode !== undefined) {
      this.syncNightModeFromEngine(result.nightMode === true)
          } else if (result.actionShow_Night_Mode !== undefined) {
      this.syncNightModeFromEngine(result.actionShow_Night_Mode === true)
          }
    this.layerStore.flipHoriz = result.actionHorizontal_Flip === true
    this.layerStore.flipVert = result.actionVertical_Flip === true
    if (result.timeRate !== undefined) {
      this.syncTimeRateState(result.timeRate as number)
    }
    if (result.timeText !== undefined) {
      this.timeStore.observationTimeText = result.formattedTime ?? this.formatObservationTime(result.timeText)
      // 顺便校准 UTC 偏移（timeText 已含观测地偏移，jd 是纯 UTC；差值即偏移小时数）
      // 供轻量刷新 refreshSimTimeLight 使用，避免每次都跑全量 getState
      if (result.jd !== undefined) {
        const localMs = Date.parse(result.timeText.endsWith('Z') ? result.timeText : result.timeText + 'Z')
        const utcMs = ((result.jd as number) - 2440587.5) * 86400000
        if (!Number.isNaN(localMs)) {
          this.utcOffsetHours = Math.round((localMs - utcMs) / 3600000 * 4) / 4 // 取到一刻钟精度
        }
      }
    }
    // 只有当原生确实返回了观测者经纬度时，才用原生值刷新头部位置字段，
    // 否则保留 setLocation 已应用到头部的值（避免被 planetName 等字段清成“未命名”或空值）。
    if (result.latitude !== undefined && result.longitude !== undefined) {
      this.coordinateText = this.locationStore.formatDegrees(result.latitude, 'N', 'S') + ' / ' + this.locationStore.formatDegrees(result.longitude, 'E', 'W')
      if (result.locationName !== undefined && result.locationName.length > 0) {
        const planetName = result.planetName && result.planetName.length > 0 ? result.planetName : 'Earth'
        this.locationText = this.locationPickerStore.locationDisplayName(result.locationName) + ' · ' + planetZh(planetName)
      }
      if (result.altitude !== undefined) {
        this.altitudeText = result.altitude.toFixed(0) + ' m'
      }
      if (result.planetName !== undefined && result.planetName.length > 0) {
        this.sessionToolStore.observerPlanet = result.planetName
      }
    }
    if (result.fov !== undefined) {
      this.fovText = result.fov.toFixed(1) + '°'
      this.fovSliderValue = result.fov
      this.currentFovText = result.fov.toFixed(1) + '°'
    }
    if (result.tracking !== undefined && !this.trackingRequestPending && Date.now() >= this.trackingStateIgnoreUntilMs) {
      this.trackingText = result.tracking ? 'On' : 'Off'
    }
    if (result.viewLock !== undefined) {
      this.viewSettingsStore.viewLock = result.viewLock === true
    }
      this.stateRefreshRequestPending = false
      if (this.stateRefreshQueued) {
        this.stateRefreshQueued = false
        this.refreshState()
      }
    }, () => {
      this.stateRefreshRequestPending = false
      if (this.stateRefreshQueued) {
        this.stateRefreshQueued = false
        this.refreshState()
      }
    })
  }

  private setLayer(actionId: string, enabled: boolean): void {
    hilog.info(0x0000, 'StellariumArkUI', 'setLayer send %{public}s|%{public}s', actionId, enabled ? '1' : '0')
    this.callInteractive('setActionChecked', actionId + '|' + (enabled ? '1' : '0'), (r: StellariumBridgeResponse) => {
      hilog.info(0x0000, 'StellariumArkUI', 'setLayer %{public}s ok=%{public}s err=%{public}s', actionId, r.ok === true ? '1' : '0', r.error ?? '')
      this.refreshState()
      // 夜间模式和赤道仪模式切换时立即持久化，避免应用被杀死后丢失
      if (actionId === 'actionShow_Night_Mode') { this.persistNightMode() }
      if (actionId === 'actionSwitch_Equatorial_Mount') { this.persistEquatorialMount() }
    })
  }

  // Routed bridge flag: calls a named bridge command (e.g. setMeteors) with "1"/"0"
  private setBridgeFlag(cmd: string, enabled: boolean): void {
    hilog.info(0x0000, 'StellariumArkUI', 'setBridgeFlag send %{public}s|%{public}s', cmd, enabled ? '1' : '0')
    if (cmd === 'setViewLock') {
      this.setViewLockState(enabled)
      return
    }
    // 同步本地 @State：否则面板关闭重开后 Toggle 会显示旧值，再点一次就把状态发反了
    this.syncBridgeFlagState(cmd, enabled)
    this.callInteractive(cmd, enabled ? '1' : '0', (r: StellariumBridgeResponse) => {
      hilog.info(0x0000, 'StellariumArkUI', 'setBridgeFlag %{public}s ok=%{public}s err=%{public}s', cmd, r.ok === true ? '1' : '0', r.error ?? '')
      this.refreshState()
    })
  }

  private setOrbitDisplayFlag(setting: string, enabled: boolean): void {
    this.callInteractive('setOrbitDisplaySetting', setting + '|' + (enabled ? '1' : '0'), (r: StellariumBridgeResponse) => {
      if (r.ok !== true) return
      if (setting === 'isolated') this.layerViewStore.orbitIsolated = enabled
      else if (setting === 'majorPlanets') this.layerViewStore.orbitMajorPlanets = enabled
      else if (setting === 'planetsOnly') this.layerViewStore.orbitPlanetsOnly = enabled
      else if (setting === 'withMoons') this.layerViewStore.orbitWithMoons = enabled
      else if (setting === 'permanent') this.layerViewStore.orbitPermanent = enabled
    })
  }

  private setOrbitDisplayThickness(value: number): void {
    const thickness = Math.round(value)
    this.callInteractive('setOrbitDisplaySetting', 'thickness|' + thickness.toString(), (r: StellariumBridgeResponse) => {
      if (r.ok === true) this.layerViewStore.orbitThickness = thickness
    })
  }

  private setOrbitColorStyle(index: number): void {
    const values: string[] = ['one_color', 'groups', 'major_planets', 'major_planets_minor_types']
    const style = values[index] ?? 'one_color'
    this.callInteractive('setOrbitDisplaySetting', 'colorStyle|' + style, (r: StellariumBridgeResponse) => {
      if (r.ok === true) this.layerViewStore.orbitColorStyle = style
    })
  }

  private setTrailDisplayFlag(setting: string, enabled: boolean): void {
    this.callInteractive('setTrailDisplaySetting', setting + '|' + (enabled ? '1' : '0'), (r: StellariumBridgeResponse) => {
      if (r.ok === true && setting === 'isolated') this.layerViewStore.trailIsolated = enabled
    })
  }

  private setTrailDisplayNumber(setting: string, value: number): void {
    const number = Math.round(value)
    this.callInteractive('setTrailDisplaySetting', setting + '|' + number.toString(), (r: StellariumBridgeResponse) => {
      if (r.ok !== true) return
      if (setting === 'selectionCount') this.layerViewStore.trailSelectionCount = number
      else if (setting === 'years') this.layerViewStore.trailYears = number
      else if (setting === 'thickness') this.layerViewStore.trailThickness = number
    })
  }

  private applyTrailColor(): void {
    const normalized = this.layerViewStore.trailColorInput.trim().toUpperCase()
    if (!/^#[0-9A-F]{6}$/.test(normalized)) {
      this.flashHint('请输入 #RRGGBB 格式的颜色')
      return
    }
    this.callInteractive('setTrailDisplaySetting', 'color|' + normalized, (r: StellariumBridgeResponse) => {
      if (r.ok !== true) return
      this.layerViewStore.trailColor = r.trailColor !== undefined ? r.trailColor : normalized
      this.layerViewStore.trailColorInput = this.layerViewStore.trailColor
    })
  }

  // 把 cmd 型开关的最新值写回对应的本地 @State，保证 Toggle 重建时显示正确
  private syncBridgeFlagState(cmd: string, enabled: boolean): void {
    if (cmd === 'setViewLock') { this.viewSettingsStore.viewLock = enabled }
    else if (cmd === 'setVerticalClamp') { this.viewSettingsStore.verticalClamp = enabled }
    else if (cmd === 'setFlatHorizon') { this.viewSettingsStore.flatHorizon = enabled }
    else if (cmd === 'setMeteors') { this.layerStore.meteors = enabled }
    else if (cmd === 'setDsoLabels') { this.layerStore.dsoLabels = enabled }
    else if (cmd === 'setAutoZoomResets') { this.viewSettingsStore.autoZoomResets = enabled }
  }

  private setViewLockState(enabled: boolean): void {
    if (enabled && !this.objectDetailStore.hasSelectedObject()) {
      this.viewSettingsStore.viewLock = false
      this.flashHint(I18n.t('view_lock_requires_selection'))
      return
    }
    const previous = this.viewSettingsStore.viewLock
    this.viewSettingsStore.viewLock = enabled
    this.callInteractive('setViewLock', enabled ? '1' : '0', (r: StellariumBridgeResponse) => {
      if (r.ok !== true) {
        this.viewSettingsStore.viewLock = previous
        this.flashHint(r.selectionRequired === true ? I18n.t('view_lock_requires_selection') : I18n.t('msg_apply_failed'))
        return
      }
      if (r.viewLock !== undefined) this.viewSettingsStore.viewLock = r.viewLock === true
      if (r.tracking !== undefined) this.trackingText = r.tracking === true ? 'On' : 'Off'
      this.flashHint(this.viewSettingsStore.viewLock ? I18n.t('view_lock_enabled') : I18n.t('view_lock_disabled'))
    }, () => {
      this.viewSettingsStore.viewLock = previous
      this.flashHint(I18n.t('msg_apply_failed'))
    })
  }

  private toggleViewLock(): void {
    this.setViewLockState(!this.viewSettingsStore.viewLock)
  }



  private setSkyDisplaySetting(setting: string, value: boolean | number): void {
    if (setting === 'luminanceAdaptation') this.layerStore.luminanceAdaptation = value as boolean
    else if (setting === 'starTwinkle') this.layerStore.starTwinkle = value as boolean
    else if (setting === 'forcedStarTwinkle') this.layerStore.forcedStarTwinkle = value as boolean
    else if (setting === 'bigStarHalo') this.layerStore.bigStarHalo = value as boolean
    else if (setting === 'starSpiky') this.layerStore.starSpiky = value as boolean
    else if (setting === 'bortleScale') this.layerViewStore.bortleScale = Math.round(value as number)
    else if (setting === 'meteorZhr') this.layerViewStore.meteorZhr = Math.round(value as number)
    else if (setting === 'zodiacalLight') this.layerStore.zodiacalLight = value as boolean
    else if (setting === 'zodiacalIntensity') this.layerViewStore.zodiacalIntensity = value as number
    const payload = setting + '|' + (typeof value === 'boolean' ? (value ? '1' : '0') : value.toString())
    this.callInteractive('setSkyDisplaySetting', payload, (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        if (typeof value === 'boolean' || setting === 'bortleScale') this.refreshState()
      } else {
        this.flashHint(r.error ?? I18n.t('msg_apply_failed'))
        this.refreshState()
      }
    })
  }

  private applyStarMagLimit(value: number): void {
    this.layerViewStore.starMagLimit = value
    this.callInteractive('setLimitMagnitude', value.toFixed(1), () => {})
  }

  private applyMilkyWayBright(value: number): void {
    this.layerViewStore.milkyWayBright = value
    this.callInteractive('setMilkyWayIntensity', (value / 3).toFixed(2), () => {})
  }

  private setProjection(name: string): void {
    this.callInteractive('setProjectionType', name, (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.currentProjection = name
        this.flashHint(I18n.projectionName(name))
      } else {
        hilog.error(0x0000, 'StellariumArkUI', 'setProjectionType rejected %{public}s err=%{public}s', name, r.error ?? '')
        this.flashHint(I18n.t('msg_apply_failed'))
      }
    })
  }

  private setEphemerisEnabled(key: string, available: boolean, enabled: boolean): void {
    if (!available && enabled) {
      this.flashHint('该星历文件未安装，无法启用')
      return
    }
    this.callInteractive('setEphemerisSetting', key + '|' + (enabled ? '1' : '0'), (r: StellariumBridgeResponse) => {
      if (r.ok !== true) { this.flashHint(r.error ?? I18n.t('msg_apply_failed')); return }
      if (key === 'de430') this.ephemerisStore.ephemerisDe430Active = enabled
      else if (key === 'de431') this.ephemerisStore.ephemerisDe431Active = enabled
      else if (key === 'de440') this.ephemerisStore.ephemerisDe440Active = enabled
      else if (key === 'de441') this.ephemerisStore.ephemerisDe441Active = enabled
    })
  }

  private setInformationMode(mode: string): void {
    if (this.infoWindowStore.informationSettingPending || mode === this.infoWindowStore.informationMode) return
    this.infoWindowStore.informationSettingPending = true
    this.callInteractive('setInformationSetting', 'mode|' + mode, (r: StellariumBridgeResponse) => {
      this.infoWindowStore.informationSettingPending = false
      if (r.ok !== true) { this.flashHint(r.error ?? I18n.t('msg_apply_failed')); return }
      this.infoWindowStore.informationMode = r.infoMode ?? mode
      if (r.customInfoMask !== undefined) this.infoWindowStore.informationCustomMask = Number(r.customInfoMask)
      this.applySelectedInfoMode(this.infoWindowStore.informationMode)
      this.objectDetailStore.selectedDetailLoaded = false
      this.refreshSelectedObject()
    }, () => {
      this.infoWindowStore.informationSettingPending = false
      this.flashHint(I18n.t('msg_apply_failed'))
    })
  }

  private setInformationField(key: string, enabled: boolean): void {
    if (this.infoWindowStore.informationSettingPending || this.infoWindowStore.informationMode !== 'custom' || this.infoWindowStore.informationMaskHas(key) === enabled) return
    const bit = informationMaskBit(key)
    if (bit === 0) return
    const nextMask = enabled ? (this.infoWindowStore.informationCustomMask | bit) : (this.infoWindowStore.informationCustomMask & ~bit)
    this.infoWindowStore.informationSettingPending = true
    this.callInteractive('setInformationSetting', 'mask|' + nextMask.toString(), (r: StellariumBridgeResponse) => {
      this.infoWindowStore.informationSettingPending = false
      if (r.ok !== true) { this.flashHint(r.error ?? I18n.t('msg_apply_failed')); return }
      this.infoWindowStore.informationMode = 'custom'
      this.infoWindowStore.informationCustomMask = r.customInfoMask !== undefined ? Number(r.customInfoMask) : nextMask
      this.infoWindowStore.infoLevel = 0
      this.objectDetailStore.selectedDetailLoaded = false
      this.refreshSelectedObject()
    }, () => {
      this.infoWindowStore.informationSettingPending = false
      this.flashHint(I18n.t('msg_apply_failed'))
    })
  }

  private applyTimeSettings(result: StellariumBridgeResponse): void {
    if (result.ok !== true) return
    this.getUIContext().animateTo({ duration: UI_OPTION_ANIMATION_MS, curve: Curve.EaseOut }, () => {
      this.timeSettingsStore.startupTimeMode = result.startupTimeMode ?? this.timeSettingsStore.startupTimeMode
      this.deltaTStore.deltaTAlgorithm = result.deltaTAlgorithm ?? this.deltaTStore.deltaTAlgorithm
    })
    this.timeSettingsStore.startupTimeStop = result.startupTimeStop ?? this.timeSettingsStore.startupTimeStop
    this.timeSettingsStore.startupTodayTime = result.todayTime ?? this.timeSettingsStore.startupTodayTime
    this.timeSettingsStore.startupPresetLocalTime = result.presetLocalTime ?? this.timeSettingsStore.startupPresetLocalTime
    if (result.presetSkyTime !== undefined) this.timeSettingsStore.presetSkyTime = Number(result.presetSkyTime)
    this.timeSettingsStore.configDateFormat = result.dateFormat ?? this.timeSettingsStore.configDateFormat
    this.timeSettingsStore.configTimeFormat = result.timeFormat ?? this.timeSettingsStore.configTimeFormat
    this.timeStore.observationTimeText = result.formattedTime ?? this.timeStore.observationTimeText
    this.timeSettingsStore.timeSettingsZone = result.timeZone ?? this.timeSettingsStore.timeSettingsZone
    this.deltaTStore.deltaTDescription = result.deltaTDescription ?? this.deltaTStore.deltaTDescription
    this.deltaTStore.timeDeltaTAlgorithms = result.deltaTAlgorithms ?? this.deltaTStore.timeDeltaTAlgorithms
    this.deltaTStore.timeDeltaTCustom = result.deltaTCustom ?? this.deltaTStore.timeDeltaTCustom
  }

  private saveTimePreference(command: string, payload: string, message: string): void {
    if (this.timeSettingsPending) return
    this.timeSettingsPending = true
    this.callInteractive(command, payload, (result: StellariumBridgeResponse) => {
      this.timeSettingsPending = false
      if (result.ok !== true) {
        this.flashHint(I18n.t('time_settings_invalid') + ' ' + (result.error ?? ''))
        return
      }
      this.applyTimeSettings(result)
      this.flashHint(I18n.t(message))
      this.refreshSimTimeLight()
    }, () => {
      this.timeSettingsPending = false
      this.flashHint(I18n.t('msg_apply_failed'))
    })
  }

  private setStartupTimeSetting(key: string, value: string): void {
    if (key === 'startupStop' && (value === '1') === this.timeSettingsStore.startupTimeStop) return
    if (key === 'startupMode' && value === this.timeSettingsStore.startupTimeMode) return
    this.saveTimePreference('setTimeSetting', key + '|' + value.trim(),
      key === 'applyStartup' || key === 'deltaT' || key === 'deltaCustom' ? 'time_settings_applied' : 'time_settings_saved')
  }

  private setNavigationBoolean(setting: string, enabled: boolean): void {
    this.callInteractive('setNavigationSetting', setting + '|' + (enabled ? '1' : '0'), (r: StellariumBridgeResponse) => {
      if (r.ok !== true) {
        this.flashHint(I18n.t('msg_apply_failed'))
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

  private setNavigationMaxFov(value: number): void {
    const maxFov = Math.max(1, Math.min(360, Math.round(value)))
    this.callInteractive('setNavigationSetting', 'maxFov|' + maxFov.toString(), (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.navigationStore.navigationMaxFov = maxFov
        this.flashHint(I18n.t('settings_view_max_fov_updated'))
      } else {
        this.flashHint(I18n.t('msg_apply_failed'))
      }
    })
  }

  private saveAllCoreSettings(): void {
    this.saveAppSettings()
    this.callInteractive('saveAllSettings', '', (r: StellariumBridgeResponse) => {
      this.flashHint(r.ok === true ? I18n.t('settings_saved') : I18n.t('msg_apply_failed'))
    })
  }

  private restoreCoreDefaults(): void {
    this.callInteractive('restoreDefaultSettings', '', (r: StellariumBridgeResponse) => {
      if (r.ok !== true) {
        this.flashHint(I18n.t('msg_apply_failed'))
        return
      }
      this.flashHint(I18n.t('settings_defaults_restart'))
    })
  }

  private setConfigurationDateFormat(value: string): void {
    this.saveTimePreference('setDateFormat', value, 'time_settings_applied')
  }

  private setConfigurationTimeFormat(value: string): void {
    this.saveTimePreference('setTimeFormat', value, 'time_settings_applied')
  }

  private setConfigurationDithering(value: string): void {
    this.callInteractive('setDitheringMode', value.toLowerCase(), (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.viewSettingsStore.configDitheringMode = value
        this.flashHint('渲染质量已更新')
      } else {
        this.flashHint(r.error ?? I18n.t('msg_apply_failed'))
        this.timeSettingsStore.loadConfigurationSettings()
      }
    })
  }

  private setDistanceUnit(useMetric: boolean): void {
    this.callInteractive('setConfigString', 'astronomy/flag_use_km_for_distance=' + (useMetric ? 'true' : 'false'), (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.viewSettingsStore.useMetricUnits = useMetric
      } else {
        this.flashHint(r.error ?? I18n.t('msg_apply_failed'))
        this.timeSettingsStore.loadConfigurationSettings()
      }
    })
  }

  private triggerAction(actionId: string): void {
    hilog.info(0x0000, 'StellariumArkUI', 'triggerAction send %{public}s', actionId)
    this.flashHint(I18n.t('msg_command_sent'))
    this.callInteractive('triggerAction', actionId, (r: StellariumBridgeResponse) => {
      hilog.info(0x0000, 'StellariumArkUI', 'triggerAction %{public}s ok=%{public}s err=%{public}s', actionId, r.ok === true ? '1' : '0', r.error ?? '')
      this.refreshState()
      if (actionId.indexOf('actionDisplayInfo_') === 0) {
        this.refreshSelectedObject()
      }
    })
  }

  private resetAngleMeasure(): void {
    this.callInteractive('resetAngleMeasure', '', (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.tools.angleMeasureHasStart = false
        this.tools.angleMeasureHasEnd = false
        this.tools.angleMeasureText = ''
      }
    })
  }

  private measureAngleAt(x: number, y: number): void {
    const payload = Math.round(x).toString() + '|' + Math.round(y).toString() + '|' +
      Math.round(this.skyWidth).toString() + '|' + Math.round(this.skyHeight).toString()
    this.callInteractive('angleMeasurePoint', payload, (r: StellariumBridgeResponse) => {
      if (r.ok !== true) {
        this.flashHint('测量点无效，请重新点击')
        return
      }
      this.tools.angleMeasureHasStart = r.hasStart === true
      this.tools.angleMeasureHasEnd = r.hasEnd === true
      this.tools.angleMeasureText = r.angleText ?? ''
      this.flashHint(this.tools.angleMeasureHasEnd ? '角距离：' + this.tools.angleMeasureText : '已记录第一个位置，请点击第二个位置')
    })
  }

  private jdToDateStr(jd: string): string {
    if (jd.indexOf('T') >= 0) {
      const match = jd.match(/^(?:\d{4}-)?(\d{2})-(\d{2})T(\d{2}):(\d{2})/)
      if (match !== null) return parseInt(match[1]).toString() + '/' + parseInt(match[2]).toString() + ' ' + match[3] + ':' + match[4]
    }
    const numJd = parseFloat(jd);
    if (numJd <= 0) return '--'
    const date = new Date((numJd - 2440587.5) * 86400000)
    return (date.getMonth() + 1).toString() + '/' + date.getDate().toString()
      + ' ' + date.getHours().toString().padStart(2, '0') + ':' + date.getMinutes().toString().padStart(2, '0')
  }


  private jumpToRts(key: string): void {
    const jd = this.astroStore.rtsData.get(key) ?? '0'
    if (parseFloat(jd) <= 0) {
      this.flashHint('该天体在当前位置没有这个事件。')
      return
    }
    this.callInteractive('setJD', jd, (r: StellariumBridgeResponse) => {
      if (r.ok === true) this.refreshState()
    })
  }


  private async exportCurrentAstroCsv(): Promise<void> {
    this.astroStore.updateAstroCalcSnapshot()
    const exportData = this.astroStore.astroCsvExport(this.wutStore.wutTargets, this.wutStore.wutObservationTime)
    if (exportData === undefined || exportData.rows.length === 0) {
      this.flashHint('当前页没有可导出的计算结果，请先生成数据。')
      return
    }
    this.astroStore.astroExporting = true
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const saveOptions = new picker.DocumentSaveOptions()
      saveOptions.newFileNames = ['astrocalc-' + Date.now().toString() + '.csv']
      saveOptions.fileSuffixChoices = ['CSV 表格|.csv']
      const viewPicker = new picker.DocumentViewPicker(context)
      const selectedUris = await viewPicker.save(saveOptions)
      if (selectedUris.length === 0 || selectedUris[0].length === 0) {
        this.flashHint('已取消保存。')
        return
      }
      const scratchPath = context.cacheDir + '/astrocalc-' + Date.now().toString() + '.csv'
      const file = fileIo.openSync(scratchPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
      const encoder = new util.TextEncoder('utf-8')
      const bytes = encoder.encodeInto(this.astroStore.makeAstroCsv(exportData))
      fileIo.writeSync(file.fd, bytes.buffer)
      fileIo.closeSync(file)
      await fileIo.copy(fileUri.getUriFromPath(scratchPath), selectedUris[0])
      try { fileIo.unlinkSync(scratchPath) } catch (error) {}
      this.flashHint('已保存 ' + exportData.title + ' CSV。')
    } catch (error) {
      hilog.error(0x0000, 'StellariumArkUI', 'AstroCalc CSV export failed: %{public}s', String(error))
      this.flashHint('保存失败，请检查文件管理权限后重试。')
    } finally {
      this.astroStore.astroExporting = false
    }
  }






  private chooseRtsCalendarStartDate(): void {
    this.pickedDate = new Date(this.astroStore.rtsCalendarStartYear, this.astroStore.rtsCalendarStartMonth - 1, this.astroStore.rtsCalendarStartDay)
    this.getUIContext().showDatePickerDialog({
      start: new Date('1900-01-01'),
      end: new Date('2100-12-31'),
      selected: this.pickedDate,
      onAccept: (value: DatePickerResult) => {
        this.astroStore.rtsCalendarStartYear = value.year ?? this.astroStore.rtsCalendarStartYear
        this.astroStore.rtsCalendarStartMonth = (value.month ?? (this.astroStore.rtsCalendarStartMonth - 1)) + 1
        this.astroStore.rtsCalendarStartDay = value.day ?? this.astroStore.rtsCalendarStartDay
        this.astroStore.rtsCalendarStartOffsetDays = -1
        this.astroStore.markRtsCalendarForRegeneration()
      },
      onCancel: () => {}
    })
  }

  private jumpToRtsCalendar(day: RtsCalendarDay): void {
    const jd = day.transitJD ?? day.riseJD ?? day.setJD ?? 0
    if (jd <= 0) return
    this.callInteractive('setJD', jd.toString(), (r: StellariumBridgeResponse) => {
      if (r.ok === true) this.refreshState()
    })
  }




  private chooseEphemerisStartDate(): void {
    this.pickedDate = new Date(this.ephemerisStore.ephemerisStartYear, this.ephemerisStore.ephemerisStartMonth - 1, this.ephemerisStore.ephemerisStartDay)
    this.getUIContext().showDatePickerDialog({
      start: new Date('1900-01-01'),
      end: new Date('2100-12-31'),
      selected: this.pickedDate,
      onAccept: (value: DatePickerResult) => {
        this.ephemerisStore.ephemerisStartYear = value.year ?? this.ephemerisStore.ephemerisStartYear
        this.ephemerisStore.ephemerisStartMonth = (value.month ?? (this.ephemerisStore.ephemerisStartMonth - 1)) + 1
        this.ephemerisStore.ephemerisStartDay = value.day ?? this.ephemerisStore.ephemerisStartDay
        this.astroStore.ephemerisStartOffsetDays = -1
        this.astroStore.loadEphemeris()
      },
      onCancel: () => {}
    })
  }

  private jumpToEphemerisRow(row: EphemerisRow): void {
    if (row.jd === undefined || row.jd <= 0) return
    this.callInteractive('setJD', String(row.jd), (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.refreshState()
        this.astroStore.loadEphemeris()
      }
    })
  }














  private chooseGraphStartDate(): void {
    this.pickedDate = new Date(this.astroStore.graphStartYear, this.astroStore.graphStartMonth - 1, this.astroStore.graphStartDay)
    this.getUIContext().showDatePickerDialog({
      start: new Date('1900-01-01'),
      end: new Date('2100-12-31'),
      selected: this.pickedDate,
      onAccept: (value: DatePickerResult) => {
        this.astroStore.graphStartYear = value.year ?? this.astroStore.graphStartYear
        this.astroStore.graphStartMonth = (value.month ?? (this.astroStore.graphStartMonth - 1)) + 1
        this.astroStore.graphStartDay = value.day ?? this.astroStore.graphStartDay
        this.astroStore.graphStartOffsetDays = -1
        this.reloadCurrentGraph()
      },
      onCancel: () => {}
    })
  }

  private reloadCurrentGraph(): void {
    if (this.astroStore.graphMode === 2) this.astroStore.loadAnnualElevation()
    else if (this.astroStore.graphMode === 3) this.astroStore.loadObservabilityCalendar()
    else if (this.astroStore.graphMode === 4) this.astroStore.loadLunarElongation()
    else if (this.astroStore.graphMode === 5) this.astroStore.loadPlanetTimeSeries()
    else this.astroStore.loadAltAzCurve()
  }

  private openGraphTargetPicker(): void {
    this.graphTargetPickerActive = true
    this.searchStore.searchText = ''
    this.searchStore.searchSuggestions = []
    this.searchStore.loadCategoryObjects('planet')
    this.setPanel('search')
  }

  private openRtsTargetPicker(): void {
    this.rtsTargetPickerActive = true
    this.searchStore.searchText = ''
    this.searchStore.searchSuggestions = []
    this.searchStore.loadCategoryObjects('planet')
    this.setPanel('search')
  }

  private openEphemerisTargetPicker(): void {
    this.ephemerisTargetPickerActive = true
    this.searchStore.searchText = ''
    this.searchStore.searchSuggestions = []
    this.searchStore.loadCategoryObjects('planet')
    this.setPanel('search')
  }




  private jumpToObservabilityDay(day: ObservabilityDay): void {
    if (day.bestJD === undefined || day.bestJD <= 0) return
    this.callInteractive('setJD', String(day.bestJD), (r: StellariumBridgeResponse) => {
      if (r.ok === true) this.refreshState()
    })
  }





  private chooseEclipseStartDate(): void {
    this.pickedDate = new Date(this.astroStore.eclipseStartYear, this.astroStore.eclipseStartMonth - 1, this.astroStore.eclipseStartDay)
    this.getUIContext().showDatePickerDialog({
      start: new Date('1900-01-01'),
      end: new Date('2100-12-31'),
      selected: this.pickedDate,
      onAccept: (value: DatePickerResult) => {
        this.astroStore.eclipseStartYear = value.year ?? this.astroStore.eclipseStartYear
        this.astroStore.eclipseStartMonth = (value.month ?? (this.astroStore.eclipseStartMonth - 1)) + 1
        this.astroStore.eclipseStartDay = value.day ?? this.astroStore.eclipseStartDay
        this.astroStore.eclipseStartOffsetDays = -1
        this.astroStore.reloadEclipses()
      },
      onCancel: () => {}
    })
  }








  private jumpToPhenomenon(item: PhenomenonItem): void {
    if (item.jd === undefined || item.jd <= 0) return
    this.callInteractive('setJD', String(item.jd), (r: StellariumBridgeResponse) => {
      if (r.ok === true) this.refreshState()
    })
  }



  private addWutTargetToObservingList(target: WutTarget): void {
    const name = (target.englishName ?? '').trim()
    if (name.length === 0 || this.obsListStore.observingList.includes(name)) { return }
    this.obsListStore.observingList = this.obsListStore.observingList.concat([name])
    this.persistObservingList()
    this.flashHint(I18n.t('i0080'))
  }

  private removeObservingTarget(name: string): void {
    this.obsListStore.observingList = this.obsListStore.observingList.filter((item: string) => item !== name)
    this.persistObservingList()
    this.flashHint(I18n.t('i0079'))
  }

  private jumpToWutTarget(target: WutTarget): void {
    if (target.jd === undefined || target.jd <= 0 || target.englishName === undefined) return
    const targetName = target.englishName
    this.callInteractive('setJD', String(target.jd), (timeResult: StellariumBridgeResponse) => {
      if (timeResult.ok !== true) { return }
      // Selecting is not centring. searchObject only marks the target; the
      // engine's own handler never moves the view (on device the log showed a
      // bare setJD + searchObject and no moveToSelected*/setTracking command at
      // all), so this row button looked dead. Run the same post-selection
      // placement the global search uses - applySelectedObject with
      // placement 'center' - so the row centres like every other entry point.
      this.callInteractive('searchObject', targetName, (selectResult: StellariumBridgeResponse) => {
        if (selectResult.found !== true) { return }
          this.applySelectedObject(selectResult, false, 'center', true)
      })
    })
  }

  // 大气参数回包写入 AtmosphereStore。保留宿主实现（§13.1 规则 6）：与 applyAtmosphere 共用，
  // 并由 TimeStore.loadTimeExtras 经 TimeHostHooks 注入调用（§14 B2R-2）。
  private applyAtmosphereResponse(r: StellariumBridgeResponse): void {
    if (r.ok !== true) return
    if (r.pressure !== undefined) this.atmosphereStore.atmoPressure = r.pressure
    if (r.temperature !== undefined) this.atmosphereStore.atmoTemperature = r.temperature
    if (r.extinction !== undefined) this.atmosphereStore.atmoExtinction = r.extinction
    this.atmosphereStore.refractionOn = (r.refractionOn === true)
  }

  private applyAtmosphere(pressure: number, temperature: number, extinction: number): void {
    this.applyAtmosphereResponse(this.callNative('setAtmosphereParams',
      JSON.stringify({ pressure: pressure, temperature: temperature, extinction: extinction })))
  }

  // ---- 天文计算辅助：高度曲线 ----



















  private planetTimeSeriesValueLabel(value: number | undefined, metric: string): string {
    return (value ?? 0).toFixed(metric === 'angularSize' ? 0 : 1) + planetMetricUnit(metric)
  }







  private celestialPositionSubtitle(position: CelestialPosition): string {
    if (position.catalogId.length > 0 && position.catalogId !== celestialTitle(position.name, position.englishName)) return position.catalogId
    return position.type
  }

  // ---- 通用格式化：把 ISO 时间截成 "MM-DD HH:MM" / "HH:MM" ----
  private fmtDateTime(s: string | undefined): string {
    if (s === undefined || s.length === 0) return '--'
    return s.replace('T', ' ').slice(0, 16)
  }

  private fmtClock(s: string | undefined): string {
    if (s === undefined || s.length < 16) return '--:--'
    return s.slice(11, 16)
  }

  private fmtEphemerisDate(s: string | undefined): string {
    if (s === undefined || s.length < 16) return '--'
    return s.slice(5, 16).replace('T', ' ')
  }

  private fmtNum(v: number | undefined, digits: number, suffix: string): string {
    if (v === undefined) return '--'
    return v.toFixed(digits) + suffix
  }





  private publishAstroPanelState(): void {
    AppStorage.setOrCreate('stellariumAstroPanelState', JSON.stringify({
      ok: true, group: this.astroStore.astroGroup, tab: this.astroStore.astroTab,
      requestedTab: this.astroRequestedTab, transitionId: this.astroTransitionId,
      transitioning: this.astroRequestedTab >= 0,
      loading: this.wutStore.wutLoading,
      period: this.wutStore.wutPeriod, altitude: this.wutStore.wutMinAltitude,
      magnitude: this.wutStore.wutMaxMagnitude, direction: this.wutStore.wutDirection,
      scrollY: this.activePanel === 'astro' && this.panelVisible ? this.astroPanelScroller.currentOffset().yOffset : 0
    }))
  }

  private selectAstroFilter(key: string, value: string): void {
    if (key === 'period' && ['evening', 'midnight', 'morning', 'night'].includes(value)) {
      if (this.wutStore.wutPeriod === value) return
      this.wutStore.wutPeriod = value
    } else if (key === 'altitude' && ['0', '10', '20', '30', '45'].includes(value)) {
      if (this.wutStore.wutMinAltitude === Number(value)) return
      this.wutStore.wutMinAltitude = Number(value)
    } else if (key === 'magnitude' && ['4', '6', '8', '10'].includes(value)) {
      if (this.wutStore.wutMaxMagnitude === Number(value)) return
      this.wutStore.wutMaxMagnitude = Number(value)
    } else if (key === 'direction' && ['all', 'north', 'east', 'south', 'west'].includes(value)) {
      if (this.wutStore.wutDirection === value) return
      this.wutStore.wutDirection = value
    } else return
    this.publishAstroPanelState()
    this.wutStore.loadWutTargets()
  }

  private selectAstroGroup(group: number): void {
    if (group < 0 || group > 2) return
    const tabs = astroTabItemsForGroup(group)
    const currentTab = tabs.find((item: TabItem) => item.id === this.astroStore.astroTab)
    this.selectAstroTab(currentTab !== undefined ? currentTab.id : tabs[0].id)
  }

  private selectAstroTab(tab: number): void {
    if (!Number.isInteger(tab) || tab < 0 || tab > 9 || tab === this.astroRequestedTab) return
    if (tab === this.astroStore.astroTab && this.astroRequestedTab < 0) return
    const order: number[] = [5, 2, 4, 9, 0, 1, 6, 3, 7, 8]
    const direction: number = order.indexOf(tab) >= order.indexOf(this.astroStore.astroTab) ? 1 : -1
    const transitionId = ++this.astroTransitionId
    this.astroRequestedTab = tab
    this.publishAstroPanelState()
    this.getUIContext().animateTo({ duration: 100, curve: Curve.EaseIn, onFinish: () => {
      if (transitionId !== this.astroTransitionId) return
      if (!this.panelVisible || this.activePanel !== 'astro') {
        this.astroRequestedTab = -1
        this.astroStore.astroContentOpacity = 1
        this.astroStore.astroContentOffsetX = 0
        this.publishAstroPanelState()
        return
      }
      this.astroStore.astroTab = tab
      this.astroStore.astroGroup = astroGroupForTab(tab)
      this.astroPanelScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false })
      this.astroStore.astroContentOffsetX = direction * 10
      this.getUIContext().animateTo({ duration: 170, curve: Curve.EaseOut, onFinish: () => {
        if (transitionId !== this.astroTransitionId) return
        this.astroRequestedTab = -1
        this.publishAstroPanelState()
        if (!this.panelVisible || this.activePanel !== 'astro') return
        this.saveAppSettings()
        this.astroStore.loadAstroTab(tab)
      } }, () => {
        this.astroStore.astroContentOpacity = 1
        this.astroStore.astroContentOffsetX = 0
      })
    } }, () => {
      this.astroStore.astroContentOpacity = 0
      this.astroStore.astroContentOffsetX = (0 - direction) * 8
    })
  }

  private openAstroTargetPicker(): void {
    if (this.astroStore.astroTab === 2) {
      this.openRtsTargetPicker()
    } else if (this.astroStore.astroTab === 4) {
      this.openGraphTargetPicker()
    } else {
      this.openEphemerisTargetPicker()
    }
  }





  private jumpToMoonPhase(item: MoonPhaseItem): void {
    if (item.jd === undefined || item.jd <= 0) return
    this.callInteractive('setJD', String(item.jd), () => { this.refreshState() })
  }


  private jumpToAlmanacSeason(event: SeasonEvent): void {
    if (event.jd === undefined || event.jd <= 0) return
    this.callInteractive('setJD', String(event.jd), (r: StellariumBridgeResponse) => {
      if (r.ok === true) this.refreshState()
    })
  }

  private selectSkyCulture(id: string): void {
    if (id === this.skyCultureViewStore.currentSkyCultureId || id === this.skyCultureViewStore.pendingId) return
    this.captureSkyCultureAnchor(id)
    const requestId = ++this.skyCultureDetailsRequestId
    this.skyCultureViewStore.pendingId = id
    this.skyCultureViewStore.detailsLoading = true
    this.skyCultureViewStore.detailError = ''
    this.callInteractive('setSkyCulture', id, (r: StellariumBridgeResponse) => {
      if (requestId !== this.skyCultureDetailsRequestId) return
      if (r.ok === true) {
        this.skyCultureViewStore.currentSkyCultureId = r.cultureId !== undefined ? r.cultureId : id
        const selected = this.skyCultureViewStore.skyCultureList.find((item: SkyCultureItem) => item.id === this.skyCultureViewStore.currentSkyCultureId)
        this.skyCultureViewStore.currentSkyCulture = r.culture !== undefined ? this.skyCultureSettingsStore.skyCultureDisplayName(this.skyCultureViewStore.currentSkyCultureId, r.culture) : (selected !== undefined ? this.skyCultureSettingsStore.skyCultureDisplayName(selected.id, selected.name) : id)
        this.skyCultureSettingsStore.skyCultureLabelPickerOpen = ''
        this.skyCultureSettingsStore.skyCultureClassificationFilterOpen = false
        this.skyCultureSettingsStore.skyCultureRegionFilterOpen = false
        this.skyCultureViewStore.narrationExpanded = false
        this.skyCultureViewStore.descriptionExpanded = false
        this.skyCultureViewStore.artExpanded = false
        this.closeSkyCultureArtPreview()
        this.skyCultureSettingsStore.skyCultureTerritoryExpanded = false
        this.skyCultureSettingsStore.skyCultureTerritoryMapExpanded = false
        this.skyCultureSettingsStore.skyCultureTerritoryMapPolygons = []
        this.skyCultureSettingsStore.skyCultureTerritoryMapError = ''
        this.loadSkyCultureDetails()
        return
      }
      this.skyCultureViewStore.pendingId = ''
      this.skyCultureViewStore.detailsLoading = false
      this.skyCultureViewStore.detailError = '切换星空文化失败，请重试。'
      this.clearSkyCultureAnchor()
    }, () => {
      if (requestId !== this.skyCultureDetailsRequestId) return
      this.skyCultureViewStore.pendingId = ''
      this.skyCultureViewStore.detailsLoading = false
      this.skyCultureViewStore.detailError = '切换星空文化失败，请重试。'
      this.clearSkyCultureAnchor()
    })
  }

  private captureSkyCultureAnchor(id: string): void {
    const y = this.skyCultureRowY[id]
    if (y === undefined || !Number.isFinite(y)) {
      hilog.info(0x0000, 'StellariumArkUI', '[sky-culture-anchor] row not measured id=%{public}s', id)
      this.clearSkyCultureAnchor()
      return
    }
    this.skyCultureAnchorId = id
    this.skyCultureAnchorY = y
    this.skyCultureAnchorRequestId = 0
    this.skyCultureAnchorArmed = false
    hilog.info(0x0000, 'StellariumArkUI',
      '[sky-culture-anchor] captured id=%{public}s y=%{public}s', id, y.toFixed(1))
  }

  private armSkyCultureAnchor(id: string, requestId: number): void {
    if (this.skyCultureAnchorId !== id) return
    this.skyCultureAnchorRequestId = requestId
    this.skyCultureAnchorArmed = true
  }

  private clearSkyCultureAnchor(): void {
    this.skyCultureAnchorId = ''
    this.skyCultureAnchorY = 0
    this.skyCultureAnchorRequestId = 0
    this.skyCultureAnchorArmed = false
  }

  private handleSkyCultureRowArea(id: string, area: Area): void {
    const y = Number.parseFloat(String(area.globalPosition.y))
    if (!Number.isFinite(y)) return
    this.skyCultureRowY[id] = y
    if (!this.skyCultureAnchorArmed || this.skyCultureAnchorId !== id ||
      this.skyCultureAnchorRequestId !== this.skyCultureDetailsRequestId) return
    const delta = y - this.skyCultureAnchorY
    this.clearSkyCultureAnchor()
    if (Math.abs(delta) < 0.5) {
      hilog.info(0x0000, 'StellariumArkUI',
        '[sky-culture-anchor] stable id=%{public}s y=%{public}s', id, y.toFixed(1))
      return
    }
    try {
      const scroller = this.isExpandedLayout ? this.widePanelScroller : this.compactPanelScroller
      const offset = scroller.currentOffset()
      const targetOffset = Math.max(0, offset.yOffset + delta)
      scroller.scrollTo({ xOffset: offset.xOffset, yOffset: targetOffset, animation: false })
      hilog.info(0x0000, 'StellariumArkUI',
        '[sky-culture-anchor] id=%{public}s delta=%{public}s offset=%{public}s',
        id, delta.toFixed(1), targetOffset.toFixed(1))
    } catch (error) {
      hilog.warn(0x0000, 'StellariumArkUI',
        '[sky-culture-anchor] correction failed id=%{public}s error=%{public}s', id, String(error))
    }
  }

  private loadSkyCultureDetails(): void {
    if (this.skyCultureViewStore.currentSkyCultureId.length === 0) return
    const requestId = ++this.skyCultureDetailsRequestId
    this.skyCultureViewStore.detailsLoading = true
    this.skyCultureViewStore.detailError = ''
    this.callInteractive('getSkyCultureDetails', '', (r: StellariumBridgeResponse) => {
      if (requestId !== this.skyCultureDetailsRequestId) return
      if (r.ok !== true) {
        this.skyCultureViewStore.detailError = '未能读取该文化的资料。'
        this.skyCultureViewStore.detailsLoading = false
        this.clearSkyCultureAnchor()
        return
      }
      this.skyCultureViewStore.currentSkyCultureId = r.id !== undefined ? r.id : this.skyCultureViewStore.currentSkyCultureId
      this.armSkyCultureAnchor(this.skyCultureViewStore.currentSkyCultureId, requestId)
      this.skyCultureViewStore.currentSkyCulture = r.name !== undefined ? this.skyCultureSettingsStore.skyCultureDisplayName(this.skyCultureViewStore.currentSkyCultureId, r.name) : this.skyCultureViewStore.currentSkyCulture
      this.skyCultureSettingsStore.skyCultureLabelPickerOpen = ''
      this.skyCultureSettingsStore.skyCultureRegions = r.region !== undefined ? r.region : []
      this.skyCultureSettingsStore.skyCultureClassification = r.classification !== undefined ? r.classification : ''
      this.skyCultureSettingsStore.skyCultureLicense = r.license !== undefined ? r.license : ''
      this.skyCultureSettingsStore.skyCultureBoundariesType = r.boundariesType !== undefined ? r.boundariesType : 'none'
      this.skyCultureSettingsStore.skyCultureUsesCommonNames = r.usesCommonNames === true
      this.skyCultureSettingsStore.skyCultureBeginTime = r.beginTime !== undefined ? r.beginTime : 0
      this.skyCultureSettingsStore.skyCultureEndTime = r.endTime !== undefined ? r.endTime : 0
      this.skyCultureSettingsStore.skyCultureConstellationCount = r.constellationCount !== undefined ? r.constellationCount : 0
      this.skyCultureSettingsStore.skyCultureAsterismCount = r.asterismCount !== undefined ? r.asterismCount : 0
      this.skyCultureSettingsStore.skyCultureNativeNameCount = r.nativeNameCount !== undefined ? r.nativeNameCount : 0
      this.skyCultureSettingsStore.skyCultureArtCount = r.artCount !== undefined ? r.artCount : 0
      this.skyCultureSettingsStore.skyCultureHasAsterisms = r.hasAsterisms === true
      this.skyCultureSettingsStore.skyCultureHasZodiac = r.hasZodiac === true
      this.skyCultureSettingsStore.skyCultureHasLunarSystem = r.hasLunarSystem === true
      this.skyCultureSettingsStore.skyCultureShortLabels = r.abbreviatedNames === true
      this.skyCultureSettingsStore.skyCultureOverrideCommonNames = r.overrideCommonNames === true
      this.skyCultureSettingsStore.skyCultureDefaultId = r.defaultId !== undefined ? r.defaultId : ''
      this.skyCultureSettingsStore.skyCultureScreenStyleMask = this.skyCultureSettingsStore.skyCultureStyleMaskFromBridge(r.screenLabelStyle)
      this.skyCultureSettingsStore.skyCultureInfoStyleMask = this.skyCultureSettingsStore.skyCultureStyleMaskFromBridge(r.infoLabelStyle)
      this.skyCultureSettingsStore.skyCultureScreenLabelMode = this.skyCultureSettingsStore.skyCultureScreenLabelModeFromBridge(r.screenLabelStyle)
      this.skyCultureSettingsStore.skyCultureInfoLabelMode = this.skyCultureSettingsStore.skyCultureScreenLabelModeFromBridge(r.infoLabelStyle)
      this.skyCultureSettingsStore.skyCultureZodiacLabelMode = this.skyCultureSettingsStore.skyCultureScreenLabelModeFromBridge(r.zodiacLabelStyle)
      this.skyCultureSettingsStore.skyCultureLunarLabelMode = this.skyCultureSettingsStore.skyCultureScreenLabelModeFromBridge(r.lunarSystemLabelStyle)
      this.skyCultureViewStore.narration = cleanSkyCultureNarration(r.narration !== undefined ? r.narration : '')
      this.skyCultureViewStore.description = cleanSkyCultureDescription(r.description !== undefined ? r.description : '')
      this.skyCultureViewStore.descriptionBlocks = r.descriptionBlocks !== undefined ? r.descriptionBlocks : []
      this.clearSkyCultureArtThumbnails()
      this.skyCultureViewStore.artItems = r.constellationArt !== undefined ? r.constellationArt : []
      this.skyCultureArtStates = {}
      this.closeSkyCultureArtPreview()
      this.prepareSkyCultureArtResources(this.skyCultureViewStore.artItems, requestId)
      this.skyCultureSettingsStore.skyCultureHasTerritoryArchive = r.hasTerritoryArchive === true
      this.skyCultureSettingsStore.skyCultureTerritorySegmentCount = r.territorySegmentCount !== undefined ? r.territorySegmentCount : 0
      this.skyCultureSettingsStore.skyCultureTerritoryArchive = r.territoryArchive !== undefined ? r.territoryArchive : []
      if (r.territorySimulationYear !== undefined) {
        this.skyCultureSettingsStore.skyCultureSimulationYear = r.territorySimulationYear
        if (this.skyCultureSettingsStore.skyCultureTimeFollowSimulation) this.skyCultureSettingsStore.setSkyCultureTimeYear(this.skyCultureSettingsStore.skyCultureSimulationYear)
        if (!this.skyCultureSettingsStore.skyCultureTerritoryMapExpanded) this.skyCultureSettingsStore.setSkyCultureTerritoryMapYear(r.territorySimulationYear)
      }
      this.skyCultureViewStore.detailsReady = true
      this.skyCultureViewStore.pendingId = ''
      this.skyCultureViewStore.detailsLoading = false
      this.skyCultureSettingsStore.loadSkyCultureConstellationSelectionFlags()
      this.skyCultureSettingsStore.loadSkyCultureVisualSettings()
    }, () => {
      if (requestId !== this.skyCultureDetailsRequestId) return
      this.skyCultureViewStore.pendingId = ''
      this.skyCultureViewStore.detailsLoading = false
      this.skyCultureViewStore.detailError = '未能读取该文化的资料。'
      this.clearSkyCultureAnchor()
    })
  }







  private setSkyCultureStyleOption(target: string, optionIndex: number, enabled: boolean): void {
    const oldMask = target === 'screen' ? this.skyCultureSettingsStore.skyCultureScreenStyleMask : this.skyCultureSettingsStore.skyCultureInfoStyleMask
    const bit = 1 << optionIndex
    const nextMask = enabled ? (oldMask | bit) : (oldMask & ~bit)
    this.callInteractive('setSkyCultureLabelStyle', target + '|' + this.skyCultureSettingsStore.skyCultureStyleValue(nextMask), (r: StellariumBridgeResponse) => {
      if (r.ok !== true) return
      const style = target === 'screen' ? r.screenLabelStyle : r.infoLabelStyle
      const actualMask = this.skyCultureSettingsStore.skyCultureStyleMaskFromBridge(style)
      if (target === 'screen') {
        this.skyCultureSettingsStore.skyCultureScreenStyleMask = actualMask
        this.skyCultureSettingsStore.skyCultureScreenLabelMode = this.skyCultureSettingsStore.skyCultureScreenLabelModeFromBridge(style)
      } else {
        this.skyCultureSettingsStore.skyCultureInfoStyleMask = actualMask
        this.skyCultureSettingsStore.skyCultureInfoLabelMode = this.skyCultureSettingsStore.skyCultureScreenLabelModeFromBridge(style)
      }
    })
  }


  private setSkyCultureScreenLabelMode(mode: number): void {
    this.setSkyCultureLabelMode('screen', mode, (value: number) => { this.skyCultureSettingsStore.skyCultureScreenLabelMode = value })
  }

  private setSkyCultureInfoLabelMode(mode: number): void {
    this.setSkyCultureLabelMode('info', mode, (value: number) => { this.skyCultureSettingsStore.skyCultureInfoLabelMode = value })
  }

  private setSkyCultureZodiacLabelMode(mode: number): void {
    this.setSkyCultureLabelMode('zodiac', mode, (value: number) => { this.skyCultureSettingsStore.skyCultureZodiacLabelMode = value })
  }

  private setSkyCultureLunarLabelMode(mode: number): void {
    this.setSkyCultureLabelMode('lunar', mode, (value: number) => { this.skyCultureSettingsStore.skyCultureLunarLabelMode = value })
  }


  private setSkyCultureLabelModeForTarget(target: string, mode: number): void {
    if (target === 'screen') {
      this.setSkyCultureScreenLabelMode(mode)
    } else if (target === 'info') {
      this.setSkyCultureInfoLabelMode(mode)
    } else if (target === 'zodiac') {
      this.setSkyCultureZodiacLabelMode(mode)
    } else {
      this.setSkyCultureLunarLabelMode(mode)
    }
  }


  // 选择某个标签模式并收起该卡片的下拉（原 skyCultureLabelModePicker 内联逻辑）。
  private selectSkyCultureLabelMode(target: string, index: number): void {
    this.setSkyCultureLabelModeForTarget(target, index)
    this.getUIContext().animateTo({ duration: 180, curve: curves.springMotion(0.46, 0.86) }, () => {
      this.skyCultureSettingsStore.skyCultureLabelPickerOpen = ''
    })
  }


  private setSkyCultureLabelMode(target: string, mode: number, apply: (value: number) => void): void {
    const styles: string[] = ['Translated', 'Native', 'Pronounce', 'Translit', 'Modern']
    if (mode < 0 || mode >= styles.length) return
    apply(mode)
    this.callInteractive('setSkyCultureLabelStyle', target + '|' + styles[mode], (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        const style = target === 'screen' ? r.screenLabelStyle
          : (target === 'info' ? r.infoLabelStyle
            : (target === 'zodiac' ? r.zodiacLabelStyle : r.lunarSystemLabelStyle))
        apply(this.skyCultureSettingsStore.skyCultureScreenLabelModeFromBridge(style))
      }
    })
  }

  private setSkyCultureShortLabels(enabled: boolean): void {
    this.callInteractive('setSkyCultureShortLabels', enabled ? '1' : '0', (r: StellariumBridgeResponse) => {
      if (r.ok === true) this.skyCultureSettingsStore.skyCultureShortLabels = r.abbreviatedNames === true
    })
  }

  private setSkyCultureCommonNames(enabled: boolean): void {
    this.callInteractive('setSkyCultureCommonNames', enabled ? '1' : '0', (r: StellariumBridgeResponse) => {
      if (r.ok === true) this.skyCultureSettingsStore.skyCultureOverrideCommonNames = r.overrideCommonNames === true
    })
  }

  private setSkyCultureConstellationIsolation(enabled: boolean): void {
    this.callInteractive('setConstellationFlag', 'isolateSelected|' + (enabled ? '1' : '0'), (r: StellariumBridgeResponse) => {
      if (r.ok !== true) return
      this.skyCultureSettingsStore.skyCultureIsolateSelected = enabled
      if (!enabled && this.skyCultureSettingsStore.skyCultureSinglePick) {
        this.setSkyCultureConstellationSinglePick(false)
      }
    })
  }

  private setSkyCultureConstellationSinglePick(enabled: boolean): void {
    if (enabled && !this.skyCultureSettingsStore.skyCultureIsolateSelected) return
    this.callInteractive('setConstellationFlag', 'constellationPick|' + (enabled ? '1' : '0'), (r: StellariumBridgeResponse) => {
      if (r.ok === true) this.skyCultureSettingsStore.skyCultureSinglePick = enabled
    })
  }

  private applySkyCultureConstellationSelection(actionId: string, hint: string): void {
    this.callInteractive('triggerAction', actionId, (r: StellariumBridgeResponse) => {
      if (r.ok === true) this.flashHint(hint)
    })
  }

  private setSkyCultureVisualSetting(setting: string, value: number): void {
    this.callInteractive('setSkyCultureVisualSetting', setting + '|' + value.toFixed(2), (r: StellariumBridgeResponse) => {
      if (r.ok === true) this.skyCultureSettingsStore.applySkyCultureVisualSetting(setting, value)
    })
  }

  private skyCultureColorOptions(): ConfigurationOption[] {
    const options: ConfigurationOption[] = []
    if (this.layerStore.constellationLines) options.push({ id: 'constellationLines', label: '星座连线' })
    if (this.layerStore.constellationLabels) options.push({ id: 'constellationLabels', label: '星座标签' })
    if (this.layerStore.constellationBoundaries) options.push({ id: 'constellationBoundaries', label: '星座边界' })
    if (this.layerStore.constellationHulls) options.push({ id: 'constellationHulls', label: '星座区域边界' })
    if (this.layerStore.asterismLines) options.push({ id: 'asterismLines', label: '星群连线' })
    if (this.layerStore.asterismLabels) options.push({ id: 'asterismLabels', label: '星群标签' })
    if (this.layerStore.rayHelpers) options.push({ id: 'rayHelpers', label: '辅助射线' })
    if (this.layerStore.zodiac && this.skyCultureSettingsStore.skyCultureHasZodiac) options.push({ id: 'zodiac', label: '文化黄道' })
    if (this.layerStore.lunarSystem && this.skyCultureSettingsStore.skyCultureHasLunarSystem) options.push({ id: 'lunarSystem', label: '月宿系统' })
    return options
  }

  private skyCultureActiveColorTarget(): string {
    const options = this.skyCultureColorOptions()
    for (const option of options) {
      if (option.id === this.skyCultureSettingsStore.skyCultureColorTarget) return option.id
    }
    return options.length > 0 ? options[0].id : 'constellationLines'
  }



  private setSkyCultureVisualColor(setting: string, color: string): void {
    const normalized = color.trim().toUpperCase()
    if (!/^#[0-9A-F]{6}$/.test(normalized)) {
      this.flashHint('请输入 #RRGGBB 格式的颜色')
      return
    }
    this.callInteractive('setSkyCultureVisualColor', setting + '|' + normalized, (r: StellariumBridgeResponse) => {
      if (r.ok !== true) return
      const nextColor = r.color !== undefined ? r.color : normalized
      const colors = this.skyCultureSettingsStore.skyCultureVisualColors
      const updated: SkyCultureVisualColors = {
        constellationLines: setting === 'constellationLines' ? nextColor : colors.constellationLines,
        constellationLabels: setting === 'constellationLabels' ? nextColor : colors.constellationLabels,
        constellationBoundaries: setting === 'constellationBoundaries' ? nextColor : colors.constellationBoundaries,
        constellationHulls: setting === 'constellationHulls' ? nextColor : colors.constellationHulls,
        zodiac: setting === 'zodiac' ? nextColor : colors.zodiac,
        lunarSystem: setting === 'lunarSystem' ? nextColor : colors.lunarSystem,
        asterismLines: setting === 'asterismLines' ? nextColor : colors.asterismLines,
        asterismLabels: setting === 'asterismLabels' ? nextColor : colors.asterismLabels,
        rayHelpers: setting === 'rayHelpers' ? nextColor : colors.rayHelpers
      }
      this.skyCultureSettingsStore.skyCultureVisualColors = updated
      if (setting === this.skyCultureActiveColorTarget()) this.skyCultureSettingsStore.skyCultureColorInput = nextColor
    })
  }

  private setCurrentSkyCultureAsDefault(): void {
    if (this.skyCultureViewStore.currentSkyCultureId.length === 0 || this.skyCultureSettingsStore.skyCultureDefaultId === this.skyCultureViewStore.currentSkyCultureId) return
    this.callInteractive('setSkyCultureDefault', this.skyCultureViewStore.currentSkyCultureId, (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.skyCultureSettingsStore.skyCultureDefaultId = r.defaultId !== undefined ? r.defaultId : this.skyCultureViewStore.currentSkyCultureId
        this.flashHint('已设为默认星空文化')
      }
    })
  }



  private skyCultureArtFilePath(rawPath: string): string {
    if (!isSafeSkyCultureArtPath(rawPath)) return ''
    const path = this.stellariumFilesDir() + '/stellarium/' + rawPath
    try {
      fileIo.accessSync(path)
      return path
    } catch (_err) {
      return ''
    }
  }

  private skyCultureArtUri(rawPath: string): string {
    const path = this.skyCultureArtFilePath(rawPath)
    return path.length > 0 ? fileUri.getUriFromPath(path) : ''
  }

  private stellariumFilesDir(): string {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    return context.getApplicationContext().filesDir
  }


  private setSkyCultureArtStatus(rawPath: string, status: string): void {
    if (this.skyCultureArtStates[rawPath] === status && this.skyCultureArtPendingStatuses[rawPath] === undefined) return
    if (this.skyCultureArtPendingStatuses[rawPath] === status) return
    this.skyCultureArtPendingStatuses[rawPath] = status
    if (this.skyCultureArtStatusFlushTimer !== 0) return
    this.skyCultureArtStatusFlushTimer = setTimeout(() => {
      this.skyCultureArtStatusFlushTimer = 0
      const pending = this.skyCultureArtPendingStatuses
      this.skyCultureArtPendingStatuses = {}
      const next: Record<string, string> = {}
      for (const key of Object.keys(this.skyCultureArtStates)) next[key] = this.skyCultureArtStates[key]
      for (const key of Object.keys(pending)) next[key] = pending[key]
      this.skyCultureArtStates = next
    }, 48) as number
  }

  private clearSkyCultureArtThumbnails(): void {
    this.skyCultureArtThumbnailGeneration++
    if (this.skyCultureArtDecodeTimer !== 0) {
      clearTimeout(this.skyCultureArtDecodeTimer)
      this.skyCultureArtDecodeTimer = 0
    }
    if (this.skyCultureArtStatusFlushTimer !== 0) {
      clearTimeout(this.skyCultureArtStatusFlushTimer)
      this.skyCultureArtStatusFlushTimer = 0
    }
    this.skyCultureArtPendingStatuses = {}
    const oldMaps = this.skyCultureArtThumbnailPixelMaps
    this.skyCultureArtThumbnailPixelMaps = {}
    for (const rawPath of Object.keys(oldMaps)) {
      releaseDecodedImage(this.hostMediaPort, oldMaps[rawPath], 'sky-culture-art-thumbnail')
    }
  }

  private decodeSkyCultureArtThumbnail(rawPath: string, requestId: number, resolvedPath: string = rawPath): void {
    if (this.skyCultureArtThumbnailPixelMaps[rawPath] !== undefined) {
      return
    }
    const filePath = this.skyCultureArtFilePath(resolvedPath)
    if (filePath.length === 0) {
      return
    }
    const generation = this.skyCultureArtThumbnailGeneration
    decodeLocalImage(this.hostMediaPort, filePath, 'sky-culture-art-thumbnail', (pixelMap: image.PixelMap) => {
      if (requestId !== this.skyCultureDetailsRequestId || generation !== this.skyCultureArtThumbnailGeneration ||
        this.skyCultureViewStore.currentSkyCultureId.length === 0) {
        releaseDecodedImage(this.hostMediaPort, pixelMap, 'stale-sky-culture-art-thumbnail')
        return
      }
      const next: Record<string, image.PixelMap> = {}
      for (const key of Object.keys(this.skyCultureArtThumbnailPixelMaps)) {
        next[key] = this.skyCultureArtThumbnailPixelMaps[key]
      }
      next[rawPath] = pixelMap
      this.skyCultureArtThumbnailPixelMaps = next
      this.setSkyCultureArtStatus(rawPath, 'ready')
      hilog.info(0x0000, 'StellariumArkUI', '[sky-culture-art] thumbnail ready path=%{public}s', rawPath)
    }, (err: Error) => {
      if (requestId !== this.skyCultureDetailsRequestId || generation !== this.skyCultureArtThumbnailGeneration ||
        this.skyCultureViewStore.currentSkyCultureId.length === 0) {
        return
      }
      this.setSkyCultureArtStatus(rawPath, 'decodeFailed')
      hilog.warn(0x0000, 'StellariumArkUI', '[sky-culture-art] thumbnail decode failed path=%{public}s error=%{public}s',
        rawPath, JSON.stringify(err))
    }, { width: 320, height: 320 })
  }

  private prepareSkyCultureArtResources(items: Array<SkyCultureArtItem>, requestId: number): void {
    const initial: Record<string, string> = {}
    const missing: Array<string> = []
    const visiblePaths: string[] = []
    let ready = 0
    for (let index = 0; index < items.length; index++) {
      const art = items[index]
      if (this.skyCultureArtFilePath(art.rawPath).length > 0) {
        initial[art.rawPath] = 'ready'
        ready++
        if (index < 24) visiblePaths.push(art.rawPath)
      } else {
        initial[art.rawPath] = 'preparing'
        missing.push(art.rawPath)
      }
    }
    this.skyCultureArtStates = initial
    let visibleIndex = 0
    const decodeVisibleChunk = (): void => {
      this.skyCultureArtDecodeTimer = 0
      if (requestId !== this.skyCultureDetailsRequestId || this.skyCultureViewStore.currentSkyCultureId.length === 0) return
      const chunkEnd = Math.min(visibleIndex + 4, visiblePaths.length)
      while (visibleIndex < chunkEnd) {
        this.decodeSkyCultureArtThumbnail(visiblePaths[visibleIndex], requestId)
        visibleIndex++
      }
      if (visibleIndex < visiblePaths.length) {
        this.skyCultureArtDecodeTimer = setTimeout(decodeVisibleChunk, 32) as number
      }
    }
    if (visiblePaths.length > 0) {
      this.skyCultureArtDecodeTimer = setTimeout(decodeVisibleChunk, 0) as number
    }
    hilog.info(0x0000, 'StellariumArkUI',
      '[sky-culture-art] probe total=%{public}s ready=%{public}s pending=%{public}s',
      items.length.toString(), ready.toString(), missing.length.toString())
    let nextIndex = 0
    const copyNext = (): void => {
      if (requestId !== this.skyCultureDetailsRequestId || this.skyCultureViewStore.currentSkyCultureId.length === 0) return
      if (nextIndex >= missing.length) {
        let completed = 0
        let failed = 0
        for (const key of Object.keys(this.skyCultureArtStates)) {
          if (this.skyCultureArtStates[key] === 'ready') completed++
          if (this.skyCultureArtStates[key] === 'missing') failed++
        }
        hilog.info(0x0000, 'StellariumArkUI',
          '[sky-culture-art] preparation complete ready=%{public}s missing=%{public}s total=%{public}s',
          completed.toString(), failed.toString(), items.length.toString())
        return
      }
      const rawPath = missing[nextIndex++]
      const context = (this.getUIContext().getHostContext() as common.UIAbilityContext).getApplicationContext()
      resolveStellariumDetailMediaAsset(context, rawPath).then((resolvedPath: string) => {
        if (requestId !== this.skyCultureDetailsRequestId) return
        const filePath = resolvedPath.length > 0 ? this.skyCultureArtFilePath(resolvedPath) : ''
        this.setSkyCultureArtStatus(rawPath, filePath.length > 0 ? 'ready' : 'missing')
        if (filePath.length > 0 && items.slice(0, 24).some((item: SkyCultureArtItem) => item.rawPath === rawPath)) {
          this.decodeSkyCultureArtThumbnail(rawPath, requestId, resolvedPath)
        }
        copyNext()
      }).catch((err: Error) => {
        if (requestId !== this.skyCultureDetailsRequestId) return
        this.setSkyCultureArtStatus(rawPath, 'missing')
        hilog.warn(0x0000, 'StellariumArkUI',
          '[sky-culture-art] preparation failed path=%{public}s error=%{public}s', rawPath, JSON.stringify(err))
        copyNext()
      })
    }
    copyNext()
  }

  private openSkyCultureArtPreview(art: SkyCultureArtItem): void {
    this.skyCultureViewStore.artPreviewOpen = true
    this.skyCultureArtDecodeGeneration++
    const oldPixelMap = this.skyCultureViewStore.artPreviewPixelMap
    this.skyCultureViewStore.artPreviewPixelMap = undefined
    releaseDecodedImage(this.hostMediaPort, oldPixelMap, 'switch-sky-culture-art')
    this.skyCultureViewStore.artPreviewRawPath = art.rawPath
    this.skyCultureViewStore.artPreviewName = art.name !== undefined && art.name.length > 0 ? art.name : '星座绘图 ' + art.index
    this.skyCultureViewStore.artPreviewFailed = false
    this.skyCultureViewStore.artPreviewLoading = true
    this.skyCultureViewStore.artPreviewPath = this.skyCultureArtUri(art.rawPath)
    this.resolveSkyCultureArtPreview(art.rawPath)
  }

  private resolveSkyCultureArtPreview(rawPath: string): void {
    const current = this.skyCultureArtFilePath(rawPath)
    if (current.length > 0) {
      this.skyCultureViewStore.artPreviewPath = fileUri.getUriFromPath(current)
      this.skyCultureViewStore.artPreviewLoading = true
      this.skyCultureViewStore.artPreviewFailed = false
      this.setSkyCultureArtStatus(rawPath, 'ready')
      this.decodeSkyCultureArtPreview(current, rawPath)
      return
    }
    const context = (this.getUIContext().getHostContext() as common.UIAbilityContext).getApplicationContext()
    resolveStellariumDetailMediaAsset(context, rawPath).then((resolvedPath: string) => {
      if (!this.skyCultureViewStore.artPreviewOpen || this.skyCultureViewStore.artPreviewRawPath !== rawPath) return
      const filePath = resolvedPath.length > 0 ? this.skyCultureArtFilePath(resolvedPath) : ''
      this.skyCultureViewStore.artPreviewPath = filePath.length > 0 ? fileUri.getUriFromPath(filePath) : ''
      this.skyCultureViewStore.artPreviewLoading = filePath.length > 0
      this.skyCultureViewStore.artPreviewFailed = filePath.length === 0
      this.setSkyCultureArtStatus(rawPath, filePath.length > 0 ? 'ready' : 'missing')
      if (filePath.length > 0) {
        this.decodeSkyCultureArtPreview(filePath, rawPath)
      }
    }).catch((_err: Error) => {
      if (!this.skyCultureViewStore.artPreviewOpen || this.skyCultureViewStore.artPreviewRawPath !== rawPath) return
      this.skyCultureViewStore.artPreviewPath = ''
      this.skyCultureViewStore.artPreviewLoading = false
      this.skyCultureViewStore.artPreviewFailed = true
      this.setSkyCultureArtStatus(rawPath, 'missing')
    })
  }

  private closeSkyCultureArtPreview(): void {
    this.skyCultureViewStore.artPreviewOpen = false
    this.skyCultureArtDecodeGeneration++
    const oldPixelMap = this.skyCultureViewStore.artPreviewPixelMap
    this.skyCultureViewStore.artPreviewPixelMap = undefined
    releaseDecodedImage(this.hostMediaPort, oldPixelMap, 'sky-culture-art')
    this.skyCultureViewStore.artPreviewPath = ''
    this.skyCultureViewStore.artPreviewName = ''
    this.skyCultureViewStore.artPreviewRawPath = ''
    this.skyCultureViewStore.artPreviewLoading = false
    this.skyCultureViewStore.artPreviewFailed = false
  }

  private onSkyCultureArtLoaded(): void {
    if (!this.skyCultureViewStore.artPreviewOpen) return
    this.skyCultureViewStore.artPreviewLoading = false
    this.skyCultureViewStore.artPreviewFailed = false
    this.setSkyCultureArtStatus(this.skyCultureViewStore.artPreviewRawPath, 'ready')
    hilog.info(0x0000, 'StellariumArkUI', '[sky-culture-art] preview loaded path=%{public}s', this.skyCultureViewStore.artPreviewRawPath)
  }

  private decodeSkyCultureArtPreview(filePath: string, rawPath: string): void {
    const generation = ++this.skyCultureArtDecodeGeneration
    decodeLocalImage(this.hostMediaPort, filePath, 'sky-culture-art', (pixelMap: image.PixelMap) => {
      if (!this.skyCultureViewStore.artPreviewOpen || this.skyCultureViewStore.artPreviewRawPath !== rawPath ||
        generation !== this.skyCultureArtDecodeGeneration) {
        releaseDecodedImage(this.hostMediaPort, pixelMap, 'stale-sky-culture-art')
        return
      }
      const oldPixelMap = this.skyCultureViewStore.artPreviewPixelMap
      this.skyCultureViewStore.artPreviewPixelMap = pixelMap
      releaseDecodedImage(this.hostMediaPort, oldPixelMap, 'previous-sky-culture-art')
      this.skyCultureViewStore.artPreviewLoading = false
      this.skyCultureViewStore.artPreviewFailed = false
      this.setSkyCultureArtStatus(rawPath, 'ready')
      hilog.info(0x0000, 'StellariumArkUI', '[sky-culture-art] pixel map ready path=%{public}s', rawPath)
    }, (err: Error) => {
      if (!this.skyCultureViewStore.artPreviewOpen || this.skyCultureViewStore.artPreviewRawPath !== rawPath ||
        generation !== this.skyCultureArtDecodeGeneration) {
        return
      }
      this.skyCultureViewStore.artPreviewLoading = false
      this.skyCultureViewStore.artPreviewFailed = true
      this.setSkyCultureArtStatus(rawPath, 'decodeFailed')
      hilog.error(0x0000, 'StellariumArkUI', '[sky-culture-art] pixel map decode failed path=%{public}s error=%{public}s',
        rawPath, JSON.stringify(err))
    })
  }

  private onSkyCultureArtError(): void {
    if (!this.skyCultureViewStore.artPreviewOpen) return
    this.skyCultureViewStore.artPreviewLoading = false
    this.skyCultureViewStore.artPreviewFailed = true
    this.setSkyCultureArtStatus(this.skyCultureViewStore.artPreviewRawPath, 'decodeFailed')
    hilog.error(0x0000, 'StellariumArkUI', '[sky-culture-art] preview decode failed path=%{public}s', this.skyCultureViewStore.artPreviewRawPath)
  }

  private retrySkyCultureArtPreview(): void {
    this.skyCultureViewStore.artPreviewFailed = false
    this.skyCultureViewStore.artPreviewLoading = true
    const oldPixelMap = this.skyCultureViewStore.artPreviewPixelMap
    this.skyCultureViewStore.artPreviewPixelMap = undefined
    releaseDecodedImage(this.hostMediaPort, oldPixelMap, 'retry-sky-culture-art')
    this.skyCultureViewStore.artPreviewPath = ''
    this.resolveSkyCultureArtPreview(this.skyCultureViewStore.artPreviewRawPath)
  }

  private openObjectInspectorMediaPreview(): void {
    if (this.objectMediaStore.objectInspectorMediaPath.length === 0) { return }
    this.objectMediaStore.objectInspectorMediaPreviewLoading = this.objectMediaStore.objectInspectorMediaPixelMap === undefined && !this.objectMediaStore.objectInspectorMediaLoadFailed
    this.objectMediaStore.objectInspectorMediaPreviewFailed = this.objectMediaStore.objectInspectorMediaLoadFailed
    this.objectMediaStore.objectInspectorMediaPreviewPath = this.objectMediaStore.objectInspectorMediaPath
    this.objectMediaStore.objectInspectorMediaFullscreen = true
    hilog.info(0x0000, 'StellariumArkUI',
      '[detail-media-preview] open kind=%{public}s request=%{public}s resolved=%{public}s uri=%{public}s',
      this.objectMediaStore.objectInspectorMediaKind, this.objectInspectorMediaResolvedRequestPath,
      this.objectInspectorMediaResolvedPath, this.objectMediaStore.objectInspectorMediaPath)
  }

  private closeObjectInspectorMediaPreview(): void {
    hilog.info(0x0000, 'StellariumArkUI', '[detail-media-preview] close')
    this.objectMediaStore.objectInspectorMediaFullscreen = false
    this.objectMediaStore.objectInspectorMediaPreviewPath = ''
    this.objectMediaStore.objectInspectorMediaPreviewLoading = false
    this.objectMediaStore.objectInspectorMediaPreviewFailed = false
  }

  private retryObjectInspectorMediaPreview(): void {
    this.objectMediaStore.objectInspectorMediaPreviewFailed = false
    this.objectMediaStore.objectInspectorMediaPreviewLoading = true
    this.objectMediaStore.objectInspectorMediaPreviewPath = ''
    hilog.info(0x0000, 'StellariumArkUI', '[detail-media-preview] retry uri=%{public}s', this.objectMediaStore.objectInspectorMediaPath)
    this.retryObjectInspectorMedia()
  }

  private onObjectInspectorMediaPreviewLoaded(): void {
    if (!this.objectMediaStore.objectInspectorMediaFullscreen) { return }
    this.objectMediaStore.objectInspectorMediaPreviewLoading = false
    this.objectMediaStore.objectInspectorMediaPreviewFailed = false
    hilog.info(0x0000, 'StellariumArkUI', '[detail-media-preview] image loaded uri=%{public}s', this.objectMediaStore.objectInspectorMediaPreviewPath)
  }

  private onObjectInspectorMediaPreviewError(): void {
    if (!this.objectMediaStore.objectInspectorMediaFullscreen) { return }
    this.objectMediaStore.objectInspectorMediaPreviewLoading = false
    this.objectMediaStore.objectInspectorMediaPreviewFailed = true
    hilog.error(0x0000, 'StellariumArkUI', '[detail-media-preview] image failed uri=%{public}s', this.objectMediaStore.objectInspectorMediaPreviewPath)
  }

  private retryObjectInspectorMedia(): void {
    const retryPath = this.objectInspectorMediaResolvedRequestPath.length > 0
      ? this.objectInspectorMediaResolvedRequestPath
      : this.objectInspectorMediaRequestPath
    hilog.info(0x0000, 'StellariumArkUI',
      '[detail-media] retry request=%{public}s resolved=%{public}s', retryPath, this.objectInspectorMediaResolvedPath)
    this.clearObjectInspectorDecodedImage()
    this.objectMediaStore.objectInspectorMediaPath = ''
    this.objectInspectorMediaResolvedPath = ''
    this.objectInspectorMediaResolvedRequestPath = ''
    this.objectInspectorMediaResolutionComplete = false
    this.objectInspectorMediaRequestPath = ''
    this.objectMediaStore.objectInspectorMediaLoading = false
    this.objectMediaStore.objectInspectorMediaDecoding = false
    this.objectMediaStore.objectInspectorMediaLoadFailed = false
    this.objectMediaStore.objectInspectorMediaPreparationFailed = false
    this.objectMediaStore.objectInspectorMediaNoMatch = false
    this.refreshObjectInspectorMedia()
  }
















  private drawSkyCultureTerritoryMap(): void {
    const width = this.skyCultureMapRenderWidth
    const height = this.skyCultureMapRenderHeight
    if (width <= 0 || height <= 0) return
    this.skyCultureMapContext.clearRect(0, 0, width, height)
    this.skyCultureMapContext.lineWidth = 1.2
    this.skyCultureMapContext.strokeStyle = 'rgba(255, 219, 115, 0.96)'
    this.skyCultureMapContext.fillStyle = 'rgba(255, 194, 76, 0.18)'
    for (let polygonIndex = 0; polygonIndex < this.skyCultureSettingsStore.skyCultureTerritoryMapPolygons.length; polygonIndex++) {
      const points = this.skyCultureSettingsStore.skyCultureTerritoryMapPolygons[polygonIndex].points
      if (points.length < 3) continue
      let started = false
      let crossesDateLine = false
      let previousLongitude = 0
      this.skyCultureMapContext.beginPath()
      for (let pointIndex = 0; pointIndex < points.length; pointIndex++) {
        const point = points[pointIndex]
        if (point.length < 2) continue
        const longitude = point[0]
        const latitude = point[1]
        const x = (longitude + 180) / 360 * width
        const y = (90 - latitude) / 180 * height
        if (!started || Math.abs(longitude - previousLongitude) > 180) {
          if (started) crossesDateLine = true
          this.skyCultureMapContext.moveTo(x, y)
          started = true
        } else {
          this.skyCultureMapContext.lineTo(x, y)
        }
        previousLongitude = longitude
      }
      if (!started) continue
      this.skyCultureMapContext.closePath()
      if (!crossesDateLine) this.skyCultureMapContext.fill()
      this.skyCultureMapContext.stroke()
    }
  }

  private skyCultureMakerDraftFromResponse(response: StellariumBridgeResponse): SkyCultureMakerDraft | undefined {
    const values = response as Record<string, Object>
    if (values['draft'] === undefined) return undefined
    try {
      return JSON.parse(JSON.stringify(values['draft'])) as SkyCultureMakerDraft
    } catch (error) {
      hilog.error(0x0000, 'StellariumArkUI', 'Sky culture maker draft decode failed: %{public}s', String(error))
      return undefined
    }
  }

  private applySkyCultureMakerDraft(draft: SkyCultureMakerDraft): void {
    this.skyCultureMakerStore.id = draft.id ?? ''
    this.skyCultureMakerStore.name = draft.name ?? ''
    this.skyCultureMakerStore.author = draft.author ?? ''
    this.skyCultureMakerStore.license = draft.license ?? 'CC BY 4.0'
    this.skyCultureMakerStore.region = draft.region ?? ''
    this.skyCultureMakerStore.classification = draft.classification !== undefined && draft.classification.length > 0
      ? draft.classification[0] : 'traditional'
    this.skyCultureMakerStore.nativeLang = draft.native_lang ?? 'zh_CN'
    this.skyCultureMakerStore.beginTime = (draft.beginTime ?? 0).toString()
    this.skyCultureMakerStore.endTime = (draft.endTime ?? 0).toString()
    this.skyCultureMakerStore.introduction = draft.introduction ?? ''
    this.skyCultureMakerStore.description = draft.description ?? ''
    this.skyCultureMakerStore.constellations = draft.constellations ?? []
    this.skyCultureMakerStore.draftReady = true
    if (this.skyCultureMakerStore.constellations.length > 0 && this.skyCultureMakerStore.selectedConstellation < 0) {
      this.skyCultureMakerStore.selectedConstellation = 0
    } else if (this.skyCultureMakerStore.selectedConstellation >= this.skyCultureMakerStore.constellations.length) {
      this.skyCultureMakerStore.selectedConstellation = this.skyCultureMakerStore.constellations.length - 1
    }
    this.refreshSkyCultureMakerArtworkPreview()
  }

  private scheduleSkyCultureMakerSave(): void {
    if (!this.skyCultureMakerStore.draftReady) return
    if (this.skyCultureMakerSaveTimer > 0) clearTimeout(this.skyCultureMakerSaveTimer)
    this.skyCultureMakerSaveTimer = setTimeout(() => {
      this.skyCultureMakerSaveTimer = 0
      this.saveSkyCultureMakerDraft(true)
    }, 650) as number
  }


  private saveSkyCultureMakerDraft(silent: boolean = false, onComplete?: (success: boolean) => void): void {
    if (!this.skyCultureMakerStore.draftReady) {
      if (!silent) this.skyCultureMakerStore.status = I18n.t('sky_culture_maker_load_failed')
      if (onComplete !== undefined) onComplete(false)
      return
    }
    if (this.skyCultureMakerStore.saving) {
      if (onComplete !== undefined) onComplete(false)
      return
    }
    this.skyCultureMakerStore.saving = true
    this.callInteractive('saveSkyCultureMakerDraft', JSON.stringify(this.skyCultureMakerStore.currentSkyCultureMakerDraft()), (response: StellariumBridgeResponse) => {
      this.skyCultureMakerStore.saving = false
      if (response.ok !== true) {
        this.skyCultureMakerStore.status = response.error ?? I18n.t('sky_culture_maker_save_failed')
        if (onComplete !== undefined) onComplete(false)
        return
      }
      this.skyCultureMakerStore.canUndo = true
      this.skyCultureMakerStore.validation = validationFromResponse(response)
      if (!silent) this.skyCultureMakerStore.status = I18n.t('sky_culture_maker_saved')
      if (onComplete !== undefined) onComplete(true)
    }, () => {
      this.skyCultureMakerStore.saving = false
      this.skyCultureMakerStore.status = I18n.t('sky_culture_maker_save_failed')
      if (onComplete !== undefined) onComplete(false)
    })
  }

  private validateSkyCultureMaker(): void {
    this.callInteractive('validateSkyCultureMakerDraft', JSON.stringify(this.skyCultureMakerStore.currentSkyCultureMakerDraft()), (response: StellariumBridgeResponse) => {
      this.skyCultureMakerStore.validation = validationFromResponse(response)
      this.skyCultureMakerStore.status = response.ok === true
        ? I18n.t('sky_culture_maker_valid')
        : I18n.t('sky_culture_maker_invalid')
      this.skyCultureMakerStore.tab = 2
    }, () => { this.skyCultureMakerStore.status = I18n.t('sky_culture_maker_validate_failed') })
  }

  private resetSkyCultureMaker(): void {
    this.callInteractive('resetSkyCultureMakerDraft', '', (response: StellariumBridgeResponse) => {
      const draft = this.skyCultureMakerDraftFromResponse(response)
      if (response.ok === true && draft !== undefined) {
        this.applySkyCultureMakerDraft(draft)
        this.skyCultureMakerStore.validation = undefined
        this.skyCultureMakerStore.canUndo = true
        this.skyCultureMakerStore.status = I18n.t('sky_culture_maker_reset_done')
      } else this.skyCultureMakerStore.status = response.error ?? I18n.t('sky_culture_maker_reset_failed')
    })
  }

  private undoSkyCultureMaker(): void {
    this.callInteractive('undoSkyCultureMakerEdit', '', (response: StellariumBridgeResponse) => {
      const draft = this.skyCultureMakerDraftFromResponse(response)
      if (response.ok === true && draft !== undefined) {
        this.applySkyCultureMakerDraft(draft)
        const values = response as Record<string, Object>
        this.skyCultureMakerStore.canUndo = values['canUndo'] === true
        this.skyCultureMakerStore.status = I18n.t('sky_culture_maker_undo_done')
      } else this.skyCultureMakerStore.status = response.error ?? I18n.t('sky_culture_maker_undo_empty')
    })
  }

  private addSkyCultureMakerConstellation(): void {
    let number = this.skyCultureMakerStore.constellations.length + 1
    let id = 'constellation_' + number.toString()
    while (this.skyCultureMakerStore.constellations.some((item: SkyCultureMakerConstellation) => item.id === id)) {
      number += 1
      id = 'constellation_' + number.toString()
    }
    const constellation: SkyCultureMakerConstellation = {
      id: id,
      english: '',
      native: '',
      pronounce: '',
      transliteration: '',
      IPA: '',
      dark: false,
      lines: []
    }
    this.skyCultureMakerStore.constellations = this.skyCultureMakerStore.constellations.concat([constellation])
    this.skyCultureMakerStore.selectedConstellation = this.skyCultureMakerStore.constellations.length - 1
    this.refreshSkyCultureMakerArtworkPreview()
    this.scheduleSkyCultureMakerSave()
  }

  private updateSkyCultureMakerConstellation(updated: SkyCultureMakerConstellation): void {
    const index = this.skyCultureMakerStore.selectedConstellation
    if (index < 0 || index >= this.skyCultureMakerStore.constellations.length) return
    this.skyCultureMakerStore.constellations = this.skyCultureMakerStore.constellations.map((item: SkyCultureMakerConstellation, itemIndex: number) => {
      return itemIndex === index ? updated : item
    })
    this.scheduleSkyCultureMakerSave()
  }

  private removeSelectedSkyCultureMakerConstellation(): void {
    const index = this.skyCultureMakerStore.selectedConstellation
    if (index < 0 || index >= this.skyCultureMakerStore.constellations.length) return
    this.skyCultureMakerStore.constellations = this.skyCultureMakerStore.constellations.filter((_item: SkyCultureMakerConstellation, itemIndex: number) => itemIndex !== index)
    this.skyCultureMakerStore.selectedConstellation = Math.min(index, this.skyCultureMakerStore.constellations.length - 1)
    this.refreshSkyCultureMakerArtworkPreview()
    this.scheduleSkyCultureMakerSave()
  }

  private addSkyCultureMakerHipLine(): void {
    const index = this.skyCultureMakerStore.selectedConstellation
    if (index < 0 || index >= this.skyCultureMakerStore.constellations.length) return
    const parts = this.skyCultureMakerStore.hipLine.trim().split(/[\s,;，；]+/)
    const hips: number[] = []
    for (const part of parts) {
      const value = Number(part.replace(/^HIP/i, ''))
      if (Number.isInteger(value) && value > 0) hips.push(value)
    }
    if (hips.length < 2) {
      this.skyCultureMakerStore.status = I18n.t('sky_culture_maker_line_needs_two')
      return
    }
    const constellation = this.skyCultureMakerStore.constellations[index]
    this.updateSkyCultureMakerConstellation({
      id: constellation.id,
      english: constellation.english,
      native: constellation.native,
      pronounce: constellation.pronounce,
      transliteration: constellation.transliteration,
      IPA: constellation.IPA,
      dark: constellation.dark,
      lines: constellation.lines.concat([hips]),
      image: constellation.image
    })
    this.skyCultureMakerStore.hipLine = ''
    this.skyCultureMakerStore.status = I18n.t('sky_culture_maker_line_added')
  }

  private removeSkyCultureMakerLine(lineIndex: number): void {
    const index = this.skyCultureMakerStore.selectedConstellation
    if (index < 0 || index >= this.skyCultureMakerStore.constellations.length) return
    const constellation = this.skyCultureMakerStore.constellations[index]
    this.updateSkyCultureMakerConstellation({
      id: constellation.id,
      english: constellation.english,
      native: constellation.native,
      pronounce: constellation.pronounce,
      transliteration: constellation.transliteration,
      IPA: constellation.IPA,
      dark: constellation.dark,
      lines: constellation.lines.filter((_line: number[], index: number) => index !== lineIndex),
      image: constellation.image
    })
  }

  private addSelectedStarToSkyCultureMaker(): void {
    const index = this.skyCultureMakerStore.selectedConstellation
    if (index < 0 || index >= this.skyCultureMakerStore.constellations.length) return
    const constellation = this.skyCultureMakerStore.constellations[index]
    const lineIndex = constellation.lines.length > 0 ? constellation.lines.length - 1 : -1
    this.saveSkyCultureMakerDraft(true, (saved: boolean) => {
      if (!saved) return
      this.callInteractive('addSkyCultureMakerSelectedStar', JSON.stringify({ constellationId: constellation.id, lineIndex: lineIndex }), (response: StellariumBridgeResponse) => {
        const draft = this.skyCultureMakerDraftFromResponse(response)
        if (response.ok === true && draft !== undefined) {
          this.applySkyCultureMakerDraft(draft)
          this.skyCultureMakerStore.status = I18n.t('sky_culture_maker_selected_star_added')
        } else this.skyCultureMakerStore.status = response.error ?? I18n.t('sky_culture_maker_selected_star_failed')
      })
    })
  }

  private skyCultureMakerArtworkFilePath(): string {
    const constellation = this.skyCultureMakerStore.selected()
    const assetFile = constellation?.image?.file ?? ''
    if (assetFile.length === 0 || assetFile.startsWith('/') || assetFile.includes('..')) return ''
    const filePath = this.stellariumFilesDir() + '/stellarium_userdir/sky-culture-maker/assets/' + assetFile
    try {
      fileIo.accessSync(filePath)
      return filePath
    } catch (_error) {
      return ''
    }
  }

  private clearSkyCultureMakerArtworkPreview(label: string = 'sky-culture-maker-artwork'): void {
    this.skyCultureMakerArtworkDecodeGeneration++
    this.skyCultureMakerArtworkPreviewPath = ''
    this.skyCultureMakerStore.artworkPreviewState = 'empty'
    const oldPixelMap = this.skyCultureMakerStore.artworkPixelMap
    this.skyCultureMakerStore.artworkPixelMap = undefined
    releaseDecodedImage(this.hostMediaPort, oldPixelMap, label)
  }

  private refreshSkyCultureMakerArtworkPreview(): void {
    const artwork = this.skyCultureMakerStore.selected()?.image
    if (artwork === undefined) {
      this.clearSkyCultureMakerArtworkPreview()
      return
    }
    const filePath = this.skyCultureMakerArtworkFilePath()
    if (filePath.length === 0) {
      this.clearSkyCultureMakerArtworkPreview()
      this.skyCultureMakerStore.artworkPreviewState = 'missing'
      hilog.warn(0x0000, 'StellariumArkUI', '[sky-culture-maker] artwork file missing')
      return
    }
    if (this.skyCultureMakerArtworkPreviewPath === filePath &&
      (this.skyCultureMakerStore.artworkPreviewState === 'preparing' || this.skyCultureMakerStore.artworkPixelMap !== undefined)) {
      return
    }
    const generation = ++this.skyCultureMakerArtworkDecodeGeneration
    const oldPixelMap = this.skyCultureMakerStore.artworkPixelMap
    this.skyCultureMakerStore.artworkPixelMap = undefined
    releaseDecodedImage(this.hostMediaPort, oldPixelMap, 'previous-sky-culture-maker-artwork')
    this.skyCultureMakerArtworkPreviewPath = filePath
    this.skyCultureMakerStore.artworkPreviewState = 'preparing'
    const sourceWidth = Math.max(1, artwork.size?.[0] ?? 1)
    const sourceHeight = Math.max(1, artwork.size?.[1] ?? 1)
    const scale = Math.min(1, 1280 / Math.max(sourceWidth, sourceHeight))
    const desiredSize: ImageDecodeSize = {
      width: Math.max(1, Math.round(sourceWidth * scale)),
      height: Math.max(1, Math.round(sourceHeight * scale))
    }
    decodeLocalImage(this.hostMediaPort, filePath, 'sky-culture-maker-artwork', (pixelMap: image.PixelMap) => {
      if (generation !== this.skyCultureMakerArtworkDecodeGeneration || this.skyCultureMakerArtworkPreviewPath !== filePath) {
        releaseDecodedImage(this.hostMediaPort, pixelMap, 'stale-sky-culture-maker-artwork')
        return
      }
      this.skyCultureMakerStore.artworkPixelMap = pixelMap
      this.skyCultureMakerStore.artworkPreviewState = 'ready'
      hilog.info(0x0000, 'StellariumArkUI', '[sky-culture-maker] artwork ready path=%{public}s', filePath)
    }, (error: Error) => {
      if (generation !== this.skyCultureMakerArtworkDecodeGeneration || this.skyCultureMakerArtworkPreviewPath !== filePath) return
      this.skyCultureMakerStore.artworkPreviewState = 'decodeFailed'
      hilog.error(0x0000, 'StellariumArkUI', '[sky-culture-maker] artwork decode failed path=%{public}s error=%{public}s',
        filePath, JSON.stringify(error))
    }, desiredSize)
  }

  private selectSkyCultureMakerConstellation(index: number): void {
    if (index < 0 || index >= this.skyCultureMakerStore.constellations.length || index === this.skyCultureMakerStore.selectedConstellation) return
    this.skyCultureMakerStore.selectedConstellation = index
    this.skyCultureMakerStore.artworkAnchorIndex = 0
    this.refreshSkyCultureMakerArtworkPreview()
  }

  private applySkyCultureMakerArtworkResponse(response: StellariumBridgeResponse, successText: string): void {
    const draft = this.skyCultureMakerDraftFromResponse(response)
    if (response.ok === true && draft !== undefined) {
      this.applySkyCultureMakerDraft(draft)
      this.skyCultureMakerStore.canUndo = true
      this.skyCultureMakerStore.validation = validationFromResponse(response)
      this.skyCultureMakerStore.status = successText
    } else {
      this.skyCultureMakerStore.status = response.error ?? I18n.t('sky_culture_maker_artwork_failed')
    }
  }

  private async importSkyCultureMakerArtworkFile(): Promise<void> {
    const constellation = this.skyCultureMakerStore.selected()
    if (constellation === undefined || this.skyCultureMakerStore.artworkImporting) return
    this.skyCultureMakerStore.artworkImporting = true
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const options = new picker.DocumentSelectOptions()
      options.fileSuffixFilters = ['图像|.png|.jpg|.jpeg|.webp']
      options.maxSelectNumber = 1
      const selectedUris = await new picker.DocumentViewPicker(context).select(options)
      if (selectedUris.length === 0 || selectedUris[0].length === 0) return
      const importDir = context.filesDir + '/sky-culture-maker-imports'
      fileIo.mkdirSync(importDir, true)
      let fileName = selectedUris[0].substring(selectedUris[0].lastIndexOf('/') + 1).replace(/[^A-Za-z0-9._-]/g, '_')
      if (fileName.length === 0) fileName = 'artwork-' + Date.now().toString() + '.png'
      const sourcePath = importDir + '/' + Date.now().toString() + '-' + fileName
      await fileIo.copy(selectedUris[0], fileUri.getUriFromPath(sourcePath))
      this.callInteractive('importSkyCultureMakerArtwork', JSON.stringify({
        constellationId: constellation.id,
        sourcePath: sourcePath
      }), (response: StellariumBridgeResponse) => {
        this.skyCultureMakerStore.artworkImporting = false
        this.skyCultureMakerStore.artworkAnchorIndex = 0
        this.applySkyCultureMakerArtworkResponse(response, I18n.t('sky_culture_maker_artwork_imported'))
      }, () => {
        this.skyCultureMakerStore.artworkImporting = false
        this.skyCultureMakerStore.status = I18n.t('sky_culture_maker_artwork_failed')
      })
    } catch (error) {
      this.skyCultureMakerStore.artworkImporting = false
      this.skyCultureMakerStore.status = I18n.t('sky_culture_maker_artwork_failed')
      hilog.error(0x0000, 'StellariumArkUI', 'Sky culture artwork import failed: %{public}s', String(error))
    }
  }

  private removeSkyCultureMakerArtwork(): void {
    const constellation = this.skyCultureMakerStore.selected()
    if (constellation === undefined) return
    this.callInteractive('removeSkyCultureMakerArtwork', JSON.stringify({ constellationId: constellation.id }), (response: StellariumBridgeResponse) => {
      this.skyCultureMakerStore.artworkAnchorIndex = 0
      this.applySkyCultureMakerArtworkResponse(response, I18n.t('sky_culture_maker_artwork_removed'))
    })
  }

  private bindSkyCultureMakerArtworkAnchor(x: number, y: number): void {
    const constellation = this.skyCultureMakerStore.selected()
    const image = constellation?.image
    if (constellation === undefined || image === undefined || image.size.length !== 2) return
    const pixelX = clamp(x / Math.max(1, this.skyCultureMakerStore.artworkRenderWidth) * image.size[0], 0, image.size[0])
    const pixelY = clamp(y / Math.max(1, this.skyCultureMakerStore.artworkRenderHeight) * image.size[1], 0, image.size[1])
    this.callInteractive('setSkyCultureMakerArtworkAnchor', JSON.stringify({
      constellationId: constellation.id,
      anchorIndex: this.skyCultureMakerStore.artworkAnchorIndex,
      x: pixelX,
      y: pixelY
    }), (response: StellariumBridgeResponse) => {
      this.applySkyCultureMakerArtworkResponse(response, I18n.format('sky_culture_maker_anchor_bound', [(this.skyCultureMakerStore.artworkAnchorIndex + 1).toString()]))
      if (response.ok === true && this.skyCultureMakerStore.artworkAnchorIndex < 2) this.skyCultureMakerStore.artworkAnchorIndex += 1
    })
  }

  private handleSkyCultureMakerArtworkTouch(event: TouchEvent): boolean {
    const points = event.touches.length > 0 ? event.touches : event.changedTouches
    if (points.length === 0) return false
    const point = points[0]
    if (event.type === TouchType.Down) {
      this.skyCultureMakerArtworkTouchStartX = point.x
      this.skyCultureMakerArtworkTouchStartY = point.y
      this.skyCultureMakerArtworkTouchMoved = false
    } else if (event.type === TouchType.Move) {
      const deltaX = point.x - this.skyCultureMakerArtworkTouchStartX
      const deltaY = point.y - this.skyCultureMakerArtworkTouchStartY
      if (Math.sqrt(deltaX * deltaX + deltaY * deltaY) > 8) this.skyCultureMakerArtworkTouchMoved = true
    } else if (event.type === TouchType.Up) {
      if (!this.skyCultureMakerArtworkTouchMoved) this.bindSkyCultureMakerArtworkAnchor(point.x, point.y)
      this.skyCultureMakerArtworkTouchMoved = false
    } else if (event.type === TouchType.Cancel) {
      this.skyCultureMakerArtworkTouchMoved = false
    }
    return false
  }

  private exportSkyCultureMaker(): void {
    this.saveSkyCultureMakerDraft(true, (saved: boolean) => {
      if (!saved) return
      this.callInteractive('exportSkyCultureMaker', '', (response: StellariumBridgeResponse) => {
        this.skyCultureMakerStore.validation = validationFromResponse(response)
        const values = response as Record<string, Object>
        if (response.ok === true) {
          this.skyCultureMakerStore.exportPath = values['path'] as string
          this.skyCultureMakerStore.exportFileName = values['fileName'] as string
          this.skyCultureMakerStore.status = I18n.t('sky_culture_maker_exported')
        } else this.skyCultureMakerStore.status = response.error ?? I18n.t('sky_culture_maker_export_failed')
        this.skyCultureMakerStore.tab = 2
      })
    })
  }

  private async importSkyCultureMakerFile(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const options = new picker.DocumentSelectOptions()
      options.fileSuffixFilters = ['Stellarium 星空文化|.zip']
      options.maxSelectNumber = 1
      const selectedUris = await new picker.DocumentViewPicker(context).select(options)
      if (selectedUris.length === 0) return
      const importDir = context.filesDir + '/sky-culture-maker-imports'
      fileIo.mkdirSync(importDir, true)
      const targetPath = importDir + '/culture-' + Date.now().toString() + '.zip'
      await fileIo.copy(selectedUris[0], fileUri.getUriFromPath(targetPath))
      this.callInteractive('importSkyCultureMaker', targetPath, (response: StellariumBridgeResponse) => {
        const draft = this.skyCultureMakerDraftFromResponse(response)
        if (response.ok === true && draft !== undefined) {
          this.applySkyCultureMakerDraft(draft)
          this.skyCultureMakerStore.validation = undefined
          this.skyCultureMakerStore.canUndo = true
          this.skyCultureMakerStore.status = I18n.t('sky_culture_maker_imported')
        } else this.skyCultureMakerStore.status = response.error ?? I18n.t('sky_culture_maker_import_failed')
      })
    } catch (error) {
      hilog.error(0x0000, 'StellariumArkUI', 'Sky culture maker import failed: %{public}s', String(error))
      this.skyCultureMakerStore.status = I18n.t('sky_culture_maker_import_failed')
    }
  }

  private updatePluginLoadedItem(id: string, loaded: boolean): void {
    this.pluginStore.pluginList = this.pluginStore.pluginList.map((item: PluginItem) => {
      if (item.id !== id) return item
      return {
        id: item.id,
        name: item.name,
        loaded: loaded,
        loadAtStartup: item.loadAtStartup,
        description: item.description,
        authors: item.authors,
        contact: item.contact,
        version: item.version,
        license: item.license,
        acknowledgements: item.acknowledgements,
        hasPreviewImage: item.hasPreviewImage,
        source: item.source
      }
    })
  }

  private pluginFeatureDestination(id: string): string {
    const route = pluginFeatureRoute(id)
    if (route.kind === 'control') return I18n.format('plugin_destination_control', [pluginHostName(route.panel)])
    if (route.kind === 'catalog') return I18n.format('plugin_destination_catalog', [pluginZh(id)])
    if (route.kind === 'host') {
      let destination = pluginHostName(route.panel)
      if (id === 'ObjectVisibility') destination += ' > ' + pluginZh('Observability')
      else destination += ' > ' + pluginZh(id)
      return I18n.format('plugin_destination_host', [destination])
    }
    if (route.kind === 'network') return I18n.t('plugin_network_disabled')
    if (route.kind === 'offline') return I18n.t('plugin_offline_disabled')
    return I18n.t('plugin_no_arkui_panel')
  }

  private pluginFeatureIsActionable(id: string): boolean {
    const kind = pluginFeatureRoute(id).kind
    return kind === 'control' || kind === 'catalog' || kind === 'host'
  }

  private pluginFeatureActionLabel(id: string): string {
    return pluginFeatureRoute(id).kind === 'catalog'
      ? I18n.t('plugin_open_catalog')
      : I18n.t('plugin_open_feature')
  }

  private setNebulaTextureVisible(enabled: boolean): void {
    this.setNebulaTextureFlag('setNebulaTexturesVisible', enabled, this.nebulaTextureStore.nebulaTextureStatus?.enabled === true)
  }

  private setNebulaTextureFlag(command: string, enabled: boolean, current: boolean): void {
    if (this.nebulaTextureStore.nebulaTexturePending || this.nebulaTextureStore.nebulaTextureLoading || this.nebulaTextureStore.nebulaTextureImporting || enabled === current) return
    this.nebulaTextureStore.nebulaTexturePending = true
    this.callInteractive(command, enabled ? '1' : '0', (r: StellariumBridgeResponse) => {
      this.nebulaTextureStore.nebulaTexturePending = false
      if (r.ok === true) this.nebulaTextureStore.nebulaTextureStatus = r as NebulaTextureStatus
      else this.nebulaTextureStore.nebulaTextureActionStatus = r.error ?? I18n.t('nebula_texture_action_failed')
    }, () => {
      this.nebulaTextureStore.nebulaTexturePending = false
      this.nebulaTextureStore.nebulaTextureActionStatus = I18n.t('nebula_texture_action_failed')
    })
  }

  private refreshNebulaTextures(): void {
    if (this.nebulaTextureStore.nebulaTextureLoading || this.nebulaTextureStore.nebulaTexturePending || this.nebulaTextureStore.nebulaTextureImporting) return
    this.nebulaTextureStore.nebulaTextureLoading = true
    this.callInteractive('refreshNebulaTextures', '', (r: StellariumBridgeResponse) => {
      this.nebulaTextureStore.nebulaTextureLoading = false
      const status = (r as NebulaTextureRefreshResponse).status
      if (status !== undefined) this.nebulaTextureStore.nebulaTextureStatus = status
      this.nebulaTextureStore.nebulaTextureActionStatus = r.ok === true ? I18n.t('nebula_texture_refreshed') : (r.error ?? I18n.t('nebula_texture_action_failed'))
    }, () => {
      this.nebulaTextureStore.nebulaTextureLoading = false
      this.nebulaTextureStore.nebulaTextureActionStatus = I18n.t('nebula_texture_action_failed')
    })
  }

  private gotoNebulaTexture(imageUrl: string): void {
    this.callInteractive('gotoNebulaTexture', imageUrl, (r: StellariumBridgeResponse) => {
      if (r.ok !== true) this.nebulaTextureStore.nebulaTextureActionStatus = r.error ?? I18n.t('nebula_texture_action_failed')
    }, () => { this.nebulaTextureStore.nebulaTextureActionStatus = I18n.t('nebula_texture_action_failed') })
  }

  private removeNebulaTexture(imageUrl: string): void {
    this.callInteractive('removeNebulaTexture', imageUrl, (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.nebulaTextureStore.nebulaTextureActionStatus = I18n.t('nebula_texture_removed')
        this.nebulaTextureStore.loadNebulaTextureStatus()
      } else this.nebulaTextureStore.nebulaTextureActionStatus = r.error ?? I18n.t('nebula_texture_action_failed')
    }, () => { this.nebulaTextureStore.nebulaTextureActionStatus = I18n.t('nebula_texture_action_failed') })
  }

  private async importNebulaTextureFile(): Promise<void> {
    if (this.nebulaTextureStore.nebulaTextureImporting) return
    this.nebulaTextureStore.nebulaTextureImporting = true
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const options = new picker.DocumentSelectOptions()
      options.fileSuffixFilters = ['图像|.png|.jpg|.jpeg|.gif|.tif|.tiff']
      options.maxSelectNumber = 1
      const selectedUris = await new picker.DocumentViewPicker(context).select(options)
      if (selectedUris.length === 0 || selectedUris[0].length === 0) {
        this.nebulaTextureStore.nebulaTextureActionStatus = I18n.t('nebula_texture_import_cancelled')
        this.nebulaTextureStore.nebulaTextureImporting = false
        return
      }
      const importDir = context.filesDir + '/nebula-texture-imports'
      fileIo.mkdirSync(importDir, true)
      const sourceName = selectedUris[0].substring(selectedUris[0].lastIndexOf('/') + 1).replace(/[^A-Za-z0-9._-]/g, '_')
      const sourcePath = importDir + '/' + (sourceName.length > 0 ? sourceName : 'texture-' + Date.now().toString() + '.png')
      await fileIo.copy(selectedUris[0], fileUri.getUriFromPath(sourcePath))
      this.callInteractive('importNebulaTexture', JSON.stringify({ sourcePath: sourcePath }), (r: StellariumBridgeResponse) => {
        this.nebulaTextureStore.nebulaTextureActionStatus = r.ok === true ? I18n.t('nebula_texture_imported') : (r.error ?? I18n.t('nebula_texture_import_failed'))
        if (r.ok === true) this.nebulaTextureStore.loadNebulaTextureStatus()
        this.nebulaTextureStore.nebulaTextureImporting = false
      }, () => {
        this.nebulaTextureStore.nebulaTextureActionStatus = I18n.t('nebula_texture_import_failed')
        this.nebulaTextureStore.nebulaTextureImporting = false
      })
    } catch (error) {
      hilog.error(0x0000, 'StellariumArkUI', 'Nebula texture import failed: %{public}s', String(error))
      this.nebulaTextureStore.nebulaTextureActionStatus = I18n.t('nebula_texture_import_failed')
      this.nebulaTextureStore.nebulaTextureImporting = false
    }
  }

  private openPluginFeature(id: string): void {
    const route = pluginFeatureRoute(id)
    if (route.kind === 'offline') {
      this.flashHint(I18n.t('plugin_offline_disabled'))
      return
    }
    if (route.kind === 'unavailable' || route.panel.length === 0) {
      this.flashHint(I18n.t('plugin_no_arkui_panel'))
      return
    }
    if (id === 'TelescopeControl') {
      this.openPluginFeatureAfterLoad(id, route)
      return
    }
    this.ensurePluginLoaded(id, () => { this.openPluginFeatureAfterLoad(id, route) }, () => {
      this.flashHint(I18n.t('plugin_load_failed'))
    })
  }

  private openPluginFeatureAfterLoad(id: string, route: PluginFeatureRoute): void {
    if (route.astroTab !== undefined) this.astroStore.astroTab = route.astroTab
    if (route.graphMode !== undefined) this.astroStore.graphMode = route.graphMode
    if (route.layerTab !== undefined) this.viewTab = route.layerTab
    if (route.catalogModuleId !== undefined) {
      this.searchStore.searchText = ''
      this.searchStore.searchCategory = 'module:' + route.catalogModuleId
      this.searchStore.loadCategoryObjects(this.searchStore.searchCategory, route.catalogModuleId)
      this.searchStore.pendingPluginCatalogId = route.catalogModuleId
    }
    this.openSubPanel(route.panel)
  }

    private loadFov(): void {
    this.callInteractive('getFieldOfView', '', (r: StellariumBridgeResponse) => {
      if (r.ok === true && typeof r.fov === 'number') {
        this.currentFovText = (r.fov as number).toFixed(1) + '°'
        this.fovSliderValue = r.fov as number
      }
    })
  }

  private changeFovBySlider(val: number): void {
    this.callInteractive('setFOV', Math.round(val).toString(), (r: StellariumBridgeResponse) => {
      hilog.info(0x0000, 'StellariumArkUI', 'changeFovBySlider %{public}d ok=%{public}s', Math.round(val), r.ok === true ? '1' : '0')
    })
  }

  private setFovMarkerSetting(setting: string, value: number): void {
    this.callInteractive('setFovMarkerSetting', setting + '|' + value.toFixed(1), () => {})
  }

private loadPlanetPositions(): void {
    this.astroStore.updateAstroCalcSnapshot()
    const requestId = ++this.planetPositionsRequestSequence
    this.astroStore.planetPositions = []
    this.astroStore.planetPositionsError = ''
    this.astroStore.planetPositionsLoading = true
    this.callInteractive('getObjectPositions', '', (r: StellariumBridgeResponse) => {
      if (requestId !== this.planetPositionsRequestSequence) return
      this.astroStore.planetPositionsLoading = false
      if (r.ok === true && Array.isArray(r.items)) {
        this.astroStore.planetPositions = (r.items as Array<PlanetPosition>).map((p: PlanetPosition): PlanetPosition => ({
          name: p.name,
          englishName: p.englishName,
          rightAscension: p.rightAscension,
          declination: p.declination,
          altitude: Math.round(p.altitude * 10) / 10,
          azimuth: Math.round(p.azimuth * 10) / 10,
          magnitude: Math.round(p.magnitude * 100) / 100,
          distanceAU: p.distanceAU,
          angularSizeArcmin: p.angularSizeArcmin,
          transit: p.transit,
        }))
        if (this.astroStore.planetPositions.length === 0) this.astroStore.planetPositionsError = '当前没有可显示的行星位置。'
      } else {
        this.astroStore.planetPositionsError = r.error ?? '行星位置计算失败，请点刷新后重试。'
      }
    }, () => {
      if (requestId !== this.planetPositionsRequestSequence) return
      this.astroStore.planetPositionsLoading = false
      this.astroStore.planetPositionsError = '行星位置计算失败，请点刷新后重试。'
    })
  }



  private selectLandscape(id: string, name: string): void {
    this.callInteractive('setLandscape', id, (response: StellariumBridgeResponse) => {
      if (response.ok !== true) {
        this.flashHint(I18n.t('msg_apply_failed'))
        return
      }
      this.layerViewStore.currentLandscapeId = id
      this.objectDetailStore.selectedLandscapeName = name
      this.landscapeDetailOpen = false
      this.refreshState()
    })
  }

  private setLandscapeFadeWithZoom(isOn: boolean): void {
    this.layerViewStore.landscapeFadeWithZoom = isOn
    this.callInteractive('setLandscapeFadeWithZoom', isOn ? '1' : '0', () => {})
  }

  private changeLandscapeTransparency(val: number): void {
    const v = (val / 100).toFixed(2)
    // 手动透明度接管地景显示；不要再调用 setLandscapeFadeWithZoom(0)，
    // C++ 里该命令会重置透明度，导致滑条看起来“没反应”。
    this.layerViewStore.landscapeFadeWithZoom = false
    this.callInteractive('setLandscapeUseTransparency', '1', () => {})
    this.callInteractive('setLandscapeTransparency', v, () => {})
  }

  private selectCommandEntry(item: CommandCatalogEntry): void {
    this.commandStore.commandNameInput = item.name
    this.commandStore.commandPayloadInput = item.examplePayload ?? ''
    this.commandStore.commandPendingConfirmation = ''
    this.commandStore.commandResultText = ''
  }

  private executeCommandFromPanel(force: boolean = false): void {
    const commandName = this.commandStore.commandNameInput.trim()
    if (!/^[A-Za-z][A-Za-z0-9_]*$/.test(commandName)) {
      this.commandStore.commandResultText = JSON.stringify({ ok: false, error: '请输入合法命令名' }, null, 2)
      return
    }
    const selected = this.commandStore.commandCatalog.find((item: CommandCatalogEntry) => item.name === commandName)
    if (selected === undefined) {
      this.commandStore.commandResultText = JSON.stringify({ ok: false, error: '命令不在当前版本目录中，请先刷新目录' }, null, 2)
      return
    }
    if (selected.requiresConfirmation && !force) {
      this.commandStore.commandPendingConfirmation = commandName
      this.commandStore.commandResultText = '该命令可能修改文件、插件、录制或外部设备状态，请确认后执行。'
      return
    }
    this.commandStore.commandPendingConfirmation = ''
    this.commandStore.commandBusy = true
    this.callInteractive(commandName, this.commandStore.commandPayloadInput, (r: StellariumBridgeResponse) => {
      this.commandStore.commandBusy = false
      this.commandStore.commandResultText = JSON.stringify(r, null, 2)
      this.refreshState()
    }, (r: StellariumBridgeResponse) => {
      this.commandStore.commandBusy = false
      this.commandStore.commandResultText = JSON.stringify({ ok: false, error: r.error ?? '命令执行超时' }, null, 2)
    })
  }

  private scheduleSuggestions(prefix: string): void {
    if (this.searchSuggestionTimer >= 0) {
      clearTimeout(this.searchSuggestionTimer)
      this.searchSuggestionTimer = -1
    }
    if (prefix.length < 1) {
      this.searchStore.searchSuggestions = []
      return
    }
    this.searchSuggestionTimer = setTimeout(() => {
      this.searchSuggestionTimer = -1
      if (this.searchStore.searchText.trim() === prefix) this.fetchSuggestions(prefix)
    }, 140)
  }

  private fetchSuggestions(prefix: string, languageSerial: number = this.languageStore.languageRefreshSerial): void {
    if (prefix.length < 1) { this.searchStore.searchSuggestions = []; return }
    // Native matching covers localized names, English names, catalog IDs, and
    // spacing/hyphen variants across every currently loaded object module.
    this.callInteractive('listMatchingObjects', prefix + '|30', (result) => {
      // Only apply if the query prefix is still current (user may have typed more).
      if (this.searchStore.searchText.trim() !== prefix || this.languageStore.languageRefreshSerial !== languageSerial) { return }
      const suggestions: SearchSug[] = []
      const seen: Record<string, boolean> = {}
      if (Array.isArray(result.items)) {
        const keys = Array.isArray(result.keys) ? result.keys as string[] : []
        const ids = Array.isArray(result.ids) ? result.ids as string[] : []
        const typeIds = Array.isArray(result.typeIds) ? result.typeIds as string[] : []
        const types = Array.isArray(result.types) ? result.types as string[] : []
        const fuzzy = Array.isArray(result.fuzzy) ? result.fuzzy as boolean[] : []
        const crossLanguage = Array.isArray(result.crossLanguage) ? result.crossLanguage as boolean[] : []
        const items = result.items as string[]
        for (let i = 0; i < items.length; i++) {
          const display = items[i]
          const key = (keys[i] && keys[i].length > 0) ? keys[i] : display
          const id = ids[i] ?? ''
          const typeId = typeIds[i] ?? ''
          const selection = id.length > 0 && typeId.length > 0 ? 'object|' + typeId + '|' + id : ''
          const uniqueKey = selection.length > 0 ? selection : key
          if (!seen[uniqueKey]) {
            seen[uniqueKey] = true
            suggestions.push({
              zh: celestialTitle(display, key),
              en: key,
              type: types[i] ?? '',
              selection: selection.length > 0 ? selection : undefined,
              fuzzy: fuzzy[i] === true,
              crossLanguage: crossLanguage[i] === true,
            })
          }
        }
      }
      // C++ ranks exact, prefix, and substring matches. Keep that order instead
      // of re-sorting localized display labels in ArkUI.
      this.searchStore.searchSuggestions = suggestions.slice(0, 30)
    })
  }

  // 搜索建议的显示名可能是当前语言的译名；en 始终是 C++ 桥返回的稳定检索键。
  // 只有核心确认选中成功时 searchObject() 才会收起手机面板。
  private selectSearchSuggestion(suggestion: SearchSug): void {
    if (this.searchSuggestionTimer >= 0) {
      clearTimeout(this.searchSuggestionTimer)
      this.searchSuggestionTimer = -1
    }
    this.searchObject(suggestion.en, '', suggestion.selection ?? '')
  }

  // Keep constellation navigation clear and light: labels and lines, no global boundaries.
  private openConstellationGuide(name: string, moduleId: string = 'ConstellationMgr', displayName: string = ''): void {
    this.flashHint('已开启星座名称和连线，正在定位' + (displayName.length > 0 ? displayName : zhNameOf(name)))
    this.callInteractive('setActionChecked', 'actionShow_Constellation_Boundaries|0', () => {
      this.layerStore.constellationBoundaries = false
      this.callInteractive('setActionChecked', 'actionShow_Constellation_Lines|1', () => {
        this.layerStore.constellationLines = true
        this.callInteractive('setActionChecked', 'actionShow_Constellation_Labels|1', () => {
          this.layerStore.constellationLabels = true
          this.searchObject(name, moduleId)
        })
      })
    })
  }

  // loadObjectCatalogCategories 已下沉 CatalogStore（§14 B2R-4）。

  // loadConstellationNavigation 已随 §14 B3-1 搬入 state/SearchStore.ets（宿主调用点显式传 languageSerial）。


  // loadCategoryObjects 已下沉 state/SearchStore.ets（§14 B3-3）。

  private publishSearchBrowserState(error: string = ''): void {
    AppStorage.setOrCreate('stellariumSearchBrowserState', JSON.stringify({
      ok: error.length === 0, error: error, page: this.searchStore.searchFilterPage || 'browse',
      category: this.searchStore.searchCategory, moduleId: this.searchStore.categoryModuleId,
      visibility: this.searchStore.searchVisibilityFilter, instrument: this.searchStore.searchInstrumentFilter,
      categories: this.catalogStore.searchAllCategoryOptions(), scrollY: this.searchPanelScroller.currentOffset()?.yOffset ?? 0
    }))
  }

  private refreshSearchFilterResults(): void {
    this.searchStore.loadCategoryObjects(this.searchStore.searchCategory)
    this.searchPanelScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false })
  }

  private selectSearchFilterCategory(category: string): void {
    if (!this.catalogStore.searchAllCategoryOptions().some((option: CatOption) => option.code === category)) {
      this.publishSearchBrowserState('unknown category')
      return
    }
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseInOut }, () => {
      this.searchStore.searchFilterPage = ''
      this.searchStore.loadCategoryObjects(category)
    })
    this.searchPanelScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false })
  }

  private selectSearchVisibilityFilter(filter: string): void {
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseInOut }, () => {
      this.searchStore.searchVisibilityFilter = filter
      this.searchStore.searchFilterPage = ''
      this.refreshSearchFilterResults()
    })
  }

  private selectSearchInstrumentFilter(filter: string): void {
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseInOut }, () => {
      this.searchStore.searchInstrumentFilter = filter
      this.searchStore.searchFilterPage = ''
      this.refreshSearchFilterResults()
    })
  }


  private setSearchFilterPage(page: string): void {
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseInOut }, () => {
      this.searchStore.searchFilterPage = page
    })
    this.searchPanelScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false })
    this.publishSearchBrowserState()
  }

  // Catalogs may contain many thousands of entries. Request small pages so the
  // first page is usable immediately and append more only when the user scrolls.
  // loadMoreCategoryObjects 已下沉 state/SearchStore.ets（§14 B3-3）。

  private stopTracking(): void {
    this.setTrackingState(false)
  }

  private setSkyCulture(name: string): void {
    this.callInteractive('setSkyCulture', name, (r: StellariumBridgeResponse) => {
      if (r.ok !== true) {
        this.flashHint(I18n.t('msg_apply_failed'))
        return
      }
      const culture = r.culture && r.culture.length > 0 ? r.culture : name
      this.skyCultureViewStore.currentSkyCulture = culture
      this.flashHint(I18n.t('i0068').replace('%s', culture))
    })
  }

  private setTimeRate(rate: number): void {
    // 速率命令本身不需要结果。此前这里紧跟一次 getState，旧的异步状态会
    // 短暂覆盖刚刚更新的文本，造成“倒带/快进按钮闪一下”的错觉。
    this.callNativeFire('setTimeRate', rate.toString())
  }

  // 时间轮交互控制器（普通类，非可观测）：拖动/惯性/轨道重基准/引擎推送。
  // 跨域依赖以回调注入：引擎推送、暂停速度、UTC 偏移。
  private timeWheelController: TimeWheelController | undefined = undefined

  private wheel(): TimeWheelController {
    if (this.timeWheelController === undefined) {
      this.timeWheelController = new TimeWheelController(
        this.timeWheelStore,
        (jd: number) => { this.callNativeFire('setTimeToJD', jd.toFixed(8)) },
        () => { this.stopTimeWheelSpeed() },
        () => { return this.utcOffsetHours }
      )
    }
    return this.timeWheelController
  }

  // 时间轮按下即暂停（原 setTimeWheelStopped 的速度域部分，跨域写收在宿主）。
  private stopTimeWheelSpeed(): void {
    this.timeStore.timeSpeedIndex = WindowNativeNode.SPEED_IDX_STOP
    this.timeStore.beginRateChange(0, 500)
    this.timeStore.timeRateText = formatRate(0)
  }

  // ===== 时间速率档位系统 =====
  // Stellarium 内部单位：Julian days per second (JD/s)
  // 1 JD = 86400 ��，所以 1x 实时 = 1/86400 ≈ 1.1574e-5 JD/s
  // 档位表：索引 0=暂停, 1=1x, 2=2x, 3=10x, 4=1分/秒, 5=1时/秒, 6=1天/秒, 7=10天/秒
  // 负索引 = 倒带：-1=-1x, -2=-1时/秒, -3=-1天/秒
  private readonly SPEED_STEPS: number[] = [
    -864000.0 / 86400.0,   // -10: 倒带 极速(1天/秒反向)
    -360.0 / 86400.0,      // -9:  倒带 快进(1时/秒反向)
    -60.0 / 86400.0,       // -8:  倒带(1分/秒反向)
    -10.0 / 86400.0,       // -7:  倒带 10x
    -2.0 / 86400.0,        // -6:  倒带 2x
    -1.0 / 86400.0,        // -5:  倒带 1x
    0,                      //  0:  停止
    1.0 / 86400.0,         //  1:  实时 1x
    2.0 / 86400.0,         //  2:  2x
    10.0 / 86400.0,        //  3:  10x
    60.0 / 86400.0,        //  4:  1分/秒
    360.0 / 86400.0,       //  5:  1时/秒
    86400.0 / 86400.0,     //  6:  1天/秒
    864000.0 / 86400.0,    //  7:  10天/秒
  ]
  // SPEED_STEPS 的"零点"索引（停止）和"实时"索引
  private static readonly SPEED_IDX_STOP = 6
  private static readonly SPEED_IDX_REALTIME = 7

  /** Apply speed at given step index. Clamps to valid range. */
  private applySpeedStep(index: number): void {
    const idx: number = Math.max(0, Math.min(this.SPEED_STEPS.length - 1, index))
    const rate: number = this.SPEED_STEPS[idx]
    this.timeStore.timeSpeedIndex = idx
    this.timeStore.beginRateChange(rate, 500)
    this.setTimeRate(rate)
    this.timeStore.timeRateText = formatRate(rate)
  }

  /** 将原生返回的速率映射回时间档位，保证面板重建后按钮状态不会丢失。 */
  private syncTimeRateState(rate: number): void {
    // 陈旧/重复回报由 store 统一判定（待定窗口 + 去重），宿主只负责按结果落库。
    if (this.timeStore.shouldIgnoreEngineRate(rate)) { return }

    this.timeStore.lastSyncedTimeRate = rate
    this.timeStore.timeRateText = formatRate(rate)
    let nearestIndex = 0
    let nearestDistance = Number.MAX_VALUE
    for (let i = 0; i < this.SPEED_STEPS.length; i++) {
      const candidate = this.SPEED_STEPS[i]
      const distance = Math.abs(candidate - rate)
      if (distance < nearestDistance) {
        nearestDistance = distance
        nearestIndex = i
      }
    }
    this.timeStore.timeSpeedIndex = nearestIndex
  }

  /** Speed up one step. */
  private speedUp(): void {
    this.applySpeedStep(this.timeStore.timeSpeedIndex + 1)
  }

  /** Slow down one step (can go into reverse). */
  private speedDown(): void {
    this.applySpeedStep(this.timeStore.timeSpeedIndex - 1)
  }

  /** Toggle pause: remember current non-zero speed, restore on unpause. */
  private togglePause(): void {
    if (this.timeStore.timeSpeedIndex === 6) { // SPEED_IDX_STOP
      // Resume: restore last speed or default to 1x
      const resumeIdx = this.timeStore.lastNonZeroSpeedIndex > 0 && this.timeStore.lastNonZeroSpeedIndex !== 6 ? this.timeStore.lastNonZeroSpeedIndex : 7
      this.applySpeedStep(resumeIdx)
    } else {
      // Pause: remember current speed
      this.timeStore.lastNonZeroSpeedIndex = this.timeStore.timeSpeedIndex
      this.applySpeedStep(6) // SPEED_IDX_STOP
    }
  }

  private zoomStep(factor: number): void {
    hilog.info(0x0000, 'StellariumArkUI', 'zoomStep factor=%{public}s', factor.toString())
    // Discrete zoom is a direct view command. Do not route it through the
    // result-polling cache, which can make a tap appear to do nothing.
    this.callNativeFire('zoomStep', factor.toString())
    this.scheduleSkyTextureStatusCheck()
    setTimeout(() => {
      this.refreshState()
      this.callInteractive('getFieldOfView', '', (r: StellariumBridgeResponse) => {
        if (r.ok === true && r.fov !== undefined) {
          const fovDeg = r.fov as number
          // 只更新常驻的 FOV 读数（dock 上方的胶囊），不再弹 "视场 xx°" 提示：
          // 胶囊一直可见，提示属于重复反馈，且会盖住星图中央。
          this.currentFovText = fovDeg.toFixed(1) + '°'
          this.fovSliderValue = fovDeg
        }
      })
    }, 450)
  }

  private advanceTime(hours: number): void {
    this.callInteractive('advanceTime', hours.toString(), () => { this.refreshTimeNow() })
    this.flashHint((hours > 0 ? I18n.t('i0044') : '') + hours.toString() + ' h')
  }

  private jumpToTimeMark(mark: string): void {
    if (this.timeMarkLoading) { return }
    const label = mark === 'sunRise' ? '日出' : (mark === 'sunTransit' ? '太阳中天' : (mark === 'sunSet' ? '日落' : '天文昏影'))
    this.timeMarkLoading = true
    this.callInteractive('getAlmanac', '', (response: StellariumBridgeResponse) => {
      const almanac = response.almanac as Record<string, Object> | undefined
      const targetJD = almanac !== undefined ? Number(almanac[mark]) : Number.NaN
      if (response.ok !== true || !Number.isFinite(targetJD) || targetJD <= 0) {
        this.timeMarkLoading = false
        this.flashHint('当前日期和地点没有可用的' + label + '时刻。')
        return
      }
      this.applySpeedStep(WindowNativeNode.SPEED_IDX_STOP)
      this.callInteractive('setJD', targetJD.toFixed(6), () => {
        this.timeMarkLoading = false
        this.wheel().syncFromSimulation(targetJD)
        this.refreshTimeNow()
        this.flashHint('已定位到' + label + '。')
      }, () => {
        this.timeMarkLoading = false
        this.flashHint(label + '时刻设置失败，请重试。')
      })
    }, () => {
      this.timeMarkLoading = false
      this.flashHint('获取' + label + '时刻失败，请重试。')
    })
  }


  private applyManualTime(): void {
    const jd = dateToJD(this.timeStore.manualYear, this.timeStore.manualMonth, this.timeStore.manualDay, this.timeStore.manualHour, this.timeStore.manualMinute)
    this.callInteractive('setJD', jd.toFixed(6), (r: StellariumBridgeResponse) => {
      this.refreshState()
      this.flashHint(String(this.timeStore.manualMonth).padStart(2, '0') + '-' + String(this.timeStore.manualDay).padStart(2, '0') + ' ' + String(this.timeStore.manualHour).padStart(2, '0') + ':' + String(this.timeStore.manualMinute).padStart(2, '0'))
    })
  }

  private setLanguage(lang: string): void {
    // Map to I18n code (handle codes like pt_BR, zh_HK that C++ may not support)
    const i18nCode = I18n.fromStellariumCode(lang)
    // 同步 I18n 模块（触发 AppStorage 变更 → UI 重渲染）
    I18n.setLanguage(i18nCode)
    // The panel contains many static text nodes. Updating this local storage
    // link and the panel identity makes the open panel rebuild immediately,
    // rather than waiting for it to be closed and opened again.
    this.i18nLang = i18nCode
    this.languageStore.selectedLanguage = lang
    const languageSerial = ++this.languageStore.languageRefreshSerial
    this.languageStore.languageRevision++
    this.panelContentKey++
    // 持久化语言选择
    try {
      const settings = AppStorage.get<string>('stellariumSettings')
      const s: Record<string, Object> = settings ? JSON.parse(settings) as Record<string, Object> : {} as Record<string, Object>
      s.selectedLanguage = lang
      AppStorage.setOrCreate('stellariumSettings', JSON.stringify(s))
    } catch (e) { }
    // 立即提示，不等 C++ 确认（避免阻塞触摸和星图交互）
    this.flashHint(I18n.t('msg_lang_switched_done') + ': ' + (LANGUAGE_DISPLAY[lang] ?? LANGUAGE_DISPLAY[i18nCode] ?? lang))
    // 延迟同步 C++ 侧语言，避免同步 N-API 调用阻塞 UI 线程导致星图无响应。
    // 这里不能 refreshState：该全量状态刷新会与选中对象的安全居中动画竞争，
    // 表现为星图先上移又下移。
    if (this.languageSwitchTimer >= 0) {
      clearTimeout(this.languageSwitchTimer)
      this.languageSwitchTimer = -1
    }
    this.languageSwitchTimer = setTimeout(() => {
      this.languageSwitchTimer = -1
      this.callNativeWhenReady('setLanguage', lang, () => {
        if (this.languageStore.languageRefreshSerial !== languageSerial) return
        const selectedCategoryModuleId = this.searchStore.categoryModuleId
        this.catalogStore.objectCatalogCategories = []
        this.searchStore.categoryObjects = []
        this.searchStore.searchSuggestions = []
        this.searchStore.constellationNavigationItems = []
        this.catalogStore.loadObjectCatalogCategories(languageSerial)
        this.searchStore.loadConstellationNavigation(languageSerial)
        this.searchStore.loadCategoryObjects(this.searchStore.searchCategory, selectedCategoryModuleId)
        const query = this.searchStore.searchText.trim()
        if (query.length > 0) this.fetchSuggestions(query, languageSerial)
      }, 0, 300, 3)
    }, 50)
  }

  private syncManualTimeFromState(): void {
    this.callInteractive('getState', '', (result) => {
    if (result.jd !== undefined) {
      const jd = result.jd as number
      const z = Math.floor(jd + 0.5)
      const f = jd + 0.5 - z
      let A = z
      if (z >= 2299161) {
        const alpha = Math.floor((z - 1867216.25) / 36524.25)
        A = z + 1 + alpha - Math.floor(alpha / 4)
      }
      const B = A + 1524
      const C = Math.floor((B - 122.1) / 365.25)
      const D = Math.floor(365.25 * C)
      const E = Math.floor((B - D) / 30.6001)
      const day = B - D - Math.floor(30.6001 * E)
      const month = E < 14 ? E - 1 : E - 13
      const year = month > 2 ? C - 4716 : C - 4715
      const dayFraction = f * 24
      const hour = Math.floor(dayFraction)
      const minute = Math.floor((dayFraction - hour) * 60)
      this.timeStore.manualYear = year
      this.timeStore.manualMonth = month
      this.timeStore.manualDay = day
      this.timeStore.manualHour = hour
      this.timeStore.manualMinute = minute
    }
    })
  }

  private flashHint(text: ResourceStr): void {
    this.actionHint = text
    if (this.hintTimer !== 0) {
      clearTimeout(this.hintTimer)
    }
    this.hintTimer = setTimeout(() => {
      this.actionHint = ''
    }, 1600) as number
  }

  private stopSkyTextureStatusObserver(): void {
    if (this.skyTextureStatusTimer !== 0) {
      clearTimeout(this.skyTextureStatusTimer)
      this.skyTextureStatusTimer = 0
    }
    if (this.skyTextureStatusDelayTimer !== 0) {
      clearTimeout(this.skyTextureStatusDelayTimer)
      this.skyTextureStatusDelayTimer = 0
    }
    this.skyTextureStatusPolls = 0
    this.skyTextureStatusSlow = false
  }

  private hideSkyTextureStatus(): void {
    this.stopSkyTextureStatusObserver()
    this.tools.skyTextureStatusVisible = false
    this.tools.skyTextureStatusText = ''
    this.tools.skyTextureStatusError = false
  }

  private updateSkyTextureStatus(result: StellariumBridgeResponse): void {
    if (result.ok !== true) {
      this.hideSkyTextureStatus()
      return
    }
    const pending = typeof result.activeTexturePendingCount === 'number'
      ? result.activeTexturePendingCount as number : 0
    const errors = typeof result.activeTextureErrorCount === 'number'
      ? result.activeTextureErrorCount as number : 0
    const status = result.activeTextureStatus ?? ''
    if (errors > 0 || status === 'error' || status === 'partial-error') {
      hilog.warn(0x0000, 'StellariumArkUI', '[sky-banner] error count=%{public}d status=%{public}s',
        errors, status)
      this.tools.skyTextureStatusVisible = true
      this.tools.skyTextureStatusError = true
      this.tools.skyTextureStatusText = '当前视野有 ' + errors.toString() + ' 项资料图加载失败'
      return
    }
    if (pending > 0 || status === 'loading') {
      hilog.info(0x0000, 'StellariumArkUI', '[sky-banner] loading pending=%{public}d status=%{public}s',
        pending, status)
      this.tools.skyTextureStatusVisible = true
      this.tools.skyTextureStatusError = false
      this.tools.skyTextureStatusText = '正在载入当前视野资料图 · ' + pending.toString() + ' 项待完成'
      return
    }
    this.hideSkyTextureStatus()
  }

  private pollSkyTextureStatus(): void {
    this.skyTextureStatusPolls++
    if (this.skyTextureStatusPolls >= SKY_TEXTURE_STATUS_FAST_POLLS) {
      this.skyTextureStatusSlow = true
    }
    // A stall far past any plausible load is surfaced as an actionable error so
    // the banner can never sit on a loading state that will never finish. This
    // is an escalation, not a silent hide: the user keeps a retry affordance.
    if (this.skyTextureStatusSlow && this.skyTextureStatusPolls >= SKY_TEXTURE_STATUS_STALL_POLLS) {
      this.tools.skyTextureStatusVisible = true
      this.tools.skyTextureStatusError = true
      this.tools.skyTextureStatusText = '当前视野资料图仍在准备，可稍后重试'
      this.stopSkyTextureStatusObserver()
      return
    }
    this.callInteractive('getDeepSkyImageStatus', '', (result: StellariumBridgeResponse) => {
      this.updateSkyTextureStatus(result)
      // updateSkyTextureStatus already retracts the banner and stops polling
      // when the bridge reports a failure.
      if (result.ok !== true) {
        return
      }
      const pending = typeof result.activeTexturePendingCount === 'number'
        ? result.activeTexturePendingCount as number : 0
      if (pending <= 0 || result.activeTextureStatus === 'error' || result.activeTextureStatus === 'partial-error') {
        this.stopSkyTextureStatusObserver()
        return
      }
      const delay = this.skyTextureStatusSlow ? SKY_TEXTURE_STATUS_SLOW_INTERVAL_MS
        : (this.skyTextureStatusPolls <= 8 ? 350 : 900)
      this.skyTextureStatusTimer = setTimeout(() => {
        this.skyTextureStatusTimer = 0
        this.pollSkyTextureStatus()
      }, delay) as number
    }, () => {
      // The bridge did not answer; sample again later without inventing a state.
      const delay = this.skyTextureStatusSlow ? SKY_TEXTURE_STATUS_SLOW_INTERVAL_MS : 900
      this.skyTextureStatusTimer = setTimeout(() => {
        this.skyTextureStatusTimer = 0
        this.pollSkyTextureStatus()
      }, delay) as number
    })
  }

  private scheduleSkyTextureStatusCheck(): void {
    if (this.skyTextureStatusDelayTimer !== 0) {
      clearTimeout(this.skyTextureStatusDelayTimer)
    }
    this.skyTextureStatusDelayTimer = setTimeout(() => {
      this.skyTextureStatusDelayTimer = 0
      this.stopSkyTextureStatusObserver()
      this.pollSkyTextureStatus()
    }, 180) as number
  }

  private retrySkyTextureStatus(): void {
    this.tools.skyTextureStatusError = false
    this.tools.skyTextureStatusVisible = true
    this.tools.skyTextureStatusText = '正在重新载入当前视野资料图'
    this.callInteractive('retryDeepSkyImages', '', () => {
      this.scheduleSkyTextureStatusCheck()
    }, () => { this.tools.skyTextureStatusError = true })
  }

  // §14 B3-4：lx200Payload / applyTelescopeProfile / applyTelescopeProfiles 已搬入 TelescopeStore
  //（它们只读写 telescopeStore 字段与 live-position 定时器，属单一域，随定时器簇同片下沉）。

  private validateTelescopeEditorStatus(): void {
	if (this.telescopeStore.lx200Protocol === 'simulated') {
	  this.telescopeStore.lx200Transport = I18n.t('m_telescope_transport_simulated')
	  this.telescopeStore.lx200Scope = I18n.t('m_telescope_scope_offline')
	  this.telescopeStore.lx200ConnectionState = 'available'
	  return
	}
    this.callInteractive('getTelescopeControl', this.telescopeStore.lx200Host.trim() + '|' + this.telescopeStore.lx200Port.trim(), (result: TelescopeControlResponse) => {
      this.telescopeStore.applyTelescopeEndpointStatus(result)
    })
  }

  // §14 B3-4：applyTelescopeEndpointStatus / loadTelescopeControlStatus 已搬入 TelescopeStore。

  private selectTelescopeProfile(slot: number): void {
    if (slot === this.telescopeStore.lx200SelectedSlot && !this.telescopeStore.lx200EditingNew) return
    this.callInteractive('selectTelescopeProfile', slot.toString(), (result: TelescopeProfilesResponse) => {
      if (result.ok === true) {
        this.telescopeStore.applyTelescopeProfiles(result)
        this.validateTelescopeEditorStatus()
      } else {
        this.telescopeStore.lx200Status = result.error ?? I18n.t('m_telescope_load_failed')
      }
    })
  }

  private beginNewTelescopeProfile(): void {
    this.telescopeStore.stopTelescopeLivePosition(false)
    const used = new Set<number>(this.telescopeStore.lx200Profiles.map((profile: TelescopeProfile) => profile.slot))
    let slot = 1
    while (slot <= 9 && used.has(slot)) slot += 1
    if (slot > 9) {
      this.telescopeStore.lx200Status = I18n.t('m_telescope_slots_full')
      return
    }
    this.telescopeStore.lx200SelectedSlot = slot
	this.telescopeStore.lx200Name = I18n.format('m_telescope_simulator_name', [slot.toString()]) as string
	this.telescopeStore.lx200Protocol = 'simulated'
	this.telescopeStore.lx200DeviceModel = TELESCOPE_SIMULATOR_MODEL
	this.telescopeStore.lx200Host = ''
	this.telescopeStore.lx200Port = ''
    this.telescopeStore.lx200Equinox = 'J2000'
    this.telescopeStore.lx200CommandDelayMs = 0
    this.telescopeStore.lx200Circles = '1, 2, 4'
	this.telescopeStore.lx200EditingNew = true
	this.telescopeStore.lx200ConnectionState = 'available'
	this.telescopeStore.lx200Position = ''
	this.telescopeStore.lx200PositionUpdatedAt = ''
	this.telescopeStore.lx200PositionUpdateState = 'idle'
	this.validateTelescopeEditorStatus()
  }

  private selectTelescopeProtocol(protocol: string): void {
	if (protocol === this.telescopeStore.lx200Protocol) return
	this.telescopeStore.stopTelescopeLivePosition(false)
	this.telescopeStore.lx200Protocol = protocol
	this.telescopeStore.lx200Position = ''
	this.telescopeStore.lx200PositionUpdatedAt = ''
	this.telescopeStore.lx200PositionUpdateState = 'idle'
	if (protocol === 'simulated') {
	  this.telescopeStore.lx200DeviceModel = TELESCOPE_SIMULATOR_MODEL
	  this.telescopeStore.lx200Host = ''
	  this.telescopeStore.lx200Port = ''
	  this.telescopeStore.lx200ConnectionState = 'available'
	  this.telescopeStore.lx200Status = I18n.t('m_telescope_simulator_ready')
	} else {
	  this.telescopeStore.lx200DeviceModel = 'Meade LX200 (compatible)'
	  this.telescopeStore.lx200Host = '127.0.0.1'
	  this.telescopeStore.lx200Port = '4030'
	  this.telescopeStore.lx200ConnectionState = 'not_tested'
	  this.telescopeStore.lx200Status = I18n.t('m_telescope_not_tested')
	}
	this.validateTelescopeEditorStatus()
  }

  private saveTelescopeProfile(): void {
    const port = Number(this.telescopeStore.lx200Port.trim())
	const invalidEndpoint = this.telescopeStore.lx200Protocol === 'lx200_tcp' &&
	  (this.telescopeStore.lx200Host.trim().length === 0 || !Number.isInteger(port) || port < 1 || port > 65535)
	if (this.telescopeStore.lx200Name.trim().length === 0 || invalidEndpoint) {
      this.telescopeStore.lx200Status = I18n.t('m_telescope_invalid_profile')
      return
    }
    const profile: TelescopeProfile = {
      slot: this.telescopeStore.lx200SelectedSlot,
      name: this.telescopeStore.lx200Name.trim(),
	  protocol: this.telescopeStore.lx200Protocol,
      deviceModel: this.telescopeStore.lx200DeviceModel,
      host: this.telescopeStore.lx200Host.trim(),
	  port: this.telescopeStore.lx200Protocol === 'simulated' ? 0 : port,
      equinox: this.telescopeStore.lx200Equinox,
      commandDelayMs: this.telescopeStore.lx200CommandDelayMs,
      circles: this.telescopeStore.telescopeCircleValues()
    }
    this.telescopeStore.lx200Busy = true
    this.callInteractive('saveTelescopeProfile', JSON.stringify(profile), (result: TelescopeProfilesResponse) => {
      this.telescopeStore.lx200Busy = false
      if (result.ok !== true) {
        this.telescopeStore.lx200Status = result.error ?? I18n.t('m_telescope_save_failed')
        return
      }
      this.telescopeStore.applyTelescopeProfiles(result)
      this.telescopeStore.lx200Status = I18n.t('m_telescope_saved')
      this.validateTelescopeEditorStatus()
    }, () => { this.telescopeStore.lx200Busy = false })
  }

  private deleteTelescopeProfile(): void {
    if (this.telescopeStore.lx200EditingNew) {
      this.telescopeStore.loadTelescopeControlStatus()
      return
    }
    this.callInteractive('deleteTelescopeProfile', this.telescopeStore.lx200SelectedSlot.toString(), (result: TelescopeProfilesResponse) => {
      if (result.ok === true) {
        this.telescopeStore.applyTelescopeProfiles(result)
        this.telescopeStore.lx200Status = I18n.t('m_telescope_deleted')
        this.validateTelescopeEditorStatus()
      } else {
        this.telescopeStore.lx200Status = result.error ?? I18n.t('m_telescope_delete_failed')
      }
    })
  }

  private testTelescopeConnection(): void {
    if (this.telescopeStore.lx200EditingNew) {
      this.telescopeStore.lx200Status = I18n.t('m_telescope_save_before_test')
      return
    }
    this.telescopeStore.stopTelescopeLivePosition(false)
    this.telescopeStore.lx200Busy = true
    this.telescopeStore.lx200Status = I18n.t('m_telescope_connecting')
    this.callInteractive('testTelescopeConnection', this.telescopeStore.lx200Payload(), (result: TelescopeControlResponse) => {
	  this.telescopeStore.lx200Busy = false
	  this.telescopeStore.applyTelescopeEndpointStatus(result)
	  this.telescopeStore.lx200ConnectionState = result.ok === true ? 'available' : 'unavailable'
	  this.telescopeStore.lx200Status = result.ok === true
		? (result.simulated === true ? I18n.t('m_telescope_simulator_ready') : I18n.t('m_telescope_available'))
		: telescopeErrorText(result, I18n.t('m_telescope_test_failed'))
	  this.telescopeStore.scheduleTelescopeLivePosition()
	}, (result: StellariumBridgeResponse) => {
	  const response = result as TelescopeControlResponse
	  this.telescopeStore.lx200Busy = false
	  if (response.state === 'available' || response.state === 'unavailable') this.telescopeStore.lx200ConnectionState = response.state
	  this.telescopeStore.lx200Status = telescopeErrorText(response, I18n.t('m_telescope_test_failed'))
	  this.telescopeStore.scheduleTelescopeLivePosition()
	})
  }


  private applyLx200Result(result: StellariumBridgeResponse): void {
	const response = result as TelescopeControlResponse
	this.telescopeStore.lx200Busy = false
    if (result.ok === true) {
	  this.telescopeStore.lx200ConnectionState = 'available'
      const target = result.target && result.target.length > 0 ? result.target : I18n.t('m_telescope_target_default')
      const mode = result.mode === 'sync' ? I18n.t('m_telescope_mode_sync') : I18n.t('m_telescope_mode_goto')
	  const coord = result.ra && result.dec ? ' · ' + result.ra + ' / ' + result.dec : ''
	  this.telescopeStore.lx200Status = I18n.format('m_telescope_command_sent', [mode as string, target as string, coord])
	  if (result.mode === 'goto') this.telescopeStore.setTelescopeLivePosition(true)
    } else {
	  if (response.state === 'available' || response.state === 'unavailable') this.telescopeStore.lx200ConnectionState = response.state
	  this.telescopeStore.lx200Status = telescopeErrorText(response, I18n.t('m_telescope_disconnected'))
    }
	this.telescopeStore.scheduleTelescopeLivePosition()
  }

  private lx200GotoSelected(): void {
	if (this.telescopeStore.lx200EditingNew) {
	  this.telescopeStore.lx200Status = I18n.t('m_telescope_save_before_control')
	  return
	}
	this.telescopeStore.stopTelescopeLivePosition(false)
	this.telescopeStore.lx200Busy = true
	this.telescopeStore.lx200Status = I18n.t('m_telescope_sending_goto')
    this.callInteractive('telescopeLx200GotoSelected', this.telescopeStore.lx200Payload(),
      (result: StellariumBridgeResponse) => this.applyLx200Result(result),
      (result: StellariumBridgeResponse) => this.applyLx200Result(result))
  }

  private lx200SyncSelected(): void {
	if (this.telescopeStore.lx200EditingNew) {
	  this.telescopeStore.lx200Status = I18n.t('m_telescope_save_before_control')
	  return
	}
	this.telescopeStore.stopTelescopeLivePosition(false)
	this.telescopeStore.lx200Busy = true
	this.telescopeStore.lx200Status = I18n.t('m_telescope_sending_sync')
    this.callInteractive('telescopeLx200SyncSelected', this.telescopeStore.lx200Payload(),
      (result: StellariumBridgeResponse) => this.applyLx200Result(result),
      (result: StellariumBridgeResponse) => this.applyLx200Result(result))
  }

  private lx200Abort(): void {
	if (this.telescopeStore.lx200EditingNew) {
	  this.telescopeStore.lx200Status = I18n.t('m_telescope_save_before_control')
	  return
	}
    this.telescopeStore.stopTelescopeLivePosition(false)
    this.telescopeStore.lx200Busy = true
    this.callInteractive('telescopeLx200Abort', this.telescopeStore.lx200Payload(), (result) => {
	  const response = result as TelescopeControlResponse
	  this.telescopeStore.lx200Busy = false
	  if (response.state === 'available' || response.state === 'unavailable') this.telescopeStore.lx200ConnectionState = response.state
	  this.telescopeStore.lx200Status = result.ok === true ? I18n.t('m_telescope_stop_sent') :
		telescopeErrorText(response, I18n.t('m_telescope_stop_failed'))
	  this.telescopeStore.scheduleTelescopeLivePosition()
	}, (result: StellariumBridgeResponse) => {
	  const response = result as TelescopeControlResponse
	  this.telescopeStore.lx200Busy = false
	  if (response.state === 'available' || response.state === 'unavailable') this.telescopeStore.lx200ConnectionState = response.state
	  this.telescopeStore.lx200Status = telescopeErrorText(response, I18n.t('m_telescope_stop_failed'))
	  this.telescopeStore.scheduleTelescopeLivePosition()
	})
  }

  private readTelescopePosition(center: boolean = false): void {
	if (this.telescopeStore.lx200EditingNew) {
	  this.telescopeStore.lx200Status = I18n.t('m_telescope_save_before_control')
	  return
	}
	this.telescopeStore.stopTelescopeLivePosition(false)
	this.telescopeStore.lx200Busy = true
	this.telescopeStore.lx200Status = center ? I18n.t('m_telescope_centering') : I18n.t('m_telescope_reading_position')
	const command = center ? 'centerScreenOnTelescope' : 'getTelescopePosition'
	this.callInteractive(command, this.telescopeStore.lx200Payload(), (result: TelescopeControlResponse) => {
	  this.telescopeStore.lx200Busy = false
	  if (result.ok === true) {
		this.telescopeStore.lx200ConnectionState = 'available'
		this.telescopeStore.lx200Position = (result.ra ?? '--:--:--') + ' / ' + (result.dec ?? '--°--:--')
		this.telescopeStore.lx200PositionUpdatedAt = telescopeUpdateTime()
		this.telescopeStore.lx200PositionUpdateState = 'fresh'
		this.telescopeStore.lx200Status = center ? I18n.t('m_telescope_centered') : I18n.t('m_telescope_position_updated')
	  } else {
		if (result.state === 'available' || result.state === 'unavailable') this.telescopeStore.lx200ConnectionState = result.state
		this.telescopeStore.lx200Status = telescopeErrorText(result, I18n.t('m_telescope_position_failed'))
	  }
	  this.telescopeStore.scheduleTelescopeLivePosition()
	}, (result: StellariumBridgeResponse) => {
	  const response = result as TelescopeControlResponse
	  this.telescopeStore.lx200Busy = false
	  if (response.state === 'available' || response.state === 'unavailable') this.telescopeStore.lx200ConnectionState = response.state
	  this.telescopeStore.lx200PositionUpdateState = 'error'
	  this.telescopeStore.lx200Status = telescopeErrorText(response, I18n.t('m_telescope_position_failed'))
	  this.telescopeStore.scheduleTelescopeLivePosition()
	})
  }

  // toggleGyroscope / refreshGyroDisplayRotation 已随 M1-B 子组① 搬入 capability/SensorController.ets。

  private confirmPrivacyRevocation(): void {
    this.getUIContext().showAlertDialog({
      title: I18n.t('privacy_revoke'),
      message: I18n.t('privacy_revoke_message'),
      primaryButton: {
        value: I18n.t('cancel'),
        action: () => {}
      },
      secondaryButton: {
        value: I18n.t('privacy_revoke_confirm'),
        fontColor: '#E36A6A',
        action: () => { this.revokePrivacyConsent() }
      }
    })
  }

  private revokePrivacyConsent(): void {
    try {
      this.gyroCtl().stopGyroscope(false)
      privacyManager.disableService()
      AppStorage.setOrCreate('stellariumPrivacyHostReady', false)
      this.privacyNativeStartupAllowed = false
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      void context.terminateSelf().catch((err: Error) => {
        hilog.error(0x0000, 'StellariumArkUI', 'Failed to terminate after privacy revocation: %{public}s', JSON.stringify(err))
      })
    } catch (err) {
      hilog.error(0x0000, 'StellariumArkUI', 'Failed to revoke privacy consent: %{public}s', JSON.stringify(err))
      this.flashHint(I18n.t('privacy_revoke_failed'))
    }
  }

  // Device-pose tracking / 目标引导 / 姿态解算方法与全部 gyro* 字段已随 M1-B 子组①
  // 搬入 capability/SensorController.ets（本处仅保留宿主调用点）。

  // Retained as a reference implementation for diagnosing sensor-fusion
  // differences. The active implementation above intentionally does not
  // anchor the sky view to an arbitrary startup pose.
  private searchObject(name: string, catalogModuleId: string = '', exactSelectionPayload: string = '', placement: string = ''): void {
    const query = name.trim()
    if (query.length === 0) {
      return
    }
    this.flashHint(I18n.t('i0070').replace('%s', query))
    // 保存搜索历史（去重，最多保留 20 条）
    const hist = this.searchStore.searchHistory.filter(h => h !== query)
    hist.unshift(query)
    this.searchStore.searchHistory = hist.slice(0, 20)
    this.searchStore.saveSearchHistoryToStorage()
    const gyroSelection = this.gyroStore.gyroscopeEnabled
    let payload = exactSelectionPayload.length > 0
      ? exactSelectionPayload
      : (catalogModuleId.length > 0 ? 'catalog|' + catalogModuleId + '|' + query : query)
    if (gyroSelection) { payload += '|selectOnly' }
    this.callInteractive('searchObject', payload, (result) => {
      if (result.found === true) {
        const selectedEnglishName = result.englishName ?? result.name ?? query
        const observerPlanetSelection = this.sessionToolStore.isObserverPlanetSelection(selectedEnglishName)
        const returnToGraph = this.graphTargetPickerActive
        const returnToRts = this.rtsTargetPickerActive
        const returnToEphemeris = this.ephemerisTargetPickerActive
        const returnToAstroCalc = returnToGraph || returnToRts || returnToEphemeris
        // Close the search sheet before calculating the target's final safe
        // point. Otherwise the first navigation avoids the old 9/10 sheet,
        // then visibly performs a second correction for the top detail card.
        if (this.activePanel === 'search' && !returnToAstroCalc) {
          // Do this in-place instead of closePanel(): that generic helper
          // schedules a later recenter for the closing sheet, which can race
          // the newly opened object card and undo its safe target.
          this.stopTimePanelTimers()
          this.getUIContext().animateTo({ duration: 260, curve: curves.springMotion(0.45, 0.9) }, () => {
            this.panelVisible = false
          })
        }
        const selectionPlacement = placement.length > 0 ? placement : (returnToAstroCalc ? '' : 'center')
        this.applySelectedObject(result, false, selectionPlacement, true)
        if (returnToGraph) {
          this.graphTargetPickerActive = false
          this.astroStore.astroTab = 4
          this.setPanel('astro')
        } else if (returnToRts) {
          this.rtsTargetPickerActive = false
          this.astroStore.astroTab = 2
          this.setPanel('astro')
        } else if (returnToEphemeris) {
          this.ephemerisTargetPickerActive = false
          this.astroStore.astroTab = 1
          this.setPanel('astro')
          this.astroStore.loadEphemeris()
        }
        // Search navigation and safe-area placement already own the camera.
        // Enabling tracking here would call moveToObject() a second time after
        // the detail card is laid out, pulling a safely placed target back to
        // the screen centre. Keep gyro/observer selections explicitly stopped;
        // normal searches remain anchored at the position reached by navigation.
        if (gyroSelection || observerPlanetSelection) {
          this.setTrackingState(false)
        } else {
          this.trackingText = 'Off'
        }
        const displayName = zhNameOf(this.objectDetailStore.selectedName.length > 0 ? this.objectDetailStore.selectedName : query)
        this.flashHint(I18n.t('i0071').replace('%s', displayName))
      } else {
        this.applySelectedObject(result)
        this.flashHint(I18n.t('i0072').replace('%s', query))
      }
    })
  }

  // 拉取当前选中天体的信息并刷新详情面板。
  // 加防重入：避免自动刷新(1Hz)与手动“刷新”按钮重叠，导致 consume-on-read 结果被互相冲掉。
  // callNativeWhenReady 放弃轮询时不会回调，所以配 detailRefreshGuard 兜底复位，防止永久卡死。
  private refreshSelectedObject(): void {
    if (this.detailRefreshing) { return }
    const expectedName = this.objectDetailStore.selectedName
    const selectionSerial = this.skySelectionRequestSerial
    this.detailRefreshing = true
    if (this.detailRefreshGuard !== 0) { clearTimeout(this.detailRefreshGuard) }
    this.detailRefreshGuard = setTimeout(() => { this.detailRefreshing = false }, 1800) as number
    const detailsNeeded = !this.objectDetailStore.selectedDetailLoaded && (this.fullInspectorRequested || useTabletObjectInspector())
    if (detailsNeeded && this.objectDetailStore.selectedDetailRequestPending) {
      this.detailRefreshing = false
      if (this.detailRefreshGuard !== 0) { clearTimeout(this.detailRefreshGuard); this.detailRefreshGuard = 0 }
      return
    }
    const details = detailsNeeded ? 'details' : ''
    if (details === 'details') { this.objectDetailStore.selectedDetailRequestPending = true }
    this.callInteractive('getSelectedObjectInfo', details, (r) => {
      if (details === 'details') { this.objectDetailStore.selectedDetailRequestPending = false }
      this.detailRefreshing = false
      if (this.detailRefreshGuard !== 0) { clearTimeout(this.detailRefreshGuard); this.detailRefreshGuard = 0 }
      if (selectionSerial !== this.skySelectionRequestSerial || expectedName !== this.objectDetailStore.selectedName) {
        return
      }
      this.applySelectedObject(r, true)
    }, () => {
      if (details === 'details') { this.objectDetailStore.selectedDetailRequestPending = false }
      this.detailRefreshing = false
      if (this.detailRefreshGuard !== 0) { clearTimeout(this.detailRefreshGuard); this.detailRefreshGuard = 0 }
    })
  }

  // 启动“详情自动刷新”：仅在【目标详情面板打开 + 有已选中天体 + 未在拖动星图】时才拉数据，避免无谓的桥调用。
  private startDetailAutoRefresh(): void {
    if (this.detailTimer !== 0) { return }
    this.detailTimer = setInterval(() => {
      if (this.skyDragging) { return }
      if (this.objectDetailStore.selectedStatus === 'Selected' && ((this.activePanel === 'object' && this.panelVisible) || this.infoWindowStore.infoWinVisible)) {
        // The one-shot full-details request owns the initial structured card
        // load. Do not race it with a second request from the live-value poll.
        if (!this.objectDetailStore.selectedDetailLoaded && this.objectDetailStore.selectedDetailTimer !== 0) { return }
        this.refreshSelectedObject()
      }
    }, 180) as number
    this.startObjectDetailConnectorRefresh()
  }

  private pauseDetailRefreshForSkyDrag(): void {
    // Object-info polling uses the same ArkTS-to-Qt queue as panning. Stop it
    // for the duration of a gesture so an open detail card cannot make the sky
    // lag behind the finger. The connector is only a lightweight projection
    // read and must keep running so its line follows the native sky gesture.
    this.stopDetailAutoRefresh()
  }

  private resumeDetailRefreshAfterSkyDrag(): void {
    if (this.infoWindowStore.infoWinVisible && this.objectDetailStore.selectedStatus === 'Selected') {
      this.startDetailAutoRefresh()
      this.refreshObjectDetailConnector()
      this.scheduleSkyTextureStatusCheck()
    }
  }

  private stopDetailAutoRefresh(): void {
    if (this.detailTimer !== 0) { clearInterval(this.detailTimer); this.detailTimer = 0 }
    if (this.detailRefreshGuard !== 0) { clearTimeout(this.detailRefreshGuard); this.detailRefreshGuard = 0 }
    this.detailRefreshing = false
  }

  private startObjectDetailConnectorRefresh(): void {
    if (this.objectDetailConnectorTimer !== 0) { return }
    this.objectDetailConnectorTimer = setInterval(() => {
      this.refreshObjectDetailConnector()
    }, 32) as number
    this.refreshObjectDetailConnector()
  }

  private stopObjectDetailConnectorRefresh(): void {
    if (this.objectDetailConnectorTimer !== 0) {
      clearInterval(this.objectDetailConnectorTimer)
      this.objectDetailConnectorTimer = 0
    }
    if (this.objectDetailConnectorAnimationTimer !== 0) {
      clearTimeout(this.objectDetailConnectorAnimationTimer)
      this.objectDetailConnectorAnimationTimer = 0
    }
    this.objectDetailConnectorAnimateGeometry = false
  }

  private armObjectDetailConnectorTransition(): void {
    this.objectDetailConnectorAnimateGeometry = true
    if (this.objectDetailConnectorAnimationTimer !== 0) {
      clearTimeout(this.objectDetailConnectorAnimationTimer)
    }
    this.objectDetailConnectorAnimationTimer = setTimeout(() => {
      this.objectDetailConnectorAnimateGeometry = false
      this.objectDetailConnectorAnimationTimer = 0
    }, 190) as number
  }

  private objectDetailCardY(): number {
    return this.isFoldHoverLayout ? this.hoverBottomCardY() : this.bottomCardY()
  }

  private rayRectIntersection(originX: number, originY: number, targetX: number, targetY: number,
    left: number, top: number, right: number, bottom: number): number[] {
    const dx = targetX - originX
    const dy = targetY - originY
    const intersections: number[][] = []
    if (Math.abs(dx) > 0.0001) {
      const leftT = (left - originX) / dx
      const leftY = originY + leftT * dy
      if (leftT > 0 && leftY >= top - 0.5 && leftY <= bottom + 0.5) intersections.push([leftT, left, leftY])
      const rightT = (right - originX) / dx
      const rightY = originY + rightT * dy
      if (rightT > 0 && rightY >= top - 0.5 && rightY <= bottom + 0.5) intersections.push([rightT, right, rightY])
    }
    if (Math.abs(dy) > 0.0001) {
      const topT = (top - originY) / dy
      const topX = originX + topT * dx
      if (topT > 0 && topX >= left - 0.5 && topX <= right + 0.5) intersections.push([topT, topX, top])
      const bottomT = (bottom - originY) / dy
      const bottomX = originX + bottomT * dx
      if (bottomT > 0 && bottomX >= left - 0.5 && bottomX <= right + 0.5) intersections.push([bottomT, bottomX, bottom])
    }
    if (intersections.length === 0) return []
    intersections.sort((a: number[], b: number[]) => a[0] - b[0])
    return [intersections[0][1], intersections[0][2]]
  }

  private segmentRectEntryFraction(startX: number, startY: number, endX: number, endY: number,
    left: number, top: number, right: number, bottom: number): number {
    const dx = endX - startX
    const dy = endY - startY
    const p: number[] = [-dx, dx, -dy, dy]
    const q: number[] = [startX - left, right - startX, startY - top, bottom - startY]
    let entry = 0
    let exit = 1
    for (let index = 0; index < 4; index++) {
      if (Math.abs(p[index]) < 0.0001) {
        if (q[index] < 0) return -1
        continue
      }
      const fraction = q[index] / p[index]
      if (p[index] < 0) {
        if (fraction > exit) return -1
        if (fraction > entry) entry = fraction
      } else {
        if (fraction < entry) return -1
        if (fraction < exit) exit = fraction
      }
    }
    return entry >= 0 && entry <= 1 && entry <= exit ? entry : -1
  }

  private objectDetailConnectorObstacles(): SkyUiObstacle[] {
    const obstacles: SkyUiObstacle[] = []
    const layoutObstacles = this.selectedObjectUiObstacles()
    for (let index = 0; index < layoutObstacles.length; index++) {
      const obstacle = layoutObstacles[index]
      // The detail card is the start of the connector, not an obstacle to
      // route around. The panel and Dock remain real visual boundaries.
      if (obstacle.label !== 'object-card' && obstacle.label !== 'object-inspector' &&
        obstacle.label !== 'summary' && obstacle.label !== 'object-peek') {
        obstacles.push(obstacle)
      }
    }
    if (this.overlayStore.viewCoordinatesVisible) {
      obstacles.push({
        label: 'view-coordinates', left: this.viewCoordinateOverlayLeft() - 8,
        top: this.viewCoordinateOverlayTop() - 8,
        right: this.viewCoordinateOverlayLeft() + this.viewCoordinateOverlayWidth() + 8,
        bottom: this.viewCoordinateOverlayTop() + 100
      })
    }
    if (this.polarScopeStore.polarScopeVisible) {
      const headerTop = this.polarScopeTopInset()
      const left = (this.skyWidth - this.polarScopeControlWidth()) / 2
      const right = left + this.polarScopeControlWidth()
      obstacles.push({ label: 'polar-scope-header', left: left, top: headerTop,
        right: right, bottom: headerTop + 60 })
      obstacles.push({ label: 'polar-scope-footer', left: left,
        top: this.skyHeight - this.polarScopeFooterHeight() - 12, right: right,
        bottom: this.skyHeight - 12 })
    }
    if (this.gyroStore.gyroscopeEnabled && this.gyroStore.gyroCalibPanelOpen) {
      const calibrationLeft = this.isExpandedLayout ? this.EDGE_MARGIN + 64 : 16
      const calibrationTop = this.isExpandedLayout ? railTop(this.EDGE_MARGIN) + 120 : 80
      obstacles.push({ label: 'gyro-calibration', left: calibrationLeft - 8, top: calibrationTop - 8,
        right: calibrationLeft + (this.isExpandedLayout ? 320 : Math.min(360, this.skyWidth - 32)) + 8,
        bottom: calibrationTop + 270 })
    }
    if (!this.isExpandedLayout && this.isCompactTopQuickPoint(this.compactTopQuickX(), compactTopQuickY())) {
      const quickX = this.compactTopQuickX()
      const quickY = compactTopQuickY()
      obstacles.push({ label: 'compact-quick', left: quickX - 8, top: quickY - 8,
        right: quickX + 52, bottom: quickY + 106 })
    }
    return obstacles
  }

  private clearObjectDetailConnector(): void {
    this.objectDetailConnectorLength = 0
  }

  private refreshObjectDetailConnector(): void {
    if (!this.overlayStore.objectDetailConnectorVisible || !this.infoWindowStore.infoWinVisible || this.objectDetailStore.selectedStatus !== 'Selected' ||
      this.objectDetailStore.selectedName.length === 0) {
      this.clearObjectDetailConnector()
      return
    }
    const projection = this.callNative('getGyroGuidePosition') as GyroGuideProjection
    if (projection.ok !== true || projection.valid !== true ||
      typeof projection.xRatio !== 'number' || typeof projection.yRatio !== 'number') {
      this.clearObjectDetailConnector()
      return
    }
    const targetX = (projection.xRatio as number) * this.skyWidth
    const targetY = (projection.yRatio as number) * this.skyHeight
    if (!Number.isFinite(targetX) || !Number.isFinite(targetY)) {
      this.clearObjectDetailConnector()
      return
    }
    const targetOnScreen = projection.visible === true && targetX >= 0 && targetX <= this.skyWidth && targetY >= 0 && targetY <= this.skyHeight
    if (this.objectCardPlacementPending) {
      this.objectCardPlacementPending = false
    }
    const left = this.detailCardX()
    const top = this.detailCardY()
    const right = left + this.detailCardWidth()
    const bottom = top + this.detailCardHeight()
    if (targetOnScreen && pointInsideRect(targetX, targetY, left, top, right, bottom, 2)) {
      this.clearObjectDetailConnector()
      return
    }
    const centerX = (left + right) / 2
    const centerY = (top + bottom) / 2
    const cardIntersection = this.rayRectIntersection(centerX, centerY, targetX, targetY, left, top, right, bottom)
    if (cardIntersection.length !== 2) {
      this.clearObjectDetailConnector()
      return
    }
    let endX = targetX
    let endY = targetY
    if (!targetOnScreen) {
      const screenIntersection = this.rayRectIntersection(centerX, centerY, targetX, targetY, 12, 12, this.skyWidth - 12, this.skyHeight - 12)
      if (screenIntersection.length !== 2) {
        this.clearObjectDetailConnector()
        return
      }
      endX = screenIntersection[0]
      endY = screenIntersection[1]
    }
    const directionX = endX - centerX
    const directionY = endY - centerY
    const directionLength = Math.sqrt(directionX * directionX + directionY * directionY)
    if (!Number.isFinite(directionLength) || directionLength < 1) {
      return
    }
    const unitX = directionX / directionLength
    const unitY = directionY / directionLength
    const anchorX = cardIntersection[0] + unitX * 5
    const anchorY = cardIntersection[1] + unitY * 5
    if (targetOnScreen) {
      endX -= unitX * 16
      endY -= unitY * 16
    }

    let clippedByUi = false
    let clipFraction = 1
    const connectorUiGap = 6
    const connectorObstacles = this.objectDetailConnectorObstacles()
    for (let index = 0; index < connectorObstacles.length; index++) {
      const obstacle = connectorObstacles[index]
      const fraction = this.segmentRectEntryFraction(anchorX, anchorY, endX, endY,
        obstacle.left - connectorUiGap, obstacle.top - connectorUiGap,
        obstacle.right + connectorUiGap, obstacle.bottom + connectorUiGap)
      if (fraction < 0) continue
      if (fraction <= 0.015) {
        this.clearObjectDetailConnector()
        return
      }
      if (fraction < clipFraction) {
        clipFraction = fraction
        clippedByUi = true
      }
    }
    const menuStateChanged = this.objectDetailConnectorLength > 0 &&
      (this.objectDetailConnectorLastPanelVisible !== this.panelVisible ||
        this.objectDetailConnectorLastActivePanel !== this.activePanel)
    const avoidanceStateChanged = this.objectDetailConnectorLength > 0 &&
      this.objectDetailConnectorLastClippedByUi !== clippedByUi
    if (menuStateChanged || avoidanceStateChanged) {
      this.armObjectDetailConnectorTransition()
    }
    this.objectDetailConnectorLastPanelVisible = this.panelVisible
    this.objectDetailConnectorLastActivePanel = this.activePanel
    this.objectDetailConnectorLastClippedByUi = clippedByUi
    if (clippedByUi) {
      const fullDistance = Math.sqrt(Math.pow(endX - anchorX, 2) + Math.pow(endY - anchorY, 2))
      const safeFraction = Math.max(0, clipFraction - connectorUiGap / Math.max(1, fullDistance))
      endX = anchorX + (endX - anchorX) * safeFraction
      endY = anchorY + (endY - anchorY) * safeFraction
    }
    const dx = endX - anchorX
    const dy = endY - anchorY
    const length = Math.sqrt(dx * dx + dy * dy)
    if (!Number.isFinite(length) || length < 18) {
      this.clearObjectDetailConnector()
      return
    }
    const nextX = (endX + anchorX) / 2
    const nextY = (endY + anchorY) / 2
    const nextLength = Math.min(length, Math.max(this.skyWidth, this.skyHeight) * 1.5)
    let nextAngle = Math.atan2(dy, dx) * 180 / Math.PI
    while (nextAngle - this.objectDetailConnectorAngle > 180) nextAngle -= 360
    while (nextAngle - this.objectDetailConnectorAngle < -180) nextAngle += 360
    const nextEndX = endX
    const nextEndY = endY
    const nextTargetOnScreen = targetOnScreen && !clippedByUi
    const nextTargetX = nextTargetOnScreen ? targetX : endX
    const nextTargetY = nextTargetOnScreen ? targetY : endY
    const geometryChanged = this.objectDetailConnectorLength <= 0 ||
      Math.abs(nextX - this.objectDetailConnectorX) >= 0.75 ||
      Math.abs(nextY - this.objectDetailConnectorY) >= 0.75 ||
      Math.abs(nextLength - this.objectDetailConnectorLength) >= 0.75 ||
      Math.abs(nextAngle - this.objectDetailConnectorAngle) >= 0.35 ||
      Math.abs(nextEndX - this.objectDetailConnectorEndX) >= 0.75 ||
      Math.abs(nextEndY - this.objectDetailConnectorEndY) >= 0.75 ||
      Math.abs(nextTargetX - this.objectDetailConnectorTargetX) >= 0.75 ||
      Math.abs(nextTargetY - this.objectDetailConnectorTargetY) >= 0.75 ||
      nextTargetOnScreen !== this.objectDetailConnectorTargetOnScreen
    if (!geometryChanged) { return }
    this.objectDetailConnectorX = nextX
    this.objectDetailConnectorY = nextY
    this.objectDetailConnectorLength = nextLength
    this.objectDetailConnectorAngle = nextAngle
    this.objectDetailConnectorEndX = nextEndX
    this.objectDetailConnectorEndY = nextEndY
    this.objectDetailConnectorTargetX = nextTargetX
    this.objectDetailConnectorTargetY = nextTargetY
    this.objectDetailConnectorTargetOnScreen = nextTargetOnScreen
  }

  private objectDetailMarkerSize(): number {
    const fov = clamp(this.fovSliderValue > 0 ? this.fovSliderValue : 60, 4, 180)
    return clamp(32 * Math.pow(60 / fov, 0.35), 24, 58)
  }

  private requestSelectedDetails(expectedName: string): void {
    if (this.objectDetailStore.selectedDetailTimer !== 0) {
      clearTimeout(this.objectDetailStore.selectedDetailTimer)
    }
    this.objectDetailStore.selectedDetailRequestPending = true
    // Let selection, initial layout, and navigation start finish before asking
    // Qt to collect the complete structured field set.
    this.objectDetailStore.selectedDetailTimer = setTimeout(() => {
      this.objectDetailStore.selectedDetailTimer = 0
      if (!this.infoWindowStore.infoWinVisible || this.objectDetailStore.selectedName !== expectedName) {
        this.objectDetailStore.selectedDetailRequestPending = false
        return
      }
      if (this.skyDragging) {
        this.requestSelectedDetails(expectedName)
        return
      }
      this.callInteractive('getSelectedObjectInfo', 'details', (r) => {
        const returnedName = r.name && r.name.length > 0 ? r.name : r.englishName
        if (r.ok === true && r.found === true && returnedName === this.objectDetailStore.selectedName) {
          this.applySelectedObject(r, true)
        }
        this.objectDetailStore.selectedDetailRequestPending = false
      }, () => {
        this.objectDetailStore.selectedDetailRequestPending = false
      })
    }, 550) as number
  }

  private requestSatellitePasses(expectedName: string): void {
    if (this.objectDetailStore.selectedName !== expectedName || this.objectDetailStore.selectedSatellitePassesLoaded) return
    const payload = JSON.stringify({ hours: 12, limit: 3, minElevation: 10, visibleOnly: false })
    this.callInteractive('getSatellitePasses', payload, (r) => {
      if (this.objectDetailStore.selectedName !== expectedName) return
      if (r.ok === true) {
        this.objectDetailStore.selectedSatellitePasses = r.satellitePassList ?? []
      } else {
        this.objectDetailStore.selectedSatellitePasses = []
      }
      this.objectDetailStore.selectedSatellitePassesLoaded = true
    }, () => {
      if (this.objectDetailStore.selectedName === expectedName) {
        this.objectDetailStore.selectedSatellitePasses = []
        this.objectDetailStore.selectedSatellitePassesLoaded = true
      }
    })
  }

  // loadSelectedSatellitePasses 已下沉 ObjectDetailStore（§14 B2R-4）。

  private moveToSelectedObject(fromLayoutChange: boolean = false): void {
    if (!this.objectDetailStore.hasSelectedObject()) {
      this.flashHint(I18n.t('center_requires_selection'))
      return
    }
    // Sensor pose is the camera owner while gyro mode is active. Starting a
    // second auto-move here creates a visible jump when the next pose sample
    // correctly takes control back, so center/track only refresh the guide.
    if (this.gyroStore.gyroscopeEnabled) {
      this.gyroCtl().updateGyroTargetGuide(true)
      this.flashHint(I18n.t('center_unavailable_gyro'))
      return
    }
    if (fromLayoutChange) {
      this.placeSelectedObjectInSafeArea('layout')
      return
    }
    this.navigateSelectedObjectTo(this.skyWidth / 2, this.skyHeight / 2, 'center')
  }

  private navigateSelectedObjectTo(x: number, y: number, mode: string = 'focus'): void {
    if (this.skyWidth <= 1 || this.skyHeight <= 1) { return }
    const payload = `${Math.round(x)}|${Math.round(y)}|${Math.round(this.skyWidth)}|${Math.round(this.skyHeight)}|${mode}`
    const navigationKey = this.objectDetailStore.selectedName + '|' + payload
    hilog.info(0x0000, 'StellariumArkUI', 'safe-target request mode=%{public}s compact=%{public}s panel=%{public}s drawer=%{public}s info=%{public}s target=%{public}s',
      mode, (!this.isExpandedLayout).toString(), this.panelVisible.toString(), 'false', this.infoWindowStore.infoWinVisible.toString(), payload)
    const now = Date.now()
    // A layout callback can re-fire long after its animation has settled.
    // Repeating the same safe point would move a time-anchored target for no
    // visible UI change. Focus commands still pass through after the short
    // debounce so the explicit centre action remains available.
    if (mode === 'layout' && navigationKey === this.lastSafeNavigationPayload) {
      hilog.info(0x0000, 'StellariumArkUI', 'safe-target skipped unchanged layout')
      return
    }
    if (navigationKey === this.lastSafeNavigationPayload && now - this.lastSafeNavigationAt < 420) {
      return
    }
    this.lastSafeNavigationPayload = navigationKey
    this.lastSafeNavigationAt = now
    this.callInteractive('moveToSelectedAt', payload, (r) => {
      if (r.ok !== true) {
        this.flashHint(r.error ?? I18n.t('msg_apply_failed'))
        return
      }
      this.applySelectedObject(r)
      if (mode === 'center') {
        this.flashHint(I18n.t('center_applied'))
      }
    }, (r) => {
      this.flashHint(r.error ?? I18n.t('msg_apply_failed'))
    })
  }

  private placeSelectedObjectInSafeArea(mode: string = 'focus'): void {
    const fallback = this.isExpandedLayout ? this.expandedSafeTargetPoint() : this.compactSafeTargetPoint()
    if (mode === 'selection' || mode === 'layout') {
      const localTarget = this.selectedObjectLayoutAvoidanceTarget(fallback)
      if (localTarget.length === 2) {
        this.navigateSelectedObjectTo(localTarget[0], localTarget[1], mode)
      }
      return
    }
    this.navigateSelectedObjectTo(fallback[0], fallback[1], mode)
  }

  private selectedObjectUiObstacles(): SkyUiObstacle[] {
    const obstacles: SkyUiObstacle[] = []
    obstacles.push({
      label: 'bottom-dock', left: dockLeft(this.isExpandedLayout, this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN, this.compactDockWidthPercent()), top: this.dockTop(),
      right: dockLeft(this.isExpandedLayout, this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN, this.compactDockWidthPercent()) + dockWidthPixels(this.isExpandedLayout, this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN, this.compactDockWidthPercent()), bottom: this.skyHeight
    })
    if (this.isExpandedLayout) {
      if (this.panelVisible) {
        obstacles.push({
          label: 'panel', left: expandedMainPanelLeft(this.EDGE_MARGIN, this.panelOffsetX), top: panelTop(this.EDGE_MARGIN, this.panelOffsetY),
          right: expandedMainPanelLeft(this.EDGE_MARGIN, this.panelOffsetX) + this.panelWidth,
          bottom: panelTop(this.EDGE_MARGIN, this.panelOffsetY) + this.panelMaxHeight
        })
      }
      if (this.infoWindowStore.infoWinVisible) {
        if (useTabletObjectInspector()) {
          obstacles.push({
            label: 'object-inspector', left: this.tabletInspectorX(), top: this.tabletInspectorY(),
            right: this.tabletInspectorX() + this.tabletInspectorWidth(), bottom: this.tabletInspectorY() + tabletInspectorHeight(this.skyHeight, this.EDGE_MARGIN)
          })
        } else if (useExpandedDetailSummary() && canShowExpandedDetailSummary(this.skyWidth, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN)) {
          obstacles.push({
            label: 'summary', left: this.expandedDetailSummaryX(), top: this.expandedDetailSummaryY(),
            right: this.expandedDetailSummaryX() + expandedDetailSummaryWidth(this.skyWidth, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN),
            bottom: this.expandedDetailSummaryY() + expandedDetailSummaryHeight()
          })
        } else {
          obstacles.push({
            label: 'object-card', left: this.bottomCardX(), top: this.bottomCardY(),
            right: this.bottomCardX() + this.bottomCardWidth(),
            bottom: this.bottomCardY() + this.bottomCardHeight()
          })
        }
      }
      return obstacles
    }

    if (this.panelVisible) {
      const sheetTop = this.isFoldHoverLayout ? this.hoverPanelTop() : this.skyHeight - 90 - this.compactPanelHeight()
      obstacles.push({ label: 'sheet', left: 0, top: sheetTop, right: this.skyWidth, bottom: this.skyHeight - 90 })
    }
    if (!this.panelVisible && this.infoWindowStore.infoWinVisible) {
      if (isPhoneDetailPeek()) {
        obstacles.push({
          label: 'object-peek', left: this.compactObjectPeekX(), top: this.compactObjectPeekY(),
          right: this.compactObjectPeekX() + this.compactObjectPeekWidth(), bottom: this.compactObjectPeekY() + 64
        })
      } else {
        obstacles.push({
          label: 'object-card', left: this.bottomCardX(), top: this.bottomCardY(),
          right: this.bottomCardX() + this.bottomCardWidth(), bottom: this.bottomCardY() + this.bottomCardHeight()
        })
      }
    }
    return obstacles
  }

  private selectedObjectLayoutAvoidanceTarget(fallback: number[]): number[] {
    const projection = this.callNative('getGyroGuidePosition') as GyroGuideProjection
    if (projection.ok !== true || projection.valid !== true || projection.visible !== true ||
      typeof projection.xRatio !== 'number' || typeof projection.yRatio !== 'number') {
      hilog.info(0x0000, 'StellariumArkUI', 'safe-target skipped unavailable projection')
      return []
    }
    const currentX = (projection.xRatio as number) * this.skyWidth
    const currentY = (projection.yRatio as number) * this.skyHeight
    const obstacles = this.selectedObjectUiObstacles()
    let collision: SkyUiObstacle | undefined = undefined
    for (let index = 0; index < obstacles.length; index++) {
      if (pointOverlapsUiObstacle(currentX, currentY, obstacles[index])) {
        collision = obstacles[index]
        break
      }
    }
    if (collision === undefined) {
      hilog.info(0x0000, 'StellariumArkUI', 'safe-target skipped clear x=%{public}d y=%{public}d', Math.round(currentX), Math.round(currentY))
      return []
    }

    const edge = 18
    const gap = 30
    const minX = edge
    const maxX = this.skyWidth - edge
    const minY = edge
    const maxY = this.skyHeight - edge
    const candidates: number[][] = [
      [collision.left - gap, currentY], [collision.right + gap, currentY],
      [currentX, collision.top - gap], [currentX, collision.bottom + gap]
    ]
    let best: number[] = []
    let bestDistance = Number.MAX_VALUE
    for (let index = 0; index < candidates.length; index++) {
      const candidateX = clamp(candidates[index][0], minX, maxX)
      const candidateY = clamp(candidates[index][1], minY, maxY)
      let clear = true
      for (let obstacleIndex = 0; obstacleIndex < obstacles.length; obstacleIndex++) {
        if (pointOverlapsUiObstacle(candidateX, candidateY, obstacles[obstacleIndex], 12)) {
          clear = false
          break
        }
      }
      const distance = Math.pow(candidateX - currentX, 2) + Math.pow(candidateY - currentY, 2)
      if (clear && distance < bestDistance) {
        best = [candidateX, candidateY]
        bestDistance = distance
      }
    }
    if (best.length !== 2 || !Number.isFinite(best[0]) || !Number.isFinite(best[1])) {
      if (!Number.isFinite(fallback[0]) || !Number.isFinite(fallback[1])) {
        hilog.info(0x0000, 'StellariumArkUI', 'safe-target skipped no clear candidate')
        return []
      }
      best = fallback
    }
    hilog.info(0x0000, 'StellariumArkUI', 'safe-target collision %{public}s at=%{public}d|%{public}d target=%{public}d|%{public}d',
      collision.label, Math.round(currentX), Math.round(currentY), Math.round(best[0]), Math.round(best[1]))
    return best
  }

  // UI layout changes only refresh the connector. The selected object owns its
  // current sky position; opening a panel must never move the sky behind it.
  private scheduleSelectedObjectForUiChange(delay: number = 360): void {
    if (this.objectDetailStore.selectedUiLayoutTimer !== 0) {
      clearTimeout(this.objectDetailStore.selectedUiLayoutTimer)
      this.objectDetailStore.selectedUiLayoutTimer = 0
    }
    if (this.objectDetailStore.selectedStatus !== 'Selected') {
      return
    }
    this.objectDetailStore.selectedUiLayoutTimer = setTimeout(() => {
      this.objectDetailStore.selectedUiLayoutTimer = 0
      if (this.objectDetailStore.selectedStatus === 'Selected') {
        this.refreshObjectDetailConnector()
      }
    }, delay) as number
  }

  private cancelSelectedObjectUiChange(): void {
    if (this.objectDetailStore.selectedUiLayoutTimer !== 0) {
      clearTimeout(this.objectDetailStore.selectedUiLayoutTimer)
      this.objectDetailStore.selectedUiLayoutTimer = 0
    }
  }

  private compactSafeTargetPoint(): number[] {
    // Phone inspectors deliberately live at the top, not at the bottom.
    // Calculate the vertical gap from their real rendered bounds so a locked
    // target never lands inside either the inspector, the bottom dock, or an
    // open sheet. The centre x is clear of the left zoom controls and the
    // right quick controls.
    let top = 38
    let bottom = this.skyHeight - 100 // compact bottom dock plus breathing room

    // Compact panels replace the detailed object card. Reserving the hidden
    // card's area made a 9/10 sheet calculate a target underneath itself.
    if (this.infoWindowStore.infoWinVisible && !this.panelVisible) {
      if (isPhoneDetailPeek()) {
        top = Math.max(top, this.compactObjectPeekY() + 72 + 28)
      } else {
        top = Math.max(top, this.bottomCardY() + this.bottomCardHeight() + 28)
      }
    }
    let sheetTop = -1
    if (this.panelVisible) {
      sheetTop = this.skyHeight - 90 - this.compactPanelHeight()
      bottom = Math.min(bottom, sheetTop - 32)
    }

    // On very short screens, preserve a reachable sky target even when the
    // detail card and a 9/10 sheet leave no conventional vertical gap.
    if (bottom - top < 96) {
      bottom = Math.max(bottom, top + 96)
    }
    const targetY = clamp((top + bottom) / 2, top + 20, bottom - 20)
    hilog.info(0x0000, 'StellariumArkUI', 'compact-safe h=%{public}d usable=%{public}d snap=%{public}s drag=%{public}s sheetTop=%{public}d top=%{public}d bottom=%{public}d targetY=%{public}d',
      Math.round(this.skyHeight), Math.round(this.compactPanelUsableHeight()), this.compactPanelSnapRatio.toString(), this.compactPanelDragOffsetY.toString(), Math.round(sheetTop), Math.round(top), Math.round(bottom), Math.round(targetY))
    return [this.skyWidth / 2, targetY]
  }

  private expandedSafeTargetPoint(): number[] {
    const left = this.panelVisible ? expandedMainPanelLeft(this.EDGE_MARGIN, this.panelOffsetX) + this.panelWidth + 18 : this.EDGE_MARGIN + 64
    const right = this.panelVisible ? this.skyWidth - this.EDGE_MARGIN
      : (this.infoWindowStore.infoWinVisible ? this.bottomCardX() - 18 : this.skyWidth - this.EDGE_MARGIN)
    let top = this.EDGE_MARGIN + 24
    // With both cards open, keep the target below the compact object summary
    // and inside the unobstructed sky to the right of the Pad panel.
    if (this.panelVisible && this.infoWindowStore.infoWinVisible && useExpandedDetailSummary()) {
      top = this.expandedDetailSummaryY() + expandedDetailSummaryHeight() + 28
    }
    const bottom = this.skyHeight - this.EDGE_MARGIN
    if (right - left < 120 || bottom - top < 120) {
      return [this.skyWidth / 2, this.skyHeight / 2]
    }
    return [(left + right) / 2, (top + bottom) / 2]
  }

  // 精确到角秒：地球自转约 15″/秒，300ms 刷新时用户能直接看到坐标连续变化。

  // 天体名称由核心的官方 .qm 资源提供。ArkUI 只负责排版，不再维护
  // 第二套恒星、行星或深空天体译名。



  private wutTargetTitle(target: WutTarget): string {
    return celestialTitle(target.name ?? '', target.englishName ?? '')
  }









  private applySelectedInfoMode(mode: string): void {
    this.infoWindowStore.informationMode = mode
    if (mode === 'all') {
      this.infoWindowStore.infoLevel = 0
    } else if (mode === 'default') {
      this.infoWindowStore.infoLevel = 1
    } else if (mode === 'short') {
      this.infoWindowStore.infoLevel = 2
    } else if (mode === 'none') {
      this.infoWindowStore.infoLevel = 3
    } else if (mode === 'custom') {
      this.infoWindowStore.infoLevel = 0
    }
  }

  private applyCustomInformationMask(): void {
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

  private updateSelectedLiveDetails(fields: Array<ObjectDetailField>): void {
    const previous = this.objectDetailStore.selectedDetailFields
    const updated = previous
      .filter((field: ObjectDetailField) => field.live !== true || fields.some((item: ObjectDetailField) => item.key === field.key))
      .map((field: ObjectDetailField) => field.live === true
        ? (fields.find((item: ObjectDetailField) => item.key === field.key) ?? field) : field)
    this.objectDetailStore.selectedDetailFields = updated.concat(fields.filter((field: ObjectDetailField) =>
      !previous.some((item: ObjectDetailField) => item.key === field.key)))
  }

  // fromRefresh=true 时来自“详情自动刷新”等后台轮询：仅刷新数值，绝不重置展开态、也绝不因瞬时未命中而关窗。
  // userReselect=true 表示这是一次“用户主动选择”（星图点选 / 搜索结果 / WUT 行）：
  // 若用户此前手动关闭了同一目标的详情卡，再次选中它时必须重新弹出，而不是继续抑制。
  private applySelectedObject(result: StellariumBridgeResponse, fromRefresh: boolean = false, placement: string = '', userReselect: boolean = false): void {
    if (result.ok !== true) {
      this.objectDetailStore.selectedStatus = result.error ? result.error : 'Core not ready'
      return
    }
    if (result.found === true) {
      const incomingName = result.name && result.name.length > 0 ? result.name : (result.englishName ? result.englishName : '')
      // 核心的 type 已经由 StelObject::getObjectTypeI18n() 按官方 .qm
      // 资源本地化。objectType 只保留给音频和旧桥接数据，不应覆盖显示文本。
      const incomingType = (result.type && result.type.length > 0)
        ? result.type
        : ((result.objectType && (result.objectType as string).length > 0) ? (result.objectType as string) : 'Object')
      // 只有真正换了目标才重开详情。用户手动关闭同一目标后，任何后续刷新/误触
      // 都只更新数值，不能把卡片重新弹回来。
      const targetChanged = (this.objectDetailStore.selectedName !== incomingName) || (this.objectDetailStore.selectedType !== incomingType)
      const reopenDismissedDetail = userReselect && !targetChanged && !this.infoWindowStore.infoWinVisible
        && this.dismissedObjectName === incomingName
      const preserveClosedDetail = !userReselect && !this.infoWindowStore.infoWinVisible && !targetChanged && this.dismissedObjectName === incomingName
      const isNewSelection = targetChanged
      this.objectDetailStore.selectedName = incomingName
      this.objectDetailStore.selectedEnglishName = result.englishName && result.englishName.length > 0 ? result.englishName : ''
      this.objectDetailStore.selectedCatalogId = result.catalogId && result.catalogId.length > 0 ? result.catalogId : ''
      this.objectDetailStore.selectedDetailMediaPath = result.detailMediaPath && result.detailMediaPath.length > 0 ? result.detailMediaPath : ''
      this.objectDetailStore.selectedDetailMediaKind = result.detailMediaKind && result.detailMediaKind.length > 0 ? result.detailMediaKind : ''
      this.objectDetailStore.selectedDetailMediaLabel = result.detailMediaLabel && result.detailMediaLabel.length > 0 ? result.detailMediaLabel : ''
      this.objectDetailStore.selectedDetailModel = result.detailModel
      this.objectModelRendererCtl().refreshObjectInspectorModelLighting()
      this.objectDetailStore.selectedConstellationCultureId = result.constellationCultureId && result.constellationCultureId.length > 0 ? result.constellationCultureId : ''
      this.objectDetailStore.selectedConstellationCultureName = result.constellationCultureName && result.constellationCultureName.length > 0 ? result.constellationCultureName : ''
      this.objectDetailStore.selectedConstellationCultureDescription = result.constellationCultureDescription && result.constellationCultureDescription.length > 0 ? result.constellationCultureDescription : ''
      this.objectDetailStore.selectedConstellationCultureDescriptionBlocks = result.constellationCultureDescriptionBlocks !== undefined ? result.constellationCultureDescriptionBlocks : []
      this.objectDetailStore.selectedConstellationCultureDescriptionSource = result.constellationCultureDescriptionSource && result.constellationCultureDescriptionSource.length > 0 ? result.constellationCultureDescriptionSource : ''
      this.objectDetailStore.selectedObjectType = result.objectType && result.objectType.length > 0 ? result.objectType : ''
      this.objectDetailStore.selectedTemperatureK = typeof result.temperatureK === 'number' ? result.temperatureK : 0
      this.objectDetailStore.selectedType = incomingType
      this.refreshObjectInspectorMedia()
      if (result.infoMode !== undefined) {
        if (result.infoMode === 'custom' && result.customInfoMask !== undefined) {
          this.infoWindowStore.informationCustomMask = Number(result.customInfoMask)
        }
        this.applySelectedInfoMode(result.infoMode)
      }
      this.objectDetailStore.selectedStatus = 'Selected'
      const mag = (typeof result.magnitude === 'number') ? (result.magnitude as number) : 99
      const showBasicInfo = this.infoWindowStore.infoLevel <= 2
      const showObservedInfo = this.infoWindowStore.infoLevel <= 1
      this.objectDetailStore.selectedMagnitude = showBasicInfo && mag < 98 ? mag.toFixed(2) : ''
      const apparentMag = (typeof result.apparentMagnitude === 'number') ? (result.apparentMagnitude as number) : 99
      this.objectDetailStore.selectedApparentMagnitude = showObservedInfo && apparentMag < 98 ? apparentMag.toFixed(2) : ''
      this.objectDetailStore.selectedAirmass = showObservedInfo && typeof result.airmass === 'number' ? (result.airmass as number).toFixed(2) : ''
      this.objectDetailStore.selectedExtinction = showObservedInfo && typeof result.extinction === 'number' ? (result.extinction as number).toFixed(2) : ''
      if (result.detailFields !== undefined) {
        this.objectDetailStore.selectedDetailFields = result.detailFields
        this.objectDetailStore.selectedDetailLoaded = true
      } else if (result.liveDetailFields !== undefined && this.objectDetailStore.selectedDetailLoaded) {
        this.updateSelectedLiveDetails(result.liveDetailFields)
      }
      if (result.satellitePasses !== undefined) {
        this.objectDetailStore.selectedSatellitePasses = result.satellitePasses
        this.objectDetailStore.selectedSatellitePassesLoaded = true
      }
      const ra: string = result.ra ? result.ra : ''
      const dec: string = result.dec ? result.dec : ''
      this.objectDetailStore.selectedCoordEq = showBasicInfo && result.equatorialOfDate
        ? result.equatorialOfDate
        : (showBasicInfo && (ra.length > 0 || dec.length > 0) ? (ra + '  ' + dec).trim() : '')
      this.objectDetailStore.selectedCoordEqJ2000 = showBasicInfo && result.equatorialJ2000 ? result.equatorialJ2000 : ''
      this.objectDetailStore.selectedCoordApparentAltAz = showObservedInfo && result.apparentAltAz ? result.apparentAltAz : ''
      this.objectDetailStore.selectedCoordGeometricAltAz = showObservedInfo && result.geometricAltAz ? result.geometricAltAz : ''
      this.objectDetailStore.selectedCoordEcliptic = showBasicInfo && result.eclipticCurrent ? result.eclipticCurrent : ''
      this.objectDetailStore.selectedCoordEclipticJ2000 = showBasicInfo && result.eclipticJ2000 ? result.eclipticJ2000 : ''
      this.objectDetailStore.selectedCoordGalactic = showBasicInfo && result.galactic ? result.galactic : ''
      this.objectDetailStore.selectedCoordSupergalactic = showBasicInfo && result.supergalactic ? result.supergalactic : ''
      this.objectDetailStore.selectedCoordParallactic = showObservedInfo && result.parallacticAngle ? result.parallacticAngle : ''
      const hasAlt: boolean = typeof result.altitude === 'number'
      const hasAz: boolean = typeof result.azimuth === 'number'
      this.gyroCtl().setGuideTarget(hasAz ? result.azimuth as number : Number.NaN, hasAlt ? result.altitude as number : Number.NaN)
      // A stationary device may not pass the sensor movement threshold again
      // after a search. Recalculate the edge guide at selection time instead
      // of waiting for the next meaningful orientation delta.
      if (this.gyroStore.gyroscopeEnabled) {
        this.gyroCtl().updateGyroTargetGuide(true)
      }
      this.objectDetailStore.selectedCoordAlt = showObservedInfo && (hasAlt || hasAz)
        ? (I18n.t('coord_alt') + ' ' + (hasAlt ? fmtDegMin(result.altitude as number) : '--') + '  ' + I18n.t('coord_az') + ' ' + (hasAz ? fmtDegMin(result.azimuth as number) : '--'))
        : ''
      this.objectDetailStore.selectedHourAngle = showObservedInfo && result.hourAngle && result.hourAngle.length > 0 ? result.hourAngle : ''
      this.objectDetailStore.selectedMeanSiderealTime = showObservedInfo && result.meanSiderealTime && result.meanSiderealTime.length > 0 ? result.meanSiderealTime : ''
      this.objectDetailStore.selectedApparentSiderealTime = showObservedInfo && result.apparentSiderealTime && result.apparentSiderealTime.length > 0 ? result.apparentSiderealTime : ''
      this.objectDetailStore.selectedConstellation = showBasicInfo && result.constellation && result.constellation.length > 0 ? result.constellation : ''
      this.objectDetailStore.selectedDistance = showObservedInfo && result.distance && result.distance.length > 0 ? result.distance : ''
      this.objectDetailStore.selectedDistanceCompact = result.distanceCompact ?? result.distance ?? ''
      this.objectDetailStore.selectedDistanceStatus = result.distanceStatus ?? 'unavailable'
      this.objectDetailStore.selectedTleOutdated = result.tleOutdated === true
      // 过滤接近0的角直径（小行星等天体角直径极小，显示0无意义）
      const rawSize = result.size && result.size.length > 0 ? result.size : ''
      if (showObservedInfo && rawSize.length > 0) {
        const sizeMatch = rawSize.match(/([\d.]+)/)
        if (sizeMatch && parseFloat(sizeMatch[1]) === 0) {
          this.objectDetailStore.selectedSize = ''
        } else {
          this.objectDetailStore.selectedSize = rawSize
        }
      } else {
        this.objectDetailStore.selectedSize = ''
      }
      this.objectDetailStore.selectedRise = showObservedInfo && result.rise && result.rise.length > 0 ? result.rise : ''
      this.objectDetailStore.selectedSet = showObservedInfo && result.set && result.set.length > 0 ? result.set : ''
      this.objectDetailStore.selectedTransit = showObservedInfo && result.transit && result.transit.length > 0 ? result.transit : ''
      this.objectDetailStore.selectedPhase = showObservedInfo && typeof result.phase === 'number' ? (result.phase as number).toFixed(0) + '%' : ''
      this.objectDetailStore.selectedElongation = showObservedInfo && typeof result.elongation === 'number' ? (result.elongation as number).toFixed(1) + '°' : ''
      this.applyCustomInformationMask()
      // 选中成功后弹出独立浮动详情窗口（新目标默认收起，不打扰当前菜单；同一目标刷新时保留展开态）
      if (targetChanged) {
        this.dismissedObjectName = ''
        this.objectDetailConnectorLength = 0
        this.objectDetailStore.selectedConstellationCultureDescriptionExpanded = false
      }
      // 再次点选同一目标：清除“已关闭”记录并恢复展开态，让详情页重新弹出。
      if (reopenDismissedDetail) {
        this.dismissedObjectName = ''
        this.infoWindowStore.infoWinExpanded = true
        this.fullInspectorRequested = true
      }
      if (!preserveClosedDetail) {
        this.infoWindowStore.infoWinVisible = true
      }
      if (isNewSelection) {
        this.infoWindowStore.infoWinExpanded = true
        this.fullInspectorRequested = true
        this.objectMediaStore.objectInspectorMoreOpen = false
        this.objectDetailStore.bottomCardIndex = 2
        this.objectCardPlacementPending = true
        // The lightweight tap/search response deliberately has no detailFields.
        // Never leave the previous target's structured data visible while loading.
        this.objectDetailStore.selectedDetailFields = []
        this.objectDetailStore.selectedDetailLoaded = false
        this.objectDetailStore.selectedDetailRequestPending = false
        this.objectDetailStore.selectedSatellitePasses = []
        this.objectDetailStore.selectedSatellitePassesLoaded = false
        this.objectDetailStore.selectedSatellitePassesRequested = false
        // Sensor tracking owns the camera. A gyro-mode search selects the
        // target and opens its card, but never starts a safe-area fly-to.
        if (!this.gyroStore.gyroscopeEnabled && !this.sessionToolStore.isObserverPlanetSelection(incomingName)) {
          if (placement === 'center') {
            this.navigateSelectedObjectTo(this.skyWidth / 2, this.skyHeight / 2, 'center')
          }
        }
      }
      this.gyroCtl().updateGyroTargetGuide(true)
      // 天体名称和资料均来自核心；不再用本地手写别名表覆盖官方名称。
      this.objectDetailStore.selectedInfo = ''
      // 换了新天体 → 按它的"性格"响一声（模仿 Sky Guide 的叮）
      if (isNewSelection) {
        AudioEngine.getInstance().chimeForSelection(result)
      }
      this.startDetailAutoRefresh()
      if (isNewSelection && !this.objectDetailStore.selectedDetailLoaded) {
        this.requestSelectedDetails(this.objectDetailStore.selectedName)
      }
    } else {
      this.objectDetailStore.selectedName = ''
      this.objectDetailStore.selectedEnglishName = ''
      this.objectDetailStore.selectedCatalogId = ''
      this.objectDetailStore.selectedDetailMediaPath = ''
      this.objectDetailStore.selectedDetailMediaKind = ''
      this.objectDetailStore.selectedDetailMediaLabel = ''
      this.objectDetailStore.selectedDetailModel = undefined
      this.objectDetailStore.selectedConstellationCultureId = ''
      this.objectDetailStore.selectedConstellationCultureName = ''
      this.objectDetailStore.selectedConstellationCultureDescription = ''
      this.objectDetailStore.selectedConstellationCultureDescriptionBlocks = []
      this.objectDetailStore.selectedConstellationCultureDescriptionSource = ''
      this.objectDetailStore.selectedObjectType = ''
      this.objectDetailStore.selectedTemperatureK = 0
      this.objectDetailStore.selectedType = ''
      this.objectDetailStore.selectedSatellitePasses = []
      this.objectDetailStore.selectedSatellitePassesLoaded = false
      this.objectDetailStore.selectedSatellitePassesRequested = false
      this.objectDetailStore.selectedStatus = result.query && result.query.length > 0 ? 'Try English name' : 'No match'
      this.objectDetailStore.selectedMagnitude = ''
      this.objectDetailStore.selectedApparentMagnitude = ''
      this.objectDetailStore.selectedAirmass = ''
      this.objectDetailStore.selectedExtinction = ''
      this.objectDetailStore.selectedDetailFields = []
      this.objectDetailStore.selectedDetailLoaded = false
      this.objectDetailStore.selectedDetailRequestPending = false
      this.objectDetailStore.selectedCoordEq = ''
      this.objectDetailStore.selectedCoordEqJ2000 = ''
      this.objectDetailStore.selectedCoordApparentAltAz = ''
      this.objectDetailStore.selectedCoordGeometricAltAz = ''
      this.objectDetailStore.selectedCoordEcliptic = ''
      this.objectDetailStore.selectedCoordEclipticJ2000 = ''
      this.objectDetailStore.selectedCoordGalactic = ''
      this.objectDetailStore.selectedCoordSupergalactic = ''
      this.objectDetailStore.selectedCoordParallactic = ''
      this.objectDetailStore.selectedCoordAlt = ''
      this.objectDetailStore.selectedHourAngle = ''
      this.objectDetailStore.selectedMeanSiderealTime = ''
      this.objectDetailStore.selectedApparentSiderealTime = ''
      this.objectDetailStore.selectedConstellation = ''
      this.objectDetailStore.selectedDistance = ''
      this.objectDetailStore.selectedDistanceCompact = ''
      this.objectDetailStore.selectedDistanceStatus = ''
      this.objectDetailStore.selectedTleOutdated = false
      this.gyroCtl().clearGuideTarget()
      this.gyroStore.gyroGuideVisible = false
      this.objectDetailStore.selectedSize = ''
      this.objectDetailStore.selectedRise = ''
      this.objectDetailStore.selectedSet = ''
      this.objectDetailStore.selectedTransit = ''
      this.objectDetailStore.selectedPhase = ''
      this.objectDetailStore.selectedElongation = ''
      this.objectMediaStore.objectInspectorMoreOpen = false
      this.objectMediaStore.objectInspectorMediaPath = ''
      this.objectMediaStore.objectInspectorMediaKind = 'none'
      this.objectMediaStore.objectInspectorMediaLabel = ''
      this.objectMediaStore.objectInspectorMediaLoading = false
      this.objectMediaStore.objectInspectorMediaDecoding = false
      this.clearObjectInspectorDecodedImage()
      this.objectMediaStore.objectInspectorMediaLoadFailed = false
      this.objectMediaStore.objectInspectorMediaPreparationFailed = false
      this.stopObjectInspectorMediaWarmup()
      this.objectInspectorMediaRequestPath = ''
      this.objectInspectorMediaResolvedRequestPath = ''
      this.objectInspectorMediaResolvedPath = ''
      this.objectInspectorMediaResolutionComplete = false
      this.objectMediaStore.objectInspectorMediaFullscreen = false
      this.objectMediaStore.objectInspectorMediaPreviewPath = ''
      this.objectMediaStore.objectInspectorMediaPreviewLoading = false
      this.objectMediaStore.objectInspectorMediaPreviewFailed = false
      this.infoWindowStore.infoWinVisible = false
      this.objectDetailStore.selectedInfo = '当前位置没有可选天体，请放大或使用搜索'
      this.astroStore.clearRtsSelectionResults()
    }
  }

  /**
   * 轻量时间刷新：只取 jd + timeRate（getSimulationTime 极轻），不做 getState 全量状态同步。
   * 用于时间面板的高频（~120ms）流式刷新，让读秒像水一样连续流动而不是每秒跳一大格。
   * 注意：不要在这里改动除时间/速率以外的任何 @State，否则会引发全局重排、拖动星图变卡。
   */
  private refreshSimTimeLight(): void {
    this.callInteractive('getSimulationTime', '', (r: StellariumBridgeResponse) => {
      if (r.ok !== true || r.jd === undefined) { return }
      const jd: number = r.jd as number
      // jd 是 UTC；加上观测地 UTC 偏移后再格式化，与 getState 的 timeText 口径保持一致
      const text: string = r.formattedTime ?? jdToLocalTimeText(jd + this.utcOffsetHours / 24.0)
      if (text !== this.timeStore.observationTimeText) {
        this.timeStore.observationTimeText = text
      }
      if (r.timeRate !== undefined) {
        this.syncTimeRateState(r.timeRate as number)
      }
      this.wheel().syncFromSimulation(jd)
      this.syncJulianDateFields(r, jd)
    })
  }

  /** 儒略日 -> 'YYYY-MM-DD HH:mm:ss' 本地显示文本（入参需已含 UTC 偏移）。 */

  private formatObservationTime(raw: string): string {
    if (!raw || raw.length === 0) {
      return '--'
    }
    // C++ has already applied the observation location's UTC offset before it
    // serializes timeText. Parsing the ISO value as a device-local Date applied
    // a second timezone conversion every 3 seconds, racing the lightweight JD
    // refresh and making the digits visibly jump. Preserve that local clock.
    let text = raw.trim()
    if (text.endsWith('Z')) {
      text = text.slice(0, -1)
    } else {
      const plus = text.lastIndexOf('+')
      const minus = text.lastIndexOf('-')
      const zoneStart = Math.max(plus, minus)
      if (zoneStart > 10) {
        text = text.slice(0, zoneStart)
      }
    }
    return text.replace('T', ' ')
  }


  // 地图几何 / 点选 / 触摸（locationMapWidth/Height、setPickerLocation、updatePickerFromMap、
  // handleLocationMapTouch）已随 §15.12 下沉 panels/location/LocationPickerPanel.ets 与
  // state/LocationPickerStore.ets（setPickerLocation 为两处共用的纯 setter）。

  // GPS 定位 / 应用 / 落地（useDeviceLocation、applyPickerLocation、setLocation）与请求中标志
  // 已随 §15.12 下沉 capability/LocationController.ets（NAPI 经 HostLocationPort，跨域写经 LocationHostHooks）。

  // 离线搜索三法（searchLocations / scanLocationSearchChunk / selectSearchLocation）已随 §15.12 下沉
  // state/LocationStore.ets（跨域助手与 setLocation 经 LocationStoreHostHooks 回注）。

  // ===== 时区获取 =====
  // approximateTimeZoneDisplay 与 loadObserverInfo 已随 §14 B2R-2 下沉：
  // 前者迁至 common/derive/labels.ets（纯函数），后者迁至 LocationPickerStore。

  // 已保存位置三法（saveCurrentLocation / deleteSavedLocation / persistSavedLocations）已随 §15.12
  // 下沉 state/LocationStore.ets（保持 AppStorage 持久化方式原样）；setObserverPlanet 已下沉
  // capability/LocationController.ets。

  // 虚拟指星笔（多设备联动）目标端测试入口：输入高度角/方位角，调 pointAtSky
  // 把星图中心转到该方向并选中那颗星。手表/分布式未来只是另一种触发方式。
  private pointAtSkyTest(): void {
    const alt = this.sessionToolStore.pointAlt.trim()
    const az = this.sessionToolStore.pointAz.trim()
    this.callNativeWhenReady('pointAtSky', alt + '|' + az, (r: StellariumBridgeResponse) => {
      if (!r.ok) {
        this.sessionToolStore.pointResult = '指星笔命令未响应'
        this.flashHint('指星笔命令未响应')
        return
      }
      this.sessionToolStore.pointResult = '已指向 高度角' + alt + '° 方位角' + az + '°（星图下一帧转过去并选中中心星）'
      this.flashHint('星图已转向 ' + alt + '°/' + az + '°')
      // 等一帧让 pointAtSky 完成中心选中，再读选中天体
      setTimeout(() => {
        this.callNativeWhenReady('getSelectedObjectInfo', '', (r2: StellariumBridgeResponse) => {
          if (!r2.ok) return
          if (r2.found) {
            const nm = (r2.name !== undefined && r2.name !== null) ? String(r2.name) : '未知'
            const tp = (r2.type !== undefined && r2.type !== null) ? String(r2.type) : ''
            this.sessionToolStore.pointResult = '指向命中：' + nm + '（' + tp + '）'
            this.flashHint('指向命中：' + nm)
          } else {
            this.sessionToolStore.pointResult = '指向方向：' + alt + '°/' + az + '° 该处暂无可选中天体'
            this.flashHint('该处暂无可选中天体')
          }
        })
      }, 400)
    })
  }

  // 虚拟指星笔（watchGyroSend/Start/Stop）已随 M1-B 子组① 搬入 capability/SensorController.ets
  // （M1-A 实测：该路径为桥驱动 pointAtSky，归 CommandPort）。

  // Jump to specific RA/Dec coordinates (J2000 equatorial).
  private goToCoordinates(): void {
    const raStr: string = this.searchStore.coordInputRA.trim()
    const decStr: string = this.searchStore.coordInputDec.trim()
    if (raStr.length === 0 || decStr.length === 0) { return }
    // Parse RA: support formats like "5.5", "5h30m", "05:30:00"
    let raHours: number = 0
    if (raStr.includes('h')) {
      const parts: string[] = raStr.replace('m', '').split('h')
      raHours = parseFloat(parts[0]) + (parts.length > 1 ? parseFloat(parts[1]) / 60 : 0)
    } else if (raStr.includes(':')) {
      const parts: string[] = raStr.split(':')
      raHours = parseFloat(parts[0]) + (parts.length > 1 ? parseFloat(parts[1]) / 60 : 0) + (parts.length > 2 ? parseFloat(parts[2]) / 3600 : 0)
    } else {
      raHours = parseFloat(raStr)
    }
    // Parse Dec: support formats like "+45.5", "45:30:00", "-45d30m"
    let decDeg: number = 0
    const decClean: string = decStr.replace(/[d°′″'"]/g, '')
    if (decClean.includes(':')) {
      const parts: string[] = decClean.split(':')
      decDeg = parseFloat(parts[0]) + (parts.length > 1 ? parseFloat(parts[1]) / 60 : 0) + (parts.length > 2 ? parseFloat(parts[2]) / 3600 : 0)
    } else {
      decDeg = parseFloat(decClean)
    }
    if (isNaN(raHours) || isNaN(decDeg)) { return }
    this.callInteractive('gotoRADec', `${raHours}|${decDeg}`, (r: StellariumBridgeResponse) => {
      if (!r.ok) {
        this.flashHint(I18n.t('msg_navigation_failed'))
        return
      }
      this.flashHint(I18n.t('msg_goto_coord'))
    })
  }

  // watchGyroStop 已随 M1-B 子组① 搬入 capability/SensorController.ets。

  // 多设备接续 / 无缝流转（能力 A 的"会话搬运"目标端 + 脚手架）
  // 把当前星图会话(视线/FOV/时间/位置/选中星)导出成 JSON，可在另一台鸿蒙设备导入接续；
  // 完整跨设备一键流转需华为分布式软总线(Distributed Hardware Kit)。当前基础 SDK 已把
  // "导出/导入"做成统一命令桥，切到含分布式能力的 SDK 后这里即可改为设备发现+拉起目标 Ability。

  private refreshTonight(): void {
    this.callNativeWhenReady('getTonightEvents', '', (r: StellariumBridgeResponse) => {
      if (!r.ok || !r.tonight) { this.flashHint(I18n.t('msg_fetch_failed')); return }
      const t = r.tonight as TonightEvents
      this.sessionToolStore.tonightDate = this.fmtIso(t.date ?? '')
      this.sessionToolStore.tonightMoon = I18n.t('tn_phase') + ': ' + (t.moon?.phaseName ?? I18n.t('m_unknown')) + ' (' + I18n.t('tn_illumination') + ' ' + Math.round(t.moon?.illumination ?? 0) + '% · ' + I18n.t('tn_moon_age') + ' ' + (t.moon?.age ?? 0).toFixed(1) + ' ' + I18n.t('tn_days') + ')\n'
        + '  ' + I18n.t('tn_rise') + ' ' + this.fmtIso(t.moon?.rise ?? '') + ' · ' + I18n.t('tn_transit') + ' ' + this.fmtIso(t.moon?.transit ?? '') + ' · ' + I18n.t('tn_set') + ' ' + this.fmtIso(t.moon?.set ?? '')
      this.sessionToolStore.tonightSun = I18n.t('tn_rise') + ' ' + this.fmtIso(t.sun?.rise ?? '') + ' · ' + I18n.t('tn_transit') + ' ' + this.fmtIso(t.sun?.transit ?? '') + ' · ' + I18n.t('tn_set') + ' ' + this.fmtIso(t.sun?.set ?? '')
      this.sessionToolStore.tonightDark = I18n.t('tn_astro_dusk') + ' ' + this.fmtIso(t.sun?.astroTwilightEnd ?? '') + ' → ' + I18n.t('tn_astro_dawn') + ' ' + this.fmtIso(t.sun?.astroTwilightStart ?? '')
        + (t.sun?.darkWindowHours !== undefined ? (' (' + I18n.t('tn_dark_hours') + ' ~' + t.sun.darkWindowHours.toFixed(1) + ' ' + I18n.t('tn_hours') + ')') : '')
      this.sessionToolStore.tonightPlanetRows = (t.planets ?? []).map((p): TonightPlanetRow => {
        const vis = p.visible === true ? I18n.t('tn_visible') : I18n.t('tn_below_horizon')
        return {
          name: p.name ?? (p.englishName ?? ''),
          line: I18n.t('tn_rise') + ' ' + this.fmtIso(p.rise ?? '') + ' · ' + I18n.t('tn_transit') + ' ' + this.fmtIso(p.transit ?? '') + ' · ' + I18n.t('tn_set') + ' ' + this.fmtIso(p.set ?? '')
            + ' · ' + I18n.t('tn_magnitude') + ' ' + (p.magnitude ?? 0).toFixed(1) + ' · ' + vis,
          jd: p.transitJd ?? 0,
          lock: p.englishName ?? (p.name ?? '')
        }
      })
      this.sessionToolStore.tonightShowers = (t.meteorShowers ?? []).map((s) => (s.name ?? '') + ': ZHR~' + (s.zhr ?? 0) + (s.status === 'confirmed' ? ' (' + I18n.t('tn_confirmed') + ')' : ' (' + I18n.t('tn_generic') + ')'))
      this.sessionToolStore.tonightSats = ((t.satellites?.enabled ?? false) ? (I18n.t('tn_loaded') + ' ' + (t.satellites?.count ?? 0) + ' ' + I18n.t('tn_sats_count')) : I18n.t('tn_not_enabled')) + ' (' + I18n.t('tn_transit_needs_data') + ')'
      // 点击跳转的时间基准
      this.sessionToolStore.tonightMoonJd = t.moon?.transitJd ?? 0
      this.sessionToolStore.tonightSunJd = t.sun?.astroTwilightEndJd ?? 0
      this.sessionToolStore.tonightShowerJd = (t.meteorShowers && t.meteorShowers.length > 0) ? (t.meteorShowers[0].primeJd ?? this.sessionToolStore.tonightSunJd) : this.sessionToolStore.tonightSunJd
      this.sessionToolStore.tonightHint = I18n.t('tn_updated') + ' · ' + this.fmtIso(t.date ?? '')
      this.flashHint('已刷新今晚天象 · 点击卡片可跳转')
    })
  }

  // 点击今晚天象卡片：跳到事件发生时刻，并锁定主角(lock)、框入卫星(月球)
  private gotoTonightEvent(jd: number, lock: string, title: string): void {
    const label = title.replace(/[^0-9A-Za-z\u4e00-\u9fa5]/g, '')
    this.flashHint(I18n.t('msg_navigating'))
    this.callNativeWhenReady('setJD', jd.toString(), () => {
      this.callNativeWhenReady('searchObject', lock, (r2: StellariumBridgeResponse) => {
        this.frameSatellite()
        const found = r2.found === true
        this.flashHint(found
          ? ('已跳至『' + label + '』时刻，锁定『' + lock + '』并框入月球(卫星)')
          : ('已跳至『' + label + '』时刻，但未找到『' + lock + '』'))
      })
    })
  }

  // 跳转后若视角过窄，适当拉远以便把卫星(月球)一并收入视野
  private frameSatellite(): void {
    this.callNativeWhenReady('getSessionState', '', (r: StellariumBridgeResponse) => {
      const fov = (r.fovDeg ?? 0)
      if (fov > 0 && fov < 12) {
        const target = 16
        this.callNativeWhenReady('zoomBy', (target / fov).toFixed(3) + '|0')
      }
    })
  }

  private fmtIso(iso: string): string {
    if (!iso || iso.length < 16) return '--'
    const parts = iso.split('T')
    const d = parts[0] ?? ''
    const t = parts[1] ?? ''
    return (d.length >= 10 ? d.slice(5) : d) + ' ' + (t.length >= 8 ? t.slice(0, 5) : t)
  }


  private selectContinent(c: string): void {
    this.locationPickerStore.hierContinent = c
    this.locationPickerStore.hierCountry = ''
    this.locationPickerStore.hierRegion = ''
    this.locationPickerStore.hierCity = ''
  }

  private selectCountry(country: string): void {
    this.locationPickerStore.hierCountry = country
    this.locationPickerStore.hierRegion = ''
    this.locationPickerStore.hierCity = ''
  }

  private selectRegion(r: string): void {
    this.locationPickerStore.hierRegion = r
    this.locationPickerStore.hierCity = ''
  }

  private selectCityByName(name: string): void {
    this.locationPickerStore.hierCity = name
    const found = this.locationPickerStore.hierCities(this.sessionToolStore.observerPlanet).find((c: HierCity) => c.n === name)
    if (found) {
      // Auto-apply the selected city immediately
      this.locationCtl().setLocation(found.n, found.la, found.lo, found.al, this.locationPickerStore.locationPlanet(found))
    }
  }




  private isUiPoint(x: number, y: number): boolean {
    // 录制聚焦态（控制条收起）：除顶部录制控制条外，面板/详情卡/搜索/Dock/底部条等界面
    // 全部隐藏，不得留下“幽灵命中区”吞掉拖动。此前只有录制条被排除，其余隐藏界面的命中区
    // 仍在，导致星图（含中央）多处拖不动。
    if (this.tools.recording && !this.tools.recordingUiExpanded &&
      !this.scriptStore.scriptPlaybackVisible(this.guideStore.guideState.active)) {
      return x >= 16 && x <= Math.max(266, this.skyWidth - 16) &&
        y >= this.EDGE_MARGIN - 8 && y <= this.EDGE_MARGIN + 58
    }
    if (this.guideStore.guideState.active) {
      return x >= guideCardX(this.isExpandedLayout, this.skyWidth, this.guideCardWidth(), this.scriptStore.scriptControlOffsetX) && x <= guideCardX(this.isExpandedLayout, this.skyWidth, this.guideCardWidth(), this.scriptStore.scriptControlOffsetX) + this.guideCardWidth() &&
        y >= guideCardY(this.skyHeight, guideCardHeight(this.skyHeight, this.scriptControlSafeTop()), this.scriptControlSafeTop(), this.scriptStore.scriptControlOffsetY) && y <= guideCardY(this.skyHeight, guideCardHeight(this.skyHeight, this.scriptControlSafeTop()), this.scriptControlSafeTop(), this.scriptStore.scriptControlOffsetY) + guideCardHeight(this.skyHeight, this.scriptControlSafeTop())
    }
    if (this.polarScopeStore.polarScopeVisible) {
      const headerTop = this.polarScopeTopInset()
      const left = (this.skyWidth - this.polarScopeControlWidth()) / 2
      if (x >= left && x <= left + this.polarScopeControlWidth() &&
        ((y >= headerTop && y <= headerTop + 60) ||
          (y >= this.skyHeight - this.polarScopeFooterHeight() - 12 && y <= this.skyHeight - 12))) {
        return true
      }
      return false
    }
    if (this.tools.recording && !this.scriptStore.scriptPlaybackVisible(this.guideStore.guideState.active) &&
      x >= 16 && x <= Math.max(266, this.skyWidth - 16) &&
      y >= this.EDGE_MARGIN - 8 && y <= this.EDGE_MARGIN + 58) {
      return true
    }
    if (isDockPoint(x, y, this.polarScopeStore.polarScopeVisible, this.isExpandedLayout, this.skyWidth, this.skyHeight, this.panelVisible, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN, this.compactDockWidthPercent(), this.dockTop())) {
      return true
    }
    if (this.overlayStore.viewCoordinatesVisible) {
      const coordinateLeft = this.viewCoordinateOverlayLeft()
      const coordinateTop = this.viewCoordinateOverlayTop()
      const coordinateWidth = this.viewCoordinateOverlayWidth()
      if (x >= coordinateLeft - 8 && x <= coordinateLeft + coordinateWidth + 8 &&
        y >= coordinateTop - 8 && y <= coordinateTop + 92) {
        return true
      }
    }
    // 顶部搜索栏：点击区域不穿透到星图
    if (this.isExpandedLayout) {
      const sbX = this.EDGE_MARGIN + 64
      const sbY = this.EDGE_MARGIN
      const sbW = 300
      const sbH = 44
      if (x >= sbX && x <= sbX + sbW && y >= sbY && y <= sbY + sbH) {
        return true
      }
    } else {
      if (this.isFoldHoverLayout && y >= this.hoverConsoleTop() - 8) {
        return true
      }
      if (x >= 16 && x <= 16 + 280 && y >= 50 && y <= 50 + 44) {
        return true
      }
      if (this.isCompactTopQuickPoint(x, y)) {
        return true
      }
      if (this.isCompactMorePoint(x, y)) {
        return true
      }
    }
    if (isObjectDetailCardPoint(x, y, this.objectDetailStore.isObjectDetailCardRendered(this.infoWindowStore.infoWinVisible), this.detailCardX(), this.detailCardY(), this.detailCardWidth(), this.detailCardHeight()) || this.isObjectActionBarPoint(x, y)) {
      return true
    }
    if (this.isExpandedLayout) {
      // 浮动面板区域（含 30vp 余量，覆盖圆角/边距，杜绝点面板却拖星图）
      if (this.panelVisible) {
        const pl = panelLeft(this.isExpandedLayout, this.skyWidth, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN)
        const pr = panelRight(this.isExpandedLayout, this.skyWidth, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN)
        const pt = panelTop(this.EDGE_MARGIN, this.panelOffsetY)
        if (x >= pl - 30 && x <= pr + 30 && y >= pt - 30 && y <= pt + this.panelMaxHeight + 30) {
          return true
        }
      }
      return false
    }
    if (this.panelVisible) {
      const panelW = this.isFoldHoverLayout ? this.skyWidth * 0.72 : this.skyWidth * 0.94
      const panelX = (this.skyWidth - panelW) / 2
      const panelBottom = this.skyHeight - 90
      const panelY = panelBottom - this.compactPanelHeight()
      if (x >= panelX - 12 && x <= panelX + panelW + 12 && y >= panelY - 18 && y <= panelBottom + 10) {
        return true
      }
    }
    if (this.isCompactTopQuickPoint(x, y)) {
      return true
    }
    return y >= this.skyHeight - 80
  }

  private handleUiTap(x: number, y: number): boolean {
    // 防闪退保护：确保所有数组和状态变量有效
    try {
	    if (typeof x !== 'number' || typeof y !== 'number' || isNaN(x) || isNaN(y)) { return false }
	    if (this.handleCompactTopQuickTap(x, y)) { return true }
    const dockItem = this.dockActionAt(x, y)
    if (dockItem !== null) {
      this.activateDockAction(dockItem)
      return true
    }
    if (this.polarScopeStore.polarScopeVisible) {
      const headerTop = this.polarScopeTopInset()
      const right = (this.skyWidth + this.polarScopeControlWidth()) / 2 - 6
      if (y >= headerTop + 6 && y <= headerTop + 54) {
        if (x >= right - 48 && x <= right) {
          this.closePolarScope()
          return true
        }
        if (x >= right - 104 && x <= right - 56) {
          this.recenterPolarScope()
          return true
        }
      }
    }
	    // 顶部搜索栏已移除，搜索功能通过左侧图标进入分类面板
    // 浮动详情窗优先处理（其区域内已由 isUiPoint 拦截，不会落到星图选星）
      if (this.isExpandedLayout && this.handleExpandedDetailSummaryTap(x, y)) { return true }
      if ((!this.panelVisible || !useExpandedDetailSummary()) && this.handleInfoWinTap(x, y)) { return true }

    if (!this.panelVisible) {
		      return false
		    }

    const left = panelLeft(this.isExpandedLayout, this.skyWidth, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN)
    const top = panelTop(this.EDGE_MARGIN, this.panelOffsetY)
    const right = panelRight(this.isExpandedLayout, this.skyWidth, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN)
    if (isPanelBackPoint(x, y, this.canGoBackPanel(), this.isExpandedLayout, this.isFoldHoverLayout, this.panelWidth, this.skyWidth, this.skyHeight, this.compactPanelHeight(), this.panelOffsetX, this.panelOffsetY, this.EDGE_MARGIN)) {
      this.handlePanelBackTap()
      return true
    }
    if (x >= right - 60 && x <= right && y >= top && y <= top + 60) {
      if (!this.viewSettingsStore.uiLocked) {
        this.closePanel(true)
      }
      return true
    }

    if (x < left || x > right || y < top || y > top + 900) {
      return false
    }
    this.resetPanelIdle()

    // Layer toggles are handled by Toggle.onChange in the LayerSwitchRow component
    // Hardcoded coordinates removed - layout changed with grouped sections

    if (this.activePanel === 'search') {
      if (y >= 505 && y <= 562) {
        if (x >= 1095 && x < 1165) { this.searchObject('Moon'); return true }
        if (x >= 1165 && x < 1230) { this.searchObject('Mars'); return true }
        if (x >= 1230 && x <= 1345) { this.searchObject('Jupiter'); return true }
      }
    } else if (this.activePanel === 'time') {
      if (y >= 545 && y <= 595) {
        // 循环升档按钮：倒带 | 停止 | 实时 | 减速 | 快进（快进/倒带可连点升档）
        if (x >= 1040 && x < 1110) { this.handleChip('rewind'); return true }
        if (x >= 1110 && x < 1180) { this.handleChip('stop'); return true }
        if (x >= 1180 && x < 1250) { this.handleChip('realtime'); return true }
        if (x >= 1250 && x < 1320) { this.handleChip('slower'); return true }
        if (x >= 1320 && x <= 1400) { this.handleChip('fast'); return true }
      }
      if (y >= 610 && y <= 660) {
        if (x >= 1095 && x < 1220) { this.advanceTime(12); return true }
        if (x >= 1220 && x <= 1345) { this.advanceTime(-12); return true }
      }
    } else if (this.activePanel === 'object') {
      if (y >= 560 && y <= 615) {
        if (x >= 1095 && x < 1160) { this.refreshSelectedObject(); this.refreshState(); return true }
        if (x >= 1160 && x < 1225) { this.moveToSelectedObject(); return true }
        if (x >= 1225 && x <= 1310) { this.callInteractive('setTracking', '0', () => { this.refreshState() }); return true }
      }
      if (!OFFLINE_APPGALLERY_BUILD && y >= 630 && y <= 690) {
        if (x >= 1095 && x < 1175) { this.lx200GotoSelected(); return true }
        if (x >= 1175 && x < 1245) { this.lx200SyncSelected(); return true }
        if (x >= 1245 && x <= 1320) { this.lx200Abort(); return true }
      }
    } else if (this.activePanel === 'place') {
      if (y >= 455 && y <= 505 && x >= 1300 && x <= right) { this.locationCtl().useDeviceLocation(); return true }
    }

    return true
    } catch (e) {
      hilog.error(0x0000, 'StellariumArkUI', 'handleUiTap crash: ' + (e instanceof Error ? e.message : String(e)))
      return false
    }
  }

  private handleOverlayTouch(event: TouchEvent): void {
    try {
    const points = event.touches.length > 0 ? event.touches : event.changedTouches
    if (points.length === 0) {
      return
    }
    const x = touchWindowX(points[0])
    const y = touchWindowY(points[0])
    // Do not rebuild the whole ArkUI shell for every Move event. Refresh the
    // chrome idle timers on gesture start/end, and at most twice per second
    // while a long drag is in progress.
    const activityNow = Date.now()
    if (event.type !== TouchType.Move || activityNow - this.lastOverlayActivityMs >= 500) {
      this.lastOverlayActivityMs = activityNow
      this.resetPanelIdle()
    }
    if (event.type === TouchType.Down) {
      this.touchStartedOnUi = this.isUiPoint(x, y)
      if (this.touchStartedOnUi) {
        this.skyTouchFeedback = false
        this.skyTouchActive = false
      }
      hilog.info(0x0000, 'StellariumArkUI', 'overlay touch down ' + Math.round(x).toString() + ',' + Math.round(y).toString() + ' ui=' + (this.touchStartedOnUi ? '1' : '0') + ' sky=' + this.skyWidth.toString() + 'x' + this.skyHeight.toString())
    }
    if (this.touchStartedOnUi) {
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.handleUiTap(x, y)
        this.touchStartedOnUi = false
      }
      return
    }
    this.skyInputCtl().handleSkyTouch(event)
    } catch (e) {
      hilog.error(0x0000, 'StellariumArkUI', 'handleOverlayTouch crash: ' + (e instanceof Error ? e.message : String(e)))
    }
  }

  private requestSkySelection(x: number, y: number): void {
    const requestSerial = ++this.skySelectionRequestSerial
    const payload = Math.round(x).toString() + '|' + Math.round(y).toString() + '|' +
      Math.round(this.skyWidth).toString() + '|' + Math.round(this.skyHeight).toString()
    this.callInteractive('selectAt', payload, (result) => {
      if (requestSerial !== this.skySelectionRequestSerial) {
        hilog.info(0x0000, 'StellariumArkUI', 'selectAt result ignored after newer selection gesture')
        return
      }
      hilog.info(0x0000, 'StellariumArkUI', 'selectAt result: ' + JSON.stringify(result))
      this.applySelectedObject(result, false, '', true)
      this.flashHint(result.found === true
        ? I18n.t('i0074').replace('%s', zhNameOf(this.objectDetailStore.selectedName))
        : I18n.t('i0075'))
    })
  }

  private clearSkySelectionFromDoubleTap(x: number, y: number): void {
    const requestSerial = ++this.skySelectionRequestSerial
    this.skyInputCtl().resetSkyTapSequence()
    this.stopDetailAutoRefresh()
    this.stopObjectDetailConnectorRefresh()
    this.applySelectedObject({ ok: true, found: false } as StellariumBridgeResponse)
    hilog.info(0x0000, 'StellariumArkUI', 'double tap cleared sky selection at ' +
      Math.round(x).toString() + ',' + Math.round(y).toString())
    this.flashHint(I18n.t('m_session_unselected'))
    this.callInteractive('clearSelection', '', (result) => {
      if (requestSerial !== this.skySelectionRequestSerial) { return }
      this.applySelectedObject(result)
    })
  }

  private centerSelectedObjectFromKeyboard(): void {
    const now = Date.now()
    if (now - this.lastCenterKeyAt < 220) { return }
    this.lastCenterKeyAt = now
    if (this.objectDetailStore.selectedStatus !== 'Selected' || this.objectDetailStore.selectedName.length === 0) {
      this.flashHint('请先选择天体')
      return
    }
    if (this.gyroStore.gyroscopeEnabled) {
      this.gyroCtl().updateGyroTargetGuide(true)
      return
    }
    this.navigateSelectedObjectTo(this.skyWidth / 2, this.skyHeight / 2, 'keyboard-center')
    this.flashHint('已居中')
  }




  build() {
    Stack() {
      // Language refresh anchor: reading i18nLang creates a reactive
      // dependency on AppStorage('i18nLang'). When language changes,
      // ArkUI re-executes build() and all I18n.t() calls re-evaluate.
      // Using a real (but invisible) element ensures the dependency is tracked.
      Text(this.i18nLang)
        .fontSize(0.1)
        .opacity(0)
        .width(0)
        .height(0)
        .zIndex(-1)
      XComponent({
        type: XComponentType.SURFACE,
        id: 'stellarium_entry_gl_probe',
        libraryname: 'entry'
      })
        .width('100%')
        .height('100%')
        .zIndex(0)
        .hitTestBehavior(HitTestMode.None)
        .onAppear(() => { this.onQtSurfaceAppear() })

      if (this.createInfo !== undefined && this.privacyNativeStartupAllowed) {
        XComponent({
          type: XComponentType.NODE,
          id: this.createInfo.xComponentId,
          libraryname: 'qohos'
        })
          .onAttach(() => { this.onQtNativeNodeAttach() })
          .onAppear(() => { this.onQtNativeNodeAppear() })
          .onDisAppear(() => { this.onQtNativeNodeDisappear() })
          .width('100%')
          .height('100%')
          .zIndex(-1)
          .opacity(0.01)
          .backgroundColor(Color.Transparent)
          .hitTestBehavior(HitTestMode.None)
          .enabled(false)
      }

      if (this.skyTouchFeedback) {
        Row()
          .width(120)
          .height(120)
          .borderRadius(60)
          .backgroundColor(this.nightModeStore.nightMode ? 'rgba(180, 40, 20, 0.15)' : 'rgba(107, 163, 214, 0.12)')
          .border({ width: 1, color: 'rgba(107, 163, 214, 0.10)' })
          .shadow({ radius: 42, color: 'rgba(107, 163, 214, 0.18)', offsetX: 0, offsetY: 0 })
          .align(Alignment.Center)
          .offset({ x: this.skyTouchX - this.skyWidth / 2, y: this.skyTouchY - this.skyHeight / 2 })
          .hitTestBehavior(HitTestMode.None)
          .zIndex(0)
          .animation({ duration: 0, curve: Curve.Linear })
      }
      if (this.skyTouchFeedbackMulti) {
        Row()
          .width(120)
          .height(120)
          .borderRadius(60)
          .backgroundColor(this.nightModeStore.nightMode ? 'rgba(180, 40, 20, 0.15)' : 'rgba(107, 163, 214, 0.12)')
          .border({ width: 1, color: 'rgba(107, 163, 214, 0.10)' })
          .shadow({ radius: 42, color: 'rgba(107, 163, 214, 0.18)', offsetX: 0, offsetY: 0 })
          .align(Alignment.Center)
          .offset({ x: this.skyTouchX2 - this.skyWidth / 2, y: this.skyTouchY2 - this.skyHeight / 2 })
          .hitTestBehavior(HitTestMode.None)
          .zIndex(0)
          .animation({ duration: 0, curve: Curve.Linear })
      }

        // 画布触摸层：与 toolbar/panel 平级（都是 1234 根 Stack 的子），
      // 承接 selectAt/onTouch。关键：不能挂在 1352 全屏 UI 父上，
      // 否则会抑制其子组件（toolbar/面板按钮）的 onClick。
      // 参考已验证的 compactShell：onTouch 挂在独立 Blank 上而非全屏 UI 父。
      Stack() { }
        .width('100%')
        .height('100%')
        // 星图触摸由各布局内部的专属触摸面处理，禁止全屏层穿透 UI。
        .hitTestBehavior(HitTestMode.None)
        .onTouch((event: TouchEvent) => {
          this.handleOverlayTouch(event)
        })

      if (this.scriptStore.scriptPlaybackVisible(this.guideStore.guideState.active)) {
        if (this.guideStore.guideState.active) {
          InteractiveGuideShell({
            guidePhase: this.guideStore.guideState.phase,
            guideIndex: this.guideStore.guideState.index,
            guideCount: this.guideStore.guideState.count,
            guideAutomatic: this.guideStore.guideState.automatic,
            guideRemaining: this.guideStore.guideState.remaining,
            guideTitle: I18n.t(this.currentGuide().title),
            guideCredit: I18n.t(this.currentGuide().credit),
            guideStepTitle: planetZh(this.currentGuideStep().title),
            guideStepText: this.currentGuideStep().text,
            guideStepKey: this.currentGuideStep().target,
            cardWidth: this.guideCardWidth(),
            cardHeight: guideCardHeight(this.skyHeight, this.scriptControlSafeTop()),
            cardX: guideCardX(this.isExpandedLayout, this.skyWidth, this.guideCardWidth(), this.scriptStore.scriptControlOffsetX),
            cardY: guideCardY(this.skyHeight, guideCardHeight(this.skyHeight, this.scriptControlSafeTop()), this.scriptControlSafeTop(), this.scriptStore.scriptControlOffsetY),
            onSkyTouch: (event: TouchEvent) => { this.skyInputCtl().handleSkyTouch(event) },
            onControlDragTouch: (event: TouchEvent) => { this.handleScriptControlDragTouch(event) },
            onAction: (action: string) => { this.guideStore.executeGuideRequest('guideAction', action) }
          })
        } else {
          ScriptFocusShell({
            scriptStore: this.scriptStore,
            playbackVisible: this.scriptStore.scriptPlaybackVisible(this.guideStore.guideState.active),
            compact: this.scriptStore.scriptControlCompact(this.skyWidth),
            displayName: scriptZh(this.scriptStore.scriptId.length > 0 ? this.scriptStore.scriptId : (this.scriptStore.scriptLaunchingName.length > 0 ? this.scriptStore.scriptLaunchingName : this.scriptStore.replayName)),
            hasCaptions: this.scriptStore.visibleScriptCaptions().length > 0,
            captionText: this.scriptStore.visibleScriptCaptionText(),
            waitText: this.scriptStore.scriptWaitDisplayText(),
            rateText: (this.scriptStore.replaying ? this.scriptStore.replayRate : this.scriptStore.scriptRate).toFixed((this.scriptStore.replaying ? this.scriptStore.replayRate : this.scriptStore.scriptRate) < 1 ? 2 : 1) + 'x',
            keyButtonWidth: this.scriptStore.scriptKeyButtonWidth(this.skyWidth),
            controlWidth: scriptControlWidth(this.skyWidth, this.scriptStore.replaying),
            controlHeight: this.scriptStore.scriptControlHeight(),
            controlX: scriptControlX(this.skyWidth, this.scriptStore.replaying, this.scriptStore.scriptControlOffsetX),
            controlY: scriptControlY(this.skyHeight, this.scriptControlSafeTop(), this.scriptStore.scriptControlHeight(), this.scriptStore.scriptControlOffsetY),
            onSkyTouch: (event: TouchEvent) => { this.skyInputCtl().handleSkyTouch(event) },
            onControlDragTouch: (event: TouchEvent) => { this.handleScriptControlDragTouch(event) },
            onContinue: () => { this.scriptStore.continueNativeScript() },
            onChangeRate: (delta: number) => { this.recordingCtl().changePlaybackRate(delta) },
            onToggleReplayPause: () => { this.recordingCtl().toggleReplayPause() },
            onStop: () => { this.scriptStore.stopScriptPlayback() },
            onSendKey: (k: string) => { this.scriptStore.sendScriptKey(k) }
          })
        }
      }
      if (!this.scriptStore.scriptPlaybackVisible(this.guideStore.guideState.active) && this.tools.recording && !this.tools.recordingUiExpanded) {
        RecordingFocusShell({ onSkyTouch: (event: TouchEvent) => { this.skyInputCtl().handleSkyTouch(event) } })
      }
      if (!this.scriptStore.scriptPlaybackVisible(this.guideStore.guideState.active) && !(this.tools.recording && !this.tools.recordingUiExpanded) && !this.polarScopeStore.polarScopeVisible) {
        Stack() {
          if (this.isFoldHoverLayout) {
            Stack() {
              HoverObservatoryShell({
                objectDetailStore: this.objectDetailStore,
                objectMediaStore: this.objectMediaStore,
                overlayStore: this.overlayStore,
                observationTimeText: this.timeStore.observationTimeText,
                currentFovText: this.currentFovText,
                skyWidth: this.skyWidth,
                skyHeight: this.skyHeight,
                hoverSkyPaneHeight: this.hoverSkyPaneHeight(),
                panelIdleGlass: this.panelIdleGlass,
                panelVisible: this.panelVisible,
                isExpandedLayout: this.isExpandedLayout,
                activePanel: this.activePanel,
                languageRevision: this.languageStore.languageRevision,
                actions: this.canonicalDockActions(),
                chromeOpacity: this.phoneChromeOpacity(),
                chromeIsGlass: this.phoneChromeIsGlass(),
                dockWidthPercent: this.compactDockWidthPercent(),
                dockIconSize: this.compactDockIconSize(),
                dockLabelFontSize: this.compactDockLabelFontSize(),
                dockItemHeight: this.compactDockItemHeight(),
                infoWinVisible: this.infoWindowStore.infoWinVisible,
                bottomCardIndex: this.objectDetailStore.bottomCardIndex,
                liveInfoVisible: this.infoWindowStore.selectedLiveInfoVisible(),
                contentOpacity: this.objectDetailContentOpacity,
                contentTranslateX: this.objectDetailContentTranslateX,
                cardWidth: this.bottomCardWidth(),
                cardHeight: this.bottomCardHeight(),
                viewLock: this.viewSettingsStore.viewLock,
                speechStatus: this.guideStore.speechStatus,
                inObservingList: this.obsListStore.observingList.includes(this.objectDetailStore.selectedName),
                iconName: this.objectDetailStore.objectInspectorIcon(),
                distanceText: this.objectDetailStore.objectDistanceNoticeText(this.infoWindowStore.distanceInformationVisible()),
                distanceSummaryText: this.objectDetailStore.objectDistanceSummary(this.infoWindowStore.distanceInformationVisible()),
                imageHeight: this.objectMediaStore.objectInspectorImageHeight(),
                inlineModelSize: this.objectInspectorInlineModelSize(),
                modelReady: this.objectModelRendererCtl().modelReady(),
                modelRendering: this.objectModelRendererCtl().isRendering(),
                hasModelTexture: this.objectModelRendererCtl().hasTexture(),
                modelNotice: this.objectMediaStore.objectInspectorModelNotice(),
                warmupText: this.objectMediaStore.objectInspectorMediaWarmupText(),
                fallbackKind: objectInspectorFallbackVisualKind(this.objectDetailStore.selectedObjectType, this.objectDetailStore.selectedType),
                starColor: objectInspectorStarColor(this.objectDetailStore.selectedTemperatureK),
                satelliteVisible: this.objectDetailStore.selectedObjectIsArtificialSatellite(),
                tleEpoch: this.objectDetailStore.selectedSatelliteTleEpoch(),
                accent: this.nightModeStore.nmAccent(),
                cultureVisible: this.objectDetailStore.selectedObjectIsConstellation(),
                textColor: this.nightModeStore.nmText(),
                connectorVisible: this.overlayStore.objectDetailConnectorVisible,
                connectorLength: this.objectDetailConnectorLength,
                connectorX: this.objectDetailConnectorX,
                connectorY: this.objectDetailConnectorY,
                connectorAngle: this.objectDetailConnectorAngle,
                connectorAnimateGeometry: this.objectDetailConnectorAnimateGeometry,
                connectorTargetOnScreen: this.objectDetailConnectorTargetOnScreen,
                connectorTargetX: this.objectDetailConnectorTargetX,
                connectorTargetY: this.objectDetailConnectorTargetY,
                connectorEndX: this.objectDetailConnectorEndX,
                connectorEndY: this.objectDetailConnectorEndY,
                markerSize: this.objectDetailMarkerSize(),
                detailX: this.detailCardX(),
                detailY: this.detailCardY(),
                detailWidth: this.detailCardWidth(),
                detailHeight: this.detailCardHeight(),
                scroller: this.objectDetailScroller,
                onSkyTouch: (event: TouchEvent) => { this.skyInputCtl().handleSkyTouch(event) },
                onDockTouch: (event: TouchEvent) => { this.handleDockTouch(event) },
                onDockTap: (item: ShellAction) => { this.activateDockAction(item) },
                onPanelTouch: (event: TouchEvent) => { this.notePanelTouch(event) },
                resolve: (key: string) => this.selectedDisplayValue(key),
                nameOf: (name: string) => zhNameOf(name),
                typeOf: (type: string) => zhType(type),
                onDragTouch: (event: TouchEvent) => { this.handleObjectInspectorDragTouch(event) },
                onDismiss: () => { this.dismissObjectInspector() },
                onSelectTab: (index: number) => { this.selectObjectDetailTab(index) },
                onLoadPasses: () => { this.objectDetailStore.loadSelectedSatellitePasses() },
                onMediaOpen: () => { this.openObjectInspectorMediaPreview() },
                onMediaRetry: () => { this.retryObjectInspectorMedia() },
                onModelExpand: () => { this.objectModelRendererCtl().setObjectInspectorModelImmersive(true) },
                onModelTouch: (event: TouchEvent) => { this.objectModelRendererCtl().handleObjectInspectorModelTouch(event) },
                onCenter: () => { this.moveToSelectedObject() },
                onToggleLock: () => { this.toggleViewLock() },
                onToggleObserving: () => { this.toggleSelectedObservingList() },
                onRefresh: () => { this.refreshSelectedObject(); this.refreshState() },
                onReselect: () => { this.triggerAction('actionGoto_ReSelect_Last_Selected_Object'); this.refreshSelectedObject() },
                onSpeak: () => { speakSelectedObject(this.commandPort(), { flashHint: (text: ResourceStr): void => this.flashHint(text), setSpeechStatus: (text: string): void => { this.guideStore.speechStatus = text } }) }
              })
              if (this.panelVisible) {
                Stack() { this.compactPanel() }
                  .position({ x: 0, y: this.hoverPanelTop() })
                  .width('100%')
                  .hitTestBehavior(HitTestMode.Default)
                  .zIndex(30)
              }
            }
              .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut })
                .combine(TransitionEffect.scale({ x: 0.985, y: 0.985 }).animation({ duration: 220, curve: curves.springMotion(0.55, 0.88) })))
          } else if (this.isExpandedLayout) {
            Stack() {
              ExpandedShell({
                objectDetailStore: this.objectDetailStore,
                objectMediaStore: this.objectMediaStore,
                overlayStore: this.overlayStore,
                gyroStore: this.gyroStore,
                expandedUiAllowed: this.expandedUiAllowed(),
                panelVisible: this.panelVisible,
                isExpandedLayout: this.isExpandedLayout,
                activePanel: this.activePanel,
                languageRevision: this.languageStore.languageRevision,
                actions: this.canonicalDockActions(),
                chromeOpacity: this.phoneChromeOpacity(),
                chromeIsGlass: this.phoneChromeIsGlass(),
                dockWidthPercent: this.compactDockWidthPercent(),
                dockIconSize: this.compactDockIconSize(),
                dockLabelFontSize: this.compactDockLabelFontSize(),
                dockItemHeight: this.compactDockItemHeight(),
                skyHeight: this.skyHeight,
                polarScopeVisible: this.polarScopeStore.polarScopeVisible,
                dockClockText: this.dockClockText,
                dockWidth: dockWidthPixels(this.isExpandedLayout, this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN, this.compactDockWidthPercent()),
                dockLeft: dockLeft(this.isExpandedLayout, this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN, this.compactDockWidthPercent()),
                dockTop: this.dockTop(),
                expandedDockWidth: expandedDockWidth(this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN),
                expandedDockLeft: expandedDockLeft(this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN),
                gyroPanelLeft: this.EDGE_MARGIN + 64,
                gyroPanelTop: railTop(this.EDGE_MARGIN) + 120,
                infoWinVisible: this.infoWindowStore.infoWinVisible,
                bottomCardIndex: this.objectDetailStore.bottomCardIndex,
                liveInfoVisible: this.infoWindowStore.selectedLiveInfoVisible(),
                contentOpacity: this.objectDetailContentOpacity,
                contentTranslateX: this.objectDetailContentTranslateX,
                cardWidth: this.bottomCardWidth(),
                cardHeight: this.bottomCardHeight(),
                viewLock: this.viewSettingsStore.viewLock,
                speechStatus: this.guideStore.speechStatus,
                inObservingList: this.obsListStore.observingList.includes(this.objectDetailStore.selectedName),
                iconName: this.objectDetailStore.objectInspectorIcon(),
                distanceText: this.objectDetailStore.objectDistanceNoticeText(this.infoWindowStore.distanceInformationVisible()),
                distanceSummaryText: this.objectDetailStore.objectDistanceSummary(this.infoWindowStore.distanceInformationVisible()),
                imageHeight: this.objectMediaStore.objectInspectorImageHeight(),
                inlineModelSize: this.objectInspectorInlineModelSize(),
                modelReady: this.objectModelRendererCtl().modelReady(),
                modelRendering: this.objectModelRendererCtl().isRendering(),
                hasModelTexture: this.objectModelRendererCtl().hasTexture(),
                modelNotice: this.objectMediaStore.objectInspectorModelNotice(),
                warmupText: this.objectMediaStore.objectInspectorMediaWarmupText(),
                fallbackKind: objectInspectorFallbackVisualKind(this.objectDetailStore.selectedObjectType, this.objectDetailStore.selectedType),
                starColor: objectInspectorStarColor(this.objectDetailStore.selectedTemperatureK),
                satelliteVisible: this.objectDetailStore.selectedObjectIsArtificialSatellite(),
                tleEpoch: this.objectDetailStore.selectedSatelliteTleEpoch(),
                accent: this.nightModeStore.nmAccent(),
                cultureVisible: this.objectDetailStore.selectedObjectIsConstellation(),
                textColor: this.nightModeStore.nmText(),
                connectorVisible: this.overlayStore.objectDetailConnectorVisible,
                connectorLength: this.objectDetailConnectorLength,
                connectorX: this.objectDetailConnectorX,
                connectorY: this.objectDetailConnectorY,
                connectorAngle: this.objectDetailConnectorAngle,
                connectorAnimateGeometry: this.objectDetailConnectorAnimateGeometry,
                connectorTargetOnScreen: this.objectDetailConnectorTargetOnScreen,
                connectorTargetX: this.objectDetailConnectorTargetX,
                connectorTargetY: this.objectDetailConnectorTargetY,
                connectorEndX: this.objectDetailConnectorEndX,
                connectorEndY: this.objectDetailConnectorEndY,
                markerSize: this.objectDetailMarkerSize(),
                detailX: this.detailCardX(),
                detailY: this.detailCardY(),
                detailWidth: this.detailCardWidth(),
                detailHeight: this.detailCardHeight(),
                scroller: this.objectDetailScroller,
                onSkyTouch: (event: TouchEvent) => { this.skyInputCtl().handleSkyTouch(event) },
                onDockTouch: (event: TouchEvent) => { this.handleDockTouch(event) },
                onDockTap: (item: ShellAction) => { this.activateDockAction(item) },
                onPanelTouch: (event: TouchEvent) => { this.notePanelTouch(event) },
                onOpenTime: () => { this.setPanel('time') },
                onZoomIn: () => { this.zoomStep(0.8) },
                onZoomOut: () => { this.zoomStep(1.25) },
                fovText: this.currentFovText,
                chromeRowY: this.chromeRowY(),
                chromeRowWidth: dockWidthPixels(this.isExpandedLayout, this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN, this.compactDockWidthPercent()),
                chromeRowPosXLeft: chromeRowPosXLeft(this.isExpandedLayout, this.EDGE_MARGIN, this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.compactDockWidthPercent()),
                chromeRowPosXRight: chromeRowPosXRight(this.isExpandedLayout, this.skyWidth, this.EDGE_MARGIN, this.panelVisible, this.panelWidth, this.panelOffsetX, this.compactDockWidthPercent()),
                chromeZoomHorizontal: this.chromeZoomHorizontal(),
                onFlashHint: (text: string) => { this.flashHint(text) },
                onCalibrate: () => { this.gyroCtl().calibrateGyroscope() },
                onToggleGyroscope: (enabled: boolean) => { this.gyroCtl().toggleGyroscope(enabled) },
                resolve: (key: string) => this.selectedDisplayValue(key),
                nameOf: (name: string) => zhNameOf(name),
                typeOf: (type: string) => zhType(type),
                onDragTouch: (event: TouchEvent) => { this.handleObjectInspectorDragTouch(event) },
                onDismiss: () => { this.dismissObjectInspector() },
                onSelectTab: (index: number) => { this.selectObjectDetailTab(index) },
                onLoadPasses: () => { this.objectDetailStore.loadSelectedSatellitePasses() },
                onMediaOpen: () => { this.openObjectInspectorMediaPreview() },
                onMediaRetry: () => { this.retryObjectInspectorMedia() },
                onModelExpand: () => { this.objectModelRendererCtl().setObjectInspectorModelImmersive(true) },
                onModelTouch: (event: TouchEvent) => { this.objectModelRendererCtl().handleObjectInspectorModelTouch(event) },
                onCenter: () => { this.moveToSelectedObject() },
                onToggleLock: () => { this.toggleViewLock() },
                onToggleObserving: () => { this.toggleSelectedObservingList() },
                onRefresh: () => { this.refreshSelectedObject(); this.refreshState() },
                onReselect: () => { this.triggerAction('actionGoto_ReSelect_Last_Selected_Object'); this.refreshSelectedObject() },
                onSpeak: () => { speakSelectedObject(this.commandPort(), { flashHint: (text: ResourceStr): void => this.flashHint(text), setSpeechStatus: (text: string): void => { this.guideStore.speechStatus = text } }) }
              })
              if (this.panelVisible) {
                Stack({ alignContent: Alignment.TopStart }) { this.floatingPanel() }
                  .width(this.panelWidth)
                  .height(this.panelMaxHeight)
                  .position({ x: expandedMainPanelLeft(this.EDGE_MARGIN, this.panelOffsetX), y: panelTop(this.EDGE_MARGIN, this.panelOffsetY) })
                  // Default keeps the panel above the sibling sky surface while still
                  // letting its deepest child (Button, Slider, Scroll, TextInput) own
                  // the gesture. Block would stop those controls at this outer shell.
                  .hitTestBehavior(HitTestMode.Default)
                  .zIndex(30)
              }
            }
              .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut })
                .combine(TransitionEffect.scale({ x: 1.015, y: 1.015 }).animation({ duration: 220, curve: curves.springMotion(0.55, 0.88) })))
          } else {
            // 手机/折叠半折壳已组件化（CompactShell）；面板仍是宿主薄 @Builder（compactPanel），
            // 无法跨组件调用（§13.1 规则 9），故在同一过渡包裹内由宿主渲染。
            Stack() {
              CompactShell({
                objectDetailStore: this.objectDetailStore,
                objectMediaStore: this.objectMediaStore,
                overlayStore: this.overlayStore,
                gyroStore: this.gyroStore,
                skyHeight: this.skyHeight,
                panelVisible: this.panelVisible,
                isExpandedLayout: this.isExpandedLayout,
                polarScopeVisible: this.polarScopeStore.polarScopeVisible,
                activePanel: this.activePanel,
                languageRevision: this.languageStore.languageRevision,
                actions: this.canonicalDockActions(),
                chromeOpacity: this.phoneChromeOpacity(),
                chromeIsGlass: this.phoneChromeIsGlass(),
                dockWidthPercent: this.compactDockWidthPercent(),
                dockIconSize: this.compactDockIconSize(),
                dockLabelFontSize: this.compactDockLabelFontSize(),
                dockItemHeight: this.compactDockItemHeight(),
                dockClockText: this.dockClockText,
                dockWidth: dockWidthPixels(this.isExpandedLayout, this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN, this.compactDockWidthPercent()),
                dockLeft: dockLeft(this.isExpandedLayout, this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN, this.compactDockWidthPercent()),
                dockTop: this.dockTop(),
                musicEnabled: this.audioStore.musicEnabled,
                compactQuickPressed: this.compactQuickPressed,
                quickX: this.compactTopQuickX(),
                quickY: compactTopQuickY(),
                infoWinVisible: this.infoWindowStore.infoWinVisible,
                bottomCardIndex: this.objectDetailStore.bottomCardIndex,
                liveInfoVisible: this.infoWindowStore.selectedLiveInfoVisible(),
                contentOpacity: this.objectDetailContentOpacity,
                contentTranslateX: this.objectDetailContentTranslateX,
                cardWidth: this.bottomCardWidth(),
                cardHeight: this.bottomCardHeight(),
                viewLock: this.viewSettingsStore.viewLock,
                speechStatus: this.guideStore.speechStatus,
                inObservingList: this.obsListStore.observingList.includes(this.objectDetailStore.selectedName),
                iconName: this.objectDetailStore.objectInspectorIcon(),
                distanceText: this.objectDetailStore.objectDistanceNoticeText(this.infoWindowStore.distanceInformationVisible()),
                distanceSummaryText: this.objectDetailStore.objectDistanceSummary(this.infoWindowStore.distanceInformationVisible()),
                imageHeight: this.objectMediaStore.objectInspectorImageHeight(),
                inlineModelSize: this.objectInspectorInlineModelSize(),
                modelReady: this.objectModelRendererCtl().modelReady(),
                modelRendering: this.objectModelRendererCtl().isRendering(),
                hasModelTexture: this.objectModelRendererCtl().hasTexture(),
                modelNotice: this.objectMediaStore.objectInspectorModelNotice(),
                warmupText: this.objectMediaStore.objectInspectorMediaWarmupText(),
                fallbackKind: objectInspectorFallbackVisualKind(this.objectDetailStore.selectedObjectType, this.objectDetailStore.selectedType),
                starColor: objectInspectorStarColor(this.objectDetailStore.selectedTemperatureK),
                satelliteVisible: this.objectDetailStore.selectedObjectIsArtificialSatellite(),
                tleEpoch: this.objectDetailStore.selectedSatelliteTleEpoch(),
                accent: this.nightModeStore.nmAccent(),
                cultureVisible: this.objectDetailStore.selectedObjectIsConstellation(),
                textColor: this.nightModeStore.nmText(),
                connectorVisible: this.overlayStore.objectDetailConnectorVisible,
                connectorLength: this.objectDetailConnectorLength,
                connectorX: this.objectDetailConnectorX,
                connectorY: this.objectDetailConnectorY,
                connectorAngle: this.objectDetailConnectorAngle,
                connectorAnimateGeometry: this.objectDetailConnectorAnimateGeometry,
                connectorTargetOnScreen: this.objectDetailConnectorTargetOnScreen,
                connectorTargetX: this.objectDetailConnectorTargetX,
                connectorTargetY: this.objectDetailConnectorTargetY,
                connectorEndX: this.objectDetailConnectorEndX,
                connectorEndY: this.objectDetailConnectorEndY,
                markerSize: this.objectDetailMarkerSize(),
                detailX: this.detailCardX(),
                detailY: this.detailCardY(),
                detailWidth: this.detailCardWidth(),
                detailHeight: this.detailCardHeight(),
                scroller: this.objectDetailScroller,
                onSkyTouch: (event: TouchEvent) => { this.skyInputCtl().handleSkyTouch(event) },
                onDockTouch: (event: TouchEvent) => { this.handleDockTouch(event) },
                onDockTap: (item: ShellAction) => { this.activateDockAction(item) },
                onPanelTouch: (event: TouchEvent) => { this.notePanelTouch(event) },
                onOpenTime: () => { this.setPanel('time') },
                onZoomIn: () => { this.zoomStep(0.8) },
                onZoomOut: () => { this.zoomStep(1.25) },
                fovText: this.currentFovText,
                chromeRowY: this.chromeRowY(),
                chromeRowWidth: dockWidthPixels(this.isExpandedLayout, this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN, this.compactDockWidthPercent()),
                chromeRowPosXLeft: chromeRowPosXLeft(this.isExpandedLayout, this.EDGE_MARGIN, this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.compactDockWidthPercent()),
                chromeRowPosXRight: chromeRowPosXRight(this.isExpandedLayout, this.skyWidth, this.EDGE_MARGIN, this.panelVisible, this.panelWidth, this.panelOffsetX, this.compactDockWidthPercent()),
                chromeZoomHorizontal: this.chromeZoomHorizontal(),
                onGyro: () => {
                  hilog.info(0x0000, 'StellariumArkUI', '[DIAG] gyro button CLICKED gyroscopeEnabled=%{public}s', this.gyroStore.gyroscopeEnabled.toString())
                  this.resetPanelIdle()
                  this.gyroCtl().toggleGyroscope(!this.gyroStore.gyroscopeEnabled)
                },
                onAudio: () => {
                  hilog.info(0x0000, 'StellariumArkUI', '[DIAG] audio button CLICKED musicEnabled=%{public}s', this.audioStore.musicEnabled.toString())
                  this.resetPanelIdle()
                  this.toggleMusic()
                  this.flashHint(this.audioStore.musicEnabled ? I18n.t('music_on_hint') : I18n.t('music_off_hint'))
                },
                onCompactTopQuickTouch: (event: TouchEvent) => { this.handleCompactTopQuickTouch(event) },
                onFlashHint: (text: string) => { this.flashHint(text) },
                onCalibrate: () => { this.gyroCtl().calibrateGyroscope() },
                onToggleGyroscope: (enabled: boolean) => { this.gyroCtl().toggleGyroscope(enabled) },
                resolve: (key: string) => this.selectedDisplayValue(key),
                nameOf: (name: string) => zhNameOf(name),
                typeOf: (type: string) => zhType(type),
                onDragTouch: (event: TouchEvent) => { this.handleObjectInspectorDragTouch(event) },
                onDismiss: () => { this.dismissObjectInspector() },
                onSelectTab: (index: number) => { this.selectObjectDetailTab(index) },
                onLoadPasses: () => { this.objectDetailStore.loadSelectedSatellitePasses() },
                onMediaOpen: () => { this.openObjectInspectorMediaPreview() },
                onMediaRetry: () => { this.retryObjectInspectorMedia() },
                onModelExpand: () => { this.objectModelRendererCtl().setObjectInspectorModelImmersive(true) },
                onModelTouch: (event: TouchEvent) => { this.objectModelRendererCtl().handleObjectInspectorModelTouch(event) },
                onCenter: () => { this.moveToSelectedObject() },
                onToggleLock: () => { this.toggleViewLock() },
                onToggleObserving: () => { this.toggleSelectedObservingList() },
                onRefresh: () => { this.refreshSelectedObject(); this.refreshState() },
                onReselect: () => { this.triggerAction('actionGoto_ReSelect_Last_Selected_Object'); this.refreshSelectedObject() },
                onSpeak: () => { speakSelectedObject(this.commandPort(), { flashHint: (text: ResourceStr): void => this.flashHint(text), setSpeechStatus: (text: string): void => { this.guideStore.speechStatus = text } }) }
              })
              if (this.panelVisible) {
                Stack({ alignContent: Alignment.Bottom }) {
                  this.compactPanel()
                }
                  .width('100%')
                  .height(this.compactPanelHeight() + 10)
                  .position({ x: 0, y: this.skyHeight - 90 - this.compactPanelHeight() })
                  .hitTestBehavior(HitTestMode.Transparent)
                  .zIndex(30)
              }
            }
              .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut })
                .combine(TransitionEffect.scale({ x: 0.985, y: 0.985 }).animation({ duration: 220, curve: curves.springMotion(0.55, 0.88) })))
          }

          // Dock uses a dedicated top-level hit target. The expanded sky surface
          // intentionally blocks gestures, so relying on the visual Dock's child
          // handlers lets tablet touches be intercepted before they reach it.
          Stack() { }
            .width(dockWidthPixels(this.isExpandedLayout, this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN, this.compactDockWidthPercent()))
            .height(this.isExpandedLayout ? 62 : 82)
            .position({ x: dockLeft(this.isExpandedLayout, this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN, this.compactDockWidthPercent()), y: this.dockTop() })
            .hitTestBehavior(HitTestMode.Block)
            .zIndex(80)
            .onTouch((event: TouchEvent) => {
              this.handleDockTouch(event)
            })

          HarmonyShell({
            overlayStore: this.overlayStore,
            gyroStore: this.gyroStore,
            isExpandedLayout: this.isExpandedLayout,
            viewCoordinatesVisible: this.overlayStore.viewCoordinatesVisible,
            primaryText: this.viewCoordinatePrimaryText,
            secondaryText: this.viewCoordinateSecondaryText,
            overlayWidth: this.viewCoordinateOverlayWidth(),
            overlayLeft: this.viewCoordinateOverlayLeft(),
            overlayTop: this.viewCoordinateOverlayTop(),
            hintTop: (this.isExpandedLayout || this.isFoldHoverLayout) ? 16 : 58,
            actionHint: this.actionHint,
            onHandleViewCoordinateTouch: (event: TouchEvent) => { this.handleViewCoordinateTouch(event) }
          })
        }
          .width('100%')
          .height('100%')
          .zIndex(3)
          .hitTestBehavior(HitTestMode.Default)
      }
      if (!this.scriptStore.scriptPlaybackVisible(this.guideStore.guideState.active) && this.tools.recording) {
        RecordingControlBar({
          store: this.tools, recordCount: this.scriptStore.recordCount, skyWidth: this.skyWidth, safeTop: this.scriptControlSafeTop(),
          onToggleUi: () => { this.toggleRecordingUi() },
          onTogglePause: () => { this.recordingCtl().toggleRecordingPause() },
          onStop: () => { this.recordingCtl().stopRecording() }
        })
      }
      if (!this.scriptStore.scriptPlaybackVisible(this.guideStore.guideState.active) && (!this.tools.recording || this.tools.recordingUiExpanded)) {
        if (this.polarScopeStore.polarScopeVisible) {
          PolarScopeOverlay({
            polarScopeStore: this.polarScopeStore,
            controlWidth: this.polarScopeControlWidth(),
            topInset: this.polarScopeTopInset(),
            footerHeight: this.polarScopeFooterHeight(),
            skyWidth: this.skyWidth,
            skyHeight: this.skyHeight,
            isExpandedLayout: this.isExpandedLayout,
            onSkyTouch: (event: TouchEvent) => { this.skyInputCtl().handleSkyTouch(event) },
            onRecenter: () => { this.recenterPolarScope() },
            onClose: () => { this.closePolarScope() },
            onHorizontalFlipChange: (value: boolean) => { this.setPolarScopeHorizontalFlip(value) },
            onVerticalFlipChange: (value: boolean) => { this.setPolarScopeVerticalFlip(value) }
          })
        }
        if (this.skyCultureViewStore.artPreviewOpen) {
          SkyCultureArtPreviewOverlay({
            skyCultureViewStore: this.skyCultureViewStore,
            textColor: this.nightModeStore.nmText(),
            subColor: this.nightModeStore.nmSub(),
            accentColor: this.nightModeStore.nmAccent(),
            bgColor: this.nightModeStore.nmBg(),
            topInset: this.mediaPreviewTopInset(),
            closeSkyCultureArtPreview: () => { this.closeSkyCultureArtPreview() },
            onSkyCultureArtLoaded: () => { this.onSkyCultureArtLoaded() },
            onSkyCultureArtError: () => { this.onSkyCultureArtError() },
            onRetrySkyCultureArtPreview: () => { this.retrySkyCultureArtPreview() }
          })
        }
        if (this.objectMediaStore.objectInspectorMediaFullscreen) {
          ObjectInspectorMediaPreviewOverlay({
            objectMediaStore: this.objectMediaStore,
            titleText: zhNameOf(this.objectDetailStore.selectedName),
            topInset: this.mediaPreviewTopInset(),
            closeObjectInspectorMediaPreview: () => { this.closeObjectInspectorMediaPreview() },
            onObjectInspectorMediaPreviewLoaded: () => { this.onObjectInspectorMediaPreviewLoaded() },
            onObjectInspectorMediaPreviewError: () => { this.onObjectInspectorMediaPreviewError() },
            retryObjectInspectorMediaPreview: () => { this.retryObjectInspectorMediaPreview() }
          })
        }
        if (this.objectMediaStore.objectInspectorModelImmersive) {
          ObjectInspectorModelOverlay({
            objectMediaStore: this.objectMediaStore,
            titleText: this.objectDetailStore.selectedName,
            noticeText: this.objectMediaStore.objectInspectorModelNotice(),
            topInset: this.mediaPreviewTopInset(),
            onCloseOverlay: () => { this.objectModelRendererCtl().setObjectInspectorModelImmersive(false) },
            onResetView: () => { this.objectModelRendererCtl().resetObjectInspectorModelView() },
            onStageTouch: (event: TouchEvent) => { this.objectModelRendererCtl().handleObjectInspectorModelTouch(event) }
          })
        }
      }

      if (this.tools.skyTextureStatusVisible) {
        Row({ space: 8 }) {
          if (!this.tools.skyTextureStatusError) {
            LoadingProgress().width(16).height(16).color('#9EDCFA')
          }
          Text(this.tools.skyTextureStatusText)
            .fontSize(11).fontColor('#EDF9FF').maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.tools.skyTextureStatusError) {
            Button('重试')
              .height(28).fontSize(10).fontColor('#F4FBFF')
              .backgroundColor('rgba(255,255,255,0.12)').borderRadius(UI_RADIUS_PILL)
              .onClick(() => { this.retrySkyTextureStatus() })
          }
        }
          .height(38).padding({ left: 12, right: 10 })
          .backgroundColor(this.tools.skyTextureStatusError ? 'rgba(111,50,42,0.92)' : 'rgba(16,31,46,0.90)')
          .backdropBlur(18).borderRadius(UI_RADIUS_PILL)
          .position({ x: 16, y: (this.isExpandedLayout || this.isFoldHoverLayout) ? 58 : 98 })
          .constraintSize({ maxWidth: Math.max(220, this.skyWidth - 32) })
          .zIndex(92).hitTestBehavior(HitTestMode.Transparent)
          .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut }))
      }

      // Native night mode colors the Qt sky. These permanent, input-transparent
      // layers extend the same low-luminance red treatment to the ArkUI tree.
      Stack()
        .width('100%')
        .height('100%')
        .backgroundColor('#A00000')
        .blendMode(BlendMode.COLOR, BlendApplyType.OFFSCREEN)
        .opacity(this.nightModeStore.nightMode ? 0.78 : 0)
        .animation({ duration: 450, curve: Curve.EaseInOut })
        .hitTestBehavior(HitTestMode.Transparent)
        .zIndex(98)
      Stack()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(this.nightModeStore.nightMode ? 0.48 : 0)
        .animation({ duration: 450, curve: Curve.EaseInOut })
        .hitTestBehavior(HitTestMode.Transparent)
        .zIndex(99)
    }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
      .focusable(true)
      .defaultFocus(true)
      .onKeyEvent((event: KeyEvent): boolean => {
        return this.skyInputCtl().handleSkyKey(event)
      })
      .onMouse((event: MouseEvent) => {
        this.skyInputCtl().handleSkyMouse(event)
      })
      .onAxisEvent((event: AxisEvent) => {
        this.skyInputCtl().handleSkyAxis(event)
      })
      .onAreaChange((oldArea: Area, newArea: Area) => {
        // 布局硬回调：稳定触发。冷启动期 ArkUI setTimeout 重试不可靠，
        // 这里借 onAreaChange 反复尝试把启动命令送到 Qt 线程。
        this.startupBridge().startupBridgeSync()
        this.skyWidth = Number(newArea.width) > 1 ? Number(newArea.width) : 1
        this.skyHeight = Number(newArea.height) > 1 ? Number(newArea.height) : 1
        this.refreshFoldState('onAreaChange')
        this.updateResponsiveLayout('onAreaChange')
        if (this.polarScopeStore.polarScopeVisible) this.syncNativePolarScopeOverlay(true)
        if (this.isFoldTabletLayout) {
          this.panelWidth = Math.min(Math.max(this.skyWidth * 0.42, 300), 340)
          this.panelMaxHeight = Math.min(this.skyHeight * 0.70, 560)
        } else if (this.isExpandedLayout) {
          // Pad and 2-in-1 windows share the same panel. Extra-wide PC
          // canvases can use a little more room without covering the sky.
          const expandedPanelMax = this.skyWidth >= 1440 ? 480 : 420
          this.panelWidth = Math.min(Math.max(this.skyWidth * 0.33, 340), expandedPanelMax)
          this.panelMaxHeight = Math.max(this.skyHeight - this.EDGE_MARGIN * 2, 320)
        } else {
          this.panelWidth = Math.min(Math.max(this.skyWidth * 0.28, 280), 400)
          this.panelMaxHeight = Math.min(this.skyHeight * 0.78, 700)
        }
      })
  }
  private publishGuideState(): void {
    AppStorage.setOrCreate('stellariumGuideState', JSON.stringify({
      ok: true, state: this.guideStore.guideState, lastRequestId: this.guideStore.guideLastRequest,
      result: this.guideStore.guideLastResult, guides: ASTRONOMY_GUIDES
    }))
  }

  private currentGuide(): AstronomyGuide {
    return ASTRONOMY_GUIDES.find((guide: AstronomyGuide) => guide.id === this.guideStore.guideState.guideId) ?? ASTRONOMY_GUIDES[0]
  }

  private currentGuideStep(): GuideStep { return this.currentGuide().steps[this.guideStore.guideState.index] }
  private guideCardWidth(): number { return Math.max(200, Math.min(440, this.skyWidth - 24)) }

  /**
   * 手机端右上角常驻快捷区：陀螺仪 + 音频控制。
   * 这两项是观星高频功能，手机端保留顶部快捷入口；它们与底部 Dock
   * 共享同一状态和命令，不再依赖已经弃用的左侧栏。
   */
  /** 手机端右上快捷区左上角坐标（与顶部搜索栏同高，靠右缘） */
  private compactTopQuickX(): number {
    return this.skyWidth - 18 - 44
  }

  private isCompactTopQuickPoint(x: number, y: number): boolean {
    if (this.isExpandedLayout) { return false }
    const qx = this.compactTopQuickX()
    const qy = compactTopQuickY()
    return x >= qx - 8 && x <= qx + 52 && y >= qy - 8 && y <= qy + 108
  }

  /**
   * 星图缩放按钮命中（vp）：返回 'in'（+放大）| 'out'（−缩小）| ''。
   * 几何必须与 panels/shell/PanelChromeExtras.ets 的 SkyZoomLayer 保持一致：
   * posX=dockLeft, posY=dockTop-104, padding-left 4, 两个 44x44 按钮间距 8。
   */
  private skyZoomButtonAt(x: number, y: number): string {
    if (this.panelVisible || this.polarScopeStore.polarScopeVisible) { return '' }
    // 几何与 SkyZoomLayer 共用 common/ui/ChromeGeometry：绘制位置和命中区域必须同源，
    // 否则两者会各自漂移（曾出现"点 + 无响应、点 − 变成放大"的整列错位）。
    const horizontal = this.chromeZoomHorizontal()
    const rowY = this.chromeRowY()
    const inTop = chromeZoomButtonTop(rowY, horizontal, 0)
    const outTop = chromeZoomButtonTop(rowY, horizontal, 1)
    const inLeft = chromeZoomButtonLeft(chromeRowPosXLeft(this.isExpandedLayout, this.EDGE_MARGIN, this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.compactDockWidthPercent()), horizontal, 0)
    const outLeft = chromeZoomButtonLeft(chromeRowPosXLeft(this.isExpandedLayout, this.EDGE_MARGIN, this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.compactDockWidthPercent()), horizontal, 1)
    const within = (v: number, start: number): boolean => v >= start && v <= start + CHROME_ZOOM_BUTTON_SIZE
    if (horizontal) {
      // 横排两枚按钮同一行、左右并排，靠 x 区分。
      if (within(y, inTop)) {
        if (within(x, inLeft)) { return 'in' }
        if (within(x, outLeft)) { return 'out' }
      }
      return ''
    }
    // 竖排两枚按钮同一列、上下排列，靠 y 区分（上 + 下 −）。
    if (within(x, inLeft)) {
      if (within(y, inTop)) { return 'in' }
      if (within(y, outTop)) { return 'out' }
    }
    return ''
  }

  private compactQuickIdAt(x: number, y: number): string {
    if (this.isExpandedLayout) { return '' }
    const qx = this.compactTopQuickX()
    const qy = compactTopQuickY()
    if (x < qx || x > qx + 44) { return '' }
    if (y >= qy && y <= qy + 44) { return 'gyro' }
    if (y >= qy + 54 && y <= qy + 98) { return 'audio' }
    return ''
  }

  // The native sky XComponent can consume ArkUI Button.onClick on phones.
  // Route these two high-frequency controls through the same coordinate path
  // as the tablet rail so their visual and touch regions always agree.
  private handleCompactTopQuickTap(x: number, y: number): boolean {
    if (this.isExpandedLayout || !this.isCompactTopQuickPoint(x, y)) {
      return false
    }
    const quickId = this.compactQuickIdAt(x, y)
    if (quickId === 'gyro') {
      this.resetPanelIdle()
      this.gyroCtl().toggleGyroscope(!this.gyroStore.gyroscopeEnabled)
      this.flashHint(this.gyroStore.gyroscopeEnabled ? '陀螺仪已开启，正在校准' : '陀螺仪已关闭')
      return true
    }
    if (quickId === 'audio') {
      this.resetPanelIdle()
      this.toggleMusic()
      this.flashHint(this.audioStore.musicEnabled ? I18n.t('music_on_hint') : I18n.t('music_off_hint'))
      return true
    }
    return false
  }

  private handleCompactTopQuickTouch(event: TouchEvent): void {
    if (event.type === TouchType.Cancel) {
      this.compactQuickPressed = ''
      return
    }
    const points = event.touches.length > 0 ? event.touches : event.changedTouches
    if (points.length === 0) { return }
    const windowX = points[0].windowX
    const windowY = points[0].windowY
    const x = typeof windowX === 'number' ? windowX : this.compactTopQuickX() + (points[0].x ?? 0)
    const y = typeof windowY === 'number' ? windowY : compactTopQuickY() + (points[0].y ?? 0)
    if (event.type === TouchType.Down) {
      this.skyInputCtl().stopSkyInertia()
      this.skyTouchFeedback = false
      this.compactQuickPressed = this.compactQuickIdAt(x, y)
      return
    }
    if (event.type === TouchType.Up) {
      this.compactQuickPressed = ''
      this.handleCompactTopQuickTap(x, y)
    }
  }

  // ---- 选中天体的独立浮动详情窗口 ----
  // 默认收起（仅一行概要），点头部展开为可滚动的富详情卡（约半屏）。
  // 它独立于右侧菜单面板（activePanel），选中天体时不再强制切换菜单，
  // 因此不会打扰用户正在进行的操作。
  private setTrackingState(enabled: boolean): void {
    if (enabled && !this.objectDetailStore.hasSelectedObject()) {
      this.flashHint(I18n.t('tracking_requires_selection'))
      return
    }
    if (this.gyroStore.gyroscopeEnabled) {
      this.gyroCtl().updateGyroTargetGuide(true)
      this.flashHint(I18n.t('tracking_unavailable_gyro'))
      return
    }
    const requestSerial = ++this.trackingRequestSerial
    this.trackingRequestPending = true
    this.trackingText = enabled ? 'On' : 'Off'
    if (enabled) {
      // Native tracking owns the camera centre, so it supersedes the optional
      // fixed-screen-position mode. The native response is authoritative and
      // refreshState() will confirm the final toggle state.
      this.viewSettingsStore.viewLock = false
    }
    this.callInteractive('setTracking', enabled ? '1' : '0', (result: StellariumBridgeResponse) => {
      if (requestSerial !== this.trackingRequestSerial) { return }
      this.trackingRequestPending = false
      if (result.tracking !== undefined) {
        this.trackingText = result.tracking === true ? 'On' : 'Off'
      }
      if (result.viewLock !== undefined) {
        this.viewSettingsStore.viewLock = result.viewLock === true
      }
      this.trackingStateIgnoreUntilMs = Date.now() + 450
      this.flashHint(this.trackingText === 'On' ? I18n.t('tracking_enabled') : I18n.t('tracking_disabled'))
    }, () => {
      if (requestSerial !== this.trackingRequestSerial) { return }
      this.trackingRequestPending = false
      this.trackingText = enabled ? 'Off' : 'On'
      this.flashHint('跟踪状态更新失败，请重试')
    })
  }

  private setObjectDetailConnector(enabled: boolean, syncNative: boolean = true): void {
    this.overlayStore.objectDetailConnectorVisible = enabled
    this.refreshObjectDetailConnector()
    this.saveAppSettings()
    if (syncNative) {
      this.callInteractive('setObjectDetailConnector', enabled ? '1' : '0', () => {})
    }
  }


  // ── 顶部搜索栏（中等宽度，点击打开搜索面板） ──
  private bottomCardX(): number {
    const base = baseBottomCardX(this.isExpandedLayout, this.isFoldHoverLayout, this.skyWidth, this.EDGE_MARGIN, this.bottomCardWidth())
    return base + this.clampedObjectCardOffsetX(base, this.bottomCardWidth())
  }


  private bottomCardY(): number {
    const base = baseBottomCardY(this.isExpandedLayout, this.skyHeight, this.EDGE_MARGIN)
    return base + this.clampedObjectCardOffsetY(base, this.bottomCardHeight())
  }

  private detailCardX(): number {
    return this.bottomCardX()
  }

  private detailCardY(): number {
    return this.objectDetailCardY()
  }

  private detailCardWidth(): number {
    return this.bottomCardWidth()
  }

  private detailCardHeight(): number {
    return this.bottomCardHeight()
  }


  private clampedObjectCardOffsetX(base: number, width: number): number {
    return clamp(this.cardOffsetX, 8 - base, this.skyWidth - width - 8 - base)
  }

  private clampedObjectCardOffsetY(base: number, height: number): number {
    return clamp(this.cardOffsetY, 8 - base, this.skyHeight - height - 8 - base)
  }

  private bottomCardWidth(): number {
    // 手机详情卡保持左右对称留白，避免视觉上贴住右侧边框。
    if (!this.isExpandedLayout && !this.isFoldHoverLayout) { return Math.min(380, Math.max(286, this.skyWidth - 58)) }
    if (!this.isExpandedLayout) { return Math.min(318, Math.max(280, this.skyWidth - 52)) }
    // Keep the same responsive width while other panels open and close.
    return clamp(this.skyWidth * 0.38, 340, 480)
  }

  private bottomCardHeight(): number {
    if (this.isExpandedLayout) { return Math.min(440, Math.max(360, this.skyHeight - 176)) }
    if (this.isFoldHoverLayout) { return Math.min(380, Math.max(320, this.skyHeight - this.hoverConsoleTop() - 104)) }
    return clamp(this.skyHeight * 0.56, 320, 420)
  }







  private expandedDetailSummaryX(): number {
    const base = baseExpandedDetailSummaryX(this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN)
    return base + this.clampedObjectCardOffsetX(base, expandedDetailSummaryWidth(this.skyWidth, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN))
  }


  private expandedDetailSummaryY(): number {
    // 上移：原先 +84 使小详情卡偏中，遮挡视野中心；贴近顶部留出更多星空可视区
    const base = baseExpandedDetailSummaryY(this.EDGE_MARGIN)
    return base + this.clampedObjectCardOffsetY(base, expandedDetailSummaryHeight())
  }


  // 平板检查器固定贴在左侧：保留大部分星图，并给底部 Dock 留出触控空间。
  private tabletInspectorWidth(): number {
    return clamp(this.skyWidth * 0.32, 340, 390)
  }

  private tabletInspectorX(): number {
    const base = baseTabletInspectorX(this.EDGE_MARGIN)
    return base + this.clampedObjectCardOffsetX(base, this.tabletInspectorWidth())
  }


  private tabletInspectorY(): number {
    const base = baseTabletInspectorY(this.EDGE_MARGIN)
    return base + this.clampedObjectCardOffsetY(base, tabletInspectorHeight(this.skyHeight, this.EDGE_MARGIN))
  }



  private showObjectActionBar(): boolean {
    return false
  }

  private objectActionBarX(): number {
    if (useExpandedDetailSummary()) { return this.expandedDetailSummaryX() }
    if (isPhoneDetailPeek()) { return this.compactObjectPeekX() }
    return this.bottomCardX()
  }

  private objectActionBarWidth(): number {
    if (useExpandedDetailSummary()) { return expandedDetailSummaryWidth(this.skyWidth, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN) }
    if (isPhoneDetailPeek()) { return this.compactObjectPeekWidth() }
    return this.bottomCardWidth()
  }


  private isObjectActionBarPoint(x: number, y: number): boolean {
    if (!this.showObjectActionBar()) { return false }
    const left = this.objectActionBarX()
    const top = objectActionBarY(this.bottomCardY(), this.expandedDetailSummaryY(), this.compactObjectPeekY(), this.hoverBottomCardY(), this.isFoldHoverLayout)
    return x >= left - 8 && x <= left + this.objectActionBarWidth() + 8 && y >= top - 8 && y <= top + 42
  }

  private isExpandedDetailSummaryPoint(x: number, y: number): boolean {
    if (!useExpandedDetailSummary() || !canShowExpandedDetailSummary(this.skyWidth, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN)) { return false }
    const sx = this.expandedDetailSummaryX()
    const sy = this.expandedDetailSummaryY()
    return x >= sx - 8 && x <= sx + expandedDetailSummaryWidth(this.skyWidth, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN) + 8 && y >= sy - 8 && y <= sy + expandedDetailSummaryHeight() + 8
  }




  private handleExpandedDetailSummaryTap(x: number, y: number): boolean {
    if (!this.isExpandedDetailSummaryPoint(x, y)) { return false }
    const sx = this.expandedDetailSummaryX()
    const sy = this.expandedDetailSummaryY()
    const sw = expandedDetailSummaryWidth(this.skyWidth, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN)
    if (y <= sy + 42 && x >= sx + sw - 40) {
      this.dismissObjectInspector()
      return true
    }
    return true
  }

  private compactObjectPeekWidth(): number {
    // Keep the selected-object peek entirely clear of the right-side gyro and
    // audio controls.  On narrow phones the old 250vp minimum overlapped them.
    const quickLeft = this.compactTopQuickX()
    return Math.min(Math.max(210, quickLeft - 34), 320)
  }

  private compactObjectPeekX(): number {
    const base = this.baseCompactObjectPeekX()
    return base + this.clampedObjectCardOffsetX(base, this.compactObjectPeekWidth())
  }

  private baseCompactObjectPeekX(): number {
    const quickLeft = this.compactTopQuickX()
    const rightBound = quickLeft - 14
    return Math.max(16, Math.min((this.skyWidth - this.compactObjectPeekWidth()) / 2, rightBound - this.compactObjectPeekWidth()))
  }

  private compactObjectPeekY(): number {
    const base = baseCompactObjectPeekY()
    return base + this.clampedObjectCardOffsetY(base, 72)
  }

  private hoverBottomCardY(): number {
    const base = this.baseHoverBottomCardY()
    return base + this.clampedObjectCardOffsetY(base, this.bottomCardHeight())
  }

  private baseHoverBottomCardY(): number {
    return Math.max(this.hoverConsoleTop() + 20, this.skyHeight - this.bottomCardHeight() - 92)
  }

  private dismissObjectInspector(): void {
    if (this.objectDetailStore.selectedUiLayoutTimer !== 0) {
      clearTimeout(this.objectDetailStore.selectedUiLayoutTimer)
      this.objectDetailStore.selectedUiLayoutTimer = 0
    }
    this.infoWindowStore.infoWinVisible = false
    this.stopObjectDetailConnectorRefresh()
    this.infoWindowStore.infoWinExpanded = false
    this.objectMediaStore.objectInspectorMoreOpen = false
    this.dismissedObjectName = this.objectDetailStore.selectedName
    this.lastInfoWinCloseMs = Date.now()
    this.skyTouchActive = false
    this.skyTouchFeedback = false
    this.skyDragging = false
    // Closing the inspector must not alter the camera mode. Tracking and
    // fixed-position anchoring are independent of the card's visibility.
  }

  private handleObjectInspectorDragTouch(event: TouchEvent): void {
    const points = event.touches.length > 0 ? event.touches : event.changedTouches
    if (points.length === 0) { return }
    const point = points[0]
    const x = touchScreenX(point)
    const y = touchScreenY(point)
    if (event.type === TouchType.Down) {
      this.objectCardDragging = true
      this.objectCardDragStartX = x
      this.objectCardDragStartY = y
      this.objectCardDragStartOffsetX = this.cardOffsetX
      this.objectCardDragStartOffsetY = this.cardOffsetY
      this.skyInputCtl().stopSkyInertia()
      this.resetPanelIdle()
      return
    }
    if (event.type === TouchType.Move && this.objectCardDragging) {
      this.cardOffsetX = this.objectCardDragStartOffsetX + x - this.objectCardDragStartX
      this.cardOffsetY = this.objectCardDragStartOffsetY + y - this.objectCardDragStartY
      return
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.objectCardDragging = false
      const baseX = baseBottomCardX(this.isExpandedLayout, this.isFoldHoverLayout, this.skyWidth, this.EDGE_MARGIN, this.bottomCardWidth())
      const baseY = this.isFoldHoverLayout ? this.baseHoverBottomCardY() : baseBottomCardY(this.isExpandedLayout, this.skyHeight, this.EDGE_MARGIN)
      const width = this.detailCardWidth()
      const height = this.detailCardHeight()
      this.cardOffsetX = this.clampedObjectCardOffsetX(baseX, width)
      this.cardOffsetY = this.clampedObjectCardOffsetY(baseY, height)
    }
  }


  private showFullObjectInspector(): void {
    this.infoWindowStore.infoWinVisible = true
    this.infoWindowStore.infoWinExpanded = true
    this.fullInspectorRequested = true
    this.objectMediaStore.objectInspectorMoreOpen = false
    this.objectDetailStore.bottomCardIndex = 2
    this.objectCardPlacementPending = true
    this.dismissedObjectName = ''
    this.resetPanelIdle()
    this.refreshSelectedObject()
    this.startObjectDetailConnectorRefresh()
    this.scheduleSelectedObjectForUiChange(320)
  }

  private toggleObjectInspector(): void {
    if (!this.objectDetailStore.hasSelectedObject()) {
      this.flashHint(I18n.t('center_requires_selection'))
      return
    }
    if (this.infoWindowStore.infoWinVisible) {
      this.dismissObjectInspector()
    } else {
      this.showFullObjectInspector()
    }
  }

  private compactPanelUsableHeight(): number {
    if (this.isFoldHoverLayout) {
      return Math.max(Math.min(this.skyHeight * 0.46, 520), 320)
    }
    return Math.max(this.skyHeight - 318, 320)
  }

  private hoverSkyPaneHeight(): number {
    const angle = clamp(this.responsiveFoldAngle(), 55, 150)
    const ratio = clamp(0.43 + ((angle - 55) / 95) * 0.13, 0.43, 0.56)
    return clamp(this.skyHeight * ratio, 240, Math.max(280, this.skyHeight - 320))
  }

  private hoverConsoleTop(): number {
    return this.hoverSkyPaneHeight() + 10
  }

  private hoverPanelTop(): number {
    return Math.max(this.hoverConsoleTop() + 12, this.skyHeight - 90 - this.compactPanelHeight())
  }

  private compactPanelHeight(): number {
    const usable = this.compactPanelUsableHeight()
    const minH = usable * 0.6
    const maxH = usable * 0.9
    return clamp(usable * this.compactPanelSnapRatio - this.compactPanelDragOffsetY, minH - 28, maxH + 22)
  }

  private isCompactMorePoint(x: number, y: number): boolean {
    if (this.isExpandedLayout) {
      return false
    }
    return y >= this.skyHeight - 92 && x >= this.skyWidth * 0.72 && x <= this.skyWidth - 18
  }

  private updateCompactPanelDrag(offsetY: number): void {
    const usable = this.compactPanelUsableHeight()
    this.compactPanelDragOffsetY = clamp(offsetY, -usable * 0.34, usable * 0.12)
  }

  private settleCompactPanelDrag(): void {
    const usable = this.compactPanelUsableHeight()
    const effectiveRatio = (usable * this.compactPanelSnapRatio - this.compactPanelDragOffsetY) / usable
    const nextRatio = this.compactPanelDragOffsetY > 32 ? 0.6 : (effectiveRatio >= 0.74 ? 0.9 : 0.6)
    this.getUIContext().animateTo({ duration: 360, curve: curves.springMotion(0.46, 0.86) }, () => {
      this.compactPanelSnapRatio = nextRatio
      this.compactPanelDragOffsetY = 0
    })
    this.scheduleSelectedObjectForUiChange(390)
  }

  private expandedUiAllowed(): boolean {
    // updateResponsiveLayout() has already classified this window as expanded.
    // Do not apply a second, stricter size threshold here: the physical Pad
    // reports a 673vp short side in landscape and otherwise loses its rail.
    return this.isExpandedLayout
  }

  private canonicalDockActions(): ShellAction[] {
    return [
      primaryDockActions()[0],
      primaryDockActions()[1],
      primaryDockActions()[2],
      primaryDockActions()[3],
      { label: I18n.t('c_more_functions'), icon: 'more', panel: 'more' }
    ] as ShellAction[]
  }

  // ---- dock 上方三件套（FOV 读数 / 缩放按钮 / 常驻时钟）的统一锚点 --------------
  // 手机与半折：左右两端取同一个 x，等价于跟随 dock 两端（与改造前逐字一致，回归安全）。
  // 平板：改贴屏幕左右缘 —— 平板 dock 宽度封顶 640，且面板打开时会被挤到面板右侧，
  // 继续跟随 dock 两端会让三件套随面板开合整体横移，读数位置"漂"。
  private chromeRowY(): number {
    return this.dockTop() - 48
  }




  // 竖排（手机·半折，列高 96）还是横排（平板，一行 44 高）：平板 dock 只有 54 高，
  // 96 高的竖排压在它上方过于突兀，横排更贴近平板的工具条语汇。
  private chromeZoomHorizontal(): boolean {
    return this.isExpandedLayout
  }




  private compactDockWidthPercent(): number {
    if (this.isFoldHoverLayout) {
      return this.panelVisible ? 46 : 58
    }
    return this.panelVisible ? 76 : 92
  }

  private compactDockLabelFontSize(): number {
    return this.isFoldHoverLayout ? 11 : 12
  }

  private compactDockIconSize(): number {
    return this.isFoldHoverLayout ? 22 : 23
  }

  private compactDockItemHeight(): number {
    return this.isFoldHoverLayout ? 52 : 56
  }

  private compactPanelHorizontalPadding(): number {
    return this.isFoldHoverLayout ? 14 : 18
  }



  private dockTop(): number {
    return this.isExpandedLayout ? this.skyHeight - 62 : this.skyHeight - 82
  }


  private dockActionAt(x: number, y: number): ShellAction | null {
    if (!isDockPoint(x, y, this.polarScopeStore.polarScopeVisible, this.isExpandedLayout, this.skyWidth, this.skyHeight, this.panelVisible, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN, this.compactDockWidthPercent(), this.dockTop())) {
      return null
    }
    const actions = this.canonicalDockActions()
    if (actions.length === 0) {
      return null
    }
    const usableLeft = dockLeft(this.isExpandedLayout, this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN, this.compactDockWidthPercent()) + 4
    const usableWidth = Math.max(1, dockWidthPixels(this.isExpandedLayout, this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN, this.compactDockWidthPercent()) - 8)
    const itemWidth = usableWidth / actions.length
    const index = Math.floor((x - usableLeft) / itemWidth)
    return index >= 0 && index < actions.length ? actions[index] : null
  }

  private activateDockAction(item: ShellAction): void {
    const now = Date.now()
    if (item.panel === this.lastDockActionPanel && now - this.lastDockActionAt < 360) {
      return
    }
    this.lastDockActionPanel = item.panel
    this.lastDockActionAt = now
    if (item.panel === 'more') {
      this.setPanel('more')
      return
    }
    if (item.panel === 'object') {
      this.showFullObjectInspector()
      return
    }
    this.setPanel(item.panel)
    this.flashHint(I18n.t('msg_panel_opened'))
  }

  private handleDockTouch(event: TouchEvent): void {
    const points = event.touches.length > 0 ? event.touches : event.changedTouches
    if (points.length === 0) { return }
    this.notePanelTouch(event)
    const x = touchScreenX(points[0])
    const y = touchScreenY(points[0])
    if (event.type === TouchType.Down) {
      this.dockTouchActive = true
      this.skyInputCtl().stopSkyInertia()
      hilog.info(0x0000, 'StellariumArkUI', '[DOCK] down screen=%{public}d,%{public}d left=%{public}d top=%{public}d width=%{public}d', Math.round(x), Math.round(y), Math.round(dockLeft(this.isExpandedLayout, this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN, this.compactDockWidthPercent())), Math.round(this.dockTop()), Math.round(dockWidthPixels(this.isExpandedLayout, this.skyWidth, this.panelVisible, this.panelWidth, this.panelOffsetX, this.EDGE_MARGIN, this.compactDockWidthPercent())))
      return
    }
    if (event.type === TouchType.Up) {
      if (this.dockTouchActive) {
        this.dockTouchActive = false
        const item = this.dockActionAt(x, y)
        hilog.info(0x0000, 'StellariumArkUI', '[DOCK] up screen=%{public}d,%{public}d item=%{public}s', Math.round(x), Math.round(y), item === null ? 'none' : item.panel)
        if (item !== null) { this.activateDockAction(item) }
      }
      return
    }
    if (event.type === TouchType.Cancel) {
      this.dockTouchActive = false
    }
  }

  // Pad 端的详情保持为左侧检查器。它不接管星图，也不会随着实时数据刷新
  // 重新打开或改变位置；长资料和观测数字使用同一个连续滚动区。
  private objectInspectorFilePath(relativePath: string): string {
    const path = this.stellariumFilesDir() + '/stellarium/' + relativePath
    try {
      return fileIo.accessSync(path) ? path : ''
    } catch (_err) {
      return ''
    }
  }

  private clearObjectInspectorDecodedImage(): void {
    const oldPixelMap = this.objectMediaStore.objectInspectorMediaPixelMap
    this.objectMediaStore.objectInspectorMediaPixelMap = undefined
    this.objectInspectorMediaDecodeGeneration++
    this.objectModelRendererCtl().clearObjectInspectorModelRenderer()
    releaseDecodedImage(this.hostMediaPort, oldPixelMap, 'object-inspector')
  }


  private updateObjectInspectorMediaWarmup(kind: string): void {
    if (kind !== 'image') {
      this.objectMediaStore.objectInspectorMediaWarmupState = 'unknown'
      this.objectMediaStore.objectInspectorMediaWarmupInstalled = 0
      this.objectMediaStore.objectInspectorMediaWarmupTotal = 0
      this.objectMediaStore.objectInspectorMediaWarmupFailed = 0
      return
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const status: DeepSkyWarmupStatus = getDeepSkyResourceWarmupStatus(context.getApplicationContext())
      this.objectMediaStore.objectInspectorMediaWarmupState = status.state
      this.objectMediaStore.objectInspectorMediaWarmupInstalled = status.installed
      this.objectMediaStore.objectInspectorMediaWarmupTotal = status.total
      this.objectMediaStore.objectInspectorMediaWarmupFailed = status.failed
    } catch (err) {
      this.objectMediaStore.objectInspectorMediaWarmupState = 'unknown'
      hilog.warn(0x0000, 'StellariumArkUI',
        '[detail-media] unable to read warmup status error=%{public}s', JSON.stringify(err))
    }
  }

  private startObjectInspectorMediaWarmup(): void {
    if (this.objectInspectorMediaWarmupTimer !== 0) {
      return
    }
    this.objectInspectorMediaWarmupTimer = setInterval(() => {
      if (!this.objectMediaStore.objectInspectorMediaLoading || this.objectMediaStore.objectInspectorMediaKind !== 'image') {
        this.stopObjectInspectorMediaWarmup()
        return
      }
      this.updateObjectInspectorMediaWarmup('image')
    }, 500) as number
  }

  private stopObjectInspectorMediaWarmup(): void {
    if (this.objectInspectorMediaWarmupTimer !== 0) {
      clearInterval(this.objectInspectorMediaWarmupTimer)
      this.objectInspectorMediaWarmupTimer = 0
    }
  }

  // Resolves the detail textures of the seven planets, the Moon and the Sun once
  // the sky has presented its first frame, one body per tick, so opening their
  // cards does not have to copy the packaged texture on demand. This only makes
  // the existing on-select work happen earlier: it never moves the view, never
  // shows a dialog and never blocks the UI thread.
  private startBodyDetailWarmup(): void {
    if (this.bodyDetailWarmupTimer !== 0) {
      return
    }
    this.bodyDetailWarmupPending = BODY_DETAIL_TEXTURE_PATHS.slice()
    this.bodyDetailWarmupIndex = 0
    this.stepBodyDetailWarmup()
    this.bodyDetailWarmupTimer = setInterval(() => {
      this.stepBodyDetailWarmup()
    }, 120) as number
  }

  private stepBodyDetailWarmup(): void {
    if (this.bodyDetailWarmupIndex >= this.bodyDetailWarmupPending.length) {
      hilog.info(0x0000, 'StellariumArkUI', '[body-warmup] completed count=%{public}d',
        this.bodyDetailWarmupPending.length)
      this.stopBodyDetailWarmup()
      return
    }
    const relativePath = this.bodyDetailWarmupPending[this.bodyDetailWarmupIndex]
    this.bodyDetailWarmupIndex++
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      resolveStellariumDetailMediaAsset(context.getApplicationContext(), relativePath).then((resolved: string) => {
        if (resolved.length === 0) {
          hilog.warn(0x0000, 'StellariumArkUI', '[body-warmup] unavailable path=%{public}s', relativePath)
        } else {
          hilog.info(0x0000, 'StellariumArkUI', '[body-warmup] ready path=%{public}s', resolved)
        }
      }).catch((err: Error) => {
        hilog.warn(0x0000, 'StellariumArkUI', '[body-warmup] failed path=%{public}s error=%{public}s',
          relativePath, JSON.stringify(err))
      })
    } catch (err) {
      hilog.warn(0x0000, 'StellariumArkUI', '[body-warmup] failed path=%{public}s error=%{public}s',
        relativePath, JSON.stringify(err))
    }
  }

  private stopBodyDetailWarmup(): void {
    if (this.bodyDetailWarmupTimer !== 0) {
      clearInterval(this.bodyDetailWarmupTimer)
      this.bodyDetailWarmupTimer = 0
    }
    this.bodyDetailWarmupIndex = 0
    this.bodyDetailWarmupPending = []
  }

  private refreshObjectInspectorMedia(): void {
    const planetTexturePath = objectInspectorPlanetTexturePath(this.objectDetailStore.selectedEnglishName)
    const deepSkyImageName = planetTexturePath.length === 0 && this.objectDetailStore.selectedDetailMediaPath.length === 0
      ? objectInspectorDeepSkyImageName(objectInspectorFallbackVisualKind(this.objectDetailStore.selectedObjectType, this.objectDetailStore.selectedType), this.objectDetailStore.objectInspectorSearchText())
      : ''
    const requestedPath = planetTexturePath.length > 0
      ? planetTexturePath
      : (this.objectDetailStore.selectedDetailMediaPath.length > 0
        ? this.objectDetailStore.selectedDetailMediaPath
        : (deepSkyImageName.length > 0 ? 'nebulae/default/' + deepSkyImageName : ''))
    const proceduralKind = requestedPath.length === 0 || (planetTexturePath.length === 0 &&
      this.objectInspectorMediaResolutionComplete && this.objectInspectorMediaResolvedRequestPath === requestedPath &&
      this.objectInspectorMediaResolvedPath.length === 0)
      ? proceduralModelKind(this.objectDetailStore.selectedObjectType + ' ' + this.objectDetailStore.selectedType) : ''
    const proceduralKey = proceduralKind.length > 0
      ? [proceduralKind, this.objectDetailStore.selectedCatalogId, this.objectDetailStore.selectedEnglishName, this.objectDetailStore.selectedTemperatureK.toString()].join('|') : ''
    if (this.objectInspectorMediaResolvedRequestPath !== requestedPath) {
      this.objectInspectorMediaResolvedRequestPath = ''
      this.objectInspectorMediaResolvedPath = ''
      this.objectInspectorMediaResolutionComplete = false
    }
    const resolvedPath = this.objectInspectorMediaResolvedRequestPath === requestedPath &&
      this.objectInspectorMediaResolvedPath.length > 0
      ? this.objectInspectorMediaResolvedPath
      : requestedPath
    const filePath = resolvedPath.length > 0 ? this.objectInspectorFilePath(resolvedPath) : ''
    const path = filePath.length > 0 ? fileUri.getUriFromPath(filePath) : ''
    const kind = planetTexturePath.length > 0 || proceduralKind.length > 0
      ? 'model'
      : (this.objectDetailStore.selectedDetailMediaPath.length > 0 ? 'constellation' : (deepSkyImageName.length > 0 ? 'image' : 'visual'))
    const modelRawFilePath = kind === 'model' && resolvedPath.length > 0
      ? this.objectInspectorFilePath(resolvedPath + '.model.rgba')
      : ''
    const ringSpec = kind === 'model' ? objectInspectorPlanetRingSpec(this.objectDetailStore.selectedEnglishName) : undefined
    const ringRawFilePath = ringSpec === undefined
      ? ''
      : this.objectInspectorFilePath(ringSpec.texturePath + '.model.rgba')
    const ringPngFilePath = ringSpec === undefined
      ? ''
      : this.objectInspectorFilePath(ringSpec.texturePath)
    const resolutionAlreadyAttempted = this.objectInspectorMediaResolutionComplete &&
      this.objectInspectorMediaResolvedRequestPath === requestedPath
    const shouldResolve = requestedPath.length > 0 && path.length === 0 && !resolutionAlreadyAttempted
    const mediaKeySame = path === this.objectMediaStore.objectInspectorMediaPath && kind === this.objectMediaStore.objectInspectorMediaKind &&
      proceduralKey === this.objectInspectorProceduralKey
    if (mediaKeySame && (this.objectMediaStore.objectInspectorMediaDecoding || this.objectModelRendererCtl().isRendering())) {
      return
    }
    const shouldDecode = path.length > 0 && (kind === 'image' || kind === 'constellation' || kind === 'model') &&
      !(mediaKeySame && this.objectMediaStore.objectInspectorMediaLoadFailed) &&
      (!mediaKeySame || (kind === 'model'
        ? !this.objectModelRendererCtl().hasTexture()
        : this.objectMediaStore.objectInspectorMediaPixelMap === undefined))
    if (mediaKeySame &&
      this.objectMediaStore.objectInspectorMediaLoading === (shouldResolve || shouldDecode) &&
      this.objectMediaStore.objectInspectorMediaDecoding === shouldDecode &&
      (!shouldResolve || this.objectInspectorMediaRequestPath === requestedPath)) { return }
    this.clearObjectInspectorDecodedImage()
    this.objectMediaStore.objectInspectorMediaPath = path
    this.objectMediaStore.objectInspectorMediaKind = kind
    this.objectMediaStore.objectInspectorProceduralKind = proceduralKind
    this.objectInspectorProceduralKey = proceduralKey
    this.objectInspectorProceduralParticles = proceduralParticles(proceduralKind, proceduralKey)
    this.objectMediaStore.objectInspectorMediaLabel = kind === 'model'
      ? (proceduralKind.length > 0 ? I18n.t('model_schematic') : I18n.t('model_offline'))
      : (kind === 'constellation' ? this.objectDetailStore.selectedDetailMediaLabel : (kind === 'image' ? '离线深空资料图像' : '本地天体类别示意'))
    this.objectMediaStore.objectInspectorMediaFullscreen = false
    this.objectMediaStore.objectInspectorMediaPreviewPath = ''
    this.objectMediaStore.objectInspectorMediaPreviewLoading = false
    this.objectMediaStore.objectInspectorMediaPreviewFailed = false
    this.objectMediaStore.objectInspectorModelScale = 1
    this.objectModelRendererCtl().resetRotationForNewMedia()
    this.objectMediaStore.objectInspectorMediaLoading = shouldResolve || shouldDecode
    this.objectMediaStore.objectInspectorMediaDecoding = shouldDecode
    this.objectMediaStore.objectInspectorMediaLoadFailed = false
    this.objectMediaStore.objectInspectorMediaPreparationFailed = false
    this.objectMediaStore.objectInspectorMediaNoMatch = false
    this.updateObjectInspectorMediaWarmup(kind)
    this.objectInspectorMediaRequestPath = this.objectMediaStore.objectInspectorMediaLoading ? requestedPath : ''
    if (proceduralKind.length > 0) {
      this.objectModelRendererCtl().requestObjectInspectorModelRender(true)
      return
    }
    if (shouldResolve) {
      const expectedSelection = this.objectDetailStore.selectedName + '\n' + this.objectDetailStore.selectedEnglishName + '\n' + this.objectDetailStore.selectedCatalogId
      const expectedRequestPath = requestedPath
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const warmupStatus: DeepSkyWarmupStatus = getDeepSkyResourceWarmupStatus(context.getApplicationContext())
      hilog.info(0x0000, 'StellariumArkUI',
        '[detail-media] warmup state=%{public}s installed=%{public}s total=%{public}s pending=%{public}s failed=%{public}s',
        warmupStatus.state, warmupStatus.installed.toString(), warmupStatus.total.toString(),
        warmupStatus.pending.toString(), warmupStatus.failed.toString())
      this.startObjectInspectorMediaWarmup()
      resolveStellariumDetailMediaAsset(context.getApplicationContext(), requestedPath).then((actualPath: string) => {
        const currentSelection = this.objectDetailStore.selectedName + '\n' + this.objectDetailStore.selectedEnglishName + '\n' + this.objectDetailStore.selectedCatalogId
        if (currentSelection !== expectedSelection || this.objectInspectorMediaRequestPath !== expectedRequestPath) { return }
        this.objectMediaStore.objectInspectorMediaLoading = false
        this.objectInspectorMediaRequestPath = ''
        this.objectInspectorMediaResolvedRequestPath = expectedRequestPath
        this.objectInspectorMediaResolvedPath = actualPath
        this.objectInspectorMediaResolutionComplete = true
        this.objectMediaStore.objectInspectorMediaNoMatch = actualPath.length === 0
        this.objectMediaStore.objectInspectorMediaLoadFailed = false
        this.objectMediaStore.objectInspectorMediaPreparationFailed = false
        this.stopObjectInspectorMediaWarmup()
        this.updateObjectInspectorMediaWarmup(kind)
        hilog.info(0x0000, 'StellariumArkUI',
          '[detail-media] selection=%{public}s requested=%{public}s resolved=%{public}s',
          this.objectDetailStore.selectedName, expectedRequestPath, actualPath)
        this.refreshObjectInspectorMedia()
      }).catch((err: Error) => {
        const currentSelection = this.objectDetailStore.selectedName + '\n' + this.objectDetailStore.selectedEnglishName + '\n' + this.objectDetailStore.selectedCatalogId
        if (currentSelection !== expectedSelection || this.objectInspectorMediaRequestPath !== expectedRequestPath) { return }
        this.objectMediaStore.objectInspectorMediaLoading = false
        this.objectInspectorMediaRequestPath = ''
        this.objectInspectorMediaResolutionComplete = true
        this.objectMediaStore.objectInspectorMediaNoMatch = false
        this.objectMediaStore.objectInspectorMediaLoadFailed = false
        this.objectMediaStore.objectInspectorMediaPreparationFailed =
          isStellariumDetailMediaPreparationFailed(context.getApplicationContext(), expectedRequestPath)
        this.stopObjectInspectorMediaWarmup()
        hilog.error(0x0000, 'StellariumArkUI',
          '[detail-media] request failed request=%{public}s error=%{public}s', expectedRequestPath, err.message)
      })
    }
    if (shouldDecode) {
      const expectedSelection = this.objectDetailStore.selectedName + '\n' + this.objectDetailStore.selectedEnglishName + '\n' + this.objectDetailStore.selectedCatalogId
      const expectedPath = path
      const generation = this.objectInspectorMediaDecodeGeneration
      hilog.info(0x0000, 'StellariumArkUI',
        '[detail-media] decoding local image kind=%{public}s uri=%{public}s', kind, expectedPath)
      if (kind === 'model') {
        this.objectMediaStore.loadObjectInspectorModelRawTexture(modelRawFilePath, ringRawFilePath, generation, expectedSelection, expectedPath,
          filePath, ringPngFilePath)
        return
      }
      decodeLocalImage(this.hostMediaPort, filePath, kind, (pixelMap: image.PixelMap) => {
        const currentSelection = this.objectDetailStore.selectedName + '\n' + this.objectDetailStore.selectedEnglishName + '\n' + this.objectDetailStore.selectedCatalogId
        if (currentSelection !== expectedSelection || this.objectMediaStore.objectInspectorMediaPath !== expectedPath ||
          generation !== this.objectInspectorMediaDecodeGeneration) {
          releaseDecodedImage(this.hostMediaPort, pixelMap, 'stale-object-inspector')
          return
        }
        const oldPixelMap = this.objectMediaStore.objectInspectorMediaPixelMap
        this.objectMediaStore.objectInspectorMediaPixelMap = pixelMap
        releaseDecodedImage(this.hostMediaPort, oldPixelMap, 'previous-object-inspector')
        this.objectMediaStore.objectInspectorMediaLoading = false
        this.objectMediaStore.objectInspectorMediaLoadFailed = false
        this.objectMediaStore.objectInspectorMediaDecoding = false
        if (this.objectMediaStore.objectInspectorMediaFullscreen) {
          this.objectMediaStore.objectInspectorMediaPreviewLoading = false
          this.objectMediaStore.objectInspectorMediaPreviewFailed = false
        }
        hilog.info(0x0000, 'StellariumArkUI',
          '[detail-media] pixel map ready kind=%{public}s uri=%{public}s', kind, expectedPath)
      }, (err: Error) => {
        const currentSelection = this.objectDetailStore.selectedName + '\n' + this.objectDetailStore.selectedEnglishName + '\n' + this.objectDetailStore.selectedCatalogId
        if (currentSelection !== expectedSelection || this.objectMediaStore.objectInspectorMediaPath !== expectedPath ||
          generation !== this.objectInspectorMediaDecodeGeneration) {
          return
        }
        this.objectMediaStore.objectInspectorMediaDecoding = false
        this.objectMediaStore.objectInspectorMediaLoading = false
        this.objectMediaStore.objectInspectorMediaLoadFailed = true
        if (this.objectMediaStore.objectInspectorMediaFullscreen) {
          this.objectMediaStore.objectInspectorMediaPreviewLoading = false
          this.objectMediaStore.objectInspectorMediaPreviewFailed = true
        }
        hilog.error(0x0000, 'StellariumArkUI',
          '[detail-media] pixel map decode failed kind=%{public}s uri=%{public}s error=%{public}s',
          kind, expectedPath, describeDecodeError(err))
      })
    }
  }




  // §14 B2R-1：ObjectMediaStore.loadObjectInspectorModelRawTexture 的原始侧车读取职责
  //（fileIo 属 NAPI，不下沉 store）——把原地内联的 open/read/close 与尺寸校验提取为本方法，
  // 经 ObjectMediaHostHooks.readRawSidecar 注入；尺寸不符或 IO 失败抛 Error，语义与原地一致。
  private readRawSidecar(path: string, expectedBytes: number, label: string): ArrayBuffer {
    let file: fileIo.File | undefined = undefined
    try {
      const pixels = new ArrayBuffer(expectedBytes)
      file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
      const bytesRead = fileIo.readSync(file.fd, pixels)
      fileIo.closeSync(file)
      file = undefined
      if (bytesRead !== expectedBytes) {
        throw new Error(label + ' has unexpected size: ' + bytesRead.toString())
      }
      return pixels
    } catch (err) {
      if (file !== undefined) {
        try {
          fileIo.closeSync(file)
        } catch (_closeErr) { }
      }
      throw err as Error
    }
  }













  private objectInspectorInlineModelSize(): number {
    return Math.min(200, Math.max(80, this.bottomCardWidth() - 112))
  }



  private selectedDisplayValue(key: string): string {
    switch (key) {
      case 'selectedAirmass': return this.objectDetailStore.selectedAirmass
      case 'selectedApparentMagnitude': return this.objectDetailStore.selectedApparentMagnitude
      case 'selectedApparentSiderealTime': return this.objectDetailStore.selectedApparentSiderealTime
      case 'selectedConstellation': return zhNameOf(this.objectDetailStore.selectedConstellation)
      case 'selectedCoordAlt': return this.objectDetailStore.selectedCoordAlt
      case 'selectedCoordApparentAltAz': return this.objectDetailStore.selectedCoordApparentAltAz || this.objectDetailStore.selectedCoordAlt
      case 'selectedCoordEcliptic': return this.objectDetailStore.selectedCoordEcliptic
      case 'selectedCoordEclipticJ2000': return this.objectDetailStore.selectedCoordEclipticJ2000
      case 'selectedCoordEq': return this.objectDetailStore.selectedCoordEq
      case 'selectedCoordEqJ2000': return this.objectDetailStore.selectedCoordEqJ2000
      case 'selectedCoordGalactic': return this.objectDetailStore.selectedCoordGalactic
      case 'selectedCoordGeometricAltAz': return this.objectDetailStore.selectedCoordGeometricAltAz
      case 'selectedCoordParallactic': return this.objectDetailStore.selectedCoordParallactic
      case 'selectedCoordSupergalactic': return this.objectDetailStore.selectedCoordSupergalactic
      case 'selectedDistance': return this.objectDetailStore.selectedDistance
      case 'selectedElongation': return this.objectDetailStore.selectedElongation
      case 'selectedEnglishName': return this.objectDetailStore.selectedEnglishName
      case 'selectedExtinction': return this.objectDetailStore.selectedExtinction
      case 'selectedHourAngle': return this.objectDetailStore.selectedHourAngle
      case 'selectedMagnitude': return this.objectDetailStore.selectedMagnitude
      case 'selectedMeanSiderealTime': return this.objectDetailStore.selectedMeanSiderealTime
      case 'selectedPhase': return this.objectDetailStore.selectedPhase
      case 'selectedRise': return this.objectDetailStore.selectedRise
      case 'selectedSet': return this.objectDetailStore.selectedSet
      case 'selectedSize': return this.objectDetailStore.selectedSize
      case 'selectedTransit': return this.objectDetailStore.selectedTransit
      case 'extinctionUnits': return this.objectDetailStore.selectedExtinction.length > 0 ? this.objectDetailStore.selectedExtinction + ' 等' : ''
      case 'atmosphere': return this.objectDetailStore.expandedAtmosphereSummary()
      default: return ''
    }
  }





  private selectObjectDetailTab(index: number): void {
    if (index === this.objectDetailStore.bottomCardIndex) return
    const direction = index > this.objectDetailStore.bottomCardIndex ? 1 : -1
    const transitionId = ++this.objectDetailTabTransitionId
    this.getUIContext().animateTo({ duration: 100, curve: Curve.EaseIn, onFinish: () => {
      if (transitionId !== this.objectDetailTabTransitionId) return
      this.objectDetailStore.bottomCardIndex = index
      this.objectDetailContentTranslateX = 0 - direction * 10
      this.getUIContext().animateTo({ duration: 170, curve: Curve.EaseOut }, () => {
        this.objectDetailContentOpacity = 1
        this.objectDetailContentTranslateX = 0
      })
    } }, () => {
      this.objectDetailContentOpacity = 0
      this.objectDetailContentTranslateX = direction * 8
    })
  }





  private toggleSelectedObservingList(): void {
    const idx = this.obsListStore.observingList.indexOf(this.objectDetailStore.selectedName)
    if (idx >= 0) {
      this.obsListStore.observingList = this.obsListStore.observingList.filter((item: string) => item !== this.objectDetailStore.selectedName)
      this.flashHint(I18n.t('i0079'))
    } else {
      this.obsListStore.observingList = this.obsListStore.observingList.concat([this.objectDetailStore.selectedName])
      this.flashHint(I18n.t('i0080'))
    }
    this.persistObservingList()
  }

  // 底部详情卡片触摸交互：只处理头部关闭按钮，
  // Swiper body 区域返回 false，让 Swiper 自身手势系统处理水平滑动。
  private handleInfoWinTap(x: number, y: number): boolean {
    if (!isObjectDetailCardPoint(x, y, this.objectDetailStore.isObjectDetailCardRendered(this.infoWindowStore.infoWinVisible), this.detailCardX(), this.detailCardY(), this.detailCardWidth(), this.detailCardHeight())) { return false }
    const bcX = this.detailCardX()
    const bcY = this.detailCardY()
    const bcW = this.detailCardWidth()
    // 只处理头部区域（前 ~48px：名称 + 类型 + 关闭按钮）
    const headerH = 48
    if (y <= bcY + headerH) {
      const closeW = 40
      if (x >= bcX + bcW - closeW) {
        this.dismissObjectInspector()
        return true
      }
      // 头部其他区域点击不做任何操作
      return true
    }
    // Swiper body 区域也消费触摸，防止详情卡内点击穿透到星图选星。
    // Swiper 的水平滑动仍由 ArkUI 组件自身处理。
    return true
  }

  // 手机上的常驻控件随空闲状态变为轻透玻璃；展开和平板悬停布局保持各自的面板规则。
  private phoneChromeOpacity(): number {
    return (!this.isExpandedLayout && !this.isFoldHoverLayout) ? this.panelIdleOpacity : 1.0
  }

  private phoneChromeIsGlass(): boolean {
    return !this.isExpandedLayout && !this.isFoldHoverLayout && this.panelIdleGlass
  }

  // 夜间模式颜色方案

  private selectedStatusZh(en: string): string {
    return I18n.selectedStatus(en)
  }











  // 收起当前页面按钮：把右侧浮动面板收回到左侧栏
  // 「更多」按钮：与搜索、时间、位置和图层共用同一主面板。

  // 音乐开关按钮（左侧栏底部）：开着时音符亮起，静音时变暗

  // ── 陀螺仪按钮（平板左侧栏，与手机端 compactQuickButton 共用 ic_gyro.svg）──

  // ── 陀螺仪校准面板 ──

  // 切换音乐开关（带 350ms 防抖，避免坐标命中与 onClick 双触发导致来回跳）
  private toggleMusic(): void {
    const now = Date.now()
    if (now - this.lastMusicToggle < 350) { return }
    this.lastMusicToggle = now
    this.audioStore.musicEnabled = !this.audioStore.musicEnabled
    const engine = AudioEngine.getInstance()
    if (this.audioStore.musicEnabled) {
      engine.start().then(() => { engine.setMuted(false) })
    } else {
      engine.setMuted(true)
    }
    this.persistMusicEnabled()
    this.flashHint(this.audioStore.musicEnabled ? '音乐：开 ♪' : '音乐：静音')
  }

  private persistMusicEnabled(): void {
    let obj: Record<string, boolean | string> = {}
    const cur = AppStorage.get<string>('stellariumSettings')
    if (cur) {
      try { obj = JSON.parse(cur) as Record<string, boolean | string> } catch (e) { }
    }
    obj['musicEnabled'] = this.audioStore.musicEnabled
    AppStorage.setOrCreate('stellariumSettings', JSON.stringify(obj))
  }

  // 引擎回报的夜视状态落库。换挡瞬间 / 轮询（约每 3 s）可能回报旧值，
  // 因此在"待定窗口"内忽略与待定值不一致的回报，避免刚打开又被旧值翻回去
  // （与 syncTimeRateState 的去重窗口同一套路）。
  private syncNightModeFromEngine(engineNight: boolean): void {
    if (this.pendingNightMode !== undefined) {
      const matches = engineNight === this.pendingNightMode
      if (!matches && Date.now() < this.pendingNightModeUntilMs) { return }
      this.pendingNightMode = undefined
      this.pendingNightModeUntilMs = 0
    }
    this.nightModeStore.nightMode = engineNight
  }

  // 夜视模式统一入口：写状态 + 可选持久化 + 下发原生命令。
  // 时间面板的夜视开关与（后续）主界面独立按钮都走这一个入口。
  private applyNightMode(enabled: boolean, persist: boolean): void {
    this.pendingNightMode = enabled
    this.pendingNightModeUntilMs = Date.now() + 3500
    this.nightModeStore.nightMode = enabled
    if (persist) { this.persistNightMode() }
    this.callNative('setNightMode', enabled ? 'true' : 'false')
  }

  private persistNightMode(): void {
    let obj: Record<string, boolean | string> = {}
    const cur = AppStorage.get<string>('stellariumSettings')
    if (cur) {
      try { obj = JSON.parse(cur) as Record<string, boolean | string> } catch (e) { }
    }
    obj['nightMode'] = this.nightModeStore.nightMode
    AppStorage.setOrCreate('stellariumSettings', JSON.stringify(obj))
  }

  private persistEquatorialMount(): void {
    let obj: Record<string, boolean | string> = {}
    const cur = AppStorage.get<string>('stellariumSettings')
    if (cur) {
      try { obj = JSON.parse(cur) as Record<string, boolean | string> } catch (e) { }
    }
    obj['equatorialMount'] = this.telescopeStore.equatorialMount
    AppStorage.setOrCreate('stellariumSettings', JSON.stringify(obj))
  }

  // 平板/桌面浮动面板与手机底部面板：体内调用 this.panelContent()。
  // ArkUI 不能在子组件里调用宿主 @Builder（会整应用退出，见计划 §13.1 规则 9），
  // 故二者是刻意的宿主薄 @Builder，不是遗漏（Phase 4h 定论，Phase 6d/7 复核仍然成立）。

  @Builder
  floatingPanel() {
    Column() {
      if (this.isExpandedLayout) {
        PadPanelHandle()
      }
      PanelHeader({
        title: panelTitleFor(this.activePanel, this.configTab, this.isExpandedLayout, this.timeStore.timePanelClockText()), subtitle: this.timeStore.panelSubtitle(this.activePanel), canGoBack: this.canGoBackPanel(),
        routeOpacity: this.panelRouteOpacity, routeOffsetX: this.panelRouteOffsetX,
        onBack: () => { this.handlePanelBackTap() },
        onClose: () => { this.closePanel(true); this.resetPanelIdle() }
      })
      Scroll(this.widePanelScroller) {
        Column() {
          Column() {
            this.panelContent()
          }
            .width('100%')
            .opacity(this.panelRouteOpacity)
            .translate({ x: this.panelRouteOffsetX, y: 0 })
        }
          .width('100%')
      // Keep the route host stable. Changing its id on every navigation makes
      // ArkUI replace the node and bypass the explicit out/swap/in animation.
      .id('panel-content-' + this.i18nLang)
      }
        .width('100%')
        .layoutWeight(1)
        .scrollable(ScrollDirection.Vertical)
        .id('panel-scroll-' + this.i18nLang)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .onAppear(() => { this.resetPanelScroll(this.widePanelScroller) })
    }
      .width(this.panelWidth)
      .height(this.panelMaxHeight)
      .constraintSize({ maxHeight: this.panelMaxHeight })
      .padding({ top: 18, left: 18, right: 18, bottom: 18 })
      .backgroundColor(this.panelIdleGlass ? 'rgba(10, 14, 26, 0.55)' : 'rgba(18, 22, 36, 0.82)')
      .backdropBlur(this.panelIdleGlass ? 45 : 30)
      .border({ width: 0.5, color: this.panelIdleGlass ? 'rgba(91, 147, 191, 0.18)' : 'rgba(91, 147, 191, 0.12)' })
      .borderRadius(UI_RADIUS_SHEET)
      .shadow({ radius: 34, color: 'rgba(0, 0, 0, 0.34)', offsetX: 0, offsetY: 18 })
      .margin({ top: 28, bottom: 28 })
      .onTouch((event: TouchEvent) => { this.notePanelTouch(event) })
      .scale({ x: this.panelIdleOpacity < 1 ? 0.97 : 1.0, y: this.panelIdleOpacity < 1 ? 0.97 : 1.0 })
      .opacity(this.panelIdleOpacity * this.panelPresentationOpacity)
      .translate({ y: this.panelPresentationOffsetY })
      .animation({ duration: 320, curve: curves.springMotion(0.46, 0.86) })
      .transition(TransitionEffect.asymmetric(
        TransitionEffect.OPACITY.animation({ duration: 260, curve: curves.springMotion(0.46, 0.86) })
          .combine(TransitionEffect.translate({ x: -22, y: 0 }).animation({ duration: 320, curve: curves.springMotion(0.46, 0.86) })),
        TransitionEffect.OPACITY.animation({ duration: 190, curve: Curve.EaseIn })
          .combine(TransitionEffect.translate({ x: -14, y: 0 }).animation({ duration: 220, curve: Curve.EaseIn }))
      ))
  }

  @Builder
  compactPanel() {
    Column() {
      PanelHandle({ onDrag: (offsetY: number) => { this.updateCompactPanelDrag(offsetY) }, onDragFinish: () => { this.settleCompactPanelDrag() } })
      PanelHeader({
        title: panelTitleFor(this.activePanel, this.configTab, this.isExpandedLayout, this.timeStore.timePanelClockText()), subtitle: this.timeStore.panelSubtitle(this.activePanel), canGoBack: this.canGoBackPanel(),
        routeOpacity: this.panelRouteOpacity, routeOffsetX: this.panelRouteOffsetX,
        onBack: () => { this.handlePanelBackTap() },
        onClose: () => { this.closePanel(true); this.resetPanelIdle() }
      })
      Scroll(this.compactPanelScroller) {
        Column() {
          Column() {
            this.panelContent()
          }
            .width('100%')
            .opacity(this.panelRouteOpacity)
            .translate({ x: this.panelRouteOffsetX, y: 0 })
        }
          .width('100%')
          .padding({ bottom: 34 })
          .id('panel-content-' + this.i18nLang)
      }
        .width('100%')
        .layoutWeight(1)
        .id('panel-scroll-' + this.i18nLang)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .onAppear(() => { this.resetPanelScroll(this.compactPanelScroller) })
    }
      .width(this.isFoldHoverLayout ? '64%' : '94%')
      .height(this.compactPanelHeight())
      .padding({ top: 12, left: this.compactPanelHorizontalPadding(), right: this.compactPanelHorizontalPadding(), bottom: 16 })
      .backgroundColor(this.panelIdleGlass ? 'rgba(10, 14, 26, 0.55)' : 'rgba(18, 22, 36, 0.82)')
      .backdropBlur(this.panelIdleGlass ? 45 : 30)
      .border({ width: 0.5, color: this.panelIdleGlass ? 'rgba(91, 147, 191, 0.18)' : 'rgba(91, 147, 191, 0.12)' })
      .borderRadius(UI_RADIUS_SHEET)
      .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.32)', offsetX: 0, offsetY: 14 })
      .margin({ bottom: 10 })
      .hitTestBehavior(HitTestMode.Default)
      .onTouch((event: TouchEvent) => { this.notePanelTouch(event) })
      .alignSelf(ItemAlign.Center)
      .scale({ x: this.panelIdleOpacity < 1 ? 0.98 : 1.0, y: this.panelIdleOpacity < 1 ? 0.98 : 1.0 })
      .opacity(this.panelIdleOpacity * this.panelPresentationOpacity)
      .translate({ y: this.panelPresentationOffsetY })
      .animation({ duration: 320, curve: curves.springMotion(0.46, 0.86) })
  }

  @Builder
  panelContent() {
    if (this.activePanel === 'more') {
      MorePanel({
        actions: moreActions(),
        languageRevision: this.languageStore.languageRevision,
        startsSection: (item: ShellAction, index: number) => this.moreActionStartsSection(item, index),
        onOpenPanel: (panel: string) => { this.openSubPanel(panel) }
      })
    } else if (this.activePanel === 'observeHub') {
      HubActionList({
        actions: observingHubActions(), description: I18n.t('more_workspace_observing_desc'),
        subColor: this.nightModeStore.nmSub(), languageRevision: this.languageStore.languageRevision,
        onOpenPanel: (panel: string) => { this.openSubPanel(panel) }
      })
    } else if (this.activePanel === 'dataHub') {
      HubActionList({
        actions: skyDataHubActions(), description: I18n.t('more_sky_data_desc'),
        subColor: this.nightModeStore.nmSub(), languageRevision: this.languageStore.languageRevision,
        onOpenPanel: (panel: string) => { this.openSubPanel(panel) }
      })
    } else if (this.activePanel === 'automationHub') {
      HubActionList({
        actions: automationHubActions(), description: I18n.t('more_automation_desc'),
        subColor: this.nightModeStore.nmSub(), languageRevision: this.languageStore.languageRevision,
        onOpenPanel: (panel: string) => { this.openSubPanel(panel) }
      })
    } else if (this.activePanel === 'object') {
      ObjectPanel({
        objectDetailStore: this.objectDetailStore,
        objectMediaStore: this.objectMediaStore,
        telescopeStore: this.telescopeStore,
        fullInspectorRequested: this.fullInspectorRequested,
        viewLock: this.viewSettingsStore.viewLock,
        speechStatus: this.guideStore.speechStatus,
        observingListStore: this.obsListStore,
        isPlannedModel: this.objectDetailStore.selectedDetailModel !== undefined && this.objectDetailStore.selectedDetailModel.state === 'planned',
        imageHeight: this.objectMediaStore.objectInspectorImageHeight(),
        iconName: this.objectDetailStore.objectInspectorIcon(),
        inlineModelSize: this.objectInspectorInlineModelSize(),
        modelReady: this.objectModelRendererCtl().modelReady(),
        modelRendering: this.objectModelRendererCtl().isRendering(),
        hasModelTexture: this.objectModelRendererCtl().hasTexture(),
        modelNotice: this.objectMediaStore.objectInspectorModelNotice(),
        warmupText: this.objectMediaStore.objectInspectorMediaWarmupText(),
        fallbackKind: objectInspectorFallbackVisualKind(this.objectDetailStore.selectedObjectType, this.objectDetailStore.selectedType),
        starColor: objectInspectorStarColor(this.objectDetailStore.selectedTemperatureK),
        satVisible: this.objectDetailStore.selectedObjectIsArtificialSatellite(),
        tleEpoch: this.objectDetailStore.selectedSatelliteTleEpoch(),
        textColor: this.nightModeStore.nmText(),
        panelColor: this.nightModeStore.nmBg(),
        borderTint: this.nightModeStore.nmBorder(),
        accentColor: this.nightModeStore.nmAccent(),
        nameOf: (raw: string) => zhNameOf(raw),
        typeOf: (type: string) => zhType(type),
        statusOf: (en: string) => this.selectedStatusZh(en),
        displayValue: (key: string) => this.selectedDisplayValue(key),
        onChip: (id: string) => { this.handleChip(id) },
        onToggleObserving: () => {
          if (this.obsListStore.observingList.includes(this.objectDetailStore.selectedName)) {
            this.obsListStore.observingList = this.obsListStore.observingList.filter((item: string) => item !== this.objectDetailStore.selectedName)
            this.flashHint(I18n.t('i0079'))
          } else {
            this.obsListStore.observingList = this.obsListStore.observingList.concat([this.objectDetailStore.selectedName])
            this.flashHint(I18n.t('i0080'))
          }
          this.persistObservingList()
        },
        onGotoReselect: () => { this.triggerAction('actionGoto_ReSelect_Last_Selected_Object') },
        onSpeak: () => { speakSelectedObject(this.commandPort(), { flashHint: (text: ResourceStr): void => this.flashHint(text), setSpeechStatus: (text: string): void => { this.guideStore.speechStatus = text } }) },
        onOpenMedia: () => { this.openObjectInspectorMediaPreview() },
        onRetryMedia: () => { this.retryObjectInspectorMedia() },
        onModelExpand: () => { this.objectModelRendererCtl().setObjectInspectorModelImmersive(true) },
        onModelTouch: (event: TouchEvent) => { this.objectModelRendererCtl().handleObjectInspectorModelTouch(event) },
        onLoadSatPasses: () => { this.objectDetailStore.loadSelectedSatellitePasses() },
        onGoto: () => { this.lx200GotoSelected() },
        onSync: () => { this.lx200SyncSelected() },
        onAbort: () => { this.lx200Abort() }
      })
    } else if (this.activePanel === 'time') {
      // 观测时间/速率已移入面板标题栏副标题（panelSubtitle() 在 Builder 内直接读 @State，
      // 不经参数传递，变化可正常触发重建）；面板首屏直接给时间转轴与时间控制按钮
      // Sky Guide 风格时间拖动滑块（-365天 ~ +365天）：置于面板最前，手机端打开即可直接拖动
      TimePanel({
        timeWheelStore: this.timeWheelStore,
        timeStore: this.timeStore,
        equationOfTimeStore: this.equationOfTimeStore,
        julianStore: this.julianStore,
        nightModeStore: this.nightModeStore,
        atmosphereStore: this.atmosphereStore,
        manualYear: this.timeStore.manualYear,
        manualMonth: this.timeStore.manualMonth,
        manualDay: this.timeStore.manualDay,
        manualHour: this.timeStore.manualHour,
        manualMinute: this.timeStore.manualMinute,
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        accentColor: this.nightModeStore.nmAccent(),
        panelColor: this.nightModeStore.nmBg(),
        inputColor: this.nightModeStore.nmInput(),
        borderTint: this.nightModeStore.nmBorder(),
        onSelectUnit: (unit: string) => { this.wheel().selectUnit(unit) },
        onWheelTouch: (event: TouchEvent) => { this.wheel().handleTouch(event) },
        onChip: (id: string) => { this.handleChip(id) },
        onEquationToggle: (setting: string, enabled: boolean) => { this.setEquationOfTime(setting, enabled) },
        onAdjustJulian: (scale: string, direction: number) => { this.adjustJulianDate(scale, direction) },
        onApplyJulian: (scale: string) => { this.applyJulianDateInput(scale) },
        onNightMode: (enabled: boolean) => { this.applyNightMode(enabled, true) },
        onAtmosphere: (pressure: number, temperature: number, extinction: number) => { this.applyAtmosphere(pressure, temperature, extinction) },
        onPickDate: (year: number, monthIndex: number, day: number) => {
          this.timeStore.manualYear = year; this.timeStore.manualMonth = monthIndex + 1; this.timeStore.manualDay = day
        },
        onPickTime: (hour: number, minute: number) => { this.timeStore.manualHour = hour; this.timeStore.manualMinute = minute },
        onApplyManual: () => { this.applyManualTime() },
        onResetManual: () => { this.syncManualTimeFromState(); this.flashHint(I18n.t('i0081')) }
      })
    } else if (this.activePanel === 'place') {
      PlacePanel({
        locationPickerStore: this.locationPickerStore,
        locationStore: this.locationStore,
        sessionToolStore: this.sessionToolStore,
        locationText: this.locationText,
        coordinateText: this.coordinateText,
        altitudeText: this.altitudeText,
        expandedLayout: this.isExpandedLayout,
        skyWidth: this.skyWidth,
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        inputColor: this.nightModeStore.nmInput(),
        accentColor: this.nightModeStore.nmAccent(),
        panelColor: this.nightModeStore.nmBg(),
        borderTint: this.nightModeStore.nmBorder(),
        planetLabel: (en: string) => planetZh(en),
        contextOf: (item: LocSearchItem) => this.locationPickerStore.locationResultContext(item, this.sessionToolStore.observerPlanet),
        onUseDeviceLocation: () => { this.locationCtl().useDeviceLocation() },
        onSearchLocations: (query: string) => { this.locationStore.searchLocations(query) },
        onPickSearchItem: (item: LocSearchItem) => { this.locationStore.selectSearchLocation(item) },
        onApply: () => { this.locationCtl().applyPickerLocation() },
        onSelectContinent: (c: string) => { this.selectContinent(c) },
        onSelectCountry: (c: string) => { this.selectCountry(c) },
        onSelectRegion: (r: string) => { this.selectRegion(r) },
        onSelectCity: (c: string) => { this.selectCityByName(c) },
        onSaveCurrent: () => { this.locationStore.saveCurrentLocation() },
        onApplyLocation: (name: string, lat: number, lon: number, alt: number, planet: string) => { this.locationCtl().setLocation(name, lat, lon, alt, planet) },
        onDeleteLocation: (name: string) => { this.locationStore.deleteSavedLocation(name) },
        onChip: (id: string) => { this.handleChip(id) },
        onSelectPlanet: (name: string) => { this.locationCtl().setObserverPlanet(name) },
        onPoint: () => { this.pointAtSkyTest() },
        onSend: () => { this.gyroCtl().watchGyroSend() },
        onStart: () => { this.gyroCtl().watchGyroStart() },
        onStop: () => { this.gyroCtl().watchGyroStop() },
        onExport: () => { this.sessionToolStore.sessionExport() },
        onSessionApply: () => { this.sessionToolStore.sessionApply() },
        onHandoff: () => { this.sessionToolStore.sessionHandoff() },
        onRefreshTonight: () => { this.refreshTonight() },
        onJump: (jd: number, lock: string, title: string) => { this.gotoTonightEvent(jd, lock, title) }
      })
    } else if (this.activePanel === 'layers') {
      LayersPanel({
        layerStore: this.layerStore,
        layerViewStore: this.layerViewStore,
        skyCultureViewStore: this.skyCultureViewStore,
        skyCultureSettingsStore: this.skyCultureSettingsStore,
        nightModeOn: this.nightModeStore.nightMode,
        viewTab: this.viewTab,
        expandedLayout: this.isExpandedLayout,
        foldTablet: this.isFoldTabletLayout,
        viewTabContentOpacity: this.viewTabContentOpacity,
        viewTabContentOffsetX: this.viewTabContentOffsetX,
        layerTabs: this.layerTabItems(),
        skyCultureArtStates: this.skyCultureArtStates,
        skyCultureArtThumbnailPixelMaps: this.skyCultureArtThumbnailPixelMaps,
        narrationParagraphs: this.skyCultureViewStore.skyCultureNarrationParagraphs(),
        mapContext: this.skyCultureMapContext,
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        accentColor: this.nightModeStore.nmAccent(),
        panelColor: this.nightModeStore.nmBg(),
        cardBorder: this.nightModeStore.nmBorder(),
        inputColor: this.nightModeStore.nmInput(),
        pickerSurface: this.nightModeStore.nmPickerSurface(),
        pickerHeader: this.nightModeStore.nmPickerHeader(),
        pickerHeaderActive: this.nightModeStore.nmPickerHeaderActive(),
        pickerSelected: this.nightModeStore.nmPickerSelected(),
        pickerOption: this.nightModeStore.nmPickerOption(),
        onPreset: (preset: string) => { this.applyLayerPreset(preset) },
        onClear: () => { this.clearMarkingLayers() },
        onSelectTab: (id: number) => { this.selectViewTab(id) },
        onToggleLayer: (actionId: string, cmd: string, value: boolean) => { this.applyLayerSwitch(actionId, cmd, value) },
        onSetSkyDisplay: (setting: string, value: boolean | number) => { this.setSkyDisplaySetting(setting, value) },
        onStarMagLimit: (value: number) => { this.applyStarMagLimit(value) },
        onMilkyWayBright: (value: number) => { this.applyMilkyWayBright(value) },
        onSetOrbitFlag: (setting: string, enabled: boolean) => { this.setOrbitDisplayFlag(setting, enabled) },
        onSetOrbitThickness: (value: number) => { this.setOrbitDisplayThickness(value) },
        onSetOrbitColorStyle: (index: number) => { this.setOrbitColorStyle(index) },
        onLoadOrbitSettings: () => { this.layerViewStore.loadOrbitDisplaySettings() },
        onSetTrailFlag: (setting: string, enabled: boolean) => { this.setTrailDisplayFlag(setting, enabled) },
        onSetTrailNumber: (setting: string, value: number) => { this.setTrailDisplayNumber(setting, value) },
        onLoadTrailSettings: () => { this.layerViewStore.loadTrailDisplaySettings() },
        onApplyTrailColor: () => { this.applyTrailColor() },
        onTriggerAction: (actionId: string) => { this.triggerAction(actionId) },
        onSetFovMarker: (setting: string, value: number) => { this.setFovMarkerSetting(setting, value) },
        onSetLandscapeFadeWithZoom: (isOn: boolean) => { this.setLandscapeFadeWithZoom(isOn) },
        onImportLandscape: () => { this.importLandscapeFile() },
        onSelectLandscape: (id: string, name: string) => { this.selectLandscape(id, name) },
        onChangeLandscapeTransparency: (val: number) => { this.changeLandscapeTransparency(val) },
        onLoadList: () => { this.skyCultureViewStore.loadSkyCultureList() },
        onSelectCulture: (id: string) => { this.selectSkyCulture(id) },
        onRowArea: (id: string, area: Area) => { this.handleSkyCultureRowArea(id, area) },
        onReloadList: () => { this.callInteractive('reloadSkyCulture', '', () => { this.skyCultureViewStore.loadSkyCultureList() }) },
        onSelectLabelMode: (target: string, index: number) => { this.selectSkyCultureLabelMode(target, index) },
        onSetShortLabels: (enabled: boolean) => { this.setSkyCultureShortLabels(enabled) },
        onSetCommonNames: (enabled: boolean) => { this.setSkyCultureCommonNames(enabled) },
        onSetIsolation: (enabled: boolean) => { this.setSkyCultureConstellationIsolation(enabled) },
        onSetSinglePick: (enabled: boolean) => { this.setSkyCultureConstellationSinglePick(enabled) },
        onConstellationSelection: (actionId: string, hint: string) => { this.applySkyCultureConstellationSelection(actionId, hint) },
        onSetStyleOption: (target: string, optionIndex: number, enabled: boolean) => { this.setSkyCultureStyleOption(target, optionIndex, enabled) },
        getColorOptions: () => this.skyCultureColorOptions(),
        onSetVisualColor: (setting: string, color: string) => { this.setSkyCultureVisualColor(setting, color) },
        onSetVisualSetting: (setting: string, value: number) => { this.setSkyCultureVisualSetting(setting, value) },
        onSetDefault: () => { this.setCurrentSkyCultureAsDefault() },
        onSyncTimeFollowTimer: () => { this.syncSkyCultureTimeFollowTimer() },
        onRefreshSimulationYear: () => { this.refreshSkyCultureSimulationYear(true) },
        onLoadTerritoryMap: () => { this.skyCultureSettingsStore.loadSkyCultureTerritoryMap() },
        onMapReady: () => { this.drawSkyCultureTerritoryMap() },
        onMapAreaChange: (width: number, height: number) => { this.skyCultureMapRenderWidth = width; this.skyCultureMapRenderHeight = height; this.drawSkyCultureTerritoryMap() },
        onLoadObserverInfo: (force: boolean) => { this.locationPickerStore.loadObserverInfo(force) },
        onArtDecodeError: (rawPath: string) => { this.setSkyCultureArtStatus(rawPath, 'decodeFailed') },
        onOpenArtPreview: (art: SkyCultureArtItem) => { this.openSkyCultureArtPreview(art) }
      })
    } else if (this.activePanel === 'pointerCoordinates') {
      PointerCoordinatesPanel({
        store: this.overlayStore,
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        accentColor: this.nightModeStore.nmAccent(),
        panelColor: this.nightModeStore.nmBg(),
        lineColor: this.nightModeStore.nmBorder(),
        onSetSetting: (setting: string, value: string) => { this.setPointerCoordinates(setting, value) }
      })
    } else if (this.activePanel === 'commands') {
      CommandsPanel({
        commandStore: this.commandStore,
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        inputColor: this.nightModeStore.nmInput(),
        accentColor: this.nightModeStore.nmAccent(),
        panelColor: this.nightModeStore.nmBg(),
        onSearchTextChange: (value: string) => { this.commandStore.commandSearchText = value },
        onNameInputChange: (value: string) => { this.commandStore.commandNameInput = value; this.commandStore.commandPendingConfirmation = '' },
        onPayloadInputChange: (value: string) => { this.commandStore.commandPayloadInput = value },
        onSelectEntry: (item: CommandCatalogEntry) => { this.selectCommandEntry(item) },
        onRefreshCatalog: () => { this.commandStore.loadCommandCatalog() },
        onExecute: (force: boolean) => { this.executeCommandFromPanel(force) }
      })
    } else if (this.activePanel === 'settings_quick_legacy') {
      SettingsQuickLegacyPanel({
        gyroStore: this.gyroStore,
        overlayStore: this.overlayStore,
        nightModeStore: this.nightModeStore,
        telescopeStore: this.telescopeStore,
        viewSettingsStore: this.viewSettingsStore,
        liveMode: this.viewSettingsStore.liveMode,
        fovSliderValue: this.fovSliderValue,
        currentProjection: this.currentProjection,
        selectedLanguage: this.languageStore.selectedLanguage,
        skyCultureViewStore: this.skyCultureViewStore,
        satelliteCatalogHealth: this.satelliteStore.satelliteCatalogHealth,
        starCatalogHealth: this.catalogStore.starCatalogHealth,
        gyroSensitivityText: sensZh(this.gyroStore.gyroscopeSensitivityText),
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        accentColor: this.nightModeStore.nmAccent(),
        panelColor: this.nightModeStore.nmBg(),
        lineColor: this.nightModeStore.nmBorder(),
        onToggleGyroscope: (v: boolean) => { this.gyroCtl().toggleGyroscope(v); this.flashHint(v ? I18n.t('s0719') : I18n.t('s0720')) },
        onRevoke: () => { this.confirmPrivacyRevocation() },
        onToggleVisible: (visible: boolean) => { this.setViewCoordinatesVisible(visible) },
        onSelectFamily: (family: string) => { this.setViewCoordinateFamily(family) },
        onSelectEpoch: (epoch: string) => { this.setViewEquatorialEpoch(epoch) },
        onApplyLayerSwitch: (actionId: string, cmd: string, value: boolean) => { this.applyLayerSwitch(actionId, cmd, value) },
        onSpeedDown: () => { this.speedDown() },
        onTogglePause: () => { this.togglePause() },
        onSpeedUp: () => { this.speedUp() },
        onFovChange: (val: number) => { this.fovSliderValue = Math.round(val); this.changeFovBySlider(val) },
        onSetProjection: (name: string) => { this.setProjection(name) },
        onSetLanguage: (lang: string) => { this.setLanguage(lang) },
        onSetSkyCulture: (name: string) => { this.setSkyCulture(name) },
        onSetUnits: (metric: boolean) => { this.viewSettingsStore.useMetricUnits = metric; this.callInteractive('setConfigString', 'astronomy/flag_use_km_for_distance=' + metric, () => {}) },
        catalogHealthTextOf: (title: string, health: CatalogHealthEntry) => this.catalogHealthText(title, health),
        catalogHealthColorOf: (health: CatalogHealthEntry) => this.catalogHealthColor(health)
      })
    } else if (this.activePanel === 'search') {
      SearchPanel({
        store: this.searchStore,
        languageRevision: this.languageStore.languageRevision,
        visibilityLabel: this.searchStore.searchVisibilityLabel(),
        instrumentLabel: this.searchStore.searchInstrumentLabel(),
        categories: this.catalogStore.searchAllCategoryOptions(),
        categoryIconKey: this.catalogStore.searchCategoryIcon(this.searchStore.searchCategory),
        categoryLabel: this.catalogStore.searchCategoryLabel(this.searchStore.searchCategory),
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        panelColor: this.nightModeStore.nmBg(),
        inputColor: this.nightModeStore.nmInput(),
        scroller: this.searchPanelScroller,
        onInput: (value: string) => { this.scheduleSuggestions(value.trim()) },
        onSubmit: (text: string) => {
          if (this.searchSuggestionTimer >= 0) {
            clearTimeout(this.searchSuggestionTimer)
            this.searchSuggestionTimer = -1
          }
          this.searchObject(text)
          this.searchStore.searchSuggestions = []
        },
        onInputFocus: () => {
          // 手机上把候选结果留在软键盘之上；用户仍可把面板拖回 6/10 吸附点。
          if (!this.isExpandedLayout && !this.isFoldHoverLayout && this.compactPanelSnapRatio < 0.9) {
            this.getUIContext().animateTo({ duration: 260, curve: curves.springMotion(0.48, 0.90) }, () => {
              this.compactPanelSnapRatio = 0.9
              this.compactPanelDragOffsetY = 0
            })
            this.scheduleSelectedObjectForUiChange(300)
          }
        },
        onSetPage: (page: string) => { this.setSearchFilterPage(page) },
        onSelectCategory: (code: string) => { this.selectSearchFilterCategory(code) },
        onSelectVisibility: (filter: string) => { this.selectSearchVisibilityFilter(filter) },
        onSelectInstrument: (filter: string) => { this.selectSearchInstrumentFilter(filter) },
        suggestionSubtitle: (title: string, englishName: string) => { return this.searchStore.celestialSubtitle(title, englishName) },
        onSelectSuggestion: (item: SearchSug) => { this.selectSearchSuggestion(item) },
        iconFor: (item: NameItem) => { return this.catalogStore.categoryObjectIcon(item, this.searchStore.searchCategory) },
        categorySubtitle: (item: NameItem) => { return this.searchStore.categoryObservationSubtitle(item) },
        onOpenCategories: () => { this.setSearchFilterPage('categories') },
        onOpenFilters: () => { this.setSearchFilterPage('root') },
        onRetry: () => { this.searchStore.loadCategoryObjects(this.searchStore.searchCategory) },
        onLoadMore: () => { this.searchStore.loadMoreCategoryObjects() },
        onSelectCategoryObject: (item: NameItem) => {
          if (this.searchStore.searchCategory === 'constellation') {
            this.openConstellationGuide(item.name ?? '', this.searchStore.categoryModuleId)
          } else {
            this.searchObject(item.name ?? '', this.searchStore.categoryModuleId)
          }
        },
        onClearVisibility: () => { this.selectSearchVisibilityFilter('all') },
        onClearInstrument: () => { this.selectSearchInstrumentFilter('all') },
        onOpenConstellation: (item: ConstellationNavigationItem) => { this.openConstellationGuide(item.englishName, 'ConstellationMgr', item.localizedName) },
        onGoCoordinates: () => { this.goToCoordinates() }
      })
    } else if (this.activePanel === 'settings') {
      SettingsPanel({
        gyroStore: this.gyroStore,
        overlayStore: this.overlayStore,
        deltaTStore: this.deltaTStore,
        timeSettingsStore: this.timeSettingsStore,
        ephemerisStore: this.ephemerisStore,
        navigationStore: this.navigationStore,
        viewSettingsStore: this.viewSettingsStore,
        scroller: this.scriptListScroller,
        configTab: this.configTab,
        configTabContentOpacity: this.configTabContentOpacity,
        configTabContentOffsetX: this.configTabContentOffsetX,
        i18nLang: this.i18nLang,
        selectedLanguage: this.languageStore.selectedLanguage,
        isExpandedLayout: this.isExpandedLayout,
        informationMode: this.infoWindowStore.informationMode,
        informationSettingPending: this.infoWindowStore.informationSettingPending,
        currentProjection: this.currentProjection,
        configDitheringMode: this.viewSettingsStore.configDitheringMode,
        timeSettingsPending: this.timeSettingsPending,
        observationTimeText: this.timeStore.observationTimeText,
        scriptLaunching: this.scriptStore.scriptLaunching,
        scriptLaunchingName: this.scriptStore.scriptLaunchingName,
        scriptList: this.scriptStore.scriptList,
        pluginStore: this.pluginStore,
        fovText: this.fovText,
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        accentColor: this.nightModeStore.nmAccent(),
        panelColor: this.nightModeStore.nmBg(),
        lineColor: this.nightModeStore.nmBorder(),
        inputColor: this.nightModeStore.nmInput(),
        informationMaskHas: (key: string) => { return this.infoWindowStore.informationMaskHas(key) },
        pluginMetaLine: (plugin: PluginItem) => { return this.pluginMetaLine(plugin) },
        pluginFeatureDestination: (id: string) => { return this.pluginFeatureDestination(id) },
        pluginFeatureIsActionable: (id: string) => { return this.pluginFeatureIsActionable(id) },
        pluginFeatureActionLabel: (id: string) => { return this.pluginFeatureActionLabel(id) },
        scriptMetaLine: (filename: string) => { return this.scriptStore.scriptMetaLine(filename) },
        scriptSourceLine: (filename: string) => { return this.scriptStore.scriptSourceLine(filename) },
        hasSelectedObject: () => { return this.objectDetailStore.hasSelectedObject() },
        selectConfigTab: (tabId: number) => { this.selectConfigTab(tabId) },
        setViewCoordinatesVisible: (visible: boolean) => { this.setViewCoordinatesVisible(visible) },
        setViewCoordinateFamily: (family: string) => { this.setViewCoordinateFamily(family) },
        setViewEquatorialEpoch: (epoch: string) => { this.setViewEquatorialEpoch(epoch) },
        setLanguage: (lang: string) => { this.setLanguage(lang) },
        setEphemerisEnabled: (key: string, available: boolean, enabled: boolean) => { this.setEphemerisEnabled(key, available, enabled) },
        setDistanceUnit: (useMetric: boolean) => { this.setDistanceUnit(useMetric) },
        setConfigurationDithering: (value: string) => { this.setConfigurationDithering(value) },
        setProjection: (name: string) => { this.setProjection(name) },
        saveAppSettings: () => { this.saveAppSettings() },
        flashHint: (text: ResourceStr) => { this.flashHint(text) },
        saveAllCoreSettings: () => { this.saveAllCoreSettings() },
        restoreCoreDefaults: () => { this.restoreCoreDefaults() },
        saveCurrentViewAsStartup: () => { this.startupBridge().saveCurrentViewAsStartup() },
        setViewLockState: (enabled: boolean) => { this.setViewLockState(enabled) },
        setNavigationBoolean: (setting: string, enabled: boolean) => { this.setNavigationBoolean(setting, enabled) },
        setNavigationMaxFov: (value: number) => { this.setNavigationMaxFov(value) },
        selectSettingsChoice: (group: string, value: string) => { this.selectSettingsChoice(group, value) },
        setStartupTimeSetting: (key: string, value: string) => { this.setStartupTimeSetting(key, value) },
        setInformationField: (key: string, enabled: boolean) => { this.setInformationField(key, enabled) },
        setObjectDetailConnector: (enabled: boolean) => { this.setObjectDetailConnector(enabled) },
        toggleGyroscope: (enabled: boolean) => { this.gyroCtl().toggleGyroscope(enabled) },
        confirmPrivacyRevocation: () => { this.confirmPrivacyRevocation() },
        loadPluginList: () => { this.pluginStore.loadPluginList() },
        openPluginFeature: (id: string) => { this.openPluginFeature(id) },
        playScriptByName: (filename: string) => { this.scriptStore.playScriptByName(filename) },
        triggerAction: (actionId: string) => { this.triggerAction(actionId) },
        moveToSelectedObject: () => { this.moveToSelectedObject() },
        onOpenLayersSky: () => { this.viewTab = 0; this.openSubPanel('layers') },
        onOpenTools: () => { this.openSubPanel('tools') }
      })
    } else if (this.activePanel === 'astro') {
      AstroPanel({
        store: this.astroStore,
        wutStore: this.wutStore,
        objectDetailStore: this.objectDetailStore,
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        panelColor: this.nightModeStore.nmBg(),
        accentColor: this.nightModeStore.nmAccent(),
        lineColor: this.nightModeStore.nmBorder(),
        scroller: this.astroPanelScroller,
        host: {
          almanacHoursLabel: (key: string) => this.astroStore.almanacHoursLabel(key),
          altAzMaxLabel: () => this.astroStore.altAzMaxLabel(),
          altAzMidpointLabel: () => this.astroStore.altAzMidpointLabel(),
          altAzNowLabel: () => this.astroStore.altAzNowLabel(),
          altAzRangeLabel: () => this.astroStore.altAzRangeLabel(),
          altAzVisibleHours: () => this.astroStore.altAzVisibleHours(),
          altBarHeight: (alt: number | undefined) => this.astroStore.altBarHeight(alt),
          altBarWidth: () => this.astroStore.altBarWidth(),
          altCurveSegmentWidth: () => this.astroStore.altCurveSegmentWidth(),
          altitudeCurveColor: (altitude: number | undefined, color: string) => this.astroStore.altitudeCurveColor(altitude, color),
          annualBarHeight: (altitude: number | undefined) => this.astroStore.annualBarHeight(altitude),
          annualBarWidth: () => this.astroStore.annualBarWidth(),
          annualMaxLabel: () => this.astroStore.annualMaxLabel(),
          astroNeedsSelectedObject: () => this.astroStore.astroNeedsSelectedObject(),
          azimuthNowLabel: () => this.astroStore.azimuthNowLabel(),
          callNative: (name: string, payload?: string) => { this.callNative(name, payload) },
          celestialPositionSubtitle: (position: CelestialPosition) => this.celestialPositionSubtitle(position),
          celestialPositionTitle: (position: CelestialPosition) => celestialTitle(position.name, position.englishName),
          chooseEclipseStartDate: () => { this.chooseEclipseStartDate() },
          chooseEphemerisStartDate: () => { this.chooseEphemerisStartDate() },
          chooseGraphStartDate: () => { this.chooseGraphStartDate() },
          chooseRtsCalendarStartDate: () => { this.chooseRtsCalendarStartDate() },
          eclipseStartOptionLabel: (offsetDays: number) => this.astroStore.eclipseStartOptionLabel(offsetDays),
          ephemerisStartOptionLabel: (offsetDays: number) => this.ephemerisStore.ephemerisStartOptionLabel(offsetDays),
          exportCurrentAstroCsv: () => this.exportCurrentAstroCsv(),
          filteredEclipses: () => this.astroStore.filteredEclipses(),
          fmtClock: (s: string | undefined) => this.fmtClock(s),
          fmtDateTime: (s: string | undefined) => this.fmtDateTime(s),
          fmtEphemerisDate: (s: string | undefined) => this.fmtEphemerisDate(s),
          fmtNum: (v: number | undefined, digits: number, suffix: string) => this.fmtNum(v, digits, suffix),
          graphCustomStartLabel: () => this.astroStore.graphCustomStartLabel(),
          graphTargetLabel: () => this.astroStore.graphTargetLabel(),
          hasSelectedObject: () => this.objectDetailStore.hasSelectedObject(),
          hecPointColor: (position: HeliocentricPosition) => hecPointColor(position, this.nightModeStore.nmAccent()),
          hecPointLeft: (position: HeliocentricPosition) => hecPointLeft(position),
          hecPointTop: (position: HeliocentricPosition) => hecPointTop(position),
          hecTitle: (position: HeliocentricPosition) => celestialTitle(position.name, position.englishName),
          jdToDateStr: (jd: string) => this.jdToDateStr(jd),
          jumpToAlmanacSeason: (event: SeasonEvent) => { this.jumpToAlmanacSeason(event) },
          jumpToEphemerisRow: (row: EphemerisRow) => { this.jumpToEphemerisRow(row) },
          jumpToMoonPhase: (item: MoonPhaseItem) => { this.jumpToMoonPhase(item) },
          jumpToObservabilityDay: (day: ObservabilityDay) => { this.jumpToObservabilityDay(day) },
          jumpToPhenomenon: (item: PhenomenonItem) => { this.jumpToPhenomenon(item) },
          jumpToRts: (key: string) => { this.jumpToRts(key) },
          jumpToRtsCalendar: (day: RtsCalendarDay) => { this.jumpToRtsCalendar(day) },
          jumpToWutTarget: (target: WutTarget) => { this.jumpToWutTarget(target) },
          loadAlmanac: () => { this.astroStore.loadAlmanac() },
          loadAltAzCurve: () => { this.astroStore.loadAltAzCurve() },
          loadAnnualElevation: () => { this.astroStore.loadAnnualElevation() },
          loadCelestialPositions: () => { this.astroStore.loadCelestialPositions() },
          loadEclipses: () => { this.astroStore.loadEclipses() },
          loadEphemeris: () => { this.astroStore.loadEphemeris() },
          loadHeliocentricPositions: () => { this.astroStore.loadHeliocentricPositions() },
          loadLunarElongation: () => { this.astroStore.loadLunarElongation() },
          loadMoonPhases: () => { this.astroStore.loadMoonPhases() },
          loadObservabilityCalendar: () => { this.astroStore.loadObservabilityCalendar() },
          loadPhenomena: () => { this.astroStore.loadPhenomena() },
          loadPlanetCalc: () => { this.astroStore.loadPlanetCalc() },
          loadPlanetPairDistance: () => { this.astroStore.loadPlanetPairDistance() },
          loadPlanetPositions: () => { this.loadPlanetPositions() },
          loadPlanetTimeSeries: () => { this.astroStore.loadPlanetTimeSeries() },
          loadPlanetaryTransits: () => { this.astroStore.loadPlanetaryTransits() },
          loadRTS: () => { this.astroStore.loadRTS() },
          loadRtsCalendar: () => { this.astroStore.loadRtsCalendar() },
          loadTonightAstro: () => { this.astroStore.loadTonightAstro() },
          loadWutTargets: () => { this.wutStore.loadWutTargets() },
          lunarElongationBarWidth: () => this.astroStore.lunarElongationBarWidth(),
          lunarElongationClosestLabel: () => this.astroStore.lunarElongationClosestLabel(),
          lunarElongationLineTop: () => this.astroStore.lunarElongationLineTop(),
          lunarElongationNowLabel: () => this.astroStore.lunarElongationNowLabel(),
          markRtsCalendarForRegeneration: () => { this.astroStore.markRtsCalendarForRegeneration() },
          openAstroTargetPicker: () => { this.openAstroTargetPicker() },
          openEphemerisTargetPicker: () => { this.openEphemerisTargetPicker() },
          openGraphTargetPicker: () => { this.openGraphTargetPicker() },
          openRtsTargetPicker: () => { this.openRtsTargetPicker() },
          phenomenaBodyName: (body: string) => this.astroStore.phenomenaBodyName(body),
          planetPairBarWidth: () => this.astroStore.planetPairBarWidth(),
          planetPairCurrentIndex: () => this.astroStore.planetPairCurrentIndex(),
          planetPairSegmentWidth: () => this.astroStore.planetPairSegmentWidth(),
          planetTimeSeriesBarWidth: () => this.astroStore.planetTimeSeriesBarWidth(),
          planetTimeSeriesSegmentWidth: () => this.astroStore.planetTimeSeriesSegmentWidth(),
          planetTimeSeriesValueLabel: (value: number | undefined, metric: string) => this.planetTimeSeriesValueLabel(value, metric),
          publishAstroPanelState: () => { this.publishAstroPanelState() },
          reloadCurrentGraph: () => { this.reloadCurrentGraph() },
          reloadEclipses: () => { this.astroStore.reloadEclipses() },
          rtsCalendarStartOptionLabel: (offsetDays: number) => this.astroStore.rtsCalendarStartOptionLabel(offsetDays),
          searchObject: (name: string, catalogModuleId?: string, exactSelectionPayload?: string, placement?: string) => { this.searchObject(name, catalogModuleId, exactSelectionPayload, placement) },
          selectAstroFilter: (key: string, value: string) => { this.selectAstroFilter(key, value) },
          selectAstroGroup: (group: number) => { this.selectAstroGroup(group) },
          selectAstroTab: (tab: number) => { this.selectAstroTab(tab) },
          wutCategoryTitle: () => this.wutStore.wutCategoryTitle(),
          wutTargetSubtitle: (target: WutTarget) => this.searchStore.wutTargetSubtitle(target),
          wutTargetTitle: (target: WutTarget) => this.wutTargetTitle(target),
        }
      })
        } else if (this.activePanel === 'help') {
      HelpPanel({
        tools: this.tools,
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        lineColor: this.nightModeStore.nmBorder(),
        accentColor: this.nightModeStore.nmAccent(),
        panelColor: this.nightModeStore.nmBg(),
        onOpenTools: () => { this.openSubPanel('tools') }
      })
	    } else if (this.activePanel === 'catalogs') {
      CatalogsPanel({
        catalogStore: this.catalogStore,
        cardBorderColor: this.nightModeStore.nmBorder(),
        onDownload: (id: string) => { this.startCatalogDownload(id) }
      })
    } else if (this.activePanel === 'bookmarks') {
      BookmarkPanel({
        store: this.bookmarkStore,
        selectedName: this.objectDetailStore.selectedName,
        cardBorderColor: this.nightModeStore.nmBorder(),
        onSaveView: () => { this.addCurrentBookmark() },
        onGoto: (id: string) => { this.gotoBookmark(id) },
        onDelete: (id: string) => { this.deleteBookmark(id) }
      })
    } else if (this.activePanel === 'oculars') {
      OcularsPanel({
        store: this.telescopeStore,
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        accentColor: this.nightModeStore.nmAccent(),
        panelColor: this.nightModeStore.nmBg(),
        lineColor: this.nightModeStore.nmBorder(),
        onOpenSubPanel: (name: string) => { this.openSubPanel(name) },
        onSetOcularMode: (isOn: boolean) => { this.setOcularMode(isOn) },
        onSetTelrad: (isOn: boolean) => { this.setTelrad(isOn) },
        onSetCrosshairs: (isOn: boolean) => { this.setCrosshairs(isOn) },
        onSetCcd: (isOn: boolean) => { this.setCCD(isOn) },
        onSelectInstrument: (kind: string, index: number) => { this.selectOcularInstrument(kind, index) },
        onChangeCcdRotation: (value: number, mode: SliderChangeMode) => { this.changeOcularCcdRotation(value, mode) },
        onChangePrismRotation: (value: number, mode: SliderChangeMode) => { this.changeOcularPrismRotation(value, mode) },
        onResetInstrument: (target: string) => { this.resetOcularInstrument(target) },
        onRotateReticle: (dir: string) => { this.rotateOcularReticle(dir) },
        onSetOcularSetting: (setting: string, isOn: boolean) => { this.setOcularSetting(setting, isOn) },
        onChangeMaskOpacity: (value: number, mode: SliderChangeMode) => { this.changeOcularMaskOpacity(value, mode) },
        onChangeCropSize: (setting: string, value: number, mode: SliderChangeMode) => { this.changeOcularCropSize(setting, value, mode) }
      })
    } else if (this.activePanel === 'mosaicCamera') {
      MosaicCameraPanel({
        mosaicStore: this.mosaicStore,
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        panelColor: this.nightModeStore.nmBg(),
        accentColor: this.nightModeStore.nmAccent(),
        onSetSetting: (setting: string, value: string) => { this.setMosaicCamera(setting, value) }
      })
    } else if (this.activePanel === 'archaeoLines') {
      ArchaeoLinesPanel({
        archaeoStore: this.archaeoStore,
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        panelColor: this.nightModeStore.nmBg(),
        accentColor: this.nightModeStore.nmAccent(),
        borderTint: this.nightModeStore.nmBorder(),
        onSetSetting: (setting: string, value: string) => { this.setArchaeoLineSetting(setting, value) },
        onLineWidthPreview: (value: number) => { this.archaeoStore.archaeoLineWidth = value },
        onSetLineWidth: (value: number) => { this.setArchaeoLineSetting('lineWidth', value.toString()) }
      })
    } else if (this.activePanel === 'angleMeasure') {
      AngleMeasurePanel({
        store: this.tools,
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        panelColor: this.nightModeStore.nmBg(),
        accentColor: this.nightModeStore.nmAccent(),
        onToggle: (enabled: boolean) => { this.tools.toggleAngleMeasure(enabled) },
        onReset: () => { this.resetAngleMeasure() }
      })
    } else if (this.activePanel === 'navStars') {
      NavStarsPanel({
        navStarsStore: this.navStarsStore,
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        panelColor: this.nightModeStore.nmBg(),
        accentColor: this.nightModeStore.nmAccent(),
        onSetSetting: (setting: string, value: string) => { this.navStarsStore.setNavStarsSetting(setting, value) }
      })
    } else if (this.activePanel === 'satellites') {
      SatellitesPanel({
        satelliteStore: this.satelliteStore,
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        panelColor: this.nightModeStore.nmBg(),
        inputColor: this.nightModeStore.nmInput(),
        accentColor: this.nightModeStore.nmAccent(),
        panelScroller: this.satellitePanelScroller,
        groupScroller: this.satelliteGroupScroller,
        onPublishState: () => { this.publishSatellitePanelState() },
        catalogHealthTextOf: (title: string, health: CatalogHealthEntry) => this.catalogHealthText(title, health),
        catalogHealthColorOf: (health: CatalogHealthEntry) => this.catalogHealthColor(health),
        onDeleteSource: (index: number) => { this.deleteSatelliteSource(index) },
        onSourceInput: (value: string) => { this.satelliteStore.satSourceInput = value },
        onSourceAddNew: (value: boolean) => { this.satelliteStore.satSourceAddNew = value },
        onAddSource: () => { this.addSatelliteSource() },
        onRefreshCatalog: () => { this.refreshSatelliteCatalog() },
        onTleFileInput: (value: string) => { this.satelliteStore.satTleFileInput = value },
        onImportTle: () => { this.importSatelliteTleFile() },
        onSetUpdateSetting: (key: string, value: boolean | number) => { this.setSatelliteUpdateSetting(key, value) },
        onUpdateFrequencyInput: (value: string) => { this.satelliteStore.satUpdateFrequencyInput = value },
        onSubmitUpdateFrequency: () => {
          const hours = Number(this.satelliteStore.satUpdateFrequencyInput)
          if (Number.isFinite(hours)) this.setSatelliteUpdateSetting('updateFrequencyHours', Math.round(hours))
        },
        onSetFlag: (flag: string, isOn: boolean) => { this.setSatelliteFlag(flag, isOn) },
        onSelectGroup: (group: string) => { this.selectSatelliteGroup(group) },
        onQueryChange: (value: string) => { this.satelliteStore.satQuery = value; this.satelliteStore.loadSatellites() },
        onSubmitQuery: () => { this.satelliteStore.loadSatellites(false, true) },
        onSearchObject: (item: SatelliteListItem) => { this.searchObject(item.name, '', 'object|Satellite|' + item.id) }
      })
    } else if (this.activePanel === 'meteorshowers') {
      MeteorShowersPanel({
        meteorStore: this.meteorStore,
        panelColor: this.nightModeStore.nmBg(),
        onSetFlag: (flag: string, value: boolean) => { this.meteorStore.setMeteorShowersFlag(flag, value) },
        onSearch: (name: string) => { this.searchObject(name, '', '', 'center') }
      })
    } else if (this.activePanel === 'scenery3d') {
      Scenery3dPanel({
        sceneryStore: this.sceneryStore,
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        panelColor: this.nightModeStore.nmBg(),
        accentColor: this.nightModeStore.nmAccent(),
        onToggleEnabled: (enabled: boolean) => { this.setScenery3dEnabled(enabled) },
        onSelectScene: (id: string) => { this.setScenery3dScene(id) }
      })
    } else if (this.activePanel === 'skyCultureMaker') {
      SkyCultureMakerPanel({
        store: this.skyCultureMakerStore,
        panelWidth: this.panelWidth,
        subColor: this.nightModeStore.nmSub(), textColor: this.nightModeStore.nmText(), accentColor: this.nightModeStore.nmAccent(), bgColor: this.nightModeStore.nmBg(),
        inputColor: this.nightModeStore.nmInput(), inputBorderColor: this.nightModeStore.nmInputBorder(),
        onEdited: () => { this.scheduleSkyCultureMakerSave() },
        onAdd: () => { this.addSkyCultureMakerConstellation() },
        onSelect: (index: number) => { this.selectSkyCultureMakerConstellation(index) },
        onUpdate: (updated: SkyCultureMakerConstellation) => { this.updateSkyCultureMakerConstellation(updated) },
        onRemoveSelected: () => { this.removeSelectedSkyCultureMakerConstellation() },
        onRemoveLine: (lineIndex: number) => { this.removeSkyCultureMakerLine(lineIndex) },
        onAddHipLine: () => { this.addSkyCultureMakerHipLine() },
        onAddSelectedStar: () => { this.addSelectedStarToSkyCultureMaker() },
        onImportArtwork: () => { this.importSkyCultureMakerArtworkFile() },
        onRemoveArtwork: () => { this.removeSkyCultureMakerArtwork() },
        onArtworkTouch: (event: TouchEvent) => { this.handleSkyCultureMakerArtworkTouch(event) },
        onValidate: () => { this.validateSkyCultureMaker() },
        onImport: () => { this.importSkyCultureMakerFile() },
        onExport: () => { this.exportSkyCultureMaker() },
        onShare: () => { shareFile(this.hostMediaPort, this.hostPlatformPort, this.skyCultureMakerStore.exportPath, utd.UniformDataType.ZIP_ARCHIVE, this.skyCultureMakerStore.exportFileName, I18n.t('sky_culture_maker_share_description'), 'sky-culture-maker-share', { flashHint: (text: ResourceStr): void => this.flashHint(text), isExpandedLayout: (): boolean => this.isExpandedLayout }) },
        onSaveAs: () => { this.saveFileAs(this.skyCultureMakerStore.exportPath, this.skyCultureMakerStore.exportFileName, 'ZIP 压缩包|.zip') },
        onSaveDraft: () => { this.saveSkyCultureMakerDraft(false) },
        onUndo: () => { this.undoSkyCultureMaker() },
        onReset: () => { this.resetSkyCultureMaker() }
      })
        } else if (this.activePanel === 'nebulaTextures') {
      NebulaTexturesPanel({
        store: this.nebulaTextureStore,
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        accentColor: this.nightModeStore.nmAccent(),
        panelColor: this.nightModeStore.nmBg(),
        onSetVisible: (enabled: boolean) => { this.setNebulaTextureVisible(enabled) },
        onRefresh: () => { this.refreshNebulaTextures() },
        onImport: () => { this.importNebulaTextureFile() },
        onSetConflictAvoidance: (value: boolean) => { this.setNebulaTextureFlag('setNebulaTextureConflictAvoidance', value, this.nebulaTextureStore.nebulaTextureStatus?.avoidAreaConflict === true) },
        onGoto: (imageUrl: string) => { this.gotoNebulaTexture(imageUrl) },
        onRemove: (imageUrl: string) => { this.removeNebulaTexture(imageUrl) }
      })
    } else if (this.activePanel === 'scripts') {
      ScriptsPanel({
        tools: this.tools,
        guideSessionActive: this.scriptStore.scriptSessionActive(this.tools.recording, this.guideStore.guideState.active),
        scriptStore: this.scriptStore,
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        accentColor: this.nightModeStore.nmAccent(),
        panelColor: this.nightModeStore.nmBg(),
        lineColor: this.nightModeStore.nmBorder(),
        scriptMetaLine: (filename: string) => { return this.scriptStore.scriptMetaLine(filename) },
        scriptSourceLine: (filename: string) => { return this.scriptStore.scriptSourceLine(filename) },
        onStartGuide: (id: string) => { this.guideStore.executeGuideRequest('startGuide', id) },
        onStopPlayback: () => { this.scriptStore.stopScriptPlayback() },
        onImportScript: () => { this.importScriptFile() },
        onPlayScript: (name: string) => { this.scriptStore.playScriptByName(name) },
        onToggleRecording: () => { this.tools.recording ? this.recordingCtl().stopRecording() : this.recordingCtl().startRecording() },
        onSaveRecording: () => { this.recordingCtl().saveCurrentRecording() },
        onSetRecordName: (value: string) => { this.scriptStore.recordName = value },
        onPlayRecording: (file: string) => { this.recordingCtl().playRecording(file) },
        onLoadRecording: (file: string, name: string) => { this.scriptStore.loadRecordingByName(file, name) },
        onShareRecording: (rec: RecordingEntry, idx: number) => {
          shareFile(this.hostMediaPort, this.hostPlatformPort, rec.path ?? '', utd.UniformDataType.PLAIN_TEXT, rec.name,
            'Stellarium 操作录制', 'recording-share-' + idx.toString(),
            { flashHint: (text: ResourceStr): void => this.flashHint(text), isExpandedLayout: (): boolean => this.isExpandedLayout })
        },
        onDeleteRecording: (file: string) => { this.recordingCtl().deleteRecording(file) },
        onToggleScreenVideo: () => {
          if (this.scriptStore.screenVideoRecording) this.recordingCtl().stopScreenVideoRecording()
          else this.recordingCtl().startScreenVideoRecording()
        },
        onSaveScreenVideoToGallery: (result: SaveButtonOnClickResult) => { void this.recordingCtl().saveScreenVideoToGallery(result === SaveButtonOnClickResult.SUCCESS) },
        onShareScreenVideo: () => {
          shareFile(this.hostMediaPort, this.hostPlatformPort, this.scriptStore.screenVideoPath, utd.UniformDataType.VIDEO, this.scriptStore.screenVideoFileName,
            'Stellarium 屏幕视频', 'screen-video-share',
            { flashHint: (text: ResourceStr): void => this.flashHint(text), isExpandedLayout: (): boolean => this.isExpandedLayout })
        },
        onSaveScreenVideoAs: () => { this.saveFileAs(this.scriptStore.screenVideoPath, this.scriptStore.screenVideoFileName, 'MP4 视频|.mp4') },
        onSetVideoFps: (value: string) => { this.scriptStore.videoFps = value },
        onSetVideoDuration: (value: string) => { this.scriptStore.videoDuration = value },
        onToggleVideoRecording: () => { this.scriptStore.videoRecording ? this.recordingCtl().stopVideoRecording() : this.recordingCtl().startVideoRecording() },
        onShareVideoArchive: () => {
          shareFile(this.hostMediaPort, this.hostPlatformPort, this.scriptStore.videoArchivePath, utd.UniformDataType.ZIP_ARCHIVE,
            this.scriptStore.videoArchiveFileName, 'Stellarium 高质量星图帧序列', 'video-frames-share',
            { flashHint: (text: ResourceStr): void => this.flashHint(text), isExpandedLayout: (): boolean => this.isExpandedLayout })
        },
        onExportVideoArchive: () => { this.saveFileAs(this.scriptStore.videoArchivePath, this.scriptStore.videoArchiveFileName, 'ZIP 压缩包|.zip') }
      })
    } else if (this.activePanel === 'observing') {
      ObservingPanel({
        wutStore: this.wutStore,
        observingListStore: this.obsListStore,
        textColor: this.nightModeStore.nmText(),
        subColor: this.nightModeStore.nmSub(),
        panelColor: this.nightModeStore.nmBg(),
        borderTint: this.nightModeStore.nmBorder(),
        accentColor: this.nightModeStore.nmAccent(),
        onOpenSearch: () => { this.openSubPanel('search') },
        onClearAll: () => {
          this.obsListStore.observingList = []
          this.persistObservingList()
          this.flashHint(I18n.t('i0302'))
        },
        onSelectCategory: (category: string) => {
          if (this.wutStore.wutCategory !== category) {
            this.wutStore.wutCategory = category
            this.wutStore.loadWutTargets()
          }
        },
        onRefreshTargets: () => { this.wutStore.loadWutTargets() },
        onJumpTarget: (target: WutTarget) => { this.jumpToWutTarget(target) },
        onAddTarget: (target: WutTarget) => { this.addWutTargetToObservingList(target) },
        onRemoveTarget: (name: string) => { this.removeObservingTarget(name) },
        onSearchName: (name: string) => { this.searchObject(name) },
        targetTitleOf: (target: WutTarget) => this.wutTargetTitle(target),
        targetSubtitleOf: (target: WutTarget) => this.searchStore.wutTargetSubtitle(target),
        typeOf: (type: string) => zhType(type),
        displayNameOf: (name: string) => this.wutStore.observingDisplayName(name)
      })
    } else if (this.activePanel === 'telescope') {
      TelescopePanel({
        store: this.telescopeStore,
        textColor: this.nightModeStore.nmText(), subColor: this.nightModeStore.nmSub(), accentColor: this.nightModeStore.nmAccent(),
        panelColor: this.nightModeStore.nmBg(), inputColor: this.nightModeStore.nmInput(), lineColor: this.nightModeStore.nmBorder(), inputLineColor: this.nightModeStore.nmInputBorder(),
        onBeginNew: () => { this.beginNewTelescopeProfile() },
        onSelectProfile: (slot: number) => { this.selectTelescopeProfile(slot) },
        onSelectProtocol: (protocol: string) => { this.selectTelescopeProtocol(protocol) },
        onValidateEditor: () => { this.validateTelescopeEditorStatus() },
        onSave: () => { this.saveTelescopeProfile() },
        onDelete: () => { this.deleteTelescopeProfile() },
        onTest: () => { this.testTelescopeConnection() },
        onGoto: () => { this.lx200GotoSelected() },
        onSync: () => { this.lx200SyncSelected() },
        onAbort: () => { this.lx200Abort() },
        onReadPosition: (center: boolean) => { this.readTelescopePosition(center) },
        onSetLivePosition: (enabled: boolean) => { this.telescopeStore.setTelescopeLivePosition(enabled) }
      })
    } else if (this.activePanel === 'tools') {
      ToolsPanel({
        store: this.tools,
        textColor: this.nightModeStore.nmText(), subColor: this.nightModeStore.nmSub(), panelColor: this.nightModeStore.nmBg(), inputColor: this.nightModeStore.nmInput(),
        configImportText: this.tools.configImportText,
        sessionImportText: this.tools.sessionImportText,
        onScreenshot: () => { saveScreenshot(this.commandPort(), this.hostMediaPort, { flashHint: (text: ResourceStr): void => this.flashHint(text), screenshotSaving: (): boolean => this.tools.screenshotSaving, setScreenshotSaving: (saving: boolean): void => { this.tools.screenshotSaving = saving } }) },
        onExportConfig: () => { this.exportConfig() },
        onImportConfig: () => { this.importConfig() },
        onConfigImportText: (value: string) => { this.tools.configImportText = value },
        onSessionExport: () => { this.sessionToolStore.sessionExport() },
        onSessionApply: () => { this.sessionToolStore.sessionApply() },
        onSessionImportText: (value: string) => { this.tools.sessionImportText = value },
        onLoadLog: () => { this.tools.loadLog() },
        onCollapseLog: () => { this.tools.logVisible = false }
      })
    } else if (this.activePanel === 'audio') {
      AudioPanel({
        audioStore: this.audioStore,
        textColor: this.nightModeStore.nmText(),
        panelColor: this.nightModeStore.nmBg(),
        accentColor: this.nightModeStore.nmAccent(),
        onToggleMusic: (enabled: boolean) => {
          this.audioStore.musicEnabled = enabled
          const engine = AudioEngine.getInstance()
          if (enabled) { engine.start().then(() => { engine.setMuted(false) }) } else { engine.setMuted(true) }
          this.persistMusicEnabled()
          this.flashHint(enabled ? I18n.t('music_on_hint') : I18n.t('music_off_hint'))
        },
        onVolumeChange: (value: number) => {
          this.audioStore.audioVolume = value
          AudioEngine.getInstance().setVolume(value)
        }
      })
    } else {
      ConfigFallbackPanel({
        gyroStore: this.gyroStore,
        layerStore: this.layerStore,
        nightModeStore: this.nightModeStore,
        telescopeStore: this.telescopeStore,
        isExpandedLayout: this.isExpandedLayout,
        fovText: this.fovText,
        selectedLanguage: this.languageStore.selectedLanguage,
        viewSettingsStore: this.viewSettingsStore,
        observingListStore: this.obsListStore,
        skyCultureViewStore: this.skyCultureViewStore,
        panelColor: this.nightModeStore.nmBg(),
        observingDisplayName: (name: string) => { return this.wutStore.observingDisplayName(name) },
        selectObservingTarget: (name: string) => { this.searchObject(name); this.flashHint(I18n.t('i0082')) },
        removeObservingTarget: (name: string) => { this.removeObservingTarget(name) },
        clearObservingList: () => { this.obsListStore.observingList = []; this.persistObservingList(); this.flashHint(I18n.t('i0302')) },
        setLegacyDistanceUnit: (useMetric: boolean) => {
          this.viewSettingsStore.useMetricUnits = useMetric
          this.callInteractive('setConfigString', 'astronomy/flag_use_km_for_distance=' + (useMetric ? 'true' : 'false'), () => {})
        },
        handleChip: (id: string) => { this.handleChip(id) },
        toggleGyroscope: (enabled: boolean) => { this.gyroCtl().toggleGyroscope(enabled) },
        flashHint: (text: ResourceStr) => { this.flashHint(text) },
        setLanguage: (lang: string) => { this.setLanguage(lang) },
        setSkyCulture: (culture: string) => { this.setSkyCulture(culture) },
        triggerAction: (actionId: string) => { this.triggerAction(actionId) },
        refreshState: () => { this.refreshState() },
        saveScreenshot: () => { saveScreenshot(this.commandPort(), this.hostMediaPort, { flashHint: (text: ResourceStr): void => this.flashHint(text), screenshotSaving: (): boolean => this.tools.screenshotSaving, setScreenshotSaving: (saving: boolean): void => { this.tools.screenshotSaving = saving } }) }
      })
    }
  }

  // 时间速度控制按钮 — 参考 Sky Guide 的交互范式
  // 布局：[倒带] [现在] [停止] [实时] [快进] [超快]
  // 当前档位高亮，点击立即更新速度显示

  // ===== Sky Guide 风格：按字段选择的时间转轴 =====
  private syncJulianDateFields(response: StellariumBridgeResponse, jd: number): void {
    const mjd = response.mjd !== undefined ? Number(response.mjd) : jd - 2400000.5
    this.julianStore.julianCalendarSystem = response.calendarSystem === 'julian' ? 'julian' : 'gregorian'
    if (!this.julianStore.julianDateEditing) {
      this.julianStore.julianDayInput = jd.toFixed(5)
      this.julianStore.modifiedJulianDayInput = mjd.toFixed(5)
    }
  }

  private applyJulianDateInput(scale: string): void {
    if (this.julianDateApplyInFlight) { return }
    const text = (scale === 'mjd' ? this.julianStore.modifiedJulianDayInput : this.julianStore.julianDayInput).trim()
    const value = Number(text)
    if (!Number.isFinite(value)) {
      this.julianStore.julianDateError = I18n.t('julian_date_invalid')
      return
    }
    this.julianStore.julianDateError = ''
    this.julianDateApplyInFlight = true
    this.callInteractive('setJulianDate', scale + '|' + value.toString(), (r: StellariumBridgeResponse) => {
      this.julianDateApplyInFlight = false
      if (r.ok !== true || r.jd === undefined) {
        this.julianStore.julianDateError = r.error ?? I18n.t('julian_date_invalid')
        return
      }
      this.julianStore.julianDateEditing = false
      this.syncJulianDateFields(r, Number(r.jd))
      this.wheel().syncFromSimulation(Number(r.jd))
      this.refreshSimTimeLight()
    }, (r: StellariumBridgeResponse) => {
      this.julianDateApplyInFlight = false
      this.julianStore.julianDateError = r.error ?? I18n.t('julian_date_invalid')
    })
  }

  private adjustJulianDate(scale: string, direction: number): void {
    const text = scale === 'mjd' ? this.julianStore.modifiedJulianDayInput : this.julianStore.julianDayInput
    const value = Number(text)
    if (!Number.isFinite(value)) {
      this.julianStore.julianDateError = I18n.t('julian_date_invalid')
      return
    }
    const adjusted = value + direction * 0.00001
    if (scale === 'mjd') this.julianStore.modifiedJulianDayInput = adjusted.toFixed(5)
    else this.julianStore.julianDayInput = adjusted.toFixed(5)
    this.applyJulianDateInput(scale)
  }

  /**
   * 时间类操作后刷新「时间/速度」显示。
   * 立即刷一次（响应快），350ms 后再刷一次（引擎异步应用 JD/timeRate 需要时间窗口）。
   */
  private refreshTimeNow(): void {
    this.refreshState()
    // 注意：此处必须是 setTimeout(refreshState)，绝不能调 refreshTimeNow 自身（会无限递归栈溢出）
    setTimeout(() => { this.refreshState() }, 350)
  }

  private handleChip(id: string): void {
    if (id === 'refresh') {
      this.refreshSelectedObject()
      this.refreshState()
    } else if (id === 'center') {
      this.moveToSelectedObject()
    } else if (id === 'lock-view') {
      this.setViewLockState(true)
    } else if (id === 'unlock-view') {
      this.setViewLockState(false)
    } else if (id === 'now') {
      // 现在：回到当前时刻 + 重置为1x
      this.triggerAction('actionReturn_To_Current_Time')
      this.applySpeedStep(7) // SPEED_IDX_REALTIME
      this.timeStore.timeRateText = '1x'
      this.refreshTimeNow()
    } else if (id === 'stop') {
      // 停止按钮是可逆状态：运行时停止，停止后恢复到停止前速度。
      if (this.timeStore.timeSpeedIndex === 6) {
        this.applySpeedStep(this.timeStore.lastNonZeroSpeedIndex === 6 ? 7 : this.timeStore.lastNonZeroSpeedIndex)
      } else {
        this.timeStore.lastNonZeroSpeedIndex = this.timeStore.timeSpeedIndex
        this.applySpeedStep(6) // SPEED_IDX_STOP
      }
      this.refreshTimeNow()
    } else if (id === 'realtime') {
      // 实时：回到当前时刻 + 恢复 1x 正常速度
      this.triggerAction('actionReturn_To_Current_Time')
      this.applySpeedStep(7) // SPEED_IDX_REALTIME
      this.timeStore.timeRateText = '1x'
      this.refreshTimeNow()
    } else if (id === 'rewind') {
      // 倒带：单按钮循环升档 -1x → -2x → -10x → -1分/秒 → -1时/秒 → -1天/秒 → 回到-1x
      let rewIdx = 5 // 默认从 -1x 起步（非倒带状态按下时）
      if (this.timeStore.timeSpeedIndex < 6) {
        // 已在倒带中：再点升一档（索引减小=更快反向）；到底(0)循环回 -1x
        rewIdx = this.timeStore.timeSpeedIndex === 0 ? 5 : this.timeStore.timeSpeedIndex - 1
      }
      this.applySpeedStep(rewIdx)
      this.flashHint(I18n.t('s0763_rewind') + ' ' + this.timeStore.timeRateText)
      this.refreshTimeNow()
    } else if (id === 'faster' || id === 'fast' || id === 'warp') {
      // 快进：单按钮循环升档 1x → 2x → 10x → 1分/秒 → 1时/秒 → 1天/秒 → 10天/秒 → 回到1x
      let fwdIdx = 7 // 默认回 1x（停止/倒带状态按下时从 1x 起步）
      if (this.timeStore.timeSpeedIndex >= 7) {
        // 已在正向：升一档；到顶(13)循环回 1x
        fwdIdx = this.timeStore.timeSpeedIndex >= 13 ? 7 : this.timeStore.timeSpeedIndex + 1
      }
      this.applySpeedStep(fwdIdx)
      this.flashHint(I18n.t('s0765_fast') + ' ' + this.timeStore.timeRateText)
      this.refreshTimeNow()
    } else if (id === 'slower') {
      // 减速：向"停止"方向降一档（快进降档、倒带也降档），降到1x再点=停止，不会跨进反向
      let prevIdx = this.timeStore.timeSpeedIndex
      if (this.timeStore.timeSpeedIndex > 6) {
        prevIdx = this.timeStore.timeSpeedIndex - 1
      } else if (this.timeStore.timeSpeedIndex < 6) {
        prevIdx = this.timeStore.timeSpeedIndex + 1
      }
      this.applySpeedStep(prevIdx)
      this.flashHint(prevIdx === 6 ? I18n.t('s0761_stop') : I18n.t('s0759_slower') + ' ' + this.timeStore.timeRateText)
      this.refreshTimeNow()
    } else if (id === '+12h') {
      this.advanceTime(12)
    } else if (id === '-12h') {
      this.advanceTime(-12)
    } else if (id === 'sunRise' || id === 'sunTransit' || id === 'sunSet' || id === 'astronomicalSet') {
      this.jumpToTimeMark(id)
    } else if (id === 'Moon') {
      this.searchObject('Moon')
    } else if (id === 'Mars') {
      this.searchObject('Mars')
    } else if (id === 'Jupiter') {
      this.searchObject('Jupiter')
    } else if (id.startsWith('city_')) {
      const cityId = id.substring(5)
      const preset = getCityPreset(cityId)
      if (preset !== undefined) {
        this.locationCtl().setLocation(cityId, preset.lat, preset.lon, preset.alt)
      }
    } else if (id === 'Beijing') {
      this.locationCtl().setLocation('Beijing', 39.9042, 116.4074, 44)
    } else if (id === 'Sun' || id === 'Mercury' || id === 'Venus' || id === 'Saturn' || id === 'Sirius' || id === 'Vega' || id === 'Betelgeuse' || id === 'Polaris' || id === 'M31' || id === 'M42' || id === 'M45' || id === 'NGC 2244') {
      this.searchObject(id)
    // 方向快捷查看
    } else if (id === 'east') {
      this.stopTracking(); this.triggerAction('actionLook_Towards_East'); this.refreshState(); this.flashHint(I18n.t('i0084'))
    } else if (id === 'south') {
      this.stopTracking(); this.triggerAction('actionLook_Towards_South'); this.refreshState(); this.flashHint(I18n.t('i0085'))
    } else if (id === 'west') {
      this.stopTracking(); this.triggerAction('actionLook_Towards_West'); this.refreshState(); this.flashHint(I18n.t('i0086'))
    } else if (id === 'north') {
      this.stopTracking(); this.triggerAction('actionLook_Towards_North'); this.refreshState(); this.flashHint(I18n.t('i0087'))
    } else if (id === 'zenith') {
      this.stopTracking(); this.triggerAction('actionLook_Towards_Zenith'); this.refreshState(); this.flashHint(I18n.t('i0088'))
    } else if (id === 'ncp') {
      this.stopTracking(); this.triggerAction('actionLook_Towards_NCP'); this.refreshState(); this.flashHint(I18n.t('i0089'))
    }
  }

  private selfTestAllActions(): void {
    hilog.info(0x0000, 'StellariumArkUI', 'selftest send %{public}d ids', this.SELFTEST_ACTION_IDS.length)
    // 引擎核心(StelApp)在启动早期尚未就绪，命令会先返回 pending 不入队；
    // 用更长重试窗口(100ms x 120 = 12s)撑过初始化，确保真正跑到 C++ 自检。
    this.callNativeWhenReady('selftestActions', this.SELFTEST_ACTION_IDS.join('|'), (r: StellariumBridgeResponse) => {
      // 把整包响应(含 total/missing)打在一行里，避免被启动期日志冲掉
      hilog.info(0x0000, 'StellariumArkUI', 'selftest done %{public}s', JSON.stringify(r))
    }, 0, 100, 120)
  }

  private settingsChoiceSelected(group: string, value: string): boolean {
    if (group === 'information') return this.infoWindowStore.informationMode === value
    if (group === 'date') return this.timeSettingsStore.configDateFormat === value
    if (group === 'time') return this.timeSettingsStore.configTimeFormat === value
    if (group === 'startup') return this.timeSettingsStore.startupTimeMode === value
    return false
  }

  private selectSettingsChoice(group: string, value: string): void {
    if (this.settingsChoiceSelected(group, value)) return
    if (group === 'information') this.setInformationMode(value)
    else if (group === 'date') this.setConfigurationDateFormat(value)
    else if (group === 'time') this.setConfigurationTimeFormat(value)
    else if (group === 'startup') this.setStartupTimeSetting('startupMode', value)
  }



  /** 面板标题行的时分秒：从 timeStore.observationTimeText 拆出第一个空格之后的部分。 */
  /** 面板副标题行的年月日（附带当前时间速率）。 */
  /** 图层开关的统一写回：setSkyDisplay* 走 setSkyDisplaySetting，其余带 cmd 的走 setBridgeFlag，
   *  无 cmd 的走 setLayer；与原 @Builder switchRow 的 onChange 分派逐字等价（含 flashHint 提示）。 */
  private applyLayerSwitch(actionId: string, cmd: string, value: boolean): void {
    if (cmd.length > 0) {
      if (cmd.indexOf('setSkyDisplay') === 0) {
        this.setSkyDisplaySetting(actionId, value)
      } else {
        this.setBridgeFlag(cmd, value)
      }
    } else {
      this.setLayer(actionId, value)
    }
    this.flashHint(I18n.t(value ? 'msg_shown' : 'msg_hidden'))
  }

  private layerTabItems(): TabItem[] {
    const tabs: TabItem[] = [
      { label: I18n.t('v0000'), id: 0 },
      { label: I18n.t('v0001'), id: 1 },
      { label: I18n.t('v0002'), id: 2 },
      { label: I18n.t('v0003'), id: 3 },
      { label: I18n.t('v0004'), id: 4 },
      { label: I18n.t('v0005'), id: 5 }
    ]
    if (!OFFLINE_APPGALLERY_BUILD) {
      tabs.push({ label: I18n.t('v0006'), id: 6 })
    }
    return tabs
  }

  private markingLayerStates(enabled: boolean): Array<LayerPresetState> {
    const states: Array<LayerPresetState> = []
    for (const actionId of MARKING_LAYER_ACTION_IDS) {
      states.push({ id: actionId, enabled: enabled })
    }
    return states
  }

  private layerPresetStates(enabled: boolean): Array<LayerPresetState> {
    const states = this.markingLayerStates(enabled)
    for (const actionId of CONTENT_LAYER_ACTION_IDS) {
      states.push({ id: actionId, enabled: enabled })
    }
    return states
  }

  private applyLayerStates(states: Array<LayerPresetState>, successMessage: string): void {
    this.callInteractive('setActionStates', JSON.stringify(states), (response: StellariumBridgeResponse) => {
      if (response.ok === true) {
        this.refreshState()
        this.flashHint(successMessage)
      } else {
        this.flashHint('图层设置未能应用，请重试。')
      }
    })
  }

  private clearMarkingLayers(): void {
    this.applyLayerStates(this.markingLayerStates(false), '已清除全部坐标与标记。')
  }

  private applyLayerPreset(preset: string): void {
    let states: Array<LayerPresetState> = this.layerPresetStates(false)
    if (preset === 'clean') {
      states.push(
        { id: 'actionShow_Stars', enabled: true }, { id: 'actionShow_Stars_Labels', enabled: false },
        { id: 'actionShow_Planets', enabled: true }, { id: 'actionShow_Planets_Labels', enabled: false },
        { id: 'actionShow_Planets_Hints', enabled: false },
        { id: 'actionShow_Nebulas', enabled: true }, { id: 'actionShow_MilkyWay', enabled: true },
        { id: 'actionShow_Constellation_Lines', enabled: false }, { id: 'actionShow_Constellation_Labels', enabled: false },
        { id: 'actionShow_Constellation_Boundaries', enabled: false }, { id: 'actionShow_Constellation_Art', enabled: false },
        { id: 'actionShow_Atmosphere', enabled: true }, { id: 'actionShow_Ground', enabled: true }
      )
    } else if (preset === 'observe') {
      states.push(
        { id: 'actionShow_Stars', enabled: true }, { id: 'actionShow_Stars_Labels', enabled: true },
        { id: 'actionShow_Planets', enabled: true }, { id: 'actionShow_Planets_Labels', enabled: true },
        { id: 'actionShow_Planets_Hints', enabled: true }, { id: 'actionShow_Planets_Orbits', enabled: true },
        { id: 'actionShow_Nebulas', enabled: true }, { id: 'actionShow_DSO_Textures', enabled: true },
        { id: 'actionShow_MilkyWay', enabled: true }, { id: 'actionShow_Constellation_Lines', enabled: true },
        { id: 'actionShow_Constellation_Labels', enabled: true }, { id: 'actionShow_Constellation_Boundaries', enabled: false },
        { id: 'actionShow_Constellation_Art', enabled: false }, { id: 'actionShow_Atmosphere', enabled: false },
        { id: 'actionShow_Ground', enabled: false }, { id: 'actionShow_Fog', enabled: false },
        { id: 'actionShow_Cardinal_Points', enabled: true }, { id: 'actionShow_Equatorial_Grid', enabled: true },
        { id: 'actionShow_Ecliptic_Line', enabled: true }, { id: 'actionShow_Meridian_Line', enabled: true },
        { id: 'actionShow_Horizon_Line', enabled: true }, { id: 'actionShow_FOV_Center_Marker', enabled: true }
      )
    } else {
      states.push(
        { id: 'actionShow_Stars', enabled: true }, { id: 'actionShow_Stars_Labels', enabled: false },
        { id: 'actionShow_Planets', enabled: false }, { id: 'actionShow_Planets_Labels', enabled: false },
        { id: 'actionShow_Planets_Hints', enabled: false },
        { id: 'actionShow_Nebulas', enabled: true }, { id: 'actionShow_MilkyWay', enabled: true },
        { id: 'actionShow_Constellation_Lines', enabled: false }, { id: 'actionShow_Constellation_Labels', enabled: false },
        { id: 'actionShow_Constellation_Boundaries', enabled: false }, { id: 'actionShow_Constellation_Art', enabled: false },
        { id: 'actionShow_Atmosphere', enabled: false }, { id: 'actionShow_Ground', enabled: false }
      )
    }
    this.applyLayerStates(states, preset === 'clean' ? '已应用纯净星空图层。' : (preset === 'observe' ? '已应用观测辅助图层。' : '已应用摄影构图图层。'))
  }

  private selectViewTab(tabId: number): void {
    if (tabId === this.viewTab) return
    const direction = tabId > this.viewTab ? 1 : -1
    const transitionId = ++this.viewTabTransitionId
    hilog.info(0x0000, 'StellariumArkUI', '[layer-transition] begin id=%{public}d from=%{public}d to=%{public}d', transitionId, this.viewTab, tabId)
    this.getUIContext().animateTo({ duration: 100, curve: Curve.EaseIn, onFinish: () => {
      if (transitionId !== this.viewTabTransitionId) return
      this.viewTab = tabId
      if (tabId === 4) this.layerViewStore.loadLandscapeList()
      this.viewTabContentOffsetX = direction * 10
      hilog.info(0x0000, 'StellariumArkUI', '[layer-transition] swap id=%{public}d tab=%{public}d', transitionId, tabId)
      this.getUIContext().animateTo({ duration: 170, curve: Curve.EaseOut }, () => {
        if (transitionId !== this.viewTabTransitionId) return
        this.viewTabContentOpacity = 1
        this.viewTabContentOffsetX = 0
        this.syncSkyCultureTimeFollowTimer()
        hilog.info(0x0000, 'StellariumArkUI', '[layer-transition] finish id=%{public}d tab=%{public}d', transitionId, tabId)
      })
    } }, () => {
      this.viewTabContentOpacity = 0
      this.viewTabContentOffsetX = (0 - direction) * 8
    })
  }

  private selectConfigTab(tabId: number): void {
    if (tabId === this.configTab) return
    const direction = tabId > this.configTab ? 1 : -1
    const transitionId = ++this.configTabTransitionId
    hilog.info(0x0000, 'StellariumArkUI', '[settings-transition] begin id=%{public}d from=%{public}d to=%{public}d', transitionId, this.configTab, tabId)
    this.getUIContext().animateTo({ duration: 90, curve: Curve.EaseIn, onFinish: () => {
      if (transitionId !== this.configTabTransitionId) return
      this.configTab = tabId
      this.configTabContentOffsetX = direction * 8
      if (tabId === 5) {
        this.scriptStore.loadScriptList()
        this.scriptStore.loadRecordings()
        this.scriptStore.loadVideoRecordingState()
      } else if (tabId === 6) {
        this.pluginStore.loadPluginList()
      }
      hilog.info(0x0000, 'StellariumArkUI', '[settings-transition] swap id=%{public}d tab=%{public}d', transitionId, tabId)
      this.getUIContext().animateTo({ duration: 170, curve: Curve.EaseOut }, () => {
        if (transitionId !== this.configTabTransitionId) return
        this.configTabContentOpacity = 1
        this.configTabContentOffsetX = 0
        hilog.info(0x0000, 'StellariumArkUI', '[settings-transition] finish id=%{public}d tab=%{public}d', transitionId, tabId)
      })
    } }, () => {
      if (transitionId !== this.configTabTransitionId) return
      this.configTabContentOpacity = 0
      this.configTabContentOffsetX = (0 - direction) * 8
    })
  }








}
