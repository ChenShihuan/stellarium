import { curves } from '@kit.ArkUI'
import { UI_RADIUS_CONTROL } from '../../common/ui/UiTokens'
import { getIcon } from '../../common/ui/ShellIcons'

// 底部 Dock 的单个入口按钮（原宿主参数化 ``@Builder dockButton(item)``）。
//
// 展开/紧凑两档只影响图标尺寸、标签字号与行高，宿主算好后以 ``@Prop`` 传入；
// 触摸与点按分别回注 ``handleDockTouch`` / ``activateDockAction``。
// 参数化 @Builder 不能保留（简单类型参数按值捕获，首帧后冻结），故下沉为组件。

@Component
export struct DockButton {
  @Prop icon: string
  @Prop label: ResourceStr
  @Prop active: boolean
  @Prop iconSize: number
  @Prop labelFontSize: number
  @Prop itemHeight: number
  onTouchEvent: (event: TouchEvent) => void = () => {}
  onTap: () => void = () => {}

  build() {
    Column() {
      Image(getIcon(this.icon, this.active))
        .width(this.iconSize)
        .height(this.iconSize)
        .objectFit(ImageFit.Contain)
        .fillColor(this.active ? '#70C8FF' : '#E5FFFFFF')
        .opacity(this.active ? 1 : 0.78)
      Text(this.label)
        .fontSize(this.labelFontSize)
        .fontColor(this.active ? '#70C8FF' : '#99FFFFFF')
        .margin({ top: 2 })
    }
      .layoutWeight(1)
      .height(this.itemHeight)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(Color.Transparent)
      .borderRadius(UI_RADIUS_CONTROL)
      .scale({ x: 1.0, y: 1.0 })
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .onTouch((event: TouchEvent) => { this.onTouchEvent(event) })
      .stateStyles({
        pressed: {
          .scale({ x: 0.92, y: 0.92 })
          .backgroundColor('rgba(255, 255, 255, 0.10)')
        }
      })
      .animation({ duration: 300, curve: curves.springMotion(0.46, 0.86) })
      .onClick(() => { this.onTap() })
  }
}
