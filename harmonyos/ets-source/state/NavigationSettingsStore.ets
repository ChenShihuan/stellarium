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
}
