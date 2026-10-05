import { I18n } from '../../pages/I18n'
import { UI_RADIUS_CONTROL } from '../../common/ui/UiTokens'
import { ObjectDetailStore } from '../../state/ObjectDetailStore'
import { SatellitePass } from '../../pages/StellariumTypes'

// 卫星过境段（原宿主 `satellitePassesDetails(tablet)` / `satellitePassCard(pass, tablet)` /
// `satellitePassTimelineRow(label, time, tablet)` 三个参数化 UI 函数，以及只服务于它们的四个纯文本助手）。
//
// 助手（`satellitePassTime` / `satellitePassVisibility` / `satellitePassAltitude` / `satellitePassAngle`）
// 在宿主里只被这一处引用，因此随界面一起搬出，作为**文件作用域函数**保留；过境的 ForEach 与 key 也一并内收，
// 宿主不再需要接触单条过境的格式化细节。夜视强调色 `nmAccent()` 由宿主以 `@Prop accent` 注入
// （宿主观测得到夜视状态变化，会重新传入新值）。

function satellitePassTime(value: string | undefined): string {
  if (value === undefined || value.length === 0) return '--'
  return value.replace('T', ' ').replace(/\.000Z$/, ' UTC').replace(/Z$/, ' UTC')
}

function satellitePassVisibility(pass: SatellitePass): string {
  if (pass.visible === true || pass.peakVisible === true) return I18n.t('satellite_pass_visible')
  switch (pass.visibilityReason) {
    case 'observer_in_daylight': return I18n.t('satellite_pass_daylight')
    case 'satellite_in_earth_shadow': return I18n.t('satellite_pass_shadow')
    case 'below_horizon': return I18n.t('satellite_pass_below_horizon')
    case 'satellite_eclipsed': return I18n.t('satellite_pass_eclipsed')
    default: return I18n.t('satellite_pass_not_visible')
  }
}

function satellitePassAltitude(value: number | undefined): string {
  return typeof value === 'number' && Number.isFinite(value) ? value.toFixed(1) + '°' : '--'
}

function satellitePassAngle(value: number | undefined): string {
  return typeof value === 'number' && Number.isFinite(value) ? value.toFixed(1) + '°' : '--'
}

@Component
export struct SatellitePassTimelineRow {
  @Prop label: string
  @Prop time: string
  @Prop tablet: boolean
  @Prop accent: string

  build() {
    Row({ space: 7 }) {
      Column() {
        Circle({ width: this.tablet ? 8 : 7, height: this.tablet ? 8 : 7 })
          .fill(this.accent)
        Divider().vertical(true).height(18).color('rgba(143,211,255,0.28)')
      }.width(10).height(30).justifyContent(FlexAlign.Center)
      Column({ space: 1 }) {
        Text(this.label).fontSize(this.tablet ? 10 : 9).fontColor('#8FBBD6')
        Text(satellitePassTime(this.time)).fontSize(this.tablet ? 12 : 11).fontColor('#E1F2FA')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.layoutWeight(1)
    }.width('100%').height(36)
  }
}

@Component
export struct SatellitePassCard {
  @Prop pass: SatellitePass
  @Prop tablet: boolean
  @Prop accent: string

  build() {
    Column({ space: 5 }) {
      Row() {
        Text(satellitePassVisibility(this.pass)).fontSize(this.tablet ? 11 : 10).fontWeight(FontWeight.Medium)
          .fontColor(this.pass.visible === true || this.pass.peakVisible === true ? '#A8F0C2' : '#D9C28F')
        Text(this.pass.ongoing === true ? ' · ' + I18n.t('satellite_pass_peak') : '')
          .fontSize(10).fontColor('#8FBBD6').layoutWeight(1)
        Text(typeof this.pass.maxMagnitude === 'number' && Number.isFinite(this.pass.maxMagnitude) ? 'm ' + this.pass.maxMagnitude.toFixed(1) : '')
          .fontSize(10).fontColor('#B9D9E9')
      }.width('100%')
      Column({ space: 1 }) {
        SatellitePassTimelineRow({ label: I18n.t('satellite_pass_appearance'), time: this.pass.start ?? this.pass.appearance ?? '', tablet: this.tablet, accent: this.accent })
        SatellitePassTimelineRow({ label: I18n.t('satellite_pass_peak'), time: this.pass.peak ?? '', tablet: this.tablet, accent: this.accent })
        SatellitePassTimelineRow({ label: I18n.t('satellite_pass_disappearance'), time: this.pass.end ?? this.pass.disappearance ?? '', tablet: this.tablet, accent: this.accent })
      }.width('100%')
      Row({ space: 10 }) {
        Column({ space: 1 }) {
          Text(I18n.t('satellite_pass_max_altitude')).fontSize(9).fontColor('#8FBBD6')
          Text(satellitePassAltitude(this.pass.maxAltitude)).fontSize(this.tablet ? 12 : 11).fontColor('#E1F2FA')
        }.layoutWeight(1)
        Column({ space: 1 }) {
          Text(I18n.t('satellite_pass_peak')).fontSize(9).fontColor('#8FBBD6')
          Text(satellitePassAngle(this.pass.peakAzimuth)).fontSize(this.tablet ? 12 : 11).fontColor('#E1F2FA')
        }.layoutWeight(1)
        Column({ space: 1 }) {
          Text(I18n.t('satellite_pass_visibility')).fontSize(9).fontColor('#8FBBD6')
          Text(satellitePassVisibility(this.pass)).fontSize(this.tablet ? 11 : 10).fontColor('#E1F2FA')
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }.layoutWeight(1)
      }.width('100%')
    }
      .width('100%').padding({ left: 10, right: 10, top: 9, bottom: 9 })
      .backgroundColor('rgba(91,147,191,0.09)')
      .border({ width: 0.5, color: 'rgba(143,211,255,0.18)' })
      .borderRadius(UI_RADIUS_CONTROL)
  }
}

@Component
export struct SatellitePassDetails {
  @ObjectLink store: ObjectDetailStore
  @Prop tablet: boolean
  @Prop visible: boolean
  @Prop tleEpoch: string
  @Prop accent: string
  onLoad: () => void = () => {}

  build() {
    if (this.visible) {
      Column({ space: 7 }) {
        Row() {
          Text(I18n.t('satellite_passes_title')).fontSize(this.tablet ? 13 : 12).fontWeight(FontWeight.Medium)
            .fontColor('#D9F2FF').layoutWeight(1)
          Text(this.store.selectedSatellitePassesLoaded ? this.store.selectedSatellitePasses.length.toString() : '')
            .fontSize(10).fontColor('#8FBBD6')
        }.width('100%')
        if (!this.store.selectedSatellitePassesRequested) {
          Row({ space: 8 }) {
            Text(I18n.t('satellite_passes_lazy_hint')).fontSize(11).fontColor('#8FBBD6')
              .layoutWeight(1).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
            Button(I18n.t('satellite_passes_load'))
              .fontSize(11).fontColor('#E1F2FA')
              .backgroundColor('rgba(91,147,191,0.28)')
              .borderRadius(UI_RADIUS_CONTROL)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .onClick(() => { this.onLoad() })
          }.width('100%').alignItems(VerticalAlign.Center).padding({ top: 6, bottom: 6 })
        } else if (!this.store.selectedSatellitePassesLoaded) {
          Row({ space: 7 }) {
            LoadingProgress().width(16).height(16).color('#8FD3FF')
            Text(I18n.t('satellite_pass_preparing')).fontSize(11).fontColor('#8FBBD6')
          }.width('100%').justifyContent(FlexAlign.Center).padding({ top: 8, bottom: 8 })
        } else if (this.store.selectedSatellitePasses.length === 0) {
          Text(I18n.t('satellite_pass_no_data')).fontSize(11).fontColor('#8FBBD6')
            .lineHeight(17).width('100%').padding({ top: 6, bottom: 6 })
        } else {
          Text(I18n.t('satellite_next_pass')).fontSize(10).fontColor('#8FBBD6').width('100%')
          ForEach(this.store.selectedSatellitePasses.slice(0, 3), (pass: SatellitePass) => {
            SatellitePassCard({ pass: pass, tablet: this.tablet, accent: this.accent })
          }, (pass: SatellitePass, index: number) => 'satellite-pass-' + index.toString() + '-' + satellitePassTime(pass.start))
        }
        if (this.store.selectedSatellitePassesLoaded && this.tleEpoch.length > 0) {
          Text(I18n.format('satellite_pass_offline_source', [this.tleEpoch])).fontSize(9).fontColor('#7599AD')
            .width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
        .width('100%').padding({ left: 10, right: 10, top: 10, bottom: 10 })
        .backgroundColor('rgba(91,147,191,0.08)')
        .border({ width: 0.5, color: 'rgba(143,211,255,0.18)' })
        .borderRadius(UI_RADIUS_CONTROL)
    }
  }
}
