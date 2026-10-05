import { I18n } from '../../pages/I18n'
import { OverlayStore } from '../../state/OverlayStore'
import { UI_RADIUS_CONTROL } from '../../common/ui/UiTokens'
import { PointerCoordinateToggle } from './PointerCoordinateToggle'

// 「指针坐标」插件面板主体（原宿主 @Builder `pointerCoordinatesPanel()`，约 54 行）。
//
// 组件只收一个 store、五个夜视色与一个写回回调：
//   - 全部 pointerCoordinates* 展示态走 @ObjectLink store（实时刷新）；
//   - 六个开关行改用 `PointerCoordinateToggle` 组件（替换原参数化 `@Builder pointerCoordinateToggle`，
//     原形参按值捕获导致开关态冻结）；
//   - 两个单选列表（坐标系 / 显示位置）的选中态直接读 store；
//   - native 桥 `setPointerCoordinates(setting|value)` 留在宿主，以 `onSetSetting(setting, value)` 注入。
//
// 视觉逐字保留：外层 Scroll 撑满面板（layoutWeight 1、滚动条 4px #33FFFFFF）、内容列 space 8、
// 内边距 left/right 8 top 8 bottom 12、加载行 42 高居中、状态条字号 11 / #FFD59A、说明字号 10、
// 分节标题字号 11（margin top 3）、单选项行内边距 left 10 right 8 top 7 bottom 7、勾选字 '✓' 15 号宽 24。
@Component
export struct PointerCoordinatesPanel {
  @ObjectLink store: OverlayStore
  @Prop textColor: string
  @Prop subColor: string
  @Prop accentColor: string
  @Prop panelColor: string
  @Prop lineColor: string
  onSetSetting: (setting: string, value: string) => void = () => {}

  build() {
    Scroll() {
      Column({ space: 8 }) {
        if (this.store.pointerCoordinatesLoading) {
          Row({ space: 8 }) {
            LoadingProgress().width(18).height(18).color(this.accentColor)
            Text(I18n.t('pointer_coord_loading')).fontSize(11).fontColor(this.subColor)
          }.width('100%').height(42).justifyContent(FlexAlign.Center)
        }
        if (this.store.pointerCoordinatesStatus.length > 0) {
          Text(this.store.pointerCoordinatesStatus).fontSize(11).fontColor('#FFD59A').width('100%')
            .padding({ left: 10, right: 10, top: 8, bottom: 8 })
            .backgroundColor('rgba(194,128,36,0.14)').borderRadius(UI_RADIUS_CONTROL)
        }
        Text(I18n.t('pointer_coord_description')).fontSize(10).fontColor(this.subColor).width('100%').maxLines(3)
        PointerCoordinateToggle({
          label: I18n.t('pointer_coord_enabled'), isOn: this.store.pointerCoordinatesEnabled,
          textColor: this.textColor, accentColor: this.accentColor, panelColor: this.panelColor, lineColor: this.lineColor,
          onToggle: (value: boolean) => { this.onSetSetting('enabled', value ? '1' : '0') }
        })
        PointerCoordinateToggle({
          label: I18n.t('pointer_coord_startup'), isOn: this.store.pointerCoordinatesStartup,
          textColor: this.textColor, accentColor: this.accentColor, panelColor: this.panelColor, lineColor: this.lineColor,
          onToggle: (value: boolean) => { this.onSetSetting('enableAtStartup', value ? '1' : '0') }
        })
        PointerCoordinateToggle({
          label: I18n.t('pointer_coord_toolbar'), isOn: this.store.pointerCoordinatesButton,
          textColor: this.textColor, accentColor: this.accentColor, panelColor: this.panelColor, lineColor: this.lineColor,
          onToggle: (value: boolean) => { this.onSetSetting('showCoordinatesButton', value ? '1' : '0') }
        })
        Text(I18n.t('pointer_coord_system')).fontSize(11).fontColor(this.subColor).width('100%').padding({ left: 2 }).margin({ top: 3 })
        ForEach(['RaDecJ2000', 'RaDec', 'HourAngle', 'Ecliptic', 'EclipticJ2000', 'AltAzi', 'Galactic', 'Supergalactic'], (key: string) => {
          Row() {
            Text(this.store.pointerCoordinateSystemLabel(key)).fontSize(12).fontColor(this.textColor).layoutWeight(1).maxLines(2)
            if (this.store.pointerCoordinatesSystem === key) {
              Text('✓').fontSize(15).fontColor(this.accentColor).width(24).textAlign(TextAlign.Center)
            }
          }
            .width('100%').padding({ left: 10, right: 8, top: 7, bottom: 7 })
            .backgroundColor(this.store.pointerCoordinatesSystem === key ? 'rgba(107,163,214,0.16)' : this.panelColor)
            .border({ width: 1, color: this.store.pointerCoordinatesSystem === key ? 'rgba(107,163,214,0.28)' : this.lineColor })
            .borderRadius(UI_RADIUS_CONTROL)
            .onClick(() => { this.onSetSetting('coordinateSystem', key) })
        }, (key: string) => key)
        Text(I18n.t('pointer_coord_display_place')).fontSize(11).fontColor(this.subColor).width('100%').padding({ left: 2 }).margin({ top: 3 })
        ForEach(['TopCenter', 'TopRight', 'RightBottomCorner', 'NearMouseCursor', 'Custom'], (key: string) => {
          Row() {
            Text(this.store.pointerCoordinatesPlaceLabel(key)).fontSize(12).fontColor(this.textColor).layoutWeight(1)
            if (this.store.pointerCoordinatesPlace === key) {
              Text('✓').fontSize(15).fontColor(this.accentColor).width(24).textAlign(TextAlign.Center)
            }
          }
            .width('100%').padding({ left: 10, right: 8, top: 7, bottom: 7 })
            .backgroundColor(this.store.pointerCoordinatesPlace === key ? 'rgba(107,163,214,0.16)' : this.panelColor)
            .border({ width: 1, color: this.store.pointerCoordinatesPlace === key ? 'rgba(107,163,214,0.28)' : this.lineColor })
            .borderRadius(UI_RADIUS_CONTROL)
            .onClick(() => { this.onSetSetting('coordinatesPlace', key) })
        }, (key: string) => key)
        Text(I18n.t('pointer_coord_details')).fontSize(11).fontColor(this.subColor).width('100%').padding({ left: 2 }).margin({ top: 3 })
        PointerCoordinateToggle({
          label: I18n.t('pointer_coord_constellation'), isOn: this.store.pointerCoordinatesConstellation,
          textColor: this.textColor, accentColor: this.accentColor, panelColor: this.panelColor, lineColor: this.lineColor,
          onToggle: (value: boolean) => { this.onSetSetting('showConstellation', value ? '1' : '0') }
        })
        PointerCoordinateToggle({
          label: I18n.t('pointer_coord_crossed_lines'), isOn: this.store.pointerCoordinatesCrossedLines,
          textColor: this.textColor, accentColor: this.accentColor, panelColor: this.panelColor, lineColor: this.lineColor,
          onToggle: (value: boolean) => { this.onSetSetting('showCrossedLines', value ? '1' : '0') }
        })
        PointerCoordinateToggle({
          label: I18n.t('pointer_coord_elongation'), isOn: this.store.pointerCoordinatesElongation,
          textColor: this.textColor, accentColor: this.accentColor, panelColor: this.panelColor, lineColor: this.lineColor,
          onToggle: (value: boolean) => { this.onSetSetting('showElongation', value ? '1' : '0') }
        })
      }.width('100%').padding({ left: 8, right: 8, top: 8, bottom: 12 })
    }
      .width('100%').layoutWeight(1).scrollBar(BarState.Auto).scrollBarWidth(4).scrollBarColor('#33FFFFFF')
  }
}
