import { StarCatalogItem, CatalogHealthEntry, StarCatalogsResponse, StarCatalogRaw, CatalogHealthResponse, StarCatalogStatusResponse } from '../pages/MainWindowModels'
import { CatOption, NameItem, StellariumBridgeResponse } from '../pages/StellariumTypes'
import { I18n } from '../pages/I18n'
import { catalogIconForModule, catalogIconForObjectType } from '../common/derive/catalog'
import { CommandPort } from '../bridge/CommandPort'

// 宿主 → CatalogStore 的检索域助手 / 跨 store setter。
// `loadObjectCatalogCategories` 写本 store 的 objectCatalogCategories，同时读 / 写 SearchStore
//（pendingPluginCatalogId / searchCategory / categoryModuleId），并复用宿主搜索域动作
//（loadCategoryObjects）与 CLI 发布点（publishSearchBrowserState）、读取宿主语言刷新代际。
// 这些跨 store / 宿主动作经 hooks 具名注入，store 不 import 他 store 或发布点。
export interface CatalogHostHooks {
  // 宿主语言刷新代际：回包返回时比对，丢弃过期请求。
  languageSerial(): number
  // 下载启动 / 轮询的 UI 提示经此回注（store 不触碰 UI）。
  flashHint(text: ResourceStr): void
  // SearchStore 的待定插件目录 id（读 + 清）。
  pendingPluginCatalogId(): string
  clearPendingPluginCatalogId(): void
  searchCategory(): string
  categoryModuleId(): string
  // 搜索域动作：loadCategoryObjects 由 SearchStore 承担（经宿主适配器转发），CLI 发布点留宿主。
  loadCategoryObjects(category: string, moduleIdOverride: string): void
  publishSearchBrowserState(): void
  // 目录健康相关的「跨域共用」标志（catalogHealthLoaded / catalogManifestPresent，
  // 供 SettingsQuickLegacyPanel / SatellitesPanel 经宿主闭包读取）与归属 SatelliteStore 的
  // satelliteCatalogHealth，均经此 setter 回注（store 不 import / 持有他 store）。
  setCatalogHealthLoaded(loaded: boolean): void
  setCatalogManifestPresent(present: boolean): void
  setSatelliteCatalogHealth(health: CatalogHealthEntry): void
}

// 星表下载域中"面板可见"的状态：面板别名 loading←catalogLoading、items←catalogList、
// busy←catalogBusy、downloadingId←catalogDownloadingId、msg←catalogMsg，store 沿用宿主字段名。
// 消费方为星表 / 设置面板（@ObjectLink）。`catalogHealthLoaded` / `catalogManifestPresent` 与
// `satelliteCatalogHealth` 属跨域共用字段，留宿主并经 CatalogHostHooks setter 回注；
// `starCatalogHealth`（设置快照面板）与 `objectCatalogCategories`（SearchPanel）由本 store 持有。
//
// —— 桥注入约定 ——
// 宿主在 aboutToAppear 调用 attachPort(port, onChanged) 注入 CommandPort，store 侧用 ensurePort() 守卫。
// 本域无 publish* 发布点、消费方均为 @ObjectLink（字段赋值即刷新），故 onChanged 为等价空实现。
@Observed
export class CatalogStore {
  catalogList: StarCatalogItem[] = []
  catalogLoading: boolean = false
  catalogBusy: boolean = false
  catalogDownloadingId: string = ''
  catalogMsg: string = ''
  starCatalogHealth: CatalogHealthEntry = {}
  objectCatalogCategories: CatOption[] = []

  // —— 桥注入 ——
  private port: CommandPort | null = null
  // 请求序号；本加载器暂未用到，预留以保持统一约定。
  private seq: number = 0
  private onChanged: (() => void) | null = null
  // 宿主助手 / 跨 store setter。
  private hooks: CatalogHostHooks | null = null

  // 宿主在 aboutToAppear 注入端口与发布回调；重复注入会覆盖旧值（幂等）。
  attachPort(port: CommandPort, onChanged: () => void): void {
    this.port = port
    this.onChanged = onChanged
  }

  // 宿主在 aboutToAppear 注入搜索域助手 / 跨 store setter；重复注入会覆盖旧值（幂等）。
  attachHooks(hooks: CatalogHostHooks): void {
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

  // 星表下载面板：桥查询可用星表列表。
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

  // 星表下载启动：忙时提示，否则下发下载命令并轮询状态。
  startCatalogDownload(id: string): void {
    const hooks = this.hooks
    const port = this.ensurePort()
    if (hooks === null || port === null) {
      return
    }
    if (this.catalogBusy) {
      hooks.flashHint(I18n.t('msg_catalog_downloading'))
      return
    }
    this.catalogBusy = true
    this.catalogDownloadingId = id
    this.catalogMsg = '开始下载 ' + id + ' …'
    hooks.flashHint('开始下载 ' + id)
    const r = port.request('downloadStarCatalog', id)
    if (!r || !r.ok) {
      this.catalogBusy = false
      this.catalogDownloadingId = ''
      this.catalogMsg = '下载启动失败'
      hooks.flashHint(I18n.t('msg_download_failed'))
      return
    }
    this.pollCatalogStatus(id)
  }

  // 星表下载状态轮询：600ms setInterval 自我收口（done/error/回包失败即 clearInterval），非持续定时器。
  private pollCatalogStatus(id: string): void {
    const hooks = this.hooks
    const port = this.ensurePort()
    if (hooks === null || port === null) {
      return
    }
    const timer = setInterval(() => {
      const r = port.request('getStarCatalogStatus', '') as StarCatalogStatusResponse
      if (!r || !r.ok) {
        clearInterval(timer)
        this.catalogBusy = false
        this.catalogDownloadingId = ''
        return
      }
      const state = r.state ?? 'downloading'
      const bytes = r.bytes ?? 0
      if (state === 'done') {
        clearInterval(timer)
        const md5ok = r.md5ok === true
        this.catalogMsg = md5ok ? ('「' + id + '」下载完成并已加载') : ('「' + id + '」下载完成，校验未通过')
        hooks.flashHint(this.catalogMsg)
        this.catalogBusy = false
        this.catalogDownloadingId = ''
        this.loadStarCatalogs()
      } else if (state === 'error') {
        clearInterval(timer)
        const err = r.error ?? '未知错误'
        this.catalogMsg = '下载失败：' + err
        hooks.flashHint('下载失败：' + err)
        this.catalogBusy = false
        this.catalogDownloadingId = ''
      } else {
        const mb = (bytes / (1024 * 1024)).toFixed(1)
        this.catalogMsg = '下载中 ' + id + '：' + mb + ' MB'
      }
    }, 600)
  }

  // 对象目录分类 chips：桥查询分类目录，回包后更新本 store 分类并经 hooks 提交 SearchStore。
  // 回包比对 languageSerial 丢弃过期请求；catalogIconForModule 由本 store 直接 import（纯函数）。
  loadObjectCatalogCategories(languageSerial: number): void {
    const hooks = this.hooks
    const port = this.ensurePort()
    if (hooks === null || port === null) {
      return
    }
    port.requestWhenReady('getObjectCatalogCategories', '', (result: StellariumBridgeResponse) => {
      if (hooks.languageSerial() !== languageSerial) return
      if (result.ok !== true || !Array.isArray(result.items)) return
      const items = result.items as Array<Record<string, Object>>
      const categories: CatOption[] = []
      for (let index = 0; index < items.length; index++) {
        const item = items[index]
        const moduleId = item['moduleId'] !== undefined ? String(item['moduleId']) : ''
        const label = item['label'] !== undefined ? String(item['label']) : moduleId
        if (moduleId.length === 0) continue
        categories.push({
          code: 'module:' + moduleId,
          label: label,
          moduleId: moduleId,
          iconKey: catalogIconForModule(moduleId),
          group: item['group'] !== undefined ? String(item['group']) : moduleId.split(':')[0],
          isCoreSubset: item['isCoreSubset'] === true,
          isPluginCatalog: item['isPluginCatalog'] === true
        })
      }
      this.objectCatalogCategories = categories
      hooks.publishSearchBrowserState()
      const pendingModuleId = hooks.pendingPluginCatalogId()
      if (pendingModuleId.length > 0 && categories.some((item: CatOption) => item.moduleId === pendingModuleId)) {
        hooks.clearPendingPluginCatalogId()
        if (hooks.searchCategory() === 'module:' + pendingModuleId || hooks.categoryModuleId() === pendingModuleId) {
          hooks.loadCategoryObjects('module:' + pendingModuleId, pendingModuleId)
        }
      }
    })
  }

  // 目录健康：桥查询目录健康，跨域共用字段经 hooks setter 回注宿主 / 他 store。
  loadCatalogHealth(): void {
    const hooks = this.hooks
    const port = this.ensurePort()
    if (hooks === null || port === null) {
      return
    }
    port.requestWhenReady('getCatalogHealth', '', (r: StellariumBridgeResponse) => {
      const health = r as CatalogHealthResponse
      hooks.setCatalogHealthLoaded(true)
      hooks.setCatalogManifestPresent(health.manifestPresent === true)
      hooks.setSatelliteCatalogHealth(health.satellites ?? {})
      this.starCatalogHealth = health.stars ?? {}
    })
  }

  // ==== 搜索域分类 chips 的「取值 / 选项」助手 ====
  //
  // 读本 store 的 `objectCatalogCategories`；`searchCategoryLabel` / `categoryObjectIcon`
  // 另需搜索域当前分类，经显式入参传入，避免 store 相互 import。

  // 目录 moduleId → 本地化标签；查不到回退 fallback。
  private catalogLabelForModule(moduleId: string, fallback: ResourceStr): ResourceStr {
    for (const option of this.objectCatalogCategories) {
      if (option.moduleId === moduleId) return option.label
    }
    return fallback
  }

  // 搜索面板内置分类表。
  searchCategoryOptions(): Array<CatOption> {
    const core: CatOption[] = [
      { code: 'planet', label: this.catalogLabelForModule('SolarSystem:planet', I18n.t('i0103')), moduleId: 'SolarSystem:planet', iconKey: 'catalog_planet' },
      { code: 'moon', label: this.catalogLabelForModule('SolarSystem:moon', I18n.objectType('Moon')), moduleId: 'SolarSystem:moon', iconKey: 'catalog_moon' },
      { code: 'comet', label: this.catalogLabelForModule('SolarSystem:comet', I18n.objectType('Comet')), moduleId: 'SolarSystem:comet', iconKey: 'catalog_comet' },
      { code: 'asteroid', label: this.catalogLabelForModule('SolarSystem:asteroid', I18n.objectType('Asteroid')), moduleId: 'SolarSystem:asteroid', iconKey: 'catalog_asteroid' },
      { code: 'star', label: this.catalogLabelForModule('StarMgr', I18n.t('i0104')), moduleId: 'StarMgr', iconKey: 'catalog_star' },
      { code: 'variable', label: this.catalogLabelForModule('StarMgr:1', I18n.objectType('Variable star')), moduleId: 'StarMgr:1', iconKey: 'catalog_variable_star' },
      { code: 'constellation', label: this.catalogLabelForModule('ConstellationMgr', I18n.objectType('Constellation')), moduleId: 'ConstellationMgr', iconKey: 'catalog_constellation' },
      { code: 'galaxy', label: this.catalogLabelForModule('NebulaMgr:0', I18n.objectType('Galaxy')), moduleId: 'NebulaMgr:0', iconKey: 'catalog_galaxy' },
      { code: 'cluster', label: this.catalogLabelForModule('NebulaMgr:5', I18n.objectType('Cluster')), moduleId: 'NebulaMgr:5', iconKey: 'catalog_cluster' },
      { code: 'nebula', label: this.catalogLabelForModule('NebulaMgr:200', I18n.t('i0107')), moduleId: 'NebulaMgr:200', iconKey: 'catalog_nebula' },
      { code: 'messier', label: this.catalogLabelForModule('NebulaMgr:100', I18n.t('i0108')), moduleId: 'NebulaMgr:100', iconKey: 'catalog_messier' },
      { code: 'artificial', label: this.catalogLabelForModule('ArtificialObjects', I18n.t('search_artificial_objects')), moduleId: 'ArtificialObjects', iconKey: 'catalog_satellite' },
      { code: 'satellite', label: this.catalogLabelForModule('Satellites', I18n.objectType('Artificial satellite')), moduleId: 'Satellites', iconKey: 'catalog_satellite' }
    ]
    return core
  }

  // 插件目录动态追加的分类。
  searchDynamicCategoryOptions(): Array<CatOption> {
    const core = this.searchCategoryOptions()
    const knownModules: Record<string, boolean> = {}
    for (const option of core) knownModules[option.moduleId ?? ''] = true
    const dynamic: CatOption[] = []
    for (const option of this.objectCatalogCategories) {
      if (!knownModules[option.moduleId ?? ''] && option.isPluginCatalog === true) dynamic.push(option)
    }
    dynamic.sort((left: CatOption, right: CatOption) => String(left.label).localeCompare(String(right.label)))
    return dynamic
  }

  // 内置 + 动态分类去重合并。
  searchAllCategoryOptions(): Array<CatOption> {
    const result: CatOption[] = []
    const modules: Record<string, boolean> = {}
    for (const option of [...this.searchCategoryOptions(), ...this.searchDynamicCategoryOptions()]) {
      const key = option.moduleId || option.code
      if (!modules[key]) {
        modules[key] = true
        result.push(option)
      }
    }
    return result
  }

  // 分类 code → 图标键。
  searchCategoryIcon(category: string): string {
    for (const option of this.searchCategoryOptions()) {
      if (option.code === category) return option.iconKey ?? 'catalog_plugin'
    }
    for (const option of this.objectCatalogCategories) {
      if (option.code === category) return option.iconKey ?? 'catalog_plugin'
    }
    return 'catalog_plugin'
  }

  // 分类 code → 目录 moduleId。
  categoryModuleIdFor(category: string): string {
    for (const option of this.searchCategoryOptions()) {
      if (option.code === category) return option.moduleId ?? ''
    }
    for (const option of this.objectCatalogCategories) {
      if (option.code === category) return option.moduleId ?? ''
    }
    return ''
  }

  // 当前分类的显示标签（当前分类经显式入参传入）。
  searchCategoryLabel(category: string): string {
    for (const option of this.searchCategoryOptions()) {
      if (option.code === category) return String(option.label)
    }
    for (const option of this.objectCatalogCategories) {
      if (option.code === category) return String(option.label)
    }
    return I18n.t('search_browse_categories')
  }

  // 分类浏览条目的图标（当前分类经显式入参传入）。
  categoryObjectIcon(item: NameItem, category: string): string {
    return catalogIconForObjectType(item.type ?? '', this.searchCategoryIcon(category))
  }
}
