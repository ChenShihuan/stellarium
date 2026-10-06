import {
  SatelliteListItem,
  SatelliteSource,
  SatelliteUpdateSettings,
  SatelliteSourcesResponse,
  SatellitesResponse,
  CatalogHealthEntry
} from '../pages/MainWindowModels'
import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import { CommandPort } from '../bridge/CommandPort'

// 卫星域 store：持有卫星分组/列表/查询、TLE 源与更新设置、目录健康等状态，
// 由 SatellitesPanel 经 @ObjectLink 观察。桥经 attachPort 注入 CommandPort，本 store 自持
// loadSatelliteSources / loadSatellites。
//
// 所有更新都必须是字段整体赋值：@ObjectLink 只观测字段赋值，观测不到数组原地 push/splice
// 或对象原地改属性。
@Observed
export class SatelliteStore {
  satGroups: string[] = []
  activeSatGroup: string = ''
  satLabels: boolean = false
  satOrbitLines: boolean = false
  satHints: boolean = false
  satIconicMode: boolean = false
  satHideInvisible: boolean = false
  satCount: number = 0
  satQuery: string = ''
  satItems: SatelliteListItem[] = []
  satOffline: boolean = true
  satObserverIsEarth: boolean = true
  satDateInRange: boolean = true
  satNewestUpdate: string = ''
  satOutdatedCount: number = 0
  satMatchedCount: number = 0
  satCatalogCreator: string = ''
  satCatalogSnapshot: string = ''
  satCatalogSource: string = ''
  satSources: SatelliteSource[] = []
  satUpdateSettings: SatelliteUpdateSettings = {
    updatesEnabled: false, autoAddEnabled: false, autoRemoveEnabled: false,
    autoDisplayEnabled: true, updateFrequencyHours: 72, secondsToUpdate: 0, updateState: 0
  }
  satSourceInput: string = ''
  satTleFileInput: string = ''
  satSourceAddNew: boolean = false
  satSourceStatus: string = ''
  satUpdateFrequencyInput: string = '72'
  satelliteListLoading: boolean = false
  satelliteCatalogHealth: CatalogHealthEntry = {}

  // —— loadSatellites 的内部字段 / 定时器 ——
  //   - satelliteListRequestId：加载器请求序号；宿主 CLI 发布点需读取，保持 public 且唯一副本。
  //   - satelliteListElapsedMs：加载耗时，同样由宿主发布点读取，保持 public。
  //   - satelliteFlagMutationId：卫星标志代际，载入回包用它决定是否回写标志；宿主动作
  //     setSatelliteFlag 与 CLI 事件两处写入，保持 public 单一副本。
  //   - satelliteLoadTimer / satelliteLoadIncludeSources：仅本加载器自持，private。
  satelliteListRequestId: number = 0
  satelliteListElapsedMs: number = 0
  satelliteFlagMutationId: number = 0
  private satelliteLoadTimer: number = -1
  private satelliteLoadIncludeSources: boolean = false

  // —— 桥注入 ——
  private port: CommandPort | null = null
  // 本加载器无并发抑制需求，seq 预留未用。
  private seq: number = 0
  private onChanged: ((error: string) => void) | null = null

  // 宿主在 aboutToAppear 注入端口与发布回调；重复注入覆盖旧值（幂等）。
  // onChanged 带 error 形参：发布端据它区分成功（空串）与失败（'satellite query failed'）。
  attachPort(port: CommandPort, onChanged: (error: string) => void): void {
    this.port = port
    this.onChanged = onChanged
  }

  // 加载器统一守卫：未注入端口时静默跳过（不 crash，也不 import 桥）。
  private ensurePort(): CommandPort | null {
    return this.port
  }

  private notifyChanged(error: string = ''): void {
    if (this.onChanged !== null) {
      this.onChanged(error)
    }
  }

  // 卫星面板「数据源」：桥拉取 TLE 源列表与更新设置。
  loadSatelliteSources(): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    port.requestWhenReady('getSatelliteSources', '', (r: StellariumBridgeResponse) => {
      const response = r as SatelliteSourcesResponse
      this.satSources = response.sources ?? []
      if (response.settings) {
        this.satUpdateSettings = response.settings
        this.satUpdateFrequencyInput = response.settings.updateFrequencyHours.toString()
      }
      this.notifyChanged()
    })
  }

  // 卫星列表加载：requestId / flagMutationId 抑制过期回包，includeSources 合并同批请求，
  // 90ms 去抖合并连续触发；定时器 0/100/15 重试。
  loadSatellites(includeSources: boolean = false, immediate: boolean = false): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const requestId = ++this.satelliteListRequestId
    const flagMutationId = this.satelliteFlagMutationId
    const startedAt = Date.now()
    this.satelliteListLoading = true
    this.notifyChanged()
    this.satelliteLoadIncludeSources = this.satelliteLoadIncludeSources || includeSources
    if (this.satelliteLoadTimer >= 0) {
      clearTimeout(this.satelliteLoadTimer)
      this.satelliteLoadTimer = -1
    }
    const run = (): void => {
      this.satelliteLoadTimer = -1
      const includeSourcesForRequest = this.satelliteLoadIncludeSources
      this.satelliteLoadIncludeSources = false
      const payload = this.activeSatGroup + '|' + this.satQuery + '|40'
      this.satelliteListLoading = true
      port.requestWhenReady('getSatellites', payload, (r: StellariumBridgeResponse) => {
        if (requestId !== this.satelliteListRequestId) return
        this.satelliteListLoading = false
        const resp = r as SatellitesResponse
        const s = resp.satellites
        if (!s) return
        if (this.satGroups.join('|') !== s.groups.join('|')) this.satGroups = s.groups
        if (flagMutationId === this.satelliteFlagMutationId) {
          this.satLabels = s.labels
          this.satOrbitLines = s.orbitLines
          this.satHints = s.hints
          this.satIconicMode = s.iconicMode
          this.satHideInvisible = s.hideInvisible
        }
        this.satCount = s.count
        this.satOffline = s.offline
        this.satObserverIsEarth = s.observerIsEarth
        this.satDateInRange = s.dateInRange
        this.satNewestUpdate = s.newestUpdate
        this.satOutdatedCount = s.outdatedCount
        this.satMatchedCount = s.matchedCount
        this.satCatalogCreator = s.catalogCreator ?? ''
        this.satCatalogSnapshot = s.catalogSnapshot ?? ''
        this.satCatalogSource = s.catalogSource ?? ''
        this.satItems = s.items
        this.satelliteListElapsedMs = Date.now() - startedAt
        this.notifyChanged()
        if (includeSourcesForRequest) this.loadSatelliteSources()
      }, () => {
        if (requestId === this.satelliteListRequestId) {
          this.satelliteListLoading = false
          this.notifyChanged('satellite query failed')
        }
      }, 0, 100, 15)
    }
    if (immediate) run()
    else this.satelliteLoadTimer = setTimeout(run, 90)
  }
}
