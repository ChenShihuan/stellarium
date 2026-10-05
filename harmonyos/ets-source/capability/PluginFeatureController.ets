// 插件功能行为控制器（STATE-REVIEW §10.2 D14，PLAN §15 D 轨道 D14）。
//
// 原宿主 MainWindowNativeNode 的插件功能动作逐字下沉：
//   ensurePluginLoaded / updatePluginLoadedItem / pluginMetaLine / pluginFeatureDestination /
//   pluginFeatureIsActionable / pluginFeatureActionLabel / openPluginFeature / openPluginFeatureAfterLoad。
//
// STATE-REVIEW §10.1 记「10 法」；工作区实测为 8 个行为法（插件列表的 pluginZh / pluginDesc /
// pluginFeatureRoute 是 common/derive/labels 的纯函数，不属行为层）：
//   - `pluginFeatureDestination` / `pluginFeatureIsActionable` / `pluginFeatureActionLabel` /
//     `pluginMetaLine` 为纯函数（只读 I18n 与 derive labels），随控制器。
//   - `openPluginFeatureAfterLoad` 原判定「写 astroStore.astroTab/graphMode + searchStore +
//     openSubPanel（跨域路由）」；实测可逐字等价下沉——astroStore/searchStore 直接注入，
//     viewTab（宿主 @State）与 openSubPanel（壳层路由）经 hooks 回注，故一并迁入（非登记保留）。
//   - 原 `ensurePluginLoaded` 的两处 hilog 诊断日志（'Plugin feature load already pending: ' /
//     'Auto-loading plugin: '）按 §15.7 规则 1（控制器不 import NAPI）**不再保留**，行为其余逐字等价。
//
// **不 import NAPI/UI**（§15.7 规则 1）：桥经 CommandPort；跨域读（activePanel + 目录/语言 store）
// 与壳层路由经 PluginFeatureHostHooks 具名回注（§13.1 规则 6）。
import { I18n } from '../pages/I18n'
import { StellariumBridgeResponse, PluginItem } from '../pages/StellariumTypes'
import { PluginFeatureRoute } from '../pages/MainWindowModels'
import { CommandPort } from '../bridge/CommandPort'
import { PluginStore } from '../state/PluginStore'
import { SearchStore } from '../state/SearchStore'
import { AstroStore } from '../state/AstroStore'
import { pluginZh, pluginHostName, pluginFeatureRoute } from '../common/derive/labels'
import { BehaviorHostHooks } from './ControllerHooks'

// 宿主 → 控制器回注（§13.1 规则 6）：跨域读与壳层路由。
export interface PluginFeatureHostHooks extends BehaviorHostHooks {
  // 插件加载成功后，若搜索面板可见则刷新对象目录 chips（宿主读 activePanel + catalogStore + languageStore）。
  refreshCatalogCategoriesIfSearchVisible(): void
  // 视图标签页宿主 @State（组件 @Prop 消费，控制器经 hooks 写，§15.7 规则 2）。
  setViewTab(value: number): void
  // 壳层路由（§15.6-4）：打开路由 panel。
  openSubPanel(panel: string): void
}

export class PluginFeatureController {
  private port: CommandPort
  private pluginStore: PluginStore
  private searchStore: SearchStore
  private astroStore: AstroStore
  private hooks: PluginFeatureHostHooks
  // 瞬时动作串：正在加载的插件 id（不入 @Observed store）。
  private pluginFeatureLoading: string[] = []

  constructor(
    port: CommandPort,
    pluginStore: PluginStore,
    searchStore: SearchStore,
    astroStore: AstroStore,
    hooks: PluginFeatureHostHooks
  ) {
    this.port = port
    this.pluginStore = pluginStore
    this.searchStore = searchStore
    this.astroStore = astroStore
    this.hooks = hooks
  }

  // 原宿主 ensurePluginLoaded()：确保插件已加载，未加载时先 loadPlugin 再回调。
  ensurePluginLoaded(pluginName: string, callback: () => void, failureCallback?: () => void): void {
    if (this.pluginFeatureLoading.indexOf(pluginName) >= 0) {
      return
    }
    this.pluginFeatureLoading = this.pluginFeatureLoading.concat([pluginName])
    const finish = (): void => {
      this.pluginFeatureLoading = this.pluginFeatureLoading.filter((id: string) => id !== pluginName)
    }
    this.port.requestWhenReady('getPluginList', '', (r: StellariumBridgeResponse) => {
      const items = r.items as Array<PluginItem> | undefined
      let loaded = false
      if (items) {
        for (let index = 0; index < items.length; index++) {
          if (items[index].id === pluginName && items[index].loaded) {
            loaded = true
            break
          }
        }
      }
      if (loaded) {
        finish()
        callback()
      } else {
        this.port.requestInteractive('loadPlugin', pluginName, (loadResult: StellariumBridgeResponse) => {
          finish()
          if (loadResult.ok === true) {
            this.updatePluginLoadedItem(pluginName, true)
            // Loading a feature plugin must not rebuild unrelated panels. The
            // catalog chips only need refreshing while the search panel is
            // visible; doing it for every plugin caused a full-shell flash.
            this.hooks.refreshCatalogCategoriesIfSearchVisible()
            callback()
          }
          else {
            this.hooks.flashHint(I18n.t('plugin_load_failed'))
            if (failureCallback !== undefined) failureCallback()
          }
        }, () => {
          finish()
          this.hooks.flashHint(I18n.t('plugin_load_failed'))
          if (failureCallback !== undefined) failureCallback()
        })
      }
    }, () => {
      finish()
      if (failureCallback !== undefined) failureCallback()
    }, 0, 100, 15)
  }

  // 原宿主 updatePluginLoadedItem()：把插件列表项的 loaded 标记整体重赋值。
  updatePluginLoadedItem(id: string, loaded: boolean): void {
    this.pluginStore.pluginList = this.pluginStore.pluginList.map((item: PluginItem) => {
      if (item.id !== id) return item
      return {
        id: item.id,
        name: item.name,
        loaded: loaded,
        loadAtStartup: item.loadAtStartup,
        description: item.description,
        authors: item.authors,
        contact: item.contact,
        version: item.version,
        license: item.license,
        acknowledgements: item.acknowledgements,
        hasPreviewImage: item.hasPreviewImage,
        source: item.source
      }
    })
  }

  // 原宿主 pluginMetaLine()：插件列表的版本 / 联系人 / 致谢 / 来源摘要行。
  pluginMetaLine(plugin: PluginItem): string {
    const values: string[] = []
    if (plugin.version && plugin.version.trim().length > 0) { values.push(I18n.t('resource_version') + ': ' + plugin.version.trim()) }
    if (plugin.contact && plugin.contact.trim().length > 0) { values.push(I18n.t('resource_contact') + ': ' + plugin.contact.trim()) }
    if (plugin.acknowledgements && plugin.acknowledgements.trim().length > 0) { values.push(I18n.t('resource_acknowledgements') + ': ' + plugin.acknowledgements.trim()) }
    if (plugin.source && plugin.source.trim().length > 0) { values.push(I18n.t('resource_source') + ': ' + plugin.source.trim()) }
    return values.join(' · ')
  }

  // 原宿主 pluginFeatureDestination()：插件功能的目标面板描述。
  pluginFeatureDestination(id: string): string {
    const route = pluginFeatureRoute(id)
    if (route.kind === 'control') return I18n.format('plugin_destination_control', [pluginHostName(route.panel)])
    if (route.kind === 'catalog') return I18n.format('plugin_destination_catalog', [pluginZh(id)])
    if (route.kind === 'host') {
      let destination = pluginHostName(route.panel)
      if (id === 'ObjectVisibility') destination += ' > ' + pluginZh('Observability')
      else destination += ' > ' + pluginZh(id)
      return I18n.format('plugin_destination_host', [destination])
    }
    if (route.kind === 'network') return I18n.t('plugin_network_disabled')
    if (route.kind === 'offline') return I18n.t('plugin_offline_disabled')
    return I18n.t('plugin_no_arkui_panel')
  }

  // 原宿主 pluginFeatureIsActionable()：插件功能是否可点开。
  pluginFeatureIsActionable(id: string): boolean {
    const kind = pluginFeatureRoute(id).kind
    return kind === 'control' || kind === 'catalog' || kind === 'host'
  }

  // 原宿主 pluginFeatureActionLabel()：插件功能按钮文案。
  pluginFeatureActionLabel(id: string): string {
    return pluginFeatureRoute(id).kind === 'catalog'
      ? I18n.t('plugin_open_catalog')
      : I18n.t('plugin_open_feature')
  }

  // 原宿主 openPluginFeature()：插件功能入口（离线 / 无面板直接提示，TelescopeControl 免加载）。
  openPluginFeature(id: string): void {
    const route = pluginFeatureRoute(id)
    if (route.kind === 'offline') {
      this.hooks.flashHint(I18n.t('plugin_offline_disabled'))
      return
    }
    if (route.kind === 'unavailable' || route.panel.length === 0) {
      this.hooks.flashHint(I18n.t('plugin_no_arkui_panel'))
      return
    }
    if (id === 'TelescopeControl') {
      this.openPluginFeatureAfterLoad(id, route)
      return
    }
    this.ensurePluginLoaded(id, () => { this.openPluginFeatureAfterLoad(id, route) }, () => {
      this.hooks.flashHint(I18n.t('plugin_load_failed'))
    })
  }

  // 原宿主 openPluginFeatureAfterLoad()：插件已加载后按路由写 astro/search 状态并打开面板。
  openPluginFeatureAfterLoad(id: string, route: PluginFeatureRoute): void {
    if (route.astroTab !== undefined) this.astroStore.astroTab = route.astroTab
    if (route.graphMode !== undefined) this.astroStore.graphMode = route.graphMode
    if (route.layerTab !== undefined) this.hooks.setViewTab(route.layerTab)
    if (route.catalogModuleId !== undefined) {
      this.searchStore.searchText = ''
      this.searchStore.searchCategory = 'module:' + route.catalogModuleId
      this.searchStore.loadCategoryObjects(this.searchStore.searchCategory, route.catalogModuleId)
      this.searchStore.pendingPluginCatalogId = route.catalogModuleId
    }
    this.hooks.openSubPanel(route.panel)
  }
}
