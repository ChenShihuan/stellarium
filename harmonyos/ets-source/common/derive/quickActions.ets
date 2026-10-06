// 「快捷操作面板」（Dock 中间入口，activePanel === 'quick'）的 12 项纯描述表。
//
// 只描述"是什么"：稳定 id、提示文案键、图标键与着色路径、图层类动作的 actionShow_* 标识。
// 开关值一律来自既有 store（layer / satellite / gyro / nightMode），故本模块零 store、零桥、零 IO。
// 动作分发在宿主：QuickPanel.onToggle → 宿主 quickToggle(id, value)。
//
// 文案一律复用既有键（与图层面板同词），见 docs/harmonyos/research/QUICK-ACTIONS-PANEL-PLAN.md §5。

export interface QuickActionItem {
  id: string
  labelKey: string
  icon: string
  kind: string
  actionId: string
}

// 顺序即网格顺序：前 6 项为第一行，后 6 项为第二行（与参考图一致）。
export function quickActionItems(): QuickActionItem[] {
  return [
    { id: 'constellation_lines', labelKey: 's0522', icon: 'bt_constellation_lines', kind: 'raster', actionId: 'actionShow_Constellation_Lines' },
    { id: 'constellation_labels', labelKey: 's0523', icon: 'bt_constellation_labels', kind: 'raster', actionId: 'actionShow_Constellation_Labels' },
    { id: 'constellation_art', labelKey: 's0525', icon: 'bt_constellation_art', kind: 'raster', actionId: 'actionShow_Constellation_Art' },
    { id: 'equatorial_grid', labelKey: 's0323', icon: 'bt_equatorial_grid', kind: 'raster', actionId: 'actionShow_Equatorial_Grid' },
    { id: 'azimuthal_grid', labelKey: 's0324', icon: 'bt_azimuthal_grid', kind: 'raster', actionId: 'actionShow_Azimuthal_Grid' },
    { id: 'ground', labelKey: 's0306', icon: 'bt_ground', kind: 'raster', actionId: 'actionShow_Ground' },
    { id: 'atmosphere', labelKey: 's0305', icon: 'bt_atmosphere', kind: 'raster', actionId: 'actionShow_Atmosphere' },
    { id: 'cardinal_points', labelKey: 's0533', icon: 'bt_cardinal_points', kind: 'raster', actionId: 'actionShow_Cardinal_Points' },
    { id: 'nebulae', labelKey: 's0320', icon: 'bt_nebula', kind: 'raster', actionId: 'actionShow_Nebulas' },
    { id: 'satellites', labelKey: 'plugin_satellites', icon: 'satellite', kind: 'vector', actionId: '' },
    { id: 'gyroscope', labelKey: 'i0060', icon: 'gyro', kind: 'vector', actionId: '' },
    { id: 'night_mode', labelKey: 's0300', icon: 'bt_night_view', kind: 'raster', actionId: '' }
  ]
}

// 网格列数：2 行 × 6 列。
export const QUICK_ACTION_COLUMNS: number = 6
