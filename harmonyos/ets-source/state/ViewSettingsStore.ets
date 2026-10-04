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
// 约束：均为标量，只做整体赋值，无原地变更。
@Observed
export class ViewSettingsStore {
  autoZoomResets: boolean = false
  useMetricUnits: boolean = true
  viewLock: boolean = false
  verticalClamp: boolean = true
  flatHorizon: boolean = true
}
