// 底部导航的"基底"：App 自己的导航皮肤选择。
//
// 官方 HdsTabs 与自绘 Dock 都只是皮肤实现，条目/选中态/回调属于宿主与基底，
// 这样切换视觉（system/custom）不影响面板、命中与几何。

export enum BottomNavSurface {
  AUTO = 'auto',
  SYSTEM = 'system',
  CUSTOM = 'custom'
}

/** 当前默认皮肤：系统皮肤的视觉与宽度回填未验收前保持自绘（零视觉变化）。 */
export const DEFAULT_BOTTOM_NAV_SURFACE: BottomNavSurface = BottomNavSurface.CUSTOM

/**
 * 是否具备系统材质导航栏（HDS 悬浮页签）能力。
 *
 * 只用 syscap 判断：`deviceInfo.apiAvailable` 是 6.1.0(26) 才有的方法，
 * 在 23–25 设备上直接调用会因缺少该方法而崩溃，不能用来做低版本分流。
 */
export function systemBottomNavAvailable(): boolean {
  return canIUse('SystemCapability.UIDesign.HDSComponent.Core')
}

export function resolveBottomNavSurface(requested: string): BottomNavSurface {
  if (requested === BottomNavSurface.CUSTOM) {
    return BottomNavSurface.CUSTOM
  }
  const available = systemBottomNavAvailable()
  if (requested === BottomNavSurface.SYSTEM) {
    return available ? BottomNavSurface.SYSTEM : BottomNavSurface.CUSTOM
  }
  return available ? BottomNavSurface.SYSTEM : BottomNavSurface.CUSTOM
}
