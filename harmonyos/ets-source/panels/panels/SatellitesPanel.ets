import { I18n } from '../../pages/I18n'
import { SatelliteListItem, SatelliteSource, SatelliteUpdateSettings, CatalogHealthEntry } from '../../pages/MainWindowModels'
import { SatelliteGroupSelector } from '../satellite/SatelliteGroupSelector'
import { UI_RADIUS_CONTROL } from '../../common/ui/UiTokens'
import { SatelliteStore } from '../../state/SatelliteStore'

// 卫星面板（原宿主 panelContent() 的 `satellites` 分支，分支体原样下沉）。
//
// 判定条件 `activePanel === 'satellites'` 留在宿主。
//
// **接入风格：Store 风格（review §2.7 的第一片从 Prop 风格转过来）**。此前本面板的 28 个
// 域字段以 @Prop 快照传入、状态留在宿主的 @State 上，任一处变化都会让宿主整棵重渲染；
// 现在状态下沉 `state/SatelliteStore.ets`，面板以 `@ObjectLink` 实时订阅，刷新粒度收缩到
// 订阅该 store 的组件。**动作**（文本输入、开关、刷新/导入/删除、分组选择、检索、目录健康
// 文案）仍是宿主注入的回调，组件自身不修改 store —— store 只承载状态，符合 §2.11 的分类。
// 两个 Scroller 以普通成员传入（宿主同一实例仍被 publishSatellitePanelState 读取）。
// 顶层 Scroll + Column({ space: 10 }) 与原分支根一致。

@Component
export struct SatellitesPanel {
  @ObjectLink satelliteStore: SatelliteStore
  @Prop textColor: string
  @Prop subColor: string
  @Prop panelColor: string
  @Prop inputColor: string
  @Prop accentColor: string
  panelScroller: Scroller = new Scroller()
  groupScroller: Scroller = new Scroller()
  onPublishState: () => void = () => {}
  catalogHealthTextOf: (title: string, health: CatalogHealthEntry) => string = (title: string) => title
  catalogHealthColorOf: (health: CatalogHealthEntry) => string = () => '#99FFFFFF'
  onDeleteSource: (index: number) => void = () => {}
  onSourceInput: (value: string) => void = () => {}
  onSourceAddNew: (value: boolean) => void = () => {}
  onAddSource: () => void = () => {}
  onRefreshCatalog: () => void = () => {}
  onTleFileInput: (value: string) => void = () => {}
  onImportTle: () => void = () => {}
  onSetUpdateSetting: (key: string, value: boolean | number) => void = () => {}
  onUpdateFrequencyInput: (value: string) => void = () => {}
  onSubmitUpdateFrequency: () => void = () => {}
  onSetFlag: (flag: string, isOn: boolean) => void = () => {}
  onSelectGroup: (group: string) => void = () => {}
  onQueryChange: (value: string) => void = () => {}
  onSubmitQuery: () => void = () => {}
  onSearchObject: (item: SatelliteListItem) => void = () => {}

  build() {
    Scroll(this.panelScroller) {
      Column({ space: 10 }) {
        Column({ space: 3 }) {
          Text(this.satelliteStore.satOffline ? '离线内置轨道数据' : '在线轨道数据')
            .fontSize(13).fontColor(this.satelliteStore.satOffline ? '#B7D8F0' : '#FFE5A6').fontWeight(FontWeight.Medium)
          if (this.satelliteStore.satNewestUpdate.length > 0) {
            Text('目录更新时间：' + this.satelliteStore.satNewestUpdate.replace('T', ' ').replace('Z', ' UTC'))
              .fontSize(11).fontColor('#99FFFFFF').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          if (this.satelliteStore.satCatalogCreator.length > 0) {
            Text('原版目录：' + this.satelliteStore.satCatalogCreator).fontSize(10).fontColor('#88FFFFFF').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          if (this.satelliteStore.satCatalogSnapshot.length > 0) {
            Text('内置快照：' + this.satelliteStore.satCatalogSnapshot.replace('T', ' ').replace('Z', ' UTC')).fontSize(10).fontColor('#88FFFFFF').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          if (this.satelliteStore.satCatalogSource.length > 0) {
            Text(I18n.t('resource_source') + ': ' + this.satelliteStore.satCatalogSource).fontSize(9).fontColor('#66FFFFFF').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          Text(this.catalogHealthTextOf('卫星目录', this.satelliteStore.satelliteCatalogHealth))
            .fontSize(11).fontColor(this.catalogHealthColorOf(this.satelliteStore.satelliteCatalogHealth)).maxLines(2)
          if (this.satelliteStore.satOutdatedCount > 0 || !this.satelliteStore.satDateInRange || !this.satelliteStore.satObserverIsEarth) {
            Text(!this.satelliteStore.satObserverIsEarth ? '人造卫星仅支持地球观测位置' : (!this.satelliteStore.satDateInRange ? '当前模拟日期超出内置轨道数据范围' : '部分轨道历元可能已过期'))
              .fontSize(11).fontColor('#FFE1A6').maxLines(2)
          }
        }.width('100%').padding({ left: 10, right: 10, top: 9, bottom: 9 }).backgroundColor('rgba(111, 168, 207, 0.12)').borderRadius(UI_RADIUS_CONTROL)
        Column({ space: 7 }) {
          Row() {
            Text(I18n.t('sat_sources_title')).fontSize(13).fontColor('#E5FFFFFF').layoutWeight(1)
            Text(this.satelliteStore.satSources.length.toString()).fontSize(11).fontColor('#99FFFFFF')
          }.width('100%')
          Text(I18n.t('sat_sources_offline_hint')).fontSize(10).fontColor('#99FFFFFF').width('100%').maxLines(3)
          if (this.satelliteStore.satSources.length > 0) {
            ForEach(this.satelliteStore.satSources, (source: SatelliteSource, sourceIndex: number) => {
              Row({ space: 6 }) {
                Column({ space: 2 }) {
                  Text((source.local ? I18n.t('sat_source_local') : I18n.t('sat_source_remote')) + ' · ' + source.scheme.toUpperCase())
                    .fontSize(11).fontColor(source.valid ? '#DCEEFF' : '#FFE1A6').maxLines(1)
                  Text(source.url).fontSize(9).fontColor('#88FFFFFF').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                if (source.addNew) Text(I18n.t('sat_source_add_new')).fontSize(9).fontColor('#B7D8F0')
                Button(I18n.t('sat_source_delete')).fontSize(10).fontColor('#FFE1A6').backgroundColor('rgba(180,60,50,0.22)')
                  .borderRadius(UI_RADIUS_CONTROL).height(28).padding({ left: 8, right: 8 })
                  .onClick(() => { this.onDeleteSource(sourceIndex) })
              }.width('100%').padding({ left: 8, right: 8, top: 6, bottom: 6 }).backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL)
            }, (source: SatelliteSource) => source.index.toString() + ':' + source.url)
          }
          TextInput({ text: this.satelliteStore.satSourceInput, placeholder: I18n.t('sat_source_placeholder') })
            .height(36).fontSize(11).fontColor('#E5FFFFFF').placeholderColor(this.subColor).width('100%')
            .backgroundColor(this.inputColor).border({ width: 1, color: 'rgba(214, 238, 255, 0.14)' }).borderRadius(UI_RADIUS_CONTROL)
            .onChange((value: string) => { this.onSourceInput(value) })
          Row({ space: 6 }) {
            Toggle({ type: ToggleType.Switch, isOn: this.satelliteStore.satSourceAddNew }).width(42).height(24)
              .onChange((value: boolean) => { this.onSourceAddNew(value) })
            Text(I18n.t('sat_source_add_new')).fontSize(10).fontColor('#B7D8F0').layoutWeight(1)
            Button(I18n.t('sat_source_add')).fontSize(11).fontColor('#E1F2FA').backgroundColor('rgba(91,147,191,0.34)')
              .borderRadius(UI_RADIUS_CONTROL).height(30).padding({ left: 10, right: 10 }).onClick(() => { this.onAddSource() })
          }.width('100%')
          Row({ space: 6 }) {
            Button(I18n.t('sat_refresh')).fontSize(10).fontColor('#E1F2FA').backgroundColor('rgba(91,147,191,0.25)')
              .borderRadius(UI_RADIUS_CONTROL).height(30).layoutWeight(1).onClick(() => { this.onRefreshCatalog() })
            TextInput({ text: this.satelliteStore.satTleFileInput, placeholder: I18n.t('sat_tle_path_placeholder') }).height(30).fontSize(10)
              .fontColor('#E5FFFFFF').placeholderColor(this.subColor).backgroundColor(this.inputColor).borderRadius(UI_RADIUS_CONTROL).layoutWeight(2)
              .onChange((value: string) => { this.onTleFileInput(value) })
            Button(I18n.t('sat_tle_import')).fontSize(10).fontColor('#E1F2FA').backgroundColor('rgba(91,147,191,0.25)')
              .borderRadius(UI_RADIUS_CONTROL).height(30).padding({ left: 8, right: 8 }).onClick(() => { this.onImportTle() })
          }.width('100%')
          Row() {
            Text(I18n.t('sat_auto_add')).fontSize(11).fontColor('#E5FFFFFF').layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.satelliteStore.satUpdateSettings.autoAddEnabled }).width(42).height(24)
              .onChange((value: boolean) => { this.onSetUpdateSetting('autoAddEnabled', value) })
          }.width('100%')
          Row() {
            Text(I18n.t('sat_auto_remove')).fontSize(11).fontColor('#E5FFFFFF').layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.satelliteStore.satUpdateSettings.autoRemoveEnabled }).width(42).height(24)
              .onChange((value: boolean) => { this.onSetUpdateSetting('autoRemoveEnabled', value) })
          }.width('100%')
          Row() {
            Text(I18n.t('sat_auto_display')).fontSize(11).fontColor('#E5FFFFFF').layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.satelliteStore.satUpdateSettings.autoDisplayEnabled }).width(42).height(24)
              .onChange((value: boolean) => { this.onSetUpdateSetting('autoDisplayEnabled', value) })
          }.width('100%')
          Row({ space: 6 }) {
            Text(I18n.t('sat_update_frequency')).fontSize(11).fontColor('#E5FFFFFF').layoutWeight(1)
            TextInput({ text: this.satelliteStore.satUpdateFrequencyInput, placeholder: '72' }).height(30).fontSize(11)
              .fontColor('#E5FFFFFF').backgroundColor(this.inputColor).borderRadius(UI_RADIUS_CONTROL).width(66)
              .onChange((value: string) => { this.onUpdateFrequencyInput(value) })
              .onSubmit(() => { this.onSubmitUpdateFrequency() })
            Text(I18n.t('sat_hours')).fontSize(10).fontColor('#99FFFFFF')
          }.width('100%')
          Row() {
            Text(I18n.t('sat_online_updates')).fontSize(11).fontColor('#E5FFFFFF').layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.satelliteStore.satUpdateSettings.updatesEnabled })
              .enabled(!this.satelliteStore.satOffline).width(42).height(24)
              .onChange((value: boolean) => { this.onSetUpdateSetting('updatesEnabled', value) })
          }.width('100%')
          if (this.satelliteStore.satSourceStatus.length > 0) Text(this.satelliteStore.satSourceStatus).fontSize(10).fontColor('#C9E8FF').width('100%').maxLines(3)
        }.width('100%').padding({ left: 10, right: 10, top: 9, bottom: 9 }).backgroundColor('rgba(111, 168, 207, 0.08)').borderRadius(UI_RADIUS_CONTROL)
        Row() {
          Text(I18n.t('c_total_count')).fontSize(13).fontColor('#E5FFFFFF').layoutWeight(1)
          Text(this.satelliteStore.satCount.toString()).fontSize(13).fontColor('#99FFFFFF')
        }.width('100%').padding({ left: 10, right: 10 }).backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL)
        Row() {
          Text(I18n.t('c_show_labels')).fontSize(13).fontColor('#E5FFFFFF').layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.satelliteStore.satLabels })
            .onChange((isOn: boolean) => { this.onSetFlag('labels', isOn) })
        }.width('100%').padding({ left: 10, right: 10 }).backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL)
        Row() {
          Text(I18n.t('c_show_orbits')).fontSize(13).fontColor('#E5FFFFFF').layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.satelliteStore.satOrbitLines })
            .onChange((isOn: boolean) => { this.onSetFlag('orbitLines', isOn) })
        }.width('100%').padding({ left: 10, right: 10 }).backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL)
        Text(I18n.t('sat_orbit_preview_hint')).fontSize(11).fontColor(this.subColor).width('100%')
        Row() {
          Text(I18n.t('c_show_hints')).fontSize(13).fontColor('#E5FFFFFF').layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.satelliteStore.satHints })
            .onChange((isOn: boolean) => { this.onSetFlag('hints', isOn) })
        }.width('100%').padding({ left: 10, right: 10 }).backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL)
        Row() {
          Text(I18n.t('c_icon_mode')).fontSize(13).fontColor('#E5FFFFFF').layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.satelliteStore.satIconicMode })
            .onChange((isOn: boolean) => { this.onSetFlag('iconicMode', isOn) })
        }.width('100%').padding({ left: 10, right: 10 }).backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL)
        Row() {
          Text(I18n.t('c_hide_invisible')).fontSize(13).fontColor('#E5FFFFFF').layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.satelliteStore.satHideInvisible })
            .onChange((isOn: boolean) => { this.onSetFlag('hideInvisible', isOn) })
        }.width('100%').padding({ left: 10, right: 10 }).backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL)
        SatelliteGroupSelector({
          groups: this.satelliteStore.satGroups,
          activeGroup: this.satelliteStore.activeSatGroup,
          loading: this.satelliteStore.satelliteListLoading,
          subColor: this.subColor,
          accentColor: this.accentColor,
          textColor: this.textColor,
          bgColor: this.panelColor,
          scroller: this.groupScroller,
          onGroupScroll: () => { this.onPublishState() },
          onSelect: (group: string) => { this.onSelectGroup(group) }
        })
        TextInput({ text: this.satelliteStore.satQuery, placeholder: '搜索卫星名称或 NORAD 编号' })
          .height(36).fontSize(13).fontColor('#E5FFFFFF').placeholderColor(this.subColor)
          .backgroundColor(this.inputColor).border({ width: 1, color: 'rgba(214, 238, 255, 0.14)' }).borderRadius(UI_RADIUS_CONTROL)
          .width('100%')
          .onChange((value: string) => { this.onQueryChange(value) })
          .onSubmit(() => { this.onSubmitQuery() })
        if (this.satelliteStore.satItems.length > 0) {
          Text('匹配卫星 ' + this.satelliteStore.satMatchedCount.toString() + ' 颗').fontSize(12).fontColor('#99FFFFFF').width('100%').padding({ left: 2 })
          ForEach(this.satelliteStore.satItems, (item: SatelliteListItem) => {
            Column({ space: 3 }) {
              Row({ space: 8 }) {
                Column({ space: 1 }) {
                  Text(item.name).fontSize(13).fontColor('#E5FFFFFF').fontWeight(FontWeight.Medium).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  if (item.englishName !== item.name) {
                    Text(item.englishName).fontSize(10).fontColor('#99FFFFFF').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                if (item.outdated) {
                  Text('历元过期').fontSize(10).fontColor('#FFE1A6')
                }
              }.width('100%')
              Text('NORAD ' + item.id + (item.heightKm > 0 ? ' · 高度 ' + item.heightKm.toFixed(0) + ' km' : ''))
                .fontSize(10).fontColor('#88FFFFFF').maxLines(1)
            }.width('100%').padding({ left: 10, right: 10, top: 8, bottom: 8 }).backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL)
              .onClick(() => { this.onSearchObject(item) })
          }, (item: SatelliteListItem) => item.id)
        } else if (this.satelliteStore.satQuery.length > 0) {
          Text('未找到匹配的内置卫星').fontSize(12).fontColor('#99FFFFFF').width('100%').padding({ left: 4, top: 4, bottom: 4 })
        }
      }.width('100%').padding({ left: 8, right: 8, top: 8, bottom: 8 })
    }.width('100%').layoutWeight(1).scrollBar(BarState.Auto).scrollBarWidth(4).scrollBarColor('#33FFFFFF')
      .onScroll(() => { this.onPublishState() })
  }
}
