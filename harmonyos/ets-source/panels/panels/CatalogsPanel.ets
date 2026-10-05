import { I18n } from '../../pages/I18n'
import { OFFLINE_APPGALLERY_BUILD, StarCatalogItem } from '../../pages/MainWindowModels'
import { UI_RADIUS_CONTROL } from '../../common/ui/UiTokens'
import { CatalogStore } from '../../state/CatalogStore'

// 星表下载面板（原宿主 panelContent() 的 `catalogs` 分支，分支体原样下沉）。
//
// 判定条件 `activePanel === 'catalogs'` 留在宿主。列表/加载/下载态来自宿主的
// @State 字段、以 @Prop 传入；下载动作回注 startCatalogDownload。
// 成员名避开 CustomComponent 属性方法（卡片描边用 cardBorderColor，不用 borderColor）。

@Component
export struct CatalogsPanel {
  // 状态经 @ObjectLink 订阅（review §2.7 第三批小簇批处理）。动作仍为宿主注入的回调。
  @ObjectLink catalogStore: CatalogStore
  @Prop cardBorderColor: string
  onDownload: (id: string) => void = () => {}

  build() {
    if (OFFLINE_APPGALLERY_BUILD) {
      Column() {
        Text(I18n.t('m_all_catalogs_included')).fontSize(14).fontColor('#E5FFFFFF').margin({ top: 8 })
      }.width('100%').height(120).justifyContent(FlexAlign.Center)
    } else {
      if (this.catalogStore.catalogLoading) {
        Column() {
          Text(I18n.t('c_loading_catalogs')).fontSize(13).fontColor('#99FFFFFF')
        }.width('100%').height(120).justifyContent(FlexAlign.Center)
      } else if (this.catalogStore.catalogList.length === 0) {
        Column() {
          Text(I18n.t('m_no_catalogs')).fontSize(14).fontColor('#E5FFFFFF').margin({ top: 8 })
          Text(I18n.t('m_all_catalogs_included')).fontSize(12).fontColor('#CC8FB6FF').margin({ top: 6 })
        }.width('100%').height(120).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.catalogStore.catalogList, (c: StarCatalogItem) => {
              Column({ space: 4 }) {
                Row() {
                  Column() {
                    Text(c.name)
                      .fontSize(14).fontColor('#E5FFFFFF').fontWeight(FontWeight.Medium)
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                    if (c.size.length > 0) {
                      Text('大小 ' + c.size)
                        .fontSize(11).fontColor('#99FFFFFF').margin({ top: 2 })
                    }
                  }.layoutWeight(1)
                  if (c.checked) {
                    Text(I18n.t('c_installed'))
                      .fontSize(11).fontColor('#7FB3DC')
                      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                      .backgroundColor('rgba(91,147,191,0.15)').borderRadius(UI_RADIUS_CONTROL)
                  } else {
                    Button(this.catalogStore.catalogBusy && this.catalogStore.catalogDownloadingId === c.id ? '下载中' : '下载')
                      .fontSize(12).fontColor('#E5FFFFFF')
                      .backgroundColor(this.catalogStore.catalogBusy ? 'rgba(255,255,255,0.10)' : 'rgba(107,163,214,0.35)')
                      .borderRadius(UI_RADIUS_CONTROL).height(32).padding({ left: 14, right: 14 })
                      .enabled(!this.catalogStore.catalogBusy)
                      .onClick(() => { this.onDownload(c.id) })
                  }
                }.width('100%')
                if (this.catalogStore.catalogBusy && this.catalogStore.catalogDownloadingId === c.id && this.catalogStore.catalogMsg.length > 0) {
                  Text(this.catalogStore.catalogMsg).fontSize(11).fontColor('#99FFFFFF').width('100%')
                }
              }
              .width('100%')
              .padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .backgroundColor('rgba(255,255,255,0.04)')
              .borderRadius(UI_RADIUS_CONTROL)
              .border({ width: 1, color: this.cardBorderColor })
            }, (c: StarCatalogItem) => c.id)
          }.width('100%').padding({ left: 2, right: 2 })
        }.width('100%').layoutWeight(1).scrollBar(BarState.Auto).scrollBarWidth(4).scrollBarColor('#33FFFFFF')
      }
    }
  }
}
