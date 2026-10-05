import { PolarScopeData, StellariumBridgeResponse } from '../pages/StellariumTypes'
import { CommandPort } from '../bridge/CommandPort'
import { I18n } from '../pages/I18n'

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
// §14 B3-2：极轴镜数据加载器 loadPolarScopeData 连其在途请求态（原宿主裸字段
// polarScopeRequestPending / polarScopeDataRequestId）一并搬入本 store；宿主每 1s 计时器
// 与面板开合只负责调用 loadPolarScopeData / cancelPolarScopeRequest，不再持有请求态。
// 「是否应刷新」谓词（applicationInForeground && polarScopeVisible）仍归宿主，经
// PolarScopeHostHooks 具名注入（store 不 import UI）。
//
// 刻意留在宿主（非本 store 状态）：极轴镜几何（polarScopeTopInset / ControlWidth / FooterHeight
// 由宿主算好后以 @Prop 传入）、引擎/定时器字段 polarScopeRestoreState / TransitionPending /
// TransitionId / Timer 与 recenterPolarScope 等动作。
//
// 约束：所有更新必须是"字段整体赋值"。polarScopeData 只被整体赋值（`= response.polarScope`
// 或 `= undefined`），改造前已普查确认无 `this.polarScopeData.<prop> =` 之类的原地变更。
export interface PolarScopeHostHooks {
  shouldRefreshPolarScope(): boolean
}

@Observed
export class PolarScopeStore {
  polarScopeData: PolarScopeData | undefined = undefined
  polarScopeVisible: boolean = false
  polarScopeLoading: boolean = false
  polarScopeError: string = ''
  polarScopeHorizontalFlip: boolean = false
  polarScopeVerticalFlip: boolean = false

  // —— 桥注入（§14 B3-2） ——
  private port: CommandPort | null = null
  private hooks: PolarScopeHostHooks | null = null
  private polarScopeRequestPending: boolean = false
  private polarScopeDataRequestSequence: number = 0

  attachPort(port: CommandPort): void {
    this.port = port
  }

  attachHooks(hooks: PolarScopeHostHooks): void {
    this.hooks = hooks
  }

  private ensurePort(): CommandPort | null {
    return this.port
  }

  private shouldRefresh(): boolean {
    const hooks = this.hooks
    return hooks !== null && hooks.shouldRefreshPolarScope()
  }

  // 宿主 stopPolarScopeTimer：作废在途请求并清 pending（原语义逐字保留）。
  cancelPolarScopeRequest(): void {
    this.polarScopeRequestPending = false
    ++this.polarScopeDataRequestSequence
  }

  // 极轴镜数据加载器（原宿主 loadPolarScopeData，函数体逐字搬入；仅
  // this.callNativeWhenReady → port.requestWhenReady、this.shouldRefreshPolarScope() → this.shouldRefresh()、
  // this.polarScopeStore.<f> → this.<f>、请求态改本 store 私有字段）。
  loadPolarScopeData(showLoading: boolean = true): void {
    if (!this.shouldRefresh() || this.polarScopeRequestPending) return
    const port = this.ensurePort()
    if (port === null) return
    this.polarScopeRequestPending = true
    const requestId = this.polarScopeDataRequestSequence
    if (showLoading && this.polarScopeData === undefined) this.polarScopeLoading = true
    port.requestWhenReady('getPolarScopeData', '', (response: StellariumBridgeResponse) => {
      if (requestId !== this.polarScopeDataRequestSequence) return
      this.polarScopeRequestPending = false
      this.polarScopeLoading = false
      if (!this.shouldRefresh() || response.polarScope === undefined) return
      this.polarScopeData = response.polarScope
      this.polarScopeError = ''
    }, () => {
      if (requestId !== this.polarScopeDataRequestSequence) return
      this.polarScopeRequestPending = false
      this.polarScopeLoading = false
      this.polarScopeError = I18n.t('polar_scope_earth_only')
    }, 0, 34, 8)
  }
}
