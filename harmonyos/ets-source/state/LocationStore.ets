import { LocSearchItem, SavedLocation } from '../pages/StellariumTypes'

// 位置域（「位置」面板）状态：离线地点搜索簇 + 已保存位置簇。
//
// 本片边界（Phase 3ai）：只搬 cityChipsRow / locationSearchPanel 直接读写的两簇字段 ——
//   locSearchQuery / locSearchResults / locSearching / locSearchDebounce / savedLocations。
// picker 簇（locationPickerName / locationPickerLatitude / locationPickerLongitude /
// locationPickerAltitude / locationPickerStatus / locationPickMode / hier* / mapRender* /
// observerTimeZone）仍留在宿主，随 locationPickerPanel 的组件化在下一片一并迁移。
//
// 只放数据与纯计算，不 import UI / NAPI。
@Observed
export class LocationStore {
  locSearchQuery: string = ''
  locSearchResults: LocSearchItem[] = []
  locSearching: boolean = false
  locSearchDebounce: number = 0
  savedLocations: SavedLocation[] = []

  // 经纬度格式化为「绝对值°方向」（N/S、E/W）。原宿主私有方法，位置域共用。
  formatDegrees(value: number, positive: string, negative: string): string {
    const direction = value >= 0 ? positive : negative
    return Math.abs(value).toFixed(2) + '°' + direction
  }
}
