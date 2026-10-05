import { I18n } from '../../pages/I18n'
import { OcularInstrumentItem } from '../../pages/MainWindowModels'
import { TelescopeStore } from '../../state/TelescopeStore'
import { UI_RADIUS_CONTROL } from '../../common/ui/UiTokens'

// 「目镜（Oculars）」面板的设备选择行（原宿主参数化 `@Builder ocularSelector(kind, label)`，约 45 行）。
//
// 为什么必须改成组件（§13.1 规则 3）：原 @Builder 用简单类型形参 kind/label，参数按值捕获，
// 子树首帧后冻结 —— 换目镜/望远镜/镜头/CCD 后选中态与摘要不再刷新。
//
// 迁移时把原生桥分派移出组件：`selectOcularInstrument(kind, index)` 经 onSelect 回调由宿主执行；
// 列表查表与选中判断（ocularInstrumentItems / ocularInstrumentIndex / ocularInstrumentSummary /
// ocularSelInfo）是纯计算，随状态一起下沉到 TelescopeStore，组件经 @ObjectLink 实时读取。
//
// 视觉逐字保留：标题 12 号 subColor + 计数 10 号 subColor / 空态 11 号高 42 / 横向 Scroll 高 52 /
// 按钮高 48（minWidth 116、maxWidth 180）/ 选中 #FFFFFF 与 #D8EEFF。
@Component
export struct OcularSelector {
  @ObjectLink store: TelescopeStore
  @Prop kind: string
  @Prop label: string
  @Prop subColor: string
  @Prop textColor: string
  @Prop panelColor: string
  @Prop accentColor: string
  @Prop lineColor: string
  onSelect: (kind: string, index: number) => void = () => {}

  build() {
    Column({ space: 6 }) {
      Row() {
        Text(this.label).fontSize(12).fontColor(this.subColor).layoutWeight(1)
        Text(this.store.ocularSelInfo(this.kind).countText).fontSize(10).fontColor(this.subColor)
      }.width('100%').padding({ left: 2, right: 2 })
      if (this.store.ocularInstrumentItems(this.kind).length === 0 && this.kind !== 'Lens') {
        Text(I18n.t('ocular_no_devices')).fontSize(11).fontColor(this.subColor)
          .width('100%').height(42).textAlign(TextAlign.Center)
          .backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL)
      } else {
        Scroll() {
          Row({ space: 7 }) {
            if (this.kind === 'Lens') {
              Button(I18n.t('ocular_no_lens'))
                .fontSize(11).fontColor(this.store.lensIndex < 0 ? '#FFFFFF' : this.subColor)
                .height(48).padding({ left: 14, right: 14 })
                .backgroundColor(this.store.lensIndex < 0 ? this.accentColor : this.panelColor)
                .border({ width: 1, color: this.store.lensIndex < 0 ? this.accentColor : this.lineColor })
                .borderRadius(UI_RADIUS_CONTROL)
                .onClick(() => { this.onSelect(this.kind, -1) })
            }
            ForEach(this.store.ocularInstrumentItems(this.kind), (item: OcularInstrumentItem) => {
              Button() {
                Column({ space: 2 }) {
                  Text(item.name.length > 0 ? item.name : this.label)
                    .fontSize(11).fontColor(this.store.ocularInstrumentIndex(this.kind) === item.index ? '#FFFFFF' : this.textColor)
                    .fontWeight(FontWeight.Medium).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.store.ocularInstrumentSummary(this.kind, item))
                    .fontSize(9).fontColor(this.store.ocularInstrumentIndex(this.kind) === item.index ? '#D8EEFF' : this.subColor)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }.alignItems(HorizontalAlign.Start)
              }
              .height(48).constraintSize({ minWidth: 116, maxWidth: 180 }).padding({ left: 12, right: 12 })
              .backgroundColor(this.store.ocularInstrumentIndex(this.kind) === item.index ? this.accentColor : this.panelColor)
              .border({ width: 1, color: this.store.ocularInstrumentIndex(this.kind) === item.index ? this.accentColor : this.lineColor })
              .borderRadius(UI_RADIUS_CONTROL)
              .onClick(() => { this.onSelect(this.kind, item.index) })
            }, (item: OcularInstrumentItem) => this.kind + '-' + item.index.toString())
          }.height(50)
        }.width('100%').height(52).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      }
    }.width('100%')
  }
}
