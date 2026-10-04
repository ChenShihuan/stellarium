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

// 卫星域状态（原宿主的 28 个 @State 字段：sat* 簇 + activeSatGroup +
// satelliteListLoading + satelliteCatalogHealth）。
//
// 这一片是 review §2.7 所指"Prop 风格域 → Store 风格"的第一个目标：此前 SatellitesPanel
// 以 28 个 @Prop 快照接收这些字段，任何一处变化都会让宿主整棵重渲染；改为 @Observed store +
// 面板 @ObjectLink 之后，刷新粒度收缩到订阅该 store 的组件。
//
// 两点取舍（与 §13.1/§13.3 的既有结论一致）：
//   1. 字段名沿用宿主原名（保留 sat 前缀），以便与既有 114 处引用机械对应、降低改错风险；
//      若要收敛命名，另开一次纯重命名提交。
//   2. 动作仍走回调注入（store 只承载状态），与 AstroPanel/LayersPanel 的既有写法一致。
//   3. 所有更新都必须是"字段重新赋值"：@ObjectLink 只观测字段赋值，观测不到数组原地
//      push/splice 或对象原地改属性。改造前已普查确认本域三处数组（satSources/satGroups/
//      satItems）与两处对象（satUpdateSettings/satelliteCatalogHealth）均无原地变更。
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

  // —— §14 B3-4：loadSatellites 的保留裸字段 / 定时器（单一持有者迁入本 store） ——
  // 原宿主裸字段 satelliteListRequestId / satelliteLoadTimer / satelliteLoadIncludeSources /
  // satelliteFlagMutationId / satelliteListElapsedMs。
  //   - satelliteListRequestId：加载器请求序号（§14.8 规则 3 随加载器搬入），宿主 CLI 发布点
  //     publishSatellitePanelState 需读取其值，故保持 public 且为唯一副本。
  //   - satelliteListElapsedMs：加载耗时，同样由宿主发布点读取，保持 public。
  //   - satelliteFlagMutationId：卫星标志代际，载入回包用它决定是否回写标志；宿主动作
  //     setSatelliteFlag 与 CLI 事件两处写入，仍保持 public 单一副本（宿主经 this.satelliteStore.X 读写）。
  //   - satelliteLoadTimer / satelliteLoadIncludeSources：仅本加载器自持，private。
  satelliteListRequestId: number = 0
  satelliteListElapsedMs: number = 0
  satelliteFlagMutationId: number = 0
  private satelliteLoadTimer: number = -1
  private satelliteLoadIncludeSources: boolean = false

  // —— 桥注入（§14.1 AB-0；§14 B1-6 起本 store 自持 loadSatelliteSources） ——
  private port: CommandPort | null = null
  // 本加载器不使用请求序号（无并发抑制需求）；预留以满足 §14.8 规则 3 的统一约定。
  private seq: number = 0
  private onChanged: ((error: string) => void) | null = null

  // 宿主在 aboutToAppear 注入端口与发布回调；重复注入会覆盖旧值（幂等）。
  // onChanged 带 error 形参：宿主 publishSatellitePanelState(error) 的 CLI 错误语义需逐字保留
  //（成功路径传空串，失败路径传 'satellite query failed'）。
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

  // 卫星面板「数据源」：桥拉取 TLE 源列表与更新设置（原宿主 loadSatelliteSources，函数体逐字搬入；
  // 仅 this.callNativeWhenReady → this.port.requestWhenReady、this.satelliteStore.<f> → this.<f>）。
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

  // 卫星列表加载（原宿主 loadSatellites，函数体逐字搬入；差异仅：
  // this.callNativeWhenReady → port.requestWhenReady（attempt/interval/max 0/100/15，onFailure 透传）、
  // this.satelliteStore.<f> → this.<f>、this.publishSatellitePanelState() → this.notifyChanged()，
  // this.satelliteListRequestId / satelliteLoadTimer / satelliteLoadIncludeSources / satelliteFlagMutationId
  // 为本地字段。requestId/flagMutationId 的并发抑制、includeSources 合并与 90ms 去抖逐字保留。）
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
