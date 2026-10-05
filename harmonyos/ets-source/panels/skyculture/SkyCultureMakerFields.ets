import { UI_RADIUS_CONTROL } from '../../common/ui/UiTokens'

// 星文化制作器的单行文本字段（原宿主参数化 `@Builder skyCultureMakerField`）。
//
// 为什么要改成组件（§13.1 规则 3）：原 @Builder 的 value/placeholder 是简单类型形参，按值捕获，
// 首帧之后整段冻结 —— 撤销 / 重置 / 导入草稿后字段不会刷新。改成组件后由 @Prop 实时刷新。
// 编辑后通过 onEdited 回调让宿主重新排一次自动保存（原 builder 内联的 scheduleSkyCultureMakerSave）。
//
// 视觉逐字保留：标签 10 号、输入框高 38 / 字号 12、圆角 UI_RADIUS_CONTROL、边框 1。
@Component
export struct SkyCultureMakerField {
  @Prop label: ResourceStr
  @Prop value: string
  @Prop placeholder: ResourceStr
  @Prop labelColor: string
  @Prop textColor: string
  @Prop inputColor: string
  @Prop inputBorderColor: string
  onChange: (value: string) => void = () => {}
  onEdited: () => void = () => {}

  build() {
    Column({ space: 5 }) {
      Text(this.label).fontSize(10).fontColor(this.labelColor).width('100%')
      TextInput({ text: this.value, placeholder: this.placeholder })
        .height(38).width('100%').fontSize(12).fontColor(this.textColor).placeholderColor(this.labelColor)
        .backgroundColor(this.inputColor).border({ width: 1, color: this.inputBorderColor }).borderRadius(UI_RADIUS_CONTROL)
        .onChange((text: string) => { this.onChange(text); this.onEdited() })
    }.width('100%')
  }
}

// 星文化制作器的多行文本字段（原宿主参数化 `@Builder skyCultureMakerLongField`）。同上。
@Component
export struct SkyCultureMakerLongField {
  @Prop label: ResourceStr
  @Prop value: string
  @Prop placeholder: ResourceStr
  @Prop labelColor: string
  @Prop textColor: string
  @Prop inputColor: string
  @Prop inputBorderColor: string
  onChange: (value: string) => void = () => {}
  onEdited: () => void = () => {}

  build() {
    Column({ space: 5 }) {
      Text(this.label).fontSize(10).fontColor(this.labelColor).width('100%')
      TextArea({ text: this.value, placeholder: this.placeholder })
        .height(94).width('100%').fontSize(12).fontColor(this.textColor).placeholderColor(this.labelColor)
        .backgroundColor(this.inputColor).border({ width: 1, color: this.inputBorderColor }).borderRadius(UI_RADIUS_CONTROL)
        .onChange((text: string) => { this.onChange(text); this.onEdited() })
    }.width('100%')
  }
}
