import { I18n } from '../../pages/I18n'
import { NebulaTextureItem } from '../../pages/MainWindowModels'
import { UI_RADIUS_CONTROL, UI_RADIUS_PILL } from '../../common/ui/UiTokens'

// 星云贴图面板（原宿主 panelContent() 的 `nebulaTextures` 分支，分支体原样下沉）。
//
// 判定条件 `activePanel === 'nebulaTextures'` 留在宿主。宿主把 `NebulaTextureStatus`
// 拆成若干 @Prop 标志/计数/条目（避免把可空对象整体作为 @Prop 传递），刷新/导入/
// 可见性/冲突规避/定位/删除等动作回注宿主。随 UI 下沉的纯助手
// nebulaTextureStatusLabel 一并迁入本组件。

@Component
export struct NebulaTexturesPanel {
  @Prop statusPresent: boolean
  @Prop statusEnabled: boolean
  @Prop statusAvoidConflict: boolean
  @Prop statusReadyCount: number
  @Prop statusCount: number
  @Prop statusConfigLoaded: boolean
  @Prop statusItems: NebulaTextureItem[]
  @Prop pending: boolean
  @Prop loading: boolean
  @Prop importing: boolean
  @Prop actionStatus: string
  @Prop textColor: string
  @Prop subColor: string
  @Prop accentColor: string
  @Prop panelColor: string
  onSetVisible: (enabled: boolean) => void = () => {}
  onRefresh: () => void = () => {}
  onImport: () => void = () => {}
  onSetConflictAvoidance: (value: boolean) => void = () => {}
  onGoto: (imageUrl: string) => void = () => {}
  onRemove: (imageUrl: string) => void = () => {}

  private nebulaTextureStatusLabel(status: string | undefined): string {
    if (status === 'ready') return I18n.t('nebula_texture_ready')
    if (status === 'missing_file') return I18n.t('nebula_texture_missing_file')
    if (status === 'decode_failed') return I18n.t('nebula_texture_decode_failed')
    if (status === 'invalid_mapping' || status === 'invalid_world_coords' || status === 'invalid_corner_count' || status === 'corner_out_of_range') return I18n.t('nebula_texture_invalid_mapping')
    if (status === 'remote_blocked') return I18n.t('nebula_texture_remote_blocked')
    if (status === 'config_invalid') return I18n.t('nebula_texture_config_invalid')
    return status ?? I18n.t('nebula_texture_unknown')
  }

  build() {
    Scroll() {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Column({ space: 2 }) {
            Text(I18n.t('nebula_texture_title')).fontSize(14).fontColor(this.textColor).fontWeight(FontWeight.Medium)
            Text(I18n.t('nebula_texture_hint')).fontSize(10).fontColor(this.subColor).width('100%').maxLines(3)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Toggle({ type: ToggleType.Switch, isOn: this.statusEnabled })
            .width(42).height(24).selectedColor(this.accentColor)
            .enabled(this.statusPresent && !this.pending && !this.loading && !this.importing)
            .onChange((enabled: boolean) => { this.onSetVisible(enabled) })
        }.width('100%').padding({ left: 10, right: 10, top: 9, bottom: 9 })
          .backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL)
        Row({ space: 8 }) {
          Button(I18n.t('act_refresh')).fontSize(10).fontColor(this.textColor).backgroundColor(this.panelColor)
            .borderRadius(UI_RADIUS_CONTROL).height(30).layoutWeight(1).enabled(!this.loading)
            .onClick(() => { this.onRefresh() })
          Button(I18n.t('nebula_texture_import')).fontSize(10).fontColor(this.textColor).backgroundColor(this.accentColor)
            .borderRadius(UI_RADIUS_CONTROL).height(30).layoutWeight(1).enabled(!this.importing)
            .onClick(() => { this.onImport() })
          if (this.loading || this.importing) LoadingProgress().width(18).height(18).color(this.accentColor)
        }.width('100%')
        if (this.actionStatus.length > 0) {
          Text(this.actionStatus).fontSize(10).fontColor('#FFD59A').width('100%').maxLines(2)
            .padding({ left: 10, right: 10, top: 7, bottom: 7 }).backgroundColor('rgba(194,128,36,0.14)').borderRadius(UI_RADIUS_CONTROL)
        }
        if (this.statusPresent) {
          Text(I18n.t('nebula_texture_library_hint')).fontSize(12).fontColor(this.subColor).width('100%').padding(8)
          Row() {
            Text(I18n.t('nebula_texture_conflict')).fontSize(12).fontColor(this.textColor).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.statusAvoidConflict })
              .width(42).height(24).selectedColor(this.accentColor)
              .enabled(!this.pending && !this.loading && !this.importing)
              .onChange((value: boolean) => { this.onSetConflictAvoidance(value) })
          }.width('100%').padding(8)
          Column({ space: 3 }) {
            Text(I18n.format('nebula_texture_summary', [String(this.statusReadyCount), String(this.statusCount)]))
              .fontSize(11).fontColor(this.textColor).width('100%')
            Text(this.statusConfigLoaded ? I18n.t('nebula_texture_config_ok') : I18n.t('nebula_texture_config_invalid'))
              .fontSize(9).fontColor(this.subColor).width('100%')
            Text(I18n.t('nebula_texture_offline_solver')).fontSize(9).fontColor('#FFD59A').width('100%').maxLines(2)
          }.width('100%').padding({ left: 10, right: 10, top: 8, bottom: 8 }).backgroundColor('rgba(111,168,207,0.08)').borderRadius(UI_RADIUS_CONTROL)
        }
        if (this.statusItems.length > 0) {
          ForEach(this.statusItems, (item: NebulaTextureItem) => {
            Column({ space: 4 }) {
              Row() {
                Text(item.imageUrl).fontSize(11).fontColor(this.textColor).layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.nebulaTextureStatusLabel(item.status)).fontSize(9).fontColor(item.ready === true ? '#B9E6C4' : '#FFD59A')
                  .padding({ left: 6, right: 6, top: 3, bottom: 3 }).backgroundColor('rgba(255,255,255,0.06)').borderRadius(UI_RADIUS_PILL)
              }.width('100%')
              if (item.width !== undefined && item.height !== undefined) {
                Text(item.width.toString() + ' × ' + item.height.toString() + ' · RA ' + (item.centerRaDeg ?? 0).toFixed(2) + '° · Dec ' + (item.centerDecDeg ?? 0).toFixed(2) + '°')
                  .fontSize(9).fontColor(this.subColor).width('100%').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              if (item.decodeError !== undefined) Text(item.decodeError).fontSize(9).fontColor('#FFD59A').width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              Row({ space: 6 }) {
                Button(I18n.t('btn_center')).fontSize(9).fontColor(this.textColor).backgroundColor(this.accentColor).borderRadius(UI_RADIUS_CONTROL).height(26).layoutWeight(1)
                  .enabled(item.ready === true).onClick(() => { this.onGoto(item.imageUrl) })
                Button(I18n.t('nebula_texture_remove')).fontSize(9).fontColor(this.textColor).backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL).height(26).layoutWeight(1)
                  .onClick(() => { this.onRemove(item.imageUrl) })
              }.width('100%')
            }.width('100%').padding({ left: 10, right: 10, top: 8, bottom: 8 }).backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL)
          }, (item: NebulaTextureItem) => item.imageUrl)
        } else if (!this.loading) {
          Text(I18n.t('nebula_texture_empty')).fontSize(11).fontColor(this.subColor).width('100%').textAlign(TextAlign.Center).padding(18)
        }
      }.width('100%').padding({ left: 8, right: 8, top: 8, bottom: 12 })
    }.width('100%').layoutWeight(1).scrollBar(BarState.Auto).scrollBarWidth(4).scrollBarColor('#33FFFFFF')
  }
}
