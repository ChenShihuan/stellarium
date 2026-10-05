import { PolarScopeData } from '../pages/StellariumTypes'

// 极轴镜（polarScope）屏幕叠层的状态。
//
// review §2.7：本域原为 "Prop 风格" —— 6 个 @State 留宿主、以 @Prop 快照传入
// PolarScopeOverlay（loading / errorText / horizontalFlip / verticalFlip 直接传，
// isSouthHemisphere / hourAngleText / viewAngleText 由宿主从 polarScopeData 取好后传）。
// 现改为 @Observed store + 叠层 @ObjectLink；读数由组件就地读 store 的 polarScopeData 派生。
//
// 本域 6 个字段全部下沉：
//   - 可见性 polarScopeVisible（宿主多处判定 + 三个壳层以 @Prop 消费，随宿主 store 读取）；
//   - 请求态 polarScopeLoading / polarScopeError；
//   - 数据 polarScopeData；
//   - 翻转开关 polarScopeHorizontalFlip / polarScopeVerticalFlip（随 saveAppSettings 持久化）。
//
// 刻意留在宿主（非本 store 状态）：极轴镜几何（polarScopeTopInset / ControlWidth / FooterHeight
// 由宿主算好后以 @Prop 传入）、引擎/定时器字段 polarScopeRestoreState / TransitionPending /
// TransitionId / RequestPending / Timer / DataRequestId 与 setPolarScopeHorizontalFlip /
// setPolarScopeVerticalFlip / recenterPolarScope 等动作。
//
// 约束：所有更新必须是"字段整体赋值"。polarScopeData 只被整体赋值（`= response.polarScope`
// 或 `= undefined`），改造前已普查确认无 `this.polarScopeData.<prop> =` 之类的原地变更。
@Observed
export class PolarScopeStore {
  polarScopeData: PolarScopeData | undefined = undefined
  polarScopeVisible: boolean = false
  polarScopeLoading: boolean = false
  polarScopeError: string = ''
  polarScopeHorizontalFlip: boolean = false
  polarScopeVerticalFlip: boolean = false
}
