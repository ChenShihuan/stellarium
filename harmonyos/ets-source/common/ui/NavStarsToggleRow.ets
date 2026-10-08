import { UI_RADIUS_CONTROL } from './UiTokens'

// 导航星插件设置开关行。
//
// 与 `ArchaeoToggleRow` / `MosaicCameraMetric` 一样，原先住在 `panels/settings/SettingsRows.ets`
// 里但并非设置面板专用（唯一消费方是 `panels/panels/NavStarsPanel.ets`），
// 2026-10-08 按 STATE-REVIEW §9 P1 迁到 `common/ui/`（§4.2-4「新通用件统一进 common/ui/」）。
@Component
export struct NavStarsToggleRow {
  @Prop label: ResourceStr
  @Prop isOn: boolean
  @Prop canToggle: boolean
  @Prop textColor: string
  @Prop panelColor: string
  onToggle: (value: boolean) => void = () => {}

  build() {
    Row() {
      Text(this.label).fontSize(12).fontColor(this.textColor).layoutWeight(1).maxLines(2)
      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .enabled(this.canToggle)
        .onChange((value: boolean) => { this.onToggle(value) })
    }.width('100%').padding({ left: 10, right: 10 }).backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL)
  }
}
