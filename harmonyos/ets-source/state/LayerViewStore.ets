import { LandscapeItem } from '../pages/StellariumTypes'

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
//     setLandscape* / getLandscapeList / setLandscape）仍留宿主，由组件回调触发；
//   - 纯 UI 展开标记里与宿主其它 UI 共享的不搬（本 store 只收图层面板独占的
//     orbitSettingsExpanded / trailSettingsExpanded）；
//   - 开关布尔值仍归 LayerStore（Phase 3ak）。
//
// 只放数据，不 import UI / NAPI。
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
}
