import { I18n } from '../../pages/I18n'
import { UI_RADIUS_CONTROL } from '../../common/ui/UiTokens'

// 音频控制面板（原宿主 panelContent() 的 `audio` 分支，分支体原样下沉）。
//
// 判定条件 `activePanel === 'audio'` 留在宿主。AudioEngine 是原生桥，
// 按 §13.1 规则 6 用回调注入：组件内不 import StellariumAudio，
// 播放/静音/音量与提示都由宿主侧的 onToggleMusic / onVolumeChange 处理。

@Component
export struct AudioPanel {
  @Prop musicEnabled: boolean
  @Prop audioVolume: number
  @Prop textColor: string
  @Prop panelColor: string
  @Prop accentColor: string
  onToggleMusic: (enabled: boolean) => void = () => {}
  onVolumeChange: (value: number) => void = () => {}

  build() {
    Scroll() {
      Column({ space: 10 }) {
        Text(I18n.t('panel_audio_ctrl')).fontSize(15).fontColor(this.textColor).width('100%').margin({ top: 4 })
        Row() {
          Text(I18n.t('audio_toggle')).fontSize(13).fontColor('#E5FFFFFF').layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.musicEnabled })
            .onChange((isOn: boolean) => { this.onToggleMusic(isOn) })
        }.width('100%').padding({ left: 10, right: 10 }).backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL)
        Row() {
          Text(I18n.t('audio_volume')).fontSize(13).fontColor('#E5FFFFFF').width(72)
          Text(Math.round(this.audioVolume * 100) + '%').fontSize(13).fontColor(this.textColor).margin({ right: 8 })
          Slider({ value: this.audioVolume, min: 0, max: 1, step: 0.05, style: SliderStyle.OutSet })
            .sliderInteractionMode(SliderInteraction.SLIDE_ONLY).minResponsiveDistance(8)
            .width('40%')
            .blockColor(this.accentColor)
            .trackColor(this.panelColor)
            .selectedColor(this.accentColor)
            .showSteps(false)
            .onChange((val: number) => { this.onVolumeChange(val) })
        }.height(40).width('100%').padding({ left: 10, right: 10 }).backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL)
      }.width('100%').padding({ left: 8, right: 8, top: 8, bottom: 8 })
    }.width('100%').layoutWeight(1).scrollBar(BarState.Auto).scrollBarWidth(4).scrollBarColor('#33FFFFFF')
  }
}
