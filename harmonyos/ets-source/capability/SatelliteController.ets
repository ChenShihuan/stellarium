// 卫星（Satellites）行为控制器（STATE-REVIEW §10.2 D13，PLAN §15 D 轨道 D13）。
//
// 原宿主 MainWindowNativeNode 的 8 个行为方法逐字下沉：
//   selectSatelliteGroup / setSatelliteUpdateSetting / addSatelliteSource / deleteSatelliteSource
//   / importSatelliteTleFile / refreshSatelliteCatalog / setSatelliteFlag / frameSatellite。
//
// STATE-REVIEW 记「11 法」；工作区实测卫星域共 9 个 private 方法（1 publish* + 8 行为）：
//   - `publishSatellitePanelState` 写 AppStorage，属 §15.6-4 的 `publish*` 保留项 —— 只迁调用方，
//     本体留宿主，经 SatelliteHostHooks 回注；
//   - `requestSatellitePasses` 归选中/详情管线（M3-3 登记），不属本片。
//
// **不 import NAPI/UI**（§15.7 规则 1）：桥经 CommandPort；状态整体写 SatelliteStore
//（SatellitesPanel 经 @ObjectLink 消费）；`selectSatelliteGroup` 的 180ms 分组过渡动画
//（getUIContext().animateTo）与 CLI 发布点经 SatelliteHostHooks 回注。
import { I18n } from '../pages/I18n'
import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import { SatelliteSourceInput } from '../pages/MainWindowModels'
import { CommandPort } from '../bridge/CommandPort'
import { SatelliteStore } from '../state/SatelliteStore'

export interface SatelliteHostHooks {
  // §15.6-4 保留的 CLI 发布点（宿主 publishSatellitePanelState，写 AppStorage）。
  publishSatellitePanelState(error: string): void
  // 分组切换的 180ms EaseOut 过渡（宿主 getUIContext().animateTo，控制器不 import UI）。
  animateSatelliteGroupChange(action: () => void): void
}

export class SatelliteController {
  private port: CommandPort
  private satelliteStore: SatelliteStore
  private hooks: SatelliteHostHooks

  constructor(port: CommandPort, satelliteStore: SatelliteStore, hooks: SatelliteHostHooks) {
    this.port = port
    this.satelliteStore = satelliteStore
    this.hooks = hooks
  }

  // 原宿主 selectSatelliteGroup()：校验分组 → 过渡动画切换 → 重载。
  selectSatelliteGroup(group: string): void {
    if (group.length > 0 && !this.satelliteStore.satGroups.includes(group)) {
      this.hooks.publishSatellitePanelState('unknown satellite group')
      return
    }
    if (this.satelliteStore.activeSatGroup === group) {
      this.hooks.publishSatellitePanelState('')
      return
    }
    this.hooks.animateSatelliteGroupChange(() => {
      this.satelliteStore.activeSatGroup = group
    })
    this.satelliteStore.loadSatellites()
  }

  // 原宿主 setSatelliteUpdateSetting()：单个更新设置写回 → 重载来源。
  setSatelliteUpdateSetting(key: string, value: boolean | number): void {
    const payload: Record<string, boolean | number> = {}
    payload[key] = value
    this.port.requestInteractive('setSatelliteUpdateSetting', JSON.stringify(payload), () => {
      this.satelliteStore.loadSatelliteSources()
    }, (failure: StellariumBridgeResponse) => { this.satelliteStore.satSourceStatus = failure.error ?? I18n.t('sat_source_invalid') })
  }

  // 原宿主 addSatelliteSource()：把输入框 URL 追加为来源写回。
  addSatelliteSource(): void {
    const url = this.satelliteStore.satSourceInput.trim()
    if (url.length === 0) { this.satelliteStore.satSourceStatus = I18n.t('sat_source_empty'); return }
    const sources: SatelliteSourceInput[] = []
    for (const source of this.satelliteStore.satSources) sources.push({ url: source.url, addNew: source.addNew })
    sources.push({ url: url, addNew: this.satelliteStore.satSourceAddNew })
    this.port.requestInteractive('setSatelliteSources', JSON.stringify({ sources: sources }), (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.satelliteStore.satSourceInput = ''
        this.satelliteStore.satSourceStatus = I18n.t('sat_source_saved')
        this.satelliteStore.loadSatelliteSources()
      } else this.satelliteStore.satSourceStatus = r.error ?? I18n.t('sat_source_invalid')
    }, (failure: StellariumBridgeResponse) => { this.satelliteStore.satSourceStatus = failure.error ?? I18n.t('sat_source_invalid') })
  }

  // 原宿主 deleteSatelliteSource()：按索引剔除来源后写回。
  deleteSatelliteSource(index: number): void {
    const sources: SatelliteSourceInput[] = []
    for (let sourceIndex = 0; sourceIndex < this.satelliteStore.satSources.length; sourceIndex++) {
      if (sourceIndex !== index) {
        const source = this.satelliteStore.satSources[sourceIndex]
        sources.push({ url: source.url, addNew: source.addNew })
      }
    }
    this.port.requestInteractive('setSatelliteSources', JSON.stringify({ sources: sources }), (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.satelliteStore.satSourceStatus = I18n.t('sat_source_deleted')
        this.satelliteStore.loadSatelliteSources()
      } else this.satelliteStore.satSourceStatus = r.error ?? I18n.t('sat_source_invalid')
    }, (failure: StellariumBridgeResponse) => { this.satelliteStore.satSourceStatus = failure.error ?? I18n.t('sat_source_invalid') })
  }

  // 原宿主 importSatelliteTleFile()：把输入框路径导入为 TLE 来源。
  importSatelliteTleFile(): void {
    const path = this.satelliteStore.satTleFileInput.trim()
    if (path.length === 0) { this.satelliteStore.satSourceStatus = I18n.t('sat_tle_path_empty'); return }
    this.port.requestInteractive('importSatelliteTle', JSON.stringify({ paths: [path] }), (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.satelliteStore.satTleFileInput = ''
        this.satelliteStore.satSourceStatus = I18n.t('sat_tle_imported')
        this.satelliteStore.loadSatellites(true, true)
      } else this.satelliteStore.satSourceStatus = r.error ?? I18n.t('sat_tle_import_failed')
    }, (failure: StellariumBridgeResponse) => { this.satelliteStore.satSourceStatus = failure.error ?? I18n.t('sat_tle_import_failed') })
  }

  // 原宿主 refreshSatelliteCatalog()：刷新目录（离线构建回退提示）。
  refreshSatelliteCatalog(): void {
    this.port.requestInteractive('refreshSatelliteCatalog', '', (r: StellariumBridgeResponse) => {
      this.satelliteStore.satSourceStatus = r.ok === true ? I18n.t('sat_refresh_started') : (r.error ?? I18n.t('sat_refresh_offline'))
      this.satelliteStore.loadSatelliteSources()
    }, (failure: StellariumBridgeResponse) => { this.satelliteStore.satSourceStatus = failure.error ?? I18n.t('sat_refresh_offline') })
  }

  // 原宿主 setSatelliteFlag()：显示开关写回（同值短路 + mutationId 代际回滚）。
  setSatelliteFlag(name: string, v: boolean): void {
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
    this.port.requestWhenReady('setSatellitesFlag', name + ':' + (v ? '1' : '0'), () => {}, () => {
      if (mutationId !== this.satelliteStore.satelliteFlagMutationId || previous === undefined) return
      if (name == 'labels') this.satelliteStore.satLabels = previous
      else if (name == 'orbitLines') this.satelliteStore.satOrbitLines = previous
      else if (name == 'hints') this.satelliteStore.satHints = previous
      else if (name == 'iconicMode') this.satelliteStore.satIconicMode = previous
      else if (name == 'hideInvisible') this.satelliteStore.satHideInvisible = previous
    }, 0, 100, 15)
  }

  // 原宿主 frameSatellite()：跳转后若视角过窄，拉远到 16° 以便框入月球(卫星)。
  frameSatellite(): void {
    this.port.requestWhenReady('getSessionState', '', (r: StellariumBridgeResponse) => {
      const fov = (r.fovDeg ?? 0)
      if (fov > 0 && fov < 12) {
        const target = 16
        this.port.requestWhenReady('zoomBy', (target / fov).toFixed(3) + '|0', () => {})
      }
    })
  }
}
