import { curves } from '@kit.ArkUI'
import { UI_RADIUS_PILL } from '../../common/ui/UiTokens'
import { getIcon } from '../../common/ui/ShellIcons'

// 面板头部 chrome（原宿主 ``panelHeader()``）：返回按钮 + 标题/副标题 + 关闭按钮。
//
// 标题与副标题文本、返回可用性、路由过渡的透明度/位移都由宿主算好后传入；
// 返回与关闭动作以回调注入（``handlePanelBackTap`` / ``closePanel(true) + resetPanelIdle``）。
// 长按/点按后的实时刷新仍由宿主状态驱动（``panelTitle()`` 会随 ``observationTimeText`` /
// ``timeStore.timeRateText`` 变化重新求值，再经 ``@Prop`` 刷新本组件）。
// ``panel-back`` / ``panel-close`` 两个静态 id 锚点原样保留。

@Component
export struct PanelHeader {
  @Prop title: ResourceStr
  @Prop subtitle: string
  @Prop canGoBack: boolean
  @Prop routeOpacity: number
  @Prop routeOffsetX: number
  onBack: () => void = () => {}
  onClose: () => void = () => {}

  build() {
    Row() {
      if (this.canGoBack) {
        Button() {
          Image(getIcon('back', false)).width(17).height(17).fillColor('#D9F1FF')
        }
          .id('panel-back')
          .width(44)
          .height(44)
          .padding(0)
          .borderRadius(0)
          .backgroundColor(Color.Transparent)
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .zIndex(3)
          .stateStyles({ pressed: { .opacity(0.62) } })
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.OPACITY.animation({ duration: 130, curve: Curve.EaseOut })
              .combine(TransitionEffect.translate({ x: -10, y: 0 }).animation({ duration: 180, curve: curves.springMotion(0.42, 0.86) })),
            TransitionEffect.OPACITY.animation({ duration: 100, curve: Curve.EaseIn })
          ))
          .onClick(() => { this.onBack() })
          .margin({ right: 8 })
      }
      Column() {
        Text(this.title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#E5FFFFFF')
        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize(14)
            .fontColor('#99FFFFFF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
        }
      }
        .height(this.subtitle.length > 0 ? 56 : 44)
        .justifyContent(FlexAlign.Center)
        .opacity(this.routeOpacity)
        .translate({ x: this.routeOffsetX, y: 0 })
      Blank()
      Button() {
        Image($r('app.media.ic_close'))
          .width(18)
          .height(18)
          .fillColor('#E5FFFFFF')
      }
      .id('panel-close')
      .width(36)
      .height(36)
      .padding(0)
      .borderRadius(UI_RADIUS_PILL)
      .backgroundColor('rgba(255, 255, 255, 0.06)')
      .zIndex(10)
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .onClick(() => { this.onClose() })
      .margin({ right: 6 })
    }
      .width('100%')
      .height(this.subtitle.length > 0 ? 56 : 44)
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 14 })
      .zIndex(4)
      .animation({ duration: 180, curve: curves.springMotion(0.42, 0.86) })
  }
}
