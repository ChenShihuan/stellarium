// 底部 Dock 的"实时激活态"（只放数据，不含 UI / NAPI）。
//
// 背景（2026-10-02）：Dock 入口用 `ForEach` 渲染，键值生成函数对**未变键**的数组项
// 不会重新执行 itemGenerator，因此把 `active` 作为 @Prop 直接传进子项会在复用后冻结；
// 而把激活态并入键值又会让子项销毁重建（动画被打断，入口视觉抖动）。
// 正确做法：同一 `@Observed` 实例经 @ObjectLink 注入每个入口，激活态变化时入口只
// 重渲染、不重建（V1 深观察），键值保持稳定。
@Observed
export class DockStore {
  activePanel: string = ''
  panelVisible: boolean = false
}
