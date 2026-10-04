// 天空输入控制器（PLAN §15.10 / §15.11 M3-1「天空输入①骨架」）。
//
// 原宿主 MainWindowNativeNode 的「鼠标 / 键盘 / 滚轮轴 / 点按序列 / 惯性」输入路径整体下沉，
// 共 8 个方法：
//   handleSkyMouse(51) / handleSkyKey(31) / handleSkyAxis(23) / handleSkyTap(11) /
//   resetSkyTapSequence(3) / isSkyDoubleTap(19) / startSkyInertia(11) / stopSkyInertia(14)。
// 触屏主路径 handleSkyTouch / emitFluidDrag 仍留宿主（M3-2），本片只把与两者共享的 5 个
// 草稿字段的所有权转移到本控制器（dragVelocityX / dragVelocityY / dragVelocitySampleValid /
// pinchActive / nativeSkyInertiaActive），宿主经 this.skyInputCtl() 读写，M3-2 再把
// handleSkyTouch 收入本类、届时这些跨边界访问自然消失。
//
// 职责划分（§15.7 规则 2）：本片方法不产生「组件要消费的可观察状态」（触摸反馈点
// skyTouchFeedback / skyTouchX/Y 属 M3-2 的 @State），故不改动任何 @Observed store；
// 本片迁移的 16 个字段全部是逐帧/草稿字段，留在控制器、不入被观察 store。
//
// 依赖注入（§15.7 规则 1 / §13.1 规则 6）：控制器不 import NAPI/UI。
//   - 桥 fire（dragView / zoomBy / panBy / startPanInertia / stopPanInertia / setNightMode）
//     经 CommandPort（与既有控制器同例）；
//   - §15.6 登记的 A2 热路径 isUiPoint 与全部宿主保留动作（路由 setPanel/closePanel、
//     zoomStep / moveToSelectedObject / centerSelectedObjectFromKeyboard、选中入口
//     requestSkySelection / clearSkySelectionFromDoubleTap / measureAngleAt、陀螺退出、
//     夜间模式持久化、模型沉浸态）一律经 SkyInputHostHooks 具名回注，宿主保留实现，不搬；
//   - NightModeStore 以实例引用持有一处（键盘 N 键切换夜间模式）。
import hilog from '@ohos.hilog'
import { KeyCode } from '@kit.InputKit'
import { CommandPort } from '../bridge/CommandPort'
import { NightModeStore } from '../state/NightModeStore'
import { distance } from '../common/derive/astro'

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

  // ── M3-2（handleSkyTouch / emitFluidDrag 仍在宿主）共享字段：本片转移所有权，
  //    宿主经 this.skyInputCtl().<field> 访问；M3-2 收入本类后恢复为纯私有。──
  nativeSkyInertiaActive: boolean = false
  dragVelocityX: number = 0
  dragVelocityY: number = 0
  dragVelocitySampleValid: boolean = false
  pinchActive: boolean = false

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
}
