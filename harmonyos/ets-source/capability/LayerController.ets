// 图层 / 视图标签行为控制器（STATE-REVIEW §10.2 D2，PLAN §15 D 轨道 D2）。
//
// 原宿主 MainWindowNativeNode 的 10 个方法逐字下沉：
//   setLayer / applyLayerSwitch / layerTabItems / markingLayerStates / layerPresetStates /
//   applyLayerStates / clearMarkingLayers / applyLayerPreset / selectViewTab / selectConfigTab。
// 私有字段 viewTabTransitionId / configTabTransitionId 随控制器（标签切换去重序号，不入 @Observed store）。
//
// 职责划分（§15.7 规则 2）：
//   - LayerViewStore 的地景加载器（loadLandscapeList）与 ScriptStore/PluginStore 的标签页数据加载
//     直接调用（本体是 store 的自持加载器）；
//   - 图层开关布尔值仍在 LayerStore、由宿主 refreshState 从引擎回填，控制器不写（故不注入 LayerStore / OverlayStore）；
//   - viewTab / configTab 与两组过渡量（内容透明度 / 水平偏移）是宿主 @State、组件经 @Prop 消费，
//     留宿主、经 hooks get/set；
//   - 标签切换动画（宿主 getUIContext().animateTo）归宿主，经 animateTabIn / animateTabOut 回注。
//
// **不 import NAPI/UI**（§15.7 规则 1）：桥经 CommandPort；跨域回调经 LayerHostHooks 具名回注（§13.1 规则 6）。
import hilog from '@ohos.hilog'
import { I18n } from '../pages/I18n'
import { StellariumBridgeResponse, TabItem } from '../pages/StellariumTypes'
import { LayerPresetState, MARKING_LAYER_ACTION_IDS, CONTENT_LAYER_ACTION_IDS, OFFLINE_APPGALLERY_BUILD } from '../pages/MainWindowModels'
import { CommandPort } from '../bridge/CommandPort'
import { LayerViewStore } from '../state/LayerViewStore'
import { ScriptStore } from '../state/ScriptStore'
import { PluginStore } from '../state/PluginStore'
import { BehaviorHostHooks } from './ControllerHooks'

// 宿主 → 控制器回注（§13.1 规则 6）：图层开关分派、持久化、标签切换动画与宿主 @State 读写。
export interface LayerHostHooks extends BehaviorHostHooks {
  // 图层开关分派（宿主保留 setSkyDisplaySetting / setBridgeFlag，二者发不同桥命令）。
  setSkyDisplaySetting(actionId: string, value: boolean): void
  setBridgeFlag(cmd: string, value: boolean): void
  // 持久化（跨 store / AppStorage：赤道仪开关归 TelescopeStore；夜视归 NightModeStore 的 D16 方法）。
  persistEquatorialMount(): void
  persistNightMode(): void
  // 星空文化「时间跟随」定时器收口（宿主保留）。
  syncSkyCultureTimeFollowTimer(): void
  // 视图标签页宿主 @State（组件 @Prop 消费，控制器经 hooks 读写，§15.7 规则 2）。
  viewTab(): number
  setViewTab(value: number): void
  viewTabContentOpacity(): number
  setViewTabContentOpacity(value: number): void
  viewTabContentOffsetX(): number
  setViewTabContentOffsetX(value: number): void
  // 设置标签页宿主 @State。
  configTab(): number
  setConfigTab(value: number): void
  configTabContentOpacity(): number
  setConfigTabContentOpacity(value: number): void
  configTabContentOffsetX(): number
  setConfigTabContentOffsetX(value: number): void
  // 标签切换动画（宿主 getUIContext().animateTo 归宿主；curve 由宿主按原调用点固定）。
  animateTabIn(durationMs: number, onFinish: () => void, action: () => void): void
  animateTabOut(durationMs: number, action: () => void): void
}

export class LayerController {
  private port: CommandPort
  private layerViewStore: LayerViewStore
  private scriptStore: ScriptStore
  private pluginStore: PluginStore
  private hooks: LayerHostHooks
  // 标签切换去重序号：草稿字段随控制器走（§15.7 规则 2，不入 @Observed store）。
  private viewTabTransitionId: number = 0
  private configTabTransitionId: number = 0

  constructor(
    port: CommandPort,
    layerViewStore: LayerViewStore,
    scriptStore: ScriptStore,
    pluginStore: PluginStore,
    hooks: LayerHostHooks
  ) {
    this.port = port
    this.layerViewStore = layerViewStore
    this.scriptStore = scriptStore
    this.pluginStore = pluginStore
    this.hooks = hooks
  }

  // 原宿主 setLayer()：桥写单个 action 勾选态，回包后刷新状态；夜视 / 赤道仪开关立即持久化。
  private setLayer(actionId: string, enabled: boolean): void {
    hilog.info(0x0000, 'StellariumArkUI', 'setLayer send %{public}s|%{public}s', actionId, enabled ? '1' : '0')
    this.port.requestInteractive('setActionChecked', actionId + '|' + (enabled ? '1' : '0'), (r: StellariumBridgeResponse) => {
      hilog.info(0x0000, 'StellariumArkUI', 'setLayer %{public}s ok=%{public}s err=%{public}s', actionId, r.ok === true ? '1' : '0', r.error ?? '')
      this.hooks.refreshState()
      // 夜间模式和赤道仪模式切换时立即持久化，避免应用被杀死后丢失
      if (actionId === 'actionShow_Night_Mode') { this.hooks.persistNightMode() }
      if (actionId === 'actionSwitch_Equatorial_Mount') { this.hooks.persistEquatorialMount() }
    })
  }

  // 原宿主 applyLayerSwitch()：图层开关的统一写回（与原 @Builder switchRow 的 onChange 分派逐字等价）。
  applyLayerSwitch(actionId: string, cmd: string, value: boolean): void {
    if (cmd.length > 0) {
      if (cmd.indexOf('setSkyDisplay') === 0) {
        this.hooks.setSkyDisplaySetting(actionId, value)
      } else {
        this.hooks.setBridgeFlag(cmd, value)
      }
    } else {
      this.setLayer(actionId, value)
    }
    this.hooks.flashHint(I18n.t(value ? 'msg_shown' : 'msg_hidden'))
  }

  // 原宿主 layerTabItems()：视图标签页清单（离线 AppGallery 构建隐藏第 7 页）。
  layerTabItems(): TabItem[] {
    const tabs: TabItem[] = [
      { label: I18n.t('v0000'), id: 0 },
      { label: I18n.t('v0001'), id: 1 },
      { label: I18n.t('v0002'), id: 2 },
      { label: I18n.t('v0003'), id: 3 },
      { label: I18n.t('v0004'), id: 4 },
      { label: I18n.t('v0005'), id: 5 }
    ]
    if (!OFFLINE_APPGALLERY_BUILD) {
      tabs.push({ label: I18n.t('v0006'), id: 6 })
    }
    return tabs
  }

  private markingLayerStates(enabled: boolean): Array<LayerPresetState> {
    const states: Array<LayerPresetState> = []
    for (const actionId of MARKING_LAYER_ACTION_IDS) {
      states.push({ id: actionId, enabled: enabled })
    }
    return states
  }

  private layerPresetStates(enabled: boolean): Array<LayerPresetState> {
    const states = this.markingLayerStates(enabled)
    for (const actionId of CONTENT_LAYER_ACTION_IDS) {
      states.push({ id: actionId, enabled: enabled })
    }
    return states
  }

  private applyLayerStates(states: Array<LayerPresetState>, successMessage: string): void {
    this.port.requestInteractive('setActionStates', JSON.stringify(states), (response: StellariumBridgeResponse) => {
      if (response.ok === true) {
        this.hooks.refreshState()
        this.hooks.flashHint(successMessage)
      } else {
        this.hooks.flashHint('图层设置未能应用，请重试。')
      }
    })
  }

  // 原宿主 clearMarkingLayers()：清空全部坐标与标记图层。
  clearMarkingLayers(): void {
    this.applyLayerStates(this.markingLayerStates(false), '已清除全部坐标与标记。')
  }

  // 原宿主 applyLayerPreset()：三种预设（纯净 / 观测 / 摄影）的图层组合。
  applyLayerPreset(preset: string): void {
    let states: Array<LayerPresetState> = this.layerPresetStates(false)
    if (preset === 'clean') {
      states.push(
        { id: 'actionShow_Stars', enabled: true }, { id: 'actionShow_Stars_Labels', enabled: false },
        { id: 'actionShow_Planets', enabled: true }, { id: 'actionShow_Planets_Labels', enabled: false },
        { id: 'actionShow_Planets_Hints', enabled: false },
        { id: 'actionShow_Nebulas', enabled: true }, { id: 'actionShow_MilkyWay', enabled: true },
        { id: 'actionShow_Constellation_Lines', enabled: false }, { id: 'actionShow_Constellation_Labels', enabled: false },
        { id: 'actionShow_Constellation_Boundaries', enabled: false }, { id: 'actionShow_Constellation_Art', enabled: false },
        { id: 'actionShow_Atmosphere', enabled: true }, { id: 'actionShow_Ground', enabled: true }
      )
    } else if (preset === 'observe') {
      states.push(
        { id: 'actionShow_Stars', enabled: true }, { id: 'actionShow_Stars_Labels', enabled: true },
        { id: 'actionShow_Planets', enabled: true }, { id: 'actionShow_Planets_Labels', enabled: true },
        { id: 'actionShow_Planets_Hints', enabled: true }, { id: 'actionShow_Planets_Orbits', enabled: true },
        { id: 'actionShow_Nebulas', enabled: true }, { id: 'actionShow_DSO_Textures', enabled: true },
        { id: 'actionShow_MilkyWay', enabled: true }, { id: 'actionShow_Constellation_Lines', enabled: true },
        { id: 'actionShow_Constellation_Labels', enabled: true }, { id: 'actionShow_Constellation_Boundaries', enabled: false },
        { id: 'actionShow_Constellation_Art', enabled: false }, { id: 'actionShow_Atmosphere', enabled: false },
        { id: 'actionShow_Ground', enabled: false }, { id: 'actionShow_Fog', enabled: false },
        { id: 'actionShow_Cardinal_Points', enabled: true }, { id: 'actionShow_Equatorial_Grid', enabled: true },
        { id: 'actionShow_Ecliptic_Line', enabled: true }, { id: 'actionShow_Meridian_Line', enabled: true },
        { id: 'actionShow_Horizon_Line', enabled: true }, { id: 'actionShow_FOV_Center_Marker', enabled: true }
      )
    } else {
      states.push(
        { id: 'actionShow_Stars', enabled: true }, { id: 'actionShow_Stars_Labels', enabled: false },
        { id: 'actionShow_Planets', enabled: false }, { id: 'actionShow_Planets_Labels', enabled: false },
        { id: 'actionShow_Planets_Hints', enabled: false },
        { id: 'actionShow_Nebulas', enabled: true }, { id: 'actionShow_MilkyWay', enabled: true },
        { id: 'actionShow_Constellation_Lines', enabled: false }, { id: 'actionShow_Constellation_Labels', enabled: false },
        { id: 'actionShow_Constellation_Boundaries', enabled: false }, { id: 'actionShow_Constellation_Art', enabled: false },
        { id: 'actionShow_Atmosphere', enabled: false }, { id: 'actionShow_Ground', enabled: false }
      )
    }
    this.applyLayerStates(states, preset === 'clean' ? '已应用纯净星空图层。' : (preset === 'observe' ? '已应用观测辅助图层。' : '已应用摄影构图图层。'))
  }

  // 原宿主 selectViewTab()：视图标签切换（两段 animateTo 时序逐字保留；动画本体归宿主）。
  selectViewTab(tabId: number): void {
    if (tabId === this.hooks.viewTab()) return
    const direction = tabId > this.hooks.viewTab() ? 1 : -1
    const transitionId = ++this.viewTabTransitionId
    hilog.info(0x0000, 'StellariumArkUI', '[layer-transition] begin id=%{public}d from=%{public}d to=%{public}d', transitionId, this.hooks.viewTab(), tabId)
    this.hooks.animateTabIn(100, (): void => {
      if (transitionId !== this.viewTabTransitionId) return
      this.hooks.setViewTab(tabId)
      if (tabId === 4) this.layerViewStore.loadLandscapeList()
      this.hooks.setViewTabContentOffsetX(direction * 10)
      hilog.info(0x0000, 'StellariumArkUI', '[layer-transition] swap id=%{public}d tab=%{public}d', transitionId, tabId)
      this.hooks.animateTabOut(170, (): void => {
        if (transitionId !== this.viewTabTransitionId) return
        this.hooks.setViewTabContentOpacity(1)
        this.hooks.setViewTabContentOffsetX(0)
        this.hooks.syncSkyCultureTimeFollowTimer()
        hilog.info(0x0000, 'StellariumArkUI', '[layer-transition] finish id=%{public}d tab=%{public}d', transitionId, tabId)
      })
    }, (): void => {
      this.hooks.setViewTabContentOpacity(0)
      this.hooks.setViewTabContentOffsetX((0 - direction) * 8)
    })
  }

  // 原宿主 selectConfigTab()：设置标签切换（同上；第 6/7 页触发脚本 / 插件数据加载）。
  selectConfigTab(tabId: number): void {
    if (tabId === this.hooks.configTab()) return
    const direction = tabId > this.hooks.configTab() ? 1 : -1
    const transitionId = ++this.configTabTransitionId
    hilog.info(0x0000, 'StellariumArkUI', '[settings-transition] begin id=%{public}d from=%{public}d to=%{public}d', transitionId, this.hooks.configTab(), tabId)
    this.hooks.animateTabIn(90, (): void => {
      if (transitionId !== this.configTabTransitionId) return
      this.hooks.setConfigTab(tabId)
      this.hooks.setConfigTabContentOffsetX(direction * 8)
      if (tabId === 5) {
        this.scriptStore.loadScriptList()
        this.scriptStore.loadRecordings()
        this.scriptStore.loadVideoRecordingState()
      } else if (tabId === 6) {
        this.pluginStore.loadPluginList()
      }
      hilog.info(0x0000, 'StellariumArkUI', '[settings-transition] swap id=%{public}d tab=%{public}d', transitionId, tabId)
      this.hooks.animateTabOut(170, (): void => {
        if (transitionId !== this.configTabTransitionId) return
        this.hooks.setConfigTabContentOpacity(1)
        this.hooks.setConfigTabContentOffsetX(0)
        hilog.info(0x0000, 'StellariumArkUI', '[settings-transition] finish id=%{public}d tab=%{public}d', transitionId, tabId)
      })
    }, (): void => {
      if (transitionId !== this.configTabTransitionId) return
      this.hooks.setConfigTabContentOpacity(0)
      this.hooks.setConfigTabContentOffsetX((0 - direction) * 8)
    })
  }
}
