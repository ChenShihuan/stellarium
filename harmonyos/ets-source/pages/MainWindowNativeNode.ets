import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'
import { geoLocationManager } from '@kit.LocationKit'
import { sensor } from '@kit.SensorServiceKit'
import { curves } from '@kit.ArkUI'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { KeyCode } from '@kit.InputKit'
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
import { modelIdentity, modelMultiply, modelDrag } from './DetailModelGeometry'
import { proceduralModelKind, proceduralParticles } from './ProceduralDetailModel'
import { DetailModelRenderClient } from './DetailModelRenderClient'
import { ASTRONOMY_GUIDES, AstronomyGuide, GuidePlayer, GuideState, GuideResult, GuideStep } from './AstronomyGuide'
import { DetailModelResources, DetailModelFrame, DetailModelResult, DetailModelRing, DetailModelLight } from './DetailModelRenderTypes'

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
import { gyroRotateAboutAxis, gyroMultiplyQuaternions, gyroFilterDeviceVector, gyroCross, gyroRotateAboutVertical, gyroScreenAxisForDisplay, shortestGyroAzimuthDelta, wrapGyroAzimuth, gyroNormalizeVector, gyroNormalizeQuaternion, gyroConjugateQuaternion, gyroDot } from '../common/derive/gyro'
import { dateToJD, jdToLocalTimeText, astroTabItemsForGroup, astroGroupForTab, graphModeLabel, graphStartOptionLabel, hourOffsetLabel, planetMetricLabel, planetMetricUnit, planetPairBodyName, phenomenonCaption, hecPointSize, hecPointAngle, hecPlanetOrbitRadius, messierNumberOf, minorPlanetNumberOf, fmtDegMin, clamp, distance } from '../common/derive/astro'
import { resourceText, describeDecodeError, zhNameOf, zhType, planetZh, sensZh, scriptZh, scriptDesc, pluginZh, pluginDesc, pluginHostName, pluginFeatureRoute, approximateTimeZoneDisplay } from '../common/derive/labels'
import { isSafeSkyCultureArtPath, cleanSkyCultureDescription, cleanSkyCultureNarration, isCliPanelName, parseObservingList, csvCell, formatRate, configDitheringLabel, informationMaskBit, isRecordable } from '../common/derive/skycult'
import { primaryDockActions, moreActions, observingHubActions, skyDataHubActions, automationHubActions, getCityPreset, telescopeUpdateTime, telescopeErrorText, validationFromResponse, normalizeLocationSearchText, officialLocationAliases, sessionSignature } from '../common/derive/actions'
import { pointInsideRect, pointOverlapsUiObstacle, touchScreenX, touchScreenY, touchWindowX, touchWindowY, azBarHeight, compactTopQuickY, baseCompactObjectPeekY, expandedDetailSummaryHeight, isPhoneDetailPeek, useTabletObjectInspector, useExpandedDetailSummary } from '../common/derive/geometry'
import { catalogIconForModule, catalogIconForObjectType, wutCategoryOptions, wutCategoryKey, wutDirectionLabel } from '../common/derive/catalog'
import { BridgeClient } from '../bridge/BridgeClient'
import { CommandPort } from '../bridge/CommandPort'
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
  ImageDecodeSize, ObjectInspectorRingSpec, HeliocentricPositionOptions, ConstellationNavigationItem, PluginFeatureRoute,
  NebulaTextureItem, NebulaTextureStatus, NebulaTextureRefreshResponse, SkyCultureMakerArtworkAnchor, SkyCultureMakerArtwork, SkyCultureMakerConstellation,
  SkyCultureMakerDraft, SkyCultureMakerIssue, TelescopeControlResponse, TelescopeProfile, TelescopeProfilesResponse,
  TELESCOPE_SIMULATOR_MODEL, HeliocentricOrbit, ConfigurationOption, SkyCultureVisualColors, CelestialPositionOptions,
  CelestialPositionCategory, PhenomenaOptions, PhenomenaStartOption, EphemerisOptions, RtsCalendarOptions, EclipseOptions,
  LayerPresetState, MARKING_LAYER_ACTION_IDS, CONTENT_LAYER_ACTION_IDS, AstroCsvExport, CELESTIAL_POSITION_CATEGORIES, HELIOCENTRIC_PLANET_ORBITS,
  HELIOCENTRIC_DISTANCE_GUIDES, PHENOMENA_START_OPTIONS, TonightPlanetRow,
  StarCatalogStatusResponse, LimitMagnitudeResponse, GyroGuideProjection, SkyUiObstacle, BookmarkItem,
  BookmarkRaw, BookmarksResponse, BOOKMARK_STORE, SEARCH_HISTORY_STORE, OBSERVING_STORE, OFFLINE_APPGALLERY_BUILD,
  OcularsData, OcularsResponse, OcularModeResponse, PointerCoordinatesData, PointerCoordinatesResponse,
  EquationOfTimeData, ArchaeoLinesData, ArchaeoPlanetOption, SatellitesData, SatelliteListItem,
  SatelliteSource, SatelliteSourceInput, SatelliteUpdateSettings, SatelliteSourcesResponse, SatellitesResponse, CatalogHealthEntry,
  CatalogHealthResponse, MeteorShowersData, Scenery3dResponse, LogResponse,
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
  private objectInspectorModelOverlaySerial: number = 0
  private objectInspectorModelRendering: boolean = false
  private objectInspectorModelRenderClient: DetailModelRenderClient | undefined = undefined
  private objectInspectorModelRotation: number[] = modelIdentity()
  private objectInspectorModelLastLighting: number[] = []
  private objectInspectorModelLastRenderTime: number = 0
  private objectInspectorModelTouchCount: number = 0
  private objectDetailScroller: Scroller = new Scroller()
  private objectInspectorModelTexturePixels: ArrayBuffer | undefined = undefined
  private objectInspectorModelTextureWidth: number = 0
  private objectInspectorModelTextureHeight: number = 0
  private objectInspectorModelTextureStride: number = 0
  private objectInspectorModelRingTexturePixels: ArrayBuffer | undefined = undefined
  private objectInspectorModelRingTextureWidth: number = 0
  private objectInspectorModelRingTextureHeight: number = 0
  private objectInspectorModelRingTextureStride: number = 0
  private objectInspectorModelLastX: number = 0
  private objectInspectorModelLastY: number = 0
  private objectInspectorModelLastPinchDistance: number = 0
  private objectInspectorModelRenderGeneration: number = 0
  private objectInspectorModelRenderPending: boolean = false
  private objectInspectorModelRenderHighQuality: boolean = false
  private objectInspectorModelRenderTimer: number = 0
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
  private mapTouchStartX: number = 0
  private mapTouchStartY: number = 0
  private mapTouchMoved: boolean = false
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
  private gyroPausedForBackground: boolean = false
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
  private satelliteListRequestId: number = 0
  private satelliteLoadTimer: number = -1
  private satelliteLoadIncludeSources: boolean = false
  private satelliteFlagMutationId: number = 0
  private satellitePanelScroller: Scroller = new Scroller()
  private satelliteGroupScroller: Scroller = new Scroller()
  private satelliteListElapsedMs: number = 0
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
  private lx200LivePositionTimer: number = 0
  private lx200LivePositionRequestPending: boolean = false
  private lx200LivePositionRequestId: number = 0
  @State private actionHint: ResourceStr = ''
  // ===== 脚本录制 / 回放（39）=====
  @State private recordBuffer: Array<RecordCmd> = []
  // speechStatus / guideState 已并入 state/GuideStore.ets（review §2.7，2026-10-04）。
  @State private guideStore: GuideStore = new GuideStore()
  private guidePlayer?: GuidePlayer
  private guideTimer: number = -1
  private guideGyroWasEnabled: boolean = false
  private guidePanelWasVisible: boolean = false
  private guideLastRequest: string = ''
  private guideLastResult: GuideResult = { ok: true }
  // ===== 视频帧序列录制（#40）=====
  private lastRecordKey: string = ''
  private lastRecordTime: number = 0
  private recordStartedAt: number = 0
  private recordPausedAt: number = 0
  private recordPausedTotal: number = 0
  private scriptStatusTimer: number = -1
  private scriptStatusRequestPending: boolean = false
  private scriptCaptionsRequestPending: boolean = false
  private scriptStartGraceUntil: number = 0
  private replayTimer: number = -1
  private replayStartedAt: number = 0
  private replayPauseStartedAt: number = 0
  private replayPausedTotal: number = 0
  private replayIndex: number = 0
  private replayCommands: Array<RecordCmd> = []
  private recordViewCheckpointTimer: number = -1
  private videoStateTimer: number = -1
  private screenCapture?: media.AVScreenCaptureRecorder
  private screenCaptureFile?: fileIo.File
  private scriptControlDragging: boolean = false
  private scriptControlDragStartX: number = 0
  private scriptControlDragStartY: number = 0
  private scriptControlDragStartOffsetX: number = 0
  private scriptControlDragStartOffsetY: number = 0

  private hintTimer: number = 0
  private locSearchRequestId: number = 0
  private locationSearchScanContinents: Array<string> = []
  private locationSearchScanRegions: Array<string> = []
  private locationSearchScanContinentIndex: number = 0
  private locationSearchScanRegionIndex: number = 0
  private locationSearchScanCityIndex: number = 0
  private locationSearchScanQuery: string = ''
  private locationSearchScanResults: Array<LocSearchItem> = []
  private locationSearchScanKeys: Set<string> = new Set<string>()
  private locationSearchScanTimer: number = -1
  private locationSearchLastPublishMs: number = 0
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
  private touchStartX: number = 0
  private touchStartY: number = 0
  private touchLastX: number = 0
  private touchLastY: number = 0
  private touchMoved: boolean = false
  private skyTouchActive: boolean = false
  private pinchStartDistance: number = 0
  private pinchLastScale: number = 1
  private pinchCenterX: number = 0
  private pinchCenterY: number = 0
  private pinchStartFov: number = 60
  private pinchLastNativePushMs: number = 0
  private pinchNativePushPending: boolean = false
  /** 缩放 FOV 胶囊提示的节流时间戳 */
  private lastFovHintMs: number = 0
  private pinchActive: boolean = false
  private nativeDragActive: boolean = false
  private lastDragCommandMs: number = 0
  private dragFilteredX: number = 0
  private dragFilteredY: number = 0
  private dragLastRawX: number = 0
  private dragLastRawY: number = 0
  private dragLastSampleMs: number = 0
  private dragVelocityX: number = 0
  private dragVelocityY: number = 0
  private dragVelocitySampleValid: boolean = false
  private skyInertiaTimer: number = 0
  // Momentum runs in the Qt render loop. ArkTS only supplies the release
  // velocity, avoiding a stream of cross-thread drag commands after lift-off.
  private nativeSkyInertiaActive: boolean = false
  private skyDragging: boolean = false
  private gyroLastTimeMs: number = 0
  private gyroGuideTargetAz: number = Number.NaN
  private gyroGuideTargetAlt: number = Number.NaN
  private gyroGuideLastUpdateMs: number = 0
  private gyroGuideReachedAtMs: number = 0
  private gyroLastCompassUiUpdateMs: number = 0
  private gyroMagneticHeading: number = Number.NaN
  private gyroRawAzimuth: number = Number.NaN
  private gyroRawAltitude: number = Number.NaN
  // Automatic, session-local alignment from the physical magnetic compass to
  // Stellarium's Alt/Az frame. The visible slider remains a separate manual
  // fine adjustment, so it stays predictable for the user.
  private gyroAbsolutePoseReady: boolean = false
  private gyroAbsoluteUp: number[] = [0, 1, 0]
  private gyroDisplayRotation: number = 0
  private gyroLastDisplayRotationCheckMs: number = 0
  // alpha is not a stable world heading while a tablet lies flat. Establish
  // this reference only after the display normal has a usable horizontal part.
  private gyroHeadingReferenceReady: boolean = false
  private gyroHeadingSensorAz: number = 0
  private gyroHeadingViewAz: number = 0
  private gyroEventCount: number = 0
  private gyroRawEventCount: number = 0
  private gyroCallbackCount: number = 0
  private gyroInvalidEventCount: number = 0
  private gyroDispatchCount: number = 0
  private gyroGravityEventCount: number = 0
  private gyroMagneticEventCount: number = 0
  private gyroStartMs: number = 0
  private gyroLastProbeMs: number = 0
  private gyroLastProbeSensor: string = ''
  private gyroRotationSubscribed: boolean = false
  private gyroOrientationSubscribed: boolean = false
  private gyroGravitySubscribed: boolean = false
  private gyroMagneticSubscribed: boolean = false
  private gyroCallback: ((data: sensor.OrientationResponse) => void) | undefined = undefined
  private gyroRotationCallback: ((data: sensor.RotationVectorResponse) => void) | undefined = undefined
  private gyroGravityCallback: ((data: sensor.GravityResponse) => void) | undefined = undefined
  private gyroMagneticCallback: ((data: sensor.MagneticFieldResponse) => void) | undefined = undefined
  private gyroUsingRotationVector: boolean = false
  // These are intentionally kept in device coordinates. Gravity and magnetic
  // samples remain available for compass, calibration and diagnostics. They
  // must not be mixed into only one camera axis because their callbacks are
  // asynchronous relative to ROTATION_VECTOR.
  private gyroGravityDevice: number[] = []
  private gyroMagneticDevice: number[] = []
  private gyroFilteredGravityDevice: number[] = []
  private gyroFilteredMagneticDevice: number[] = []
  private dragLogCount: number = 0
  private touchStartedOnUi: boolean = false
  private lastSkyTapAt: number = 0
  private lastSkyTapX: number = 0
  private lastSkyTapY: number = 0
  private skySelectionRequestSerial: number = 0
  private mouseSkyPressed: boolean = false
  private mouseSkyMoved: boolean = false
  private mouseSkyStartX: number = 0
  private mouseSkyStartY: number = 0
  private mouseSkyLastX: number = 0
  private mouseSkyLastY: number = 0
  private mouseSkyLastSampleMs: number = 0
  private lastCenterKeyAt: number = 0
  private lastDockActionAt: number = 0
  private lastDockActionPanel: string = ''
  private dockTouchActive: boolean = false
  private panelDragging: boolean = false
  private panelDragStartX: number = 0
  private panelDragStartY: number = 0
  private panelDragStartOffsetX: number = 0
  private panelDragStartOffsetY: number = 0

  // 所有设备共享同一动作模型。布局只决定面板如何呈现，不改变入口和语义。

  private moreActionStartsSection(item: ShellAction, index: number): boolean {
    if (index === 0) return true
    const actions = moreActions()
    return actions[index - 1].section !== item.section
  }
  private railTop(): number { return this.EDGE_MARGIN }

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

  aboutToAppear(): void {
    hilog.info(0x0000, 'StellariumArkUI', '[privacy-probe] phase=main-page-appear')
    const localStorage = this.getUIContext().getSharedLocalStorage()
    if (localStorage) {
      this.createInfo = localStorage.get<WindowNativeNodeCreateInfo>('createInfo')
    }
    // §14.1：把宿主桥注入 ToolsStore。ToolsStore 消费方均为 @ObjectLink，字段赋值即刷新，
    // 故此处 onChanged 注入等价空实现（该域无 publish* 发布点）。
    const hostPort = new HostCommandPort(
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
    this.tools.attachPort(hostPort, () => {})
    // §14 B3-1：角度测量加载器 loadAngleMeasure 与动作 toggleAngleMeasure 同片搬入 ToolsStore；
    // 动作回包后的 UI 提示经 ToolsHostHooks.flashHint 回注（store 不触碰 UI）。
    this.tools.attachHooks({
      flashHint: (text: ResourceStr): void => { this.flashHint(text) }
    })
    // §14 B1-1：望远镜/目镜域复用同一个 HostCommandPort 实例。其消费方均为 @ObjectLink，
    // 字段赋值即刷新，且该域无 publish* 发布点，故 onChanged 传空实现。
    this.telescopeStore.attachPort(hostPort, () => {})
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
      publishSearchBrowserState: (): void => { this.publishSearchBrowserState() }
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
      flashHint: (text: ResourceStr): void => { this.flashHint(text) }
    })
    this.sessionToolStore.attachPort(hostPort, () => {})
    this.skyCultureSettingsStore.attachPort(hostPort, () => {})
    this.objectDetailStore.attachPort(hostPort, () => {})
    // §14 B2R-4：卫星过境加载器 loadSelectedSatellitePasses 下沉 ObjectDetailStore，复用未随本片
    // 下沉的宿主助手 selectedObjectIsArtificialSatellite / requestSatellitePasses（经 hooks 回注）。
    this.objectDetailStore.attachHooks({
      selectedObjectIsArtificialSatellite: (): boolean => this.selectedObjectIsArtificialSatellite(),
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
    this.satelliteStore.attachPort(hostPort, () => { this.publishSatellitePanelState() })
    // §14 B1-6：位置域的 loadSavedLocations 读 AppStorage 而非桥，port 暂未使用（预留）。
    this.locationStore.attachPort(hostPort, () => {})
    // §14 B2A：Astro 簇加载器下沉。astroStore 复用同一 HostCommandPort；onChanged 走
    // publishAstroPanelState，保持 CLI 侧 stellariumAstroPanelState 同步；跨 store
    // （objectDetailStore / wutStore / ephemerisStore）与未随本片下沉的宿主加载器
    // （loadPlanetPositions）经 AstroHostHooks 具名注入（月相 / 天文计算上下文加载器已于 B3-2 下沉）。
    this.astroStore.attachPort(hostPort, () => { this.publishAstroPanelState() })
    this.astroStore.attachHooks({
      hasSelectedObject: () => this.hasSelectedObject(),
      selectedObjectName: () => this.objectDetailStore.selectedName,
      wutCategory: () => this.wutStore.wutCategory,
      wutObservationTime: () => this.wutStore.wutObservationTime,
      loadWutTargets: () => { this.wutStore.loadWutTargets() },
      ephemerisCustomStartJD: () => dateToJD(this.ephemerisStore.ephemerisStartYear, this.ephemerisStore.ephemerisStartMonth, this.ephemerisStore.ephemerisStartDay, 0, 0),
      fmtDateTime: (s: string | undefined) => this.fmtDateTime(s),
      hecLayoutPositions: (positions: Array<HeliocentricPosition>) => this.hecLayoutPositions(positions),
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
    // ObjectMediaStore。其读写的宿主逐帧裸字段（objectInspectorModelTexturePixels / RingTexture*）
    // 与 image / fileIo / decodeLocalImage 职责经 ObjectMediaHostHooks 具名注入（store 不 import
    // NAPI/UI）；该加载器不走桥、无 publish* 发布点，故不注入 CommandPort。
    this.objectMediaStore.attachHooks({
      readRawSidecar: (path: string, expectedBytes: number, label: string): ArrayBuffer => this.readRawSidecar(path, expectedBytes, label),
      decodeObjectInspectorModelTextureFromPng: (pngFilePath: string, ringPngFilePath: string, mediaGeneration: number, expectedSelection: string, expectedPath: string): void =>
        this.decodeObjectInspectorModelTextureFromPng(pngFilePath, ringPngFilePath, mediaGeneration, expectedSelection, expectedPath),
      commitObjectInspectorModelTexture: (texture: ArrayBuffer, ringTexture: ArrayBuffer | undefined, mediaGeneration: number, expectedSelection: string, expectedPath: string, sourceLabel: string): void =>
        this.commitObjectInspectorModelTexture(texture, ringTexture, mediaGeneration, expectedSelection, expectedPath, sourceLabel),
      failObjectInspectorModelTexture: (mediaGeneration: number, reason: string): void => this.failObjectInspectorModelTexture(mediaGeneration, reason)
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
      categoryModuleIdFor: (category: string): string => this.categoryModuleIdFor(category),
      ensurePluginLoaded: (pluginName: string, callback: () => void, failureCallback?: () => void): void => this.ensurePluginLoaded(pluginName, callback, failureCallback),
      celestialTitle: (nativeName: string, englishName: string): string => this.celestialTitle(nativeName, englishName),
      celestialSubtitle: (title: string, englishName: string): string => this.celestialSubtitle(title, englishName),
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
        this.executeGuideRequest(commandName, String(event['payload'] ?? ''), requestId)
        return
      }
      if (commandName === 'setSatellitesFlag' && response.ok === true) {
        const parts = String(event['payload'] ?? '').split(':')
        const enabled = parts[1] === '1' || parts[1] === 'true'
        this.satelliteFlagMutationId++
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
          this.setObjectInspectorModelImmersive(true)
        } else if (value === 'close') {
          this.setObjectInspectorModelImmersive(false)
        } else if (value === 'reset') {
          this.resetObjectInspectorModelView()
        } else {
          const parts = value.split('|')
          this.rotateObjectInspectorModel(Number(parts[0]), Number(parts[1]))
          this.requestObjectInspectorModelRender(true)
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
          this.toggleGyroscope(true)
          hilog.info(0x0000, 'StellariumArkUI', '[cli-ui] gyroscope enabled=true')
        } else if (value === '0' || value === 'false' || value === 'off') {
          this.toggleGyroscope(false)
          hilog.info(0x0000, 'StellariumArkUI', '[cli-ui] gyroscope enabled=false')
        } else {
          hilog.warn(0x0000, 'StellariumArkUI', '[cli-ui] rejected gyroscope value=%{public}s', value)
        }
        return
      }
      if (commandName === 'setTelescopeLivePosition') {
        const value = String(event['payload'] ?? '').trim().toLowerCase()
        const enabled = value === '1' || value === 'true' || value === 'on'
        this.setTelescopeLivePosition(enabled)
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
        this.scriptStartGraceUntil = Date.now() + 2500
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
      if (commandName === 'stopScript' && response.ok === true && this.scriptSessionActive()) {
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
    this.startupBridgeSync()
  }

  // 启动期只用一个轻量查询确认 Qt 核心就绪。其余查询分批执行，避免在
  // ArkUI 主线程上并发创建大量同步 NAPI 调用和重试链。
  private startupBridgeSync(): void {
    if (this.bridgeSyncStarted) { return }
    this.bridgeSyncStarted = true
    this.callNativeWhenReady("getSkyCultures", "", (r) => {
      if (r.ok !== true || !Array.isArray(r.items)) { return }
      this.skyCultureViewStore.skyCultures = r.items as string[]
      this.skyCultureViewStore.currentSkyCulture = r.current as string
      this.dismissSplash()
      this.runStartupBridgeTasks()
    })
  }

  private runStartupBridgeTasks(): void {
    const tasks: Array<() => void> = [
      () => this.callNativeWhenReady('setLanguage', this.languageStore.selectedLanguage, () => {}),
      () => this.layerViewStore.loadLandscapeList(),
      () => this.callNativeWhenReady("getScriptList", "", (r) => {
        if (r.ok === true && Array.isArray(r.items)) { this.scriptStore.scriptList = r.items as string[]; this.scriptStore.setScriptMetadata(r.details) }
      }),
      () => this.callNativeWhenReady('getProjectionList', '', (r) => {
        if (r.ok === true && r.current !== undefined) { this.currentProjection = r.current as string }
      }),
      () => this.callNativeWhenReady('getConfigString', 'astronomy/flag_use_km_for_distance', (r) => {
        if (r.ok) { this.viewSettingsStore.useMetricUnits = r.value === 'true' }
      }),
      () => this.callNativeWhenReady('getLimitMagnitude', '', (r) => {
        const response = r as LimitMagnitudeResponse
        if (response.ok && response.customStarMagLimit !== undefined) {
          const value = Number(response.customStarMagLimit)
          if (!isNaN(value)) { this.layerViewStore.starMagLimit = Math.round(value * 10) / 10 }
        }
      }),
      () => this.restoreStartupSettings(),
      () => this.callNativeWhenReady("setFlatHorizon", "1", (r: StellariumBridgeResponse) => {
        if (r.ok === true) { this.viewSettingsStore.flatHorizon = true }
      }),
      () => this.callNativeWhenReady("setActionChecked", "actionShow_Zenith_Nadir|1", (r: StellariumBridgeResponse) => {
        if (r.ok === true) { this.layerStore.zenithNadir = true }
      }),
      () => { if (this.SELFTEST) { this.selfTestAllActions() } },
    ]
    let taskIndex = 0
    const runNext = (): void => {
      if (taskIndex >= tasks.length) { return }
      tasks[taskIndex++]()
      setTimeout(runNext, 48)
    }
    runNext()
  }

  private restoreStartupSettings(): void {
    this.skyCultureViewStore.loadSkyCultureList()
    this.pluginStore.loadPluginList()
    const settings = AppStorage.get<string>("stellariumSettings")
    if (settings) {
      try {
        const saved = JSON.parse(settings) as Record<string, boolean | string>
        if (saved.nightMode !== undefined) {
          this.nightModeStore.nightMode = saved.nightMode as boolean
                    this.callNativeWhenReady('setNightMode', this.nightModeStore.nightMode ? 'true' : 'false', () => {})
        }
        if (saved.equatorialMount !== undefined) {
          this.telescopeStore.equatorialMount = saved.equatorialMount as boolean
          this.callNativeWhenReady('setActionChecked', 'actionSwitch_Equatorial_Mount|' + (this.telescopeStore.equatorialMount ? '1' : '0'), () => {})
        }
        if (saved.gyroscopeEnabled !== undefined) {
          this.gyroStore.gyroscopeEnabled = false
          this.gyroStore.gyroscopeStatus = I18n.t('m_gyro_off')
        }
        if (saved.gyroscopeSensitivityText !== undefined) { this.gyroStore.gyroscopeSensitivityText = saved.gyroscopeSensitivityText as string }
        if (saved.selectedLanguage !== undefined) {
          const language = saved.selectedLanguage as string
          if (language !== this.languageStore.selectedLanguage) {
            I18n.setLanguage(I18n.fromStellariumCode(language))
            this.setLanguage(language)
          }
        }
        if (saved.musicEnabled !== undefined) { this.audioStore.musicEnabled = saved.musicEnabled as boolean }
        if (saved.useMetricUnits !== undefined) { this.viewSettingsStore.useMetricUnits = saved.useMetricUnits as boolean }
        if (saved.viewCoordinatesVisible !== undefined) { this.overlayStore.viewCoordinatesVisible = saved.viewCoordinatesVisible as boolean }
        if (saved.viewCoordinateFamily !== undefined) { this.overlayStore.viewCoordinateFamily = saved.viewCoordinateFamily as string }
        if (saved.viewEquatorialEpoch !== undefined) { this.overlayStore.viewEquatorialEpoch = saved.viewEquatorialEpoch as string }
        if (saved.objectDetailConnectorVisible !== undefined) { this.overlayStore.objectDetailConnectorVisible = saved.objectDetailConnectorVisible as boolean }
        const savedAstroTab = Number(saved.astroTab)
        if (Number.isInteger(savedAstroTab) && savedAstroTab >= 0 && savedAstroTab <= 9) {
          this.astroStore.astroTab = savedAstroTab
          this.astroStore.astroGroup = astroGroupForTab(savedAstroTab)
        }
        const savedPositionMode = Number(saved.positionMode)
        if (Number.isInteger(savedPositionMode) && savedPositionMode >= 0 && savedPositionMode <= 2) this.astroStore.positionMode = savedPositionMode
        const savedCelestialMagnitude = Number(saved.celestialPositionMagnitude)
        if (Number.isFinite(savedCelestialMagnitude)) this.astroStore.celestialPositionMagnitude = clamp(savedCelestialMagnitude, -5, 25)
        if (saved.celestialPositionCategory !== undefined) this.astroStore.celestialPositionCategory = saved.celestialPositionCategory as string
        if (saved.celestialPositionHorizontal !== undefined) this.astroStore.celestialPositionHorizontal = saved.celestialPositionHorizontal === 'true'
        const savedEphemerisMode = Number(saved.ephemerisMode)
        if (Number.isInteger(savedEphemerisMode) && savedEphemerisMode >= 0 && savedEphemerisMode <= 2) this.astroStore.ephemerisMode = savedEphemerisMode
        const savedEphemerisDays = Number(saved.ephemerisDays)
        if (Number.isInteger(savedEphemerisDays) && savedEphemerisDays >= 1 && savedEphemerisDays <= 31) this.astroStore.ephemerisDays = savedEphemerisDays
        const savedEphemerisStep = Number(saved.ephemerisStepHours)
        if (Number.isInteger(savedEphemerisStep) && savedEphemerisStep >= 1 && savedEphemerisStep <= 24) this.astroStore.ephemerisStepHours = savedEphemerisStep
        const savedRtsDays = Number(saved.rtsCalendarDays)
        if (Number.isInteger(savedRtsDays) && savedRtsDays >= 1 && savedRtsDays <= 365) this.astroStore.rtsCalendarDays = savedRtsDays
        const savedGraphMode = Number(saved.graphMode)
        if (Number.isInteger(savedGraphMode) && savedGraphMode >= 0 && savedGraphMode <= 5) this.astroStore.graphMode = savedGraphMode
        const savedEclipseMonths = Number(saved.eclipseMonths)
        if (Number.isInteger(savedEclipseMonths) && savedEclipseMonths >= 1 && savedEclipseMonths <= 60) this.astroStore.eclipseMonths = savedEclipseMonths
        const savedMoonPhaseDays = Number(saved.moonPhaseDays)
        if (savedMoonPhaseDays === 30 || savedMoonPhaseDays === 90) this.astroStore.moonPhaseDays = savedMoonPhaseDays
      } catch (_err) { }
    }
    if (this.audioStore.musicEnabled) { AudioEngine.getInstance().start() }
    I18n.setLanguage(I18n.fromStellariumCode(this.languageStore.selectedLanguage))
    this.syncViewCoordinateTimer()
    this.syncDockClockTimer()
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
    if (this.guideTimer >= 0) clearInterval(this.guideTimer)
    this.guideTimer = -1
    this.guideGyroWasEnabled = false
    this.guidePanelWasVisible = false
    this.guidePlayer?.stop()
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
    this.stopSkyInertia()
    this.stopGyroscope(false)
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
    this.releaseDecodedImage(skyCulturePixelMap, 'disappear-sky-culture-art')
    this.clearSkyCultureMakerArtworkPreview('disappear-sky-culture-maker-artwork')
    this.stopSkyTextureStatusObserver()
    this.stopTimePanelTimers()
    this.stopViewCoordinateTimer()
    this.stopDockClockTimer()
    if (this.timeWheelController !== undefined) { this.timeWheelController.stop() }
    this.stopSkyCultureTimeFollowTimer()
    this.stopPolarScopeTimer()
    this.stopAstroCalcContextTimer()
    this.stopTelescopeLivePosition(false)
    this.stopScriptStatusPolling()
    if (this.scriptStore.replaying) {
      this.finishRecordingReplay('回放已结束')
    }
    this.tools.recording = false
    this.tools.recordingPaused = false
    this.unregisterFoldListeners()
    this.unsubscribeApplicationLifecycle()
  }

  private handleApplicationLifecycle = (foreground: boolean): void => {
    this.applicationInForeground = foreground
    if (!foreground && this.guideStore.guideState.phase === 'observing') this.guidePlayer?.action('pause')
    this.objectInspectorModelRenderClient?.setSuspended(!foreground)
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
      if (this.gyroPausedForBackground) {
        this.gyroPausedForBackground = false
        this.startGyroscope()
        hilog.info(0x0000, 'StellariumArkUI', 'foreground: gyroscope subscriptions restored')
      }
      this.syncViewCoordinateTimer()
      this.syncDockClockTimer()
      this.syncSkyCultureTimeFollowTimer()
      this.syncPolarScopeTimer()
      this.syncAstroCalcContextTimer()
      this.syncTelescopeLivePosition()
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
    this.stopTelescopeLivePosition(false)
    this.stopDetailAutoRefresh()
    this.stopSkyInertia()
    void AudioEngine.getInstance().stop()
    if (this.gyroStore.gyroscopeEnabled) {
      this.gyroPausedForBackground = true
      this.stopGyroscope(false)
      hilog.info(0x0000, 'StellariumArkUI', 'background: gyroscope subscriptions released')
    }
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

  private stopTelescopeLivePosition(markStale: boolean = true): void {
    if (this.lx200LivePositionTimer !== 0) {
      clearTimeout(this.lx200LivePositionTimer)
      this.lx200LivePositionTimer = 0
    }
    this.lx200LivePositionRequestPending = false
    this.lx200LivePositionRequestId++
    if (markStale && this.telescopeStore.lx200Position.length > 0) {
      this.telescopeStore.lx200PositionUpdateState = 'stale'
    }
  }

  private scheduleTelescopeLivePosition(delayMs: number = 1000): void {
    if (!this.shouldRefreshTelescopePosition() || this.lx200LivePositionTimer !== 0) return
    this.lx200LivePositionTimer = setTimeout(() => {
      this.lx200LivePositionTimer = 0
      this.refreshTelescopeLivePosition()
    }, delayMs) as number
  }


  private refreshTelescopeLivePosition(): void {
    if (!this.shouldRefreshTelescopePosition() || this.lx200LivePositionRequestPending) return
    this.lx200LivePositionRequestPending = true
    this.telescopeStore.lx200PositionUpdateState = 'updating'
    const requestId = ++this.lx200LivePositionRequestId
    this.callInteractive('getTelescopePosition', this.lx200Payload(), (result: TelescopeControlResponse) => {
      if (requestId !== this.lx200LivePositionRequestId) return
      this.lx200LivePositionRequestPending = false
      if (result.ok === true) {
        this.telescopeStore.lx200ConnectionState = 'available'
        this.telescopeStore.lx200Position = (result.ra ?? '--:--:--') + ' / ' + (result.dec ?? '--°--:--')
        this.telescopeStore.lx200PositionUpdatedAt = telescopeUpdateTime()
        this.telescopeStore.lx200PositionUpdateState = 'fresh'
        this.scheduleTelescopeLivePosition(1000)
        return
      }
      if (result.state === 'available' || result.state === 'unavailable') this.telescopeStore.lx200ConnectionState = result.state
      this.telescopeStore.lx200PositionUpdateState = 'error'
      this.telescopeStore.lx200Status = telescopeErrorText(result, I18n.t('m_telescope_position_failed'))
      this.scheduleTelescopeLivePosition(1800)
    }, (result: StellariumBridgeResponse) => {
      if (requestId !== this.lx200LivePositionRequestId) return
      this.lx200LivePositionRequestPending = false
      this.telescopeStore.lx200PositionUpdateState = 'error'
      this.telescopeStore.lx200Status = result.error ?? I18n.t('m_telescope_position_failed')
      this.scheduleTelescopeLivePosition(1800)
    })
  }

  private syncTelescopeLivePosition(): void {
    if (!this.shouldRefreshTelescopePosition()) {
      this.stopTelescopeLivePosition()
      return
    }
    if (this.lx200LivePositionRequestPending || this.lx200LivePositionTimer !== 0) return
    this.refreshTelescopeLivePosition()
  }

  private setTelescopeLivePosition(enabled: boolean): void {
    this.telescopeStore.lx200LivePositionEnabled = enabled
    if (enabled) {
      this.telescopeStore.lx200PositionUpdateState = 'updating'
      this.syncTelescopeLivePosition()
    } else {
      this.stopTelescopeLivePosition()
    }
  }

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

  private panelRouteRoot(panel: string): string {
    const mainPanels = ['search', 'time', 'place', 'layers', 'more']
    if (mainPanels.indexOf(panel) >= 0) return panel
    return 'more'
  }

  private panelRouteParent(panel: string): string {
    if (panel === 'observeHub' || panel === 'dataHub' || panel === 'automationHub') return 'more'
    if (panel === 'pluginManager') return 'dataHub'
    if (observingHubActions().some((item: ShellAction) => item.panel === panel)) return 'observeHub'
    if (skyDataHubActions().some((item: ShellAction) => item.panel === panel)) return 'dataHub'
    if (automationHubActions().some((item: ShellAction) => item.panel === panel)) return 'automationHub'
    return ''
  }

  private openPanelFromCli(panel: string): void {
    if (panel === 'settingsInformation' || panel === 'settingsTime' || panel === 'settingsPrivacy') {
      this.openPanelFromCli('settings')
      this.selectConfigTab(panel === 'settingsInformation' ? 1 : (panel === 'settingsTime' ? 3 : -1))
      return
    }
    const parent = this.panelRouteParent(panel)
    this.panelNavigationStack = parent.length > 0 ? [parent] : []
    this.panelNavigationDepth = this.panelNavigationStack.length
    this.setPanel(panel, true, true)
  }

  private inferredPanelRouteDirection(fromPanel: string, toPanel: string): number {
    if (fromPanel === toPanel) return 1
    const routeOrder = ['search', 'time', 'place', 'layers', 'more']
    const fromRoot = this.panelRouteRoot(fromPanel)
    const toRoot = this.panelRouteRoot(toPanel)
    const fromIndex = routeOrder.indexOf(fromRoot)
    const toIndex = routeOrder.indexOf(toRoot)
    if (fromIndex >= 0 && toIndex >= 0 && fromIndex !== toIndex) {
      return toIndex > fromIndex ? 1 : -1
    }
    if (this.panelRouteParent(toPanel) === fromPanel) return 1
    if (this.panelRouteParent(fromPanel) === toPanel) return -1
    if (this.panelRouteParent(fromPanel).length > 0 &&
      this.panelRouteParent(fromPanel) === this.panelRouteParent(toPanel)) return 1
    return 1
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
      ? this.inferredPanelRouteDirection(currentPanel, panel)
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
    this.stopTelescopeLivePosition(false)
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
        this.loadCatalogHealth()
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
        this.loadCatalogHealth()
        this.ensurePluginLoaded('Satellites', () => { this.loadSatellites(true, true) })
      } else if (panel === 'meteorshowers') {
        this.ensurePluginLoaded('MeteorShowers', () => { this.meteorStore.loadMeteorShowers() })
      } else if (panel === 'scenery3d') {
        this.ensurePluginLoaded('Scenery3d', () => { this.loadScenery3d() })
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
        this.loadVideoRecordingState()
      } else if (panel === 'telescope') {
        this.loadTelescopeControlStatus()
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
    return this.panelNavigationStack.length > 0 || this.panelRouteParent(this.activePanel).length > 0
  }

  private handlePanelBackTap(): void {
    const now = Date.now()
    if (now - this.lastPanelBackAt < 240) return
    this.lastPanelBackAt = now
    hilog.info(0x0000, 'StellariumArkUI', '[panel-back] panel=%{public}s stack=%{public}d parent=%{public}s',
      this.activePanel, this.panelNavigationStack.length, this.panelRouteParent(this.activePanel))
    this.goBackPanel()
  }

  private isPanelBackPoint(x: number, y: number): boolean {
    if (!this.canGoBackPanel()) return false
    const width = this.isExpandedLayout ? this.panelWidth : this.skyWidth * (this.isFoldHoverLayout ? 0.72 : 0.94)
    const left = this.isExpandedLayout ? this.panelLeft() : (this.skyWidth - width) / 2
    const top = this.isExpandedLayout ? this.panelTop() : this.skyHeight - 90 - this.compactPanelHeight()
    return x >= left - 8 && x <= left + Math.min(width * 0.52, 142) && y >= top - 10 && y <= top + 82
  }

  private goBackPanel(): void {
    let previous = ''
    if (this.panelNavigationStack.length > 0) {
      previous = this.panelNavigationStack[this.panelNavigationStack.length - 1]
      this.panelNavigationStack = this.panelNavigationStack.slice(0, this.panelNavigationStack.length - 1)
    } else {
      previous = this.panelRouteParent(this.activePanel)
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
    this.stopTelescopeLivePosition(false)
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
    if (r.ok === true) { this.recordAcceptedCommand(name, payload) }
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
      if (accepted) { this.recordAcceptedCommand(name, payload) }
    }
  }

  private recordAcceptedCommand(name: string, payload: string): void {
    if (!this.tools.recording || this.tools.recordingPaused || this.scriptStore.replaying || !isRecordable(name)) { return }
    const key = name + '|' + payload
    const now = Date.now()
    if (key === this.lastRecordKey && now - this.lastRecordTime <= 400) { return }
    this.recordBuffer.push({ c: name, p: payload,
      t: Math.max(0, now - this.recordStartedAt - this.recordPausedTotal) })
    this.scriptStore.recordCount = this.recordBuffer.length
    this.lastRecordKey = key
    this.lastRecordTime = now
  }

  private cancelRecordingViewCheckpoint(): void {
    if (this.recordViewCheckpointTimer >= 0) {
      clearTimeout(this.recordViewCheckpointTimer)
      this.recordViewCheckpointTimer = -1
    }
  }

  private scheduleRecordingViewCheckpoint(delayMs: number = 900, fullSession: boolean = false): void {
    this.cancelRecordingViewCheckpoint()
    if (!this.tools.recording || this.tools.recordingPaused || this.scriptStore.replaying) { return }
    this.recordViewCheckpointTimer = setTimeout(() => {
      this.recordViewCheckpointTimer = -1
      this.callInteractive('getSessionState', '', (response: StellariumBridgeResponse) => {
        if (!this.tools.recording || this.tools.recordingPaused || this.scriptStore.replaying || response.ok !== true) { return }
        const state = response as SessionSnapshot
        const checkpoint: SessionSnapshot = fullSession ? {
          schemaVersion: 1,
          viewJ2000: state.viewJ2000,
          fovDeg: state.fovDeg,
          jd: state.jd,
          location: state.location,
          selected: state.selected,
          flags: state.flags
        } : {
          schemaVersion: 1,
          viewJ2000: state.viewJ2000,
          fovDeg: state.fovDeg
        }
        this.recordAcceptedCommand('applySessionState', JSON.stringify(checkpoint))
      })
    }, delayMs) as number
  }

  // Retry a native command until the Stellarium core is initialized.
  // At startup the ArkUI thread may call the bridge before Qt has finished
  // bootstrapping; those calls return ok:false and are retried on a short
  // backoff instead of crashing the process.
  private callNativeWhenReady(name: string, payload: string = '', onOk?: (r: StellariumBridgeResponse) => void, attempt: number = 0, intervalMs: number = 200, maxAttempts: number = 60, onFailure?: (r: StellariumBridgeResponse) => void): void {
    BridgeClient.requestWhenReady(name, payload, (r: StellariumBridgeResponse) => {
      // 录制：仅在录制开启、非回放、且命令可录制时记录，并对短时重试用去重窗口避免重复。
      this.recordAcceptedCommand(name, payload)
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
      this.stopSkyInertia()
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
  private startRecording(): void {
    if (this.scriptSessionActive()) {
      this.flashHint('脚本或回放进行中，结束后再开始录制')
      return
    }
    this.tools.recording = true
    this.tools.recordingPaused = false
    this.recordBuffer = []
    this.scriptStore.recordCount = 0
    this.scriptStore.recordMsg = '录制中…'
    this.lastRecordKey = ''
    this.lastRecordTime = 0
    this.recordStartedAt = Date.now()
    this.recordPausedAt = 0
    this.recordPausedTotal = 0
    this.tools.recordingUiExpanded = false
    this.panelVisible = false
    this.infoWindowStore.infoWinVisible = false
    this.scheduleRecordingViewCheckpoint(80, true)
    this.flashHint('开始录制：接下来的操作会被记录')
  }

  private toggleRecordingPause(): void {
    if (!this.tools.recording) { return }
    const now = Date.now()
    this.tools.recordingPaused = !this.tools.recordingPaused
    if (this.tools.recordingPaused) {
      this.cancelRecordingViewCheckpoint()
      this.recordPausedAt = now
    } else if (this.recordPausedAt > 0) {
      this.recordPausedTotal += now - this.recordPausedAt
      this.recordPausedAt = 0
    }
    this.scriptStore.recordMsg = this.tools.recordingPaused ? '已暂停录制' : '录制中…'
    this.lastRecordKey = ''
    this.lastRecordTime = 0
    this.flashHint(this.scriptStore.recordMsg)
  }

  private stopRecording(): void {
    if (this.tools.recordingPaused && this.recordPausedAt > 0) {
      this.recordPausedTotal += Date.now() - this.recordPausedAt
      this.recordPausedAt = 0
    }
    this.tools.recording = false
    this.cancelRecordingViewCheckpoint()
    this.tools.recordingPaused = false
    this.tools.recordingUiExpanded = true
    this.scriptStore.recordCount = this.recordBuffer.length
    this.scriptStore.recordMsg = this.scriptStore.recordCount > 0 ? '已停止，可保存' : '已停止（没有可保存的操作）'
    this.flashHint(this.scriptStore.recordMsg)
    this.setPanel('scripts')
  }

  private saveCurrentRecording(): void {
    if (this.recordBuffer.length === 0) {
      this.scriptStore.recordMsg = '没有可保存的操作，请先开始录制'
      this.flashHint(this.scriptStore.recordMsg)
      return
    }
    const safeName = this.scriptStore.recordName.trim().replace(/\|/g, '_').replace(/\n/g, ' ')
    const payload = safeName + '|' + JSON.stringify(this.recordBuffer)
    this.callInteractive('saveRecording', payload, (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.scriptStore.recordMsg = '已保存：' + (r.name ?? this.scriptStore.recordName)
        this.flashHint(this.scriptStore.recordMsg)
        this.recordBuffer = []
        this.scriptStore.recordCount = 0
        this.scriptStore.recordName = ''
        this.scriptStore.loadRecordings()
      } else {
        this.scriptStore.recordMsg = '保存失败：' + (r.error ?? '未知错误')
        this.flashHint(this.scriptStore.recordMsg)
      }
    })
  }

  private playRecording(file: string): void {
    if (this.scriptSessionActive()) {
      this.flashHint('已有脚本或回放正在运行')
      return
    }
    this.callInteractive('loadRecording', file, (r: StellariumBridgeResponse) => {
      const resp = r as RecordingDetailResponse
      const cmds = resp.commands ?? []
      if (cmds.length === 0) {
        this.flashHint(I18n.t('msg_recording_empty'))
        return
      }
      this.scriptStore.replaying = true
      this.scriptStore.replayPaused = false
      this.scriptStore.replayRate = 1
      this.scriptStore.replayName = resp.name ?? file
      this.replayCommands = cmds
      this.replayIndex = 0
      this.replayStartedAt = Date.now()
      this.replayPauseStartedAt = 0
      this.replayPausedTotal = 0
      this.flashHint('正在回放 ' + cmds.length + ' 条命令…')
      this.replayNextCommand()
    })
  }

  private replayNextCommand(): void {
    if (!this.scriptStore.replaying || this.scriptStore.replayPaused) { return }
    if (this.replayIndex >= this.replayCommands.length) {
      this.finishRecordingReplay('回放完成')
      return
    }
    const commandItem = this.replayCommands[this.replayIndex]
    const fallbackTime = this.replayIndex * 40
    const targetTime = typeof commandItem.t === 'number' && Number.isFinite(commandItem.t)
      ? Math.max(0, commandItem.t) : fallbackTime
    const timelineElapsed = this.replayTimelineMs()
    const delay = Math.max(0, (targetTime - timelineElapsed) / Math.max(0.25, this.scriptStore.replayRate))
    this.replayTimer = setTimeout(() => {
      if (!this.scriptStore.replaying) { return }
      this.replayIndex++
      this.callNativeWhenReady(commandItem.c, commandItem.p, () => {
        this.replayNextCommand()
      }, 0, 100, 15, () => {
        this.finishRecordingReplay('回放中断：命令执行失败')
      })
    }, delay) as number
  }

  private finishRecordingReplay(message: string): void {
    if (this.replayTimer >= 0) {
      clearTimeout(this.replayTimer)
      this.replayTimer = -1
    }
    this.scriptStore.replaying = false
    this.scriptStore.replayPaused = false
    this.scriptStore.replayRate = 1
    this.scriptStore.replayName = ''
    this.replayCommands = []
    this.replayIndex = 0
    this.replayPauseStartedAt = 0
    this.replayPausedTotal = 0
      this.flashHint(message)
  }

  private replayTimelineMs(): number {
    const now = this.scriptStore.replayPaused && this.replayPauseStartedAt > 0
      ? this.replayPauseStartedAt : Date.now()
    return Math.max(0, now - this.replayStartedAt - this.replayPausedTotal) * this.scriptStore.replayRate
  }

  private toggleReplayPause(): void {
    if (!this.scriptStore.replaying) { return }
    if (this.scriptStore.replayPaused) {
      if (this.replayPauseStartedAt > 0) {
        this.replayPausedTotal += Date.now() - this.replayPauseStartedAt
      }
      this.replayPauseStartedAt = 0
      this.scriptStore.replayPaused = false
      this.flashHint('回放继续')
      this.replayNextCommand()
      return
    }
    if (this.replayTimer >= 0) {
      clearTimeout(this.replayTimer)
      this.replayTimer = -1
    }
    this.replayPauseStartedAt = Date.now()
    this.scriptStore.replayPaused = true
    this.flashHint('回放已暂停')
  }

  private changePlaybackRate(direction: number): void {
    if (this.scriptStore.replaying) {
      const next = Math.max(0.25, Math.min(16, this.scriptStore.replayRate * (direction > 0 ? 2 : 0.5)))
      const timeline = this.replayTimelineMs()
      const anchor = this.scriptStore.replayPaused && this.replayPauseStartedAt > 0
        ? this.replayPauseStartedAt : Date.now()
      this.scriptStore.replayRate = next
      this.replayStartedAt = anchor - this.replayPausedTotal - timeline / next
      if (this.replayTimer >= 0) {
        clearTimeout(this.replayTimer)
        this.replayTimer = -1
      }
      this.replayNextCommand()
      return
    }
    this.changeScriptRate(direction)
  }

  private toggleRecordingUi(): void {
    this.tools.recordingUiExpanded = !this.tools.recordingUiExpanded
    if (!this.tools.recordingUiExpanded) {
      this.panelVisible = false
      this.infoWindowStore.infoWinVisible = false
      this.gyroStore.gyroCalibPanelOpen = false
    }
  }

  private scriptPlaybackVisible(): boolean {
    return this.guideStore.guideState.active || this.scriptStore.scriptFocusActive || this.scriptStore.scriptLaunching || this.scriptStore.replaying
  }

  private scriptSessionActive(): boolean {
    return this.tools.recording || this.scriptPlaybackVisible()
  }

  private scriptControlWidth(): number {
    return Math.max(280, Math.min(this.skyWidth - 24, this.scriptStore.replaying ? 520 : 500))
  }

  private scriptControlCompact(): boolean {
    return this.scriptControlWidth() < 390
  }

  private scriptControlSafeTop(): number {
    const safeTop = this.getUIContext().px2vp(Math.max(0, this.screenSafeTopPixels))
    return Math.max(this.EDGE_MARGIN, safeTop + 12)
  }

  private scriptControlX(): number {
    const maxX = Math.max(8, this.skyWidth - this.scriptControlWidth() - 8)
    return clamp(12 + this.scriptStore.scriptControlOffsetX, 8, maxX)
  }

  private scriptControlY(): number {
    const safeTop = this.scriptControlSafeTop()
    const maxY = Math.max(safeTop, this.skyHeight - this.scriptControlHeight() - 12)
    return clamp(safeTop + this.scriptStore.scriptControlOffsetY, safeTop, maxY)
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
      this.stopSkyInertia()
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
        this.scriptStore.scriptControlOffsetX = this.guideCardX() - (this.isExpandedLayout ? 12 : (this.skyWidth - this.guideCardWidth()) / 2)
        this.scriptStore.scriptControlOffsetY = this.guideCardY() - (this.skyHeight - this.guideCardHeight() - 16)
      } else {
        this.scriptStore.scriptControlOffsetX = this.scriptControlX() - 12
        this.scriptStore.scriptControlOffsetY = this.scriptControlY() - this.scriptControlSafeTop()
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
    this.scriptStartGraceUntil = 0
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
    if (this.guideStore.guideState.active || this.scriptStatusRequestPending || !this.scriptPlaybackVisible()) { return }
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
      if (!running && !this.scriptStore.scriptLaunching && !this.scriptStore.replaying && Date.now() >= this.scriptStartGraceUntil) {
        this.finishNativeScriptUi(I18n.t('script_finished'))
      }
    }, () => {
      this.scriptStatusRequestPending = false
    })
  }

  private refreshScriptCaptions(): void {
    if (this.scriptCaptionsRequestPending || !this.scriptPlaybackVisible()) return
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

  private visibleScriptCaptions(): Array<string> {
    return this.scriptStore.scriptCaptions.slice(-3)
  }

  private visibleScriptCaptionText(): string {
    return this.visibleScriptCaptions().join('\n')
  }

  private scriptWaitDisplayText(): string {
    const message = this.scriptStore.scriptWaitMessage.trim()
    if (message.length === 0 || /press\s+(any\s+)?key\s+to\s+continue/i.test(message)) {
      return I18n.t('script_wait_hint')
    }
    return message
  }

  private stopScriptPlayback(): void {
    if (this.guideStore.guideState.active) {
      this.executeGuideRequest('guideAction', 'stop')
      return
    }
    if (this.scriptStore.replaying) {
      this.finishRecordingReplay('回放已停止')
    }
    this.callInteractive('stopScript', '', (r: StellariumBridgeResponse) => {
      this.finishNativeScriptUi(r.ok === true ? I18n.t('script_stopped') : I18n.t('script_stop_failed'))
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

  private deleteRecording(file: string): void {
    this.callInteractive('deleteRecording', file, (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.flashHint(I18n.t('msg_recording_deleted'))
        this.scriptStore.loadRecordings()
      } else {
        this.flashHint(I18n.t('msg_delete_failed'))
      }
    })
  }

  private continueNativeScript(): void {
    if (!this.scriptStore.scriptRunning || this.scriptStore.replaying) return
    this.callInteractive('continueScript', '', (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.getUIContext().animateTo({ duration: 160, curve: Curve.EaseOut }, () => {
          this.scriptStore.scriptWaiting = false
          this.scriptStore.scriptWaitMessage = ''
        })
        this.flashHint(I18n.t('script_continue'))
      } else {
        this.flashHint(I18n.t('script_continue_failed'))
      }
    })
  }

  private sendScriptKey(key: string): void {
    if (!this.scriptStore.scriptRunning || this.scriptStore.replaying) return
    this.callInteractive('sendKey', key, (r: StellariumBridgeResponse) => {
      if (r.ok !== true) {
        this.flashHint('脚本按键不可用')
      }
    })
  }

  private scriptControlHeight(): number {
    return this.scriptStore.replaying ? 176 : 224
  }

  private scriptKeyButtonWidth(): number {
    return Math.max(32, Math.min(44, (this.scriptControlWidth() - 49) / 6))
  }

  // loadScriptList / setScriptMetadata 已下沉 ScriptStore（§14 B2R-4）。

  private scriptMeta(filename: string): ScriptMetadata | undefined {
    return this.scriptStore.scriptMetadata[filename]
  }

  private scriptMetaLine(filename: string): string {
    const metadata = this.scriptMeta(filename)
    if (metadata === undefined) { return I18n.t('resource_not_provided') }
    const values: string[] = []
    values.push(I18n.t('resource_author') + ': ' + resourceText(metadata.author, I18n.t('resource_not_provided')))
    values.push(I18n.t('resource_license') + ': ' + resourceText(metadata.license, I18n.t('resource_not_provided')))
    if (metadata.version && metadata.version.trim().length > 0) { values.push(I18n.t('resource_version') + ': ' + metadata.version.trim()) }
    return values.join(' · ')
  }

  private scriptSourceLine(filename: string): string {
    const metadata = this.scriptMeta(filename)
    return metadata !== undefined && metadata.source ? I18n.t('resource_source') + ': ' + metadata.source : ''
  }

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

  private async shareFile(path: string, type: string, title: string, description: string,
    anchorId: string): Promise<void> {
    if (path.length === 0 || !fileIo.accessSync(path)) {
      this.flashHint('没有可分享的文件')
      return
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const data = new systemShare.SharedData({
        utd: type,
        uri: fileUri.getUriFromPath(path),
        title: title,
        description: description
      })
      const controller = new systemShare.ShareController(data)
      const options: systemShare.ShareControllerOptions = this.isExpandedLayout ? { anchor: anchorId } : {}
      await controller.show(context, options)
    } catch (error) {
      hilog.error(0x0000, 'StellariumArkUI', 'Share failed: %{public}s', String(error))
      this.flashHint('无法打开系统分享面板')
    }
  }

  private async saveFileAs(path: string, fileName: string, suffixLabel: string): Promise<void> {
    if (path.length === 0 || !fileIo.accessSync(path)) {
      this.flashHint('没有可导出的文件')
      return
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const options = new picker.DocumentSaveOptions()
      options.newFileNames = [fileName]
      options.fileSuffixChoices = [suffixLabel]
      const uris = await new picker.DocumentViewPicker(context).save(options)
      if (uris.length > 0) {
        await fileIo.copy(fileUri.getUriFromPath(path), uris[0])
        this.flashHint('文件已导出')
      }
    } catch (error) {
      hilog.error(0x0000, 'StellariumArkUI', 'Export file failed: %{public}s', String(error))
      this.flashHint('导出失败')
    }
  }

  private closeScreenCaptureFile(): void {
    if (this.screenCaptureFile !== undefined) {
      try { fileIo.closeSync(this.screenCaptureFile.fd) } catch (_error) {}
      this.screenCaptureFile = undefined
    }
  }

  private async finalizeScreenVideo(message: string): Promise<void> {
    if (this.scriptStore.screenCaptureFinalizing) { return }
    this.scriptStore.screenCaptureFinalizing = true
    const recorder = this.screenCapture
    this.screenCapture = undefined
    if (recorder !== undefined) {
      try { recorder.off('stateChange') } catch (_error) {}
      try { recorder.off('error') } catch (_error) {}
      try { await recorder.release() } catch (_error) {}
    }
    this.closeScreenCaptureFile()
    this.scriptStore.screenVideoRecording = false
    try {
      this.scriptStore.screenVideoBytes = this.scriptStore.screenVideoPath.length > 0 ? fileIo.statSync(this.scriptStore.screenVideoPath).size : 0
    } catch (_error) {
      this.scriptStore.screenVideoBytes = 0
    }
    this.scriptStore.screenVideoStatus = this.scriptStore.screenVideoBytes > 0 ? message : '录屏没有生成有效视频'
    this.scriptStore.screenCaptureFinalizing = false
    this.flashHint(this.scriptStore.screenVideoStatus)
  }

  private async startScreenVideoRecording(): Promise<void> {
    if (this.scriptStore.screenVideoRecording || this.scriptStore.screenCaptureFinalizing) { return }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const dir = context.filesDir + '/recordings/videos'
      fileIo.mkdirSync(dir, true)
      this.scriptStore.screenVideoFileName = 'stellarium-screen-' + Date.now().toString() + '.mp4'
      this.scriptStore.screenVideoPath = dir + '/' + this.scriptStore.screenVideoFileName
      this.scriptStore.screenVideoBytes = 0
      this.scriptStore.screenVideoStatus = '等待系统录屏授权…'
      this.screenCaptureFile = fileIo.openSync(this.scriptStore.screenVideoPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
      const displayInfo = display.getDefaultDisplaySync()
      const frameWidth = Math.max(64, Math.floor(displayInfo.width / 64) * 64)
      const frameHeight = Math.max(2, Math.floor(displayInfo.height / 2) * 2)
      const recorder = await media.createAVScreenCaptureRecorder()
      this.screenCapture = recorder
      recorder.on('stateChange', (state: media.AVScreenCaptureStateCode) => {
        if (state === media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_STARTED) {
          this.scriptStore.screenVideoRecording = true
          this.scriptStore.screenVideoStatus = '正在录制 MP4'
        } else if (state === media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_CANCELED) {
          this.finalizeScreenVideo('用户取消了录屏授权')
        } else if (state === media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_STOPPED_BY_USER) {
          this.finalizeScreenVideo('MP4 已生成，可保存到相册或分享')
        } else if (state === media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_INTERRUPTED_BY_OTHER ||
          state === media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_STOPPED_BY_CALL ||
          state === media.AVScreenCaptureStateCode.SCREENCAPTURE_STATE_STOPPED_BY_USER_SWITCHES) {
          this.finalizeScreenVideo('录屏已被系统中断，已保留现有视频')
        }
      })
      recorder.on('error', (error) => {
        hilog.error(0x0000, 'StellariumArkUI', 'Screen capture error: %{public}s', String(error))
        this.finalizeScreenVideo('录屏失败')
      })
      const config: media.AVScreenCaptureRecordConfig = {
        fd: this.screenCaptureFile.fd,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
        videoBitrate: 10000000,
        displayId: displayInfo.id,
        fillMode: media.AVScreenCaptureFillMode.PRESERVE_ASPECT_RATIO,
        preset: media.AVScreenCaptureRecordPreset.SCREEN_RECORD_PRESET_H264_AAC_MP4
      }
      await recorder.init(config)
      await recorder.startRecording()
    } catch (error) {
      hilog.error(0x0000, 'StellariumArkUI', 'Start screen capture failed: %{public}s', String(error))
      await this.finalizeScreenVideo('无法开始录屏')
    }
  }

  private async stopScreenVideoRecording(): Promise<void> {
    if (this.screenCapture === undefined || this.scriptStore.screenCaptureFinalizing) { return }
    this.scriptStore.screenCaptureFinalizing = true
    try {
      this.screenCapture.off('stateChange')
      this.screenCapture.off('error')
      await this.screenCapture.stopRecording()
      await this.screenCapture.release()
    } catch (error) {
      hilog.error(0x0000, 'StellariumArkUI', 'Stop screen capture failed: %{public}s', String(error))
    }
    this.screenCapture = undefined
    this.closeScreenCaptureFile()
    this.scriptStore.screenVideoRecording = false
    try { this.scriptStore.screenVideoBytes = fileIo.statSync(this.scriptStore.screenVideoPath).size } catch (_error) { this.scriptStore.screenVideoBytes = 0 }
    this.scriptStore.screenVideoStatus = this.scriptStore.screenVideoBytes > 0 ? 'MP4 已生成，可保存到相册或分享' : '录屏没有生成有效视频'
    this.scriptStore.screenCaptureFinalizing = false
    this.flashHint(this.scriptStore.screenVideoStatus)
  }

  private async saveScreenVideoToGallery(result: SaveButtonOnClickResult): Promise<void> {
    if (result !== SaveButtonOnClickResult.SUCCESS || this.scriptStore.screenVideoPath.length === 0) {
      this.flashHint('未获得保存到相册的临时授权')
      return
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const helper = photoAccessHelper.getPhotoAccessHelper(context)
      const request = photoAccessHelper.MediaAssetChangeRequest.createVideoAssetRequest(
        context, fileUri.getUriFromPath(this.scriptStore.screenVideoPath))
      await helper.applyChanges(request)
      this.flashHint('视频已保存到相册')
    } catch (error) {
      hilog.error(0x0000, 'StellariumArkUI', 'Save video to gallery failed: %{public}s', String(error))
      this.flashHint('保存到相册失败')
    }
  }

  // ===== 视频帧序列录制（纯星图高质量导出）=====
  private startVideoRecording(): void {
    const fps = parseInt(this.scriptStore.videoFps, 10) || 1
    const duration = parseInt(this.scriptStore.videoDuration, 10) || 5
    this.callInteractive('startVideoRecording', fps + '|' + duration, (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.scriptStore.videoRecording = true
        this.scriptStore.videoDir = r.dir as string ?? ''
        this.scriptStore.videoFrameCount = 0
        this.scriptStore.videoFailedFrames = 0
        this.scriptStore.videoMaxFrames = r.maxFrames as number ?? 0
        this.scriptStore.videoArchivePath = ''
        this.scriptStore.videoArchiveFileName = ''
        this.startVideoStatePolling()
        this.flashHint('开始录制视频帧序列：' + fps + ' fps × ' + duration + ' s')
      } else {
        this.flashHint('开始录制失败：' + (r.error ?? '未知错误'))
      }
    })
  }

  private stopVideoRecording(): void {
    this.callInteractive('stopVideoRecording', '', (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.scriptStore.videoRecording = false
        this.stopVideoStatePolling()
        this.scriptStore.videoFrameCount = (r.diskFrames as number) ?? (r.frameCount as number) ?? 0
        this.scriptStore.videoFailedFrames = (r.failedFrames as number) ?? 0
        this.scriptStore.videoDir = r.dir as string ?? ''
        this.scriptStore.videoArchivePath = r.archivePath as string ?? ''
        this.scriptStore.videoArchiveFileName = r.archiveFileName as string ?? ''
        this.flashHint(this.scriptStore.videoArchivePath.length > 0 ?
          '已停止，共 ' + this.scriptStore.videoFrameCount + ' 帧，ZIP 已生成' :
          '已停止，共 ' + this.scriptStore.videoFrameCount + ' 帧，但 ZIP 生成失败')
      } else {
        this.flashHint('停止录制失败')
      }
    })
  }

  private loadVideoRecordingState(): void {
    this.callInteractive('getVideoRecordingState', '', (r: StellariumBridgeResponse) => {
      const wasRecording = this.scriptStore.videoRecording
      this.scriptStore.videoRecording = r.recording === true
      this.scriptStore.videoDir = r.dir as string ?? ''
      this.scriptStore.videoFrameCount = r.frameCount as number ?? 0
      this.scriptStore.videoFailedFrames = r.failedFrames as number ?? 0
      this.scriptStore.videoMaxFrames = r.maxFrames as number ?? 0
      if (wasRecording && !this.scriptStore.videoRecording) {
        this.stopVideoStatePolling()
        setTimeout(() => { this.stopVideoRecording() }, 0)
      }
    })
  }

  private startVideoStatePolling(): void {
    this.stopVideoStatePolling()
    this.videoStateTimer = setInterval(() => { this.loadVideoRecordingState() }, 450) as number
  }

  private stopVideoStatePolling(): void {
    if (this.videoStateTimer >= 0) {
      clearInterval(this.videoStateTimer)
      this.videoStateTimer = -1
    }
  }

  // ===== 望远镜/目镜配置（Oculars 插件桥）=====
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
    const previous = this.archaeoLineSettingValue(setting)
    this.applyArchaeoLineSetting(setting, value)
    this.archaeoStore.archaeoStatus = ''
    this.callInteractive('setArchaeoLineSetting', setting + '|' + value, () => {}, () => {
      if (mutationId !== this.archaeoMutationId) return
      this.applyArchaeoLineSetting(setting, previous)
      this.archaeoStore.archaeoStatus = I18n.t('plugin_action_failed')
    })
  }

  private archaeoLineSettingValue(setting: string): string {
    switch (setting) {
      case 'enabled': return this.archaeoStore.archaeoLinesEnabled ? '1' : '0'
      case 'equinox': return this.archaeoStore.archaeoEquinox ? '1' : '0'
      case 'solstices': return this.archaeoStore.archaeoSolstices ? '1' : '0'
      case 'crossquarters': return this.archaeoStore.archaeoCrossquarters ? '1' : '0'
      case 'majorStandstills': return this.archaeoStore.archaeoMajorStandstills ? '1' : '0'
      case 'minorStandstills': return this.archaeoStore.archaeoMinorStandstills ? '1' : '0'
      case 'polarCircles': return this.archaeoStore.archaeoPolarCircles ? '1' : '0'
      case 'zenithPassage': return this.archaeoStore.archaeoZenithPassage ? '1' : '0'
      case 'nadirPassage': return this.archaeoStore.archaeoNadirPassage ? '1' : '0'
      case 'selectedObject': return this.archaeoStore.archaeoSelectedObject ? '1' : '0'
      case 'selectedObjectAzimuth': return this.archaeoStore.archaeoSelectedObjectAzimuth ? '1' : '0'
      case 'selectedObjectHourAngle': return this.archaeoStore.archaeoSelectedObjectHourAngle ? '1' : '0'
      case 'currentSun': return this.archaeoStore.archaeoCurrentSun ? '1' : '0'
      case 'currentMoon': return this.archaeoStore.archaeoCurrentMoon ? '1' : '0'
      case 'currentPlanet': return ['none', 'Mercury', 'Venus', 'Mars', 'Jupiter', 'Saturn'][this.archaeoStore.archaeoCurrentPlanet] ?? 'none'
      case 'lineWidth': return this.archaeoStore.archaeoLineWidth.toString()
      default: return ''
    }
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
      groups: this.satelliteStore.satGroups, requestId: this.satelliteListRequestId,
      orbitLines: this.satelliteStore.satOrbitLines, hints: this.satelliteStore.satHints,
      elapsedMs: this.satelliteListElapsedMs,
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
    this.loadSatellites()
  }
  private loadSatellites(includeSources: boolean = false, immediate: boolean = false): void {
    const requestId = ++this.satelliteListRequestId
    const flagMutationId = this.satelliteFlagMutationId
    const startedAt = Date.now()
    this.satelliteStore.satelliteListLoading = true
    this.publishSatellitePanelState()
    this.satelliteLoadIncludeSources = this.satelliteLoadIncludeSources || includeSources
    if (this.satelliteLoadTimer >= 0) {
      clearTimeout(this.satelliteLoadTimer)
      this.satelliteLoadTimer = -1
    }
    const run = (): void => {
      this.satelliteLoadTimer = -1
      const includeSourcesForRequest = this.satelliteLoadIncludeSources
      this.satelliteLoadIncludeSources = false
      const payload = this.satelliteStore.activeSatGroup + '|' + this.satelliteStore.satQuery + '|40'
      this.satelliteStore.satelliteListLoading = true
      this.callNativeWhenReady('getSatellites', payload, (r: StellariumBridgeResponse) => {
        if (requestId !== this.satelliteListRequestId) return
        this.satelliteStore.satelliteListLoading = false
        const resp = r as SatellitesResponse
        const s = resp.satellites
        if (!s) return
        if (this.satelliteStore.satGroups.join('|') !== s.groups.join('|')) this.satelliteStore.satGroups = s.groups
        if (flagMutationId === this.satelliteFlagMutationId) {
          this.satelliteStore.satLabels = s.labels
          this.satelliteStore.satOrbitLines = s.orbitLines
          this.satelliteStore.satHints = s.hints
          this.satelliteStore.satIconicMode = s.iconicMode
          this.satelliteStore.satHideInvisible = s.hideInvisible
        }
        this.satelliteStore.satCount = s.count
        this.satelliteStore.satOffline = s.offline
        this.satelliteStore.satObserverIsEarth = s.observerIsEarth
        this.satelliteStore.satDateInRange = s.dateInRange
        this.satelliteStore.satNewestUpdate = s.newestUpdate
        this.satelliteStore.satOutdatedCount = s.outdatedCount
        this.satelliteStore.satMatchedCount = s.matchedCount
        this.satelliteStore.satCatalogCreator = s.catalogCreator ?? ''
        this.satelliteStore.satCatalogSnapshot = s.catalogSnapshot ?? ''
        this.satelliteStore.satCatalogSource = s.catalogSource ?? ''
        this.satelliteStore.satItems = s.items
        this.satelliteListElapsedMs = Date.now() - startedAt
        this.publishSatellitePanelState()
        if (includeSourcesForRequest) this.satelliteStore.loadSatelliteSources()
      }, 0, 100, 15, () => {
        if (requestId === this.satelliteListRequestId) {
          this.satelliteStore.satelliteListLoading = false
          this.publishSatellitePanelState('satellite query failed')
        }
      })
    }
    if (immediate) run()
    else this.satelliteLoadTimer = setTimeout(run, 90)
  }
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
        this.loadSatellites(true, true)
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
    const mutationId = ++this.satelliteFlagMutationId
    let previous: boolean | undefined
    if (name == 'labels') { previous = this.satelliteStore.satLabels; this.satelliteStore.satLabels = v }
    else if (name == 'orbitLines') { previous = this.satelliteStore.satOrbitLines; this.satelliteStore.satOrbitLines = v }
    else if (name == 'hints') { previous = this.satelliteStore.satHints; this.satelliteStore.satHints = v }
    else if (name == 'iconicMode') { previous = this.satelliteStore.satIconicMode; this.satelliteStore.satIconicMode = v }
    else if (name == 'hideInvisible') { previous = this.satelliteStore.satHideInvisible; this.satelliteStore.satHideInvisible = v }
    this.callNativeWhenReady('setSatellitesFlag', name + ':' + (v ? '1' : '0'), () => {}, 0, 100, 15, () => {
      if (mutationId !== this.satelliteFlagMutationId || previous === undefined) return
      if (name == 'labels') this.satelliteStore.satLabels = previous
      else if (name == 'orbitLines') this.satelliteStore.satOrbitLines = previous
      else if (name == 'hints') this.satelliteStore.satHints = previous
      else if (name == 'iconicMode') this.satelliteStore.satIconicMode = previous
      else if (name == 'hideInvisible') this.satelliteStore.satHideInvisible = previous
    })
  }
  private loadCatalogHealth(): void {
    this.callNativeWhenReady('getCatalogHealth', '', (r: StellariumBridgeResponse) => {
      const health = r as CatalogHealthResponse
      this.catalogHealthLoaded = true
      this.catalogManifestPresent = health.manifestPresent === true
      this.satelliteStore.satelliteCatalogHealth = health.satellites ?? {}
      this.catalogStore.starCatalogHealth = health.stars ?? {}
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

  private loadScenery3d(): void {
    this.sceneryStore.scenery3dLoading = true
    this.callNativeWhenReady('getScenery3dList', '', (r: StellariumBridgeResponse) => {
      this.sceneryStore.scenery3dLoading = false
      const response = r as Scenery3dResponse
      if (response.ok !== true) return
      this.sceneryStore.scenery3dItems = response.items ?? []
      this.scenery3dCurrentId = response.current ?? ''
      this.sceneryStore.scenery3dLoadingId = response.loading ?? ''
      this.sceneryStore.scenery3dEnabled = response.enabled === true
    })
  }

  private setScenery3dScene(id: string): void {
    this.sceneryStore.scenery3dLoadingId = id
    this.callInteractive('setScenery3dScene', id, (r: StellariumBridgeResponse) => {
      if (r.ok !== true) {
        this.sceneryStore.scenery3dLoadingId = ''
        this.flashHint('三维地景加载失败')
        return
      }
      this.loadScenery3d()
    }, () => { this.sceneryStore.scenery3dLoadingId = '' })
  }

  private setScenery3dEnabled(enabled: boolean): void {
    this.sceneryStore.scenery3dEnabled = enabled
    this.callInteractive('setScenery3dEnabled', enabled ? '1' : '0', (r: StellariumBridgeResponse) => {
      if (r.ok !== true) this.sceneryStore.scenery3dEnabled = !enabled
      this.loadScenery3d()
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
      this.copyTextToClipboard(this.tools.configExportText, I18n.t('config_export_copied'))
    })
  }

  private async copyTextToClipboard(text: string, successHint: ResourceStr): Promise<boolean> {
    if (text.length === 0) {
      this.flashHint(I18n.t('clipboard_copy_empty'))
      return false
    }
    const result = await writeClipboardText(text)
    if (result.ok) {
      this.flashHint(successHint)
      return true
    }
    this.flashHint(I18n.t('clipboard_copy_failed'))
    return false
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
  private speakSelectedObject(): void {
    this.callNativeWhenReady('getObjectSpokenText', '', (r: StellariumBridgeResponse) => {
      const resp = r as SpokenTextResponse
      if (resp.ok !== true || !resp.text) {
        this.flashHint(I18n.t('msg_no_selection_for_tts'))
        return
      }
      this.guideStore.speechStatus = resp.text
      this.flashHint('已生成朗读文本（当前 SDK 未集成语音合成）')
    })
  }

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
    if (enabled && !this.hasSelectedObject()) {
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

  private informationMaskHas(key: string): boolean {
    const bit = informationMaskBit(key)
    return bit > 0 && (this.infoWindowStore.informationCustomMask & bit) === bit
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
    if (this.infoWindowStore.informationSettingPending || this.infoWindowStore.informationMode !== 'custom' || this.informationMaskHas(key) === enabled) return
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

  private saveCurrentViewAsStartup(): void {
    this.callInteractive('saveCurrentView', '', (r: StellariumBridgeResponse) => {
      if (r.ok !== true) {
        this.flashHint(I18n.t('msg_apply_failed'))
        return
      }
      this.flashHint(I18n.t('settings_view_saved'))
      this.timeSettingsStore.loadConfigurationSettings()
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

  private saveScreenshot(): void {
    if (this.tools.screenshotSaving) return
    this.tools.screenshotSaving = true
    this.flashHint(I18n.t('screenshot_preparing'))
    this.callInteractive('saveScreenShot', '', (r: StellariumBridgeResponse) => {
      const response = r as ScreenshotResponse
      if (response.ok !== true || !response.path || !response.fileName) {
        this.tools.screenshotSaving = false
        this.flashHint(I18n.t('screenshot_failed'))
        return
      }
      this.exportScreenshotToUserStorage(response)
    }, () => {
      this.tools.screenshotSaving = false
      this.flashHint(I18n.t('screenshot_failed'))
    })
  }

  private async exportScreenshotToUserStorage(response: ScreenshotResponse): Promise<void> {
    const sourcePath = response.path ?? ''
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const saveOptions = new picker.DocumentSaveOptions()
      saveOptions.newFileNames = [response.fileName ?? ('stellarium-' + Date.now().toString() + '.png')]
      const format = (response.format ?? 'png').toUpperCase()
      saveOptions.fileSuffixChoices = [format + ' image|.' + format.toLowerCase()]
      const selectedUris = await new picker.DocumentViewPicker(context).save(saveOptions)
      if (selectedUris.length === 0 || selectedUris[0].length === 0) {
        this.flashHint(I18n.t('screenshot_cancelled'))
        return
      }
      await fileIo.copy(fileUri.getUriFromPath(sourcePath), selectedUris[0])
      this.flashHint(I18n.t('screenshot_saved'))
    } catch (error) {
      hilog.error(0x0000, 'StellariumArkUI', 'Screenshot export failed: %{public}s', String(error))
      this.flashHint(I18n.t('screenshot_failed'))
    } finally {
      if (sourcePath.length > 0) {
        try { fileIo.unlinkSync(sourcePath) } catch (error) {}
      }
      this.tools.screenshotSaving = false
    }
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

  private makeAstroCsv(exportData: AstroCsvExport): string {
    const lines: Array<string> = []
    lines.push('# ' + exportData.title)
    if (this.astroStore.astroContext !== undefined) {
      const location = this.astroStore.astroContext.observerLocation !== undefined && this.astroStore.astroContext.observerLocation.length > 0
        ? this.astroStore.astroContext.observerLocation : '当前观测位置'
      lines.push('# 观测地点: ' + location)
      lines.push('# 本地时间: ' + this.fmtDateTime(this.astroStore.astroContext.localTime))
      lines.push('# 时区: ' + (this.astroStore.astroContext.timeZone ?? '--'))
      lines.push('# 平恒星时: ' + (this.astroStore.astroContext.meanSiderealTime ?? '--'))
      lines.push('# 视恒星时: ' + (this.astroStore.astroContext.apparentSiderealTime ?? '--'))
    }
    if (this.astroStore.astroCalcSnapshot.length > 0) lines.push('# 参数: ' + this.astroStore.astroCalcSnapshot)
    lines.push(exportData.headers.map((header: string) => csvCell(header)).join(','))
    for (const row of exportData.rows) {
      lines.push(row.map((cell: string | number | boolean | undefined) => csvCell(cell)).join(','))
    }
    return lines.join('\r\n') + '\r\n'
  }

  private currentAstroCsvExport(): AstroCsvExport | undefined {
    if (this.astroStore.astroTab === 0) {
      if (this.astroStore.positionMode === 0 && this.astroStore.planetPositions.length > 0) {
        return { title: '地平位置', headers: ['天体', '赤经(当日)', '赤纬(当日)', '高度(度)', '方位(度)', '星等', '距离(AU)', '视直径(角分)', '中天'],
          rows: this.astroStore.planetPositions.map((item: PlanetPosition) => [planetZh(item.name), item.rightAscension, item.declination, item.altitude, item.azimuth, item.magnitude, item.distanceAU, item.angularSizeArcmin, item.transit]) }
      }
      if (this.astroStore.positionMode === 1 && this.astroStore.hecPositions.length > 0) {
        return { title: '日心黄道位置', headers: ['天体', '英文名', '黄纬(度)', '黄经(度)', '日心距离(AU)', '彗星', '已选小天体'],
          rows: this.astroStore.hecPositions.map((item: HeliocentricPosition) => [this.hecTitle(item), item.englishName, item.latitude, item.longitude, item.distanceAU, item.isComet, item.isSelectedMinor]) }
      }
      if (this.astroStore.positionMode === 2 && this.astroStore.celestialPositions.length > 0) {
        return { title: '目录天体位置', headers: ['天体', '英文名', '目录编号', '坐标一', '坐标二', '高度(度)', '方位(度)', '星等', '类型', '距日(度)', '视直径(角分)', '距离(AU)', '中天'],
          rows: this.astroStore.celestialPositions.map((item: CelestialPosition) => [this.celestialPositionTitle(item), item.englishName, item.catalogId, item.firstCoordinate, item.secondCoordinate, item.altitude, item.azimuth, item.magnitude, item.type, item.elongation, item.angularSizeArcmin, item.distanceAU, item.transit]) }
      }
    } else if (this.astroStore.astroTab === 1 && this.astroStore.ephemerisData.length > 0) {
      return { title: (this.astroStore.ephemerisName.length > 0 ? this.astroStore.ephemerisName : '天体') + '星历', headers: ['日期时间', '天体', '英文名', '赤经(J2000)', '赤纬(J2000)', '赤经(当日)', '赤纬(当日)', '高度(度)', '方位(度)', '时角(度)', '极距(度)', '星等', '相位(%)', '距离(AU)', '距日(度)', '视直径(角分)', '气团质量'],
        rows: this.astroStore.ephemerisData.map((item: EphemerisRow) => [item.date, item.bodyName, item.bodyEnglishName, item.ra, item.dec, item.raOfDate, item.decOfDate, item.altitude, item.azimuth, item.hourAngleDegrees, item.polarDistanceDegrees, item.magnitude, item.phase !== undefined ? item.phase * 100 : undefined, item.distanceAU, item.elongationDegrees, item.angularSizeArcmin, item.airmass]) }
    } else if (this.astroStore.astroTab === 2 && this.astroStore.rtsCalendarData.length > 0) {
      return { title: (this.astroStore.rtsCalendarName.length > 0 ? this.astroStore.rtsCalendarName : '天体') + '升中天落日期表', headers: ['日期', '升起', '中天', '落下', '中天高度(度)', '星等', '距日(度)', '距月(度)', '状态'],
        rows: this.astroStore.rtsCalendarData.map((item: RtsCalendarDay) => [item.date, item.rise, item.transit, item.set, item.transitAltitude, item.magnitude, item.solarElongation, item.lunarElongation, item.status]) }
    } else if (this.astroStore.astroTab === 3 && this.astroStore.phenomenaData.length > 0) {
      return { title: '天象预报', headers: ['日期时间', '事件', '天体一', '天体二', '数值', '指标', '单位'],
        rows: this.astroStore.phenomenaData.map((item: PhenomenonItem) => [item.date, item.type, item.bodyA, item.bodyB, item.separation, item.metricLabel, item.metricUnit]) }
    } else if (this.astroStore.astroTab === 4) {
      if ((this.astroStore.graphMode === 0 || this.astroStore.graphMode === 1) && this.astroStore.altAzCurve.length > 0) {
        return { title: this.astroStore.altAzName + (this.astroStore.graphMode === 0 ? '地平高度曲线' : '方位角曲线'), headers: ['儒略日', '距起点(小时)', '高度(度)', '方位(度)', '太阳高度(度)', '月亮高度(度)'],
          rows: this.astroStore.altAzCurve.map((item: AltAzPoint) => [item.jd, item.t, item.altitude, item.azimuth, item.sunAltitude, item.moonAltitude]) }
      }
      if (this.astroStore.graphMode === 2 && this.astroStore.annualElevationData.length > 0) {
        return { title: this.astroStore.annualElevationName + '全年高度', headers: ['日期', '儒略日', '高度(度)', '方位(度)'],
          rows: this.astroStore.annualElevationData.map((item: AnnualElevationPoint) => [item.date, item.jd, item.altitude, item.azimuth]) }
      }
      if (this.astroStore.graphMode === 3 && this.astroStore.observabilityData.length > 0) {
        return { title: this.astroStore.observabilityName + '观测窗口', headers: ['日期', '最佳时刻', '最高高度(度)', '可观测时长(小时)', '暗夜时长(小时)', '月面照明(%)', '月亮高度(度)'],
          rows: this.astroStore.observabilityData.map((item: ObservabilityDay) => [item.date, item.peakTime, item.maxAltitude, item.visibleHours, item.darkHours, item.moonIllumination, item.moonAltitude]) }
      }
      if (this.astroStore.graphMode === 4 && this.astroStore.lunarElongationData.length > 0) {
        return { title: this.astroStore.lunarElongationName + '月距曲线', headers: ['日期时间', '儒略日', '距起点(小时)', '月距(度)'],
          rows: this.astroStore.lunarElongationData.map((item: LunarElongationPoint) => [item.date, item.jd, item.t, item.separation]) }
      }
      if (this.astroStore.graphMode === 5 && this.astroStore.planetTimeSeriesData.length > 0) {
        return { title: this.astroStore.planetTimeSeriesName + '双变量时间曲线', headers: ['日期时间', '儒略日', '距起点(小时)', planetMetricLabel(this.astroStore.planetTimeSeriesLeftMetric), planetMetricLabel(this.astroStore.planetTimeSeriesRightMetric)],
          rows: this.astroStore.planetTimeSeriesData.map((item: PlanetTimeSeriesPoint) => [item.date, item.jd, item.t, item.left, item.right]) }
      }
    } else if (this.astroStore.astroTab === 5 && this.wutStore.wutTargets.length > 0) {
      return { title: '今晚可观测天体', headers: ['天体', '英文名', '类型', '观测时刻', '高度(度)', '方位(度)', '星等', '角尺寸(角分)', '升起', '中天', '落下'],
        rows: this.wutStore.wutTargets.map((item: WutTarget) => [zhNameOf(item.name ?? ''), item.englishName, item.type, this.wutStore.wutObservationTime, item.altitude, item.azimuth, item.magnitude, item.angularSizeArcmin, item.rise, item.transit, item.set]) }
    } else if (this.astroStore.astroTab === 6) {
      if (this.astroStore.planetCalcMode === 0 && this.astroStore.planetCalcData.length > 0) {
        return { title: '行星计算', headers: ['天体', '英文名', '赤经', '赤纬', '高度(度)', '方位(度)', '星等', '距离(AU)', '距日(度)', '相位(%)', '升起', '中天', '落下'],
          rows: this.astroStore.planetCalcData.map((item: PlanetCalcItem) => [item.name, item.englishName, item.ra, item.dec, item.altitude, item.azimuth, item.magnitude, item.distanceAU, item.elongation, item.phase !== undefined ? item.phase * 100 : undefined, item.rise, item.transit, item.set]) }
      }
      if (this.astroStore.planetCalcMode === 1 && this.astroStore.planetPairDistanceData.length > 0) {
        return { title: this.astroStore.planetPairFirstName + '与' + this.astroStore.planetPairSecondName + '距离曲线', headers: ['日期时间', '儒略日', '距起点(天)', '线性距离(AU)', '角距离(度)'],
          rows: this.astroStore.planetPairDistanceData.map((item: PlanetPairDistancePoint) => [item.date, item.jd, item.t, item.linearDistance, item.angularDistance]) }
      }
    } else if (this.astroStore.astroTab === 7) {
      if (this.astroStore.eclipseMode === 0 && this.filteredEclipses().length > 0) {
        return { title: '日月食预报', headers: ['日期时间', '类别', '类型', '食分', '沙罗周期', '本地可见', '本地食甚', '太阳高度(度)', '月亮高度(度)', '备注'],
          rows: this.filteredEclipses().map((item: EclipseItem) => [item.date, item.kind, item.type, item.magnitude, item.saros, item.localVisible, item.localMax, item.localSunAltitude, item.localMoonAltitude, item.note]) }
      }
      if (this.astroStore.eclipseMode === 1 && this.astroStore.planetaryTransitData.length > 0) {
        return { title: '行星凌日预报', headers: ['日期时间', '行星', '初亏', '内切始', '食甚', '内切终', '复圆', '食分', '最小距日心(度)', '持续(分钟)', '本地可见'],
          rows: this.astroStore.planetaryTransitData.map((item: PlanetaryTransitItem) => [item.date, item.planet, item.firstContact, item.secondContact, item.middle, item.thirdContact, item.lastContact, item.magnitude, item.minimumSeparation, item.durationMin, item.localVisible]) }
      }
    } else if (this.astroStore.astroTab === 8 && this.astroStore.almanacData.size > 0) {
      const rows: Array<Array<string | number | boolean | undefined>> = []
      this.astroStore.almanacData.forEach((value: string, key: string) => { rows.push([key, value]) })
      for (const event of this.astroStore.almanacSeasons) rows.push(['四季节点：' + (event.label ?? ''), event.date])
      return { title: '历法与月相', headers: ['项目', '数值'], rows: rows }
    } else if (this.astroStore.astroTab === 9 && this.astroStore.moonPhaseData.length > 0) {
      return { title: '月相预报', headers: ['日期时间', '月相', '照亮(%)', '高度(度)', '方位(度)', '升起', '中天', '落下'],
        rows: this.astroStore.moonPhaseData.map((item: MoonPhaseItem) => [item.date, item.phase, item.illumination, item.altitude, item.azimuth, item.rise, item.transit, item.set]) }
    }
    return undefined
  }

  private async exportCurrentAstroCsv(): Promise<void> {
    this.astroStore.updateAstroCalcSnapshot()
    const exportData = this.currentAstroCsvExport()
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
      const bytes = encoder.encodeInto(this.makeAstroCsv(exportData))
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





  private rtsCalendarStartOptionLabel(offsetDays: number): string {
    if (offsetDays < 0) {
      return this.astroStore.rtsCalendarStartYear.toString() + '-' + this.astroStore.rtsCalendarStartMonth.toString().padStart(2, '0') + '-' + this.astroStore.rtsCalendarStartDay.toString().padStart(2, '0')
    }
    if (offsetDays === 0) return '当前'
    return '+' + offsetDays.toString() + ' 天'
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




  private ephemerisStartOptionLabel(offsetDays: number): string {
    if (offsetDays < 0) {
      return this.ephemerisStore.ephemerisStartYear.toString() + '-' + this.ephemerisStore.ephemerisStartMonth.toString().padStart(2, '0') + '-' + this.ephemerisStore.ephemerisStartDay.toString().padStart(2, '0')
    }
    if (offsetDays === 0) return '当前'
    return '+' + offsetDays.toString() + ' 天'
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














  private graphCustomStartLabel(): string {
    if (this.astroStore.graphStartOffsetDays >= 0) return '指定日期'
    return this.astroStore.graphStartYear.toString() + '-' + this.astroStore.graphStartMonth.toString().padStart(2, '0') + '-' + this.astroStore.graphStartDay.toString().padStart(2, '0')
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

  private hasSelectedObject(): boolean {
    return this.objectDetailStore.selectedStatus === 'Selected' && this.objectDetailStore.selectedName.length > 0
  }




  private jumpToObservabilityDay(day: ObservabilityDay): void {
    if (day.bestJD === undefined || day.bestJD <= 0) return
    this.callInteractive('setJD', String(day.bestJD), (r: StellariumBridgeResponse) => {
      if (r.ok === true) this.refreshState()
    })
  }





  private eclipseStartOptionLabel(offsetDays: number): string {
    if (offsetDays < 0) {
      return this.astroStore.eclipseStartYear.toString() + '-' + this.astroStore.eclipseStartMonth.toString().padStart(2, '0') + '-' + this.astroStore.eclipseStartDay.toString().padStart(2, '0')
    }
    if (offsetDays === 0) return '当前'
    return '+' + offsetDays.toString() + ' 天'
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

  private filteredEclipses(): Array<EclipseItem> {
    const filtered: Array<EclipseItem> = []
    for (const eclipse of this.astroStore.eclipseData) {
      if (this.astroStore.eclipseKindFilter === 1 && eclipse.kind !== 'solar') continue
      if (this.astroStore.eclipseKindFilter === 2 && eclipse.kind !== 'lunar') continue
      const type = eclipse.type ?? ''
      if (this.astroStore.eclipseTypeFilter === 1 && type !== '全食') continue
      if (this.astroStore.eclipseTypeFilter === 2 && type !== '环食') continue
      if (this.astroStore.eclipseTypeFilter === 3 && type !== '偏食') continue
      if (this.astroStore.eclipseTypeFilter === 4 && type !== '半影食') continue
      filtered.push(eclipse)
    }
    return filtered
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
        this.applySelectedObject(selectResult, false, 'center')
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

  private altAzMaxLabel(): string {
    let m: number = -999
    let t: number = 0
    for (let i = 0; i < this.astroStore.altAzCurve.length; i++) {
      const p: AltAzPoint = this.astroStore.altAzCurve[i]
      const v: number = p.altitude !== undefined ? p.altitude : -999
      if (v > m) { m = v; t = p.t !== undefined ? p.t : 0 }
    }
    if (m < -90) return '--'
    return m.toFixed(1) + '°（' + hourOffsetLabel(t) + '）'
  }

  private altAzNowLabel(): string {
    if (this.astroStore.altAzCurve.length === 0) return '--'
    const p: AltAzPoint = this.astroStore.altAzCurve[0]
    const alt: number = p.altitude !== undefined ? p.altitude : 0
    const az: number = p.azimuth !== undefined ? p.azimuth : 0
    return '高度 ' + alt.toFixed(1) + '° / 方位 ' + az.toFixed(1) + '°'
  }

  private altAzVisibleHours(): string {
    let hours: number = 0
    for (let i = 0; i + 1 < this.astroStore.altAzCurve.length; i++) {
      const p: AltAzPoint = this.astroStore.altAzCurve[i]
      const next: AltAzPoint = this.astroStore.altAzCurve[i + 1]
      if (p.altitude !== undefined && p.altitude > 0 && p.t !== undefined && next.t !== undefined) {
        hours += next.t - p.t
      }
    }
    return hours.toFixed(1) + ' 小时'
  }

  private altAzRangeLabel(): string {
    return '未来 ' + this.astroStore.altAzHours.toString() + ' 小时'
  }

  private altAzMidpointLabel(): string {
    return '+' + (this.astroStore.altAzHours / 2).toString() + 'h'
  }

  private altBarWidth(): number {
    if (this.astroStore.altAzCurve.length === 0) return 4
    return Math.max(1, Math.min(4, 292 / this.astroStore.altAzCurve.length))
  }

  private altBarHeight(alt: number | undefined): number {
    const a: number = alt !== undefined ? alt : -90
    if (a < this.astroStore.altAzMinimum) return 1
    const range: number = 90 - this.astroStore.altAzMinimum
    return Math.max(1, Math.min(96, (a - this.astroStore.altAzMinimum) / range * 96))
  }

  private altitudeCurveColor(altitude: number | undefined, color: string): string {
    return (altitude ?? -90) >= this.astroStore.altAzMinimum ? color : '#33FFFFFF'
  }

  private altCurveSegmentWidth(): number {
    let count: number = 1
    if (this.astroStore.altAzShowSun) count++
    if (this.astroStore.altAzShowMoon) count++
    return Math.max(1, (this.altBarWidth() - Math.max(0, count - 1)) / count)
  }

  private annualBarHeight(altitude: number | undefined): number {
    const value: number = altitude !== undefined ? altitude : -90
    if (value < this.astroStore.annualElevationMinimum) return 1
    const range: number = 90 - this.astroStore.annualElevationMinimum
    return Math.max(1, Math.min(96, (value - this.astroStore.annualElevationMinimum) / range * 96))
  }

  private annualBarWidth(): number {
    if (this.astroStore.annualElevationData.length === 0) return 3
    return Math.max(1, Math.min(6, 292 / this.astroStore.annualElevationData.length))
  }

  private annualMaxLabel(): string {
    let maximum: number = -91
    let date: string = ''
    for (const point of this.astroStore.annualElevationData) {
      const altitude: number = point.altitude ?? -91
      if (altitude > maximum) {
        maximum = altitude
        date = point.date ?? ''
      }
    }
    return maximum < -90 ? '--' : maximum.toFixed(1) + '°（' + (date.length >= 10 ? date.slice(5) : date) + '）'
  }

  private azimuthNowLabel(): string {
    if (this.astroStore.altAzCurve.length === 0) return '--'
    return (this.astroStore.altAzCurve[0].azimuth ?? 0).toFixed(1) + '°'
  }

  private lunarElongationBarWidth(): number {
    if (this.astroStore.lunarElongationData.length === 0) return 4
    return Math.max(1, Math.min(4, 292 / this.astroStore.lunarElongationData.length))
  }


  private lunarElongationLineTop(): number {
    return Math.max(0, Math.min(95, (1 - this.astroStore.lunarElongationLimit / 180) * 96))
  }

  private lunarElongationNowLabel(): string {
    if (this.astroStore.lunarElongationData.length === 0) return '--'
    return (this.astroStore.lunarElongationData[0].separation ?? 0).toFixed(1) + '°'
  }

  private lunarElongationClosestLabel(): string {
    let closest: number = 181
    let time: number = 0
    for (const point of this.astroStore.lunarElongationData) {
      const separation: number = point.separation ?? 181
      if (separation < closest) {
        closest = separation
        time = point.t ?? 0
      }
    }
    return closest > 180 ? '--' : closest.toFixed(1) + '°（' + hourOffsetLabel(time) + '）'
  }



  private planetTimeSeriesBarWidth(): number {
    if (this.astroStore.planetTimeSeriesData.length === 0) return 4
    return Math.max(2, Math.min(6, 292 / this.astroStore.planetTimeSeriesData.length))
  }

  private planetTimeSeriesSegmentWidth(): number {
    return Math.max(1, (this.planetTimeSeriesBarWidth() - 1) / 2)
  }


  private planetTimeSeriesValueLabel(value: number | undefined, metric: string): string {
    return (value ?? 0).toFixed(metric === 'angularSize' ? 0 : 1) + planetMetricUnit(metric)
  }


  private planetPairBarWidth(): number {
    if (this.astroStore.planetPairDistanceData.length === 0) return 4
    return Math.max(2, Math.min(6, 292 / this.astroStore.planetPairDistanceData.length))
  }

  private planetPairSegmentWidth(): number {
    return Math.max(1, (this.planetPairBarWidth() - 1) / 2)
  }



  private planetPairCurrentIndex(): number {
    return Math.floor(this.astroStore.planetPairDistanceData.length / 2)
  }

  private hecDistanceToRadius(distanceAU: number): number {
    if (distanceAU <= 1) return clamp(24 + distanceAU * 33, 24, 57)
    if (distanceAU <= 5) return 57 + (distanceAU - 1) * 7.5
    if (distanceAU <= 15) return 87 + (distanceAU - 5) * 2.6
    return clamp(113 + (distanceAU - 15) * 1.35, 113, 133)
  }


  private hecOrbitVerticalRadius(englishName: string): number {
    const radius = hecPlanetOrbitRadius(englishName)
    return radius > 0 ? radius * 0.86 : 0
  }

  private hecPointDistance(position: HeliocentricPosition): number {
    if (position.displayRadius !== undefined) return position.displayRadius
    const planetRadius = hecPlanetOrbitRadius(position.englishName)
    return planetRadius > 0 ? planetRadius : this.hecDistanceToRadius(position.distanceAU)
  }


  private hecPointHorizontalRadius(position: HeliocentricPosition): number {
    return this.hecPointDistance(position)
  }

  private hecPointVerticalRadius(position: HeliocentricPosition): number {
    const orbitVerticalRadius = this.hecOrbitVerticalRadius(position.englishName)
    return orbitVerticalRadius > 0 ? orbitVerticalRadius : this.hecPointDistance(position)
  }


  private hecPointX(position: HeliocentricPosition): number {
    const angle = (360 - hecPointAngle(position)) * Math.PI / 180
    return 146 + this.hecPointHorizontalRadius(position) * Math.sin(angle)
  }

  private hecPointY(position: HeliocentricPosition): number {
    const angle = (360 - hecPointAngle(position)) * Math.PI / 180
    return 146 - this.hecPointVerticalRadius(position) * Math.cos(angle)
  }

  private hecPointLeft(position: HeliocentricPosition): number {
    return this.hecPointX(position) - hecPointSize(position) / 2
  }

  private hecPointTop(position: HeliocentricPosition): number {
    return this.hecPointY(position) - hecPointSize(position) / 2
  }

  private hecPointColor(position: HeliocentricPosition): string {
    if (position.isComet) return '#7CC8E8'
    if (position.isSelectedMinor) return '#C2A36B'
    if (position.englishName === 'Mercury') return '#AAB5C5'
    if (position.englishName === 'Venus') return '#DEC18A'
    if (position.englishName === 'Earth') return '#6BAED6'
    if (position.englishName === 'Mars') return '#D18467'
    if (position.englishName === 'Jupiter') return '#D6A06D'
    if (position.englishName === 'Saturn') return '#D7BF76'
    if (position.englishName === 'Uranus') return '#82C9D2'
    if (position.englishName === 'Neptune') return '#6F9EDD'
    return this.nmAccent()
  }

  private hecLayoutPositions(positions: Array<HeliocentricPosition>): Array<HeliocentricPosition> {
    const placed: Array<HeliocentricPosition> = []
    for (const position of positions) {
      const baseRadius = this.hecPointDistance(position)
      const flexiblePosition = position.isComet || position.isSelectedMinor
      // 行星必须留在真实黄经对应的轨道位置。只有没有专属轨道的小天体
      // 才允许做很小的视觉避让，否则点会看起来偏离自己的轨道。
      const angularOffsets: Array<number> = flexiblePosition ? [0, 4, -4, 8, -8, 14, -14] : [0]
      const radialOffsets: Array<number> = flexiblePosition ? [0, 3, -3, 6, -6] : [0]
      let displayPosition: HeliocentricPosition = {
        name: position.name,
        englishName: position.englishName,
        latitude: position.latitude,
        longitude: position.longitude,
        distanceAU: position.distanceAU,
        isComet: position.isComet,
        isSelectedMinor: position.isSelectedMinor,
        displayLongitude: position.longitude,
        displayRadius: baseRadius,
      }
      let collisionFree: boolean = false
      for (const radialOffset of radialOffsets) {
        if (collisionFree) break
        for (const angularOffset of angularOffsets) {
          const candidate: HeliocentricPosition = {
            name: position.name,
            englishName: position.englishName,
            latitude: position.latitude,
            longitude: position.longitude,
            distanceAU: position.distanceAU,
            isComet: position.isComet,
            isSelectedMinor: position.isSelectedMinor,
            displayLongitude: position.longitude + angularOffset,
            displayRadius: clamp(baseRadius + radialOffset, 22, 136),
          }
          let collides: boolean = false
          for (const existing of placed) {
            const deltaX = this.hecPointX(candidate) - this.hecPointX(existing)
            const deltaY = this.hecPointY(candidate) - this.hecPointY(existing)
            const clearance = (hecPointSize(candidate) + hecPointSize(existing)) / 2 + 2
            if (deltaX * deltaX + deltaY * deltaY < clearance * clearance) {
              collides = true
              break
            }
          }
          if (!collides) {
            displayPosition = candidate
            collisionFree = true
            break
          }
        }
      }
      placed.push(displayPosition)
    }
    return placed
  }

  private hecTitle(position: HeliocentricPosition): string {
    return this.celestialTitle(position.name, position.englishName)
  }


  private isObserverPlanetSelection(name: string): boolean {
    return name.trim().toLowerCase() === this.sessionToolStore.observerPlanet.trim().toLowerCase()
  }

  private celestialPositionTitle(position: CelestialPosition): string {
    return this.celestialTitle(position.name, position.englishName)
  }

  private celestialPositionSubtitle(position: CelestialPosition): string {
    if (position.catalogId.length > 0 && position.catalogId !== this.celestialPositionTitle(position)) return position.catalogId
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

  private almanacHoursLabel(key: string): string {
    const value = this.astroStore.almanacData.get(key) ?? ''
    return value.length > 0 ? parseFloat(value).toFixed(1) + ' 小时' : '--'
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

  private astroNeedsSelectedObject(): boolean {
    if (this.astroStore.astroTab === 2 || this.astroStore.astroTab === 4) return true
    if (this.astroStore.astroTab === 1 && this.astroStore.ephemerisMode < 2) return true
    if (this.astroStore.astroTab === 6 && this.astroStore.planetCalcMode === 1) return false
    return false
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


  private skyCultureNarrationParagraphs(): string[] {
    return cleanSkyCultureNarration(this.skyCultureViewStore.narration).split(/\n+/).map((item: string) => item.trim()).filter((item: string) => item.length > 0)
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
      this.releaseDecodedImage(oldMaps[rawPath], 'sky-culture-art-thumbnail')
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
    this.decodeLocalImage(filePath, 'sky-culture-art-thumbnail', (pixelMap: image.PixelMap) => {
      if (requestId !== this.skyCultureDetailsRequestId || generation !== this.skyCultureArtThumbnailGeneration ||
        this.skyCultureViewStore.currentSkyCultureId.length === 0) {
        this.releaseDecodedImage(pixelMap, 'stale-sky-culture-art-thumbnail')
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
    this.releaseDecodedImage(oldPixelMap, 'switch-sky-culture-art')
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
    this.releaseDecodedImage(oldPixelMap, 'sky-culture-art')
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
    this.decodeLocalImage(filePath, 'sky-culture-art', (pixelMap: image.PixelMap) => {
      if (!this.skyCultureViewStore.artPreviewOpen || this.skyCultureViewStore.artPreviewRawPath !== rawPath ||
        generation !== this.skyCultureArtDecodeGeneration) {
        this.releaseDecodedImage(pixelMap, 'stale-sky-culture-art')
        return
      }
      const oldPixelMap = this.skyCultureViewStore.artPreviewPixelMap
      this.skyCultureViewStore.artPreviewPixelMap = pixelMap
      this.releaseDecodedImage(oldPixelMap, 'previous-sky-culture-art')
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
    this.releaseDecodedImage(oldPixelMap, 'retry-sky-culture-art')
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

  private currentSkyCultureMakerDraft(): SkyCultureMakerDraft {
    let beginTime = Number(this.skyCultureMakerStore.beginTime)
    let endTime = Number(this.skyCultureMakerStore.endTime)
    if (!Number.isFinite(beginTime)) beginTime = 0
    if (!Number.isFinite(endTime)) endTime = 0
    return {
      schemaVersion: 1,
      id: this.skyCultureMakerStore.id.trim(),
      name: this.skyCultureMakerStore.name.trim(),
      author: this.skyCultureMakerStore.author.trim(),
      license: this.skyCultureMakerStore.license.trim(),
      region: this.skyCultureMakerStore.region.trim(),
      classification: [this.skyCultureMakerStore.classification],
      native_lang: this.skyCultureMakerStore.nativeLang.trim(),
      beginTime: Math.trunc(beginTime),
      endTime: Math.trunc(endTime),
      introduction: this.skyCultureMakerStore.introduction,
      description: this.skyCultureMakerStore.description,
      constellations: this.skyCultureMakerStore.constellations
    }
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
    this.callInteractive('saveSkyCultureMakerDraft', JSON.stringify(this.currentSkyCultureMakerDraft()), (response: StellariumBridgeResponse) => {
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
    this.callInteractive('validateSkyCultureMakerDraft', JSON.stringify(this.currentSkyCultureMakerDraft()), (response: StellariumBridgeResponse) => {
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

  private selectedSkyCultureMakerConstellation(): SkyCultureMakerConstellation | undefined {
    const index = this.skyCultureMakerStore.selectedConstellation
    if (index < 0 || index >= this.skyCultureMakerStore.constellations.length) return undefined
    return this.skyCultureMakerStore.constellations[index]
  }

  private skyCultureMakerArtworkFilePath(): string {
    const constellation = this.selectedSkyCultureMakerConstellation()
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
    this.releaseDecodedImage(oldPixelMap, label)
  }

  private refreshSkyCultureMakerArtworkPreview(): void {
    const artwork = this.selectedSkyCultureMakerConstellation()?.image
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
    this.releaseDecodedImage(oldPixelMap, 'previous-sky-culture-maker-artwork')
    this.skyCultureMakerArtworkPreviewPath = filePath
    this.skyCultureMakerStore.artworkPreviewState = 'preparing'
    const sourceWidth = Math.max(1, artwork.size?.[0] ?? 1)
    const sourceHeight = Math.max(1, artwork.size?.[1] ?? 1)
    const scale = Math.min(1, 1280 / Math.max(sourceWidth, sourceHeight))
    const desiredSize: ImageDecodeSize = {
      width: Math.max(1, Math.round(sourceWidth * scale)),
      height: Math.max(1, Math.round(sourceHeight * scale))
    }
    this.decodeLocalImage(filePath, 'sky-culture-maker-artwork', (pixelMap: image.PixelMap) => {
      if (generation !== this.skyCultureMakerArtworkDecodeGeneration || this.skyCultureMakerArtworkPreviewPath !== filePath) {
        this.releaseDecodedImage(pixelMap, 'stale-sky-culture-maker-artwork')
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
    const constellation = this.selectedSkyCultureMakerConstellation()
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
    const constellation = this.selectedSkyCultureMakerConstellation()
    if (constellation === undefined) return
    this.callInteractive('removeSkyCultureMakerArtwork', JSON.stringify({ constellationId: constellation.id }), (response: StellariumBridgeResponse) => {
      this.skyCultureMakerStore.artworkAnchorIndex = 0
      this.applySkyCultureMakerArtworkResponse(response, I18n.t('sky_culture_maker_artwork_removed'))
    })
  }

  private bindSkyCultureMakerArtworkAnchor(x: number, y: number): void {
    const constellation = this.selectedSkyCultureMakerConstellation()
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

  private playScriptByName(filename: string): void {
    if (this.scriptSessionActive()) {
      return
    }
    this.scriptStore.scriptLaunching = true
    this.scriptStore.scriptLaunchingName = filename
    this.scriptStore.scriptFocusActive = true
    this.scriptStore.scriptId = filename
    this.scriptStore.scriptRate = 1
    this.scriptStore.scriptWaiting = false
    this.scriptStore.scriptWaitMessage = ''
    this.scriptStartGraceUntil = Date.now() + 2500
    this.panelVisible = false
    this.infoWindowStore.infoWinVisible = false
    this.gyroStore.gyroCalibPanelOpen = false
    this.stopTimePanelTimers()
    this.stopSkyCultureTimeFollowTimer()
    this.stopPolarScopeTimer()
    this.startScriptStatusPolling()
    this.flashHint('正在启动脚本…')
    this.callInteractive('playScript', filename, (r: StellariumBridgeResponse) => {
      this.scriptStore.scriptLaunching = false
      this.scriptStore.scriptLaunchingName = ''
      if (r.ok === true) {
        this.flashHint(I18n.t('msg_script_running'))
        this.refreshScriptStatus()
      } else {
        this.scriptStore.scriptFocusActive = false
        this.scriptStore.scriptWaiting = false
        this.scriptStore.scriptWaitMessage = ''
        this.stopScriptStatusPolling()
        hilog.error(0x0000, 'StellariumArkUI', 'playScript failed %{public}s err=%{public}s', filename, r.error ?? '')
        this.flashHint(I18n.t('msg_apply_failed'))
      }
    }, () => {
      this.scriptStore.scriptLaunching = false
      this.scriptStore.scriptLaunchingName = ''
      this.scriptStore.scriptFocusActive = false
      this.scriptStore.scriptWaiting = false
      this.scriptStore.scriptWaitMessage = ''
      this.stopScriptStatusPolling()
      this.flashHint('脚本启动超时，请重试')
    })
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
              zh: this.celestialTitle(display, key),
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

  private catalogLabelForModule(moduleId: string, fallback: ResourceStr): ResourceStr {
    for (const option of this.catalogStore.objectCatalogCategories) {
      if (option.moduleId === moduleId) return option.label
    }
    return fallback
  }


  private categoryModuleIdFor(category: string): string {
    for (const option of this.searchCategoryOptions()) {
      if (option.code === category) return option.moduleId ?? ''
    }
    for (const option of this.catalogStore.objectCatalogCategories) {
      if (option.code === category) return option.moduleId ?? ''
    }
    return ''
  }

  // loadCategoryObjects 已下沉 state/SearchStore.ets（§14 B3-3）。

  private searchCategoryOptions(): Array<CatOption> {
    const core: CatOption[] = [
      { code: 'planet', label: this.catalogLabelForModule('SolarSystem:planet', I18n.t('i0103')), moduleId: 'SolarSystem:planet', iconKey: 'catalog_planet' },
      { code: 'moon', label: this.catalogLabelForModule('SolarSystem:moon', I18n.objectType('Moon')), moduleId: 'SolarSystem:moon', iconKey: 'catalog_moon' },
      { code: 'comet', label: this.catalogLabelForModule('SolarSystem:comet', I18n.objectType('Comet')), moduleId: 'SolarSystem:comet', iconKey: 'catalog_comet' },
      { code: 'asteroid', label: this.catalogLabelForModule('SolarSystem:asteroid', I18n.objectType('Asteroid')), moduleId: 'SolarSystem:asteroid', iconKey: 'catalog_asteroid' },
      { code: 'star', label: this.catalogLabelForModule('StarMgr', I18n.t('i0104')), moduleId: 'StarMgr', iconKey: 'catalog_star' },
      { code: 'variable', label: this.catalogLabelForModule('StarMgr:1', I18n.objectType('Variable star')), moduleId: 'StarMgr:1', iconKey: 'catalog_variable_star' },
      { code: 'constellation', label: this.catalogLabelForModule('ConstellationMgr', I18n.objectType('Constellation')), moduleId: 'ConstellationMgr', iconKey: 'catalog_constellation' },
      { code: 'galaxy', label: this.catalogLabelForModule('NebulaMgr:0', I18n.objectType('Galaxy')), moduleId: 'NebulaMgr:0', iconKey: 'catalog_galaxy' },
      { code: 'cluster', label: this.catalogLabelForModule('NebulaMgr:5', I18n.objectType('Cluster')), moduleId: 'NebulaMgr:5', iconKey: 'catalog_cluster' },
      { code: 'nebula', label: this.catalogLabelForModule('NebulaMgr:200', I18n.t('i0107')), moduleId: 'NebulaMgr:200', iconKey: 'catalog_nebula' },
      { code: 'messier', label: this.catalogLabelForModule('NebulaMgr:100', I18n.t('i0108')), moduleId: 'NebulaMgr:100', iconKey: 'catalog_messier' },
      { code: 'artificial', label: this.catalogLabelForModule('ArtificialObjects', I18n.t('search_artificial_objects')), moduleId: 'ArtificialObjects', iconKey: 'catalog_satellite' },
      { code: 'satellite', label: this.catalogLabelForModule('Satellites', I18n.objectType('Artificial satellite')), moduleId: 'Satellites', iconKey: 'catalog_satellite' }
    ]
    return core
  }

  private searchDynamicCategoryOptions(): Array<CatOption> {
    const core = this.searchCategoryOptions()
    const knownModules: Record<string, boolean> = {}
    for (const option of core) knownModules[option.moduleId ?? ''] = true
    const dynamic: CatOption[] = []
    for (const option of this.catalogStore.objectCatalogCategories) {
      if (!knownModules[option.moduleId ?? ''] && option.isPluginCatalog === true) dynamic.push(option)
    }
    dynamic.sort((left: CatOption, right: CatOption) => String(left.label).localeCompare(String(right.label)))
    return dynamic
  }

  private searchCategoryLabel(): string {
    for (const option of this.searchCategoryOptions()) {
      if (option.code === this.searchStore.searchCategory) return String(option.label)
    }
    for (const option of this.catalogStore.objectCatalogCategories) {
      if (option.code === this.searchStore.searchCategory) return String(option.label)
    }
    return I18n.t('search_browse_categories')
  }

  private searchAllCategoryOptions(): Array<CatOption> {
    const result: CatOption[] = []
    const modules: Record<string, boolean> = {}
    for (const option of [...this.searchCategoryOptions(), ...this.searchDynamicCategoryOptions()]) {
      const key = option.moduleId || option.code
      if (!modules[key]) {
        modules[key] = true
        result.push(option)
      }
    }
    return result
  }

  private publishSearchBrowserState(error: string = ''): void {
    AppStorage.setOrCreate('stellariumSearchBrowserState', JSON.stringify({
      ok: error.length === 0, error: error, page: this.searchStore.searchFilterPage || 'browse',
      category: this.searchStore.searchCategory, moduleId: this.searchStore.categoryModuleId,
      visibility: this.searchStore.searchVisibilityFilter, instrument: this.searchStore.searchInstrumentFilter,
      categories: this.searchAllCategoryOptions(), scrollY: this.searchPanelScroller.currentOffset()?.yOffset ?? 0
    }))
  }

  private searchCategoryIcon(category: string): string {
    for (const option of this.searchCategoryOptions()) {
      if (option.code === category) return option.iconKey ?? 'catalog_plugin'
    }
    for (const option of this.catalogStore.objectCatalogCategories) {
      if (option.code === category) return option.iconKey ?? 'catalog_plugin'
    }
    return 'catalog_plugin'
  }

  private searchVisibilityLabel(): string {
    if (this.searchStore.searchVisibilityFilter === 'above') return I18n.t('search_above_horizon')
    if (this.searchStore.searchVisibilityFilter === 'good') return I18n.t('search_good_observing')
    return ''
  }

  private searchInstrumentLabel(): string {
    if (this.searchStore.searchInstrumentFilter === 'naked') return I18n.t('search_naked_eye')
    if (this.searchStore.searchInstrumentFilter === 'binocular') return I18n.t('search_binoculars')
    if (this.searchStore.searchInstrumentFilter === 'telescope') return I18n.t('search_telescope')
    return ''
  }

  private refreshSearchFilterResults(): void {
    this.searchStore.loadCategoryObjects(this.searchStore.searchCategory)
    this.searchPanelScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false })
  }

  private selectSearchFilterCategory(category: string): void {
    if (!this.searchAllCategoryOptions().some((option: CatOption) => option.code === category)) {
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

  private categoryObservationSubtitle(item: NameItem): string {
    const parts: string[] = []
    const catalogText = this.celestialSubtitle(String(item.zh ?? item.name), item.name)
    if (catalogText.length > 0) parts.push(catalogText)
    if (item.visibleNow !== undefined) {
      parts.push(item.visibleNow ? I18n.t('search_visible_now') : I18n.t('search_below_horizon'))
    }
    if (item.altitude !== undefined && Number.isFinite(item.altitude)) {
      parts.push(I18n.format('search_altitude', [item.altitude.toFixed(0)]))
    }
    if (item.magnitude !== undefined && Number.isFinite(item.magnitude) && item.magnitude < 90) {
      parts.push(I18n.format('search_magnitude', [item.magnitude.toFixed(1)]))
    }
    return parts.join(' · ')
  }


  private categoryObjectIcon(item: NameItem): string {
    return catalogIconForObjectType(item.type ?? '', this.searchCategoryIcon(this.searchStore.searchCategory))
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

  private lx200Payload(): string {
    return JSON.stringify({
      slot: this.telescopeStore.lx200SelectedSlot,
      targetSource: this.telescopeStore.lx200TargetSource
    })
  }

  private applyTelescopeProfile(profile: TelescopeProfile): void {
    this.stopTelescopeLivePosition(false)
    this.telescopeStore.lx200SelectedSlot = profile.slot
    this.telescopeStore.lx200Name = profile.name
    this.telescopeStore.lx200Protocol = profile.protocol
    this.telescopeStore.lx200DeviceModel = profile.deviceModel
    this.telescopeStore.lx200Host = profile.host
    this.telescopeStore.lx200Port = profile.port.toString()
    this.telescopeStore.lx200Equinox = profile.equinox
    this.telescopeStore.lx200CommandDelayMs = profile.commandDelayMs
    this.telescopeStore.lx200Circles = profile.circles.join(', ')
	this.telescopeStore.lx200ConnectionState = profile.protocol === 'simulated' ? 'available' : (profile.state ?? 'not_tested')
	this.telescopeStore.lx200Position = ''
	this.telescopeStore.lx200PositionUpdatedAt = ''
	this.telescopeStore.lx200PositionUpdateState = 'idle'
	if (profile.protocol === 'simulated') {
	  this.telescopeStore.lx200Transport = I18n.t('m_telescope_transport_simulated')
	  this.telescopeStore.lx200Scope = I18n.t('m_telescope_scope_offline')
	  this.telescopeStore.lx200Status = I18n.t('m_telescope_simulator_ready')
	} else if (this.telescopeStore.lx200ConnectionState === 'unavailable') {
	  this.telescopeStore.lx200Status = profile.lastError ?? I18n.t('m_telescope_unavailable')
	} else if (this.telescopeStore.lx200ConnectionState === 'available') {
	  this.telescopeStore.lx200Status = I18n.t('m_telescope_available')
	} else {
	  this.telescopeStore.lx200Status = I18n.t('m_telescope_not_tested')
    }
    this.telescopeStore.lx200EditingNew = false
    this.scheduleTelescopeLivePosition(500)
  }

  private applyTelescopeProfiles(result: TelescopeProfilesResponse): void {
    const profiles = result.profiles ?? []
    this.telescopeStore.lx200Profiles = profiles
    const selectedSlot = result.selectedSlot ?? (profiles.length > 0 ? profiles[0].slot : 1)
    this.telescopeStore.lx200SelectedSlot = selectedSlot
    const selected = profiles.find((profile: TelescopeProfile) => profile.slot === selectedSlot)
    if (selected !== undefined) {
      this.applyTelescopeProfile(selected)
    }
  }

  private validateTelescopeEditorStatus(): void {
	if (this.telescopeStore.lx200Protocol === 'simulated') {
	  this.telescopeStore.lx200Transport = I18n.t('m_telescope_transport_simulated')
	  this.telescopeStore.lx200Scope = I18n.t('m_telescope_scope_offline')
	  this.telescopeStore.lx200ConnectionState = 'available'
	  return
	}
    this.callInteractive('getTelescopeControl', this.telescopeStore.lx200Host.trim() + '|' + this.telescopeStore.lx200Port.trim(), (result: TelescopeControlResponse) => {
      this.applyTelescopeEndpointStatus(result)
    })
  }

  private applyTelescopeEndpointStatus(result: TelescopeControlResponse): void {
    if (result.ok !== true) {
      this.telescopeStore.lx200Scope = I18n.t('m_telescope_scope_invalid')
      this.telescopeStore.lx200Transport = I18n.t('m_telescope_transport_tcp')
      return
    }
	if (result.simulated === true || result.scope === 'offline_simulator') {
	  this.telescopeStore.lx200Transport = I18n.t('m_telescope_transport_simulated')
	  this.telescopeStore.lx200Scope = I18n.t('m_telescope_scope_offline')
	  this.telescopeStore.lx200ConnectionState = 'available'
	  return
	}
    this.telescopeStore.lx200Transport = I18n.t('m_telescope_transport_tcp')
    const scope = result.scope as string
    if (scope === 'local_device') this.telescopeStore.lx200Scope = I18n.t('m_telescope_scope_local')
    else if (scope === 'local_or_lan') this.telescopeStore.lx200Scope = I18n.t('m_telescope_scope_lan')
    else if (scope === 'public_or_unclassified' || scope === 'hostname_or_unclassified') this.telescopeStore.lx200Scope = I18n.t('m_telescope_scope_blocked')
    else this.telescopeStore.lx200Scope = I18n.t('m_telescope_scope_unknown')
	this.telescopeStore.lx200ConnectionState = result.state ?? this.telescopeStore.lx200ConnectionState
  }

  private loadTelescopeControlStatus(): void {
    this.callInteractive('getTelescopeProfiles', '', (result: TelescopeProfilesResponse) => {
      if (result.ok !== true) {
        this.telescopeStore.lx200Status = result.error ?? I18n.t('m_telescope_load_failed')
        return
      }
      this.applyTelescopeProfiles(result)
      this.callInteractive('getTelescopeControl', this.lx200Payload(), (endpoint: TelescopeControlResponse) => {
        this.applyTelescopeEndpointStatus(endpoint)
        this.scheduleTelescopeLivePosition(500)
      })
    })
  }

  private selectTelescopeProfile(slot: number): void {
    if (slot === this.telescopeStore.lx200SelectedSlot && !this.telescopeStore.lx200EditingNew) return
    this.callInteractive('selectTelescopeProfile', slot.toString(), (result: TelescopeProfilesResponse) => {
      if (result.ok === true) {
        this.applyTelescopeProfiles(result)
        this.validateTelescopeEditorStatus()
      } else {
        this.telescopeStore.lx200Status = result.error ?? I18n.t('m_telescope_load_failed')
      }
    })
  }

  private beginNewTelescopeProfile(): void {
    this.stopTelescopeLivePosition(false)
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
	this.stopTelescopeLivePosition(false)
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

  private telescopeCircleValues(): number[] {
    const values: number[] = []
    const parts = this.telescopeStore.lx200Circles.split(',')
    for (let index = 0; index < parts.length; index += 1) {
      const value = Number(parts[index].trim())
      if (Number.isFinite(value) && value > 0 && value <= 180 && !values.includes(value)) {
        values.push(value)
      }
      if (values.length >= 10) break
    }
    values.sort((left: number, right: number) => left - right)
    return values
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
      circles: this.telescopeCircleValues()
    }
    this.telescopeStore.lx200Busy = true
    this.callInteractive('saveTelescopeProfile', JSON.stringify(profile), (result: TelescopeProfilesResponse) => {
      this.telescopeStore.lx200Busy = false
      if (result.ok !== true) {
        this.telescopeStore.lx200Status = result.error ?? I18n.t('m_telescope_save_failed')
        return
      }
      this.applyTelescopeProfiles(result)
      this.telescopeStore.lx200Status = I18n.t('m_telescope_saved')
      this.validateTelescopeEditorStatus()
    }, () => { this.telescopeStore.lx200Busy = false })
  }

  private deleteTelescopeProfile(): void {
    if (this.telescopeStore.lx200EditingNew) {
      this.loadTelescopeControlStatus()
      return
    }
    this.callInteractive('deleteTelescopeProfile', this.telescopeStore.lx200SelectedSlot.toString(), (result: TelescopeProfilesResponse) => {
      if (result.ok === true) {
        this.applyTelescopeProfiles(result)
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
    this.stopTelescopeLivePosition(false)
    this.telescopeStore.lx200Busy = true
    this.telescopeStore.lx200Status = I18n.t('m_telescope_connecting')
    this.callInteractive('testTelescopeConnection', this.lx200Payload(), (result: TelescopeControlResponse) => {
	  this.telescopeStore.lx200Busy = false
	  this.applyTelescopeEndpointStatus(result)
	  this.telescopeStore.lx200ConnectionState = result.ok === true ? 'available' : 'unavailable'
	  this.telescopeStore.lx200Status = result.ok === true
		? (result.simulated === true ? I18n.t('m_telescope_simulator_ready') : I18n.t('m_telescope_available'))
		: telescopeErrorText(result, I18n.t('m_telescope_test_failed'))
	  this.scheduleTelescopeLivePosition()
	}, (result: StellariumBridgeResponse) => {
	  const response = result as TelescopeControlResponse
	  this.telescopeStore.lx200Busy = false
	  if (response.state === 'available' || response.state === 'unavailable') this.telescopeStore.lx200ConnectionState = response.state
	  this.telescopeStore.lx200Status = telescopeErrorText(response, I18n.t('m_telescope_test_failed'))
	  this.scheduleTelescopeLivePosition()
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
	  if (result.mode === 'goto') this.setTelescopeLivePosition(true)
    } else {
	  if (response.state === 'available' || response.state === 'unavailable') this.telescopeStore.lx200ConnectionState = response.state
	  this.telescopeStore.lx200Status = telescopeErrorText(response, I18n.t('m_telescope_disconnected'))
    }
	this.scheduleTelescopeLivePosition()
  }

  private lx200GotoSelected(): void {
	if (this.telescopeStore.lx200EditingNew) {
	  this.telescopeStore.lx200Status = I18n.t('m_telescope_save_before_control')
	  return
	}
	this.stopTelescopeLivePosition(false)
	this.telescopeStore.lx200Busy = true
	this.telescopeStore.lx200Status = I18n.t('m_telescope_sending_goto')
    this.callInteractive('telescopeLx200GotoSelected', this.lx200Payload(),
      (result: StellariumBridgeResponse) => this.applyLx200Result(result),
      (result: StellariumBridgeResponse) => this.applyLx200Result(result))
  }

  private lx200SyncSelected(): void {
	if (this.telescopeStore.lx200EditingNew) {
	  this.telescopeStore.lx200Status = I18n.t('m_telescope_save_before_control')
	  return
	}
	this.stopTelescopeLivePosition(false)
	this.telescopeStore.lx200Busy = true
	this.telescopeStore.lx200Status = I18n.t('m_telescope_sending_sync')
    this.callInteractive('telescopeLx200SyncSelected', this.lx200Payload(),
      (result: StellariumBridgeResponse) => this.applyLx200Result(result),
      (result: StellariumBridgeResponse) => this.applyLx200Result(result))
  }

  private lx200Abort(): void {
	if (this.telescopeStore.lx200EditingNew) {
	  this.telescopeStore.lx200Status = I18n.t('m_telescope_save_before_control')
	  return
	}
    this.stopTelescopeLivePosition(false)
    this.telescopeStore.lx200Busy = true
    this.callInteractive('telescopeLx200Abort', this.lx200Payload(), (result) => {
	  const response = result as TelescopeControlResponse
	  this.telescopeStore.lx200Busy = false
	  if (response.state === 'available' || response.state === 'unavailable') this.telescopeStore.lx200ConnectionState = response.state
	  this.telescopeStore.lx200Status = result.ok === true ? I18n.t('m_telescope_stop_sent') :
		telescopeErrorText(response, I18n.t('m_telescope_stop_failed'))
	  this.scheduleTelescopeLivePosition()
	}, (result: StellariumBridgeResponse) => {
	  const response = result as TelescopeControlResponse
	  this.telescopeStore.lx200Busy = false
	  if (response.state === 'available' || response.state === 'unavailable') this.telescopeStore.lx200ConnectionState = response.state
	  this.telescopeStore.lx200Status = telescopeErrorText(response, I18n.t('m_telescope_stop_failed'))
	  this.scheduleTelescopeLivePosition()
	})
  }

  private readTelescopePosition(center: boolean = false): void {
	if (this.telescopeStore.lx200EditingNew) {
	  this.telescopeStore.lx200Status = I18n.t('m_telescope_save_before_control')
	  return
	}
	this.stopTelescopeLivePosition(false)
	this.telescopeStore.lx200Busy = true
	this.telescopeStore.lx200Status = center ? I18n.t('m_telescope_centering') : I18n.t('m_telescope_reading_position')
	const command = center ? 'centerScreenOnTelescope' : 'getTelescopePosition'
	this.callInteractive(command, this.lx200Payload(), (result: TelescopeControlResponse) => {
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
	  this.scheduleTelescopeLivePosition()
	}, (result: StellariumBridgeResponse) => {
	  const response = result as TelescopeControlResponse
	  this.telescopeStore.lx200Busy = false
	  if (response.state === 'available' || response.state === 'unavailable') this.telescopeStore.lx200ConnectionState = response.state
	  this.telescopeStore.lx200PositionUpdateState = 'error'
	  this.telescopeStore.lx200Status = telescopeErrorText(response, I18n.t('m_telescope_position_failed'))
	  this.scheduleTelescopeLivePosition()
	})
  }

  private toggleGyroscope(enabled: boolean): void {
    hilog.info(0x0000, 'StellariumArkUI', 'toggleGyroscope enabled=%{public}s current=%{public}s', enabled.toString(), this.gyroStore.gyroscopeEnabled.toString())
    if (enabled) {
      this.startGyroscope()
    } else {
      this.stopGyroscope(true)
    }
  }

  private refreshGyroDisplayRotation(source: string): void {
    try {
      const rotation = Number(display.getDefaultDisplaySync().rotation)
      if (!Number.isInteger(rotation) || rotation < 0 || rotation > 3) {
        return
      }
      if (rotation !== this.gyroDisplayRotation) {
        this.gyroDisplayRotation = rotation
        this.gyroFwd = []
        this.gyroUp = []
        this.gyroSentFwd = []
        this.gyroLastDispatchMs = 0
        hilog.info(0x0000, 'StellariumArkUI', '[gyro-probe] displayRotation source=%{public}s value=%{public}s', source, rotation.toString())
      }
      this.gyroLastDisplayRotationCheckMs = Date.now()
    } catch (error) {
      hilog.warn(0x0000, 'StellariumArkUI', '[gyro-probe] displayRotation unavailable source=%{public}s', source)
    }
  }

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
      this.stopGyroscope(false)
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

  private startGyroscope(): void {
    if (!this.privacyNativeStartupAllowed || !this.applicationInForeground || !hasCurrentPrivacyConsent()) {
      return
    }
    if (this.gyroStore.gyroscopeEnabled) {
      hilog.info(0x0000, 'StellariumArkUI', 'startGyroscope ignored already enabled')
      return
    }
    if (this.gyroCallback === undefined) {
      this.gyroCallback = (data: sensor.OrientationResponse) => {
        this.onOrientationData(data)
      }
    }
    if (this.gyroRotationCallback === undefined) {
      this.gyroRotationCallback = (data: sensor.RotationVectorResponse) => {
        this.onRotationVectorDirect(data)
      }
    }
    if (this.gyroGravityCallback === undefined) {
      this.gyroGravityCallback = (data: sensor.GravityResponse) => {
        this.onGravityData(data)
      }
    }
    if (this.gyroMagneticCallback === undefined) {
      this.gyroMagneticCallback = (data: sensor.MagneticFieldResponse) => {
        this.onMagneticFieldData(data)
      }
    }
    this.gyroLastTimeMs = 0
    this.gyroEventCount = 0
    this.gyroRawEventCount = 0
    this.gyroCallbackCount = 0
    this.gyroInvalidEventCount = 0
    this.gyroDispatchCount = 0
    this.gyroGravityEventCount = 0
    this.gyroMagneticEventCount = 0
    this.gyroStartMs = Date.now()
    this.gyroLastProbeMs = 0
    this.gyroLastProbeSensor = ''
    this.gyroRotationSubscribed = false
    this.gyroOrientationSubscribed = false
    this.gyroGravitySubscribed = false
    this.gyroMagneticSubscribed = false
    this.gyroFirstReading = true
    this.gyroCalibrated = false
    this.gyroLastDispatchMs = 0
    this.gyroDisplayRotation = 0
    this.gyroLastDisplayRotationCheckMs = 0
    this.gyroAbsolutePoseReady = false
    this.gyroHeadingReferenceReady = false
    this.gyroFwd = []
    this.gyroUp = []
    this.gyroSentFwd = []
    this.gyroGravityDevice = []
    this.gyroMagneticDevice = []
    this.gyroFilteredGravityDevice = []
    this.gyroFilteredMagneticDevice = []
    this.gyroMagneticHeading = Number.NaN
    this.gyroStore.gyroCompassAzAlignment = 0
    this.gyroStore.gyroCompassText = '罗盘 --'
    this.gyroStore.gyroCompassAngle = 0
    this.gyroUsingRotationVector = false
    this.gyroStore.gyroscopeEnabled = true
    this.refreshGyroDisplayRotation('start')
    this.gyroStore.gyroscopeStatus = '正在校准'
    this.callNativeFire('beginGyroViewTransition')

    const rotationSupported = this.probeGyroSensor(sensor.SensorId.ROTATION_VECTOR, 'rotation-vector')
    if (rotationSupported) {
      try {
        sensor.on(sensor.SensorId.ROTATION_VECTOR, this.gyroRotationCallback, { interval: 16666667 })
        this.gyroRotationSubscribed = true
        this.gyroUsingRotationVector = true
        hilog.info(0x0000, 'StellariumArkUI', '[gyro-probe] subscribed sensor=rotation-vector intervalNs=16666667')
      } catch (error) {
        hilog.error(0x0000, 'StellariumArkUI', '[gyro-probe] subscribe failed sensor=rotation-vector error=%{public}s', JSON.stringify(error))
      }
    }

    if (this.gyroRotationSubscribed) {
      if (this.probeGyroSensor(sensor.SensorId.GRAVITY, 'gravity')) {
        try {
          sensor.on(sensor.SensorId.GRAVITY, this.gyroGravityCallback, { interval: 16666667 })
          this.gyroGravitySubscribed = true
          hilog.info(0x0000, 'StellariumArkUI', '[gyro-probe] subscribed sensor=gravity intervalNs=16666667')
        } catch (error) {
          hilog.warn(0x0000, 'StellariumArkUI', '[gyro-probe] subscribe failed sensor=gravity error=%{public}s', JSON.stringify(error))
        }
      }
      if (this.probeGyroSensor(sensor.SensorId.MAGNETIC_FIELD, 'magnetic-field')) {
        try {
          sensor.on(sensor.SensorId.MAGNETIC_FIELD, this.gyroMagneticCallback, { interval: 33333333 })
          this.gyroMagneticSubscribed = true
          hilog.info(0x0000, 'StellariumArkUI', '[gyro-probe] subscribed sensor=magnetic-field intervalNs=33333333')
        } catch (error) {
          hilog.warn(0x0000, 'StellariumArkUI', '[gyro-probe] subscribe failed sensor=magnetic-field error=%{public}s', JSON.stringify(error))
        }
      }
      hilog.info(0x0000, 'StellariumArkUI', '[gyro-probe] start mode=rotation-vector gravity=%{public}s magnetic=%{public}s',
        this.gyroGravitySubscribed.toString(), this.gyroMagneticSubscribed.toString())
      return
    }

    if (this.probeGyroSensor(sensor.SensorId.ORIENTATION, 'orientation-fallback')) {
      try {
        sensor.on(sensor.SensorId.ORIENTATION, this.gyroCallback, { interval: 16666667 })
        this.gyroOrientationSubscribed = true
        this.gyroStore.gyroscopeStatus = '正在校准'
        hilog.warn(0x0000, 'StellariumArkUI', '[gyro-probe] start mode=orientation-fallback')
        return
      } catch (error) {
        hilog.error(0x0000, 'StellariumArkUI', '[gyro-probe] subscribe failed sensor=orientation-fallback error=%{public}s', JSON.stringify(error))
      }
    }

    this.gyroStore.gyroscopeEnabled = false
    this.callNativeFire('cancelGyroViewTransition')
    this.gyroStore.gyroscopeStatus = I18n.t('m_gyro_unavailable')
    this.flashHint(I18n.t('m_gyro_unavailable'))
    hilog.error(0x0000, 'StellariumArkUI', '[gyro-probe] start failed no supported orientation sensor')
  }

  private probeGyroSensor(type: sensor.SensorId, label: string): boolean {
    try {
      const info = sensor.getSingleSensorSync(type)
      this.gyroLastProbeSensor = label
      hilog.info(0x0000, 'StellariumArkUI', '[gyro-probe] sensor=%{public}s supported=true name=%{public}s vendor=%{public}s',
        label, info.sensorName, info.vendorName)
      return true
    } catch (error) {
      hilog.warn(0x0000, 'StellariumArkUI', '[gyro-probe] sensor=%{public}s supported=false error=%{public}s', label, JSON.stringify(error))
      return false
    }
  }

  private stopGyroscope(updateStatus: boolean): void {
    this.callNativeFire('cancelGyroViewTransition')
    const mode = this.gyroUsingRotationVector ? 'rotation-vector' : (this.gyroOrientationSubscribed ? 'orientation-fallback' : 'none')
    const elapsedMs = this.gyroStartMs > 0 ? Math.max(1, Date.now() - this.gyroStartMs) : 1
    hilog.info(0x0000, 'StellariumArkUI', '[gyro-probe] stop mode=%{public}s callbacks=%{public}s valid=%{public}s dispatch=%{public}s invalid=%{public}s gravity=%{public}s magnetic=%{public}s elapsedMs=%{public}s',
      mode, this.gyroCallbackCount.toString(), this.gyroRawEventCount.toString(), this.gyroDispatchCount.toString(),
      this.gyroInvalidEventCount.toString(), this.gyroGravityEventCount.toString(), this.gyroMagneticEventCount.toString(), elapsedMs.toString())
    if (this.gyroOrientationSubscribed && this.gyroCallback !== undefined) {
      try {
        sensor.off(sensor.SensorId.ORIENTATION, this.gyroCallback)
      } catch (error) {
      }
    }
    if (this.gyroRotationSubscribed && this.gyroRotationCallback !== undefined) {
      try {
        sensor.off(sensor.SensorId.ROTATION_VECTOR, this.gyroRotationCallback)
      } catch (error) {
      }
    }
    if (this.gyroGravitySubscribed && this.gyroGravityCallback !== undefined) {
      try {
        sensor.off(sensor.SensorId.GRAVITY, this.gyroGravityCallback)
      } catch (error) {
      }
    }
    if (this.gyroMagneticSubscribed && this.gyroMagneticCallback !== undefined) {
      try {
        sensor.off(sensor.SensorId.MAGNETIC_FIELD, this.gyroMagneticCallback)
      } catch (error) {
      }
    }
    this.gyroOrientationSubscribed = false
    this.gyroRotationSubscribed = false
    this.gyroGravitySubscribed = false
    this.gyroMagneticSubscribed = false
    this.gyroLastTimeMs = 0
    this.gyroCalibrated = false
    this.gyroFirstReading = true
    this.gyroLastDispatchMs = 0
    this.gyroAbsolutePoseReady = false
    this.gyroHeadingReferenceReady = false
    this.gyroUsingRotationVector = false
    this.gyroGravityDevice = []
    this.gyroMagneticDevice = []
    this.gyroFilteredGravityDevice = []
    this.gyroFilteredMagneticDevice = []
    this.gyroMagneticHeading = Number.NaN
    this.gyroStore.gyroCompassAzAlignment = 0
    this.gyroStore.gyroCompassText = '罗盘 --'
    this.gyroStore.gyroCompassAngle = 0
    this.gyroStore.gyroGuideVisible = false
    this.gyroStore.gyroscopeEnabled = false
    if (updateStatus) {
      this.gyroStore.gyroscopeStatus = I18n.t('m_gyro_off')
    }
  }

  // Device-pose tracking.
  //
  // Only the *heading* is calibrated against the current sky view. Pitch and
  // roll come from gravity and are already absolute, so re-basing them would
  // tilt the horizon. The heading, by contrast, depends on the magnetometer
  // and is either arbitrary or drifting, which is what made the sky jump
  // sideways when the fusion filter re-converged.
  private gyroLastAz: number = 0
  private gyroLastAlt: number = 0
  private gyroFirstReading: boolean = true
  private gyroCalibrated: boolean = false
  private gyroRawAz: number = 0
  private gyroRawAlt: number = 0
  // Smoothed pose, expressed in the bridge's alt-az frame.
  private gyroFwd: number[] = []
  private gyroUp: number[] = []
  private gyroSentFwd: number[] = []
  private gyroLastSampleMs: number = 0
  private gyroLastDispatchMs: number = 0
  // Last raw sensor quaternion (x,y,z,w) — kept for the diagnostic log so the
  // exact mapping can be reconstructed and verified offline.
  private gyroLastRawQ: number[] = [0, 0, 0, 1]
  // Anchored-pose model: we capture the device orientation and the engine's
  // current sky view once, then track only the *relative* tablet rotation from
  // that anchor. This is immune to landscape/portrait screen rotation and to
  // Stellarium's internal azimuth-sign convention (we read the live view back
  // from the engine instead of guessing an ENU->alt-az mapping).

  // Keep the guide's heading continuous. Native projection supplies angles in
  // [-180, 180], but animating that value directly can make a one-degree turn
  // across the boundary look like a full-circle spin.
  private setGyroGuidePose(x: number, y: number, targetAngle: number): void {
    let angle = targetAngle
    if (this.gyroStore.gyroGuideVisible) {
      let delta = (targetAngle - this.gyroStore.gyroGuideAngle) % 360
      if (delta > 180) { delta -= 360 }
      if (delta < -180) { delta += 360 }
      angle = this.gyroStore.gyroGuideAngle + delta
    }
    this.gyroStore.gyroGuideX = x
    this.gyroStore.gyroGuideY = y
    this.gyroStore.gyroGuideAngle = angle
    this.gyroStore.gyroGuideVisible = true
  }

  private updateGyroTargetGuide(force: boolean = false): void {
    if (!this.gyroStore.gyroscopeEnabled || this.objectDetailStore.selectedStatus !== 'Selected' ||
      !Number.isFinite(this.gyroGuideTargetAz) || !Number.isFinite(this.gyroGuideTargetAlt) ||
      !Number.isFinite(this.gyroLastAz) || !Number.isFinite(this.gyroLastAlt)) {
      this.gyroStore.gyroGuideVisible = false
      this.gyroGuideReachedAtMs = 0
      return
    }
    const now = Date.now()
    // The guide is an informational ArkUI overlay, not part of the camera
    // feedback loop. Updating it at 20 Hz keeps it responsive without making
    // every 60 Hz sensor sample perform a synchronous native projection query.
    if (!force && now - this.gyroGuideLastUpdateMs < 50) { return }
    this.gyroGuideLastUpdateMs = now

    const left = this.isExpandedLayout && this.panelVisible
      ? this.expandedMainPanelLeft() + this.panelWidth + 18
      : (this.isExpandedLayout ? this.EDGE_MARGIN + 24 : 18)
    const right = this.isExpandedLayout ? this.skyWidth - this.EDGE_MARGIN : this.skyWidth - 18
    const top = this.isFoldHoverLayout ? 46 : 64
    const bottom = this.skyHeight - (this.isFoldHoverLayout ? 104 : 96)
    const centerX = Math.max(left + 24, (left + right) / 2)
    const centerY = Math.max(top + 24, (top + bottom) / 2)

    // The C++ render loop projects the selected object with the active
    // Stellarium projector. This remains correct for every FOV and projection
    // type, unlike deriving a screen vector from separate alt/az deltas.
    const projection = this.callNative('getGyroGuidePosition') as GyroGuideProjection
    if (projection.ok === true && projection.valid === true &&
      typeof projection.xRatio === 'number' && typeof projection.yRatio === 'number') {
      const targetX = (projection.xRatio as number) * this.skyWidth
      const targetY = (projection.yRatio as number) * this.skyHeight
      const targetInClearSky = projection.visible === true &&
        targetX >= left + 24 && targetX <= right - 24 && targetY >= top + 24 && targetY <= bottom - 24
      if (targetInClearSky) {
        if (this.gyroGuideReachedAtMs === 0) {
          this.gyroGuideReachedAtMs = now
        }
        // The arrow confirms that the target has arrived, then gets out of
        // the way. It reappears only after the object leaves the clear sky.
        if (now - this.gyroGuideReachedAtMs >= 1800) {
          this.gyroStore.gyroGuideVisible = false
          return
        }
        // The guide sits above its target and points down. At the very top,
        // place it below instead so it stays fully reachable and visible.
        const placeAbove = targetY - 58 >= top
        this.setGyroGuidePose(
          clamp(targetX - 22, left, Math.max(left, right - 44)),
          clamp(targetY + (placeAbove ? -58 : 14) - 22, top, Math.max(top, bottom - 44)),
          placeAbove ? 90 : -90
        )
        return
      }
      this.gyroGuideReachedAtMs = 0
      // If the native projection is outside the usable sky area, its true
      // screen-space vector still gives an accurate edge direction.
      const dx = targetX - centerX
      const dy = targetY - centerY
      if (Number.isFinite(dx) && Number.isFinite(dy) && Math.abs(dx) + Math.abs(dy) > 0.5) {
        const angle = Math.atan2(dy, dx) * 180 / Math.PI
        const radians = angle * Math.PI / 180
        const halfW = Math.max(1, (right - left) / 2 - 24)
        const halfH = Math.max(1, (bottom - top) / 2 - 24)
        const edgeScaleX = Math.abs(Math.cos(radians)) > 0.0001 ? halfW / Math.abs(Math.cos(radians)) : Number.POSITIVE_INFINITY
        const edgeScaleY = Math.abs(Math.sin(radians)) > 0.0001 ? halfH / Math.abs(Math.sin(radians)) : Number.POSITIVE_INFINITY
        const edgeScale = Math.min(edgeScaleX, edgeScaleY)
        this.setGyroGuidePose(
          clamp(centerX + Math.cos(radians) * edgeScale - 22, left, Math.max(left, right - 44)),
          clamp(centerY + Math.sin(radians) * edgeScale - 22, top, Math.max(top, bottom - 44)),
          angle
        )
        return
      }
    }

    // Project the target's local tangent-plane direction around the current
    // view. Cos(altitude) prevents a small azimuth change near zenith from
    // looking like an enormous horizontal turn.
    const horizontal = shortestGyroAzimuthDelta(this.gyroGuideTargetAz, this.gyroLastAz) *
      Math.cos(this.gyroLastAlt * Math.PI / 180)
    const vertical = this.gyroGuideTargetAlt - this.gyroLastAlt
    const separation = Math.sqrt(horizontal * horizontal + vertical * vertical)
    const fov = Math.max(5, this.fovSliderValue > 0 ? this.fovSliderValue : 60)
    if (separation <= fov * 0.48) {
      this.gyroStore.gyroGuideVisible = false
      this.gyroGuideReachedAtMs = 0
      return
    }

    // The forward icon points right at 0 degrees. Negative vertical is up on
    // screen, so a target above the view produces a -90 degree arrow.
    const angle = Math.atan2(-vertical, horizontal) * 180 / Math.PI
    const radians = angle * Math.PI / 180
    const dx = Math.cos(radians)
    const dy = Math.sin(radians)
    // Intersect the direction vector with the usable viewport rectangle.
    // This puts the guide on its edge rather than on an arbitrary inner ring.
    const halfW = Math.max(1, (right - left) / 2 - 24)
    const halfH = Math.max(1, (bottom - top) / 2 - 24)
    const edgeScaleX = Math.abs(dx) > 0.0001 ? halfW / Math.abs(dx) : Number.POSITIVE_INFINITY
    const edgeScaleY = Math.abs(dy) > 0.0001 ? halfH / Math.abs(dy) : Number.POSITIVE_INFINITY
    const edgeScale = Math.min(edgeScaleX, edgeScaleY)
    this.setGyroGuidePose(
      clamp(centerX + dx * edgeScale - 22, left, Math.max(left, right - 44)),
      clamp(centerY + dy * edgeScale - 22, top, Math.max(top, bottom - 44)),
      angle
    )
  }

  // The Orientation sensor already reports a world-referenced pose. Do not
  // anchor it to the existing sky view: doing so makes "flat" retain an
  // arbitrary altitude instead of consistently looking at the nadir.
  private calibrateGyroscope(): void {
    if (!this.gyroStore.gyroscopeEnabled || this.gyroFirstReading) { return }
    this.gyroAbsolutePoseReady = false
    this.gyroHeadingReferenceReady = false
    this.gyroLastDispatchMs = 0
    this.gyroCalibrated = true
    this.gyroStore.gyroscopeStatus = '已校准'
  }

  private onOrientationData(data: sensor.OrientationResponse): void {
    if (!this.gyroStore.gyroscopeEnabled) { return }
    this.gyroCallbackCount += 1
    let smoothFactor: number = 0.18
    if (this.gyroStore.gyroscopeSensitivityText === 'Low') { smoothFactor = 0.10 }
    else if (this.gyroStore.gyroscopeSensitivityText === 'High') { smoothFactor = 0.28 }

    if (!Number.isFinite(data.alpha) || !Number.isFinite(data.beta) || !Number.isFinite(data.gamma)) {
      this.gyroInvalidEventCount += 1
      this.emitGyroPoseProbe('invalid')
      return
    }
    this.gyroRawEventCount += 1
    const alpha = data.alpha * Math.PI / 180
    const beta = data.beta * Math.PI / 180
    const gamma = data.gamma * Math.PI / 180
    const cosAlpha = Math.cos(alpha)
    const sinAlpha = Math.sin(alpha)
    const cosBeta = Math.cos(beta)
    const sinBeta = Math.sin(beta)
    const cosGamma = Math.cos(gamma)
    const sinGamma = Math.sin(gamma)
    // World-space normal of the display front. The observer looks through the
    // back of the device, hence the sky-forward vector is its inverse.
    const normalX = cosAlpha * sinGamma + sinAlpha * sinBeta * cosGamma
    const normalY = sinAlpha * sinGamma - cosAlpha * sinBeta * cosGamma
    const normalZ = cosBeta * cosGamma
    const forwardX = -normalX
    const forwardY = -normalY
    const forwardZ = -normalZ
    const targetAlt = clamp(Math.asin(clamp(forwardZ, -1, 1)) * 180 / Math.PI + this.gyroStore.gyroOffsetAlt, -90, 90)
    // A display pointing near the zenith or nadir has no meaningful heading:
    // tiny sensor noise can map to any azimuth and makes the horizon slide
    // sideways while lifting the Pad. alpha is the fused compass heading and
    // remains stable when the Pad is vertical, so use it for yaw; retain the
    // last heading in the polar dead zone and restore it progressively.
    const horizontalStrength = Math.sqrt(forwardX * forwardX + forwardY * forwardY)
    // In landscape, the reported alpha rotates in the opposite direction to
    // Stellarium's azimuth frame. More importantly, it becomes ambiguous when
    // the Pad is flat. Anchor only once the display has a real horizontal aim;
    // after that use its delta, not its changing Euler-angle zero point.
    const rawHeading = wrapGyroAzimuth(-data.alpha + this.gyroStore.gyroOffsetAz)
    let targetAz = rawHeading
    if (this.gyroAbsolutePoseReady) {
      if (!this.gyroHeadingReferenceReady && horizontalStrength >= 0.42) {
        this.gyroHeadingSensorAz = rawHeading
        this.gyroHeadingViewAz = this.gyroLastAz
        this.gyroHeadingReferenceReady = true
      }
      targetAz = this.gyroHeadingReferenceReady
        ? wrapGyroAzimuth(this.gyroHeadingViewAz + shortestGyroAzimuthDelta(this.gyroHeadingSensorAz, rawHeading))
        : this.gyroLastAz
    }
    // Device Y is the top edge of the screen. Keeping it as the camera up
    // basis removes the otherwise undefined roll at zenith and nadir.
    const rawUp: number[] = [-sinAlpha * cosBeta, cosAlpha * cosBeta, sinBeta]

    this.gyroRawAz = targetAz
    this.gyroRawAlt = targetAlt
    this.emitGyroPoseProbe('sample', [forwardX, forwardY, forwardZ], rawUp, targetAz, targetAlt)
    if (this.gyroFirstReading) {
      this.gyroFirstReading = false
      this.calibrateGyroscope()
      return
    }
    if (!this.gyroCalibrated) { return }

    let initialPose = false
    if (!this.gyroAbsolutePoseReady) {
      this.gyroLastAz = targetAz
      this.gyroLastAlt = targetAlt
      this.gyroAbsoluteUp = rawUp
      this.gyroAbsolutePoseReady = true
      initialPose = true
    }
    const headingFactor = this.gyroHeadingReferenceReady ? smoothFactor : 0
    const smoothAz = wrapGyroAzimuth(this.gyroLastAz +
      shortestGyroAzimuthDelta(this.gyroLastAz, targetAz) * headingFactor)
    const smoothAlt = this.gyroLastAlt + (targetAlt - this.gyroLastAlt) * smoothFactor

    const azDelta = shortestGyroAzimuthDelta(this.gyroLastAz, smoothAz)
    const altDelta = smoothAlt - this.gyroLastAlt
    // The first valid pose must always reach the native view. Without this,
    // enabling the sensor while the Pad is held still leaves Stellarium at
    // the old horizon because the normal dead-zone returns before dispatch.
    if (!initialPose && Math.abs(azDelta) < 0.25 && Math.abs(altDelta) < 0.25) { return }

    this.gyroLastAz = smoothAz
    this.gyroLastAlt = smoothAlt
    const aimX = Math.cos(smoothAlt * Math.PI / 180) * Math.cos(smoothAz * Math.PI / 180)
    const aimY = Math.cos(smoothAlt * Math.PI / 180) * Math.sin(smoothAz * Math.PI / 180)
    const aimZ = Math.sin(smoothAlt * Math.PI / 180)
    let upX = this.gyroAbsoluteUp[0] + (rawUp[0] - this.gyroAbsoluteUp[0]) * smoothFactor
    let upY = this.gyroAbsoluteUp[1] + (rawUp[1] - this.gyroAbsoluteUp[1]) * smoothFactor
    let upZ = this.gyroAbsoluteUp[2] + (rawUp[2] - this.gyroAbsoluteUp[2]) * smoothFactor
    const upDotAim = upX * aimX + upY * aimY + upZ * aimZ
    upX -= aimX * upDotAim
    upY -= aimY * upDotAim
    upZ -= aimZ * upDotAim
    const upLength = Math.sqrt(upX * upX + upY * upY + upZ * upZ)
    this.gyroAbsoluteUp = upLength > 0.0001 ? [upX / upLength, upY / upLength, upZ / upLength] : rawUp
    const now = Date.now()
    this.updateGyroTargetGuide()
    if (now - this.gyroLastDispatchMs < 20) { return }
    this.gyroLastDispatchMs = now
    this.callNativeFire('setGyroView', smoothAz.toFixed(3) + '|' + smoothAlt.toFixed(3) + '|'
      + this.gyroAbsoluteUp[0].toFixed(5) + '|' + this.gyroAbsoluteUp[1].toFixed(5) + '|' + this.gyroAbsoluteUp[2].toFixed(5))
    this.gyroEventCount += 1
    this.gyroDispatchCount += 1
    if (this.gyroEventCount % 20 === 0) {
      this.gyroStore.gyroscopeStatus = I18n.t('m_gyro_working')
    }
  }

  private gyroRotateVector(q: number[], v: number[]): number[] {
    const vectorQuaternion = [v[0], v[1], v[2], 0]
    const rotated = gyroMultiplyQuaternions(gyroMultiplyQuaternions(q, vectorQuaternion), gyroConjugateQuaternion(q))
    return [rotated[0], rotated[1], rotated[2]]
  }

  private gyroVectorAltAz(v: number[]): number[] {
    const n = gyroNormalizeVector(v)
    let azimuth = Math.atan2(n[1], n[0]) * 180 / Math.PI
    if (azimuth < 0) { azimuth += 360 }
    return [azimuth, Math.asin(n[2]) * 180 / Math.PI]
  }

  // Keep the up vector perpendicular to the view direction. Without this the
  // two drift apart after repeated smoothing and the roll becomes unstable
  // near the zenith.
  private gyroOrthonormalizeUp(fwd: number[], up: number[]): number[] {
    const d = fwd[0] * up[0] + fwd[1] * up[1] + fwd[2] * up[2]
    let o: number[] = [up[0] - fwd[0] * d, up[1] - fwd[1] * d, up[2] - fwd[2] * d]
    if (o[0] * o[0] + o[1] * o[1] + o[2] * o[2] < 0.000001) {
      const dz = fwd[2]
      o = [-fwd[0] * dz, -fwd[1] * dz, 1 - fwd[2] * dz]
      if (o[0] * o[0] + o[1] * o[1] + o[2] * o[2] < 0.000001) { return [1, 0, 0] }
    }
    return gyroNormalizeVector(o)
  }

  // Interpolate directly on the unit sphere. Linear interpolation of the
  // forward and screen-up vectors independently makes a non-rigid camera and
  // is the source of the apparent jump when the view crosses the zenith.
  // Parallel-transport the screen's up axis along the celestial sphere from
  // one look direction to the next. This provides a continuous tangent-plane
  // basis at zenith and nadir instead of rebuilding one from an Euler angle.
  // The rotation-vector sensor reports in the ENU (east/north/up) world frame,
  // while the engine view direction and setGyroView use the bridge alt-az frame
  // (azimuth = atan2(y, x), x points south). The two frames differ only by a
  // 90 deg rotation about the vertical, but applying an ENU-frame relative
  // rotation directly to a bridge-frame vector silently swaps pitch and roll.
  // These helpers keep the math in one frame at a time.
  private gyroBridgeFromEnu(v: number[]): number[] { // ENU -> bridge
    return [-v[1], v[0], v[2]]
  }

  // Legacy quaternion implementation retained temporarily only to keep this
  // restoration narrowly scoped. It is not subscribed or called.
  // Capture the engine's current sky view plus the device pose as the anchor.
  // After this, the gyro tracks only the *relative* tablet rotation from the
  // anchor, which is independent of landscape/portrait and of the engine's
  // internal azimuth convention. `q` is the device->world quaternion.
  // Direct rotation-vector path. The system fusion already combines gravity,
  // gyroscope and magnetometer into a complete pose, which avoids the Euler
  // alpha/beta/gamma discontinuity at the horizon. The separate gravity and
  // magnetic callbacks remain active for compass/calibration data, but never
  // replace only one axis of this high-frequency camera pose.
  private onGravityData(data: sensor.GravityResponse): void {
    this.gyroGravityEventCount += 1
    if (Number.isFinite(data.x) && Number.isFinite(data.y) && Number.isFinite(data.z)) {
      const sample = [data.x, data.y, data.z]
      this.gyroGravityDevice = sample
      this.gyroFilteredGravityDevice = gyroFilterDeviceVector(this.gyroFilteredGravityDevice, sample, 0.22)
    }
  }

  private onMagneticFieldData(data: sensor.MagneticFieldResponse): void {
    this.gyroMagneticEventCount += 1
    if (Number.isFinite(data.x) && Number.isFinite(data.y) && Number.isFinite(data.z)) {
      const sample = [data.x, data.y, data.z]
      this.gyroMagneticDevice = sample
      this.gyroFilteredMagneticDevice = gyroFilterDeviceVector(this.gyroFilteredMagneticDevice, sample, 0.16)
    }
  }

  // Derive the world basis directly from the two physical references. On this
  // HarmonyOS device the gravity response is the support vector pointing up.
  // Magnetic x up points east; up x east points north.
  // This gives a true device pose without applying a second correction to an
  // already fused rotation quaternion.
  // Heading from magnetic north with tilt compensation. `GRAVITY` supplies
  // the physical up axis and the horizontal component of the magnetic field
  // supplies magnetic north, so this remains meaningful while the tablet is
  // tilted toward the horizon. It is deliberately diagnostic/calibration-only
  // and never fed into the high-frequency camera loop.
  private gyroMagneticHeadingFromDeviceVectors(): number {
    if (this.gyroGravityDevice.length !== 3 || this.gyroMagneticDevice.length !== 3) {
      return Number.NaN
    }
    const gravity = this.gyroFilteredGravityDevice.length === 3
      ? this.gyroFilteredGravityDevice : this.gyroGravityDevice
    const magneticField = this.gyroFilteredMagneticDevice.length === 3
      ? this.gyroFilteredMagneticDevice : this.gyroMagneticDevice
    const up = gyroNormalizeVector(gravity)
    const magnetic = gyroNormalizeVector(magneticField)
    const northRaw = [
      magnetic[0] - up[0] * gyroDot(magnetic, up),
      magnetic[1] - up[1] * gyroDot(magnetic, up),
      magnetic[2] - up[2] * gyroDot(magnetic, up)
    ]
    const northLength = Math.sqrt(gyroDot(northRaw, northRaw))
    if (northLength < 0.12) { return Number.NaN }
    const north = [northRaw[0] / northLength, northRaw[1] / northLength, northRaw[2] / northLength]
    const east = gyroNormalizeVector(gyroCross(north, up))
    // The observer looks through the rear side of the display.
    const rearNormal = [0, 0, -1]
    const eastComponent = gyroDot(rearNormal, east)
    const northComponent = gyroDot(rearNormal, north)
    return wrapGyroAzimuth(Math.atan2(eastComponent, northComponent) * 180 / Math.PI)
  }

  private gyroCompassDirection(heading: number): string {
    const directions = ['北', '东北', '东', '东南', '南', '西南', '西', '西北']
    const index = Math.floor((wrapGyroAzimuth(heading) + 22.5) / 45) % directions.length
    return directions[index]
  }

  private updateGyroCompassReadout(): void {
    const heading = this.gyroMagneticHeadingFromDeviceVectors()
    if (!Number.isFinite(heading)) { return }
    this.gyroMagneticHeading = heading
    // Keep the needle continuous through 359 -> 0 rather than animating a
    // full revolution in the opposite direction.
    let delta = (heading - this.gyroStore.gyroCompassAngle) % 360
    if (delta > 180) { delta -= 360 }
    if (delta < -180) { delta += 360 }
    this.gyroStore.gyroCompassAngle += delta
    const now = Date.now()
    if (now - this.gyroLastCompassUiUpdateMs < 120) { return }
    this.gyroLastCompassUiUpdateMs = now
    this.gyroStore.gyroCompassText = '磁北 ' + this.gyroCompassDirection(heading) + ' ' + Math.round(heading).toString().padStart(3, '0') + '°'
  }

  private emitGyroPoseProbe(reason: string, rawForward: number[] = [], rawUp: number[] = [], rawAz: number = Number.NaN, rawAlt: number = Number.NaN): void {
    const now = Date.now()
    if (now - this.gyroLastProbeMs < 1000) { return }
    this.gyroLastProbeMs = now
    hilog.info(0x0000, 'StellariumArkUI',
      '[GYRO_PROBE] reason=%{public}s callbacks=%{public}d dispatch=%{public}d invalid=%{public}d',
      reason, this.gyroCallbackCount, this.gyroDispatchCount, this.gyroInvalidEventCount)
  }

  private onRotationVectorDirect(data: sensor.RotationVectorResponse): void {
    if (!this.gyroStore.gyroscopeEnabled) { return }
    this.gyroCallbackCount += 1
    if (!Number.isFinite(data.x) || !Number.isFinite(data.y) ||
      !Number.isFinite(data.z) || !Number.isFinite(data.w)) {
      this.gyroInvalidEventCount += 1
      this.emitGyroPoseProbe('invalid')
      return
    }
    this.gyroLastRawQ = [data.x, data.y, data.z, data.w]
    const rawQuaternionNorm = Math.sqrt(data.x * data.x + data.y * data.y + data.z * data.z + data.w * data.w)
    if (!Number.isFinite(rawQuaternionNorm) || rawQuaternionNorm < 0.000001) {
      this.gyroInvalidEventCount += 1
      this.emitGyroPoseProbe('invalid')
      return
    }
    this.gyroRawEventCount += 1
    const sampleNow = Date.now()
    if (sampleNow - this.gyroLastDisplayRotationCheckMs >= 500) {
      this.refreshGyroDisplayRotation('sample')
    }
    if (this.gyroRawEventCount % 120 === 0) {
      this.callNativeFire('gyroDiagnostic', data.x.toFixed(3) + '|' + data.y.toFixed(3) + '|' +
        data.z.toFixed(3) + '|' + this.gyroRawEventCount.toString())
    }
    const orientation = gyroNormalizeQuaternion([data.x, data.y, data.z, data.w])
    const screenRight = gyroScreenAxisForDisplay([1, 0, 0], this.gyroDisplayRotation)
    const screenUp = gyroScreenAxisForDisplay([0, 1, 0], this.gyroDisplayRotation)
    const screenFrontWorld = this.gyroRotateVector(orientation, [0, 0, 1])
    const screenRightWorld = this.gyroRotateVector(orientation, screenRight)
    const screenUpWorld = this.gyroRotateVector(orientation, screenUp)
    // ROTATION_VECTOR is already a device-to-world orientation. The sky ray
    // goes opposite to the screen front normal; the screen basis stays rigid.
    let forward = this.gyroBridgeFromEnu([-screenFrontWorld[0], -screenFrontWorld[1], -screenFrontWorld[2]])
    forward = gyroNormalizeVector(forward)

    if (this.gyroStore.gyroOffsetAz !== 0) {
      forward = gyroRotateAboutVertical(forward, this.gyroStore.gyroOffsetAz)
    }
    if (this.gyroStore.gyroOffsetAlt !== 0) {
      const horizontal = Math.sqrt(forward[0] * forward[0] + forward[1] * forward[1])
      if (horizontal > 0.001) {
        forward = gyroRotateAboutAxis(forward, [forward[1] / horizontal, -forward[0] / horizontal, 0], this.gyroStore.gyroOffsetAlt)
        forward = gyroNormalizeVector(forward)
      }
    }

    let up = this.gyroBridgeFromEnu(screenUpWorld)
    const rightLength = Math.sqrt(gyroDot(screenRightWorld, screenRightWorld))
    if (rightLength < 0.5) {
      this.gyroInvalidEventCount += 1
      this.emitGyroPoseProbe('invalid-basis', forward, up)
      return
    }
    this.updateGyroCompassReadout()
    if (this.gyroStore.gyroOffsetAz !== 0) {
      up = gyroRotateAboutVertical(up, this.gyroStore.gyroOffsetAz)
    }
    if (this.gyroStore.gyroOffsetAlt !== 0) {
      const horizontal = Math.sqrt(forward[0] * forward[0] + forward[1] * forward[1])
      if (horizontal > 0.001) {
        up = gyroRotateAboutAxis(up, [forward[1] / horizontal, -forward[0] / horizontal, 0], this.gyroStore.gyroOffsetAlt)
      }
    }
    up = this.gyroOrthonormalizeUp(forward, up)
    const rawAltAz = this.gyroVectorAltAz(forward)
    this.gyroRawAzimuth = rawAltAz[0]
    this.gyroRawAltitude = rawAltAz[1]

    const now = Date.now()
    let poseSmoothingAmount = 1
    if (this.gyroFwd.length !== 3) {
      this.gyroFwd = forward
      this.gyroLastSampleMs = now
    } else {
      let dt = this.gyroLastSampleMs > 0 ? (now - this.gyroLastSampleMs) / 1000 : 1 / 60
      this.gyroLastSampleMs = now
      if (dt <= 0) { dt = 1 / 60 }
      if (dt > 0.25) { dt = 0.25 }
      // ROTATION_VECTOR is already sensor-fused. A long second low-pass filter
      // made the sky trail the Pad by roughly 100 ms, which felt like dropped
      // frames even when rendering was healthy. Keep only enough damping for
      // hand tremor and use the same time-based amount for forward and up.
      let tau = 0.045
      if (this.gyroStore.gyroscopeSensitivityText === 'Low') { tau = 0.08 }
      else if (this.gyroStore.gyroscopeSensitivityText === 'High') { tau = 0.025 }
      poseSmoothingAmount = 1 - Math.exp(-dt / tau)
      this.gyroFwd = gyroNormalizeVector([
        this.gyroFwd[0] + (forward[0] - this.gyroFwd[0]) * poseSmoothingAmount,
        this.gyroFwd[1] + (forward[1] - this.gyroFwd[1]) * poseSmoothingAmount,
        this.gyroFwd[2] + (forward[2] - this.gyroFwd[2]) * poseSmoothingAmount
      ])
    }

    if (this.gyroUp.length !== 3) {
      this.gyroUp = up
    } else {
      if (gyroDot(this.gyroUp, up) < 0) {
        up = [-up[0], -up[1], -up[2]]
      }
      this.gyroUp = this.gyroOrthonormalizeUp(this.gyroFwd, [
        this.gyroUp[0] + (up[0] - this.gyroUp[0]) * poseSmoothingAmount,
        this.gyroUp[1] + (up[1] - this.gyroUp[1]) * poseSmoothingAmount,
        this.gyroUp[2] + (up[2] - this.gyroUp[2]) * poseSmoothingAmount
      ])
    }
    this.emitGyroPoseProbe('sample', forward, up, rawAltAz[0], rawAltAz[1])

    if (now - this.gyroLastDispatchMs < 16) { return }
    this.gyroLastDispatchMs = now
    const altAz = this.gyroVectorAltAz(this.gyroFwd)
    this.gyroLastAz = altAz[0]
    this.gyroLastAlt = altAz[1]
    this.updateGyroTargetGuide()
    this.callNativeFire('setGyroView', this.gyroLastAz.toFixed(3) + '|' + this.gyroLastAlt.toFixed(3) + '|'
      + this.gyroUp[0].toFixed(5) + '|' + this.gyroUp[1].toFixed(5) + '|' + this.gyroUp[2].toFixed(5))
    this.gyroEventCount += 1
    this.gyroDispatchCount += 1
    if (this.gyroEventCount % 20 === 0 && this.gyroStore.gyroscopeStatus !== I18n.t('m_gyro_working')) {
      this.gyroStore.gyroscopeStatus = I18n.t('m_gyro_working')
    }
  }

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
        const observerPlanetSelection = this.isObserverPlanetSelection(selectedEnglishName)
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
        this.applySelectedObject(result, false, selectionPlacement)
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
      const calibrationTop = this.isExpandedLayout ? this.railTop() + 120 : 80
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
    if (!this.hasSelectedObject()) {
      this.flashHint(I18n.t('center_requires_selection'))
      return
    }
    // Sensor pose is the camera owner while gyro mode is active. Starting a
    // second auto-move here creates a visible jump when the next pose sample
    // correctly takes control back, so center/track only refresh the guide.
    if (this.gyroStore.gyroscopeEnabled) {
      this.updateGyroTargetGuide(true)
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
      label: 'bottom-dock', left: this.dockLeft(), top: this.dockTop(),
      right: this.dockLeft() + this.dockWidthPixels(), bottom: this.skyHeight
    })
    if (this.isExpandedLayout) {
      if (this.panelVisible) {
        obstacles.push({
          label: 'panel', left: this.expandedMainPanelLeft(), top: this.panelTop(),
          right: this.expandedMainPanelLeft() + this.panelWidth,
          bottom: this.panelTop() + this.panelMaxHeight
        })
      }
      if (this.infoWindowStore.infoWinVisible) {
        if (useTabletObjectInspector()) {
          obstacles.push({
            label: 'object-inspector', left: this.tabletInspectorX(), top: this.tabletInspectorY(),
            right: this.tabletInspectorX() + this.tabletInspectorWidth(), bottom: this.tabletInspectorY() + this.tabletInspectorHeight()
          })
        } else if (useExpandedDetailSummary() && this.canShowExpandedDetailSummary()) {
          obstacles.push({
            label: 'summary', left: this.expandedDetailSummaryX(), top: this.expandedDetailSummaryY(),
            right: this.expandedDetailSummaryX() + this.expandedDetailSummaryWidth(),
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
    const left = this.panelVisible ? this.expandedMainPanelLeft() + this.panelWidth + 18 : this.EDGE_MARGIN + 64
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
  private observingDisplayName(englishName: string): string {
    const target = this.wutStore.wutTargets.find((item: WutTarget) => item.englishName === englishName)
    if (target !== undefined) return this.wutTargetTitle(target)
    return planetZh(englishName) !== englishName ? planetZh(englishName) : zhNameOf(englishName)
  }


  private celestialTitle(nativeName: string, englishName: string): string {
    const localizedNative = zhNameOf(nativeName)
    return localizedNative.length > 0 ? localizedNative : englishName
  }


  private celestialSubtitle(title: string, englishName: string): string {
    const parts: string[] = []
    if (englishName.length > 0 && title.trim().toLowerCase() !== englishName.trim().toLowerCase()) {
      parts.push(englishName.trim())
    }
    const messier = messierNumberOf(englishName)
    if (messier.length > 0) { parts.push(I18n.format('search_catalog_number', ['M' + messier])) }
    if (this.searchStore.searchCategory === 'asteroid') {
      const number = minorPlanetNumberOf(englishName)
      if (number.length > 0) { parts.push(I18n.format('search_permanent_number', [number])) }
    }
    return parts.join(' · ')
  }

  private wutTargetTitle(target: WutTarget): string {
    return this.celestialTitle(target.name ?? '', target.englishName ?? '')
  }





  private wutTargetSubtitle(target: WutTarget): string {
    return this.celestialSubtitle(this.wutTargetTitle(target), target.englishName ?? '')
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

  private selectedLiveInfoVisible(): boolean {
    return this.infoWindowStore.infoLevel <= 1
  }

  private applyCustomInformationMask(): void {
    if (this.infoWindowStore.informationMode !== 'custom') return
    if (!this.informationMaskHas('magnitude')) {
      this.objectDetailStore.selectedMagnitude = ''
      this.objectDetailStore.selectedApparentMagnitude = ''
      this.objectDetailStore.selectedAirmass = ''
      this.objectDetailStore.selectedExtinction = ''
    }
    if (!this.informationMaskHas('raOfDate')) this.objectDetailStore.selectedCoordEq = ''
    if (!this.informationMaskHas('raJ2000')) this.objectDetailStore.selectedCoordEqJ2000 = ''
    if (!this.informationMaskHas('altAz')) {
      this.objectDetailStore.selectedCoordAlt = ''
      this.objectDetailStore.selectedCoordApparentAltAz = ''
      this.objectDetailStore.selectedCoordGeometricAltAz = ''
    }
    if (!this.informationMaskHas('eclipticOfDate')) this.objectDetailStore.selectedCoordEcliptic = ''
    if (!this.informationMaskHas('eclipticJ2000')) this.objectDetailStore.selectedCoordEclipticJ2000 = ''
    if (!this.informationMaskHas('galactic')) this.objectDetailStore.selectedCoordGalactic = ''
    if (!this.informationMaskHas('supergalactic')) this.objectDetailStore.selectedCoordSupergalactic = ''
    if (!this.informationMaskHas('otherCoordinates')) this.objectDetailStore.selectedCoordParallactic = ''
    if (!this.informationMaskHas('hourAngle')) this.objectDetailStore.selectedHourAngle = ''
    if (!this.informationMaskHas('constellation')) this.objectDetailStore.selectedConstellation = ''
    if (!this.informationMaskHas('distance')) this.objectDetailStore.selectedDistance = ''
    if (!this.informationMaskHas('size')) this.objectDetailStore.selectedSize = ''
    if (!this.informationMaskHas('siderealTime')) {
      this.objectDetailStore.selectedMeanSiderealTime = ''
      this.objectDetailStore.selectedApparentSiderealTime = ''
    }
    if (!this.informationMaskHas('riseTransitSet')) {
      this.objectDetailStore.selectedRise = ''
      this.objectDetailStore.selectedSet = ''
      this.objectDetailStore.selectedTransit = ''
    }
    if (!this.informationMaskHas('elongation')) {
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
      this.informationMaskHas(groups.get(field.key) ?? 'extra'))
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
  private applySelectedObject(result: StellariumBridgeResponse, fromRefresh: boolean = false, placement: string = ''): void {
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
      const preserveClosedDetail = !this.infoWindowStore.infoWinVisible && !targetChanged && this.dismissedObjectName === incomingName
      const isNewSelection = targetChanged
      this.objectDetailStore.selectedName = incomingName
      this.objectDetailStore.selectedEnglishName = result.englishName && result.englishName.length > 0 ? result.englishName : ''
      this.objectDetailStore.selectedCatalogId = result.catalogId && result.catalogId.length > 0 ? result.catalogId : ''
      this.objectDetailStore.selectedDetailMediaPath = result.detailMediaPath && result.detailMediaPath.length > 0 ? result.detailMediaPath : ''
      this.objectDetailStore.selectedDetailMediaKind = result.detailMediaKind && result.detailMediaKind.length > 0 ? result.detailMediaKind : ''
      this.objectDetailStore.selectedDetailMediaLabel = result.detailMediaLabel && result.detailMediaLabel.length > 0 ? result.detailMediaLabel : ''
      this.objectDetailStore.selectedDetailModel = result.detailModel
      this.refreshObjectInspectorModelLighting()
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
      this.gyroGuideTargetAlt = hasAlt ? result.altitude as number : Number.NaN
      this.gyroGuideTargetAz = hasAz ? result.azimuth as number : Number.NaN
      // A stationary device may not pass the sensor movement threshold again
      // after a search. Recalculate the edge guide at selection time instead
      // of waiting for the next meaningful orientation delta.
      if (this.gyroStore.gyroscopeEnabled) {
        this.updateGyroTargetGuide(true)
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
        if (!this.gyroStore.gyroscopeEnabled && !this.isObserverPlanetSelection(incomingName)) {
          if (placement === 'center') {
            this.navigateSelectedObjectTo(this.skyWidth / 2, this.skyHeight / 2, 'center')
          }
        }
      }
      this.updateGyroTargetGuide(true)
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
      this.gyroGuideTargetAz = Number.NaN
      this.gyroGuideTargetAlt = Number.NaN
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


  private locationMapWidth(): number {
    if (this.isExpandedLayout) {
      return 292
    }
    return clamp(this.skyWidth * 0.92 - 32, 276, 620)
  }

  private locationMapHeight(): number {
    return this.isExpandedLayout ? 146 : 156
  }

  private setPickerLocation(name: string, latitude: number, longitude: number, altitude: number, status: ResourceStr): void {
    this.locationPickerStore.locationPickerName = name
    this.locationPickerStore.locationPickerLatitude = clamp(latitude, -90, 90)
    this.locationPickerStore.locationPickerLongitude = clamp(longitude, -180, 180)
    this.locationPickerStore.locationPickerAltitude = Math.round(altitude)
    this.locationPickerStore.locationPickerStatus = status
  }

  private updatePickerFromMap(x: number, y: number): void {
    const width = this.locationPickerStore.mapRenderWidth
    const height = this.locationPickerStore.mapRenderHeight
    const latitude = 90 - clamp(y, 0, height) / height * 180
    const longitude = clamp(x, 0, width) / width * 360 - 180
    this.setPickerLocation(I18n.t('custom_location'), latitude, longitude, this.locationPickerStore.locationPickerAltitude, I18n.t('m_map_selected'))
    this.locationStore.locSearchQuery = ''
  }

  private handleLocationMapTouch(event: TouchEvent): boolean {
    const points = event.touches.length > 0 ? event.touches : event.changedTouches
    if (points.length < 1) {
      return false
    }
    const point = points[0]
    if (event.type === TouchType.Down) {
      this.mapTouchStartX = point.x
      this.mapTouchStartY = point.y
      this.mapTouchMoved = false
    } else if (event.type === TouchType.Move) {
      const deltaX = point.x - this.mapTouchStartX
      const deltaY = point.y - this.mapTouchStartY
      if (Math.sqrt(deltaX * deltaX + deltaY * deltaY) > 10) this.mapTouchMoved = true
    } else if (event.type === TouchType.Up) {
      if (!this.mapTouchMoved) {
        this.updatePickerFromMap(point.x, point.y)
        this.applyPickerLocation()
      }
      this.mapTouchMoved = false
    } else if (event.type === TouchType.Cancel) {
      this.mapTouchMoved = false
    }
    // Do not take ownership of a vertical panel scroll. A deliberate stationary
    // tap still chooses the map point, while swiping across the map scrolls the panel.
    return false
  }

  private deviceLocationRequestInProgress: boolean = false

  private async useDeviceLocation(): Promise<void> {
    if (this.deviceLocationRequestInProgress || !this.privacyNativeStartupAllowed ||
      !this.applicationInForeground || !hasCurrentPrivacyConsent()) return
    this.deviceLocationRequestInProgress = true
    hilog.info(0x0000, 'StellariumArkUI', 'useDeviceLocation() called')
    this.locationPickerStore.locationPickerStatus = I18n.t('m_req_location_perm')
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const atManager = abilityAccessCtrl.createAtManager()
      const permissions: Array<Permissions> = [
        'ohos.permission.APPROXIMATELY_LOCATION',
        'ohos.permission.LOCATION'
      ]
      const permissionResult = await atManager.requestPermissionsFromUser(context, permissions)
      if (!this.privacyNativeStartupAllowed || !this.applicationInForeground || !hasCurrentPrivacyConsent()) return
      if (!permissionResult.authResults.some((result: number) => result === 0)) {
        this.locationPickerStore.locationPickerStatus = I18n.t('m_gps_unavailable')
        return
      }
      this.locationPickerStore.locationPickerStatus = I18n.t('m_getting_location')
      const current = await geoLocationManager.getCurrentLocation({
        priority: geoLocationManager.LocationRequestPriority.ACCURACY,
        scenario: geoLocationManager.LocationRequestScenario.DAILY_LIFE_SERVICE,
        maxAccuracy: 2000,
        timeoutMs: 5000
      })
      if (!this.privacyNativeStartupAllowed || !this.applicationInForeground || !hasCurrentPrivacyConsent()) return
      const altitude = Number.isFinite(current.altitude) ? current.altitude : 0
      this.setPickerLocation(I18n.t('m_current_location'), current.latitude, current.longitude, altitude, I18n.t('m_device_loc_synced'))
      this.applyPickerLocation()
      this.locationPickerStore.locationPickMode = 'map'
      this.locationPickerStore.hierContinent = ''
      this.locationPickerStore.hierCountry = ''
      this.locationPickerStore.hierRegion = ''
      this.locationPickerStore.hierCity = ''
    } catch (err) {
      const errMsg: string = err instanceof Error ? err.message : JSON.stringify(err)
      hilog.warn(0x0000, 'StellariumArkUI', 'device location failed: %{public}s', errMsg)
      this.locationPickerStore.locationPickerStatus = I18n.t('m_gps_unavailable')
    } finally {
      this.deviceLocationRequestInProgress = false
    }
  }

  private applyPickerLocation(): void {
    this.setLocation(this.locationPickerStore.locationPickerName, this.locationPickerStore.locationPickerLatitude, this.locationPickerStore.locationPickerLongitude, this.locationPickerStore.locationPickerAltitude)
    // 延迟刷新时区信息（等C++侧location切换完成）
    setTimeout(() => { this.locationPickerStore.loadObserverInfo(true) }, 500)
  }



  private setLocation(name: string, latitude: number, longitude: number, altitude: number, planet: string = 'Earth'): void {
    const targetPlanet = planet.length > 0 ? planet : 'Earth'
    const currentPlanet = this.sessionToolStore.observerPlanet
    // Update picker UI immediately (non-blocking, gives instant feedback)
    this.setPickerLocation(name, latitude, longitude, altitude, I18n.t('m_synced_to_sky'))
    this.sessionToolStore.observerPlanet = targetPlanet
    this.locationText = this.locationPickerStore.locationDisplayName(name) + ' · ' + planetZh(targetPlanet)
    this.coordinateText = this.locationStore.formatDegrees(latitude, 'N', 'S') + ' / ' + this.locationStore.formatDegrees(longitude, 'E', 'W')
    this.altitudeText = altitude.toFixed(0) + ' m'
    this.locationPickerStore.observerTimeZone = targetPlanet === 'Earth' ? approximateTimeZoneDisplay(longitude) : I18n.t('tz_system')
    this.flashHint(I18n.t('i0073').replace('%s', this.locationPickerStore.locationDisplayName(name)))
    if (targetPlanet !== currentPlanet || targetPlanet !== 'Earth') {
      this.callNativeWhenReady('setObserverPlanet', `${targetPlanet}|${latitude}|${longitude}|${altitude}`, (r: StellariumBridgeResponse) => {
        if (r.ok === true) {
          this.refreshState()
          setTimeout(() => { this.locationPickerStore.loadObserverInfo(true) }, 300)
        } else {
          this.sessionToolStore.observerPlanet = currentPlanet
          this.flashHint('切换观测星球失败')
        }
      }, 0, 100, 10)
      return
    }
    // 经纬度是地图选点和层级城市的共同事实源，先写坐标，避免名称查库失败或读回旧位置。
    this.callNativeWhenReady('setLocation', `${name}|${latitude}|${longitude}|${altitude}`, (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.refreshState()
        setTimeout(() => { this.locationPickerStore.loadObserverInfo(true) }, 300)
      } else {
        hilog.info(0x0000, 'StellariumArkUI', 'setLocation failed, fallback to setLocationCoords')
        this.callNativeWhenReady('setLocationCoords', `${latitude},${longitude},${altitude}`, (r2: StellariumBridgeResponse) => {
          if (r2.ok === true) {
            this.refreshState()
            setTimeout(() => { this.locationPickerStore.loadObserverInfo(true) }, 300)
          } else {
            hilog.info(0x0000, 'StellariumArkUI', 'setLocationCoords failed, fallback to setLocationByName')
            this.callNativeWhenReady('setLocationByName', name, (r3: StellariumBridgeResponse) => {
              if (r3.ok === true) {
                this.refreshState()
                setTimeout(() => { this.locationPickerStore.loadObserverInfo(true) }, 300)
              }
            })
          }
        })
      }
    }, 0, 100, 10)
  }

  // ===== 位置搜索（离线数据，按查询分块扫描）=====
  private quickLocationSearchItems(): Array<LocSearchItem> {
    const names: string[] = [
      'Beijing', 'Shanghai', 'Guangzhou', 'Shenzhen', 'Chengdu', 'Hangzhou', 'Wuhan',
      'Xian', 'Nanjing', 'Chongqing', 'Harbin', 'Lhasa', 'Urumqi', 'HongKong', 'Taipei',
      'Tokyo', 'Seoul', 'Singapore', 'NewYork', 'London', 'Sydney', 'Paris', 'Berlin',
      'Moscow', 'Dubai', 'Mumbai', 'Cairo', 'Rio', 'LosAngeles', 'Toronto', 'Mexico',
      'Bangkok', 'Istanbul', 'Amsterdam', 'Stockholm', 'Reykjavik', 'CapeTown',
      'BuenosAires', 'Honolulu'
    ]
    const items: Array<LocSearchItem> = []
    for (const name of names) {
      const preset = getCityPreset(name)
      if (preset === undefined) continue
      const displayName = this.locationPickerStore.locationDisplayName(name)
      items.push({ name: name, displayName: displayName, lat: preset.lat, lon: preset.lon, alt: preset.alt, planet: 'Earth', country: '', region: '' })
    }
    return items
  }


  private matchesLocationSearch(text: string, query: string): boolean {
    const rawQuery = query.trim().toLocaleLowerCase()
    if (!rawQuery) return false
    const rawText = text.toLocaleLowerCase()
    return rawText.includes(rawQuery) ||
      normalizeLocationSearchText(rawText).includes(normalizeLocationSearchText(rawQuery))
  }

  private locationSearchMatchScore(query: string, primaryNames: Array<string>, text: string): number {
    const normalizedQuery = normalizeLocationSearchText(query)
    if (!normalizedQuery) return 0
    let best = 0
    for (const primaryName of primaryNames) {
      const normalizedName = normalizeLocationSearchText(primaryName)
      if (!normalizedName) continue
      if (normalizedName === normalizedQuery) best = Math.max(best, 100)
      else if (normalizedName.startsWith(normalizedQuery)) best = Math.max(best, 85)
      else if (normalizedName.includes(normalizedQuery)) best = Math.max(best, 70)
    }
    if (best > 0) return best
    return normalizeLocationSearchText(text).includes(normalizedQuery) ? 40 : 0
  }


  private locationSearchCountryName(countryCode: string): string {
    if (countryCode === 'TW' || countryCode === 'HK' || countryCode === 'MO') {
      return I18n.isChineseLanguage()
        ? (LOCATION_COUNTRY_NAMES[countryCode]?.zh ?? this.locationPickerStore.translateCountry(countryCode, this.sessionToolStore.observerPlanet))
        : this.locationPickerStore.translateCountry(countryCode, this.sessionToolStore.observerPlanet)
    }
    return this.locationPickerStore.translateCountry(countryCode, this.sessionToolStore.observerPlanet)
  }

  private locationResultContext(item: LocSearchItem): string {
    const parts: Array<string> = []
    const append = (value: string): void => {
      if (value.length > 0 && !parts.includes(value)) parts.push(value)
    }
    if (item.province) append(this.locationPickerStore.translateProvince(item.province))
    else if (item.region) append(this.locationPickerStore.translateProvince(item.region))
    if (item.country) append(this.locationSearchCountryName(item.country))
    return parts.join(' · ')
  }

  private quickLocationSearch(query: string): Array<LocSearchItem> {
    if (!query.trim()) return []
    return this.quickLocationSearchItems()
      .filter((item: LocSearchItem) => item.planet.toLowerCase() === this.sessionToolStore.observerPlanet.toLowerCase())
      .filter((item: LocSearchItem) => this.matchesLocationSearch(
        item.name + ' ' + (item.displayName ?? '') + ' ' + (LOCATION_ZH_NAMES[item.name] ?? ''), query))
      .sort((left: LocSearchItem, right: LocSearchItem) => {
        const leftText = left.name + ' ' + (left.displayName ?? '') + ' ' + (LOCATION_ZH_NAMES[left.name] ?? '')
        const rightText = right.name + ' ' + (right.displayName ?? '') + ' ' + (LOCATION_ZH_NAMES[right.name] ?? '')
        return this.locationSearchMatchScore(query, [left.name, left.displayName ?? '', LOCATION_ZH_NAMES[left.name] ?? ''], leftText) -
          this.locationSearchMatchScore(query, [right.name, right.displayName ?? '', LOCATION_ZH_NAMES[right.name] ?? ''], rightText)
      })
  }

  private searchLocations(query: string): void {
    const q = query.trim()
    const requestId = ++this.locSearchRequestId
    if (this.locationSearchScanTimer >= 0) {
      clearTimeout(this.locationSearchScanTimer)
      this.locationSearchScanTimer = -1
    }
    if (q.length < 1) {
      this.locationStore.locSearchResults = []
      this.locationStore.locSearching = false
      return
    }
    const quickResults = this.quickLocationSearch(q)
    if (quickResults.length > 0) {
      this.locationStore.locSearchResults = quickResults.slice(0, 20)
      this.locationStore.locSearching = false
      return
    }
    this.locationStore.locSearching = true
    this.locationSearchScanQuery = q
    this.locationSearchScanResults = []
    this.locationSearchScanKeys = new Set<string>()
    this.locationSearchScanContinents = Object.keys(LOCATION_HIERARCHY)
    this.locationSearchScanRegions = []
    this.locationSearchScanContinentIndex = 0
    this.locationSearchScanRegionIndex = 0
    this.locationSearchScanCityIndex = 0
    this.locationSearchLastPublishMs = 0
    this.locationStore.locSearchResults = []
    this.locationSearchScanTimer = setTimeout(() => { this.scanLocationSearchChunk(requestId) }, 0)
  }

  private scanLocationSearchChunk(requestId: number): void {
    if (requestId !== this.locSearchRequestId) return
    const startedAt = Date.now()
    let changed = false
    while (this.locationSearchScanContinentIndex < this.locationSearchScanContinents.length && Date.now() - startedAt < 5) {
      const continent = this.locationSearchScanContinents[this.locationSearchScanContinentIndex]
      if (this.locationSearchScanRegions.length === 0) {
        this.locationSearchScanRegions = Object.keys(LOCATION_HIERARCHY[continent])
      }
      if (this.locationSearchScanRegionIndex >= this.locationSearchScanRegions.length) {
        this.locationSearchScanContinentIndex++
        this.locationSearchScanRegions = []
        this.locationSearchScanRegionIndex = 0
        this.locationSearchScanCityIndex = 0
        continue
      }
      const region = this.locationSearchScanRegions[this.locationSearchScanRegionIndex]
      const cities = LOCATION_HIERARCHY[continent][region]
      if (this.locationSearchScanCityIndex >= cities.length) {
        this.locationSearchScanRegionIndex++
        this.locationSearchScanCityIndex = 0
        continue
      }
      const city = cities[this.locationSearchScanCityIndex++]
      if (!this.locationPickerStore.isCurrentObserverPlanet(city, this.sessionToolStore.observerPlanet)) continue
      const chinese = LOCATION_ZH_NAMES[city.n] ?? ''
      const displayName = this.locationPickerStore.locationDisplayName(city.n)
      const countryCode = city.country
      const country = this.locationSearchCountryName(countryCode)
      const province = this.locationPickerStore.translateProvince(city.province ?? '')
      // Search accepts the source name, official Chinese name, and the name
      // rendered for the active language. Display itself remains single-language.
      const sourceCountry = LOCATION_COUNTRY_NAMES[countryCode]
      const text = city.n + ' ' + chinese + ' ' + displayName + ' ' +
        (city.province ?? '') + ' ' + province + ' ' + region + ' ' + country + ' ' +
        (sourceCountry?.zh ?? '') + ' ' + (sourceCountry?.en ?? '') + officialLocationAliases(countryCode)
      const matchScore = this.locationSearchMatchScore(this.locationSearchScanQuery,
        [city.n, chinese, displayName, city.province ?? '', province, region, country], text)
      if (matchScore <= 0) continue
      const item: LocSearchItem = {
        name: city.n,
        displayName: displayName,
        lat: city.la,
        lon: city.lo,
        alt: city.al,
        planet: this.locationPickerStore.locationPlanet(city),
        country: countryCode,
        region: region,
        province: city.province ?? '',
        searchScore: matchScore,
      }
      const key = city.n + '|' + city.la.toFixed(4) + '|' + city.lo.toFixed(4)
      if (this.locationSearchScanKeys.has(key)) continue
      this.locationSearchScanKeys.add(key)
      this.locationSearchScanResults.push(item)
      this.locationSearchScanResults.sort((left: LocSearchItem, right: LocSearchItem) =>
        (right.searchScore ?? 0) - (left.searchScore ?? 0))
      if (this.locationSearchScanResults.length > 20) this.locationSearchScanResults.pop()
      changed = true
    }
    if (requestId !== this.locSearchRequestId) return
    const finished = this.locationSearchScanContinentIndex >= this.locationSearchScanContinents.length
    const now = Date.now()
    if (changed && (finished || now - this.locationSearchLastPublishMs >= 120)) {
      this.locationStore.locSearchResults = this.locationSearchScanResults.slice()
      this.locationSearchLastPublishMs = now
    }
    if (finished) {
      this.locationStore.locSearching = false
      this.locationSearchScanTimer = -1
      return
    }
    this.locationSearchScanTimer = setTimeout(() => { this.scanLocationSearchChunk(requestId) }, 16)
  }

  private selectSearchLocation(item: LocSearchItem): void {
    this.setLocation(item.name, item.lat, item.lon, item.alt, item.planet)
    this.locationStore.locSearchQuery = ''
    this.locationStore.locSearchResults = []
      this.locationPickerStore.locationPickMode = 'map'
  }

  // ===== 时区获取 =====
  // approximateTimeZoneDisplay 与 loadObserverInfo 已随 §14 B2R-2 下沉：
  // 前者迁至 common/derive/labels.ets（纯函数），后者迁至 LocationPickerStore。

  // ===== 已保存位置管理（持久化到 preferences）=====
  private saveCurrentLocation(): void {
    const name = this.locationPickerStore.locationPickerName
    // 检查是否已存在
    const exists = this.locationStore.savedLocations.some((s: SavedLocation) => s.name === name)
    if (exists) {
      this.flashHint(I18n.t('loc_already_saved'))
      return
    }
    const item: SavedLocation = {
      name: name,
      lat: this.locationPickerStore.locationPickerLatitude,
      lon: this.locationPickerStore.locationPickerLongitude,
      alt: this.locationPickerStore.locationPickerAltitude,
      planet: this.sessionToolStore.observerPlanet,
    }
    this.locationStore.savedLocations = [...this.locationStore.savedLocations, item]
    this.persistSavedLocations()
    this.flashHint(I18n.t('loc_saved_success'))
  }

  private deleteSavedLocation(name: string): void {
    this.locationStore.savedLocations = this.locationStore.savedLocations.filter((s: SavedLocation) => s.name !== name)
    this.persistSavedLocations()
  }

  private persistSavedLocations(): void {
    try {
      let prefs = AppStorage.get<Record<string, Object>>('stellariumPrefs')
      if (!prefs) {
        prefs = {} as Record<string, Object>
      }
      prefs['savedLocations'] = this.locationStore.savedLocations
      AppStorage.setOrCreate<Record<string, Object>>('stellariumPrefs', prefs)
    } catch (e) {
      hilog.info(0x0000, 'StellariumArkUI', 'persistSavedLocations error: %{public}s', (e as Error).message ?? '')
    }
  }

  private setObserverPlanet(name: string): void {
    this.callInteractive('setObserverPlanet', name, (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.sessionToolStore.observerPlanet = name
        this.locationPickerStore.hierContinent = ''
        this.locationPickerStore.hierCountry = ''
        this.locationPickerStore.hierRegion = ''
        this.locationPickerStore.hierCity = ''
        this.refreshState()
        this.flashHint('已切换观测星球：' + name)
      } else {
        this.flashHint('切换失败：' + (r.error ?? 'unknown'))
      }
    })
  }

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

  // 虚拟指星笔 —— 手表当陀螺仪（发射端模拟）
  // 手表 IMU(加速度/陀螺仪/方向传感器) 实时算出 alt|az，通过软总线发给大屏；大屏用
  // pointAtSky track=1 每帧平滑跟随。这里用滑块模拟手腕转动当发射端，验证整条链路。
  private watchGyroSend(): void {
    if (!this.sessionToolStore.watchTracking) return
    const now = Date.now()
    if (now - this.watchLastSend < 70) return // 节流，避免拖动时刷爆命令队列
    this.watchLastSend = now
    const alt = this.sessionToolStore.watchAlt
    const az = this.sessionToolStore.watchAz
    this.callNativeWhenReady('pointAtSky', alt + '|' + az + '|1', (r: StellariumBridgeResponse) => {
      if (!r.ok) { this.sessionToolStore.watchResult = '手表指向未响应'; return }
      // 跟踪模式只负责跟随，不刷文本，避免抖动
    })
  }

  private watchGyroStart(): void {
    this.sessionToolStore.watchTracking = true
    this.sessionToolStore.watchResult = '手表指向中：拖动滑块，大屏实时跟随（像陀螺仪追手）'
    this.flashHint(I18n.t('msg_watch_pointing_started'))
    this.watchGyroSend()
  }

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

  private watchGyroStop(): void {
    this.sessionToolStore.watchTracking = false
    this.callNativeWhenReady('pointAtSkyStop', '', (r: StellariumBridgeResponse) => {
      if (!r.ok) { this.sessionToolStore.watchResult = I18n.t('m_lock_failed'); return }
      this.sessionToolStore.watchResult = I18n.t('m_locking_center')
      setTimeout(() => {
        this.callNativeWhenReady('getSelectedObjectInfo', '', (r2: StellariumBridgeResponse) => {
          if (!r2.ok) return
          if (r2.found) {
            const nm = (r2.name !== undefined && r2.name !== null) ? String(r2.name) : I18n.t('m_unknown')
            const tp = (r2.type !== undefined && r2.type !== null) ? String(r2.type) : ''
            this.sessionToolStore.watchResult = I18n.t('m_lock_hit') + ': ' + nm + (tp ? ' (' + I18n.objectType(tp) + ')' : '')
            this.flashHint(I18n.t('m_lock_hit') + ': ' + nm)
          } else {
            this.sessionToolStore.watchResult = I18n.t('m_no_target_dir')
            this.flashHint(I18n.t('m_no_target_dir'))
          }
        })
      }, 400)
    })
  }

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


  private sessionSummary(r: StellariumBridgeResponse): string {
    const locObj = r.location as Record<string, Object>
    const planet = (r.location && locObj['planetName'] !== undefined) ? String(locObj['planetName']) : 'Earth'
    const selection = r.selected ? I18n.format('m_session_selected', [r.selected]) : I18n.t('m_session_unselected')
    return I18n.format('m_session_summary', [(r.fovDeg ?? 0).toFixed(1), planetZh(planet), selection])
  }

  private sessionExport(): void {
    this.callNativeWhenReady('getSessionState', '', (r: StellariumBridgeResponse) => {
      if (!r.ok) { this.sessionToolStore.sessionHint = I18n.t('m_session_export_failed'); return }
      const snap: SessionSnapshot = {
        schemaVersion: 1,
        exportedAt: new Date().toISOString(),
        viewJ2000: r.viewJ2000,
        fovDeg: r.fovDeg,
        jd: r.jd,
        location: r.location,
        selected: r.selected,
        flags: r.flags
      }
      this.sessionToolStore.sessionJson = JSON.stringify(snap, null, '  ')
      this.tools.sessionExportText = this.sessionToolStore.sessionJson
      this.sessionToolStore.sessionExportSig = sessionSignature(r)
      this.sessionToolStore.sessionHint = I18n.t('m_session_exported') + ': ' + this.sessionSummary(r)
      this.copyTextToClipboard(this.sessionToolStore.sessionJson, I18n.t('session_export_copied'))
    })
  }

  private sessionApply(): void {
    const importedJson = this.tools.sessionImportText.trim()
    const json = importedJson.length > 0 ? importedJson : this.sessionToolStore.sessionJson.trim()
    if (!json) { this.sessionToolStore.sessionHint = I18n.t('m_session_export_first'); return }
    this.callNativeWhenReady('applySessionState', json, (r2: StellariumBridgeResponse) => {
      if (!r2.ok) { this.sessionToolStore.sessionHint = I18n.t('m_apply_failed') + ': ' + (r2.error ?? I18n.t('m_unknown')); this.flashHint(I18n.t('m_apply_failed')); return }
      this.sessionToolStore.sessionHint = I18n.t('m_session_applied_syncing')
      this.flashHint(I18n.t('m_session_applied_syncing'))
      // 等一帧让 applySessionState 生效，再导出比对，验证无缝还原
      setTimeout(() => {
        this.callNativeWhenReady('getSessionState', '', (r3: StellariumBridgeResponse) => {
          if (!r3.ok) return
          const sig = sessionSignature(r3)
          if (sig === this.sessionToolStore.sessionExportSig) {
            this.sessionToolStore.sessionHint = I18n.t('m_session_exact')
            this.flashHint(I18n.t('m_session_exact'))
          } else {
            this.sessionToolStore.sessionHint = I18n.t('m_session_applied_done')
            this.flashHint(I18n.t('m_session_applied_done'))
          }
        })
      }, 500)
    })
  }

  private sessionHandoff(): void {
    // 完整形态需华为分布式软总线(Distributed Hardware Kit)：
    //   const dm = distributedHardware.createDeviceManager()
    //   const devs = dm.getAvailableDeviceListSync()          // 同账号设备
    //   continuationManager.startContinuation(...)            // 拉起目标 Ability 并带 want 参数
    // 当前基础 SDK 无这些 kit，故先给出可落地的本地能力说明。
    if (this.canUseDistributed) {
      this.flashHint(I18n.t('msg_continuation_initiated'))
      this.sessionToolStore.sessionHint = I18n.t('m_continuation_migrating')
    } else {
      this.flashHint(I18n.t('m_continuation_basic_sdk'))
      this.sessionToolStore.sessionHint = I18n.t('m_continuation_basic_desc')
    }
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
      this.setLocation(found.n, found.la, found.lo, found.al, this.locationPickerStore.locationPlanet(found))
    }
  }

  private panelLeft(): number {
    // 跟随面板真实位置（含拖动偏移），避免点面板却漏成星图拖拽。
    // 展开态直接复用渲染用的 expandedMainPanelLeft()，保证命中区与实际绘制位置永远一致
    // （历史上两者各算各的，右侧 EDGE_MARGIN 留边导致命中区整体偏移）。
    if (this.isExpandedLayout) {
      return this.expandedMainPanelLeft()
    }
    return this.skyWidth - this.panelWidth + this.panelOffsetX
  }

  private panelRight(): number {
    return this.panelLeft() + this.panelWidth
  }

  private panelTop(): number {
    return this.EDGE_MARGIN + this.panelOffsetY
  }

  private isUiPoint(x: number, y: number): boolean {
    if (this.guideStore.guideState.active) {
      return x >= this.guideCardX() && x <= this.guideCardX() + this.guideCardWidth() &&
        y >= this.guideCardY() && y <= this.guideCardY() + this.guideCardHeight()
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
    if (this.tools.recording && !this.scriptPlaybackVisible() &&
      x >= 16 && x <= Math.max(266, this.skyWidth - 16) &&
      y >= this.EDGE_MARGIN - 8 && y <= this.EDGE_MARGIN + 58) {
      return true
    }
    if (this.isDockPoint(x, y)) {
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
    if (this.isObjectDetailCardPoint(x, y) || this.isObjectActionBarPoint(x, y)) {
      return true
    }
    if (this.isExpandedLayout) {
      // 浮动面板区域（含 30vp 余量，覆盖圆角/边距，杜绝点面板却拖星图）
      if (this.panelVisible) {
        const pl = this.panelLeft()
        const pr = this.panelRight()
        const pt = this.panelTop()
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

    const left = this.panelLeft()
    const top = this.panelTop()
    const right = this.panelRight()
    if (this.isPanelBackPoint(x, y)) {
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
      if (y >= 455 && y <= 505 && x >= 1300 && x <= right) { this.useDeviceLocation(); return true }
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
    this.handleSkyTouch(event)
    } catch (e) {
      hilog.error(0x0000, 'StellariumArkUI', 'handleOverlayTouch crash: ' + (e instanceof Error ? e.message : String(e)))
    }
  }

  private resetSkyTapSequence(): void {
    this.lastSkyTapAt = 0
  }

  private isSkyDoubleTap(x: number, y: number): boolean {
    const now = Date.now()
    const tapInterval = this.lastSkyTapAt > 0 ? now - this.lastSkyTapAt : 0
    const withinTime = this.lastSkyTapAt > 0 && tapInterval <= 800
    const withinDistance = distance(x, y, this.lastSkyTapX, this.lastSkyTapY) <= 28
    if (this.lastSkyTapAt > 0) {
      hilog.info(0x0000, 'StellariumArkUI', 'sky tap interval=' + tapInterval.toString() +
        'ms distance=' + distance(x, y, this.lastSkyTapX, this.lastSkyTapY).toFixed(1) +
        ' double=' + (withinTime && withinDistance).toString())
    }
    if (withinTime && withinDistance) {
      this.resetSkyTapSequence()
      return true
    }
    this.lastSkyTapAt = now
    this.lastSkyTapX = x
    this.lastSkyTapY = y
    return false
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
      this.applySelectedObject(result)
      this.flashHint(result.found === true
        ? I18n.t('i0074').replace('%s', zhNameOf(this.objectDetailStore.selectedName))
        : I18n.t('i0075'))
    })
  }

  private clearSkySelectionFromDoubleTap(x: number, y: number): void {
    const requestSerial = ++this.skySelectionRequestSerial
    this.resetSkyTapSequence()
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

  private handleSkyTap(x: number, y: number): void {
    if (this.tools.angleMeasureEnabled) {
      this.measureAngleAt(x, y)
      return
    }
    if (this.isSkyDoubleTap(x, y)) {
      this.clearSkySelectionFromDoubleTap(x, y)
      return
    }
    this.requestSkySelection(x, y)
  }

  private handleSkyMouse(event: MouseEvent): void {
    const x = event.windowX
    const y = event.windowY
    if (event.action === 0 && event.button === 0) {
      this.mouseSkyPressed = !this.isUiPoint(x, y)
      if (!this.mouseSkyPressed) { this.resetSkyTapSequence() }
      this.mouseSkyMoved = false
      this.mouseSkyStartX = x
      this.mouseSkyStartY = y
      this.mouseSkyLastX = x
      this.mouseSkyLastY = y
      this.mouseSkyLastSampleMs = Date.now()
      if (this.mouseSkyPressed) { this.stopSkyInertia() }
      return
    }
    if (event.action === 2 && this.mouseSkyPressed) {
      const moveDistance = distance(x, y, this.mouseSkyStartX, this.mouseSkyStartY)
      if (moveDistance > 3) {
        this.resetSkyTapSequence()
        if (!this.mouseSkyMoved && this.gyroStore.gyroscopeEnabled) {
          this.stopGyroscope(true)
          this.flashHint('已退出陀螺仪')
        }
        this.mouseSkyMoved = true
        const now = Date.now()
        const dt = Math.max(1, now - this.mouseSkyLastSampleMs)
        const vx = (x - this.mouseSkyLastX) / dt
        const vy = (y - this.mouseSkyLastY) / dt
        this.dragVelocityX = this.dragVelocityX * 0.35 + vx * 0.65
        this.dragVelocityY = this.dragVelocityY * 0.35 + vy * 0.65
        this.callNativeFire('dragView', Math.round(this.mouseSkyLastX).toString() + '|' +
          Math.round(this.mouseSkyLastY).toString() + '|' + Math.round(x).toString() + '|' + Math.round(y).toString())
        this.mouseSkyLastX = x
        this.mouseSkyLastY = y
        this.mouseSkyLastSampleMs = now
      }
      return
    }
    if (event.action === 1 && this.mouseSkyPressed) {
      this.mouseSkyPressed = false
      if (!this.mouseSkyMoved && !this.isUiPoint(x, y)) {
        this.handleSkyTap(x, y)
      } else if (this.mouseSkyMoved) {
        if (Date.now() - this.mouseSkyLastSampleMs > 90) {
          this.dragVelocityX *= 0.35
          this.dragVelocityY *= 0.35
        }
        this.startSkyInertia()
      }
    }
  }

  private handleSkyAxis(event: AxisEvent): void {
    const x = event.windowX
    const y = event.windowY
    if (this.isUiPoint(x, y)) { return }
    const pinchScale = event.getPinchAxisScaleValue()
    if (pinchScale > 0 && Math.abs(pinchScale - 1) > 0.001) {
      this.callNativeFire('zoomBy', pinchScale.toFixed(4) + '|0')
      return
    }
    const horizontal = event.getHorizontalAxisValue()
    const vertical = event.getVerticalAxisValue()
    if (event.scrollStep !== undefined) {
      if (Math.abs(vertical) > 0.001) {
        const scale = vertical > 0 ? 1.12 : 0.89
        this.callNativeFire('zoomBy', scale.toFixed(3) + '|0')
      }
      return
    }
    if (Math.abs(horizontal) > 0.001 || Math.abs(vertical) > 0.001) {
      this.callNativeFire('panBy', (-horizontal * 28).toFixed(2) + '|' +
        (-vertical * 28).toFixed(2) + '|' + Math.round(this.skyWidth).toString() + '|' + Math.round(this.skyHeight).toString())
    }
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
      this.updateGyroTargetGuide(true)
      return
    }
    this.navigateSelectedObjectTo(this.skyWidth / 2, this.skyHeight / 2, 'keyboard-center')
    this.flashHint('已居中')
  }

  private handleSkyKey(event: KeyEvent): boolean {
    if (event.type !== 0) { return false }
    const width = Math.round(this.skyWidth).toString()
    const height = Math.round(this.skyHeight).toString()
    const pan = (x: number, y: number): boolean => {
      this.callNativeFire('panBy', x.toString() + '|' + y.toString() + '|' + width + '|' + height)
      return true
    }
    switch (event.keyCode) {
      case KeyCode.KEYCODE_DPAD_UP: return pan(0, -80)
      case KeyCode.KEYCODE_DPAD_DOWN: return pan(0, 80)
      case KeyCode.KEYCODE_DPAD_LEFT: return pan(-80, 0)
      case KeyCode.KEYCODE_DPAD_RIGHT: return pan(80, 0)
      case KeyCode.KEYCODE_PLUS:
      case KeyCode.KEYCODE_EQUALS: this.zoomStep(0.8); return true
      case KeyCode.KEYCODE_MINUS: this.zoomStep(1.25); return true
      case KeyCode.KEYCODE_SPACE: this.centerSelectedObjectFromKeyboard(); return true
      case KeyCode.KEYCODE_ENTER: this.moveToSelectedObject(); return true
      case KeyCode.KEYCODE_F: this.setPanel('search'); return true
      case KeyCode.KEYCODE_N:
        this.nightModeStore.nightMode = !this.nightModeStore.nightMode
                this.persistNightMode()
        this.callNativeFire('setNightMode', this.nightModeStore.nightMode ? 'true' : 'false')
        return true
      case KeyCode.KEYCODE_ESCAPE:
        if (this.objectMediaStore.objectInspectorModelImmersive) this.setObjectInspectorModelImmersive(false)
        else this.closePanel()
        return true
      default: return false
    }
  }

  // The floating panel sits above the sky touch surface.  Keep its gestures
  // owned by ArkUI so a Slider/Scroll drag can never become a sky pan.
  private stopSkyInertia(resetVelocity: boolean = true): void {
    if (this.skyInertiaTimer !== 0) {
      clearInterval(this.skyInertiaTimer)
      this.skyInertiaTimer = 0
    }
    if (this.nativeSkyInertiaActive) {
      this.callNativeFire('stopPanInertia', '')
      this.nativeSkyInertiaActive = false
    }
    if (resetVelocity) {
      this.dragVelocityX = 0
      this.dragVelocityY = 0
    }
  }

  private dragFollowAlpha(dtMs: number): number {
    // Keep only a light stabilizer. The previous low-pass values made the
    // camera visibly trail behind the finger, especially beside an open menu.
    const base = this.isFoldTabletLayout ? 0.96 : (this.isExpandedLayout ? 0.97 : 0.94)
    return clamp(1 - Math.pow(1 - base, Math.max(1, dtMs) / 16.67), 0.88, 0.995)
  }

  private emitFluidDrag(targetX: number, targetY: number, now: number, sampleVelocity: boolean = true): void {
    const dt = this.dragLastSampleMs > 0 ? Math.max(1, now - this.dragLastSampleMs) : 16
    const rawDx = targetX - this.dragLastRawX
    const rawDy = targetY - this.dragLastRawY
    // Physical Pads have a large, high-density canvas. A small gain keeps the
    // sky responsive without changing the geometry of the native renderer.
    const gain = this.isExpandedLayout ? 1.35 : (this.isFoldHoverLayout ? 1.34 : 1.36)
    if (sampleVelocity && this.dragLastSampleMs > 0 && dt >= 8 && dt <= 220) {
      const vx = rawDx * gain / dt
      const vy = rawDy * gain / dt
      this.dragVelocityX = this.dragVelocityX * 0.35 + vx * 0.65
      this.dragVelocityY = this.dragVelocityY * 0.35 + vy * 0.65
      this.dragVelocitySampleValid = true
    }
    this.dragLastRawX = targetX
    this.dragLastRawY = targetY
    this.dragLastSampleMs = now

    const alpha = this.dragFollowAlpha(dt)
    const desiredX = this.dragFilteredX + rawDx * gain
    const desiredY = this.dragFilteredY + rawDy * gain
    const nextX = this.dragFilteredX + (desiredX - this.dragFilteredX) * alpha
    const nextY = this.dragFilteredY + (desiredY - this.dragFilteredY) * alpha
    if (Math.abs(nextX - this.dragFilteredX) < 0.25 && Math.abs(nextY - this.dragFilteredY) < 0.25) {
      return
    }
    this.callNativeFire('dragView',
      Math.round(this.dragFilteredX).toString() + '|' +
      Math.round(this.dragFilteredY).toString() + '|' +
      Math.round(nextX).toString() + '|' +
      Math.round(nextY).toString())
    this.dragFilteredX = nextX
    this.dragFilteredY = nextY
    this.touchLastX = nextX
    this.touchLastY = nextY
  }

  private startSkyInertia(): void {
    // Do not discard the velocity sampled from the gesture that just ended.
    this.stopSkyInertia(false)
    const initialSpeed = Math.sqrt(this.dragVelocityX * this.dragVelocityX + this.dragVelocityY * this.dragVelocityY)
    if (initialSpeed < 0.05 || !this.dragVelocitySampleValid || this.pinchActive) {
      return
    }
    this.nativeSkyInertiaActive = true
    this.callNativeFire('startPanInertia',
      this.dragVelocityX.toFixed(4) + '|' + this.dragVelocityY.toFixed(4))
  }

  private handleSkyTouch(event: TouchEvent): void {
    const points = event.touches.length > 0 ? event.touches : event.changedTouches
    if (points.length === 0) {
      return
    }

    if (event.type === TouchType.Down) {
      this.stopSkyInertia()
      const allowTouchFeedback = !this.panelVisible
      const downX = touchWindowX(points[0])
      const downY = touchWindowY(points[0])
      // Panel header drag detection (before isUiPoint sidebar check)
      if (this.panelVisible) {
        const pl = this.panelLeft()
        const pr = this.panelRight()
        const pt = this.panelTop()
        if (downX >= pl && downX <= pr && downY >= pt && downY <= pt + 48) {
          this.panelDragging = true
          this.panelDragStartX = downX
          this.panelDragStartY = downY
          this.panelDragStartOffsetX = this.panelOffsetX
          this.panelDragStartOffsetY = this.panelOffsetY
          return
        }
      }
      // 左侧非手势缩放按钮（+放大 / −缩小）：与右上角快捷区同理，XComponent 吞掉
      // ArkUI onClick，必须在 Down 上按坐标分派，否则点击会穿到星图变成 selectAt。
      const zoomHit = this.skyZoomButtonAt(downX, downY)
      if (zoomHit.length > 0) {
        this.resetSkyTapSequence()
        this.touchStartedOnUi = true
        this.skyTouchFeedback = false
        this.skyTouchActive = false
        if (zoomHit === 'in') {
          hilog.info(0x0000, 'StellariumArkUI', '[DIAG] sky zoom in via handleSkyTouch')
          this.zoomStep(0.8)
        } else {
          hilog.info(0x0000, 'StellariumArkUI', '[DIAG] sky zoom out via handleSkyTouch')
          this.zoomStep(1.25)
        }
        return
      }
      if (this.isDockPoint(downX, downY)) {
        this.resetSkyTapSequence()
        this.dockTouchActive = true
        this.touchStartedOnUi = true
        this.skyTouchFeedback = false
        this.skyTouchActive = false
        return
      }
      if (this.isUiPoint(downX, downY)) {
        this.resetSkyTapSequence()
        this.touchStartedOnUi = true
        // A UI touch must never inherit sky-drag ownership. This branch used to
        // set only touchStartedOnUi, unlike the dock branch below which also
        // clears the drag state: a gesture that began on the sky and lifted over
        // a panel left skyTouchActive set, so every later swipe *inside the panel*
        // cleared the "!skyTouchActive" gate in the move handler and panned the
        // star map along with the list.
        this.skyTouchFeedback = false
        this.skyTouchActive = false
        this.skyDragging = false
        this.nativeDragActive = false
        // 手机端右上角快捷按钮（陀螺仪/音频）：XComponent 同样吞掉了 onClick，
        // 需要坐标级分派，与上方 tablet rail workaround 同理。
        if (!this.isExpandedLayout && this.isCompactTopQuickPoint(downX, downY)) {
          const qx = this.compactTopQuickX()
          const qy = compactTopQuickY()
          // 陀螺仪按钮（上方的 44x44，圆心约 qx+22, qy+22）
          if (downX >= qx && downX <= qx + 44 && downY >= qy && downY <= qy + 44) {
            hilog.info(0x0000, 'StellariumArkUI', '[DIAG] gyro tap via handleSkyTouch')
            this.resetPanelIdle()
            this.toggleGyroscope(!this.gyroStore.gyroscopeEnabled)
            return
          }
          // 音频按钮（下方的 44x44，间距 10vp，圆心约 qx+22, qy+54+22）
          if (downX >= qx && downX <= qx + 44 && downY >= qy + 54 && downY <= qy + 54 + 44) {
            hilog.info(0x0000, 'StellariumArkUI', '[DIAG] audio tap via handleSkyTouch')
            this.resetPanelIdle()
            this.toggleMusic()
            this.flashHint(this.audioStore.musicEnabled ? I18n.t('music_on_hint') : I18n.t('music_off_hint'))
            return
          }
        }
        return
      }
      this.skyTouchActive = true
      this.skyDragging = true
      this.cancelSelectedObjectUiChange()
      this.callNativeFire('beginSkyGesture')
      this.pauseDetailRefreshForSkyDrag()
      this.touchStartX = downX
      this.touchStartY = downY
      this.touchLastX = this.touchStartX
      this.touchLastY = this.touchStartY
      this.touchMoved = false
        this.pinchActive = false
        this.callNativeFire('endPinch')
        this.nativeDragActive = false
      this.lastDragCommandMs = 0
      this.dragFilteredX = downX
      this.dragFilteredY = downY
      this.dragLastRawX = downX
      this.dragLastRawY = downY
      this.dragLastSampleMs = Date.now()
      this.dragVelocityX = 0
      this.dragVelocityY = 0
      this.dragVelocitySampleValid = false
      this.dragLogCount = 0
      this.skyTouchFeedback = allowTouchFeedback
      this.skyTouchX = downX
      this.skyTouchY = downY
      this.skyTouchFeedbackMulti = allowTouchFeedback && points.length >= 2
      hilog.info(0x0000, 'StellariumArkUI', 'sky touch down at ' + Math.round(this.touchStartX).toString() + ',' + Math.round(this.touchStartY).toString() + ' sky=' + this.skyWidth.toString() + 'x' + this.skyHeight.toString())
      if (points.length >= 2) {
        this.resetSkyTapSequence()
        this.skyTouchX2 = touchWindowX(points[1])
        this.skyTouchY2 = touchWindowY(points[1])
        this.pinchCenterX = (touchWindowX(points[0]) + this.skyTouchX2) / 2
        this.pinchCenterY = (touchWindowY(points[0]) + this.skyTouchY2) / 2
        this.pinchStartDistance = distance(
          touchWindowX(points[0]), touchWindowY(points[0]),
          touchWindowX(points[1]), touchWindowY(points[1]))
        this.pinchStartFov = clamp(this.fovSliderValue > 0 ? this.fovSliderValue : 60, 4, 180)
        this.pinchLastScale = 1
        this.pinchLastNativePushMs = Date.now()
        this.pinchNativePushPending = false
        this.pinchActive = true
        this.callNativeFire('zoomBy', '1|1|' + this.pinchCenterX.toFixed(2) + '|' +
          this.pinchCenterY.toFixed(2) + '|' + Math.round(this.skyWidth).toString() + '|' +
          Math.round(this.skyHeight).toString())
      }
      return
    }

    if ((event.type === TouchType.Up || event.type === TouchType.Cancel) && this.dockTouchActive) {
      const x = touchWindowX(points[0])
      const y = touchWindowY(points[0])
      this.dockTouchActive = false
      this.touchStartedOnUi = false
      if (event.type === TouchType.Up) {
        const dockItem = this.dockActionAt(x, y)
        if (dockItem !== null) { this.activateDockAction(dockItem) }
      }
      return
    }
    if (!this.skyTouchActive) {
      return
    }

    if (event.type === TouchType.Move) {
      const x = touchWindowX(points[0])
      const y = touchWindowY(points[0])
      if (this.skyTouchFeedback) {
        this.skyTouchX = x
        this.skyTouchY = y
      }
      if (points.length >= 2) {
        this.skyTouchFeedbackMulti = this.skyTouchFeedback
        this.skyTouchX2 = touchWindowX(points[1])
        this.skyTouchY2 = touchWindowY(points[1])
        this.pinchCenterX = (x + this.skyTouchX2) / 2
        this.pinchCenterY = (y + this.skyTouchY2) / 2
        this.nativeDragActive = false
        this.stopSkyInertia()
        const currentDistance = distance(
          x, y, touchWindowX(points[1]), touchWindowY(points[1]))
        if (!this.pinchActive || this.pinchStartDistance <= 1) {
          this.pinchStartDistance = currentDistance
          this.pinchStartFov = clamp(this.fovSliderValue > 0 ? this.fovSliderValue : 60, 4, 180)
          this.pinchActive = true
          this.pinchLastScale = 1
          this.pinchLastNativePushMs = Date.now()
          this.pinchNativePushPending = false
          this.callNativeFire('zoomBy', '1|1|' + this.pinchCenterX.toFixed(2) + '|' +
            this.pinchCenterY.toFixed(2) + '|' + Math.round(this.skyWidth).toString() + '|' +
            Math.round(this.skyHeight).toString())
        } else {
          const scale = currentDistance / this.pinchStartDistance
          this.pinchLastScale = scale
          const estimatedFov = clamp(this.pinchStartFov / Math.max(0.25, scale), 4, 180)
          this.fovSliderValue = estimatedFov
          this.currentFovText = estimatedFov.toFixed(1) + '°'
          this.pinchNativePushPending = true
          const now = Date.now()
          if (now - this.pinchLastNativePushMs >= 16) {
            this.callNativeFire('zoomBy', scale.toString() + '|0|' + this.pinchCenterX.toFixed(2) + '|' +
              this.pinchCenterY.toFixed(2) + '|' + Math.round(this.skyWidth).toString() + '|' +
              Math.round(this.skyHeight).toString())
            this.pinchLastNativePushMs = now
            this.pinchNativePushPending = false
          }
          // 缩放时弹小蓝胶囊实时显示 FOV（节流 150ms，避免桥接风暴）
          const nowMs = Date.now()
          if (nowMs - this.lastFovHintMs >= 150) {
            this.lastFovHintMs = nowMs
            this.callInteractive('getFieldOfView', '', (r: StellariumBridgeResponse) => {
              if (r.ok === true && r.fov !== undefined) {
                const fovDeg = r.fov as number
                this.currentFovText = fovDeg.toFixed(1) + '°'
              }
            })
          }
        }
        this.touchMoved = true
        return
      }
      this.skyTouchFeedbackMulti = false

      // Panel drag handling
      if (this.panelDragging) {
        this.touchStartedOnUi = false
        this.panelOffsetX = this.panelDragStartOffsetX + (x - this.panelDragStartX)
        this.panelOffsetY = this.panelDragStartOffsetY + (y - this.panelDragStartY)
        return
      }

      const totalMove = distance(x, y, this.touchStartX, this.touchStartY)
      // 阈值放宽到 16vp:uitest/mock 注入的触摸常有几像素位移,
      // 4vp 会把"轻点"误判成"拖动",导致 selectAt 不触发。
      if (totalMove > 16) {
        this.resetSkyTapSequence()
        this.cancelSelectedObjectUiChange()
        // Manual panning and sensor tracking must never drive the native
        // camera together. Leave gyro mode on the first real sky drag, while
        // keeping taps and pinch zoom available without changing its state.
        if (!this.touchMoved && this.gyroStore.gyroscopeEnabled) {
          this.stopGyroscope(true)
          this.flashHint('已退出陀螺仪')
        }
        this.touchMoved = true
      }
      // Ownership is decided on Down: only a gesture that actually started on the
      // sky may pan it. Relying on skyTouchActive alone let a stale flag drag the
      // sky from inside a panel, so the origin is now part of the condition.
      if (this.touchMoved && !this.touchStartedOnUi) {
        this.nativeDragActive = true
        const now = Date.now()
        if (now - this.lastDragCommandMs >= 16) {
          if (this.dragLogCount < 5) {
            hilog.info(0x0000, 'StellariumArkUI', 'dragView dx=' + Math.round(x - this.touchLastX).toString() + ' dy=' + Math.round(y - this.touchLastY).toString() + ' throttle=' + (now - this.lastDragCommandMs).toString() + 'ms')
            this.dragLogCount += 1
          }
          this.emitFluidDrag(x, y, now)
          this.lastDragCommandMs = now
        }
      }
      return
    }

    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      const x = touchWindowX(points[0])
      const y = touchWindowY(points[0])
      const endedOnUi = this.isUiPoint(x, y)
      const recordingViewChanged = this.touchMoved || this.pinchActive
      // End panel drag
      if (this.panelDragging) {
        this.panelDragging = false
        this.scheduleSelectedObjectForUiChange(160)
        return
      }
      // Gesture ownership is decided on Down. A drag that started on the sky
      // must still finish as a sky gesture even when the finger crosses the
      // floating object card before it lifts; otherwise the early return leaves
      // skyDragging set and permanently pauses detail refresh/inertia.
      if (this.touchStartedOnUi) {
        if (this.dockTouchActive) {
          this.dockTouchActive = false
          if (event.type === TouchType.Up) {
            const dockItem = this.dockActionAt(x, y)
            if (dockItem !== null) {
              this.activateDockAction(dockItem)
            }
          }
        }
        this.touchStartedOnUi = false
        // Clear the same drag state the sky branch clears on lift-off: this early
        // return used to leave it behind for the next gesture to inherit.
        this.nativeDragActive = false
        this.skyTouchActive = false
        this.skyTouchFeedback = false
        this.skyDragging = false
        return
      }
      if (this.nativeDragActive && event.type === TouchType.Up) {
        this.emitFluidDrag(x, y, Date.now(), false)
        this.startSkyInertia()
      } else if (event.type === TouchType.Cancel) {
        this.stopSkyInertia()
      } else if (!this.touchMoved && !this.pinchActive && !endedOnUi && Date.now() - this.lastInfoWinCloseMs > 320) {
        hilog.info(0x0000, 'StellariumArkUI', 'selectAt payload: ' +
          Math.round(this.touchStartX).toString() + '|' + Math.round(this.touchStartY).toString() + '|' +
          Math.round(this.skyWidth).toString() + '|' + Math.round(this.skyHeight).toString())
        this.handleSkyTap(this.touchStartX, this.touchStartY)
      }
      if (this.pinchActive) {
        if (this.pinchNativePushPending) {
          this.callNativeFire('zoomBy', this.pinchLastScale.toString() + '|0|' +
            this.pinchCenterX.toFixed(2) + '|' + this.pinchCenterY.toFixed(2) + '|' +
            Math.round(this.skyWidth).toString() + '|' + Math.round(this.skyHeight).toString())
        }
        this.callNativeFire('endPinch')
        this.scheduleSkyTextureStatusCheck()
      }
      this.pinchActive = false
      this.pinchNativePushPending = false
      this.nativeDragActive = false
      this.skyTouchActive = false
      this.skyTouchFeedback = false
      this.skyTouchFeedbackMulti = false
      this.skyDragging = false
      if (event.type === TouchType.Cancel) { this.resetSkyTapSequence() }
      this.resumeDetailRefreshAfterSkyDrag()
      if (event.type === TouchType.Up && recordingViewChanged) {
        this.scheduleRecordingViewCheckpoint(this.nativeSkyInertiaActive ? 1100 : 180)
      }
    }
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

      if (this.scriptPlaybackVisible()) {
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
            cardHeight: this.guideCardHeight(),
            cardX: this.guideCardX(),
            cardY: this.guideCardY(),
            onSkyTouch: (event: TouchEvent) => { this.handleSkyTouch(event) },
            onControlDragTouch: (event: TouchEvent) => { this.handleScriptControlDragTouch(event) },
            onAction: (action: string) => { this.executeGuideRequest('guideAction', action) }
          })
        } else {
          ScriptFocusShell({
            scriptStore: this.scriptStore,
            playbackVisible: this.scriptPlaybackVisible(),
            compact: this.scriptControlCompact(),
            displayName: scriptZh(this.scriptStore.scriptId.length > 0 ? this.scriptStore.scriptId : (this.scriptStore.scriptLaunchingName.length > 0 ? this.scriptStore.scriptLaunchingName : this.scriptStore.replayName)),
            hasCaptions: this.visibleScriptCaptions().length > 0,
            captionText: this.visibleScriptCaptionText(),
            waitText: this.scriptWaitDisplayText(),
            rateText: (this.scriptStore.replaying ? this.scriptStore.replayRate : this.scriptStore.scriptRate).toFixed((this.scriptStore.replaying ? this.scriptStore.replayRate : this.scriptStore.scriptRate) < 1 ? 2 : 1) + 'x',
            keyButtonWidth: this.scriptKeyButtonWidth(),
            controlWidth: this.scriptControlWidth(),
            controlHeight: this.scriptControlHeight(),
            controlX: this.scriptControlX(),
            controlY: this.scriptControlY(),
            onSkyTouch: (event: TouchEvent) => { this.handleSkyTouch(event) },
            onControlDragTouch: (event: TouchEvent) => { this.handleScriptControlDragTouch(event) },
            onContinue: () => { this.continueNativeScript() },
            onChangeRate: (delta: number) => { this.changePlaybackRate(delta) },
            onToggleReplayPause: () => { this.toggleReplayPause() },
            onStop: () => { this.stopScriptPlayback() },
            onSendKey: (k: string) => { this.sendScriptKey(k) }
          })
        }
      }
      if (!this.scriptPlaybackVisible() && this.tools.recording && !this.tools.recordingUiExpanded) {
        RecordingFocusShell({ onSkyTouch: (event: TouchEvent) => { this.handleSkyTouch(event) } })
      }
      if (!this.scriptPlaybackVisible() && !(this.tools.recording && !this.tools.recordingUiExpanded) && !this.polarScopeStore.polarScopeVisible) {
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
                liveInfoVisible: this.selectedLiveInfoVisible(),
                contentOpacity: this.objectDetailContentOpacity,
                contentTranslateX: this.objectDetailContentTranslateX,
                cardWidth: this.bottomCardWidth(),
                cardHeight: this.bottomCardHeight(),
                viewLock: this.viewSettingsStore.viewLock,
                speechStatus: this.guideStore.speechStatus,
                inObservingList: this.obsListStore.observingList.includes(this.objectDetailStore.selectedName),
                iconName: this.objectInspectorIcon(),
                distanceText: this.objectDistanceNoticeText(),
                distanceSummaryText: this.objectDistanceSummary(),
                imageHeight: this.objectInspectorImageHeight(),
                inlineModelSize: this.objectInspectorInlineModelSize(),
                modelReady: this.objectInspectorModelReady(),
                modelRendering: this.objectInspectorModelRendering,
                hasModelTexture: this.objectInspectorModelTexturePixels !== undefined,
                modelNotice: this.objectInspectorModelNotice(),
                warmupText: this.objectInspectorMediaWarmupText(),
                fallbackKind: this.objectInspectorFallbackVisualKind(),
                starColor: this.objectInspectorStarColor(),
                satelliteVisible: this.selectedObjectIsArtificialSatellite(),
                tleEpoch: this.selectedSatelliteTleEpoch(),
                accent: this.nmAccent(),
                cultureVisible: this.selectedObjectIsConstellation(),
                textColor: this.nmText(),
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
                onSkyTouch: (event: TouchEvent) => { this.handleSkyTouch(event) },
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
                onModelExpand: () => { this.setObjectInspectorModelImmersive(true) },
                onModelTouch: (event: TouchEvent) => { this.handleObjectInspectorModelTouch(event) },
                onCenter: () => { this.moveToSelectedObject() },
                onToggleLock: () => { this.toggleViewLock() },
                onToggleObserving: () => { this.toggleSelectedObservingList() },
                onRefresh: () => { this.refreshSelectedObject(); this.refreshState() },
                onReselect: () => { this.triggerAction('actionGoto_ReSelect_Last_Selected_Object'); this.refreshSelectedObject() },
                onSpeak: () => { this.speakSelectedObject() }
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
                dockWidth: this.dockWidthPixels(),
                dockLeft: this.dockLeft(),
                dockTop: this.dockTop(),
                expandedDockWidth: this.expandedDockWidth(),
                expandedDockLeft: this.expandedDockLeft(),
                gyroPanelLeft: this.EDGE_MARGIN + 64,
                gyroPanelTop: this.railTop() + 120,
                infoWinVisible: this.infoWindowStore.infoWinVisible,
                bottomCardIndex: this.objectDetailStore.bottomCardIndex,
                liveInfoVisible: this.selectedLiveInfoVisible(),
                contentOpacity: this.objectDetailContentOpacity,
                contentTranslateX: this.objectDetailContentTranslateX,
                cardWidth: this.bottomCardWidth(),
                cardHeight: this.bottomCardHeight(),
                viewLock: this.viewSettingsStore.viewLock,
                speechStatus: this.guideStore.speechStatus,
                inObservingList: this.obsListStore.observingList.includes(this.objectDetailStore.selectedName),
                iconName: this.objectInspectorIcon(),
                distanceText: this.objectDistanceNoticeText(),
                distanceSummaryText: this.objectDistanceSummary(),
                imageHeight: this.objectInspectorImageHeight(),
                inlineModelSize: this.objectInspectorInlineModelSize(),
                modelReady: this.objectInspectorModelReady(),
                modelRendering: this.objectInspectorModelRendering,
                hasModelTexture: this.objectInspectorModelTexturePixels !== undefined,
                modelNotice: this.objectInspectorModelNotice(),
                warmupText: this.objectInspectorMediaWarmupText(),
                fallbackKind: this.objectInspectorFallbackVisualKind(),
                starColor: this.objectInspectorStarColor(),
                satelliteVisible: this.selectedObjectIsArtificialSatellite(),
                tleEpoch: this.selectedSatelliteTleEpoch(),
                accent: this.nmAccent(),
                cultureVisible: this.selectedObjectIsConstellation(),
                textColor: this.nmText(),
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
                onSkyTouch: (event: TouchEvent) => { this.handleSkyTouch(event) },
                onDockTouch: (event: TouchEvent) => { this.handleDockTouch(event) },
                onDockTap: (item: ShellAction) => { this.activateDockAction(item) },
                onPanelTouch: (event: TouchEvent) => { this.notePanelTouch(event) },
                onOpenTime: () => { this.setPanel('time') },
                onZoomIn: () => { this.zoomStep(0.8) },
                onZoomOut: () => { this.zoomStep(1.25) },
                fovText: this.currentFovText,
                chromeRowY: this.chromeRowY(),
                chromeRowWidth: this.chromeRowWidth(),
                chromeRowPosXLeft: this.chromeRowPosXLeft(),
                chromeRowPosXRight: this.chromeRowPosXRight(),
                chromeZoomHorizontal: this.chromeZoomHorizontal(),
                onFlashHint: (text: string) => { this.flashHint(text) },
                onCalibrate: () => { this.calibrateGyroscope() },
                onToggleGyroscope: (enabled: boolean) => { this.toggleGyroscope(enabled) },
                resolve: (key: string) => this.selectedDisplayValue(key),
                nameOf: (name: string) => zhNameOf(name),
                typeOf: (type: string) => zhType(type),
                onDragTouch: (event: TouchEvent) => { this.handleObjectInspectorDragTouch(event) },
                onDismiss: () => { this.dismissObjectInspector() },
                onSelectTab: (index: number) => { this.selectObjectDetailTab(index) },
                onLoadPasses: () => { this.objectDetailStore.loadSelectedSatellitePasses() },
                onMediaOpen: () => { this.openObjectInspectorMediaPreview() },
                onMediaRetry: () => { this.retryObjectInspectorMedia() },
                onModelExpand: () => { this.setObjectInspectorModelImmersive(true) },
                onModelTouch: (event: TouchEvent) => { this.handleObjectInspectorModelTouch(event) },
                onCenter: () => { this.moveToSelectedObject() },
                onToggleLock: () => { this.toggleViewLock() },
                onToggleObserving: () => { this.toggleSelectedObservingList() },
                onRefresh: () => { this.refreshSelectedObject(); this.refreshState() },
                onReselect: () => { this.triggerAction('actionGoto_ReSelect_Last_Selected_Object'); this.refreshSelectedObject() },
                onSpeak: () => { this.speakSelectedObject() }
              })
              if (this.panelVisible) {
                Stack({ alignContent: Alignment.TopStart }) { this.floatingPanel() }
                  .width(this.panelWidth)
                  .height(this.panelMaxHeight)
                  .position({ x: this.expandedMainPanelLeft(), y: this.panelTop() })
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
                dockWidth: this.dockWidthPixels(),
                dockLeft: this.dockLeft(),
                dockTop: this.dockTop(),
                musicEnabled: this.audioStore.musicEnabled,
                compactQuickPressed: this.compactQuickPressed,
                quickX: this.compactTopQuickX(),
                quickY: compactTopQuickY(),
                infoWinVisible: this.infoWindowStore.infoWinVisible,
                bottomCardIndex: this.objectDetailStore.bottomCardIndex,
                liveInfoVisible: this.selectedLiveInfoVisible(),
                contentOpacity: this.objectDetailContentOpacity,
                contentTranslateX: this.objectDetailContentTranslateX,
                cardWidth: this.bottomCardWidth(),
                cardHeight: this.bottomCardHeight(),
                viewLock: this.viewSettingsStore.viewLock,
                speechStatus: this.guideStore.speechStatus,
                inObservingList: this.obsListStore.observingList.includes(this.objectDetailStore.selectedName),
                iconName: this.objectInspectorIcon(),
                distanceText: this.objectDistanceNoticeText(),
                distanceSummaryText: this.objectDistanceSummary(),
                imageHeight: this.objectInspectorImageHeight(),
                inlineModelSize: this.objectInspectorInlineModelSize(),
                modelReady: this.objectInspectorModelReady(),
                modelRendering: this.objectInspectorModelRendering,
                hasModelTexture: this.objectInspectorModelTexturePixels !== undefined,
                modelNotice: this.objectInspectorModelNotice(),
                warmupText: this.objectInspectorMediaWarmupText(),
                fallbackKind: this.objectInspectorFallbackVisualKind(),
                starColor: this.objectInspectorStarColor(),
                satelliteVisible: this.selectedObjectIsArtificialSatellite(),
                tleEpoch: this.selectedSatelliteTleEpoch(),
                accent: this.nmAccent(),
                cultureVisible: this.selectedObjectIsConstellation(),
                textColor: this.nmText(),
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
                onSkyTouch: (event: TouchEvent) => { this.handleSkyTouch(event) },
                onDockTouch: (event: TouchEvent) => { this.handleDockTouch(event) },
                onDockTap: (item: ShellAction) => { this.activateDockAction(item) },
                onPanelTouch: (event: TouchEvent) => { this.notePanelTouch(event) },
                onOpenTime: () => { this.setPanel('time') },
                onZoomIn: () => { this.zoomStep(0.8) },
                onZoomOut: () => { this.zoomStep(1.25) },
                fovText: this.currentFovText,
                chromeRowY: this.chromeRowY(),
                chromeRowWidth: this.chromeRowWidth(),
                chromeRowPosXLeft: this.chromeRowPosXLeft(),
                chromeRowPosXRight: this.chromeRowPosXRight(),
                chromeZoomHorizontal: this.chromeZoomHorizontal(),
                onGyro: () => {
                  hilog.info(0x0000, 'StellariumArkUI', '[DIAG] gyro button CLICKED gyroscopeEnabled=%{public}s', this.gyroStore.gyroscopeEnabled.toString())
                  this.resetPanelIdle()
                  this.toggleGyroscope(!this.gyroStore.gyroscopeEnabled)
                },
                onAudio: () => {
                  hilog.info(0x0000, 'StellariumArkUI', '[DIAG] audio button CLICKED musicEnabled=%{public}s', this.audioStore.musicEnabled.toString())
                  this.resetPanelIdle()
                  this.toggleMusic()
                  this.flashHint(this.audioStore.musicEnabled ? I18n.t('music_on_hint') : I18n.t('music_off_hint'))
                },
                onCompactTopQuickTouch: (event: TouchEvent) => { this.handleCompactTopQuickTouch(event) },
                onFlashHint: (text: string) => { this.flashHint(text) },
                onCalibrate: () => { this.calibrateGyroscope() },
                onToggleGyroscope: (enabled: boolean) => { this.toggleGyroscope(enabled) },
                resolve: (key: string) => this.selectedDisplayValue(key),
                nameOf: (name: string) => zhNameOf(name),
                typeOf: (type: string) => zhType(type),
                onDragTouch: (event: TouchEvent) => { this.handleObjectInspectorDragTouch(event) },
                onDismiss: () => { this.dismissObjectInspector() },
                onSelectTab: (index: number) => { this.selectObjectDetailTab(index) },
                onLoadPasses: () => { this.objectDetailStore.loadSelectedSatellitePasses() },
                onMediaOpen: () => { this.openObjectInspectorMediaPreview() },
                onMediaRetry: () => { this.retryObjectInspectorMedia() },
                onModelExpand: () => { this.setObjectInspectorModelImmersive(true) },
                onModelTouch: (event: TouchEvent) => { this.handleObjectInspectorModelTouch(event) },
                onCenter: () => { this.moveToSelectedObject() },
                onToggleLock: () => { this.toggleViewLock() },
                onToggleObserving: () => { this.toggleSelectedObservingList() },
                onRefresh: () => { this.refreshSelectedObject(); this.refreshState() },
                onReselect: () => { this.triggerAction('actionGoto_ReSelect_Last_Selected_Object'); this.refreshSelectedObject() },
                onSpeak: () => { this.speakSelectedObject() }
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
            .width(this.dockWidthPixels())
            .height(this.isExpandedLayout ? 62 : 82)
            .position({ x: this.dockLeft(), y: this.dockTop() })
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
      if (!this.scriptPlaybackVisible() && this.tools.recording) {
        RecordingControlBar({
          store: this.tools, recordCount: this.scriptStore.recordCount, skyWidth: this.skyWidth, safeTop: this.scriptControlSafeTop(),
          onToggleUi: () => { this.toggleRecordingUi() },
          onTogglePause: () => { this.toggleRecordingPause() },
          onStop: () => { this.stopRecording() }
        })
      }
      if (!this.scriptPlaybackVisible() && (!this.tools.recording || this.tools.recordingUiExpanded)) {
        if (this.polarScopeStore.polarScopeVisible) {
          PolarScopeOverlay({
            polarScopeStore: this.polarScopeStore,
            controlWidth: this.polarScopeControlWidth(),
            topInset: this.polarScopeTopInset(),
            footerHeight: this.polarScopeFooterHeight(),
            skyWidth: this.skyWidth,
            skyHeight: this.skyHeight,
            isExpandedLayout: this.isExpandedLayout,
            onSkyTouch: (event: TouchEvent) => { this.handleSkyTouch(event) },
            onRecenter: () => { this.recenterPolarScope() },
            onClose: () => { this.closePolarScope() },
            onHorizontalFlipChange: (value: boolean) => { this.setPolarScopeHorizontalFlip(value) },
            onVerticalFlipChange: (value: boolean) => { this.setPolarScopeVerticalFlip(value) }
          })
        }
        if (this.skyCultureViewStore.artPreviewOpen) {
          SkyCultureArtPreviewOverlay({
            skyCultureViewStore: this.skyCultureViewStore,
            textColor: this.nmText(),
            subColor: this.nmSub(),
            accentColor: this.nmAccent(),
            bgColor: this.nmBg(),
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
            noticeText: this.objectInspectorModelNotice(),
            topInset: this.mediaPreviewTopInset(),
            onCloseOverlay: () => { this.setObjectInspectorModelImmersive(false) },
            onResetView: () => { this.resetObjectInspectorModelView() },
            onStageTouch: (event: TouchEvent) => { this.handleObjectInspectorModelTouch(event) }
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
        return this.handleSkyKey(event)
      })
      .onMouse((event: MouseEvent) => {
        this.handleSkyMouse(event)
      })
      .onAxisEvent((event: AxisEvent) => {
        this.handleSkyAxis(event)
      })
      .onAreaChange((oldArea: Area, newArea: Area) => {
        // 布局硬回调：稳定触发。冷启动期 ArkUI setTimeout 重试不可靠，
        // 这里借 onAreaChange 反复尝试把启动命令送到 Qt 线程。
        this.startupBridgeSync()
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
      ok: true, state: this.guideStore.guideState, lastRequestId: this.guideLastRequest,
      result: this.guideLastResult, guides: ASTRONOMY_GUIDES
    }))
  }

  private async executeGuideRequest(commandName: string, payload: string, requestId: string = ''): Promise<void> {
    if (!this.guidePlayer) {
      this.guidePlayer = new GuidePlayer((name: string, value: string): Promise<GuideResult> => {
        return new Promise<GuideResult>((resolve) => {
          this.callInteractive(name, value,
            (response: StellariumBridgeResponse) => resolve({ ok: response.ok === true, error: response.error }),
            () => resolve({ ok: false, error: 'bridge_timeout' }))
        })
      }, (state: GuideState) => {
        const ended = this.guideStore.guideState.active && !state.active
        if (this.guideStore.guideState.phase !== state.phase || this.guideStore.guideState.index !== state.index) {
          this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseInOut }, () => { this.guideStore.guideState = state })
        } else {
          this.guideStore.guideState = state
        }
        this.publishGuideState()
        if (ended) {
          if (this.guideTimer >= 0) clearInterval(this.guideTimer)
          this.guideTimer = -1
          this.panelVisible = this.guidePanelWasVisible
          if (this.guideGyroWasEnabled && this.applicationInForeground) {
            this.gyroStore.gyroscopeEnabled = true
            this.startGyroscope()
          }
          this.guideGyroWasEnabled = false
          this.refreshState()
          this.locationPickerStore.loadObserverInfo(true)
        }
      })
    }
    let result: GuideResult
    if (commandName === 'startGuide') {
      if (this.scriptSessionActive() || this.polarScopeStore.polarScopeVisible || !ASTRONOMY_GUIDES.some((guide: AstronomyGuide) => guide.id === payload)) {
        result = { ok: false, error: 'session_busy_or_unknown_guide' }
      } else {
        this.guidePanelWasVisible = this.panelVisible
        this.guideGyroWasEnabled = this.gyroStore.gyroscopeEnabled
        this.stopGyroscope(false)
        this.gyroStore.gyroscopeEnabled = false
        this.stopSkyInertia()
        this.panelVisible = false
        this.infoWindowStore.infoWinVisible = false
        this.stopDetailAutoRefresh()
        this.stopTimePanelTimers()
        this.stopSkyCultureTimeFollowTimer()
        this.stopAstroCalcContextTimer()
        this.stopTelescopeLivePosition(false)
        this.guideTimer = setInterval(() => {
          if (this.applicationInForeground) this.guidePlayer?.tick(0.25)
        }, 250) as number
        result = await this.guidePlayer.start(payload)
      }
    } else {
      if (['return', 'next', 'previous', 'stop', 'retry', 'center', 'closer', 'wider'].includes(payload)) {
        this.stopSkyInertia()
      }
      result = await this.guidePlayer.action(payload)
    }
    this.guideLastRequest = requestId
    this.guideLastResult = result
    this.publishGuideState()
    if (!result.ok) this.flashHint(I18n.t('guide_error'))
  }

  private currentGuide(): AstronomyGuide {
    return ASTRONOMY_GUIDES.find((guide: AstronomyGuide) => guide.id === this.guideStore.guideState.guideId) ?? ASTRONOMY_GUIDES[0]
  }

  private currentGuideStep(): GuideStep { return this.currentGuide().steps[this.guideStore.guideState.index] }
  private guideCardWidth(): number { return Math.max(200, Math.min(440, this.skyWidth - 24)) }
  private guideCardHeight(): number { return Math.max(160, Math.min(390, this.skyHeight - this.scriptControlSafeTop() - 24)) }
  private guideCardX(): number {
    return clamp((this.isExpandedLayout ? 12 : (this.skyWidth - this.guideCardWidth()) / 2) + this.scriptStore.scriptControlOffsetX, 8, Math.max(8, this.skyWidth - this.guideCardWidth() - 8))
  }
  private guideCardY(): number {
    return clamp(this.skyHeight - this.guideCardHeight() - 16 + this.scriptStore.scriptControlOffsetY,
      this.scriptControlSafeTop(), Math.max(this.scriptControlSafeTop(), this.skyHeight - this.guideCardHeight() - 12))
  }

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
    const inLeft = chromeZoomButtonLeft(this.chromeRowPosXLeft(), horizontal, 0)
    const outLeft = chromeZoomButtonLeft(this.chromeRowPosXLeft(), horizontal, 1)
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
      this.toggleGyroscope(!this.gyroStore.gyroscopeEnabled)
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
      this.stopSkyInertia()
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
    if (enabled && !this.hasSelectedObject()) {
      this.flashHint(I18n.t('tracking_requires_selection'))
      return
    }
    if (this.gyroStore.gyroscopeEnabled) {
      this.updateGyroTargetGuide(true)
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
    const base = this.baseBottomCardX()
    return base + this.clampedObjectCardOffsetX(base, this.bottomCardWidth())
  }

  private baseBottomCardX(): number {
    if (!this.isExpandedLayout && !this.isFoldHoverLayout) { return 16 }
    if (!this.isExpandedLayout) { return Math.max(24, (this.skyWidth - this.bottomCardWidth()) / 2) }
    // The detail card is a freely placed window. Its base geometry must not
    // depend on whether another panel is open, otherwise the card jumps when
    // the bottom Dock changes the surrounding layout.
    return Math.max(this.EDGE_MARGIN + 92, this.skyWidth - this.bottomCardWidth() - this.EDGE_MARGIN + 16)
  }

  private bottomCardY(): number {
    const base = this.baseBottomCardY()
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

  private baseBottomCardY(): number {
    // Keep the selected target in the visual centre. Full details live in the
    // upper safe area, leaving the lower half of the sky visible for the lock
    // marker and for direct sky interaction.
    return this.isExpandedLayout ? Math.max(this.EDGE_MARGIN + 76, 92) : Math.max(86, Math.min(126, this.skyHeight * 0.12))
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

  private expandedMainPanelLeft(): number {
    return this.EDGE_MARGIN + this.panelOffsetX
  }

  private expandedDetailAvailableWidth(): number {
    const detailLeft = this.expandedMainPanelLeft() + this.panelWidth + 18
    return this.skyWidth - this.EDGE_MARGIN - detailLeft
  }

  private expandedDetailSummaryWidth(): number {
    return clamp(this.expandedDetailAvailableWidth(), 140, 300)
  }

  private canShowExpandedDetailSummary(): boolean {
    return this.expandedDetailAvailableWidth() >= 140
  }

  private expandedDetailSummaryX(): number {
    const base = this.baseExpandedDetailSummaryX()
    return base + this.clampedObjectCardOffsetX(base, this.expandedDetailSummaryWidth())
  }

  private baseExpandedDetailSummaryX(): number {
    return this.expandedMainPanelLeft() + this.panelWidth + 18
  }

  private expandedDetailSummaryY(): number {
    // 上移：原先 +84 使小详情卡偏中，遮挡视野中心；贴近顶部留出更多星空可视区
    const base = this.baseExpandedDetailSummaryY()
    return base + this.clampedObjectCardOffsetY(base, expandedDetailSummaryHeight())
  }

  private baseExpandedDetailSummaryY(): number {
    return Math.max(this.EDGE_MARGIN + 16, 48)
  }

  // 平板检查器固定贴在左侧：保留大部分星图，并给底部 Dock 留出触控空间。
  private tabletInspectorWidth(): number {
    return clamp(this.skyWidth * 0.32, 340, 390)
  }

  private tabletInspectorX(): number {
    const base = this.baseTabletInspectorX()
    return base + this.clampedObjectCardOffsetX(base, this.tabletInspectorWidth())
  }

  private baseTabletInspectorX(): number {
    return this.EDGE_MARGIN + 12
  }

  private tabletInspectorY(): number {
    const base = this.baseTabletInspectorY()
    return base + this.clampedObjectCardOffsetY(base, this.tabletInspectorHeight())
  }

  private baseTabletInspectorY(): number {
    return Math.max(this.EDGE_MARGIN + 56, 58)
  }

  private tabletInspectorHeight(): number {
    return Math.max(360, this.skyHeight - this.baseTabletInspectorY() - 84)
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
    if (useExpandedDetailSummary()) { return this.expandedDetailSummaryWidth() }
    if (isPhoneDetailPeek()) { return this.compactObjectPeekWidth() }
    return this.bottomCardWidth()
  }

  private objectActionBarY(): number {
    let cardY = this.bottomCardY()
    if (useExpandedDetailSummary()) { cardY = this.expandedDetailSummaryY() }
    if (isPhoneDetailPeek()) { cardY = this.compactObjectPeekY() }
    if (this.isFoldHoverLayout && !useExpandedDetailSummary()) { cardY = this.hoverBottomCardY() }
    return Math.max(8, cardY - 44)
  }

  private isObjectActionBarPoint(x: number, y: number): boolean {
    if (!this.showObjectActionBar()) { return false }
    const left = this.objectActionBarX()
    const top = this.objectActionBarY()
    return x >= left - 8 && x <= left + this.objectActionBarWidth() + 8 && y >= top - 8 && y <= top + 42
  }

  private isExpandedDetailSummaryPoint(x: number, y: number): boolean {
    if (!useExpandedDetailSummary() || !this.canShowExpandedDetailSummary()) { return false }
    const sx = this.expandedDetailSummaryX()
    const sy = this.expandedDetailSummaryY()
    return x >= sx - 8 && x <= sx + this.expandedDetailSummaryWidth() + 8 && y >= sy - 8 && y <= sy + expandedDetailSummaryHeight() + 8
  }

  private isObjectDetailCardRendered(): boolean {
    return this.infoWindowStore.infoWinVisible && this.objectDetailStore.selectedName.length > 0
  }

  private isObjectDetailCardPoint(x: number, y: number): boolean {
    if (!this.isObjectDetailCardRendered()) { return false }
    const left = this.detailCardX()
    const top = this.detailCardY()
    return x >= left - 8 && x <= left + this.detailCardWidth() + 8 &&
      y >= top - 8 && y <= top + this.detailCardHeight() + 8
  }

  private handleExpandedDetailSummaryTap(x: number, y: number): boolean {
    if (!this.isExpandedDetailSummaryPoint(x, y)) { return false }
    const sx = this.expandedDetailSummaryX()
    const sy = this.expandedDetailSummaryY()
    const sw = this.expandedDetailSummaryWidth()
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
      this.stopSkyInertia()
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
      const baseX = this.baseBottomCardX()
      const baseY = this.isFoldHoverLayout ? this.baseHoverBottomCardY() : this.baseBottomCardY()
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
    if (!this.hasSelectedObject()) {
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

  private chromeRowWidth(): number {
    return this.dockWidthPixels()
  }

  private chromeRowPosXLeft(): number {
    return this.isExpandedLayout ? this.EDGE_MARGIN : this.dockLeft()
  }

  private chromeRowPosXRight(): number {
    if (this.isExpandedLayout) {
      return this.skyWidth - this.EDGE_MARGIN - this.dockWidthPixels()
    }
    return this.dockLeft()
  }

  // 竖排（手机·半折，列高 96）还是横排（平板，一行 44 高）：平板 dock 只有 54 高，
  // 96 高的竖排压在它上方过于突兀，横排更贴近平板的工具条语汇。
  private chromeZoomHorizontal(): boolean {
    return this.isExpandedLayout
  }

  private expandedDockOccupiedLeft(): number {
    if (this.panelVisible) {
      return this.expandedMainPanelLeft() + this.panelWidth + 16
    }
    return this.EDGE_MARGIN
  }

  private expandedDockWidth(): number {
    const right = this.EDGE_MARGIN
    const available = Math.max(280, this.skyWidth - this.expandedDockOccupiedLeft() - right)
    const squeeze = Math.max(0, this.expandedDockOccupiedLeft() - this.EDGE_MARGIN)
    return clamp(640 - squeeze * 0.55, 320, Math.min(640, available))
  }

  private expandedDockLeft(): number {
    const available = Math.max(280, this.skyWidth - this.expandedDockOccupiedLeft() - this.EDGE_MARGIN)
    return this.expandedDockOccupiedLeft() + Math.max(0, (available - this.expandedDockWidth()) / 2)
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

  private dockWidthPixels(): number {
    return this.isExpandedLayout ? this.expandedDockWidth() : this.skyWidth * this.compactDockWidthPercent() / 100
  }

  private dockLeft(): number {
    if (this.isExpandedLayout) {
      return this.expandedDockLeft()
    }
    return Math.max(0, (this.skyWidth - this.dockWidthPixels()) / 2)
  }

  private dockTop(): number {
    return this.isExpandedLayout ? this.skyHeight - 62 : this.skyHeight - 82
  }

  private isDockPoint(x: number, y: number): boolean {
    if (this.polarScopeStore.polarScopeVisible) return false
    const left = this.dockLeft()
    const right = left + this.dockWidthPixels()
    const top = this.dockTop()
    const bottom = this.skyHeight
    return x >= left - 8 && x <= right + 8 && y >= top - 8 && y <= bottom
  }

  private dockActionAt(x: number, y: number): ShellAction | null {
    if (!this.isDockPoint(x, y)) {
      return null
    }
    const actions = this.canonicalDockActions()
    if (actions.length === 0) {
      return null
    }
    const usableLeft = this.dockLeft() + 4
    const usableWidth = Math.max(1, this.dockWidthPixels() - 8)
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
      this.stopSkyInertia()
      hilog.info(0x0000, 'StellariumArkUI', '[DOCK] down screen=%{public}d,%{public}d left=%{public}d top=%{public}d width=%{public}d', Math.round(x), Math.round(y), Math.round(this.dockLeft()), Math.round(this.dockTop()), Math.round(this.dockWidthPixels()))
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
  private objectInspectorIcon(): string {
    return catalogIconForObjectType(this.objectDetailStore.selectedType + ' ' + this.objectDetailStore.selectedObjectType, 'catalog_star')
  }

  private objectInspectorSearchText(): string {
    return (this.objectDetailStore.selectedCatalogId + ' ' + this.objectDetailStore.selectedEnglishName + ' ' + this.objectDetailStore.selectedName).toLowerCase()
  }

  private objectInspectorFilePath(relativePath: string): string {
    const path = this.stellariumFilesDir() + '/stellarium/' + relativePath
    try {
      return fileIo.accessSync(path) ? path : ''
    } catch (_err) {
      return ''
    }
  }

  private releaseDecodedImage(pixelMap: image.PixelMap | undefined, label: string): void {
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

  private clearObjectInspectorDecodedImage(): void {
    const oldPixelMap = this.objectMediaStore.objectInspectorMediaPixelMap
    this.objectMediaStore.objectInspectorMediaPixelMap = undefined
    this.objectInspectorMediaDecodeGeneration++
    this.clearObjectInspectorModelRenderer()
    this.releaseDecodedImage(oldPixelMap, 'object-inspector')
  }

  private clearObjectInspectorModelRenderer(): void {
    this.objectInspectorModelRenderClient?.dispose()
    this.objectInspectorModelRenderClient = undefined
    this.objectMediaStore.objectInspectorProceduralKind = ''
    this.objectInspectorProceduralKey = ''
    this.objectInspectorProceduralParticles = []
    this.objectMediaStore.objectInspectorModelImmersive = false
    this.objectMediaStore.objectInspectorModelOverlayOpacity = 0
    this.objectInspectorModelOverlaySerial++
    AppStorage.setOrCreate('stellariumObjectModelView', JSON.stringify({
      ok: false, error: 'model is not ready'
    }))
    this.objectInspectorModelTouchCount = 0
    this.objectInspectorModelLastLighting = []
    const oldModelPixelMap = this.objectMediaStore.objectInspectorModelPixelMap
    if (this.objectInspectorModelRenderTimer !== 0) {
      clearTimeout(this.objectInspectorModelRenderTimer)
      this.objectInspectorModelRenderTimer = 0
    }
    this.objectMediaStore.objectInspectorModelPixelMap = undefined
    this.objectInspectorModelTexturePixels = undefined
    this.objectInspectorModelTextureWidth = 0
    this.objectInspectorModelTextureHeight = 0
    this.objectInspectorModelTextureStride = 0
    this.objectInspectorModelRingTexturePixels = undefined
    this.objectInspectorModelRingTextureWidth = 0
    this.objectInspectorModelRingTextureHeight = 0
    this.objectInspectorModelRingTextureStride = 0
    this.objectInspectorModelRendering = false
    this.objectInspectorModelRenderPending = false
    this.objectInspectorModelRenderHighQuality = false
    this.objectMediaStore.objectInspectorModelInteracting = false
    this.objectInspectorModelRenderGeneration++
    this.releaseDecodedImage(oldModelPixelMap, 'object-inspector-model')
  }

  private decodeLocalImage(
    filePath: string,
    label: string,
    onSuccess: (pixelMap: image.PixelMap) => void,
    onFailure: (err: Error) => void,
    desiredSize?: ImageDecodeSize,
  ): void {
    let source: image.ImageSource | undefined = undefined
    let file: fileIo.File | undefined = undefined
    const closeFile = (): void => {
      if (file === undefined) return
      try {
        fileIo.closeSync(file)
      } catch (err) {
        hilog.warn(0x0000, 'StellariumArkUI', '[detail-media] file close failed kind=%{public}s error=%{public}s',
          label, JSON.stringify(err))
      }
      file = undefined
    }
    try {
      file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY)
      hilog.info(0x0000, 'StellariumArkUI',
        '[detail-media] create image source kind=%{public}s path=%{public}s fd=%{public}s',
        label, filePath, file.fd.toString())
      source = image.createImageSource(file.fd)
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
      pixelMapPromise.then((pixelMap: image.PixelMap) => {
        if (label === 'model') {
          hilog.info(0x0000, 'StellariumArkUI',
            '[detail-media] decode promise settled kind=%{public}s bytes=%{public}s',
            label, pixelMap.getPixelBytesNumber().toString())
        }
        onSuccess(pixelMap)
        source?.release().catch((err: Error) => {
          hilog.warn(0x0000, 'StellariumArkUI', '[detail-media] image source release failed kind=%{public}s error=%{public}s',
            label, JSON.stringify(err))
        })
        closeFile()
      }).catch((err: Error) => {
        source?.release().catch((releaseErr: Error) => {
          hilog.warn(0x0000, 'StellariumArkUI', '[detail-media] image source release failed kind=%{public}s error=%{public}s',
            label, JSON.stringify(releaseErr))
        })
        closeFile()
        onFailure(err)
      })
    } catch (err) {
      if (source !== undefined) {
        source.release().catch((releaseErr: Error) => {
          hilog.warn(0x0000, 'StellariumArkUI', '[detail-media] image source release failed kind=%{public}s error=%{public}s',
            label, JSON.stringify(releaseErr))
        })
      }
      closeFile()
      onFailure(err as Error)
    }
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

  private objectInspectorMediaWarmupText(): string {
    if (this.objectMediaStore.objectInspectorMediaWarmupTotal <= 0) {
      return '正在检查离线图库'
    }
    let text = '离线图库已准备 ' + this.objectMediaStore.objectInspectorMediaWarmupInstalled.toString() + '/' +
      this.objectMediaStore.objectInspectorMediaWarmupTotal.toString()
    if (this.objectMediaStore.objectInspectorMediaWarmupFailed > 0) {
      text += ' · ' + this.objectMediaStore.objectInspectorMediaWarmupFailed.toString() + ' 项失败'
    }
    return text
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

  private objectInspectorPlanetTexturePath(): string {
    const objectKey = this.objectDetailStore.selectedEnglishName.toLowerCase().replace(/[^a-z0-9]/g, '')
    const textures: Array<[string, string]> = [
      ['sun', 'textures/sun.png'], ['mercury', 'textures/mercury.png'], ['venus', 'textures/venus.png'],
      ['earth', 'textures/earth_cmap.png'], ['moon', 'textures/moon.png'], ['mars', 'textures/mars.png'],
      ['jupiter', 'textures/jupiter.png'], ['saturn', 'textures/saturn.png'], ['uranus', 'textures/uranus.png'],
      ['neptune', 'textures/neptune.png'], ['pluto', 'textures/pluto.png'], ['charon', 'textures/charon.png'],
      ['ceres', 'textures/ceres.png'], ['vesta', 'textures/vesta.png'], ['eros', 'textures/eros.png'],
      ['bennu', 'textures/bennu.png'], ['gaspra', 'textures/gaspra.png'], ['ida', 'textures/ida.png'],
      ['sedna', 'textures/sedna.png'], ['eris', 'textures/eris.png'], ['haumea', 'textures/haumea.png'],
      ['dysnomia', 'textures/dysnomia.png'], ['2007or10', 'textures/2007OR10.png'],
      ['phobos', 'textures/phobos.png'], ['deimos', 'textures/deimos.png'], ['io', 'textures/io.png'],
      ['europa', 'textures/europa.png'], ['ganymede', 'textures/ganymede.png'], ['callisto', 'textures/callisto.png'],
      ['amalthea', 'textures/amalthea.png'], ['mimas', 'textures/mimas.png'], ['enceladus', 'textures/enceladus.png'],
      ['tethys', 'textures/tethys.png'], ['dione', 'textures/dione.png'], ['rhea', 'textures/rhea.png'],
      ['titan', 'textures/titan.png'], ['hyperion', 'textures/hyperion.png'], ['iapetus', 'textures/iapetus.png'],
      ['phoebe', 'textures/phoebe.png'], ['janus', 'textures/janus.png'], ['epimetheus', 'textures/epimetheus.png'],
      ['prometheus', 'textures/prometheus.png'], ['ariel', 'textures/ariel.png'], ['umbriel', 'textures/umbriel.png'],
      ['titania', 'textures/titania.png'], ['oberon', 'textures/oberon.png'], ['miranda', 'textures/miranda.png'],
      ['triton', 'textures/triton.png'], ['nereid', 'textures/nereid.png'], ['proteus', 'textures/proteus.png']
    ]
    for (const pair of textures) {
      if (objectKey === pair[0] || objectKey.startsWith(pair[0] + 'observer')) {
        return pair[1]
      }
    }
    return ''
  }

  private objectInspectorPlanetRingSpec(): ObjectInspectorRingSpec | undefined {
    const objectKey = this.objectDetailStore.selectedEnglishName.toLowerCase().replace(/[^a-z0-9]/g, '')
    const specs: Array<[string, ObjectInspectorRingSpec]> = [
      ['saturn', { texturePath: 'textures/saturn_rings_radial.png', innerRadius: 1.24, outerRadius: 2.33, tilt: 0.35, opacity: 0.94 }],
      ['uranus', { texturePath: 'textures/uranus_rings.png', innerRadius: 1.05, outerRadius: 3.82, tilt: 0.55, opacity: 1.0 }],
      ['neptune', { texturePath: 'textures/neptune_rings.png', innerRadius: 1.65, outerRadius: 2.54, tilt: 0.42, opacity: 0.9 }]
    ]
    for (const pair of specs) {
      if (objectKey === pair[0] || objectKey.startsWith(pair[0] + 'observer')) {
        return pair[1]
      }
    }
    return undefined
  }

  private objectInspectorDeepSkyImageName(): string {
    const visualKind = this.objectInspectorFallbackVisualKind()
    if (visualKind !== 'galaxy' && visualKind !== 'nebula' && visualKind !== 'globular-cluster' && visualKind !== 'open-cluster') {
      return ''
    }
    const text = this.objectInspectorSearchText()
    // Some widely known objects use a Messier image while the core's primary
    // catalog identifier is NGC. Keep these explicit rather than guessing.
    const aliases: Record<string, string> = {
      'ngc 224': 'm31.png', 'ngc224': 'm31.png', 'ngc 1952': 'm1dumont.png', 'ngc1952': 'm1dumont.png'
    }
    for (const key of Object.keys(aliases)) {
      if (text.indexOf(key) >= 0) {
        return aliases[key]
      }
    }
    const match = text.match(/\b(m|ngc|ic)\s*0*(\d+)\b/i)
    if (match === null || match.length < 3) { return '' }
    const prefix = match[1].toLowerCase() === 'ngc' ? 'n' : match[1].toLowerCase()
    return prefix + match[2] + '.png'
  }

  private objectInspectorFallbackVisualKind(): string {
    const type = (this.objectDetailStore.selectedObjectType + ' ' + this.objectDetailStore.selectedType).toLowerCase()
    const procedural = proceduralModelKind(type)
    if (procedural.length > 0) return procedural
    if (type.indexOf('comet') >= 0 || type.indexOf('彗') >= 0) return 'comet'
    if (type.indexOf('asteroid') >= 0 || type.indexOf('minor planet') >= 0 || type.indexOf('小行星') >= 0) return 'asteroid'
    if (type.indexOf('galaxy') >= 0 || type.indexOf('星系') >= 0) return 'galaxy'
    if (type.indexOf('globular') >= 0 || type.indexOf('球状星团') >= 0) return 'globular-cluster'
    if (type.indexOf('cluster') >= 0 || type.indexOf('星团') >= 0) return 'open-cluster'
    if (type.indexOf('nebula') >= 0 || type.indexOf('星云') >= 0) return 'nebula'
    if (type.indexOf('constellation') >= 0 || type.indexOf('星座') >= 0) return 'constellation'
    if (type.indexOf('artificial') >= 0 || type.indexOf('人造') >= 0) return 'satellite'
    if (type.indexOf('moon') >= 0) return 'moon'
    if (type.indexOf('satellite') >= 0 || type.indexOf('卫星') >= 0) return 'satellite'
    if (type.indexOf('star') >= 0 || type.indexOf('恒星') >= 0 || type.indexOf('变星') >= 0) return 'star'
    return 'object'
  }

  private objectInspectorStarColor(): string {
    const temperature = this.objectDetailStore.selectedTemperatureK
    if (temperature >= 11000) return '#A8C8FF'
    if (temperature >= 7500) return '#D6E5FF'
    if (temperature >= 6000) return '#FFF5D8'
    if (temperature >= 4500) return '#FFD3A3'
    if (temperature > 0) return '#FFAA86'
    return '#E8F4FF'
  }

  private refreshObjectInspectorMedia(): void {
    const planetTexturePath = this.objectInspectorPlanetTexturePath()
    const deepSkyImageName = planetTexturePath.length === 0 && this.objectDetailStore.selectedDetailMediaPath.length === 0
      ? this.objectInspectorDeepSkyImageName()
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
    const ringSpec = kind === 'model' ? this.objectInspectorPlanetRingSpec() : undefined
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
    if (mediaKeySame && (this.objectMediaStore.objectInspectorMediaDecoding || this.objectInspectorModelRendering)) {
      return
    }
    const shouldDecode = path.length > 0 && (kind === 'image' || kind === 'constellation' || kind === 'model') &&
      !(mediaKeySame && this.objectMediaStore.objectInspectorMediaLoadFailed) &&
      (!mediaKeySame || (kind === 'model'
        ? this.objectInspectorModelTexturePixels === undefined
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
    this.objectInspectorModelRotation = this.defaultObjectInspectorModelRotation()
    this.objectInspectorModelLastPinchDistance = 0
    this.objectMediaStore.objectInspectorMediaLoading = shouldResolve || shouldDecode
    this.objectMediaStore.objectInspectorMediaDecoding = shouldDecode
    this.objectMediaStore.objectInspectorMediaLoadFailed = false
    this.objectMediaStore.objectInspectorMediaPreparationFailed = false
    this.objectMediaStore.objectInspectorMediaNoMatch = false
    this.updateObjectInspectorMediaWarmup(kind)
    this.objectInspectorMediaRequestPath = this.objectMediaStore.objectInspectorMediaLoading ? requestedPath : ''
    if (proceduralKind.length > 0) {
      this.requestObjectInspectorModelRender(true)
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
      this.decodeLocalImage(filePath, kind, (pixelMap: image.PixelMap) => {
        const currentSelection = this.objectDetailStore.selectedName + '\n' + this.objectDetailStore.selectedEnglishName + '\n' + this.objectDetailStore.selectedCatalogId
        if (currentSelection !== expectedSelection || this.objectMediaStore.objectInspectorMediaPath !== expectedPath ||
          generation !== this.objectInspectorMediaDecodeGeneration) {
          this.releaseDecodedImage(pixelMap, 'stale-object-inspector')
          return
        }
        const oldPixelMap = this.objectMediaStore.objectInspectorMediaPixelMap
        this.objectMediaStore.objectInspectorMediaPixelMap = pixelMap
        this.releaseDecodedImage(oldPixelMap, 'previous-object-inspector')
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

  private failObjectInspectorModelTexture(mediaGeneration: number, reason: string): void {
    if (mediaGeneration !== this.objectInspectorMediaDecodeGeneration) {
      return
    }
    this.objectMediaStore.objectInspectorMediaLoading = false
    this.objectMediaStore.objectInspectorMediaDecoding = false
    this.objectMediaStore.objectInspectorMediaLoadFailed = true
    hilog.error(0x0000, 'StellariumArkUI',
      '[detail-model] CPU texture load failed uri=%{public}s reason=%{public}s',
      this.objectMediaStore.objectInspectorMediaPath, reason)
  }

  private commitObjectInspectorModelTexture(
    texture: ArrayBuffer,
    ringTexture: ArrayBuffer | undefined,
    mediaGeneration: number,
    expectedSelection: string,
    expectedPath: string,
    sourceLabel: string,
  ): void {
    const currentSelection = this.objectDetailStore.selectedName + '\n' + this.objectDetailStore.selectedEnglishName + '\n' + this.objectDetailStore.selectedCatalogId
    if (currentSelection !== expectedSelection || this.objectMediaStore.objectInspectorMediaPath !== expectedPath ||
      mediaGeneration !== this.objectInspectorMediaDecodeGeneration) {
      return
    }
    this.objectInspectorModelTexturePixels = texture
    this.objectInspectorModelTextureWidth = 512
    this.objectInspectorModelTextureHeight = 256
    this.objectInspectorModelTextureStride = 512 * 4
    if (ringTexture !== undefined) {
      this.objectInspectorModelRingTexturePixels = ringTexture
      this.objectInspectorModelRingTextureWidth = 512
      this.objectInspectorModelRingTextureHeight = 2
      this.objectInspectorModelRingTextureStride = 512 * 4
    } else {
      this.objectInspectorModelRingTexturePixels = undefined
      this.objectInspectorModelRingTextureWidth = 0
      this.objectInspectorModelRingTextureHeight = 0
      this.objectInspectorModelRingTextureStride = 0
    }
    this.objectMediaStore.objectInspectorMediaLoading = false
    this.objectMediaStore.objectInspectorMediaDecoding = true
    this.objectMediaStore.objectInspectorMediaLoadFailed = false
    hilog.info(0x0000, 'StellariumArkUI',
      '[detail-model] CPU texture ready uri=%{public}s bytes=%{public}s source=%{public}s phase=%{public}s',
      expectedPath, texture.byteLength.toString(), sourceLabel, this.objectDetailStore.selectedPhase)
    this.requestObjectInspectorModelRender(true)
  }

  // HarmonyOS 的 CPU 光栅化需要原始 RGBA 字节。构建期侧车（.model.rgba）缺失时
  // （Windows 资源同步脚本不生成它们），退回到用鸿蒙图像框架解码 PNG（512x256，
  // RGBA_8888）再读回像素，避免“本地资源已找到但设备无法显示”因缺少侧车而失败。
  private decodeObjectInspectorModelTextureFromPng(
    pngFilePath: string,
    ringPngFilePath: string,
    mediaGeneration: number,
    expectedSelection: string,
    expectedPath: string,
  ): void {
    if (pngFilePath.length === 0) {
      this.failObjectInspectorModelTexture(mediaGeneration, 'sidecar and PNG are both missing')
      return
    }
    this.decodeLocalImage(pngFilePath, 'model', (pixelMap: image.PixelMap) => {
      const pixels = new ArrayBuffer(512 * 256 * 4)
      try {
        pixelMap.readPixelsToBufferSync(pixels)
      } catch (err) {
        this.releaseDecodedImage(pixelMap, 'model-texture-fallback')
        this.failObjectInspectorModelTexture(mediaGeneration, 'PNG readback failed: ' + describeDecodeError(err as Error))
        return
      }
      this.releaseDecodedImage(pixelMap, 'model-texture-fallback')
      if (ringPngFilePath.length === 0) {
        this.commitObjectInspectorModelTexture(pixels, undefined, mediaGeneration, expectedSelection, expectedPath, 'png')
        return
      }
      this.decodeLocalImage(ringPngFilePath, 'model', (ringPixelMap: image.PixelMap) => {
        const ringPixels = new ArrayBuffer(512 * 2 * 4)
        let ringTexture: ArrayBuffer | undefined = undefined
        try {
          ringPixelMap.readPixelsToBufferSync(ringPixels)
          ringTexture = ringPixels
        } catch (err) {
          hilog.warn(0x0000, 'StellariumArkUI', '[detail-model] ring PNG readback failed error=%{public}s',
            describeDecodeError(err as Error))
        }
        this.releaseDecodedImage(ringPixelMap, 'model-ring-texture-fallback')
        this.commitObjectInspectorModelTexture(pixels, ringTexture, mediaGeneration, expectedSelection, expectedPath, 'png')
      }, (err: Error) => {
        hilog.warn(0x0000, 'StellariumArkUI', '[detail-model] ring PNG decode failed error=%{public}s',
          describeDecodeError(err))
        this.commitObjectInspectorModelTexture(pixels, undefined, mediaGeneration, expectedSelection, expectedPath, 'png')
      }, { width: 512, height: 2 })
    }, (err: Error) => {
      this.failObjectInspectorModelTexture(mediaGeneration, 'PNG decode failed: ' + describeDecodeError(err))
    }, { width: 512, height: 256 })
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

  private refreshObjectInspectorModelLighting(): void {
    if (!this.infoWindowStore.infoWinVisible || this.objectDetailStore.bottomCardIndex !== 2) return
    const lighting = this.objectDetailStore.selectedDetailModel?.lighting
    if (lighting === undefined || this.objectInspectorModelTexturePixels === undefined) return
    const values = lighting.viewToBody.concat(lighting.sunDirectionBody)
    const changed = values.some((value: number, index: number) =>
      Math.abs(value - (this.objectInspectorModelLastLighting[index] ?? 10)) > 0.0001)
    if (changed && Date.now() - this.objectInspectorModelLastRenderTime >= 250) {
      this.requestObjectInspectorModelRender(!this.objectMediaStore.objectInspectorModelInteracting)
    }
  }

  private objectInspectorModelTransform(): number[] {
    return modelMultiply(this.objectDetailStore.selectedDetailModel?.lighting?.viewToBody ?? modelIdentity(),
      this.objectInspectorModelRotation)
  }

  private rotateObjectInspectorModel(deltaX: number, deltaY: number): void {
    this.objectInspectorModelRotation = modelDrag(this.objectInspectorModelRotation, deltaX, deltaY)
    this.requestObjectInspectorModelRender(false)
  }

  private requestObjectInspectorModelRender(highQuality: boolean): void {
    if (!this.objectInspectorModelReady()) {
      return
    }
    this.objectInspectorModelRenderHighQuality = this.objectInspectorModelRenderHighQuality || highQuality
    this.objectInspectorModelRenderPending = true
    if (this.objectInspectorModelRendering) {
      return
    }
    if (!highQuality) {
      if (this.objectInspectorModelRenderTimer !== 0) {
        return
      }
      this.objectInspectorModelRenderTimer = setTimeout(() => {
        this.objectInspectorModelRenderTimer = 0
        this.flushObjectInspectorModelRender()
      }, 18) as number
      return
    }
    if (this.objectInspectorModelRenderTimer !== 0) {
      clearTimeout(this.objectInspectorModelRenderTimer)
      this.objectInspectorModelRenderTimer = 0
    }
    this.flushObjectInspectorModelRender()
  }

  private flushObjectInspectorModelRender(): void {
    if (this.objectInspectorModelRendering || !this.objectInspectorModelRenderPending ||
      !this.objectInspectorModelReady()) {
      return
    }
    const renderHighQuality = this.objectInspectorModelRenderHighQuality
    this.objectInspectorModelRenderPending = false
    this.objectInspectorModelRenderHighQuality = false
    this.objectInspectorModelRendering = true
    this.renderObjectInspectorModel(renderHighQuality)
  }

  private renderObjectInspectorModel(highQuality: boolean): void {
    if (!this.objectInspectorModelReady()) {
      this.objectInspectorModelRendering = false
      return
    }
    const generation = this.objectInspectorModelRenderGeneration
    const immersive = this.objectMediaStore.objectInspectorModelImmersive
    const renderSize = highQuality ? (immersive ? 640 : 320) : 224
    const transform = this.objectInspectorModelTransform()
    const inspectionRotation = this.objectInspectorModelRotation.slice()
    const lighting = this.objectDetailStore.selectedDetailModel?.lighting
    const started = Date.now()
    let computeMs = 0
    let pixelMapStarted = 0
    let uiPulseCount = 0
    let uiMaxDelayMs = 0
    this.objectInspectorModelLastRenderTime = started
    this.objectInspectorModelLastLighting = lighting === undefined ? [] :
      lighting.viewToBody.concat(lighting.sunDirectionBody)
    if (this.objectMediaStore.objectInspectorModelPixelMap === undefined) this.objectMediaStore.objectInspectorMediaDecoding = true
    const ring = this.objectInspectorPlanetRingSpec()
    const renderRing: DetailModelRing | undefined = ring === undefined ? undefined : {
      innerRadius: ring.innerRadius, outerRadius: ring.outerRadius, opacity: ring.opacity
    }
    const renderLighting: DetailModelLight | undefined = lighting === undefined ? undefined : {
      viewToBody: lighting.viewToBody, sunDirectionBody: lighting.sunDirectionBody, emissive: lighting.emissive
    }
    const resources: DetailModelResources = {
      texture: this.objectInspectorModelTexturePixels,
      textureWidth: this.objectInspectorModelTextureWidth,
      textureHeight: this.objectInspectorModelTextureHeight,
      textureStride: this.objectInspectorModelTextureStride,
      ringTexture: this.objectInspectorModelRingTexturePixels,
      ringWidth: this.objectInspectorModelRingTextureWidth,
      ringHeight: this.objectInspectorModelRingTextureHeight,
      ringSpec: renderRing,
      kind: this.objectMediaStore.objectInspectorProceduralKind,
      temperature: this.objectDetailStore.selectedTemperatureK,
      particles: this.objectInspectorProceduralParticles
    }
    const frame: DetailModelFrame = {
      renderSize: renderSize, scale: this.objectMediaStore.objectInspectorModelScale, transform: transform, lighting: renderLighting
    }
    if (this.objectInspectorModelRenderClient === undefined) {
      this.objectInspectorModelRenderClient = new DetailModelRenderClient()
    }
    this.objectInspectorModelRenderClient.setSuspended(!this.applicationInForeground)
    this.objectInspectorModelRenderClient.render(resources, frame).then((result: DetailModelResult) => {
      if (generation !== this.objectInspectorModelRenderGeneration || !this.objectInspectorModelReady()) {
        throw new Error('stale model frame')
      }
      computeMs = result.computeMs
      uiPulseCount = result.uiPulseCount ?? 0
      uiMaxDelayMs = result.uiMaxDelayMs ?? 0
      pixelMapStarted = Date.now()
      return image.createPixelMap(result.pixels as ArrayBuffer, {
      size: { width: renderSize, height: renderSize },
      srcPixelFormat: image.PixelMapFormat.RGBA_8888,
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      alphaType: image.AlphaType.UNPREMUL,
      editable: false
      })
    }).then((pixelMap: image.PixelMap) => {
      if (generation !== this.objectInspectorModelRenderGeneration ||
        !this.objectInspectorModelReady()) {
        this.releaseDecodedImage(pixelMap, 'stale-object-inspector-model')
        return
      }
      const oldPixelMap = this.objectMediaStore.objectInspectorModelPixelMap
      this.objectMediaStore.objectInspectorModelPixelMap = pixelMap
      AppStorage.setOrCreate('stellariumObjectModelView', JSON.stringify({
        ok: true, selectedEnglishName: this.objectDetailStore.selectedEnglishName,
        rotation: inspectionRotation, viewToBody: transform,
        lighting: lighting, renderSize: renderSize, renderedAt: this.objectInspectorModelLastRenderTime,
        kind: this.objectMediaStore.objectInspectorProceduralKind || 'textured-sphere',
        schematic: this.objectMediaStore.objectInspectorProceduralKind.length > 0,
        temperatureK: this.objectDetailStore.selectedTemperatureK > 0 ? this.objectDetailStore.selectedTemperatureK : null,
        immersive: immersive, renderer: 'worker', computeMs: computeMs,
        uiPulseCount: uiPulseCount, uiMaxDelayMs: uiMaxDelayMs,
        pixelMapMs: Date.now() - pixelMapStarted, totalMs: Date.now() - started
      }))
      this.releaseDecodedImage(oldPixelMap, 'previous-object-inspector-model')
      this.objectInspectorModelRendering = false
      this.objectMediaStore.objectInspectorMediaDecoding = false
      this.objectMediaStore.objectInspectorMediaLoadFailed = false
      const renderAgain = this.objectInspectorModelRenderPending
      const renderAgainHighQuality = this.objectInspectorModelRenderHighQuality
      this.objectInspectorModelRenderPending = false
      this.objectInspectorModelRenderHighQuality = false
      if (renderAgain) {
        this.requestObjectInspectorModelRender(renderAgainHighQuality)
      }
    }).catch((err: Error) => {
      if (generation !== this.objectInspectorModelRenderGeneration) {
        return
      }
      this.objectInspectorModelRendering = false
      this.objectMediaStore.objectInspectorMediaDecoding = false
      this.objectMediaStore.objectInspectorMediaLoadFailed = true
      hilog.error(0x0000, 'StellariumArkUI',
        '[detail-model] sphere render failed error=%{public}s', JSON.stringify(err))
      AppStorage.setOrCreate('stellariumObjectModelView', JSON.stringify({
        ok: false, error: 'model render failed', selectedEnglishName: this.objectDetailStore.selectedEnglishName
      }))
    })
  }

  private objectInspectorModelReady(): boolean {
    return this.objectMediaStore.objectInspectorProceduralKind.length > 0 ||
      (this.objectInspectorModelTexturePixels !== undefined && this.objectInspectorModelTextureWidth > 0 && this.objectInspectorModelTextureHeight > 0)
  }

  private defaultObjectInspectorModelRotation(): number[] {
    return this.objectMediaStore.objectInspectorProceduralKind === 'quasar' ? modelDrag(modelIdentity(), 0, -100) : modelIdentity()
  }

  private resetObjectInspectorModelView(): void {
    this.objectInspectorModelRotation = this.defaultObjectInspectorModelRotation()
    this.objectMediaStore.objectInspectorModelScale = 1
    this.objectInspectorModelLastPinchDistance = 0
    this.objectMediaStore.objectInspectorModelInteracting = false
    this.requestObjectInspectorModelRender(true)
  }

  private objectInspectorModelNotice(): string {
    return this.objectMediaStore.objectInspectorProceduralKind.length > 0
      ? I18n.t('model_basis_' + this.objectMediaStore.objectInspectorProceduralKind)
      : I18n.t('model_lighting_note')
  }

  private setObjectInspectorModelImmersive(open: boolean): void {
    if (open === this.objectMediaStore.objectInspectorModelImmersive &&
      this.objectMediaStore.objectInspectorModelOverlayOpacity === (open ? 1 : 0)) return
    const serial = ++this.objectInspectorModelOverlaySerial
    if (open) {
      this.objectMediaStore.objectInspectorModelImmersive = true
      this.objectMediaStore.objectInspectorModelOverlayOpacity = 0
      this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.objectMediaStore.objectInspectorModelOverlayOpacity = 1
      })
      this.requestObjectInspectorModelRender(true)
    } else {
      this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseIn, onFinish: () => {
        if (serial !== this.objectInspectorModelOverlaySerial) return
        this.objectMediaStore.objectInspectorModelImmersive = false
        this.requestObjectInspectorModelRender(true)
      } }, () => { this.objectMediaStore.objectInspectorModelOverlayOpacity = 0 })
    }
  }

  private handleObjectInspectorModelTouch(event: TouchEvent): void {
    event.stopPropagation()
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.objectInspectorModelTouchCount = 0
      this.objectInspectorModelLastPinchDistance = 0
      this.objectMediaStore.objectInspectorModelInteracting = false
      this.requestObjectInspectorModelRender(true)
      return
    }
    const points = event.touches.length > 0 ? event.touches : event.changedTouches
    if (points.length === 0) { return }
    const x = touchScreenX(points[0])
    const y = touchScreenY(points[0])
    if (event.type === TouchType.Down || this.objectInspectorModelTouchCount !== points.length) {
      this.objectInspectorModelTouchCount = points.length
      this.objectMediaStore.objectInspectorModelInteracting = true
      this.objectInspectorModelLastX = x
      this.objectInspectorModelLastY = y
      if (points.length > 1) {
        const secondX = touchScreenX(points[1])
        const secondY = touchScreenY(points[1])
        const deltaX = secondX - x
        const deltaY = secondY - y
        this.objectInspectorModelLastPinchDistance = Math.sqrt(deltaX * deltaX + deltaY * deltaY)
      } else {
        this.objectInspectorModelLastPinchDistance = 0
      }
      return
    }
    if (event.type === TouchType.Move) {
      if (points.length > 1) {
        const secondX = touchScreenX(points[1])
        const secondY = touchScreenY(points[1])
        const deltaX = secondX - x
        const deltaY = secondY - y
        const distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY)
        if (this.objectInspectorModelLastPinchDistance > 0) {
          const rawScaleFactor = distance / this.objectInspectorModelLastPinchDistance
          if (Number.isFinite(rawScaleFactor) && Math.abs(rawScaleFactor - 1) > 0.002) {
            const scaleFactor = 1 + (rawScaleFactor - 1) * 0.68
            this.objectMediaStore.objectInspectorModelScale = Math.max(0.82, Math.min(1.20,
              this.objectMediaStore.objectInspectorModelScale * scaleFactor))
            this.requestObjectInspectorModelRender(false)
          }
        }
        this.objectInspectorModelLastPinchDistance = distance
        return
      }
      const deltaX = x - this.objectInspectorModelLastX
      const deltaY = y - this.objectInspectorModelLastY
      this.objectInspectorModelLastX = x
      this.objectInspectorModelLastY = y
      this.objectInspectorModelLastPinchDistance = 0
      this.rotateObjectInspectorModel(deltaX, deltaY)
      return
    }
  }

  private objectInspectorInlineModelSize(): number {
    return Math.min(200, Math.max(80, this.bottomCardWidth() - 112))
  }

  private objectInspectorImageHeight(): number {
    return this.objectMediaStore.objectInspectorMediaViewportHeight > 0
      ? Math.max(72, Math.min(210, this.objectMediaStore.objectInspectorMediaViewportHeight - 88)) : 210
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
      case 'atmosphere': return this.expandedAtmosphereSummary()
      default: return ''
    }
  }

  private expandedAtmosphereSummary(): string {
    const apparent = this.objectDetailStore.selectedApparentMagnitude.length > 0 ? '大气后 ' + this.objectDetailStore.selectedApparentMagnitude + ' 等' : ''
    const airmass = this.objectDetailStore.selectedAirmass.length > 0 ? '气团 ' + this.objectDetailStore.selectedAirmass : ''
    return (apparent + '  ' + airmass).trim()
  }



  private distanceInformationVisible(): boolean {
    return this.infoWindowStore.infoLevel <= 1 && (this.infoWindowStore.informationMode !== 'custom' || this.informationMaskHas('distance'))
  }

  private objectDistanceSummary(): string {
    if (!this.distanceInformationVisible()) return '--'
    return this.objectDetailStore.selectedDistance.length > 0 ? (this.objectDetailStore.selectedDistanceCompact || this.objectDetailStore.selectedDistance) : I18n.t('distance_missing')
  }

  private objectDistanceNoticeText(): string {
    if (!this.distanceInformationVisible()) return ''
    const status = this.objectDetailStore.selectedDistanceStatus
    if (status === 'invalid_orbit') return I18n.t('satellite_propagation_invalid')
    if (this.objectDetailStore.selectedTleOutdated) return I18n.t('satellite_tle_stale')
    if (status === 'catalog' || status === 'computed' || status.length === 0) return ''
    const key = ['low_confidence', 'redshift_only', 'invalid_orbit', 'unsupported_unit', 'estimated'].includes(status)
      ? status : 'unavailable'
    return I18n.t('distance_' + key)
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
    if (!this.isObjectDetailCardPoint(x, y)) { return false }
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
  private nmText(): string {
    return this.nightModeStore.nightMode ? '#FF6644' : '#E5FFFFFF'
  }
  private nmSub(): string {
    return this.nightModeStore.nightMode ? '#CC5533' : '#99FFFFFF'
  }
  private nmAccent(): string {
    return this.nightModeStore.nightMode ? '#FF5533' : '#5B93BF'
  }
  private nmBg(): string {
    return this.nightModeStore.nightMode ? 'rgba(180, 40, 20, 0.12)' : 'rgba(255,255,255,0.04)'
  }
  private nmBorder(): string {
    return this.nightModeStore.nightMode ? 'rgba(200, 60, 30, 0.20)' : 'rgba(255,255,255,0.08)'
  }
  private nmInput(): string {
    return this.nightModeStore.nightMode ? 'rgba(120, 30, 15, 0.50)' : 'rgba(255,255,255,0.06)'
  }
  private nmInputBorder(): string {
    return this.nightModeStore.nightMode ? 'rgba(200, 60, 30, 0.25)' : 'rgba(214, 238, 255, 0.14)'
  }
  private nmPickerSurface(): string {
    return this.nightModeStore.nightMode ? '#32120D' : '#101A2B'
  }
  private nmPickerHeader(): string {
    return this.nightModeStore.nightMode ? '#48170F' : '#18263B'
  }
  private nmPickerHeaderActive(): string {
    return this.nightModeStore.nightMode ? '#5D1D12' : '#1E3A54'
  }
  private nmPickerSelected(): string {
    return this.nightModeStore.nightMode ? '#8A2B1B' : '#285F84'
  }
  private nmPickerOption(): string {
    return this.nightModeStore.nightMode ? '#41160F' : '#172338'
  }

  private selectedStatusZh(en: string): string {
    return I18n.selectedStatus(en)
  }


  private selectedObjectIsConstellation(): boolean {
    const type = (this.objectDetailStore.selectedType + ' ' + this.objectDetailStore.selectedObjectType).toLowerCase()
    return type.indexOf('constellation') >= 0 || type.indexOf('星座') >= 0
  }

  private selectedObjectIsArtificialSatellite(): boolean {
    if (this.objectDetailStore.selectedSatellitePassesLoaded) return true
    for (let index = 0; index < this.objectDetailStore.selectedDetailFields.length; index++) {
      if (this.objectDetailStore.selectedDetailFields[index].key === 'tleEpoch') return true
    }
    const type = (this.objectDetailStore.selectedType + ' ' + this.objectDetailStore.selectedObjectType).toLowerCase()
    return type.indexOf('artificial satellite') >= 0 || type.indexOf('人造卫星') >= 0
  }


  private selectedSatelliteTleEpoch(): string {
    if (this.objectDetailStore.selectedSatellitePasses.length === 0) return ''
    return this.objectDetailStore.selectedSatellitePasses[0].tleEpoch ?? ''
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
        title: this.panelTitle(), subtitle: this.panelSubtitle(), canGoBack: this.canGoBackPanel(),
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
        title: this.panelTitle(), subtitle: this.panelSubtitle(), canGoBack: this.canGoBackPanel(),
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
        subColor: this.nmSub(), languageRevision: this.languageStore.languageRevision,
        onOpenPanel: (panel: string) => { this.openSubPanel(panel) }
      })
    } else if (this.activePanel === 'dataHub') {
      HubActionList({
        actions: skyDataHubActions(), description: I18n.t('more_sky_data_desc'),
        subColor: this.nmSub(), languageRevision: this.languageStore.languageRevision,
        onOpenPanel: (panel: string) => { this.openSubPanel(panel) }
      })
    } else if (this.activePanel === 'automationHub') {
      HubActionList({
        actions: automationHubActions(), description: I18n.t('more_automation_desc'),
        subColor: this.nmSub(), languageRevision: this.languageStore.languageRevision,
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
        imageHeight: this.objectInspectorImageHeight(),
        iconName: this.objectInspectorIcon(),
        inlineModelSize: this.objectInspectorInlineModelSize(),
        modelReady: this.objectInspectorModelReady(),
        modelRendering: this.objectInspectorModelRendering,
        hasModelTexture: this.objectInspectorModelTexturePixels !== undefined,
        modelNotice: this.objectInspectorModelNotice(),
        warmupText: this.objectInspectorMediaWarmupText(),
        fallbackKind: this.objectInspectorFallbackVisualKind(),
        starColor: this.objectInspectorStarColor(),
        satVisible: this.selectedObjectIsArtificialSatellite(),
        tleEpoch: this.selectedSatelliteTleEpoch(),
        textColor: this.nmText(),
        panelColor: this.nmBg(),
        borderTint: this.nmBorder(),
        accentColor: this.nmAccent(),
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
        onSpeak: () => { this.speakSelectedObject() },
        onOpenMedia: () => { this.openObjectInspectorMediaPreview() },
        onRetryMedia: () => { this.retryObjectInspectorMedia() },
        onModelExpand: () => { this.setObjectInspectorModelImmersive(true) },
        onModelTouch: (event: TouchEvent) => { this.handleObjectInspectorModelTouch(event) },
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
        textColor: this.nmText(),
        subColor: this.nmSub(),
        accentColor: this.nmAccent(),
        panelColor: this.nmBg(),
        inputColor: this.nmInput(),
        borderTint: this.nmBorder(),
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
        mapWidth: this.locationMapWidth(),
        mapHeight: this.locationMapHeight(),
        textColor: this.nmText(),
        subColor: this.nmSub(),
        inputColor: this.nmInput(),
        accentColor: this.nmAccent(),
        panelColor: this.nmBg(),
        borderTint: this.nmBorder(),
        planetLabel: (en: string) => planetZh(en),
        contextOf: (item: LocSearchItem) => this.locationResultContext(item),
        onUseDeviceLocation: () => { this.useDeviceLocation() },
        onSearchLocations: (query: string) => { this.searchLocations(query) },
        onPickSearchItem: (item: LocSearchItem) => { this.selectSearchLocation(item) },
        onApply: () => { this.applyPickerLocation() },
        onMapTouch: (event: TouchEvent) => this.handleLocationMapTouch(event),
        onSelectContinent: (c: string) => { this.selectContinent(c) },
        onSelectCountry: (c: string) => { this.selectCountry(c) },
        onSelectRegion: (r: string) => { this.selectRegion(r) },
        onSelectCity: (c: string) => { this.selectCityByName(c) },
        onSaveCurrent: () => { this.saveCurrentLocation() },
        onApplyLocation: (name: string, lat: number, lon: number, alt: number, planet: string) => { this.setLocation(name, lat, lon, alt, planet) },
        onDeleteLocation: (name: string) => { this.deleteSavedLocation(name) },
        onChip: (id: string) => { this.handleChip(id) },
        onSelectPlanet: (name: string) => { this.setObserverPlanet(name) },
        onPoint: () => { this.pointAtSkyTest() },
        onSend: () => { this.watchGyroSend() },
        onStart: () => { this.watchGyroStart() },
        onStop: () => { this.watchGyroStop() },
        onExport: () => { this.sessionExport() },
        onSessionApply: () => { this.sessionApply() },
        onHandoff: () => { this.sessionHandoff() },
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
        narrationParagraphs: this.skyCultureNarrationParagraphs(),
        mapContext: this.skyCultureMapContext,
        textColor: this.nmText(),
        subColor: this.nmSub(),
        accentColor: this.nmAccent(),
        panelColor: this.nmBg(),
        cardBorder: this.nmBorder(),
        inputColor: this.nmInput(),
        pickerSurface: this.nmPickerSurface(),
        pickerHeader: this.nmPickerHeader(),
        pickerHeaderActive: this.nmPickerHeaderActive(),
        pickerSelected: this.nmPickerSelected(),
        pickerOption: this.nmPickerOption(),
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
        textColor: this.nmText(),
        subColor: this.nmSub(),
        accentColor: this.nmAccent(),
        panelColor: this.nmBg(),
        lineColor: this.nmBorder(),
        onSetSetting: (setting: string, value: string) => { this.setPointerCoordinates(setting, value) }
      })
    } else if (this.activePanel === 'commands') {
      CommandsPanel({
        commandStore: this.commandStore,
        textColor: this.nmText(),
        subColor: this.nmSub(),
        inputColor: this.nmInput(),
        accentColor: this.nmAccent(),
        panelColor: this.nmBg(),
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
        textColor: this.nmText(),
        subColor: this.nmSub(),
        accentColor: this.nmAccent(),
        panelColor: this.nmBg(),
        lineColor: this.nmBorder(),
        onToggleGyroscope: (v: boolean) => { this.toggleGyroscope(v); this.flashHint(v ? I18n.t('s0719') : I18n.t('s0720')) },
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
        visibilityLabel: this.searchVisibilityLabel(),
        instrumentLabel: this.searchInstrumentLabel(),
        categories: this.searchAllCategoryOptions(),
        categoryIconKey: this.searchCategoryIcon(this.searchStore.searchCategory),
        categoryLabel: this.searchCategoryLabel(),
        textColor: this.nmText(),
        subColor: this.nmSub(),
        panelColor: this.nmBg(),
        inputColor: this.nmInput(),
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
        suggestionSubtitle: (title: string, englishName: string) => { return this.celestialSubtitle(title, englishName) },
        onSelectSuggestion: (item: SearchSug) => { this.selectSearchSuggestion(item) },
        iconFor: (item: NameItem) => { return this.categoryObjectIcon(item) },
        categorySubtitle: (item: NameItem) => { return this.categoryObservationSubtitle(item) },
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
        textColor: this.nmText(),
        subColor: this.nmSub(),
        accentColor: this.nmAccent(),
        panelColor: this.nmBg(),
        lineColor: this.nmBorder(),
        inputColor: this.nmInput(),
        informationMaskHas: (key: string) => { return this.informationMaskHas(key) },
        pluginMetaLine: (plugin: PluginItem) => { return this.pluginMetaLine(plugin) },
        pluginFeatureDestination: (id: string) => { return this.pluginFeatureDestination(id) },
        pluginFeatureIsActionable: (id: string) => { return this.pluginFeatureIsActionable(id) },
        pluginFeatureActionLabel: (id: string) => { return this.pluginFeatureActionLabel(id) },
        scriptMetaLine: (filename: string) => { return this.scriptMetaLine(filename) },
        scriptSourceLine: (filename: string) => { return this.scriptSourceLine(filename) },
        hasSelectedObject: () => { return this.hasSelectedObject() },
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
        saveCurrentViewAsStartup: () => { this.saveCurrentViewAsStartup() },
        setViewLockState: (enabled: boolean) => { this.setViewLockState(enabled) },
        setNavigationBoolean: (setting: string, enabled: boolean) => { this.setNavigationBoolean(setting, enabled) },
        setNavigationMaxFov: (value: number) => { this.setNavigationMaxFov(value) },
        selectSettingsChoice: (group: string, value: string) => { this.selectSettingsChoice(group, value) },
        setStartupTimeSetting: (key: string, value: string) => { this.setStartupTimeSetting(key, value) },
        setInformationField: (key: string, enabled: boolean) => { this.setInformationField(key, enabled) },
        setObjectDetailConnector: (enabled: boolean) => { this.setObjectDetailConnector(enabled) },
        toggleGyroscope: (enabled: boolean) => { this.toggleGyroscope(enabled) },
        confirmPrivacyRevocation: () => { this.confirmPrivacyRevocation() },
        loadPluginList: () => { this.pluginStore.loadPluginList() },
        openPluginFeature: (id: string) => { this.openPluginFeature(id) },
        playScriptByName: (filename: string) => { this.playScriptByName(filename) },
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
        textColor: this.nmText(),
        subColor: this.nmSub(),
        panelColor: this.nmBg(),
        accentColor: this.nmAccent(),
        lineColor: this.nmBorder(),
        scroller: this.astroPanelScroller,
        host: {
          almanacHoursLabel: (key: string) => this.almanacHoursLabel(key),
          altAzMaxLabel: () => this.altAzMaxLabel(),
          altAzMidpointLabel: () => this.altAzMidpointLabel(),
          altAzNowLabel: () => this.altAzNowLabel(),
          altAzRangeLabel: () => this.altAzRangeLabel(),
          altAzVisibleHours: () => this.altAzVisibleHours(),
          altBarHeight: (alt: number | undefined) => this.altBarHeight(alt),
          altBarWidth: () => this.altBarWidth(),
          altCurveSegmentWidth: () => this.altCurveSegmentWidth(),
          altitudeCurveColor: (altitude: number | undefined, color: string) => this.altitudeCurveColor(altitude, color),
          annualBarHeight: (altitude: number | undefined) => this.annualBarHeight(altitude),
          annualBarWidth: () => this.annualBarWidth(),
          annualMaxLabel: () => this.annualMaxLabel(),
          astroNeedsSelectedObject: () => this.astroNeedsSelectedObject(),
          azimuthNowLabel: () => this.azimuthNowLabel(),
          callNative: (name: string, payload?: string) => { this.callNative(name, payload) },
          celestialPositionSubtitle: (position: CelestialPosition) => this.celestialPositionSubtitle(position),
          celestialPositionTitle: (position: CelestialPosition) => this.celestialPositionTitle(position),
          chooseEclipseStartDate: () => { this.chooseEclipseStartDate() },
          chooseEphemerisStartDate: () => { this.chooseEphemerisStartDate() },
          chooseGraphStartDate: () => { this.chooseGraphStartDate() },
          chooseRtsCalendarStartDate: () => { this.chooseRtsCalendarStartDate() },
          eclipseStartOptionLabel: (offsetDays: number) => this.eclipseStartOptionLabel(offsetDays),
          ephemerisStartOptionLabel: (offsetDays: number) => this.ephemerisStartOptionLabel(offsetDays),
          exportCurrentAstroCsv: () => this.exportCurrentAstroCsv(),
          filteredEclipses: () => this.filteredEclipses(),
          fmtClock: (s: string | undefined) => this.fmtClock(s),
          fmtDateTime: (s: string | undefined) => this.fmtDateTime(s),
          fmtEphemerisDate: (s: string | undefined) => this.fmtEphemerisDate(s),
          fmtNum: (v: number | undefined, digits: number, suffix: string) => this.fmtNum(v, digits, suffix),
          graphCustomStartLabel: () => this.graphCustomStartLabel(),
          graphTargetLabel: () => this.astroStore.graphTargetLabel(),
          hasSelectedObject: () => this.hasSelectedObject(),
          hecPointColor: (position: HeliocentricPosition) => this.hecPointColor(position),
          hecPointLeft: (position: HeliocentricPosition) => this.hecPointLeft(position),
          hecPointTop: (position: HeliocentricPosition) => this.hecPointTop(position),
          hecTitle: (position: HeliocentricPosition) => this.hecTitle(position),
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
          lunarElongationBarWidth: () => this.lunarElongationBarWidth(),
          lunarElongationClosestLabel: () => this.lunarElongationClosestLabel(),
          lunarElongationLineTop: () => this.lunarElongationLineTop(),
          lunarElongationNowLabel: () => this.lunarElongationNowLabel(),
          markRtsCalendarForRegeneration: () => { this.astroStore.markRtsCalendarForRegeneration() },
          openAstroTargetPicker: () => { this.openAstroTargetPicker() },
          openEphemerisTargetPicker: () => { this.openEphemerisTargetPicker() },
          openGraphTargetPicker: () => { this.openGraphTargetPicker() },
          openRtsTargetPicker: () => { this.openRtsTargetPicker() },
          phenomenaBodyName: (body: string) => this.astroStore.phenomenaBodyName(body),
          planetPairBarWidth: () => this.planetPairBarWidth(),
          planetPairCurrentIndex: () => this.planetPairCurrentIndex(),
          planetPairSegmentWidth: () => this.planetPairSegmentWidth(),
          planetTimeSeriesBarWidth: () => this.planetTimeSeriesBarWidth(),
          planetTimeSeriesSegmentWidth: () => this.planetTimeSeriesSegmentWidth(),
          planetTimeSeriesValueLabel: (value: number | undefined, metric: string) => this.planetTimeSeriesValueLabel(value, metric),
          publishAstroPanelState: () => { this.publishAstroPanelState() },
          reloadCurrentGraph: () => { this.reloadCurrentGraph() },
          reloadEclipses: () => { this.astroStore.reloadEclipses() },
          rtsCalendarStartOptionLabel: (offsetDays: number) => this.rtsCalendarStartOptionLabel(offsetDays),
          searchObject: (name: string, catalogModuleId?: string, exactSelectionPayload?: string, placement?: string) => { this.searchObject(name, catalogModuleId, exactSelectionPayload, placement) },
          selectAstroFilter: (key: string, value: string) => { this.selectAstroFilter(key, value) },
          selectAstroGroup: (group: number) => { this.selectAstroGroup(group) },
          selectAstroTab: (tab: number) => { this.selectAstroTab(tab) },
          wutCategoryTitle: () => this.wutStore.wutCategoryTitle(),
          wutTargetSubtitle: (target: WutTarget) => this.wutTargetSubtitle(target),
          wutTargetTitle: (target: WutTarget) => this.wutTargetTitle(target),
        }
      })
        } else if (this.activePanel === 'help') {
      HelpPanel({
        tools: this.tools,
        textColor: this.nmText(),
        subColor: this.nmSub(),
        lineColor: this.nmBorder(),
        accentColor: this.nmAccent(),
        panelColor: this.nmBg(),
        onOpenTools: () => { this.openSubPanel('tools') }
      })
	    } else if (this.activePanel === 'catalogs') {
      CatalogsPanel({
        catalogStore: this.catalogStore,
        cardBorderColor: this.nmBorder(),
        onDownload: (id: string) => { this.startCatalogDownload(id) }
      })
    } else if (this.activePanel === 'bookmarks') {
      BookmarkPanel({
        store: this.bookmarkStore,
        selectedName: this.objectDetailStore.selectedName,
        cardBorderColor: this.nmBorder(),
        onSaveView: () => { this.addCurrentBookmark() },
        onGoto: (id: string) => { this.gotoBookmark(id) },
        onDelete: (id: string) => { this.deleteBookmark(id) }
      })
    } else if (this.activePanel === 'oculars') {
      OcularsPanel({
        store: this.telescopeStore,
        textColor: this.nmText(),
        subColor: this.nmSub(),
        accentColor: this.nmAccent(),
        panelColor: this.nmBg(),
        lineColor: this.nmBorder(),
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
        textColor: this.nmText(),
        subColor: this.nmSub(),
        panelColor: this.nmBg(),
        accentColor: this.nmAccent(),
        onSetSetting: (setting: string, value: string) => { this.setMosaicCamera(setting, value) }
      })
    } else if (this.activePanel === 'archaeoLines') {
      ArchaeoLinesPanel({
        archaeoStore: this.archaeoStore,
        textColor: this.nmText(),
        subColor: this.nmSub(),
        panelColor: this.nmBg(),
        accentColor: this.nmAccent(),
        borderTint: this.nmBorder(),
        onSetSetting: (setting: string, value: string) => { this.setArchaeoLineSetting(setting, value) },
        onLineWidthPreview: (value: number) => { this.archaeoStore.archaeoLineWidth = value },
        onSetLineWidth: (value: number) => { this.setArchaeoLineSetting('lineWidth', value.toString()) }
      })
    } else if (this.activePanel === 'angleMeasure') {
      AngleMeasurePanel({
        store: this.tools,
        textColor: this.nmText(),
        subColor: this.nmSub(),
        panelColor: this.nmBg(),
        accentColor: this.nmAccent(),
        onToggle: (enabled: boolean) => { this.tools.toggleAngleMeasure(enabled) },
        onReset: () => { this.resetAngleMeasure() }
      })
    } else if (this.activePanel === 'navStars') {
      NavStarsPanel({
        navStarsStore: this.navStarsStore,
        textColor: this.nmText(),
        subColor: this.nmSub(),
        panelColor: this.nmBg(),
        accentColor: this.nmAccent(),
        onSetSetting: (setting: string, value: string) => { this.navStarsStore.setNavStarsSetting(setting, value) }
      })
    } else if (this.activePanel === 'satellites') {
      SatellitesPanel({
        satelliteStore: this.satelliteStore,
        textColor: this.nmText(),
        subColor: this.nmSub(),
        panelColor: this.nmBg(),
        inputColor: this.nmInput(),
        accentColor: this.nmAccent(),
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
        onQueryChange: (value: string) => { this.satelliteStore.satQuery = value; this.loadSatellites() },
        onSubmitQuery: () => { this.loadSatellites(false, true) },
        onSearchObject: (item: SatelliteListItem) => { this.searchObject(item.name, '', 'object|Satellite|' + item.id) }
      })
    } else if (this.activePanel === 'meteorshowers') {
      MeteorShowersPanel({
        meteorStore: this.meteorStore,
        panelColor: this.nmBg(),
        onSetFlag: (flag: string, value: boolean) => { this.meteorStore.setMeteorShowersFlag(flag, value) },
        onSearch: (name: string) => { this.searchObject(name, '', '', 'center') }
      })
    } else if (this.activePanel === 'scenery3d') {
      Scenery3dPanel({
        sceneryStore: this.sceneryStore,
        textColor: this.nmText(),
        subColor: this.nmSub(),
        panelColor: this.nmBg(),
        accentColor: this.nmAccent(),
        onToggleEnabled: (enabled: boolean) => { this.setScenery3dEnabled(enabled) },
        onSelectScene: (id: string) => { this.setScenery3dScene(id) }
      })
    } else if (this.activePanel === 'skyCultureMaker') {
      SkyCultureMakerPanel({
        store: this.skyCultureMakerStore,
        panelWidth: this.panelWidth,
        subColor: this.nmSub(), textColor: this.nmText(), accentColor: this.nmAccent(), bgColor: this.nmBg(),
        inputColor: this.nmInput(), inputBorderColor: this.nmInputBorder(),
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
        onShare: () => { this.shareFile(this.skyCultureMakerStore.exportPath, utd.UniformDataType.ZIP_ARCHIVE, this.skyCultureMakerStore.exportFileName, I18n.t('sky_culture_maker_share_description'), 'sky-culture-maker-share') },
        onSaveAs: () => { this.saveFileAs(this.skyCultureMakerStore.exportPath, this.skyCultureMakerStore.exportFileName, 'ZIP 压缩包|.zip') },
        onSaveDraft: () => { this.saveSkyCultureMakerDraft(false) },
        onUndo: () => { this.undoSkyCultureMaker() },
        onReset: () => { this.resetSkyCultureMaker() }
      })
        } else if (this.activePanel === 'nebulaTextures') {
      NebulaTexturesPanel({
        store: this.nebulaTextureStore,
        textColor: this.nmText(),
        subColor: this.nmSub(),
        accentColor: this.nmAccent(),
        panelColor: this.nmBg(),
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
        guideSessionActive: this.scriptSessionActive(),
        scriptStore: this.scriptStore,
        textColor: this.nmText(),
        subColor: this.nmSub(),
        accentColor: this.nmAccent(),
        panelColor: this.nmBg(),
        lineColor: this.nmBorder(),
        scriptMetaLine: (filename: string) => { return this.scriptMetaLine(filename) },
        scriptSourceLine: (filename: string) => { return this.scriptSourceLine(filename) },
        onStartGuide: (id: string) => { this.executeGuideRequest('startGuide', id) },
        onStopPlayback: () => { this.stopScriptPlayback() },
        onImportScript: () => { this.importScriptFile() },
        onPlayScript: (name: string) => { this.playScriptByName(name) },
        onToggleRecording: () => { this.tools.recording ? this.stopRecording() : this.startRecording() },
        onSaveRecording: () => { this.saveCurrentRecording() },
        onSetRecordName: (value: string) => { this.scriptStore.recordName = value },
        onPlayRecording: (file: string) => { this.playRecording(file) },
        onLoadRecording: (file: string, name: string) => { this.scriptStore.loadRecordingByName(file, name) },
        onShareRecording: (rec: RecordingEntry, idx: number) => {
          this.shareFile(rec.path ?? '', utd.UniformDataType.PLAIN_TEXT, rec.name,
            'Stellarium 操作录制', 'recording-share-' + idx.toString())
        },
        onDeleteRecording: (file: string) => { this.deleteRecording(file) },
        onToggleScreenVideo: () => {
          if (this.scriptStore.screenVideoRecording) this.stopScreenVideoRecording()
          else this.startScreenVideoRecording()
        },
        onSaveScreenVideoToGallery: (result: SaveButtonOnClickResult) => { this.saveScreenVideoToGallery(result) },
        onShareScreenVideo: () => {
          this.shareFile(this.scriptStore.screenVideoPath, utd.UniformDataType.VIDEO, this.scriptStore.screenVideoFileName,
            'Stellarium 屏幕视频', 'screen-video-share')
        },
        onSaveScreenVideoAs: () => { this.saveFileAs(this.scriptStore.screenVideoPath, this.scriptStore.screenVideoFileName, 'MP4 视频|.mp4') },
        onSetVideoFps: (value: string) => { this.scriptStore.videoFps = value },
        onSetVideoDuration: (value: string) => { this.scriptStore.videoDuration = value },
        onToggleVideoRecording: () => { this.scriptStore.videoRecording ? this.stopVideoRecording() : this.startVideoRecording() },
        onShareVideoArchive: () => {
          this.shareFile(this.scriptStore.videoArchivePath, utd.UniformDataType.ZIP_ARCHIVE,
            this.scriptStore.videoArchiveFileName, 'Stellarium 高质量星图帧序列', 'video-frames-share')
        },
        onExportVideoArchive: () => { this.saveFileAs(this.scriptStore.videoArchivePath, this.scriptStore.videoArchiveFileName, 'ZIP 压缩包|.zip') }
      })
    } else if (this.activePanel === 'observing') {
      ObservingPanel({
        wutStore: this.wutStore,
        observingListStore: this.obsListStore,
        textColor: this.nmText(),
        subColor: this.nmSub(),
        panelColor: this.nmBg(),
        borderTint: this.nmBorder(),
        accentColor: this.nmAccent(),
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
        targetSubtitleOf: (target: WutTarget) => this.wutTargetSubtitle(target),
        typeOf: (type: string) => zhType(type),
        displayNameOf: (name: string) => this.observingDisplayName(name)
      })
    } else if (this.activePanel === 'telescope') {
      TelescopePanel({
        store: this.telescopeStore,
        textColor: this.nmText(), subColor: this.nmSub(), accentColor: this.nmAccent(),
        panelColor: this.nmBg(), inputColor: this.nmInput(), lineColor: this.nmBorder(), inputLineColor: this.nmInputBorder(),
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
        onSetLivePosition: (enabled: boolean) => { this.setTelescopeLivePosition(enabled) }
      })
    } else if (this.activePanel === 'tools') {
      ToolsPanel({
        store: this.tools,
        textColor: this.nmText(), subColor: this.nmSub(), panelColor: this.nmBg(), inputColor: this.nmInput(),
        configImportText: this.tools.configImportText,
        sessionImportText: this.tools.sessionImportText,
        onScreenshot: () => { this.saveScreenshot() },
        onExportConfig: () => { this.exportConfig() },
        onImportConfig: () => { this.importConfig() },
        onConfigImportText: (value: string) => { this.tools.configImportText = value },
        onSessionExport: () => { this.sessionExport() },
        onSessionApply: () => { this.sessionApply() },
        onSessionImportText: (value: string) => { this.tools.sessionImportText = value },
        onLoadLog: () => { this.tools.loadLog() },
        onCollapseLog: () => { this.tools.logVisible = false }
      })
    } else if (this.activePanel === 'audio') {
      AudioPanel({
        audioStore: this.audioStore,
        textColor: this.nmText(),
        panelColor: this.nmBg(),
        accentColor: this.nmAccent(),
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
        panelColor: this.nmBg(),
        observingDisplayName: (name: string) => { return this.observingDisplayName(name) },
        selectObservingTarget: (name: string) => { this.searchObject(name); this.flashHint(I18n.t('i0082')) },
        removeObservingTarget: (name: string) => { this.removeObservingTarget(name) },
        clearObservingList: () => { this.obsListStore.observingList = []; this.persistObservingList(); this.flashHint(I18n.t('i0302')) },
        setLegacyDistanceUnit: (useMetric: boolean) => {
          this.viewSettingsStore.useMetricUnits = useMetric
          this.callInteractive('setConfigString', 'astronomy/flag_use_km_for_distance=' + (useMetric ? 'true' : 'false'), () => {})
        },
        handleChip: (id: string) => { this.handleChip(id) },
        toggleGyroscope: (enabled: boolean) => { this.toggleGyroscope(enabled) },
        flashHint: (text: ResourceStr) => { this.flashHint(text) },
        setLanguage: (lang: string) => { this.setLanguage(lang) },
        setSkyCulture: (culture: string) => { this.setSkyCulture(culture) },
        triggerAction: (actionId: string) => { this.triggerAction(actionId) },
        refreshState: () => { this.refreshState() },
        saveScreenshot: () => { this.saveScreenshot() }
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
        this.setLocation(cityId, preset.lat, preset.lon, preset.alt)
      }
    } else if (id === 'Beijing') {
      this.setLocation('Beijing', 39.9042, 116.4074, 44)
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

  private panelTitle(): ResourceStr {
    if (this.activePanel === 'more') {
      return I18n.t('c_more_functions')
    }
    if (this.activePanel === 'observeHub') {
      return I18n.t('more_workspace_observing')
    }
    if (this.activePanel === 'dataHub') {
      return I18n.t('more_sky_data')
    }
    if (this.activePanel === 'automationHub') {
      return I18n.t('more_automation')
    }
    if (this.activePanel === 'search') {
      return this.isExpandedLayout ? '探索' : I18n.t('i0021')
    }
    if (this.activePanel === 'observing') {
      return I18n.t('panel_observing_list')
    }
    if (this.activePanel === 'time') {
      return I18n.t('i0054') + ' ' + this.timePanelClockText()
    }
    if (this.activePanel === 'place') {
      return I18n.t('i0014')
    }
    if (this.activePanel === 'layers') {
      return I18n.t('i0100')
    }
    if (this.activePanel === 'config') {
      return I18n.t('i0273')
    }
    if (this.activePanel === 'astro') {
      return I18n.t('i0274')
    }
    if (this.activePanel === 'help') {
      return I18n.t('i0217')
    }
    if (this.activePanel === 'settings') {
      if (this.configTab === 6) return I18n.t('more_plugins_manage')
      if (this.configTab === 7) return I18n.t('settings_view_navigation')
      if (this.configTab === 4) return I18n.t('c0004')
      if (this.configTab === 5) return I18n.t('c0005')
      if (this.configTab === 3) return I18n.t('c0003')
      if (this.configTab === 2) return I18n.t('c0002')
      if (this.configTab === 1) return I18n.t('c0001')
      if (this.configTab === -1) return I18n.t('settings_device_privacy')
      return I18n.t('i0102')
    }
    if (this.activePanel === 'catalogs') {
      return I18n.t('p_catalogs')
    }
    if (this.activePanel === 'bookmarks') {
      return I18n.t('p_bookmarks')
    }
    if (this.activePanel === 'oculars') {
      return I18n.t('p_oculars')
    }
    if (this.activePanel === 'mosaicCamera') {
      return I18n.t('p_mosaic_camera')
    }
    if (this.activePanel === 'archaeoLines') {
      return I18n.t('p_archaeo_lines')
    }
    if (this.activePanel === 'angleMeasure') {
      return I18n.t('panel_angle_measure')
    }
    if (this.activePanel === 'navStars') {
      return I18n.t('panel_nav_stars')
    }
    if (this.activePanel === 'satellites') {
      return I18n.t('p_satellites')
    }
    if (this.activePanel === 'meteorshowers') {
      return I18n.t('p_meteors')
    }
    if (this.activePanel === 'scenery3d') {
      return I18n.pluginName('Scenery3d')
    }
    if (this.activePanel === 'nebulaTextures') {
      return I18n.t('nebula_texture_title')
    }
    if (this.activePanel === 'skyCultureMaker') {
      return I18n.t('sky_culture_maker_title')
    }
    if (this.activePanel === 'pointerCoordinates') {
      return I18n.t('p_pointer_coordinates')
    }
    if (this.activePanel === 'scripts') {
      return I18n.t('p_scripts')
    }
    if (this.activePanel === 'commands') {
      return I18n.t('panel_commands')
    }
    if (this.activePanel === 'telescope') {
      return I18n.t('panel_telescope_control')
    }
    if (this.activePanel === 'tools') {
      return I18n.t('panel_tools_data')
    }
    return I18n.t('i0101')
  }

  private panelSubtitle(): string {
    if (this.activePanel === 'time') {
      return this.timePanelDateText()
    }
    return ''
  }

  /** 面板标题行的时分秒：从 timeStore.observationTimeText 拆出第一个空格之后的部分。 */
  private timePanelClockText(): string {
    const text = this.timeStore.observationTimeText
    const idx = text.indexOf(' ')
    return idx > 0 ? text.substring(idx + 1) : text
  }

  /** 面板副标题行的年月日（附带当前时间速率）。 */
  private timePanelDateText(): string {
    const text = this.timeStore.observationTimeText
    const idx = text.indexOf(' ')
    const date = idx > 0 ? text.substring(0, idx) : ''
    return date.length > 0 ? date + ' · ' + this.timeStore.timeRateText : this.timeStore.timeRateText
  }

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
        this.loadVideoRecordingState()
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
