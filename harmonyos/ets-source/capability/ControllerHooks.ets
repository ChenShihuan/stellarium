// 行为控制器共享宿主 hook（D0 前置，STATE-REVIEW §10.3）。
//
// 背景：D 轨道的 D4/D5/D8/D10 等簇均因调 `refreshState()` 或写 `activePanel`/`panelVisible`
// 而受阻。解法是在 D 轨道前置切片 D0 建立三个具名宿主回调，控制器经此回调宿主，
// **不 import 宿主**（§13.1 规则 6）。
//
// 本文件是**纯接口**：不 import NAPI / UI / 宿主。后续控制器接口可 `extends BehaviorHostHooks`，
// 例如 capability/DetailConnectorController.ets 的 `DetailConnectorHostHooks`。
export interface BehaviorHostHooks {
  // 宿主 refreshState()（生命周期收口，§15.6 保留）。
  refreshState(): void
  // 宿主 flashHint()（UI 提示）。
  flashHint(text: ResourceStr): void
  // 面板路由：宿主 activePanel / panelVisible 写入 + Dock 时钟收口
  //（STATE-REVIEW §10.3 第 2 条：宿主传 `() => { this.activePanel = panel; this.panelVisible = visible; this.syncDockClockTimer() }`）。
  panelChange(panel: string, visible: boolean): void
}
