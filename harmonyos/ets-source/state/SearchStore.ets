import { NameItem, SearchSug, StellariumBridgeResponse } from '../pages/StellariumTypes'
import { ConstellationNavigationItem } from '../pages/MainWindowModels'
import { CommandPort } from '../bridge/CommandPort'

// 宿主 → SearchStore 的跨域只读注入（§13.1 规则 6 / §14.8 规则 2）。
// loadConstellationNavigation 需在回包返回时比对语言刷新代际 languageRefreshSerial 以丢弃
// 过期请求；该代际的单一持有者是 LanguageStore（§14 B3-1），本 store 只经 hooks 只读获取，
// 不 import 他 store、不另存副本。
export interface SearchHostHooks {
  languageSerial(): number
}

// 搜索域状态：输入文本与候选建议。
//
// `searchHistory` 不进 store：它只在存储读写与 `searchObject()` 中使用、没有任何渲染读取，
// 因此保留为宿主普通字段（连 @State 都不需要）。
//
// §14 B3-1：加载器 loadConstellationNavigation 自宿主搬入（星座快捷导航列表），宿主调用点
// 显式传入当次 languageSerial；回包过期判定经 SearchHostHooks.languageSerial() 读 LanguageStore。
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

  // —— 桥注入（§14.1 AB-0 / §14 B3-1） ——
  private port: CommandPort | null = null
  // 本域加载器不用请求序号（回包过期由语言代际 languageSerial 判定），预留统一约定（§14.8 规则 3）。
  private seq: number = 0
  private onChanged: (() => void) | null = null
  private hooks: SearchHostHooks | null = null

  // 宿主在 aboutToAppear 注入端口与发布回调；重复注入会覆盖旧值（幂等）。
  attachPort(port: CommandPort, onChanged: () => void): void {
    this.port = port
    this.onChanged = onChanged
  }

  attachHooks(hooks: SearchHostHooks): void {
    this.hooks = hooks
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

  // 星座快捷导航：桥拉取星座名并按当前语言本地化（原宿主 loadConstellationNavigation，§14 B3-1 搬入；
  // 函数体逐字）。差异仅：this.callNativeWhenReady → port.requestWhenReady、
  // this.languageRefreshSerial → hooks.languageSerial()、this.searchStore.<f> → this.<f>；
  // 宿主调用点显式传入当次 languageSerial（默认参数依赖 this.languageRefreshSerial，已随字段入 store）。
  loadConstellationNavigation(languageSerial: number): void {
    const hooks = this.hooks
    const port = this.ensurePort()
    if (hooks === null || port === null) {
      return
    }
    port.requestWhenReady('getConstellationList', '', (result: StellariumBridgeResponse) => {
      if (hooks.languageSerial() !== languageSerial) return
      if (result.ok !== true || !Array.isArray(result.items)) return
      const rawItems = result.items as Array<Record<string, Object>>
      const localizedByEnglish: Record<string, string> = {}
      for (let index = 0; index < rawItems.length; index++) {
        const rawItem = rawItems[index]
        const englishName = rawItem['englishName'] !== undefined ? String(rawItem['englishName']) : ''
        const localizedName = rawItem['localizedName'] !== undefined ? String(rawItem['localizedName']) : englishName
        if (englishName.length > 0) localizedByEnglish[englishName] = localizedName
      }
      const navigationItems: ConstellationNavigationItem[] = []
      const seen: Record<string, boolean> = {}
      for (const rawItem of rawItems) {
        const englishName = rawItem['englishName'] !== undefined ? String(rawItem['englishName']) : ''
        const localizedName = localizedByEnglish[englishName] ?? englishName
        if (englishName.length > 0 && localizedName.length > 0 && !seen[englishName]) {
          seen[englishName] = true
          navigationItems.push({ englishName: englishName, localizedName: localizedName })
        }
      }
      navigationItems.sort((left: ConstellationNavigationItem, right: ConstellationNavigationItem) =>
        left.localizedName.localeCompare(right.localizedName))
      this.constellationNavigationItems = navigationItems
    })
  }
}
