import { QuickActionItem } from '../../common/derive/quickActions'
import { QuickActionGrid } from '../quick/QuickActionGrid'

// 「快捷操作」面板，对应 `activePanel === 'quick'`（Dock 中间入口）：
// 2×6 = 12 个显示开关图标；标题栏显示当前位置且本身是按钮（跳「位置」面板，见 PanelHeader 的 titleAsButton）。
//
// 12 项描述表、当前值、动作全部由宿主算好后经 @Prop / 回调下发；本组件不读 store、不碰桥。
@Component
export struct QuickPanel {
  @Prop items: QuickActionItem[]
  @Prop values: Record<string, boolean>
  onToggle: (id: string, value: boolean) => void = () => {}
  onHint: (text: string) => void = () => {}

  build() {
    Column() {
      QuickActionGrid({
        items: this.items,
        values: this.values,
        onToggle: (id: string, value: boolean) => { this.onToggle(id, value) },
        onHint: (text: string) => { this.onHint(text) }
      })
    }
      .width('100%')
  }
}
