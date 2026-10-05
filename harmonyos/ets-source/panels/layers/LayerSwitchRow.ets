import { curves } from '@kit.ArkUI'
import { UI_RADIUS_CONTROL } from '../../common/ui/UiTokens'

// 「图层」面板的开关行（原宿主参数化 `@Builder switchRow(label, enabled, actionId, cmd?)`）。
//
// 为什么要改成组件（§13.1 规则 3）：原 @Builder 用简单类型形参接收 label/enabled，参数按值捕获，
// 首帧之后整行冻结 —— 点开关不会立即变色，只有面板重建才刷新。改成组件后由 @Prop 实时刷新。
//
// 迁移时把原 builder 里靠 actionId 分派的逻辑全部移出组件：
//   - isOn / 行底色 / 边框色：调用方传入的 `enabled` 即当前开关值（原 builder 里
//     `actionId === 'actionShow_Ground' ? this.ground : (... : enabled)` 的三元判断在调用点
//     本来就传的是 `this.ground` / `this.mistHorizon`，等价）；
//   - onChange 的写回（setLayer / setBridgeFlag / setSkyDisplaySetting）与 flashHint 提示
//     经 onToggle 回调由宿主完成；
//   - 与当前值相同的重复触发仍在此拦掉（等价于原 builder 对 ground / mistHorizon 的提前 return）。
//
// 视觉逐字保留：Text 14 / Toggle 46×28 / 选中色 #5B93BF / 行高 42 / 底色与边框的开关态 rgba /
// 圆角 UI_RADIUS_CONTROL / 下边距 6 / 200ms springMotion(0.45, 0.9)。
@Component
export struct LayerSwitchRow {
  @Prop label: ResourceStr
  @Prop isOn: boolean
  @Prop labelColor: string = '#E5FFFFFF'
  @Prop selectedColor: string = '#5B93BF'
  onToggle: (value: boolean) => void = () => {}

  build() {
    Row() {
      Text(this.label)
        .fontSize(14)
        .fontColor(this.labelColor)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .width(46)
        .height(28)
        .selectedColor(this.selectedColor)
        .clickEffect({ level: ClickEffectLevel.LIGHT })
        .onChange((value: boolean) => {
          if (value === this.isOn) return
          this.onToggle(value)
        })
    }
      .height(42)
      .width('100%')
      .padding({ left: 10, right: 8 })
      .backgroundColor(this.isOn ? 'rgba(107, 163, 214, 0.12)' : 'rgba(255, 255, 255, 0.04)')
      .border({ width: 1, color: this.isOn ? 'rgba(107, 163, 214, 0.18)' : 'rgba(255, 255, 255, 0.05)' })
      .borderRadius(UI_RADIUS_CONTROL)
      .margin({ bottom: 6 })
      .animation({ duration: 200, curve: curves.springMotion(0.45, 0.9) })
  }
}
