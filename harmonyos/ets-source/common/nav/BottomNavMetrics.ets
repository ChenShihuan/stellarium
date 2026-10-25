import {
  dockLeft, dockWidthPixels
} from '../derive/geometry'

// 底部导航的几何单一来源。
//
// 视觉（ExpandedShell / HoverObservatoryShell / CompactShell）与命中、面板锚点、
// chrome 读数行都必须从这里取数，避免"看得见的位置"和"点得到的区域"各算一套。
// 这些常量与三套 shell 的 .position/.height 一一对应，改动时必须一起改。

/** 展开/悬停布局：Dock 顶边 = skyHeight - 62（见 ExpandedShell / HoverObservatoryShell）。 */
export const NAV_EXPANDED_BASELINE: number = 62

/** 展开/悬停布局：Dock 视觉高度。 */
export const NAV_EXPANDED_HEIGHT: number = 54

/** 手机紧凑布局：Dock 视觉高度。 */
export const NAV_COMPACT_HEIGHT: number = 66

/** 面板下沿与 Dock 上沿之间的固定间距。 */
export const NAV_PANEL_GAP: number = 10

export interface BottomNavRect {
  left: number
  top: number
  width: number
  height: number
}

export function bottomNavHeight(isExpandedLayout: boolean): number {
  return isExpandedLayout ? NAV_EXPANDED_HEIGHT : NAV_COMPACT_HEIGHT
}

// compactBottomClearance 由宿主按安全区换算（安全区 + 30vp）。
export function bottomNavTop(isExpandedLayout: boolean, skyHeight: number,
  compactBottomClearance: number): number {
  if (isExpandedLayout) {
    return Math.max(0, skyHeight - NAV_EXPANDED_BASELINE)
  }
  return Math.max(0, skyHeight - NAV_COMPACT_HEIGHT - compactBottomClearance)
}

export function bottomNavRect(isExpandedLayout: boolean, skyWidth: number, skyHeight: number,
  panelVisible: boolean, panelWidth: number, panelOffsetX: number, edgeMargin: number,
  compactDockWidthPercent: number, compactBottomClearance: number): BottomNavRect {
  return {
    left: dockLeft(isExpandedLayout, skyWidth, panelVisible, panelWidth, panelOffsetX,
      edgeMargin, compactDockWidthPercent),
    top: bottomNavTop(isExpandedLayout, skyHeight, compactBottomClearance),
    width: dockWidthPixels(isExpandedLayout, skyWidth, panelVisible, panelWidth, panelOffsetX,
      edgeMargin, compactDockWidthPercent),
    height: bottomNavHeight(isExpandedLayout)
  }
}
