import { ShellAction } from '../types/StellariumTypes'
import { BottomDock } from '../../panels/shell/BottomDock'
import { SystemBottomNav } from '../../panels/shell/nav/SystemBottomNav'
import { BottomNavSurface, DEFAULT_BOTTOM_NAV_SURFACE, resolveBottomNavSurface } from './BottomNavModel'

// 底部导航分发器：App 定义的导航基底。
//
// 皮肤 A（系统材质 HdsTabs）与皮肤 B（现有自绘 Dock）二选一；两者的条目、
// 选中态、几何与命中完全一致，因此切换皮肤不需要改面板锚点或输入分发。
// T0 只接入自绘皮肤（零视觉变化）；系统皮肤在 T1 按 surface 分支接入。

@Component
export struct BottomNav {
  @Prop actions: ShellAction[]
  @Prop isExpanded: boolean
  @Prop panelVisible: boolean
  @Prop activePanel: string
  @Prop chromeOpacity: number
  @Prop isGlass: boolean
  @Prop widthPercent: number
  @Prop languageRevision: number
  @Prop iconSize: number
  @Prop labelFontSize: number
  @Prop itemHeight: number
  @Prop surface: string = DEFAULT_BOTTOM_NAV_SURFACE
  onDockTouch: (event: TouchEvent) => void = () => {}
  onDockTap: (item: ShellAction) => void = () => {}
  onPanelTouch: (event: TouchEvent) => void = () => {}

  build() {
    if (resolveBottomNavSurface(this.surface) === BottomNavSurface.SYSTEM) {
      SystemBottomNav({
        actions: this.actions,
        activePanel: this.activePanel,
        languageRevision: this.languageRevision,
        onDockTap: (item: ShellAction) => { this.onDockTap(item) }
      })
    } else {
      BottomDock({
        actions: this.actions, isExpanded: this.isExpanded,
        panelVisible: this.panelVisible, chromeOpacity: this.chromeOpacity,
        isGlass: this.isGlass, widthPercent: this.widthPercent,
        languageRevision: this.languageRevision,
        iconSize: this.iconSize,
        labelFontSize: this.labelFontSize,
        itemHeight: this.itemHeight,
        activePanel: this.activePanel,
        onDockTouch: (event: TouchEvent) => { this.onDockTouch(event) },
        onDockTap: (item: ShellAction) => { this.onDockTap(item) },
        onPanelTouch: (event: TouchEvent) => { this.onPanelTouch(event) }
      })
    }
  }
}
