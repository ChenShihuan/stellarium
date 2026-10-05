import hilog from '@ohos.hilog'
import { NameItem, SearchSug, StellariumBridgeResponse, WutTarget } from '../pages/StellariumTypes'
import { ConstellationNavigationItem } from '../pages/MainWindowModels'
import { I18n } from '../pages/I18n'
import { messierNumberOf, minorPlanetNumberOf } from '../common/derive/astro'
import { celestialTitle } from '../common/derive/labels'
import { CommandPort } from '../bridge/CommandPort'

// 宿主 → SearchStore 的跨域只读 / 助手 / 存储注入（§13.1 规则 6 / §14.8 规则 2）。
// loadConstellationNavigation 需在回包返回时比对语言刷新代际 languageRefreshSerial 以丢弃
// 过期请求；该代际的单一持有者是 LanguageStore（§14 B3-1），本 store 只经 hooks 只读获取，
// 不 import 他 store、不另存副本。
//
// §14 B3-3：分类浏览（loadCategoryObjects / loadMoreCategoryObjects）自宿主搬入，其调用的
// 宿主助手 / CLI 发布点 / 插件加载器经下列 hooks 具名回注；搜索历史 Preferences 读写同理
// （store 不 import NAPI/UI 上下文，§14.8 规则 2）。
export interface SearchHostHooks {
  languageSerial(): number
  // CLI 发布点（沿用 CatalogHostHooks 同名注入）。
  publishSearchBrowserState(): void
  // 分类 code → 目录 moduleId（读宿主 searchCategoryOptions / CatalogStore）。
  categoryModuleIdFor(category: string): string
  // 确保插件已加载（loadCategoryObjects 的 Satellites 分支）。
  ensurePluginLoaded(pluginName: string, callback: () => void, failureCallback?: () => void): void
  // 天体标题（loadMoreCategoryObjects 生成 NameItem）；副标题已随 §14 A2-3 下沉本 store 方法，
  // 故不再是 hook。
  celestialTitle(nativeName: string, englishName: string): string
  // 搜索历史 Preferences 原始读写（宿主用 @ohos.data.preferences 实现）。
  readSearchHistoryStorage(): Promise<string>
  writeSearchHistoryStorage(json: string): Promise<void>
}

// 搜索域状态：输入文本与候选建议、分类浏览、搜索历史。
//
// §14 B3-3：`searchHistory` 由宿主普通字段搬入本 store（单一持有者）。原宿主中的读取方只有
// `searchObject()`（写历史 + 持久化），非渲染读取，故直接写 `this.searchStore.searchHistory`；
// Preferences 读写经 SearchHostHooks.readSearchHistoryStorage / writeSearchHistoryStorage 回注。
//
// §14 B3-1：加载器 loadConstellationNavigation 自宿主搬入（星座快捷导航列表），宿主调用点
// 显式传入当次 languageSerial；回包过期判定经 SearchHostHooks.languageSerial() 读 LanguageStore。
//
// §14 B3-3：loadCategoryObjects / loadMoreCategoryObjects 自宿主搬入（分类浏览分页），
// 跨页游标 categoryOffset 与代际计数 categoryRequestSerial、跨域标志 satelliteCatalogReady
// 随加载器一并入 store（单一持有者 + 无第二份副本）。
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
  // §14 B3-3：跨页游标 / 代际计数 / 卫星目录就绪标志随分类浏览加载器搬入（原宿主裸字段）。
  categoryOffset: number = 0
  categoryRequestSerial: number = 0
  satelliteCatalogReady: boolean = false
  // §14 B3-3：搜索历史（原宿主普通字段；单一持有者，Preferences 读写经 hooks）。
  searchHistory: string[] = []
  // §14 B3-3：分类浏览分页大小（原宿主 readonly 常量，随加载器搬入）。
  private readonly CATEGORY_PAGE_SIZE: number = 60
  // ==== 星座快捷导航与 RA/Dec 坐标输入 ====
  constellationNavigationItems: ConstellationNavigationItem[] = []
  coordInputRA: string = ''
  coordInputDec: string = ''

  // —— 桥注入（§14.1 AB-0 / §14 B3-1） ——
  private port: CommandPort | null = null
  // 通用预留序号（本 store 的分类加载器使用具名 categoryRequestSerial，见上）。
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

  // 分类浏览首页：重置游标与列表状态后发起首屏加载（原宿主 loadCategoryObjects，§14 B3-3 搬入；
  // 函数体逐字）。差异仅：this.searchStore.<f> → this.<f>、this.categoryOffset/categoryRequestSerial/
  // satelliteCatalogReady → this.<f>、this.categoryModuleIdFor → hooks.categoryModuleIdFor、
  // this.publishSearchBrowserState → hooks.publishSearchBrowserState、this.ensurePluginLoaded →
  // hooks.ensurePluginLoaded、this.loadMoreCategoryObjects → this.loadMoreCategoryObjects（同 store）。
  loadCategoryObjects(category: string, moduleIdOverride: string = ''): void {
    const hooks = this.hooks
    if (hooks === null) {
      return
    }
    this.searchCategory = category
    this.pendingPluginCatalogId = ''
    const moduleId = moduleIdOverride.length > 0 ? moduleIdOverride : hooks.categoryModuleIdFor(category)
    this.categoryModuleId = moduleId
    this.categoryObjects = []
    this.categoryObjectCount = 0
    this.categoryLoadedCount = 0
    this.categoryLoading = false
    this.categoryLoadFailed = false
    this.categoryHasMore = false
    this.categoryListKind = ''
    this.categoryCatalogTotal = 0
    this.categoryCatalogReady = true
    this.categoryCatalogMessage = ''
    this.categoryOffset = 0
    this.categoryRequestSerial += 1
    hooks.publishSearchBrowserState()
    if (moduleId === 'Satellites' && !this.satelliteCatalogReady) {
      const serial = this.categoryRequestSerial
      this.categoryLoading = true
      hooks.ensurePluginLoaded('Satellites', () => {
        if (serial !== this.categoryRequestSerial || this.categoryModuleId !== 'Satellites') return
        this.satelliteCatalogReady = true
        this.categoryLoading = false
        this.loadMoreCategoryObjects()
      }, () => {
        if (serial !== this.categoryRequestSerial || this.categoryModuleId !== 'Satellites') return
        this.categoryLoading = false
        this.categoryLoadFailed = true
      })
      return
    }
    this.loadMoreCategoryObjects()
  }

  // 分类浏览翻页：请求下一页并追加（原宿主 loadMoreCategoryObjects，§14 B3-3 搬入；函数体逐字）。
  // 差异仅：this.searchStore.<f> → this.<f>、this.categoryOffset/categoryRequestSerial → this.<f>、
  // this.CATEGORY_PAGE_SIZE → this.CATEGORY_PAGE_SIZE（同 store 常量）、
  // this.callNativeWhenReady → port.requestWhenReady（重试档 0/100/60 逐字保留、onFailure 由第 4 参传入）、
  // this.celestialTitle → hooks.celestialTitle（副标题经 §14 A2-3 下沉本 store 方法）。
  loadMoreCategoryObjects(): void {
    const hooks = this.hooks
    const port = this.ensurePort()
    if (hooks === null || port === null) {
      return
    }
    if (this.categoryLoading || !this.categoryModuleId.length || (!this.categoryHasMore && this.categoryOffset > 0)) {
      return
    }
    const serial = this.categoryRequestSerial
    const offset = this.categoryOffset
    const category = this.searchCategory
    this.categoryLoading = true
    this.categoryLoadFailed = false
    port.requestWhenReady('listObjects', this.categoryModuleId + '|' + this.CATEGORY_PAGE_SIZE + '|' + offset + '|' + this.searchVisibilityFilter + '|' + this.searchInstrumentFilter, (result: StellariumBridgeResponse) => {
      if (serial !== this.categoryRequestSerial) { return }
      const items = Array.isArray(result.items) ? result.items as string[] : []
      const keys = Array.isArray(result.keys) ? result.keys as string[] : []
      const types = Array.isArray(result.types) ? result.types as string[] : []
      const altitudes = Array.isArray(result.altitudes) ? result.altitudes as number[] : []
      const magnitudes = Array.isArray(result.magnitudes) ? result.magnitudes as number[] : []
      const visibleNow = Array.isArray(result.visibleNow) ? result.visibleNow as boolean[] : []
      const seen: Record<string, boolean> = {}
      for (const existing of this.categoryObjects) {
        if (existing.name.length > 0) { seen[existing.name] = true }
      }
      const browse: NameItem[] = []
      for (let i = 0; i < items.length; i++) {
        const key = (keys[i] && keys[i].length > 0) ? keys[i] : items[i]
        if (key.length === 0 || seen[key]) { continue }
        seen[key] = true
        // Keep the stable catalog ID for native selection. The display label
        // already comes from StelObject::getNameI18n() and the official sky
        // translation resources loaded by the native core.
        const title = hooks.celestialTitle(items[i], key)
        browse.push({ name: key, zh: title, subtitle: this.celestialSubtitle(title, key), type: types[i] ?? '', altitude: altitudes[i], magnitude: magnitudes[i], visibleNow: visibleNow[i] === true })
      }
      const combined = this.categoryObjects.concat(browse)
      this.categoryObjects = combined
      this.categoryLoadedCount = combined.length
      this.categoryObjectCount = typeof result.count === 'number' && result.count > 0 ? result.count : combined.length
      this.categoryOffset = offset + items.length
      this.categoryHasMore = result.hasMore === true && items.length > 0
      this.categoryListKind = result.listKind ?? ''
      this.categoryCatalogTotal = typeof result.catalogTotal === 'number' ? result.catalogTotal : this.categoryObjectCount
      this.categoryCatalogReady = result.catalogReady !== false
      this.categoryCatalogMessage = result.catalogMessage !== undefined ? String(result.catalogMessage) : ''
      this.categoryLoading = false
      this.categoryLoadFailed = false
    }, (_failure: StellariumBridgeResponse) => {
      if (serial !== this.categoryRequestSerial) { return }
      this.categoryLoading = false
      this.categoryLoadFailed = true
      this.categoryHasMore = false
    }, 0, 100, 60)
  }

  // 首次启动从 Preferences 载入搜索历史（原宿主 loadSearchHistoryFromStorage，§14 B3-3 搬入；
  // 函数体逐字）。差异仅：getUIContext + preferences → hooks.readSearchHistoryStorage
  //（store 不 import NAPI/UI）；this.searchHistory → this.searchHistory（本 store 字段）。
  async loadSearchHistoryFromStorage(): Promise<void> {
    const hooks = this.hooks
    try {
      const jsonStr: string = hooks !== null ? await hooks.readSearchHistoryStorage() : '[]'
      const parsed: string[] = JSON.parse(jsonStr)
      if (parsed.length > 0) {
        this.searchHistory = parsed.slice(0, 20)
      }
    } catch (e) {
      hilog.warn(0xD002, 'Stellarium', 'load search history failed: %{public}s', String(e))
    }
  }

  // 持久化搜索历史（原宿主 saveSearchHistoryToStorage，§14 B3-3 同片搬入；随 searchHistory 单一
  // 持有者）。差异仅：getUIContext + preferences → hooks.writeSearchHistoryStorage。
  async saveSearchHistoryToStorage(): Promise<void> {
    const hooks = this.hooks
    if (hooks === null) {
      return
    }
    try {
      await hooks.writeSearchHistoryStorage(JSON.stringify(this.searchHistory))
    } catch (e) {
      hilog.warn(0xD002, 'Stellarium', 'save search history failed: %{public}s', String(e))
    }
  }

  // ==== 搜索域「取值/标签」助手（§14 A2-3，原宿主私有方法逐字搬入）====
  //
  // 均读本 store 的搜索筛选/当前分类字段（searchVisibilityFilter / searchInstrumentFilter /
  // searchCategory），按 §14.3「读本域 store 字段 → 并入该 store 方法（零入参）」下沉；
  // 函数体逐字保留，仅去掉宿主前缀。

  // 可见性筛选的当前标签（原宿主 searchVisibilityLabel）。
  searchVisibilityLabel(): string {
    if (this.searchVisibilityFilter === 'above') return I18n.t('search_above_horizon')
    if (this.searchVisibilityFilter === 'good') return I18n.t('search_good_observing')
    return ''
  }

  // 观测设备筛选的当前标签（原宿主 searchInstrumentLabel）。
  searchInstrumentLabel(): string {
    if (this.searchInstrumentFilter === 'naked') return I18n.t('search_naked_eye')
    if (this.searchInstrumentFilter === 'binocular') return I18n.t('search_binoculars')
    if (this.searchInstrumentFilter === 'telescope') return I18n.t('search_telescope')
    return ''
  }

  // 天体副标题（目录号 / 小行星永久编号；原宿主 celestialSubtitle）。
  celestialSubtitle(title: string, englishName: string): string {
    const parts: string[] = []
    if (englishName.length > 0 && title.trim().toLowerCase() !== englishName.trim().toLowerCase()) {
      parts.push(englishName.trim())
    }
    const messier = messierNumberOf(englishName)
    if (messier.length > 0) { parts.push(I18n.format('search_catalog_number', ['M' + messier])) }
    if (this.searchCategory === 'asteroid') {
      const number = minorPlanetNumberOf(englishName)
      if (number.length > 0) { parts.push(I18n.format('search_permanent_number', [number])) }
    }
    return parts.join(' · ')
  }

  // WUT 目标副标题（原宿主 wutTargetSubtitle，A2-6）：标题经同源纯函数 celestialTitle 求得，
  // 再走本 store 的 celestialSubtitle。函数体逐字等价（this.wutTargetTitle/target → 内联标题）。
  wutTargetSubtitle(target: WutTarget): string {
    return this.celestialSubtitle(celestialTitle(target.name ?? '', target.englishName ?? ''), target.englishName ?? '')
  }

  // 分类浏览条目的副标题（原宿主 categoryObservationSubtitle）。
  categoryObservationSubtitle(item: NameItem): string {
    const parts: string[] = []
    const catalogText = this.celestialSubtitle(String(item.zh ?? item.name), item.name)
    if (catalogText.length > 0) parts.push(catalogText)
    if (item.visibleNow !== undefined) {
      parts.push(item.visibleNow ? I18n.t('search_visible_now') : I18n.t('search_below_horizon'))
    }
    if (item.altitude !== undefined && Number.isFinite(item.altitude)) {
      parts.push(I18n.format('search_altitude', [item.altitude.toFixed(0)]))
    }
    if (item.magnitude !== undefined && Number.isFinite(item.magnitude) && item.magnitude < 90) {
      parts.push(I18n.format('search_magnitude', [item.magnitude.toFixed(1)]))
    }
    return parts.join(' · ')
  }
}
