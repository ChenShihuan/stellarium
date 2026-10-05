import { curves } from '@kit.ArkUI'
import { UI_RADIUS_PANEL } from '../../common/ui/UiTokens'
import { ShellAction } from '../../pages/StellariumTypes'
import { DockButton } from './DockButton'

// 主界面底部 Dock 栏（原宿主无参 @Builder bottomDock）。
//
// 入口集合、展开/紧凑两档的尺寸、玻璃态与透明度由宿主以 @Prop 传入；
// 每个入口的激活判定、触摸、点按与面板触摸回注宿主（§13.1 规则 6）。
// 视觉与几何逐字保留（含原有两处 onTouch 叠加，后者生效、并已内含 notePanelTouch）。

@Component
export struct BottomDock {
  @Prop actions: ShellAction[]
  @Prop isExpanded: boolean
  @Prop panelVisible: boolean
  @Prop chromeOpacity: number
  @Prop isGlass: boolean
  @Prop widthPercent: number
  @Prop languageRevision: number
  @Prop iconSize: number
  @Prop labelFontSize: number
  @Prop itemHeight: number
  isActive: (item: ShellAction) => boolean = () => false
  onDockTouch: (event: TouchEvent) => void = () => {}
  onDockTap: (item: ShellAction) => void = () => {}
  onPanelTouch: (event: TouchEvent) => void = () => {}

  build() {
    Row() {
      // 所有屏幕统一使用五个入口；手机仅改变面板的呈现方式，不改变动作集合。
      ForEach(this.actions, (item: ShellAction) => {
        DockButton({
          icon: item.icon, label: item.label, active: this.isActive(item),
          iconSize: this.iconSize, labelFontSize: this.labelFontSize, itemHeight: this.itemHeight,
          onTouchEvent: (event: TouchEvent) => { this.onDockTouch(event) },
          onTap: () => { this.onDockTap(item) }
        })
      }, (item: ShellAction) => item.panel + '/' + this.languageRevision.toString())
    }
      .height(this.isExpanded ? 48 : 66)
      .width(this.isExpanded ? '100%' : this.widthPercent + '%')
      .padding({ left: this.isExpanded ? 4 : 6, right: this.isExpanded ? 4 : 6 })
      .justifyContent(FlexAlign.SpaceBetween)
      .backgroundColor(this.isGlass ? 'rgba(10, 14, 26, 0.42)' : 'rgba(25, 26, 28, 0.64)')
      .backdropBlur(this.isGlass ? 40 : 26)
      .border({ width: 0.5, color: this.isGlass ? 'rgba(147, 215, 255, 0.10)' : 'rgba(255, 255, 255, 0.08)' })
      .borderRadius(UI_RADIUS_PANEL)
      .shadow({ radius: this.isExpanded ? 18 : 28, color: 'rgba(0, 0, 0, 0.30)', offsetX: 0, offsetY: this.isExpanded ? 8 : 14 })
      .alignSelf(ItemAlign.Center)
      .onTouch((event: TouchEvent) => { this.onPanelTouch(event) })
      .opacity(this.chromeOpacity * (this.panelVisible ? 1.0 : 0.985))
      .scale({ x: this.chromeOpacity < 1 ? 0.98 : (this.panelVisible ? 1.0 : 0.985), y: this.chromeOpacity < 1 ? 0.98 : (this.panelVisible ? 1.0 : 0.985) })
      .translate({ y: this.panelVisible ? 0 : 2 })
      .animation({ duration: 300, curve: curves.springMotion(0.46, 0.86) })
      .onTouch((event: TouchEvent) => { this.onDockTouch(event) })
  }
}
