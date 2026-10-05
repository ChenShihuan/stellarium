// 「视图交互偏好」状态簇（review §2.7）。
//
// 5 个字段全部下沉（原宿主 @State）：自动重置缩放（autoZoomResets）、距离单位
// （useMetricUnits）、锁定视角（viewLock）、竖直限位（verticalClamp）、地平线平直
// （flatHorizon）。它们同属「视图 / 显示交互偏好」，默认在设置面板（configTab 7）、
// 快捷设置（旧版）面板与配置回退面板里成组出现；viewLock 还经宿主以 @Prop 下发给
// 三个壳层内的 UnifiedObjectDetailCard。
//
// 为什么 flatHorizon 不并入 OverlayStore：OverlayStore 的既定范围是叠层 / 坐标 / 指向线，
// 而 flatHorizon 与 verticalClamp / viewLock 一样由 syncBridgeFlagState() 统一写回，
// 语义同属「视图限位 / 交互」，故并入本 store。
//
// 动作（setDistanceUnit / setViewLockState / syncBridgeFlagState / setNavigationBoolean
// 内的 autoZoomResets 分支）与桥调用留在宿主（§13.1 规则 6），组件只读字段。
//
// 2026-10-04 追加两字段（review §2.7 残留并入）：
//   - configDitheringMode —— 抖动/渲染质量档（Color888…），SettingsPanel 经既有 @ObjectLink 消费；
//   - liveMode —— 实时模式开关显示值，SettingsQuickLegacyPanel 经 @Prop 快照消费。
//   二者消费方都已持有本 store，故并入而不新建。
//
// 2026-10-04 追加一字段（review §2.7 残留并入）：
//   - uiLocked —— 界面锁定标志，门控面板关闭与空闲淡出（`closePanel` / `handleUiTap` 关闭按钮 /
//     `resetPanelIdle`）。属"视图交互锁定"，与 `viewLock`（锁定视图中心）同域，故并入本 store 而不新建。
//
// 约束：均为标量，只做整体赋值，无原地变更。
//
// 2026-10-05（解散 capability/SettingsController.ets）：四个设置动作按「写本域 store 字段 → 并入
// 该 store 方法」下沉 —— setConfigurationDithering / setDistanceUnit 写 configDitheringMode /
// useMetricUnits（失败回滚经 hooks 调 timeSettingsStore.loadConfigurationSettings）；setFovMarkerSetting
// 为薄桥；setProjection 回包后写宿主 @State currentProjection（经 hook）。桥经 CommandPort。
import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import { I18n } from '../pages/I18n'
import { CommandPort } from '../bridge/CommandPort'

// 宿主 → ViewSettingsStore 回注（§13.1 规则 6 / §15.7 规则 4）。
export interface ViewSettingsHostHooks {
  flashHint(text: ResourceStr): void
  // 宿主 @State currentProjection（setProjection 回包成功后写；StartupBridge 亦经宿主写）。
  setCurrentProjection(name: string): void
  // 跨 store 回滚：timeSettingsStore.loadConfigurationSettings()（抖动 / 距离单位失败分支）。
  reloadConfigurationSettings(): void
  // setProjectionType 被拒时的 hilog（store 不 import @ohos.hilog，§15.7 规则 1）。
  logProjectionError(name: string, error: string): void
}

@Observed
export class ViewSettingsStore {
  autoZoomResets: boolean = false
  useMetricUnits: boolean = true
  viewLock: boolean = false
  verticalClamp: boolean = true
  flatHorizon: boolean = true
  configDitheringMode: string = 'Color888'
  liveMode: boolean = true
  uiLocked: boolean = false

  // —— 桥 / 宿主回注（§14.1 AB-0；2026-10-05 随显示设置动作并入） ——
  private port: CommandPort | null = null
  private hooks: ViewSettingsHostHooks | null = null

  attachPort(port: CommandPort): void {
    this.port = port
  }

  attachHooks(hooks: ViewSettingsHostHooks): void {
    this.hooks = hooks
  }

  private ensurePort(): CommandPort | null {
    return this.port
  }

  // 抖动 / 渲染质量档写回（原 SettingsController.setConfigurationDithering，函数体逐字搬入；
  // 差异仅 this.viewSettingsStore.<f> → this.<f>、rollback → hooks.reloadConfigurationSettings）。
  setConfigurationDithering(value: string): void {
    const port = this.ensurePort()
    const hooks = this.hooks
    if (port === null || hooks === null) {
      return
    }
    port.requestInteractive('setDitheringMode', value.toLowerCase(), (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.configDitheringMode = value
        hooks.flashHint('渲染质量已更新')
      } else {
        hooks.flashHint(r.error ?? I18n.t('msg_apply_failed'))
        hooks.reloadConfigurationSettings()
      }
    })
  }

  // 距离单位写回（原 SettingsController.setDistanceUnit，函数体逐字搬入）。
  setDistanceUnit(useMetric: boolean): void {
    const port = this.ensurePort()
    const hooks = this.hooks
    if (port === null || hooks === null) {
      return
    }
    port.requestInteractive('setConfigString', 'astronomy/flag_use_km_for_distance=' + (useMetric ? 'true' : 'false'), (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.useMetricUnits = useMetric
      } else {
        hooks.flashHint(r.error ?? I18n.t('msg_apply_failed'))
        hooks.reloadConfigurationSettings()
      }
    })
  }

  // 视场标记设置（原 SettingsController.setFovMarkerSetting，薄桥）。
  setFovMarkerSetting(setting: string, value: number): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    port.requestInteractive('setFovMarkerSetting', setting + '|' + value.toFixed(1), () => {})
  }

  // 投影方式写回（原 SettingsController.setProjection）：回包成功后写宿主 @State（经 hooks）并提示。
  setProjection(name: string): void {
    const port = this.ensurePort()
    const hooks = this.hooks
    if (port === null || hooks === null) {
      return
    }
    port.requestInteractive('setProjectionType', name, (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        hooks.setCurrentProjection(name)
        hooks.flashHint(I18n.projectionName(name))
      } else {
        hooks.logProjectionError(name, r.error ?? '')
        hooks.flashHint(I18n.t('msg_apply_failed'))
      }
    })
  }
}
