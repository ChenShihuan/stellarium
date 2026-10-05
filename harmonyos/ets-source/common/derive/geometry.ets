// 几何 / 触摸 / 布局常量纯函数。
// 依据计划 §14.2 轨道 A1-6，逐字从 pages/MainWindowNativeNode.ets 的私有方法迁出。
// 这些函数零 this、零 IO、零桥、零 store 依赖，只依赖入参、静态常量与纯计算；
// 宿主与 panels 直连本模块（§14.8 规则 6：不 import store）。
// 触摸/命中类（pointInsideRect / pointOverlapsUiObstacle / touch*）逐字保留比较边界，
// 不得改写 <= / >= / ??

import { SkyUiObstacle } from '../../pages/MainWindowModels'

// 方位条高度（vp，1..96）。
export function azBarHeight(azimuth: number | undefined): number {
  const value: number = azimuth !== undefined ? azimuth : 0
  return Math.max(1, Math.min(96, value / 360 * 96))
}

// 点在矩形内（含 margin 外扩）。
export function pointInsideRect(x: number, y: number, left: number, top: number, right: number,
  bottom: number, margin: number = 0): boolean {
  return x >= left - margin && x <= right + margin && y >= top - margin && y <= bottom + margin
}

// 点与 UI 障碍矩形重叠（含 margin 外扩）。
export function pointOverlapsUiObstacle(x: number, y: number, obstacle: SkyUiObstacle,
  margin: number = 10): boolean {
  return x >= obstacle.left - margin && x <= obstacle.right + margin &&
    y >= obstacle.top - margin && y <= obstacle.bottom + margin
}

// 触摸窗口坐标（优先 point.x/y，回退 windowX/windowY）。
export function touchWindowX(point: TouchObject): number {
  return point.x ?? point.windowX ?? 0
}

export function touchWindowY(point: TouchObject): number {
  return point.y ?? point.windowY ?? 0
}

// 触摸屏幕坐标（优先 windowX/windowY，回退 point.x/y）。
export function touchScreenX(point: TouchObject): number {
  return point.windowX ?? point.x ?? 0
}

export function touchScreenY(point: TouchObject): number {
  return point.windowY ?? point.y ?? 0
}

// 手机端右上快捷区左上角 Y（与顶部搜索栏同高）。
export function compactTopQuickY(): number {
  return 50
}

// 平板展开布局 + 搜索面板打开时，始终用紧凑摘要（不挤完整大卡片）。
export function useExpandedDetailSummary(): boolean {
  return false
}

// 展开态摘要卡高度（vp）。
export function expandedDetailSummaryHeight(): number {
  return 230
}

// 平板对象检查器（当前构型关闭）。
export function useTabletObjectInspector(): boolean {
  return false
}

// 手机端详情卡 peek（当前构型关闭）。
export function isPhoneDetailPeek(): boolean {
  return false
}

// 紧凑对象卡 peek 基础 Y（vp）。
export function baseCompactObjectPeekY(): number {
  return 92
}
