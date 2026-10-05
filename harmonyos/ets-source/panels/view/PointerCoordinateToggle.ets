import { UI_RADIUS_CONTROL } from '../../common/ui/UiTokens'

// 「指针坐标」插件面板的开关行（原宿主**参数化** `@Builder pointerCoordinateToggle(label, enabled, setting)`）。
//
// 为什么改成组件（§13.1 规则 3）：原 @Builder 的 `enabled` 是简单类型形参、按值捕获，子树首帧后冻结 ——
// 插件回包刷新后开关不会跟着变，必须重开面板才更新。改成组件后由 `@Prop isOn` 实时刷新。
//
// 迁移时移出组件的两件事：
//   - 写回：原 builder 内 `this.setPointerCoordinates(setting, value ? '1' : '0')` 抽成 `onToggle` 回调
//     （宿主按 setting 名分派到 native 桥）；
//   - 底色/边框色由调用方传入（夜视三色 + 面板色 + 描边色）。
//
// 视觉逐字保留：Text 12 / Toggle 46×28 / 选中色 accent / 内边距 left 10 right 8 top 7 bottom 7 /
// 开态底色 rgba(107,163,214,0.12)、边框 rgba(107,163,214,0.18) / 圆角 UI_RADIUS_CONTROL / 180ms EaseOut。
@Component
export struct PointerCoordinateToggle {
  @Prop label: string
  @Prop isOn: boolean
  @Prop textColor: string
  @Prop accentColor: string
  @Prop panelColor: string
  @Prop lineColor: string
  onToggle: (value: boolean) => void = () => {}

  build() {
    Row() {
      Text(this.label).fontSize(12).fontColor(this.textColor).layoutWeight(1).maxLines(2)
      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .width(46).height(28).selectedColor(this.accentColor)
        .onChange((value: boolean) => { this.onToggle(value) })
    }
      .width('100%').padding({ left: 10, right: 8, top: 7, bottom: 7 })
      .backgroundColor(this.isOn ? 'rgba(107,163,214,0.12)' : this.panelColor)
      .border({ width: 1, color: this.isOn ? 'rgba(107,163,214,0.18)' : this.lineColor })
      .borderRadius(UI_RADIUS_CONTROL)
      .animation({ duration: 180, curve: Curve.EaseOut })
  }
}
