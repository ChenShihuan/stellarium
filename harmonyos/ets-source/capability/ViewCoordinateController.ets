// 视图中心坐标叠层行为控制器（STATE-REVIEW §10.2 D6，PLAN §15 D 轨道 D6）。
//
// 原宿主 MainWindowNativeNode 的 8 个行为方法逐字下沉：
//   refreshViewCenterCoordinates / applyViewCoordinateSnapshot / syncViewCoordinateTimer
//   / stopViewCoordinateTimer / setViewCoordinatesVisible / setViewCoordinateFamily
//   / setViewEquatorialEpoch / handleViewCoordinateTouch。
//
// STATE-REVIEW 记「16 法 / 10 私有字段」，工作区实测：
//   - 行为方法 8 个（本控制器）；
//   - 5 个几何方法 viewCoordinateOverlayWidth / Left / Top + clampedViewCoordinateOffsetX / Y
//     属 §2.7.1 A-保留 51（G 类逐帧读数），按 §15.6-2 留宿主，经 hooks 回注（本控制器调
//     viewCoordinateRestOffsetX / Y 取回拖拽落点）；
//   - 4 个 @State viewCoordinatePrimaryText / SecondaryText / OffsetX / OffsetY 同属 §2.7.1 G 类
//     保留裸字段（50ms 定时器回填 / 拖拽逐帧写），按 §15.7 规则 2「高频字段不入被观察 store」
//     留宿主，经 hooks 读写；
//   - utcOffsetHours 实测引用点全在本 8 法之外（dock 时钟 refreshDockClock / 时间格式化 /
//     TimeWheel 的 getUtcOffsetHours 钩子），属跨域共用，按 §15.6-1 留宿主。
//
// **不 import NAPI/UI**（§15.7 规则 1）：桥经 CommandPort；开关 / 坐标系 / 历元写 OverlayStore
//（ViewCoordinateSettings / ViewCenterCoordinateOverlay 消费）；applicationInForeground /
// saveAppSettings / stopSkyInertia 与叠层 4 个 @State 经 ViewCoordinateHostHooks 回注。
// 定时器 viewCoordinateTimer 由控制器自持（§15.7 规则 3）：stopViewCoordinateTimer / syncViewCoordinateTimer。
import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import { CommandPort } from '../bridge/CommandPort'
import { OverlayStore } from '../state/OverlayStore'
import { touchScreenX, touchScreenY } from '../common/derive/geometry'

export interface ViewCoordinateHostHooks {
  applicationInForeground(): boolean
  saveAppSettings(): void
  stopSkyInertia(): void
  viewCoordinateOffsetX(): number
  setViewCoordinateOffsetX(value: number): void
  viewCoordinateOffsetY(): number
  setViewCoordinateOffsetY(value: number): void
  setViewCoordinatePrimaryText(text: string): void
  setViewCoordinateSecondaryText(text: string): void
  viewCoordinateRestOffsetX(): number
  viewCoordinateRestOffsetY(): number
}

export class ViewCoordinateController {
  private port: CommandPort
  private overlayStore: OverlayStore
  private hooks: ViewCoordinateHostHooks
  // 拖拽/请求草稿字段（§15.7 规则 2）：不入 @Observed store；4 个可观测 @State 留宿主经 hooks 读写。
  private viewCoordinateDragging: boolean = false
  private viewCoordinateDragStartX: number = 0
  private viewCoordinateDragStartY: number = 0
  private viewCoordinateDragStartOffsetX: number = 0
  private viewCoordinateDragStartOffsetY: number = 0
  private viewCoordinateSnapshot: StellariumBridgeResponse = {}
  private viewCoordinateTimer: number = 0
  private viewCoordinateRequestPending: boolean = false

  constructor(port: CommandPort, overlayStore: OverlayStore, hooks: ViewCoordinateHostHooks) {
    this.port = port
    this.overlayStore = overlayStore
    this.hooks = hooks
  }

  // 原宿主 refreshViewCenterCoordinates()：50ms 轮询回包 → 快照 → 按坐标系拆文案。
  refreshViewCenterCoordinates(): void {
    if (!this.overlayStore.viewCoordinatesVisible || !this.hooks.applicationInForeground() || this.viewCoordinateRequestPending) {
      return
    }
    this.viewCoordinateRequestPending = true
    this.port.requestWhenReady('getViewCenterCoordinates', '', (result: StellariumBridgeResponse) => {
      this.viewCoordinateRequestPending = false
      if (!this.overlayStore.viewCoordinatesVisible || !this.hooks.applicationInForeground()) { return }
      this.viewCoordinateSnapshot = result
      this.applyViewCoordinateSnapshot()
    }, () => {
      this.viewCoordinateRequestPending = false
    }, 0, 34, 8)
  }

  // 原宿主 applyViewCoordinateSnapshot()：按当前坐标系 / 历元把快照转成主副读数。
  applyViewCoordinateSnapshot(): void {
    const snapshot = this.viewCoordinateSnapshot
    if (this.overlayStore.viewCoordinateFamily === 'horizontal') {
      this.hooks.setViewCoordinatePrimaryText(snapshot.azimuthText ?? '--')
      this.hooks.setViewCoordinateSecondaryText(snapshot.altitudeText ?? '--')
    } else if (this.overlayStore.viewCoordinateFamily === 'galactic') {
      this.hooks.setViewCoordinatePrimaryText(snapshot.galacticLongitude ?? '--')
      this.hooks.setViewCoordinateSecondaryText(snapshot.galacticLatitude ?? '--')
    } else if (this.overlayStore.viewEquatorialEpoch === 'ofDate') {
      this.hooks.setViewCoordinatePrimaryText(snapshot.ofDateRa ?? '--')
      this.hooks.setViewCoordinateSecondaryText(snapshot.ofDateDec ?? '--')
    } else {
      this.hooks.setViewCoordinatePrimaryText(snapshot.j2000Ra ?? '--')
      this.hooks.setViewCoordinateSecondaryText(snapshot.j2000Dec ?? '--')
    }
  }

  // 原宿主 stopViewCoordinateTimer()。
  stopViewCoordinateTimer(): void {
    if (this.viewCoordinateTimer !== 0) {
      clearInterval(this.viewCoordinateTimer)
      this.viewCoordinateTimer = 0
    }
  }

  // 原宿主 syncViewCoordinateTimer()：可见且前台时启动 50ms 轮询。
  syncViewCoordinateTimer(): void {
    this.stopViewCoordinateTimer()
    if (!this.overlayStore.viewCoordinatesVisible || !this.hooks.applicationInForeground()) { return }
    this.refreshViewCenterCoordinates()
    this.viewCoordinateTimer = setInterval(() => {
      this.refreshViewCenterCoordinates()
    }, 50)
  }

  // 原宿主 setViewCoordinatesVisible()。
  setViewCoordinatesVisible(visible: boolean): void {
    this.overlayStore.viewCoordinatesVisible = visible
    this.hooks.saveAppSettings()
    this.syncViewCoordinateTimer()
  }

  // 原宿主 setViewCoordinateFamily()。
  setViewCoordinateFamily(family: string): void {
    this.overlayStore.viewCoordinateFamily = family
    this.applyViewCoordinateSnapshot()
    this.hooks.saveAppSettings()
  }

  // 原宿主 setViewEquatorialEpoch()。
  setViewEquatorialEpoch(epoch: string): void {
    this.overlayStore.viewEquatorialEpoch = epoch
    this.applyViewCoordinateSnapshot()
    this.hooks.saveAppSettings()
  }

  // 原宿主 handleViewCoordinateTouch()：叠层拖拽（Down 记起点并停惯性 → Move 写偏移 → Up/Cancel 落位回夹）。
  handleViewCoordinateTouch(event: TouchEvent): void {
    const points = event.touches.length > 0 ? event.touches : event.changedTouches
    if (points.length === 0) { return }
    const point = points[0]
    const x = touchScreenX(point)
    const y = touchScreenY(point)
    if (event.type === TouchType.Down) {
      this.viewCoordinateDragging = true
      this.viewCoordinateDragStartX = x
      this.viewCoordinateDragStartY = y
      this.viewCoordinateDragStartOffsetX = this.hooks.viewCoordinateOffsetX()
      this.viewCoordinateDragStartOffsetY = this.hooks.viewCoordinateOffsetY()
      this.hooks.stopSkyInertia()
      return
    }
    if (event.type === TouchType.Move && this.viewCoordinateDragging) {
      this.hooks.setViewCoordinateOffsetX(this.viewCoordinateDragStartOffsetX + x - this.viewCoordinateDragStartX)
      this.hooks.setViewCoordinateOffsetY(this.viewCoordinateDragStartOffsetY + y - this.viewCoordinateDragStartY)
      return
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.viewCoordinateDragging = false
      this.hooks.setViewCoordinateOffsetX(this.hooks.viewCoordinateRestOffsetX())
      this.hooks.setViewCoordinateOffsetY(this.hooks.viewCoordinateRestOffsetY())
    }
  }
}
