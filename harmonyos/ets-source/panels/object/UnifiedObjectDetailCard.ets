import { UI_RADIUS_PANEL } from '../../common/ui/UiTokens'
import { ObjectDetailStore } from '../../state/ObjectDetailStore'
import { ObjectMediaStore } from '../../state/ObjectMediaStore'
import { ObjectDetailCardHeader, ObjectDetailCardTabs } from './ObjectDetailCardChrome'
import { ObjectDetailObserveTab, ObjectDetailCoordinateTab, ObjectDetailDataTab } from './ObjectDetailTabs'
import { ObjectDetailActionsTab } from './ObjectDetailActionsTab'

// 天体详情主卡片的整体外壳：页头 + 页签栏 + 分隔线 + `Scroll` 内四个页组件。
//
// 宿主侧派生值（图标 / 距离摘要 / 资料页媒体参数 / 卡片尺寸）以 `@Prop` 传入，动态查值与名称本地化
// 以回调注入，`Scroller` 与宿主共享同一实例。滚动位置上报与媒体视口高度回写留在组件内，
// 因为它们只依赖本组件的 scroller 与 `mediaStore`。
// 不用 `@BuilderParam` 承接宿主 `@Builder`——真机上会让应用在渲染该页时退出。

@Component
export struct UnifiedObjectDetailCard {
  @ObjectLink store: ObjectDetailStore
  @ObjectLink mediaStore: ObjectMediaStore
  @Prop activeIndex: number
  @Prop liveInfoVisible: boolean
  @Prop contentOpacity: number
  @Prop contentTranslateX: number
  @Prop cardWidth: number
  @Prop cardHeight: number
  @Prop viewLock: boolean
  @Prop speechStatus: string
  @Prop inObservingList: boolean
  @Prop iconName: string
  @Prop detailDisplayMode: string
  @Prop observeExpanded: boolean
  @Prop distanceText: string
  @Prop distanceSummaryText: string
  @Prop imageHeight: number
  @Prop inlineModelSize: number
  @Prop modelReady: boolean
  @Prop modelRendering: boolean
  @Prop hasModelTexture: boolean
  @Prop modelNotice: string
  @Prop warmupText: string
  @Prop fallbackKind: string
  @Prop starColor: string
  @Prop satelliteVisible: boolean
  @Prop tleEpoch: string
  @Prop accent: string
  @Prop cultureVisible: boolean
  @Prop textColor: string
  scroller: Scroller = new Scroller()
  resolve: (key: string) => string = () => ''
  nameOf: (name: string) => string = () => ''
  typeOf: (type: string) => string = () => ''
  onDragTouch: (event: TouchEvent) => void = () => {}
  onDismiss: () => void = () => {}
  onCenterObject: () => void = () => {}
  onExpandObserve: () => void = () => {}
  onCollapseObserve: () => void = () => {}
  onSelectTab: (index: number) => void = () => {}
  onLoadPasses: () => void = () => {}
  onMediaOpen: () => void = () => {}
  onMediaRetry: () => void = () => {}
  onModelExpand: () => void = () => {}
  onModelTouch: (event: TouchEvent) => void = () => {}
  onCenter: () => void = () => {}
  onToggleLock: () => void = () => {}
  onToggleObserving: () => void = () => {}
  onRefresh: () => void = () => {}
  onReselect: () => void = () => {}
  onSpeak: () => void = () => {}

  // 观测极简形态：只有页头会渲染（页签栏 + 分隔线 + 滚动区整体不渲染）。
  private observeCompact(): boolean {
    return this.detailDisplayMode === 'observe' && !this.observeExpanded
  }

  build() {
    Column() {
      ObjectDetailCardHeader({
        store: this.store, iconName: this.iconName, liveInfoVisible: this.liveInfoVisible,
        detailDisplayMode: this.detailDisplayMode, observeExpanded: this.observeExpanded,
        // 距离摘要的可见性/回退由宿主决定（`distanceSummaryText`）；两个实参在页头内直接读
        // `@ObjectLink store`，仅用于建立元素级依赖，使切换天体时该摘要会重算。
        distanceSummary: (_distance: string, _compact: string) => this.distanceSummaryText,
        nameOf: this.nameOf, typeOf: this.typeOf,
        onDragTouch: (event: TouchEvent) => { this.onDragTouch(event) }, onDismiss: () => { this.onDismiss() },
        onCenterObject: () => { this.onCenterObject() },
        onExpandObserve: () => { this.onExpandObserve() },
        onCollapseObserve: () => { this.onCollapseObserve() }
      })

      if (!this.observeCompact()) {
        ObjectDetailCardTabs({ activeIndex: this.activeIndex, onSelect: (index: number) => { this.onSelectTab(index) } })

        Divider().color('rgba(91,147,191,0.16)').margin({ left: 16, right: 16 })

        Scroll(this.scroller) {
          Column({ space: 8 }) {
            if (this.activeIndex === 0) {
              ObjectDetailObserveTab({ store: this.store, distanceText: this.distanceText, resolve: this.resolve })
            } else if (this.activeIndex === 1) {
              ObjectDetailCoordinateTab({ store: this.store, distanceText: this.distanceText, resolve: this.resolve })
            } else if (this.activeIndex === 2) {
              ObjectDetailDataTab({
                store: this.store, mediaStore: this.mediaStore, tablet: false, distanceText: this.distanceText,
                iconName: this.iconName, imageHeight: this.imageHeight, inlineModelSize: this.inlineModelSize,
                modelReady: this.modelReady, modelRendering: this.modelRendering, hasModelTexture: this.hasModelTexture,
                modelNotice: this.modelNotice, warmupText: this.warmupText, fallbackKind: this.fallbackKind, starColor: this.starColor,
                satelliteVisible: this.satelliteVisible, tleEpoch: this.tleEpoch, accent: this.accent,
                cultureVisible: this.cultureVisible, textColor: this.textColor,
                resolve: this.resolve,
                onLoadPasses: () => { this.onLoadPasses() }, onMediaOpen: () => { this.onMediaOpen() },
                onMediaRetry: () => { this.onMediaRetry() }, onModelExpand: () => { this.onModelExpand() },
                onModelTouch: (event: TouchEvent) => { this.onModelTouch(event) }
              })
            } else {
              ObjectDetailActionsTab({
                viewLock: this.viewLock,
                speechStatus: this.speechStatus,
                inObservingList: this.inObservingList,
                onCenter: () => { this.onCenter() },
                onToggleLock: () => { this.onToggleLock() },
                onToggleObserving: () => { this.onToggleObserving() },
                onRefresh: () => { this.onRefresh() },
                onReselect: () => { this.onReselect() },
                onSpeak: () => { this.onSpeak() }
              })
            }
          }
            .width('100%').padding({ left: 16, right: 16, top: 10, bottom: 10 })
        }
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.Auto)
          .width('100%')
          .layoutWeight(1)
          .opacity(this.contentOpacity)
          .translate({ x: this.contentTranslateX, y: 0 })
          .id('object-detail-content-scroll')
          .onScroll(() => {
            AppStorage.setOrCreate('stellariumObjectDetailScrollY', this.scroller.currentOffset()?.yOffset ?? 0)
          })
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            const height = Number(newArea.height)
            if (Number.isFinite(height) && height > 0 && Math.abs(height - this.mediaStore.objectInspectorMediaViewportHeight) > 1) {
              this.mediaStore.objectInspectorMediaViewportHeight = height
            }
          })
      }

    }
      .width(this.cardWidth)
      .height(this.cardHeight)
      .backgroundColor('rgba(12, 16, 28, 0.72)')
      .backdropBlur(28)
      .border({ width: 0.5, color: 'rgba(91, 147, 191, 0.18)' })
      .borderRadius(UI_RADIUS_PANEL)
      .shadow({ radius: 20, color: 'rgba(0,0,0,0.30)', offsetX: 0, offsetY: 8 })
  }
}
