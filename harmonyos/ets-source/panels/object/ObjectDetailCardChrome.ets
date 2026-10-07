import { I18n } from '../../pages/I18n'
import { UI_RADIUS_CONTROL } from '../../common/ui/UiTokens'
import { getIcon } from '../../common/ui/ShellIcons'
import { ObjectDetailStore } from '../../state/ObjectDetailStore'
import { ObjectCompactMetric, ObjectDetailTab } from './DetailTiles'
import { SelectedLiveInfoRows } from './DetailLiveRows'

// 详情卡外壳的页头与页签栏。
//
// 页头 = 拖拽柄 + 标题行 + 紧凑指标 + 实时高度方位行 + 时角行；页签栏 = 四个 `ObjectDetailTab`。
// 动态查值与名称本地化由宿主以回调注入。
//
// 页头三枚摘要（星等 / 星座 / 距离）必须**直接读 `@ObjectLink store`**：ArkUI 的局部刷新按元素
// 记录依赖，若取值只经普通成员回调（`resolve` / `distanceSummary`）而不触碰被观察对象，
// 切换天体时该元素不会被标脏，会一直显示上一颗天体的旧值。

@Component
export struct ObjectDetailCardHeader {
  @ObjectLink store: ObjectDetailStore
  @Prop iconName: string
  @Prop liveInfoVisible: boolean
  // 呈现轴（信息窗 store 读后下发）：'planetarium' | 'observe'，以及观测模式的临时展开态。
  @Prop detailDisplayMode: string
  @Prop observeExpanded: boolean
  distanceSummary: (distance: string, compact: string) => string = () => ''
  nameOf: (name: string) => string = () => ''
  typeOf: (type: string) => string = () => ''
  onDragTouch: (event: TouchEvent) => void = () => {}
  onDismiss: () => void = () => {}
  onCenterObject: () => void = () => {}
  onExpandObserve: () => void = () => {}
  onCollapseObserve: () => void = () => {}

  // 观测极简形态：页签 / 实时行 / 滚动区全隐藏，只留页头 + 三 tag + 按钮行。
  private observeCompact(): boolean {
    return this.detailDisplayMode === 'observe' && !this.observeExpanded
  }

  // 观测展开形态：内容与天文馆模式一致，但页头多一个「收起」。
  private observeCollapsible(): boolean {
    return this.detailDisplayMode === 'observe' && this.observeExpanded
  }

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
        if (this.observeCollapsible()) {
          Text(I18n.t('detail_observe_collapse'))
            .fontSize(11).fontColor('#8FBBD6')
            .padding({ left: 10, right: 2, top: 5, bottom: 5 })
            .id('object-detail-observe-collapse')
            .onClick(() => {
              this.onCollapseObserve()
            })
        }
        Text('✕')
          .fontSize(15).fontColor('#B8CAD7').padding({ left: 12, right: 4, top: 4, bottom: 4 })
          .onClick(() => {
            this.onDismiss()
          })
      }
      .width('100%').padding({ left: 16, right: 14, top: 10, bottom: 6 })

      Row({ space: 4 }) {
        if (this.observeCompact()) {
          ObjectCompactMetric({ label: this.store.observeMagnitudeLabel(), value: this.store.observeMagnitudeValue() })
        } else {
          ObjectCompactMetric({ label: I18n.t('i0007'), value: this.store.selectedMagnitude })
        }
        ObjectCompactMetric({ label: I18n.t('i0010'), value: this.nameOf(this.store.selectedConstellation) })
        ObjectCompactMetric({ label: I18n.t('i0011'), value: this.distanceSummary(this.store.selectedDistance, this.store.selectedDistanceCompact) })
      }
        .width('100%').padding({ left: 16, right: 16, top: 3, bottom: 7 })

      if (this.observeCompact()) {
        // 紧凑按钮行（不做全高按钮）：左「居中」、右「展开」，中间 Blank 撑开。
        Row() {
          Row() {
            Text('◎').fontSize(13).fontColor('#8FBBD6')
            Text(I18n.t('detail_observe_center')).fontSize(11).fontColor('#8FBBD6').margin({ left: 5 })
          }
            .padding({ left: 2, right: 8, top: 2, bottom: 2 })
            .id('object-detail-observe-center')
            .onClick(() => {
              this.onCenterObject()
            })
          Blank()
          Row() {
            Text(I18n.t('detail_observe_expand')).fontSize(11).fontColor('#8FBBD6')
            Text('⤢').fontSize(13).fontColor('#8FBBD6').margin({ left: 5 })
          }
            .padding({ left: 8, right: 2, top: 2, bottom: 2 })
            .id('object-detail-observe-expand')
            .onClick(() => {
              this.onExpandObserve()
            })
        }
          .width('100%').height(28).padding({ left: 16, right: 16, top: 2, bottom: 6 })
      } else {
        Row() {
          // 标签不固定宽度（固定 72 会让 9 字标签自身被截断）；数值已含方位/高度，
          // 无需额外的"已定位/等待定位"标签——它只挤占宽度导致数值被省略号截断。
          Text('实时高度 / 方位').fontSize(10).fontColor('#8FBBD6')
          Text(this.store.selectedCoordAlt.length > 0 ? this.store.selectedCoordAlt : '--')
            .fontSize(11).fontColor('#E2F5FF').layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ left: 6 })
        }
          .height(24).width('100%').padding({ left: 16, right: 16, bottom: 4 })

        SelectedLiveInfoRows({ store: this.store, compact: true, visible: this.liveInfoVisible })
      }
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
