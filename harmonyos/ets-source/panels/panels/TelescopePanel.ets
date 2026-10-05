// 「望远镜」面板（原宿主 panelContent() 的 `telescope` 分支，分支体原样下沉，Phase 4i）。
//
// 判定条件 `activePanel === 'telescope'` 留在宿主；分支体只是把既有 Lx200Panel 包进
// Scroll + Column 并加一行提示文案，因此本组件除 @ObjectLink store 外都是主题色 @Prop
// 与回注宿主的动作（新建 / 选择 / 校验 / 保存 / 删除 / 连接测试 / GoTo / 同步 / 中止 /
// 读取位置 / 实时位置，§13.1 规则 6）。
// 视觉逐字保留：Scroll 撑满（layoutWeight(1)）+ Column({ space: 8 }) + 四周 8 内边距。
// 本文件不含 @BuilderParam，不含参数化 @Builder（规则 9）。
import { I18n } from '../../pages/I18n'
import { TelescopeStore } from '../../state/TelescopeStore'
import { Lx200Panel } from '../telescope/Lx200Panel'

@Component
export struct TelescopePanel {
  @ObjectLink store: TelescopeStore
  @Prop textColor: string
  @Prop subColor: string
  @Prop accentColor: string
  @Prop panelColor: string
  @Prop inputColor: string
  @Prop lineColor: string
  @Prop inputLineColor: string
  onBeginNew: () => void = () => {}
  onSelectProfile: (slot: number) => void = () => {}
  onSelectProtocol: (protocol: string) => void = () => {}
  onValidateEditor: () => void = () => {}
  onSave: () => void = () => {}
  onDelete: () => void = () => {}
  onTest: () => void = () => {}
  onGoto: () => void = () => {}
  onSync: () => void = () => {}
  onAbort: () => void = () => {}
  onReadPosition: (center: boolean) => void = () => {}
  onSetLivePosition: (enabled: boolean) => void = () => {}

  build() {
      Scroll() {
        Column({ space: 8 }) {
          Text(I18n.t('telescope_control_hint')).fontSize(10).fontColor(this.subColor).width('100%')
          Lx200Panel({
        store: this.store,
        textColor: this.textColor, subColor: this.subColor, accentColor: this.accentColor,
        panelColor: this.panelColor, inputColor: this.inputColor, lineColor: this.lineColor, inputLineColor: this.inputLineColor,
        onBeginNew: () => { this.onBeginNew() },
        onSelectProfile: (slot: number) => { this.onSelectProfile(slot) },
        onSelectProtocol: (protocol: string) => { this.onSelectProtocol(protocol) },
        onValidateEditor: () => { this.onValidateEditor() },
        onSave: () => { this.onSave() },
        onDelete: () => { this.onDelete() },
        onTest: () => { this.onTest() },
        onGoto: () => { this.onGoto() },
        onSync: () => { this.onSync() },
        onAbort: () => { this.onAbort() },
        onReadPosition: (center: boolean) => { this.onReadPosition(center) },
        onSetLivePosition: (enabled: boolean) => { this.onSetLivePosition(enabled) }
      })
        }.width('100%').padding({ left: 8, right: 8, top: 8, bottom: 8 })
      }.width('100%').layoutWeight(1).scrollBar(BarState.Auto).scrollBarWidth(4).scrollBarColor('#33FFFFFF')
  }
}
