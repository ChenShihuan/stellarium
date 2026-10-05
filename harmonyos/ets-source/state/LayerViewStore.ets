import { StellariumBridgeResponse, LandscapeItem } from '../pages/StellariumTypes'
import { CommandPort } from '../bridge/CommandPort'

// 「图层」面板（activePanel === 'layers'）六个视图标签页的**数值/展开态设置**簇。
//
// 本片边界（Phase 4f）：原宿主 31 个 `@State` 字段（天空显示 6、行星轨道 8、轨迹 7、
// 视场标记 4、地景 6）逐条搬到这里，保留原类型与默认值。宿主以
// `@State private layerViewStore: LayerViewStore = new LayerViewStore()` 持有，
// 组件经 @ObjectLink 读到实时值（§13.1 规则 4/5：这些字段只被图层面板的 viewXxxTab 读取，
// 必须与读它的 UI 同片搬迁）。
//
// 不搬的宿主职责：
//   - native 桥（setSkyDisplaySetting / setLimitMagnitude / setMilkyWayIntensity /
//     setOrbitDisplaySetting / setTrailDisplaySetting / setFovMarkerSetting /
//     setLandscape* / setLandscape）仍留宿主，由组件回调触发；
//   - 纯 UI 展开标记里与宿主其它 UI 共享的不搬（本 store 只收图层面板独占的
//     orbitSettingsExpanded / trailSettingsExpanded）；
//   - 开关布尔值仍归 LayerStore（Phase 3ak）。
//
// 只放数据，不 import UI / NAPI（只额外 import 纯类型 StellariumBridgeResponse /
// LandscapeItem 与纯接口 CommandPort，均不触碰 libentry.so / @ohos.*）。
//
// —— 桥注入约定（§14.1 AB-0 起；§14 B1-2 起本域加载器自持） ——
// 宿主在 aboutToAppear 用同一个 HostCommandPort 实例 attachPort(port, onChanged) 注入；
// 请求序号 seq 随加载器搬入 store（§14.8 规则 3）。消费方均为 @ObjectLink，字段赋值即刷新，
// 本域无 publish* 发布点，故宿主注入的 onChanged 目前为等价空实现，notifyChanged() 为无副作用调用。
@Observed
export class LayerViewStore {
  // —— 天空与恒星显示 ——
  starMagLimit: number = 6.0
  bortleScale: number = 3
  milkyWayBright: number = 3
  meteorZhr: number = 10
  meteorZhrMax: number = 240000
  zodiacalIntensity: number = 1

  // —— 行星轨道 ——
  orbitSettingsExpanded: boolean = false
  orbitIsolated: boolean = true
  orbitMajorPlanets: boolean = false
  orbitPlanetsOnly: boolean = false
  orbitWithMoons: boolean = false
  orbitPermanent: boolean = false
  orbitThickness: number = 1
  orbitColorStyle: string = 'one_color'

  // —— 行星轨迹 ——
  trailSettingsExpanded: boolean = false
  trailIsolated: boolean = true
  trailSelectionCount: number = 1
  trailYears: number = 1
  trailThickness: number = 1
  trailColor: string = '#FFFFFF'
  trailColorInput: string = '#FFFFFF'

  // —— 视场标记尺寸 ——
  fovCircularMarkerSize: number = 1
  fovRectangularMarkerWidth: number = 4
  fovRectangularMarkerHeight: number = 3
  fovRectangularMarkerRotation: number = 0

  // —— 地景 ——
  landscapeList: Array<LandscapeItem> = []
  landscapeLoading: boolean = false
  landscapeImporting: boolean = false
  currentLandscapeId: string = ''
  landscapeTransp: number = 0
  landscapeFadeWithZoom: boolean = true

  // —— 桥注入（§14.1 AB-0 约定；§14 B1-2 起本域加载器自持） ——
  private port: CommandPort | null = null
  // 原宿主的请求序号搬入 store（§14.8 规则 3）；本片加载器暂未用到，供后续 B 片复用。
  private seq: number = 0
  private onChanged: (() => void) | null = null

  attachPort(port: CommandPort, onChanged: () => void): void {
    this.port = port
    this.onChanged = onChanged
  }

  private ensurePort(): CommandPort | null {
    return this.port
  }

  private notifyChanged(): void {
    if (this.onChanged !== null) {
      this.onChanged()
    }
  }

  // 地景列表加载（原宿主 loadLandscapeList，函数体逐字搬入；仅 this.callNativeWhenReady →
  // this.port.requestWhenReady、this.layerViewStore.<f> → this.<f>）。
  loadLandscapeList(): void {
    const port = this.ensurePort()
    if (port === null) return
    if (this.landscapeLoading) return
    this.landscapeLoading = true
    port.requestWhenReady('getLandscapeList', '', (r: StellariumBridgeResponse) => {
      this.landscapeLoading = false
      if (r.ok !== true || !Array.isArray(r.items)) return
      this.landscapeList = r.items as Array<LandscapeItem>
      this.currentLandscapeId = r.current as string
      this.notifyChanged()
    }, () => {
      this.landscapeLoading = false
    }, 0, 100, 15)
  }

  // 行星轨道显示设置加载（原宿主 loadOrbitDisplaySettings，函数体逐字搬入）。
  loadOrbitDisplaySettings(): void {
    const port = this.ensurePort()
    if (port === null) return
    port.requestInteractive('getOrbitDisplaySettings', '', (r: StellariumBridgeResponse) => {
      if (r.ok !== true) return
      this.orbitIsolated = r.orbitIsolated !== undefined ? r.orbitIsolated : this.orbitIsolated
      this.orbitMajorPlanets = r.orbitMajorPlanets !== undefined ? r.orbitMajorPlanets : this.orbitMajorPlanets
      this.orbitPlanetsOnly = r.orbitPlanetsOnly !== undefined ? r.orbitPlanetsOnly : this.orbitPlanetsOnly
      this.orbitWithMoons = r.orbitWithMoons !== undefined ? r.orbitWithMoons : this.orbitWithMoons
      this.orbitPermanent = r.orbitPermanent !== undefined ? r.orbitPermanent : this.orbitPermanent
      this.orbitThickness = r.orbitThickness !== undefined ? r.orbitThickness : this.orbitThickness
      this.orbitColorStyle = r.orbitColorStyle !== undefined ? r.orbitColorStyle : this.orbitColorStyle
      this.notifyChanged()
    })
  }

  // 行星轨迹显示设置加载（原宿主 loadTrailDisplaySettings，函数体逐字搬入）。
  loadTrailDisplaySettings(): void {
    const port = this.ensurePort()
    if (port === null) return
    port.requestInteractive('getTrailDisplaySettings', '', (r: StellariumBridgeResponse) => {
      if (r.ok !== true) return
      this.trailIsolated = r.trailIsolated !== undefined ? r.trailIsolated : this.trailIsolated
      this.trailSelectionCount = r.trailSelectionCount !== undefined ? r.trailSelectionCount : this.trailSelectionCount
      this.trailYears = r.trailYears !== undefined ? r.trailYears : this.trailYears
      this.trailThickness = r.trailThickness !== undefined ? r.trailThickness : this.trailThickness
      if (r.trailColor !== undefined) {
        this.trailColor = r.trailColor
        this.trailColorInput = r.trailColor
      }
      this.notifyChanged()
    })
  }
}
