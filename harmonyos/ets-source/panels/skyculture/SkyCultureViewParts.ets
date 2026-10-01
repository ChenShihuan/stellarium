import { curves } from '@kit.ArkUI'
import { UI_RADIUS_CONTROL } from '../../common/ui/UiTokens'
import { I18n } from '../../pages/I18n'

// 「星空文化」查看器面板的五个叶件（原宿主 private @Builder，Phase 4d）。
//
// 全部由**参数化 @Builder** 改为组件（§13.1 规则 3）：原 target/kind/title 等简单类型形参按值捕获，
// 首帧后子树冻结 —— 切档 / 展开 / 选项高亮都不刷新。改组件后由 @Prop 实时刷新，宿主只注入
// 「宿主算好的值 + 夜视三色 + 回调」，状态与桥调用仍留在宿主（规则 5）。
//
// 本文件不含 @ObjectLink：这五个叶件都只吃 @Prop，不接受 @BuilderParam（规则 9）。
// 视觉逐字保留，未改任何字号 / 间距 / 圆角 / 动画时长。

// 分组小标题（原 `skyCultureSectionHeader(title, subtitle)`）。
@Component
export struct SkyCultureSectionHeader {
  @Prop title: ResourceStr
  @Prop subtitle: ResourceStr
  @Prop textColor: string
  @Prop subColor: string
  @Prop accentColor: string

  build() {
    Row({ space: 8 }) {
      Row().width(3).height(27).backgroundColor(this.accentColor).borderRadius(2)
      Column({ space: 2 }) {
        Text(this.title).fontSize(13).fontColor(this.textColor).fontWeight(FontWeight.Medium).width('100%')
        Text(this.subtitle).fontSize(9).fontColor(this.subColor).width('100%').maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }.width('100%').padding({ left: 2, right: 2, top: 4, bottom: 7 })
  }
}

// 元信息小块（原 `skyCultureMetaItem(label, value, accent)`）。
@Component
export struct SkyCultureMetaItem {
  @Prop label: ResourceStr
  @Prop value: string
  @Prop accent: boolean
  @Prop subColor: string
  @Prop textColor: string
  @Prop accentColor: string
  @Prop bgColor: string
  @Prop cardBorder: string

  build() {
    Column({ space: 5 }) {
      Text(this.label).fontSize(10).fontColor(this.subColor).width('100%').maxLines(1)
      Text(this.value).fontSize(12).fontColor(this.accent ? this.accentColor : this.textColor).width('100%')
        .maxLines(2).lineHeight(17).textOverflow({ overflow: TextOverflow.Ellipsis })
    }.width('47.5%').height(70).padding({ left: 11, right: 11, top: 10, bottom: 9 })
      .backgroundColor(this.bgColor).border({ width: 0.5, color: this.cardBorder })
      .borderRadius(UI_RADIUS_CONTROL)
      .margin({ bottom: 8 })
  }
}

// 标签模式选择卡片（原 `skyCultureLabelSettingCard` + `skyCultureLabelModePicker` 合并为一个组件）。
//
// 合并原因：settingCard 只是给 modePicker 包一层描边，二者调用点一一对应；合并后避免十几条
// 颜色属性在两组件间再传一遍。展开标记 / 当前档位 / 可选项都由宿主算好后经 @Prop 传入；
// 切换与选中通过 onToggle / onSelectMode 回注宿主（宿主内仍走原有 animateTo 与桥调用）。
@Component
export struct SkyCultureLabelSettingCard {
  @Prop target: string
  @Prop title: ResourceStr
  @Prop options: string[]
  @Prop mode: number
  @Prop isOpen: boolean
  @Prop subColor: string
  @Prop textColor: string
  @Prop accentColor: string
  @Prop cardBorder: string
  @Prop pickerSurface: string
  @Prop pickerHeader: string
  @Prop pickerHeaderActive: string
  @Prop pickerSelected: string
  @Prop pickerOption: string
  @Prop inputColor: string
  onToggle: (target: string) => void = () => {}
  onSelectMode: (target: string, index: number) => void = () => {}

  build() {
    Column() {
      Column() {
        Row() {
          Column({ space: 1 }) {
            Text(this.title).fontSize(9).fontColor(this.subColor).width('100%')
            Text(this.options[this.mode])
              .fontSize(12).fontColor(this.textColor).width('100%').maxLines(2).lineHeight(17)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }.layoutWeight(1)
          Text(this.isOpen ? I18n.t('culture_collapse') : I18n.t('culture_expand')).fontSize(10)
            .fontColor(this.textColor).padding({ left: 7, right: 7, top: 4, bottom: 4 })
            .backgroundColor(this.isOpen ? this.pickerSelected : this.inputColor)
            .border({ width: 1, color: this.isOpen ? this.accentColor : this.cardBorder })
            .borderRadius(UI_RADIUS_CONTROL)
            .animation({ duration: 160, curve: Curve.EaseInOut })
        }.height(52).width('100%').padding({ left: 12, right: 12 })
          .backgroundColor(this.isOpen ? this.pickerHeaderActive : this.pickerHeader)
          .borderRadius(UI_RADIUS_CONTROL)
          .animation({ duration: 160, curve: Curve.EaseInOut })
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .hitTestBehavior(HitTestMode.Block)
          .onClick(() => {
            this.onToggle(this.target)
          })
        if (this.isOpen) {
          Column({ space: 6 }) {
            ForEach(this.options, (option: string, index: number) => {
              Row({ space: 10 }) {
                Stack({ alignContent: Alignment.Center }) {
                  Circle().width(18).height(18).fill(index === this.mode ? this.accentColor : 'rgba(255,255,255,0.02)')
                  if (index === this.mode) {
                    Text('✓').fontSize(12).fontColor('#FFFFFFFF').fontWeight(FontWeight.Bold)
                  }
                }.width(20).height(20)
                Text(option).fontSize(12).fontColor(this.textColor).layoutWeight(1)
                  .maxLines(2).lineHeight(17).textOverflow({ overflow: TextOverflow.Ellipsis })
              }.height(44).width('100%').padding({ left: 12, right: 12 })
                .backgroundColor(index === this.mode ? this.pickerSelected : this.pickerOption)
                .border({ width: 0.5, color: index === this.mode ? this.accentColor : this.cardBorder })
                .borderRadius(UI_RADIUS_CONTROL)
                .animation({ duration: 180, curve: Curve.EaseInOut })
                .clickEffect({ level: ClickEffectLevel.LIGHT })
                .hitTestBehavior(HitTestMode.Block)
                .onClick(() => {
                  this.onSelectMode(this.target, index)
                })
            }, (option: string) => this.target + '-' + option)
          }.width('100%').padding({ left: 7, right: 7, top: 6, bottom: 8 })
            .transition(TransitionEffect.asymmetric(
              TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.EaseOut })
                .combine(TransitionEffect.translate({ x: 0, y: -7 }).animation({ duration: 180, curve: Curve.EaseOut })),
              TransitionEffect.OPACITY.animation({ duration: 120, curve: Curve.EaseIn })
                .combine(TransitionEffect.translate({ x: 0, y: -4 }).animation({ duration: 140, curve: Curve.EaseIn }))
            ))
        }
      }.width('100%').backgroundColor(this.pickerSurface)
        .border({ width: 1, color: this.isOpen ? this.accentColor : this.cardBorder })
        .borderRadius(UI_RADIUS_CONTROL)
        .animation({ duration: 180, curve: Curve.EaseInOut })
    }.width('100%')
      .border({ width: 1, color: this.cardBorder })
      .borderRadius(UI_RADIUS_CONTROL)
      .animation({ duration: 180, curve: Curve.EaseInOut })
  }
}

// 筛选器选项行（原 `skyCultureFilterOption(kind, index, label)`）。
//
// 供 SkyCultureFilterPicker 在展开列表内使用；选中态由 selected 传入（原 helper
// `skyCultureFilterOptionSelected` 已删）。调用方须把 selected 纳入 ForEach 键，否则
// 同键子项不会重建、@Prop 会冻结（§13.5 BottomDock 的教训）。
@Component
export struct SkyCultureFilterOption {
  @Prop label: string
  @Prop selected: boolean
  @Prop textColor: string
  @Prop accentColor: string
  @Prop selectedBg: string
  @Prop optionBg: string
  @Prop cardBorder: string
  onPick: () => void = () => {}

  build() {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Circle().width(18).height(18).fill(this.selected ? this.accentColor : 'rgba(255,255,255,0.02)')
        if (this.selected) {
          Text('✓').fontSize(12).fontColor('#FFFFFFFF').fontWeight(FontWeight.Bold)
        }
      }.width(20).height(20)
      Text(this.label).fontSize(12).fontColor(this.textColor).layoutWeight(1)
        .maxLines(2).lineHeight(17).textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.selected) {
        Text(I18n.t('culture_current')).fontSize(9).fontColor(this.accentColor)
      }
    }.height(44).width('100%').padding({ left: 12, right: 12 })
      .backgroundColor(this.selected ? this.selectedBg : this.optionBg)
      .border({ width: 0.5, color: this.selected ? this.accentColor : this.cardBorder })
      .borderRadius(UI_RADIUS_CONTROL)
      .animation({ duration: 180, curve: curves.springMotion(0.46, 0.88) })
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .onClick(() => { this.onPick() })
  }
}

// 分类 / 地区筛选器（原 `skyCultureFilterPicker(kind)`）。
//
// 选中的下标由宿主演算成 selectedIndex 传入；展开时用选定下标参与 ForEach 键，保证选中高亮实时刷新。
@Component
export struct SkyCultureFilterPicker {
  @Prop kind: string
  @Prop labels: string[]
  @Prop selectedIndex: number
  @Prop isOpen: boolean
  @Prop subColor: string
  @Prop textColor: string
  @Prop accentColor: string
  @Prop cardBorder: string
  @Prop pickerSurface: string
  @Prop pickerHeader: string
  @Prop pickerHeaderActive: string
  @Prop pickerSelected: string
  @Prop pickerOption: string
  @Prop inputColor: string
  onToggle: (kind: string) => void = () => {}
  onPick: (kind: string, index: number) => void = () => {}

  private pickerTitle(): ResourceStr {
    return this.kind === 'classification' ? I18n.t('culture_type') : I18n.t('culture_region')
  }

  build() {
    Column({ space: 2 }) {
      Row() {
        Column({ space: 3 }) {
          Text(this.pickerTitle())
            .fontSize(10).fontColor(this.subColor).width('100%')
          Text(this.labels[this.selectedIndex]).fontSize(12).fontColor(this.textColor).width('100%')
            .maxLines(2).lineHeight(17).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(this.isOpen ? I18n.t('culture_collapse') : I18n.t('culture_choose')).fontSize(10).fontColor(this.accentColor)
          .padding({ left: 5, right: 5, top: 3, bottom: 3 })
          .backgroundColor(this.isOpen ? this.pickerSelected : this.inputColor)
          .border({ width: 1, color: this.isOpen ? this.accentColor : this.cardBorder })
          .borderRadius(UI_RADIUS_CONTROL)
      }.height(54).width('100%').padding({ left: 12, right: 12 })
        .backgroundColor(this.isOpen ? this.pickerHeaderActive : this.pickerHeader)
        .border({ width: 1, color: this.isOpen ? this.accentColor : this.cardBorder })
        .borderRadius(UI_RADIUS_CONTROL)
        .animation({ duration: 180, curve: Curve.EaseInOut })
        .clickEffect({ level: ClickEffectLevel.LIGHT })
        .onClick(() => { this.onToggle(this.kind) })
      if (this.isOpen) {
        Column({ space: 6 }) {
          ForEach(this.labels, (label: string, index: number) => {
            SkyCultureFilterOption({
              label: label,
              selected: index === this.selectedIndex,
              textColor: this.textColor,
              accentColor: this.accentColor,
              selectedBg: this.pickerSelected,
              optionBg: this.pickerOption,
              cardBorder: this.cardBorder,
              onPick: () => { this.onPick(this.kind, index) }
            })
          }, (label: string, index: number) => this.kind + '-' + label + (index === this.selectedIndex ? '-s' : ''))
        }.width('100%').padding({ left: 7, right: 7, top: 6, bottom: 8 })
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.EaseOut })
              .combine(TransitionEffect.translate({ x: 0, y: -8 }).animation({ duration: 220, curve: curves.springMotion(0.46, 0.88) })),
            TransitionEffect.OPACITY.animation({ duration: 120, curve: Curve.EaseIn })
              .combine(TransitionEffect.translate({ x: 0, y: -4 }).animation({ duration: 150, curve: Curve.EaseIn }))
          ))
      }
    }.width('100%')
      .backgroundColor(this.isOpen ? this.pickerSurface : 'rgba(255,255,255,0.045)')
      .border({ width: 1, color: this.isOpen ? this.accentColor : this.cardBorder })
      .borderRadius(UI_RADIUS_CONTROL)
      .animation({ duration: 220, curve: curves.springMotion(0.46, 0.88) })
  }
}
