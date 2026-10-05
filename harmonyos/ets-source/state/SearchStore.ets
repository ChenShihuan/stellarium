import { SearchSug } from '../pages/StellariumTypes'

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
}
