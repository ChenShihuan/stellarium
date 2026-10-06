import { I18n } from '../../pages/I18n'
import { getIcon } from '../../common/ui/ShellIcons'
import { QuickActionItem } from '../../common/derive/quickActions'
import { UI_RADIUS_CONTROL } from '../../common/ui/UiTokens'

// 快捷操作面板的单个图标按钮。
//
// 着色双路径（本组件唯一技术点）：
//   raster —— Stellarium 官方 `-off` PNG，用 colorFilter 颜色矩阵把 RGB 统一压成目标色、保留 alpha。
//             不能用 colorBlend：它会把透明背景一起染（ArkUI FAQ faqs-arkui-1328）。
//   vector —— 自研 `ic_*.svg`，走 fillColor。
// 两条路径产出同一套「亮 = 高亮 / 灭 = 暗灰」观感；官方 `-on` 图标一律不用。
//
// 网格内不显示文字（对齐参考图），长按经 onHint 出名称提示。
// 纯色替换矩阵：把 RGB 统一压成目标色、alpha 原样透传。
// 值必须归一化到 0.0–1.0（1.0 对应 255）——用 0–255 会被截断成近白（官方 FAQ faqs-arkui-1353）。
// 亮 = #EAF7FF（234/247/255），灭 = #7E8896（126/136/150）。
const TINT_ON: number[] = [
  0, 0, 0, 0, 0.9176,
  0, 0, 0, 0, 0.9686,
  0, 0, 0, 0, 1,
  0, 0, 0, 1, 0
]

const TINT_OFF: number[] = [
  0, 0, 0, 0, 0.4941,
  0, 0, 0, 0, 0.5333,
  0, 0, 0, 0, 0.5882,
  0, 0, 0, 1, 0
]

@Component
export struct QuickActionCell {
  @Prop item: QuickActionItem
  @Prop isOn: boolean
  onToggle: (id: string, value: boolean) => void = () => {}
  onHint: (text: string) => void = () => {}

  build() {
    Button() {
      Column() {
        if (this.item.kind === 'raster') {
          Image(getIcon(this.item.icon, false))
            .width(30)
            .height(30)
            .objectFit(ImageFit.Contain)
            .colorFilter(this.isOn ? TINT_ON : TINT_OFF)
        } else {
          Image(getIcon(this.item.icon, false))
            .width(26)
            .height(26)
            .objectFit(ImageFit.Contain)
            .fillColor(this.isOn ? '#EAF7FF' : '#7E8896')
        }
      }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
    }
      .id('quick-action-' + this.item.id)
      .layoutWeight(1)
      .aspectRatio(1)
      .padding(0)
      // 只给「开」画底框：夜间模式下灭态的浅底框在暗背景里几乎不可辨，反而糊成一团。
      // 边框宽度恒为 1（颜色透明）以免开关切换时格子尺寸跳动。
      .backgroundColor(this.isOn ? 'rgba(107, 163, 214, 0.12)' : Color.Transparent)
      .border({ width: 1, color: this.isOn ? 'rgba(107, 163, 214, 0.18)' : Color.Transparent })
      .borderRadius(UI_RADIUS_CONTROL)
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .accessibilityText(I18n.t(this.item.labelKey))
      .onClick(() => { this.onToggle(this.item.id, !this.isOn) })
      .gesture(LongPressGesture().onAction(() => { this.onHint(I18n.t(this.item.labelKey)) }))
  }
}
