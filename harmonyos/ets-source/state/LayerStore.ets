// 「图层」面板（activePanel === 'layers'）的开关状态簇。
//
// 本片边界（Phase 3ak）：原宿主的 ~94 个 `@State private <name>: boolean` 图层开关
// （天空/恒星、太阳系、深空、标记与网格、景观、星座与星空文化六组）逐条搬到这里，
// 保留原类型（boolean）与默认值。宿主以 `@State private layerStore: LayerStore = new LayerStore()`
// 持有，UI 侧经 @Prop 读到解析后的布尔值，写回由宿主回调完成（§13.1 规则 4）。
//
// 不搬的宿主职责：
//   - native 桥（setLayer / setBridgeFlag / setSkyDisplaySetting / callInteractive / refreshState）、
//     flashHint 提示、以及图层预设的组装（markingLayerStates / layerPresetStates / applyLayerPreset）；
//   - 视图标签切换动画所用的过渡量（viewTab / viewTabContentOpacity / viewTabContentOffsetX /
//     viewTabTransitionId）与 selectViewTab 的 animateTo 时序 —— 它们不是「开关」，留在宿主；
//   - 渲染管线逐帧写回的两字段（objectInspectorModelRendering / objectInspectorModelTexturePixels）
//     本就与图层无关，不在此列。
//
// 只放数据，不 import UI / NAPI。
@Observed
export class LayerStore {
  // —— 天空与恒星 ——
  stars: boolean = true
  milkyWay: boolean = true
  starLabels: boolean = false
  atmosphere: boolean = true
  luminanceAdaptation: boolean = true
  starTwinkle: boolean = true
  forcedStarTwinkle: boolean = false
  bigStarHalo: boolean = true
  starSpiky: boolean = false
  zodiacalLight: boolean = true

  // —— 太阳系 ——
  planets: boolean = true
  planetOrbits: boolean = false
  planetHints: boolean = false
  planetTrails: boolean = false
  minorBodyMarkers: boolean = false
  planetNomenclature: boolean = false
  enlargeMoon: boolean = false
  enlargePlanets: boolean = false
  enlargeSun: boolean = false

  // —— 深空与流星 ——
  nebulae: boolean = false
  dsoLabels: boolean = true
  dsoTextures: boolean = true
  meteors: boolean = false

  // —— 地平与景观 ——
  ground: boolean = true
  mistHorizon: boolean = true
  fogEffect: boolean = false
  landscapeIllum: boolean = false
  landscapeLabels: boolean = false
  flipHoriz: boolean = false
  flipVert: boolean = false
  cardinalPoints: boolean = true
  compassMarks: boolean = false

  // —— 标记：网格 ——
  gridlinesMaster: boolean = false
  equatorialGrid: boolean = false
  azimuthGrid: boolean = false
  galacticGrid: boolean = false
  eclipticGrid: boolean = false
  equatorialJ2000Grid: boolean = false
  eclipticJ2000Grid: boolean = false
  supergalacticGrid: boolean = false
  fixedEquatorialGrid: boolean = false

  // —— 标记：线 ——
  equatorLine: boolean = false
  eclipticLine: boolean = true
  meridianLine: boolean = false
  horizonLine: boolean = false
  galacticEquator: boolean = false
  supergalacticEq: boolean = false
  equJ2000Line: boolean = false
  eclJ2000Line: boolean = false
  primeVerticalLine: boolean = false
  currentVerticalLine: boolean = false
  colureLines: boolean = false
  precessionCircles: boolean = false
  circumpolarCircles: boolean = false
  invariantPlaneLine: boolean = false
  solarEquatorLine: boolean = false
  fixedEquatorLine: boolean = false
  longitudeLine: boolean = false
  quadratureLine: boolean = false

  // —— 标记：点 ——
  celestialPoles: boolean = false
  eclipticPoles: boolean = false
  galacticPoles: boolean = false
  equinoxPoints: boolean = false
  solsticePoints: boolean = false
  antisolarPoint: boolean = false
  umbraCircle: boolean = false
  penumbraCircle: boolean = false
  zenithNadir: boolean = false
  celestialJ2000Poles: boolean = false
  eclipticJ2000Poles: boolean = false
  equinoxJ2000Pts: boolean = false
  solsticeJ2000Pts: boolean = false
  galacticCenter: boolean = false
  supergalacticPoles: boolean = false
  apexPoints: boolean = false
  umbraCenter: boolean = false

  // —— 标记：方位细分 ——
  intercardinalPts: boolean = false
  secondaryIntercardinalPts: boolean = false
  tertiaryIntercardinalPts: boolean = false

  // —— 标记：视场 ——
  fovMarker: boolean = false
  fovCircularMarker: boolean = false
  fovRectangularMarker: boolean = false

  // —— 星座与星空文化 ——
  constellationLines: boolean = false
  constellationLabels: boolean = false
  constellationBoundaries: boolean = false
  constellationHulls: boolean = false
  constellationArt: boolean = false
  zodiac: boolean = false
  lunarSystem: boolean = false
  asterismLines: boolean = false
  asterismLabels: boolean = false
  rayHelpers: boolean = false

  // —— 巡天（离线 AppGallery 构建下隐藏）——
  hipsSurveys: boolean = false
  toastSurvey: boolean = false
}
