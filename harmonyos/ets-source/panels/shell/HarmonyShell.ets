import { UI_RADIUS_PILL } from '../../common/ui/UiTokens'
import { ViewCenterCoordinateOverlay } from '../overlay/ViewCenterCoordinateOverlay'
import { GyroTargetGuide } from '../astro/GyroTargetGuide'
import { OverlayStore } from '../../state/OverlayStore'
import { GyroStore } from '../../state/GyroStore'

// 和谐桌面壳的共享 chrome（原宿主无参 @Builder `harmonyShell()` 的三层常驻浮层）。
//
// 原 `harmonyShell()` 的根 Stack 里同时有：① 三种布局壳（foldHover / expanded / compact）
// 的分发；② 视图中心坐标叠层；③ 顶层 Dock 命中靶（Block，必须与星空触摸层同级才能拦住
// 星图手势，见原注释）；④ 陀螺仪指引；⑤ 点击反馈气泡。
//
// 其中：
//   - 布局壳分发里的 `hoverObservatoryShell` / `expandedShell` 仍是宿主 @Builder，
//     `compactShell` 已组件化；把它经 @BuilderParam 传进子组件会真机退出（§13.1 规则 9），
//     故**分发留在宿主调用点**（同 Phase 6a 的交互导览分发处置）。
//   - 顶层 Dock 命中靶必须与星空触摸层处于**同一层**（`HitTestMode.Block` 只拦同级/其后
//     的兄弟子树），故同样留在宿主调用点，不并入本组件。
//   - 组件只承载**不依赖同级拦截**的常驻浮层：视图中心坐标叠层、陀螺仪指引、点击反馈气泡。
//
// 视觉、几何、zIndex、命中语义逐字保留；组件根用 `HitTestMode.Transparent`，确保宿主同级
// 的布局壳仍可命中（子节点照常响应）。
@Component
export struct HarmonyShell {
  @ObjectLink overlayStore: OverlayStore
  @ObjectLink gyroStore: GyroStore

  @Prop isExpandedLayout: boolean
  @Prop viewCoordinatesVisible: boolean
  @Prop primaryText: string
  @Prop secondaryText: string
  @Prop overlayWidth: number
  @Prop overlayLeft: number
  @Prop overlayTop: number
  @Prop hintTop: number
  @Prop actionHint: ResourceStr

  onHandleViewCoordinateTouch: (event: TouchEvent) => void = () => {}

  build() {
    Stack() {
      if (this.viewCoordinatesVisible) {
        Stack() {
          ViewCenterCoordinateOverlay({
            store: this.overlayStore,
            primaryText: this.primaryText,
            secondaryText: this.secondaryText,
            labelWidth: this.isExpandedLayout ? 78 : 68,
            onHandleTouch: (event: TouchEvent) => { this.onHandleViewCoordinateTouch(event) }
          })
        }
          .width(this.overlayWidth)
          .position({ x: this.overlayLeft, y: this.overlayTop })
          .zIndex(12)
          .hitTestBehavior(HitTestMode.Default)
          .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut }))
      }

      // Gyroscope target guide: it is deliberately visual-only, so it never
      // steals a pan, pinch, or button press from the sky and chrome layers.
      if (this.gyroStore.gyroGuideVisible) {
        Stack() { GyroTargetGuide({ store: this.gyroStore }) }
          .position({ x: this.gyroStore.gyroGuideX, y: this.gyroStore.gyroGuideY })
          .width(44)
          .height(44)
          .zIndex(4)
          .hitTestBehavior(HitTestMode.None)
          .animation({ duration: 130, curve: Curve.Linear })
          .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut }))
      }

      // 点击反馈提示：置顶显示、不拦截触摸
      if (this.actionHint !== '') {
        Row() {
          Text(this.actionHint)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .padding({ left: 16, right: 16, top: 9, bottom: 9 })
            .backgroundColor('rgba(91, 147, 191, 0.92)')
            .borderRadius(UI_RADIUS_PILL)
            .shadow({ radius: 20, color: 'rgba(0, 0, 0, 0.30)', offsetX: 0, offsetY: 8 })
        }
          .hitTestBehavior(HitTestMode.None)
          .position({ x: 0, y: this.hintTop })
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .zIndex(20)
          // 提示气泡：下滑淡入、上浮淡出
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.EaseOut })
              .combine(TransitionEffect.translate({ x: 0, y: -12 }).animation({ duration: 220, curve: Curve.Friction })),
            TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseIn })
              .combine(TransitionEffect.translate({ x: 0, y: -8 }).animation({ duration: 220, curve: Curve.EaseIn }))
          ))
      }
    }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)
  }
}
