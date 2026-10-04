// 「视图交互偏好」状态簇（review §2.7）。
//
// 5 个字段全部下沉（原宿主 @State）：自动重置缩放（autoZoomResets）、距离单位
// （useMetricUnits）、锁定视角（viewLock）、竖直限位（verticalClamp）、地平线平直
// （flatHorizon）。它们同属「视图 / 显示交互偏好」，默认在设置面板（configTab 7）、
// 快捷设置（旧版）面板与配置回退面板里成组出现；viewLock 还经宿主以 @Prop 下发给
// 三个壳层内的 UnifiedObjectDetailCard。
//
// 为什么 flatHorizon 不并入 OverlayStore：OverlayStore 的既定范围是叠层 / 坐标 / 指向线，
// 而 flatHorizon 与 verticalClamp / viewLock 一样由 syncBridgeFlagState() 统一写回，
// 语义同属「视图限位 / 交互」，故并入本 store。
//
// 动作（setDistanceUnit / setViewLockState / syncBridgeFlagState / setNavigationBoolean
// 内的 autoZoomResets 分支）与桥调用留在宿主（§13.1 规则 6），组件只读字段。
//
// 2026-10-04 追加两字段（review §2.7 残留并入）：
//   - configDitheringMode —— 抖动/渲染质量档（Color888…），SettingsPanel 经既有 @ObjectLink 消费；
//   - liveMode —— 实时模式开关显示值，SettingsQuickLegacyPanel 经 @Prop 快照消费。
//   二者消费方都已持有本 store，故并入而不新建。
//
// 2026-10-04 追加一字段（review §2.7 残留并入）：
//   - uiLocked —— 界面锁定标志，门控面板关闭与空闲淡出（`closePanel` / `handleUiTap` 关闭按钮 /
//     `resetPanelIdle`）。属"视图交互锁定"，与 `viewLock`（锁定视图中心）同域，故并入本 store 而不新建。
//
// 约束：均为标量，只做整体赋值，无原地变更。
@Observed
export class ViewSettingsStore {
  autoZoomResets: boolean = false
  useMetricUnits: boolean = true
  viewLock: boolean = false
  verticalClamp: boolean = true
  flatHorizon: boolean = true
  configDitheringMode: string = 'Color888'
  liveMode: boolean = true
  uiLocked: boolean = false
}
