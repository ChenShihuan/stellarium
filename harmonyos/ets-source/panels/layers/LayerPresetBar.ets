import { UI_RADIUS_CONTROL } from '../../common/ui/UiTokens'

// 本组件职责：「图层」面板顶部的图层预设条。
//
// 预设的应用逻辑（applyLayerPreset / clearMarkingLayers）走原生桥与 flashHint，
// 由宿主提供，以回调注入。
@Component
export struct LayerPresetBar {
  @Prop subColor: string
  @Prop textColor: string
  @Prop panelColor: string
  onPreset: (preset: string) => void = () => {}
  onClear: () => void = () => {}

  build() {
    Column({ space: 4 }) {
      Text('图层预设').fontSize(10).fontColor(this.subColor).width('100%').padding({ left: 2 })
      Row({ space: 5 }) {
        Button('纯净星空').fontSize(10).fontColor(this.textColor).backgroundColor(this.panelColor)
          .borderRadius(UI_RADIUS_CONTROL).height(28).padding({ left: 9, right: 9 })
          .onClick(() => { this.onPreset('clean') })
        Button('观测辅助').fontSize(10).fontColor(this.textColor).backgroundColor(this.panelColor)
          .borderRadius(UI_RADIUS_CONTROL).height(28).padding({ left: 9, right: 9 })
          .onClick(() => { this.onPreset('observe') })
        Button('摄影构图').fontSize(10).fontColor(this.textColor).backgroundColor(this.panelColor)
          .borderRadius(UI_RADIUS_CONTROL).height(28).padding({ left: 9, right: 9 })
          .onClick(() => { this.onPreset('photo') })
      }.width('100%').padding({ left: 2, right: 2 })
      Button('清除坐标与标记').fontSize(10).fontColor(this.subColor).backgroundColor(this.panelColor)
        .borderRadius(UI_RADIUS_CONTROL).height(27).padding({ left: 9, right: 9 })
        .onClick(() => { this.onClear() })
    }.width('100%').margin({ bottom: 4 })
  }
}
