import { I18n } from '../../pages/I18n'
import { UI_RADIUS_CONTROL } from '../../common/ui/UiTokens'
import { getIcon } from '../../common/ui/ShellIcons'
import { ObjectDetailStore } from '../../state/ObjectDetailStore'
import { ObjectCompactMetric, ObjectDetailTab } from './DetailTiles'
import { SelectedLiveInfoRows } from './DetailLiveRows'

// 详情卡外壳的页头与页签栏（原 ``unifiedObjectDetailCard()`` 的前半部分）。
//
// 页头 = 拖拽柄 + 标题行（图标/名/类型/关闭）+ 紧凑指标 + 实时高度方位行 + 时角行；
// 页签栏 = 四个 ``ObjectDetailTab``。动态查值与名称本地化仍留在宿主，以回调注入。
// 外层 ``Column()`` 与卡片根容器一致（无间距），保持原布局。

@Component
export struct ObjectDetailCardHeader {
  @ObjectLink store: ObjectDetailStore
  @Prop iconName: string
  @Prop liveInfoVisible: boolean
  resolve: (key: string) => string = () => ''
  distanceSummary: () => string = () => ''
  nameOf: (name: string) => string = () => ''
  typeOf: (type: string) => string = () => ''
  onDragTouch: (event: TouchEvent) => void = () => {}
  onDismiss: () => void = () => {}

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(40).height(4).backgroundColor('rgba(225,241,250,0.34)').borderRadius(2)
      }
        .width('100%').height(26)
        .hitTestBehavior(HitTestMode.Block)
        .onTouch((event: TouchEvent) => { this.onDragTouch(event) })
      Row() {
        Image(getIcon(this.iconName, false))
          .width(26).height(26).fillColor('#73C8FF').margin({ right: 7 })
        Text(this.nameOf(this.store.selectedName))
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FFFFFFFF')
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.typeOf(this.store.selectedType))
          .fontSize(11).fontColor('#BDE8FF')
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor('rgba(91,147,191,0.18)').borderRadius(UI_RADIUS_CONTROL)
        Text('✕')
          .fontSize(15).fontColor('#B8CAD7').padding({ left: 12, right: 4, top: 4, bottom: 4 })
          .onClick(() => {
            this.onDismiss()
          })
      }
      .width('100%').padding({ left: 16, right: 14, top: 10, bottom: 6 })

      Row({ space: 4 }) {
        ObjectCompactMetric({ label: I18n.t('i0007'), value: this.resolve('selectedMagnitude') })
        ObjectCompactMetric({ label: I18n.t('i0010'), value: this.resolve('selectedConstellation') })
        ObjectCompactMetric({ label: I18n.t('i0011'), value: this.distanceSummary() })
      }
        .width('100%').padding({ left: 16, right: 16, top: 3, bottom: 7 })

      Row() {
        Text('实时高度 / 方位').fontSize(10).fontColor('#8FBBD6').width(72)
        Text(this.store.selectedCoordAlt.length > 0 ? this.store.selectedCoordAlt : '--')
          .fontSize(11).fontColor('#E2F5FF').layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.store.selectedCoordAlt.length > 0 ? '已定位' : '等待定位')
          .fontSize(10).fontColor('#BDE8FF').margin({ left: 8 })
      }
        .height(24).width('100%').padding({ left: 16, right: 16, bottom: 4 })

      SelectedLiveInfoRows({ store: this.store, compact: true, visible: this.liveInfoVisible })
    }
  }
}

@Component
export struct ObjectDetailCardTabs {
  @Prop activeIndex: number
  onSelect: (index: number) => void = () => {}

  build() {
      Row({ space: 4 }) {
        ObjectDetailTab({ label: '观测', active: this.activeIndex === 0, onSelect: () => { this.onSelect(0) } })
        ObjectDetailTab({ label: '坐标', active: this.activeIndex === 1, onSelect: () => { this.onSelect(1) } })
        ObjectDetailTab({ label: '资料', active: this.activeIndex === 2, onSelect: () => { this.onSelect(2) } })
        ObjectDetailTab({ label: '操作', active: this.activeIndex === 3, onSelect: () => { this.onSelect(3) } })
      }
        .width('100%').padding({ left: 16, right: 16, bottom: 8 })
  }
}
