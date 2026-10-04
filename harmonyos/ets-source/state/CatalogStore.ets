import { StarCatalogItem, CatalogHealthEntry, StarCatalogsResponse, StarCatalogRaw } from '../pages/MainWindowModels'
import { CatOption, StellariumBridgeResponse } from '../pages/StellariumTypes'
import { I18n } from '../pages/I18n'
import { CommandPort } from '../bridge/CommandPort'

// 星表下载域中"面板可见"的状态（原宿主 5 个 @State）。
//
// review §2.7 第三批（小簇批处理）之一。面板别名对应：
// `loading←catalogLoading`、`items←catalogList`、`busy←catalogBusy`、
// `downloadingId←catalogDownloadingId`、`msg←catalogMsg`；store 沿用宿主字段名。
//
// `catalogHealthLoaded` / `catalogManifestPresent` **不搬**：它们与卫星面板（"卫星目录健康"
// 文案）及恒星表共用，不是本面板的入参 —— 与卫星片里保留这两个字段的判断一致。
// 后续（review §2.7 续作）并入：`starCatalogHealth`（SettingsQuickLegacyPanel 以 @Prop 消费）与
// `objectCatalogCategories`（经宿主 searchAllCategoryOptions() 进 SearchPanel @Prop categories）。
//
// —— 桥注入约定（§14.1，AB-0 起） ——
// `loadStarCatalogs`（§14 B1-3）由 store 自持，宿主不再持有同名方法：宿主在 aboutToAppear
// 调用 attachPort(port, onChanged) 注入 CommandPort，store 侧用 ensurePort() 守卫。
// 请求序号 seq 随加载器搬入 store（§14.8 规则 3），本加载器暂未用到，供后续 B 片复用。
// 本域无 publish* 发布点、消费方均为 @ObjectLink（字段赋值即刷新），故宿主注入的 onChanged
// 为等价空实现，notifyChanged() 为无副作用调用。
@Observed
export class CatalogStore {
  catalogList: StarCatalogItem[] = []
  catalogLoading: boolean = false
  catalogBusy: boolean = false
  catalogDownloadingId: string = ''
  catalogMsg: string = ''
  starCatalogHealth: CatalogHealthEntry = {}
  objectCatalogCategories: CatOption[] = []

  // —— 桥注入（§14.1 AB-0） ——
  private port: CommandPort | null = null
  // 原宿主的请求序号搬入 store（§14.8 规则 3）；本加载器暂未用到，供后续 B 片复用。
  private seq: number = 0
  private onChanged: (() => void) | null = null

  // 宿主在 aboutToAppear 注入端口与发布回调；重复注入会覆盖旧值（幂等）。
  attachPort(port: CommandPort, onChanged: () => void): void {
    this.port = port
    this.onChanged = onChanged
  }

  // 加载器统一守卫：未注入端口时静默跳过（不 crash，也不 import 桥）。
  private ensurePort(): CommandPort | null {
    return this.port
  }

  private notifyChanged(): void {
    if (this.onChanged !== null) {
      this.onChanged()
    }
  }

  // 星表下载面板：桥查询可用星表列表（原宿主 loadStarCatalogs，函数体逐字搬入；
  // 仅 this.callNativeWhenReady → this.port.requestWhenReady、this.catalogStore.<f> → this.<f>）。
  loadStarCatalogs(): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    this.catalogLoading = true
    port.requestWhenReady('getStarCatalogs', '', (r: StellariumBridgeResponse) => {
      const resp = r as StarCatalogsResponse
      const list = resp.catalogs ?? []
      this.catalogList = list.map((c: StarCatalogRaw): StarCatalogItem => ({
        id: c.id ?? '',
        name: c.name ?? (c.id ?? I18n.t('catalog_fallback')),
        size: c.size ?? '',
        key: c.key ?? '',
        fileName: c.fileName ?? '',
        url: c.url ?? '',
        html: c.html ?? '',
        checked: c.checked === true || c.checked === 'true' || c.checked === 1,
      }))
      this.catalogLoading = false
      this.notifyChanged()
    })
  }
}
