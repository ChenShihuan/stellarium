// 夜视模式（红光）状态 —— 独立模块。
//
// 为什么单独一份 store：夜视模式是**全局视觉模式**，后续要在主界面添加独立按钮，
// 因此它的状态必须能被宿主之外的组件共享（`NightModeToggleRow` 与未来的主界面按钮）。
// 宿主以 @State 持有本 store，`nm*()` 系列配色方法读 `this.nightModeStore.nightMode`；
// 组件以 @ObjectLink 订阅同一实例。
//
// 注：原先还存在一个只被时间面板一行读取的镜像字段 `nightModeOn`，已随本次拆分删除，
// 使"真源"只剩一个（避免双写不同步）。
@Observed
export class NightModeStore {
  nightMode: boolean = false
}
