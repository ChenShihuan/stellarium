// 「视图导航」设置页（设置 > 视图导航，configTab 7）的状态簇（review §2.7）。
//
// 本域 9 个字段全部下沉（原宿主 @State）：鼠标导航 / 鼠标缩放 / 键盘导航 / 键盘缩放 /
// 重力标签，以及启动视场（FOV）、启动朝向（方位角 / 高度角）与最大视场角。均为持久化设置；
// 读写在 loadConfigurationSettings() / setNavigationBoolean() / setNavigationMaxFov()
// 与 SettingsPanel 之间。消费面板只有 SettingsPanel（9 个 @Prop → 1 个 @ObjectLink）。
//
// 刻意留在宿主（非本 store 状态）：
//   - `maxFovDraft`（最大视场角滑块草稿）是 SettingsPanel 的本地 @State，随面板存在，不下沉；
//   - `saveCurrentViewAsStartup()` / `saveAllCoreSettings()` / `restoreCoreDefaults()` 等动作
//     与桥调用留在宿主，按 §13.1 规则 6 回注。
//
// 约束：均为标量，只做整体赋值，无原地变更（改造前已普查 `this.<field>.push|splice|...` 为 0）。
//
// 2026-10-05（解散 capability/SettingsController.ets）：导航开关 / 最大 FOV 两个桥动作按「写本域
// store 字段 → 并入该 store 方法」下沉（原 SettingsController.setNavigationBoolean / setNavigationMaxFov）。
// 桥经 CommandPort；autoZoomResets 分支写 ViewSettingsStore、UI 提示经 NavigationSettingsHostHooks
// 具名回注宿主（store 不 import 他 store / UI）。
import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import { I18n } from '../pages/I18n'
import { CommandPort } from '../bridge/CommandPort'

// 宿主 → NavigationSettingsStore 回注（§13.1 规则 6 / §15.7 规则 4）。
export interface NavigationSettingsHostHooks {
  flashHint(text: ResourceStr): void
  // ViewSettingsStore.autoZoomResets（setNavigationBoolean 的 autoZoomResets 分支）。
  setAutoZoomResets(value: boolean): void
}

@Observed
export class NavigationSettingsStore {
  navigationMouseEnabled: boolean = true
  navigationMouseZoomEnabled: boolean = true
  navigationMoveKeysEnabled: boolean = true
  navigationZoomKeysEnabled: boolean = true
  navigationGravityLabelsEnabled: boolean = false
  navigationStartupFov: number = 60
  navigationStartupAzimuth: number = 0
  navigationStartupAltitude: number = 45
  navigationMaxFov: number = 180

  // —— 桥 / 宿主回注（§14.1 AB-0；2026-10-05 随导航设置动作并入） ——
  private port: CommandPort | null = null
  private hooks: NavigationSettingsHostHooks | null = null

  // 宿主在 aboutToAppear 注入端口；字段赋值即驱动宿主重绘（store 无 publish* 发布点）。
  attachPort(port: CommandPort): void {
    this.port = port
  }

  attachHooks(hooks: NavigationSettingsHostHooks): void {
    this.hooks = hooks
  }

  private ensurePort(): CommandPort | null {
    return this.port
  }

  // 导航布尔设置写回（原 SettingsController.setNavigationBoolean，函数体逐字搬入；差异仅
  // this.navigationStore.<f> → this.<f>、this.viewSettingsStore.autoZoomResets → hooks.setAutoZoomResets、
  // 提示经 hooks.flashHint、桥经 port）。
  setNavigationBoolean(setting: string, enabled: boolean): void {
    const port = this.ensurePort()
    const hooks = this.hooks
    if (port === null || hooks === null) {
      return
    }
    port.requestInteractive('setNavigationSetting', setting + '|' + (enabled ? '1' : '0'), (r: StellariumBridgeResponse) => {
      if (r.ok !== true) {
        hooks.flashHint(I18n.t('msg_apply_failed'))
        return
      }
      if (setting === 'mouseNavigation') this.navigationMouseEnabled = enabled
      else if (setting === 'mouseZooming') this.navigationMouseZoomEnabled = enabled
      else if (setting === 'moveKeys') this.navigationMoveKeysEnabled = enabled
      else if (setting === 'zoomKeys') this.navigationZoomKeysEnabled = enabled
      else if (setting === 'gravityLabels') this.navigationGravityLabelsEnabled = enabled
      else if (setting === 'autoZoomResets') hooks.setAutoZoomResets(enabled)
    })
  }

  // 最大视场角（原 SettingsController.setNavigationMaxFov，函数体逐字搬入）。
  setNavigationMaxFov(value: number): void {
    const port = this.ensurePort()
    const hooks = this.hooks
    if (port === null || hooks === null) {
      return
    }
    const maxFov = Math.max(1, Math.min(360, Math.round(value)))
    port.requestInteractive('setNavigationSetting', 'maxFov|' + maxFov.toString(), (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.navigationMaxFov = maxFov
        hooks.flashHint(I18n.t('settings_view_max_fov_updated'))
      } else {
        hooks.flashHint(I18n.t('msg_apply_failed'))
      }
    })
  }
}
