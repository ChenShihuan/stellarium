import { UI_RADIUS_CONTROL } from '../../common/ui/UiTokens'

// 「图层」面板顶部的图层预设条（原宿主 @Builder `layerPresetBar()`）。
//
// 原 @Builder 无参数，本可保留；但它只服务图层面板，按协议（§13.2 步 3：面板内的 builder
// 一并下沉为组件）随本片收进 panels/layers。预设的应用逻辑（applyLayerPreset / clearMarkingLayers）
// 走原生桥与 flashHint，留在宿主，以回调注入。
//
// 视觉逐字保留：标题 10 号 subColor、三枚预设按钮（高 28、10 号 textColor、panelColor 底、
// UI_RADIUS_CONTROL 圆角）、清除按钮（高 27、subColor）。
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
