import { StarCatalogItem, CatalogHealthEntry } from '../pages/MainWindowModels'
import { CatOption } from '../pages/StellariumTypes'

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
@Observed
export class CatalogStore {
  catalogList: StarCatalogItem[] = []
  catalogLoading: boolean = false
  catalogBusy: boolean = false
  catalogDownloadingId: string = ''
  catalogMsg: string = ''
  starCatalogHealth: CatalogHealthEntry = {}
  objectCatalogCategories: CatOption[] = []
}
