// 天空输入控制器（PLAN §15.10 / §15.11 M3「天空输入」，M3-1 骨架 + M3-2 主路径）。
//
// 原宿主 MainWindowNativeNode 的天空输入路径整体下沉：M3-1 搬鼠标/键盘/滚轮轴/点按序列/
// 惯性 8 法；M3-2 搬触屏主路径 dragFollowAlpha / emitFluidDrag / handleSkyTouch。
// 共 11 个方法。
//
// 职责划分（§15.7 规则 2）：可观测状态（触摸反馈点 skyTouchFeedback / skyTouchX/Y 等）与
// 跨 handler 共用的手势归属标志（touchStartedOnUi / skyTouchActive / skyDragging /
// dockTouchActive）仍是宿主裸 @State / 私有字段，由 build() 与 handleOverlayTouch /
// handleDockTouch / 详情定时器消费、控制器只经 hooks 读写；控制器内保留纯逐帧/草稿字段
// （触摸采样 / 捏合 / 滤波），不入被观察 store。
//
// 依赖注入（§15.7 规则 1 / §13.1 规则 6）：控制器不 import NAPI/UI（仅 ArkUI 事件类型与
// 纯几何/数学 derive 模块）。
//   - 桥 fire（dragView / zoomBy / panBy / beginSkyGesture / endPinch / startPanInertia /
//     stopPanInertia / setNightMode）经 CommandPort；
//   - §15.6 登记的 A2 热路径 isUiPoint / skyZoomButtonAt / dockActionAt 与全部宿主保留动作
//     （路由 setPanel/closePanel、zoomStep / moveToSelectedObject / 选中入口 / 详情刷新
//     收放 / Dock 动作 / 陀螺退出 / 音乐开关 / 面板拖动落盘等）一律经 SkyInputHostHooks
//     具名回注，宿主保留实现，不搬；
//   - NightModeStore 以实例引用持有一处（键盘 N 键切换夜间模式）。
import hilog from '@ohos.hilog'
import { KeyCode } from '@kit.InputKit'
import { CommandPort } from '../bridge/CommandPort'
import { NightModeStore } from '../state/NightModeStore'
import { ShellAction } from '../pages/StellariumTypes'
import { clamp, distance } from '../common/derive/astro'
import { touchWindowX, touchWindowY, panelTop, panelLeft, panelRight, isDockPoint, compactTopQuickY } from '../common/derive/geometry'

// 宿主 → 控制器回注（§13.1 规则 6）。第一项 isUiPoint 属 §15.6 A2 登记热路径，宿主保留实现。
export interface SkyInputHostHooks {
  isUiPoint(x: number, y: number): boolean
  flashHint(text: string): void
  skyWidth(): number
  skyHeight(): number
  gyroscopeEnabled(): boolean
  stopGyroscope(updateStatus: boolean): void
  angleMeasureEnabled(): boolean
  measureAngleAt(x: number, y: number): void
  requestSkySelection(x: number, y: number): void
  clearSkySelectionFromDoubleTap(x: number, y: number): void
  zoomStep(factor: number): void
  setPanel(panel: string): void
  closePanel(): void
  moveToSelectedObject(): void
  centerSelectedObjectFromKeyboard(): void
  persistNightMode(): void
  modelImmersive(): boolean
  setModelImmersive(value: boolean): void
  // ── M3-2：触屏主路径（handleSkyTouch / emitFluidDrag）依赖的宿主状态与动作 ──
  // 布局 / 面板几何（宿主 @State，控制器只读）
  isExpandedLayout(): boolean
  isFoldHoverLayout(): boolean
  isFoldTabletLayout(): boolean
  panelVisible(): boolean
  panelWidth(): number
  panelOffsetX(): number
  panelOffsetY(): number
  edgeMargin(): number
  fovSliderValue(): number
  setFovSliderValue(value: number): void
  polarScopeVisible(): boolean
  compactDockWidthPercent(): number
  dockTop(): number
  compactTopQuickX(): number
  isCompactTopQuickPoint(x: number, y: number): boolean
  lastInfoWinCloseMs(): number
  // 手势归属标志（宿主裸字段，跨 handleOverlayTouch / Dock / 详情定时器共用）
  touchStartedOnUi(): boolean
  setTouchStartedOnUi(value: boolean): void
  skyTouchActive(): boolean
  setSkyTouchActive(value: boolean): void
  setSkyDragging(value: boolean): void
  dockTouchActive(): boolean
  setDockTouchActive(value: boolean): void
  // 触摸反馈点（§2.7.1 保留 @State，宿主 build() 消费，控制器只写）
  skyTouchFeedback(): boolean
  setSkyTouchFeedback(value: boolean): void
  setSkyTouchPoint(x: number, y: number): void
  setSkyTouchPoint2(x: number, y: number): void
  skyTouchX2(): number
  skyTouchY2(): number
  setSkyTouchFeedbackMulti(value: boolean): void
  setCurrentFovText(text: string): void
  setPanelOffset(offsetX: number, offsetY: number): void
  // 宿主保留动作（选中 UI / 详情刷新 / 缩放按钮命中 / 面板拖动收尾等）
  cancelSelectedObjectUiChange(): void
  pauseDetailRefreshForSkyDrag(): void
  resumeDetailRefreshAfterSkyDrag(): void
  scheduleSelectedObjectForUiChange(delay: number): void
  scheduleSkyTextureStatusCheck(): void
  scheduleRecordingViewCheckpoint(delay: number): void
  resetPanelIdle(): void
  toggleMusic(): void
  musicHintText(): string
  toggleGyroscope(value: boolean): void
  skyZoomButtonAt(x: number, y: number): string
  dockActionAt(x: number, y: number): ShellAction | null
  activateDockAction(item: ShellAction): void
  requestFieldOfView(onResult: (fov: number) => void): void
}

export class SkyInputController {
  private commandPort: CommandPort
  private nightModeStore: NightModeStore
  private hooks: SkyInputHostHooks

  // ── 逐帧/草稿字段（留控制器，不入被观察 store；§15.7 规则 2）──
  private skyInertiaTimer: number = 0
  private lastSkyTapAt: number = 0
  private lastSkyTapX: number = 0
  private lastSkyTapY: number = 0

  // ── M3-2：触屏主路径（handleSkyTouch / emitFluidDrag）的草稿/逐帧字段（§15.7 规则 2）──
  // M3-1 暂转移所有权的 5 个共享字段（宿主原经 this.skyInputCtl().<f> 访问）在 M3-2 收归私有。
  private nativeSkyInertiaActive: boolean = false
  private dragVelocityX: number = 0
  private dragVelocityY: number = 0
  private dragVelocitySampleValid: boolean = false
  private pinchActive: boolean = false
  // 触摸/拖拽/捏合草稿（宿主引用数为 0，可整块迁移）
  private touchStartX: number = 0
  private touchStartY: number = 0
  private touchLastX: number = 0
  private touchLastY: number = 0
  private touchMoved: boolean = false
  private pinchStartDistance: number = 0
  private pinchLastScale: number = 1
  private pinchCenterX: number = 0
  private pinchCenterY: number = 0
  private pinchStartFov: number = 60
  private pinchLastNativePushMs: number = 0
  private pinchNativePushPending: boolean = false
  /** 缩放 FOV 胶囊提示的节流时间戳 */
  private lastFovHintMs: number = 0
  private nativeDragActive: boolean = false
  private lastDragCommandMs: number = 0
  private dragFilteredX: number = 0
  private dragFilteredY: number = 0
  private dragLastRawX: number = 0
  private dragLastRawY: number = 0
  private dragLastSampleMs: number = 0
  private dragLogCount: number = 0
  // 面板标题栏拖动（仅 handleSkyTouch 使用；panelOffsetX/Y 仍是宿主 @State，经 hooks 读写）
  private panelDragging: boolean = false
  private panelDragStartX: number = 0
  private panelDragStartY: number = 0
  private panelDragStartOffsetX: number = 0
  private panelDragStartOffsetY: number = 0

  private mouseSkyPressed: boolean = false
  private mouseSkyMoved: boolean = false
  private mouseSkyStartX: number = 0
  private mouseSkyStartY: number = 0
  private mouseSkyLastX: number = 0
  private mouseSkyLastY: number = 0
  private mouseSkyLastSampleMs: number = 0

  constructor(commandPort: CommandPort, nightModeStore: NightModeStore, hooks: SkyInputHostHooks) {
    this.commandPort = commandPort
    this.nightModeStore = nightModeStore
    this.hooks = hooks
  }

  // ── 宿主生命周期收口（§15.7 规则 3）──
  // 唯一的定时器句柄 skyInertiaTimer 仅在 stopSkyInertia() 内被 clearInterval；
  // stop() 为生命周期钩子（面板/后台/ aboutToDisappear 等价于 stopSkyInertia()）。
  stop(): void {
    this.stopSkyInertia()
  }

  resetSkyTapSequence(): void {
    this.lastSkyTapAt = 0
  }

  private isSkyDoubleTap(x: number, y: number): boolean {
    const now = Date.now()
    const tapInterval = this.lastSkyTapAt > 0 ? now - this.lastSkyTapAt : 0
    const withinTime = this.lastSkyTapAt > 0 && tapInterval <= 800
    const withinDistance = distance(x, y, this.lastSkyTapX, this.lastSkyTapY) <= 28
    if (this.lastSkyTapAt > 0) {
      hilog.info(0x0000, 'StellariumArkUI', 'sky tap interval=' + tapInterval.toString() +
        'ms distance=' + distance(x, y, this.lastSkyTapX, this.lastSkyTapY).toFixed(1) +
        ' double=' + (withinTime && withinDistance).toString())
    }
    if (withinTime && withinDistance) {
      this.resetSkyTapSequence()
      return true
    }
    this.lastSkyTapAt = now
    this.lastSkyTapX = x
    this.lastSkyTapY = y
    return false
  }

  handleSkyTap(x: number, y: number): void {
    if (this.hooks.angleMeasureEnabled()) {
      this.hooks.measureAngleAt(x, y)
      return
    }
    if (this.isSkyDoubleTap(x, y)) {
      this.hooks.clearSkySelectionFromDoubleTap(x, y)
      return
    }
    this.hooks.requestSkySelection(x, y)
  }

  handleSkyMouse(event: MouseEvent): void {
    const x = event.windowX
    const y = event.windowY
    if (event.action === 0 && event.button === 0) {
      this.mouseSkyPressed = !this.hooks.isUiPoint(x, y)
      if (!this.mouseSkyPressed) { this.resetSkyTapSequence() }
      this.mouseSkyMoved = false
      this.mouseSkyStartX = x
      this.mouseSkyStartY = y
      this.mouseSkyLastX = x
      this.mouseSkyLastY = y
      this.mouseSkyLastSampleMs = Date.now()
      if (this.mouseSkyPressed) { this.stopSkyInertia() }
      return
    }
    if (event.action === 2 && this.mouseSkyPressed) {
      const moveDistance = distance(x, y, this.mouseSkyStartX, this.mouseSkyStartY)
      if (moveDistance > 3) {
        this.resetSkyTapSequence()
        if (!this.mouseSkyMoved && this.hooks.gyroscopeEnabled()) {
          this.hooks.stopGyroscope(true)
          this.hooks.flashHint('已退出陀螺仪')
        }
        this.mouseSkyMoved = true
        const now = Date.now()
        const dt = Math.max(1, now - this.mouseSkyLastSampleMs)
        const vx = (x - this.mouseSkyLastX) / dt
        const vy = (y - this.mouseSkyLastY) / dt
        this.dragVelocityX = this.dragVelocityX * 0.35 + vx * 0.65
        this.dragVelocityY = this.dragVelocityY * 0.35 + vy * 0.65
        this.commandPort.fire('dragView', Math.round(this.mouseSkyLastX).toString() + '|' +
          Math.round(this.mouseSkyLastY).toString() + '|' + Math.round(x).toString() + '|' + Math.round(y).toString())
        this.mouseSkyLastX = x
        this.mouseSkyLastY = y
        this.mouseSkyLastSampleMs = now
      }
      return
    }
    if (event.action === 1 && this.mouseSkyPressed) {
      this.mouseSkyPressed = false
      if (!this.mouseSkyMoved && !this.hooks.isUiPoint(x, y)) {
        this.handleSkyTap(x, y)
      } else if (this.mouseSkyMoved) {
        if (Date.now() - this.mouseSkyLastSampleMs > 90) {
          this.dragVelocityX *= 0.35
          this.dragVelocityY *= 0.35
        }
        this.startSkyInertia()
      }
    }
  }

  handleSkyAxis(event: AxisEvent): void {
    const x = event.windowX
    const y = event.windowY
    if (this.hooks.isUiPoint(x, y)) { return }
    const pinchScale = event.getPinchAxisScaleValue()
    if (pinchScale > 0 && Math.abs(pinchScale - 1) > 0.001) {
      this.commandPort.fire('zoomBy', pinchScale.toFixed(4) + '|0')
      return
    }
    const horizontal = event.getHorizontalAxisValue()
    const vertical = event.getVerticalAxisValue()
    if (event.scrollStep !== undefined) {
      if (Math.abs(vertical) > 0.001) {
        const scale = vertical > 0 ? 1.12 : 0.89
        this.commandPort.fire('zoomBy', scale.toFixed(3) + '|0')
      }
      return
    }
    if (Math.abs(horizontal) > 0.001 || Math.abs(vertical) > 0.001) {
      this.commandPort.fire('panBy', (-horizontal * 28).toFixed(2) + '|' +
        (-vertical * 28).toFixed(2) + '|' + Math.round(this.hooks.skyWidth()).toString() + '|' + Math.round(this.hooks.skyHeight()).toString())
    }
  }

  handleSkyKey(event: KeyEvent): boolean {
    if (event.type !== 0) { return false }
    const width = Math.round(this.hooks.skyWidth()).toString()
    const height = Math.round(this.hooks.skyHeight()).toString()
    const pan = (x: number, y: number): boolean => {
      this.commandPort.fire('panBy', x.toString() + '|' + y.toString() + '|' + width + '|' + height)
      return true
    }
    switch (event.keyCode) {
      case KeyCode.KEYCODE_DPAD_UP: return pan(0, -80)
      case KeyCode.KEYCODE_DPAD_DOWN: return pan(0, 80)
      case KeyCode.KEYCODE_DPAD_LEFT: return pan(-80, 0)
      case KeyCode.KEYCODE_DPAD_RIGHT: return pan(80, 0)
      case KeyCode.KEYCODE_PLUS:
      case KeyCode.KEYCODE_EQUALS: this.hooks.zoomStep(0.8); return true
      case KeyCode.KEYCODE_MINUS: this.hooks.zoomStep(1.25); return true
      case KeyCode.KEYCODE_SPACE: this.hooks.centerSelectedObjectFromKeyboard(); return true
      case KeyCode.KEYCODE_ENTER: this.hooks.moveToSelectedObject(); return true
      case KeyCode.KEYCODE_F: this.hooks.setPanel('search'); return true
      case KeyCode.KEYCODE_N:
        this.nightModeStore.nightMode = !this.nightModeStore.nightMode
        this.hooks.persistNightMode()
        this.commandPort.fire('setNightMode', this.nightModeStore.nightMode ? 'true' : 'false')
        return true
      case KeyCode.KEYCODE_ESCAPE:
        if (this.hooks.modelImmersive()) this.hooks.setModelImmersive(false)
        else this.hooks.closePanel()
        return true
      default: return false
    }
  }

  // The floating panel sits above the sky touch surface.  Keep its gestures
  // owned by ArkUI so a Slider/Scroll drag can never become a sky pan.
  stopSkyInertia(resetVelocity: boolean = true): void {
    if (this.skyInertiaTimer !== 0) {
      clearInterval(this.skyInertiaTimer)
      this.skyInertiaTimer = 0
    }
    if (this.nativeSkyInertiaActive) {
      this.commandPort.fire('stopPanInertia', '')
      this.nativeSkyInertiaActive = false
    }
    if (resetVelocity) {
      this.dragVelocityX = 0
      this.dragVelocityY = 0
    }
  }

  startSkyInertia(): void {
    // Do not discard the velocity sampled from the gesture that just ended.
    this.stopSkyInertia(false)
    const initialSpeed = Math.sqrt(this.dragVelocityX * this.dragVelocityX + this.dragVelocityY * this.dragVelocityY)
    if (initialSpeed < 0.05 || !this.dragVelocitySampleValid || this.pinchActive) {
      return
    }
    this.nativeSkyInertiaActive = true
    this.commandPort.fire('startPanInertia',
      this.dragVelocityX.toFixed(4) + '|' + this.dragVelocityY.toFixed(4))
  }

  // ── M3-2：触屏主路径（原宿主 dragFollowAlpha / emitFluidDrag / handleSkyTouch，逐字等价迁移）──
  // 唯一的改写是"取值参数化"——宿主布局/几何/store 读数经 hooks 取，宿主保留动作经 hooks 调；
  // 比较边界、分支顺序、取整、事件类型判定一律未动。

  private dragFollowAlpha(dtMs: number): number {
    // Keep only a light stabilizer. The previous low-pass values made the
    // camera visibly trail behind the finger, especially beside an open menu.
    const base = this.hooks.isFoldTabletLayout() ? 0.96 : (this.hooks.isExpandedLayout() ? 0.97 : 0.94)
    return clamp(1 - Math.pow(1 - base, Math.max(1, dtMs) / 16.67), 0.88, 0.995)
  }

  private emitFluidDrag(targetX: number, targetY: number, now: number, sampleVelocity: boolean = true): void {
    const dt = this.dragLastSampleMs > 0 ? Math.max(1, now - this.dragLastSampleMs) : 16
    const rawDx = targetX - this.dragLastRawX
    const rawDy = targetY - this.dragLastRawY
    // Physical Pads have a large, high-density canvas. A small gain keeps the
    // sky responsive without changing the geometry of the native renderer.
    const gain = this.hooks.isExpandedLayout() ? 1.35 : (this.hooks.isFoldHoverLayout() ? 1.34 : 1.36)
    if (sampleVelocity && this.dragLastSampleMs > 0 && dt >= 8 && dt <= 220) {
      const vx = rawDx * gain / dt
      const vy = rawDy * gain / dt
      this.dragVelocityX = this.dragVelocityX * 0.35 + vx * 0.65
      this.dragVelocityY = this.dragVelocityY * 0.35 + vy * 0.65
      this.dragVelocitySampleValid = true
    }
    this.dragLastRawX = targetX
    this.dragLastRawY = targetY
    this.dragLastSampleMs = now

    const alpha = this.dragFollowAlpha(dt)
    const desiredX = this.dragFilteredX + rawDx * gain
    const desiredY = this.dragFilteredY + rawDy * gain
    const nextX = this.dragFilteredX + (desiredX - this.dragFilteredX) * alpha
    const nextY = this.dragFilteredY + (desiredY - this.dragFilteredY) * alpha
    if (Math.abs(nextX - this.dragFilteredX) < 0.25 && Math.abs(nextY - this.dragFilteredY) < 0.25) {
      return
    }
    this.commandPort.fire('dragView',
      Math.round(this.dragFilteredX).toString() + '|' +
      Math.round(this.dragFilteredY).toString() + '|' +
      Math.round(nextX).toString() + '|' +
      Math.round(nextY).toString())
    this.dragFilteredX = nextX
    this.dragFilteredY = nextY
    this.touchLastX = nextX
    this.touchLastY = nextY
  }

  handleSkyTouch(event: TouchEvent): void {
    const points = event.touches.length > 0 ? event.touches : event.changedTouches
    if (points.length === 0) {
      return
    }

    if (event.type === TouchType.Down) {
      this.stopSkyInertia()
      const allowTouchFeedback = !this.hooks.panelVisible()
      const downX = touchWindowX(points[0])
      const downY = touchWindowY(points[0])
      // Panel header drag detection (before isUiPoint sidebar check)
      if (this.hooks.panelVisible()) {
        const pl = panelLeft(this.hooks.isExpandedLayout(), this.hooks.skyWidth(), this.hooks.panelWidth(), this.hooks.panelOffsetX(), this.hooks.edgeMargin())
        const pr = panelRight(this.hooks.isExpandedLayout(), this.hooks.skyWidth(), this.hooks.panelWidth(), this.hooks.panelOffsetX(), this.hooks.edgeMargin())
        const pt = panelTop(this.hooks.edgeMargin(), this.hooks.panelOffsetY())
        if (downX >= pl && downX <= pr && downY >= pt && downY <= pt + 48) {
          this.panelDragging = true
          this.panelDragStartX = downX
          this.panelDragStartY = downY
          this.panelDragStartOffsetX = this.hooks.panelOffsetX()
          this.panelDragStartOffsetY = this.hooks.panelOffsetY()
          return
        }
      }
      // 左侧非手势缩放按钮（+放大 / −缩小）：与右上角快捷区同理，XComponent 吞掉
      // ArkUI onClick，必须在 Down 上按坐标分派，否则点击会穿到星图变成 selectAt。
      const zoomHit = this.hooks.skyZoomButtonAt(downX, downY)
      if (zoomHit.length > 0) {
        this.resetSkyTapSequence()
        this.hooks.setTouchStartedOnUi(true)
        this.hooks.setSkyTouchFeedback(false)
        this.hooks.setSkyTouchActive(false)
        if (zoomHit === 'in') {
          hilog.info(0x0000, 'StellariumArkUI', '[DIAG] sky zoom in via handleSkyTouch')
          this.hooks.zoomStep(0.8)
        } else {
          hilog.info(0x0000, 'StellariumArkUI', '[DIAG] sky zoom out via handleSkyTouch')
          this.hooks.zoomStep(1.25)
        }
        return
      }
      if (isDockPoint(downX, downY, this.hooks.polarScopeVisible(), this.hooks.isExpandedLayout(), this.hooks.skyWidth(), this.hooks.skyHeight(), this.hooks.panelVisible(), this.hooks.panelWidth(), this.hooks.panelOffsetX(), this.hooks.edgeMargin(), this.hooks.compactDockWidthPercent(), this.hooks.dockTop())) {
        this.resetSkyTapSequence()
        this.hooks.setDockTouchActive(true)
        this.hooks.setTouchStartedOnUi(true)
        this.hooks.setSkyTouchFeedback(false)
        this.hooks.setSkyTouchActive(false)
        return
      }
      if (this.hooks.isUiPoint(downX, downY)) {
        this.resetSkyTapSequence()
        this.hooks.setTouchStartedOnUi(true)
        // A UI touch must never inherit sky-drag ownership. This branch used to
        // set only touchStartedOnUi, unlike the dock branch below which also
        // clears the drag state: a gesture that began on the sky and lifted over
        // a panel left skyTouchActive set, so every later swipe *inside the panel*
        // cleared the "!skyTouchActive" gate in the move handler and panned the
        // star map along with the list.
        this.hooks.setSkyTouchFeedback(false)
        this.hooks.setSkyTouchActive(false)
        this.hooks.setSkyDragging(false)
        this.nativeDragActive = false
        // 手机端右上角快捷按钮（陀螺仪/音频）：XComponent 同样吞掉了 onClick，
        // 需要坐标级分派，与上方 tablet rail workaround 同理。
        if (!this.hooks.isExpandedLayout() && this.hooks.isCompactTopQuickPoint(downX, downY)) {
          const qx = this.hooks.compactTopQuickX()
          const qy = compactTopQuickY()
          // 陀螺仪按钮（上方的 44x44，圆心约 qx+22, qy+22）
          if (downX >= qx && downX <= qx + 44 && downY >= qy && downY <= qy + 44) {
            hilog.info(0x0000, 'StellariumArkUI', '[DIAG] gyro tap via handleSkyTouch')
            this.hooks.resetPanelIdle()
            this.hooks.toggleGyroscope(!this.hooks.gyroscopeEnabled())
            return
          }
          // 音频按钮（下方的 44x44，间距 10vp，圆心约 qx+22, qy+54+22）
          if (downX >= qx && downX <= qx + 44 && downY >= qy + 54 && downY <= qy + 54 + 44) {
            hilog.info(0x0000, 'StellariumArkUI', '[DIAG] audio tap via handleSkyTouch')
            this.hooks.resetPanelIdle()
            this.hooks.toggleMusic()
            this.hooks.flashHint(this.hooks.musicHintText())
            return
          }
        }
        return
      }
      this.hooks.setSkyTouchActive(true)
      this.hooks.setSkyDragging(true)
      this.hooks.cancelSelectedObjectUiChange()
      this.commandPort.fire('beginSkyGesture')
      this.hooks.pauseDetailRefreshForSkyDrag()
      this.touchStartX = downX
      this.touchStartY = downY
      this.touchLastX = this.touchStartX
      this.touchLastY = this.touchStartY
      this.touchMoved = false
        this.pinchActive = false
        this.commandPort.fire('endPinch')
        this.nativeDragActive = false
      this.lastDragCommandMs = 0
      this.dragFilteredX = downX
      this.dragFilteredY = downY
      this.dragLastRawX = downX
      this.dragLastRawY = downY
      this.dragLastSampleMs = Date.now()
      this.dragVelocityX = 0
      this.dragVelocityY = 0
      this.dragVelocitySampleValid = false
      this.dragLogCount = 0
      this.hooks.setSkyTouchFeedback(allowTouchFeedback)
      this.hooks.setSkyTouchPoint(downX, downY)
      this.hooks.setSkyTouchFeedbackMulti(allowTouchFeedback && points.length >= 2)
      hilog.info(0x0000, 'StellariumArkUI', 'sky touch down at ' + Math.round(this.touchStartX).toString() + ',' + Math.round(this.touchStartY).toString() + ' sky=' + this.hooks.skyWidth().toString() + 'x' + this.hooks.skyHeight().toString())
      if (points.length >= 2) {
        this.resetSkyTapSequence()
        this.hooks.setSkyTouchPoint2(touchWindowX(points[1]), touchWindowY(points[1]))
        this.pinchCenterX = (touchWindowX(points[0]) + this.hooks.skyTouchX2()) / 2
        this.pinchCenterY = (touchWindowY(points[0]) + this.hooks.skyTouchY2()) / 2
        this.pinchStartDistance = distance(
          touchWindowX(points[0]), touchWindowY(points[0]),
          touchWindowX(points[1]), touchWindowY(points[1]))
        this.pinchStartFov = clamp(this.hooks.fovSliderValue() > 0 ? this.hooks.fovSliderValue() : 60, 4, 180)
        this.pinchLastScale = 1
        this.pinchLastNativePushMs = Date.now()
        this.pinchNativePushPending = false
        this.pinchActive = true
        this.commandPort.fire('zoomBy', '1|1|' + this.pinchCenterX.toFixed(2) + '|' +
          this.pinchCenterY.toFixed(2) + '|' + Math.round(this.hooks.skyWidth()).toString() + '|' +
          Math.round(this.hooks.skyHeight()).toString())
      }
      return
    }

    if ((event.type === TouchType.Up || event.type === TouchType.Cancel) && this.hooks.dockTouchActive()) {
      const x = touchWindowX(points[0])
      const y = touchWindowY(points[0])
      this.hooks.setDockTouchActive(false)
      this.hooks.setTouchStartedOnUi(false)
      if (event.type === TouchType.Up) {
        const dockItem = this.hooks.dockActionAt(x, y)
        if (dockItem !== null) { this.hooks.activateDockAction(dockItem) }
      }
      return
    }
    if (!this.hooks.skyTouchActive()) {
      return
    }

    if (event.type === TouchType.Move) {
      const x = touchWindowX(points[0])
      const y = touchWindowY(points[0])
      if (this.hooks.skyTouchFeedback()) {
        this.hooks.setSkyTouchPoint(x, y)
      }
      if (points.length >= 2) {
        this.hooks.setSkyTouchFeedbackMulti(this.hooks.skyTouchFeedback())
        this.hooks.setSkyTouchPoint2(touchWindowX(points[1]), touchWindowY(points[1]))
        this.pinchCenterX = (x + this.hooks.skyTouchX2()) / 2
        this.pinchCenterY = (y + this.hooks.skyTouchY2()) / 2
        this.nativeDragActive = false
        this.stopSkyInertia()
        const currentDistance = distance(
          x, y, touchWindowX(points[1]), touchWindowY(points[1]))
        if (!this.pinchActive || this.pinchStartDistance <= 1) {
          this.pinchStartDistance = currentDistance
          this.pinchStartFov = clamp(this.hooks.fovSliderValue() > 0 ? this.hooks.fovSliderValue() : 60, 4, 180)
          this.pinchActive = true
          this.pinchLastScale = 1
          this.pinchLastNativePushMs = Date.now()
          this.pinchNativePushPending = false
          this.commandPort.fire('zoomBy', '1|1|' + this.pinchCenterX.toFixed(2) + '|' +
            this.pinchCenterY.toFixed(2) + '|' + Math.round(this.hooks.skyWidth()).toString() + '|' +
            Math.round(this.hooks.skyHeight()).toString())
        } else {
          const scale = currentDistance / this.pinchStartDistance
          this.pinchLastScale = scale
          const estimatedFov = clamp(this.pinchStartFov / Math.max(0.25, scale), 4, 180)
          this.hooks.setFovSliderValue(estimatedFov)
          this.hooks.setCurrentFovText(estimatedFov.toFixed(1) + '°')
          this.pinchNativePushPending = true
          const now = Date.now()
          if (now - this.pinchLastNativePushMs >= 16) {
            this.commandPort.fire('zoomBy', scale.toString() + '|0|' + this.pinchCenterX.toFixed(2) + '|' +
              this.pinchCenterY.toFixed(2) + '|' + Math.round(this.hooks.skyWidth()).toString() + '|' +
              Math.round(this.hooks.skyHeight()).toString())
            this.pinchLastNativePushMs = now
            this.pinchNativePushPending = false
          }
          // 缩放时弹小蓝胶囊实时显示 FOV（节流 150ms，避免桥接风暴）
          const nowMs = Date.now()
          if (nowMs - this.lastFovHintMs >= 150) {
            this.lastFovHintMs = nowMs
            this.hooks.requestFieldOfView((fovDeg: number): void => {
              this.hooks.setCurrentFovText(fovDeg.toFixed(1) + '°')
            })
          }
        }
        this.touchMoved = true
        return
      }
      this.hooks.setSkyTouchFeedbackMulti(false)

      // Panel drag handling
      if (this.panelDragging) {
        this.hooks.setTouchStartedOnUi(false)
        this.hooks.setPanelOffset(this.panelDragStartOffsetX + (x - this.panelDragStartX),
          this.panelDragStartOffsetY + (y - this.panelDragStartY))
        return
      }

      const totalMove = distance(x, y, this.touchStartX, this.touchStartY)
      // 阈值放宽到 16vp:uitest/mock 注入的触摸常有几像素位移,
      // 4vp 会把"轻点"误判成"拖动",导致 selectAt 不触发。
      if (totalMove > 16) {
        this.resetSkyTapSequence()
        this.hooks.cancelSelectedObjectUiChange()
        // Manual panning and sensor tracking must never drive the native
        // camera together. Leave gyro mode on the first real sky drag, while
        // keeping taps and pinch zoom available without changing its state.
        if (!this.touchMoved && this.hooks.gyroscopeEnabled()) {
          this.hooks.stopGyroscope(true)
          this.hooks.flashHint('已退出陀螺仪')
        }
        this.touchMoved = true
      }
      // Ownership is decided on Down: only a gesture that actually started on the
      // sky may pan it. Relying on skyTouchActive alone let a stale flag drag the
      // sky from inside a panel, so the origin is now part of the condition.
      if (this.touchMoved && !this.hooks.touchStartedOnUi()) {
        this.nativeDragActive = true
        const now = Date.now()
        if (now - this.lastDragCommandMs >= 16) {
          if (this.dragLogCount < 5) {
            hilog.info(0x0000, 'StellariumArkUI', 'dragView dx=' + Math.round(x - this.touchLastX).toString() + ' dy=' + Math.round(y - this.touchLastY).toString() + ' throttle=' + (now - this.lastDragCommandMs).toString() + 'ms')
            this.dragLogCount += 1
          }
          this.emitFluidDrag(x, y, now)
          this.lastDragCommandMs = now
        }
      }
      return
    }

    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      const x = touchWindowX(points[0])
      const y = touchWindowY(points[0])
      const endedOnUi = this.hooks.isUiPoint(x, y)
      const recordingViewChanged = this.touchMoved || this.pinchActive
      // End panel drag
      if (this.panelDragging) {
        this.panelDragging = false
        this.hooks.scheduleSelectedObjectForUiChange(160)
        return
      }
      // Gesture ownership is decided on Down. A drag that started on the sky
      // must still finish as a sky gesture even when the finger crosses the
      // floating object card before it lifts; otherwise the early return leaves
      // skyDragging set and permanently pauses detail refresh/inertia.
      if (this.hooks.touchStartedOnUi()) {
        if (this.hooks.dockTouchActive()) {
          this.hooks.setDockTouchActive(false)
          if (event.type === TouchType.Up) {
            const dockItem = this.hooks.dockActionAt(x, y)
            if (dockItem !== null) {
              this.hooks.activateDockAction(dockItem)
            }
          }
        }
        this.hooks.setTouchStartedOnUi(false)
        // Clear the same drag state the sky branch clears on lift-off: this early
        // return used to leave it behind for the next gesture to inherit.
        this.nativeDragActive = false
        this.hooks.setSkyTouchActive(false)
        this.hooks.setSkyTouchFeedback(false)
        this.hooks.setSkyDragging(false)
        return
      }
      if (this.nativeDragActive && event.type === TouchType.Up) {
        this.emitFluidDrag(x, y, Date.now(), false)
        this.startSkyInertia()
      } else if (event.type === TouchType.Cancel) {
        this.stopSkyInertia()
      } else if (!this.touchMoved && !this.pinchActive && !endedOnUi && Date.now() - this.hooks.lastInfoWinCloseMs() > 320) {
        hilog.info(0x0000, 'StellariumArkUI', 'selectAt payload: ' +
          Math.round(this.touchStartX).toString() + '|' + Math.round(this.touchStartY).toString() + '|' +
          Math.round(this.hooks.skyWidth()).toString() + '|' + Math.round(this.hooks.skyHeight()).toString())
        this.handleSkyTap(this.touchStartX, this.touchStartY)
      }
      if (this.pinchActive) {
        if (this.pinchNativePushPending) {
          this.commandPort.fire('zoomBy', this.pinchLastScale.toString() + '|0|' +
            this.pinchCenterX.toFixed(2) + '|' + this.pinchCenterY.toFixed(2) + '|' +
            Math.round(this.hooks.skyWidth()).toString() + '|' + Math.round(this.hooks.skyHeight()).toString())
        }
        this.commandPort.fire('endPinch')
        this.hooks.scheduleSkyTextureStatusCheck()
      }
      this.pinchActive = false
      this.pinchNativePushPending = false
      this.nativeDragActive = false
      this.hooks.setSkyTouchActive(false)
      this.hooks.setSkyTouchFeedback(false)
      this.hooks.setSkyTouchFeedbackMulti(false)
      this.hooks.setSkyDragging(false)
      if (event.type === TouchType.Cancel) { this.resetSkyTapSequence() }
      this.hooks.resumeDetailRefreshAfterSkyDrag()
      if (event.type === TouchType.Up && recordingViewChanged) {
        this.hooks.scheduleRecordingViewCheckpoint(this.nativeSkyInertiaActive ? 1100 : 180)
      }
    }
  }
}
