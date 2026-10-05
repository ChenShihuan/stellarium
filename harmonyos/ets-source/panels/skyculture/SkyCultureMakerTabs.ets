import { curves } from '@kit.ArkUI'
import { UI_RADIUS_CONTROL } from '../../common/ui/UiTokens'
import { I18n } from '../../pages/I18n'
import { SkyCultureMakerStore } from '../../state/SkyCultureMakerStore'

// 星文化制作器的三个标签页（原宿主无参 `@Builder skyCultureMakerTabs`）。
//
// 改成组件只为与同域其余子块一致（这里的 tab 本来就是宿主 @State，无参 builder 不会冻结）；
// 选中态直接改写 store（@ObjectLink 允许）—— 宿主读 store，因此标签切换会实时刷新。
// 视觉逐字保留：Row space 6 / 文本 11 号 / 高 34 / 下边距 10 / 选中白字 + 强调底色 / 180ms springMotion。
@Component
export struct SkyCultureMakerTabs {
  @ObjectLink store: SkyCultureMakerStore
  @Prop subColor: string
  @Prop accentColor: string
  @Prop bgColor: string

  build() {
    Row({ space: 6 }) {
      ForEach([I18n.t('sky_culture_maker_overview'), I18n.t('sky_culture_maker_constellations'), I18n.t('sky_culture_maker_validate_export')], (label: ResourceStr, index: number) => {
        Text(label).fontSize(11).fontColor(this.store.tab === index ? '#FFFFFFFF' : this.subColor)
          .fontWeight(this.store.tab === index ? FontWeight.Medium : FontWeight.Normal)
          .textAlign(TextAlign.Center).layoutWeight(1).height(34).padding({ top: 8 })
          .backgroundColor(this.store.tab === index ? this.accentColor : this.bgColor)
          .borderRadius(UI_RADIUS_CONTROL)
          .animation({ duration: 180, curve: curves.springMotion(0.42, 0.86) })
          .onClick(() => { this.store.tab = index })
      }, (_label: ResourceStr, index: number) => index.toString())
    }.width('100%').margin({ bottom: 10 })
  }
}
