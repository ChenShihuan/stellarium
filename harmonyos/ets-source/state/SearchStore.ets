import { NameItem, SearchSug } from '../pages/StellariumTypes'
import { ConstellationNavigationItem } from '../pages/MainWindowModels'

// 搜索域状态：输入文本与候选建议。
//
// `searchHistory` 不进 store：它只在存储读写与 `searchObject()` 中使用、没有任何渲染读取，
// 因此保留为宿主普通字段（连 @State 都不需要）。
@Observed
export class SearchStore {
  searchText: string = ''
  searchSuggestions: SearchSug[] = []

  // ==== 筛选器（原宿主 @State）====
  searchFilterPage: string = ''
  searchCategory: string = 'planet'
  searchVisibilityFilter: string = 'all'
  searchInstrumentFilter: string = 'all'

  // ==== 分类浏览（原宿主 @State）====
  categoryObjects: NameItem[] = []
  categoryObjectCount: number = 0
  categoryLoadedCount: number = 0
  categoryLoading: boolean = false
  categoryLoadFailed: boolean = false
  categoryHasMore: boolean = false
  categoryListKind: string = ''
  categoryCatalogTotal: number = 0
  categoryCatalogReady: boolean = true
  categoryCatalogMessage: string = ''
  categoryModuleId: string = ''
  pendingPluginCatalogId: string = ''
  // ==== 星座快捷导航与 RA/Dec 坐标输入 ====
  constellationNavigationItems: ConstellationNavigationItem[] = []
  coordInputRA: string = ''
  coordInputDec: string = ''
}