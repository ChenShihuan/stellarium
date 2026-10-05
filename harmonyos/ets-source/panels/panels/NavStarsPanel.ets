import { I18n } from '../../pages/I18n'
import { NavStarsToggleRow } from '../settings/SettingsRows'
import { UI_RADIUS_CONTROL } from '../../common/ui/UiTokens'

// 航海星面板（原宿主 panelContent() 的 `navStars` 分支，分支体原样下沉）。
//
// 判定条件 `activePanel === 'navStars'` 留在宿主；加载/开关/星表簇状态全部由宿主
// @State 字段以 @Prop 传入（宿主仍是写方），设置动作回注宿主（setNavStarsSetting）；
// 星表名翻译助手 navStarsSetLabel 随 UI 一并下沉（纯函数，不依赖宿主实例）。

@Component
export struct NavStarsPanel {
  @Prop navStarsLoading: boolean
  @Prop navStarsStatus: string
  @Prop navStarsEnabled: boolean
  @Prop navStarsSetKey: string
  @Prop navStarsSetDescription: string
  @Prop navStarsSetKeys: string[]
  @Prop navStarsCount: number
  @Prop navStarsHighlight: boolean
  @Prop navStarsLimitInfo: boolean
  @Prop navStarsUpperLimb: boolean
  @Prop navStarsTabulated: boolean
  @Prop navStarsExtraDecimals: boolean
  @Prop navStarsUseUtc: boolean
  @Prop navStarsStartup: boolean
  @Prop textColor: string
  @Prop subColor: string
  @Prop panelColor: string
  @Prop accentColor: string
  onSetSetting: (setting: string, value: string) => void = () => {}

  private navStarsSetLabel(key: string): ResourceStr {
    switch (key) {
      case 'AngloAmerican': return '英美航海星'
      case 'French': return '法国航海星'
      case 'British': return '英国航海星'
      case 'Wrinkles': return '19世纪英国航海星'
      case 'Russian': return '俄罗斯航海星'
      case 'USSRAvia': return '苏联航空星'
      case 'USSRSpace': return '苏联航天星'
      case 'German': return '德国航海星'
      case 'GeminiAPS': return 'Gemini 对准星'
      case 'MeadeLX200': return 'Meade LX200 对准星'
      case 'MeadeETX': return 'Meade ETX 对准星'
      case 'MeadeAS494': return 'Meade 494 对准星'
      case 'MeadeAS497': return 'Meade 497 对准星'
      case 'CelestronNS': return 'Celestron 对准星'
      case 'Apollo': return 'Apollo 导航星'
      case 'SkywatcherSS': return 'Sky-Watcher 对准星'
      case 'VixenSB': return 'Vixen 对准星'
      case 'ArgoNavis': return 'Argo Navis 对准星'
      case 'OrionIS': return 'Orion 对准星'
      case 'SkyCommander': return 'Sky Commander 对准星'
      default: return key
    }
  }

  build() {
    Scroll() {
      Column({ space: 10 }) {
        Row() {
          Column({ space: 3 }) {
            Text(I18n.t('panel_nav_stars')).fontSize(15).fontColor(this.textColor).width('100%')
            Text(I18n.t('nav_stars_hint')).fontSize(10).fontColor(this.subColor).width('100%').maxLines(2)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          if (this.navStarsLoading) { LoadingProgress().width(20).height(20).color(this.accentColor) }
          Toggle({ type: ToggleType.Switch, isOn: this.navStarsEnabled })
            .enabled(!this.navStarsLoading)
            .onChange((v: boolean) => { this.onSetSetting('enabled', v ? '1' : '0') })
        }.width('100%').padding({ left: 10, right: 10, top: 9, bottom: 9 }).backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL)
        if (this.navStarsStatus.length > 0) { Text(this.navStarsStatus).fontSize(11).fontColor('#FFD59A').width('100%') }
        Row() {
          Text(I18n.t('nav_stars_set')).fontSize(12).fontColor(this.textColor).layoutWeight(1)
          Text(this.navStarsCount.toString() + ' ' + I18n.t('nav_stars_count')).fontSize(11).fontColor(this.subColor)
        }.width('100%')
        Scroll() {
          Row({ space: 6 }) {
            ForEach(this.navStarsSetKeys, (key: string) => {
              Text(this.navStarsSetLabel(key)).fontSize(10)
                .fontColor(this.navStarsSetKey === key ? '#FFFFFF' : this.subColor)
                .padding({ left: 9, right: 9, top: 7, bottom: 7 })
                .backgroundColor(this.navStarsSetKey === key ? this.accentColor : this.panelColor)
                .borderRadius(UI_RADIUS_CONTROL)
                .onClick(() => { this.onSetSetting('set', key) })
            }, (key: string) => key)
          }.padding({ left: 2, right: 2 })
        }.width('100%').height(42).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
        if (this.navStarsSetDescription.length > 0) {
          Text(this.navStarsSetDescription.replace(/<[^>]+>/g, '')).fontSize(10).fontColor(this.subColor)
            .width('100%').maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        NavStarsToggleRow({ label: I18n.t('nav_stars_highlight'), isOn: this.navStarsHighlight, canToggle: !this.navStarsLoading, textColor: this.textColor, panelColor: this.panelColor, onToggle: (v: boolean) => { this.onSetSetting('highlightWhenVisible', v ? '1' : '0') } })
        NavStarsToggleRow({ label: I18n.t('nav_stars_limit_info'), isOn: this.navStarsLimitInfo, canToggle: !this.navStarsLoading, textColor: this.textColor, panelColor: this.panelColor, onToggle: (v: boolean) => { this.onSetSetting('limitInfo', v ? '1' : '0') } })
        NavStarsToggleRow({ label: I18n.t('nav_stars_upper_limb'), isOn: this.navStarsUpperLimb, canToggle: !this.navStarsLoading, textColor: this.textColor, panelColor: this.panelColor, onToggle: (v: boolean) => { this.onSetSetting('upperLimb', v ? '1' : '0') } })
        NavStarsToggleRow({ label: I18n.t('nav_stars_tabulated'), isOn: this.navStarsTabulated, canToggle: !this.navStarsLoading, textColor: this.textColor, panelColor: this.panelColor, onToggle: (v: boolean) => { this.onSetSetting('tabulatedDisplay', v ? '1' : '0') } })
        NavStarsToggleRow({ label: I18n.t('nav_stars_extra_decimals'), isOn: this.navStarsExtraDecimals, canToggle: !this.navStarsLoading, textColor: this.textColor, panelColor: this.panelColor, onToggle: (v: boolean) => { this.onSetSetting('extraDecimals', v ? '1' : '0') } })
        NavStarsToggleRow({ label: I18n.t('nav_stars_utc'), isOn: this.navStarsUseUtc, canToggle: !this.navStarsLoading, textColor: this.textColor, panelColor: this.panelColor, onToggle: (v: boolean) => { this.onSetSetting('useUtc', v ? '1' : '0') } })
        NavStarsToggleRow({ label: I18n.t('nav_stars_startup'), isOn: this.navStarsStartup, canToggle: !this.navStarsLoading, textColor: this.textColor, panelColor: this.panelColor, onToggle: (v: boolean) => { this.onSetSetting('enableAtStartup', v ? '1' : '0') } })
      }.width('100%').padding({ left: 8, right: 8, top: 8, bottom: 12 })
    }.width('100%').layoutWeight(1).scrollBar(BarState.Auto).scrollBarWidth(4).scrollBarColor('#33FFFFFF')
  }
}
