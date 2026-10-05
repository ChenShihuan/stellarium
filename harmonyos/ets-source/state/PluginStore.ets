import { PluginItem } from '../pages/StellariumTypes'

// 插件管理（设置 > 插件管理）列表状态（原宿主 @State，Phase 4m）。
//
// review §2.7：本域原为 "Prop 风格" —— pluginList / pluginListLoading 以 @Prop 快照传入
// SettingsPanel。现改为 @Observed store + 面板 @ObjectLink，列表/加载态变更只重绘插件页。
//
// 刻意留在宿主（非本 store 状态）：宿主私有动作 loadPluginList / updatePluginLoadedItem /
// pluginZh / pluginDesc / pluginMetaLine / pluginFeatureRoute / pluginFeatureDestination /
// pluginFeatureIsActionable / pluginFeatureActionLabel 与 pluginFeatureLoading（瞬时动作串）。
//
// 约束：所有更新必须是"字段整体赋值"。改造前已普查确认 pluginList 只被整体赋值
// （`= list` 与 `= this.pluginList.map(...)`），改动前无 push/splice 等原地变更；
// 改造后 `updatePluginLoadedItem` 仍以 `= this.<store>.pluginList.map(...)` 整体赋值。
@Observed
export class PluginStore {
  pluginList: Array<PluginItem> = []
  pluginListLoading: boolean = false
}
