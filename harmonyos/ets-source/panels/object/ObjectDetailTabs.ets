import { I18n } from '../../pages/I18n'
import { ObjectDetailStore } from '../../state/ObjectDetailStore'
import { ObjectMetric, ObjectScheduleTile } from './DetailTiles'
import { ObjectDataRow } from './DetailRows'
import { ObjectDistanceNotice, SelectedCoordinateRows } from './DetailLiveRows'

// 详情主卡片的"观测"与"坐标"两页（原 ``unifiedObjectDetailCard()`` 里 ``bottomCardIndex`` 0/1 的分支）。
//
// 贴片与坐标行由子组件自行观察 store；动态查值 ``selectedDisplayValue(key)`` 仍留在宿主（多处共用），
// 以 ``resolve`` 回调注入。「资料」页暂仍留在宿主：它需要把宿主的**无参** ``@Builder tabletInspectorMedia()``
// 插到页面中部，``@BuilderParam`` 传递在真机上会让应用在渲染该页时退出（2026-10-01 实测，已回退），
// 待把媒体区改成 ``TabletInspectorMediaGroup`` 组件后再搬。「操作」页在同目录 ``ObjectDetailActionsTab``。

@Component
export struct ObjectDetailObserveTab {
  @ObjectLink store: ObjectDetailStore
  @Prop distanceText: string
  resolve: (key: string) => string = () => ''

  build() {
    Column({ space: 8 }) {
      Text('今晚观测窗口').fontSize(12).fontWeight(FontWeight.Medium).fontColor('#D9F2FF').width('100%')
      Row({ space: 6 }) {
        ObjectScheduleTile({ label: I18n.t('s0700'), value: this.resolve('selectedRise') })
        ObjectScheduleTile({ label: I18n.t('s0701'), value: this.resolve('selectedTransit') })
        ObjectScheduleTile({ label: I18n.t('s0702'), value: this.resolve('selectedSet') })
      }.width('100%')
      if (this.store.selectedApparentMagnitude.length > 0 || this.store.selectedAirmass.length > 0 || this.store.selectedExtinction.length > 0) {
        Text('大气影响').fontSize(12).fontWeight(FontWeight.Medium).fontColor('#D9F2FF').width('100%').margin({ top: 3 })
        Row({ space: 8 }) {
          if (this.store.selectedApparentMagnitude.length > 0) { ObjectMetric({ label: '大气后星等', value: this.resolve('selectedApparentMagnitude') }) }
          if (this.store.selectedExtinction.length > 0) { ObjectMetric({ label: '大气衰减', value: this.resolve('extinctionUnits') }) }
          if (this.store.selectedAirmass.length > 0) { ObjectMetric({ label: '气团质量', value: this.resolve('selectedAirmass') }) }
        }.width('100%')
      }
      if (this.store.selectedPhase.length > 0 || this.store.selectedElongation.length > 0 || this.store.selectedSize.length > 0) {
        Row({ space: 8 }) {
          if (this.store.selectedPhase.length > 0) { ObjectMetric({ label: I18n.t('i0291'), value: this.resolve('selectedPhase') }) }
          if (this.store.selectedElongation.length > 0) { ObjectMetric({ label: I18n.t('i0255'), value: this.resolve('selectedElongation') }) }
          if (this.store.selectedSize.length > 0) { ObjectMetric({ label: I18n.t('i0290'), value: this.resolve('selectedSize') }) }
        }.width('100%').margin({ top: 2 })
      }
      if (this.store.selectedDistanceStatus === 'invalid_orbit' || this.store.selectedTleOutdated) {
        ObjectDistanceNotice({ text: this.distanceText })
      }
      if (this.store.selectedInfo.length > 0) {
        Text(this.store.selectedInfo).fontSize(12).fontColor('#C3DDEB').lineHeight(18).width('100%')
          .padding({ top: 8, bottom: 2 })
      }
    }
  }
}

@Component
export struct ObjectDetailCoordinateTab {
  @ObjectLink store: ObjectDetailStore
  @Prop distanceText: string
  resolve: (key: string) => string = () => ''

  build() {
    Column({ space: 8 }) {
      Text('当前天球位置').fontSize(12).fontWeight(FontWeight.Medium).fontColor('#D9F2FF').width('100%')
      ObjectDistanceNotice({ text: this.distanceText })
      SelectedCoordinateRows({ store: this.store, tablet: false })
      ObjectDataRow({ label: I18n.t('i0010'), value: this.resolve('selectedConstellation') })
      Text('坐标会跟随时间、位置与视角更新。').fontSize(11).fontColor('#8FBBD6').lineHeight(16).width('100%').margin({ top: 4 })
    }
  }
}
