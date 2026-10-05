import {
  SatelliteListItem,
  SatelliteSource,
  SatelliteUpdateSettings,
  SatelliteSourcesResponse,
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

  // —— 桥注入（§14.1 AB-0；§14 B1-6 起本 store 自持 loadSatelliteSources） ——
  private port: CommandPort | null = null
  // 本加载器不使用请求序号（无并发抑制需求）；预留以满足 §14.8 规则 3 的统一约定。
  private seq: number = 0
  private onChanged: (() => void) | null = null

  // 宿主在 aboutToAppear 注入端口与发布回调；重复注入会覆盖旧值（幂等）。
  attachPort(port: CommandPort, onChanged: () => void): void {
    this.port = port
    this.onChanged = onChanged
  }

  // 加载器统一守卫：未注入端口时静默跳过（不 crash，也不 import 桥）。
  private ensurePort(): CommandPort | null {
    return this.port
  }

  private notifyChanged(): void {
    if (this.onChanged !== null) {
      this.onChanged()
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
}
