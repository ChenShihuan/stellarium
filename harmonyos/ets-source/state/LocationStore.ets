import { LocSearchItem, SavedLocation } from '../pages/StellariumTypes'
import { CommandPort } from '../bridge/CommandPort'
import hilog from '@ohos.hilog'

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

  // —— 桥注入（§14.1 AB-0；§14 B1-6 起本 store 自持 loadSavedLocations） ——
  // 注意：本加载器读 AppStorage 持久化（`stellariumPrefs`）而非桥，故当前不调用 port；
  // port/seq/onChanged 按统一约定预留，供本域后续 B2/B3 加载器复用。
  private port: CommandPort | null = null
  private seq: number = 0
  private onChanged: (() => void) | null = null

  attachPort(port: CommandPort, onChanged: () => void): void {
    this.port = port
    this.onChanged = onChanged
  }

  private notifyChanged(): void {
    if (this.onChanged !== null) {
      this.onChanged()
    }
  }

  // 已保存位置（持久化在 AppStorage 的 `stellariumPrefs` 键）：把原始条目规整为 SavedLocation[]
  // （原宿主 loadSavedLocations，函数体逐字搬入；仅 this.locationStore.savedLocations → this.savedLocations）。
  loadSavedLocations(): void {
    try {
      const prefs = AppStorage.get<Record<string, Object>>('stellariumPrefs')
      if (prefs && prefs['savedLocations']) {
        const raw = prefs['savedLocations'] as Object[]
        this.savedLocations = raw.map((item: Object): SavedLocation => {
          const loc = item as Record<string, string | number>
          return {
            name: (loc['name'] as string) ?? '',
            lat: (loc['lat'] as number) ?? 0,
            lon: (loc['lon'] as number) ?? 0,
            alt: (loc['alt'] as number) ?? 0,
            planet: (loc['planet'] as string) ?? 'Earth',
          } as SavedLocation
        })
        this.notifyChanged()
      }
    } catch (e) {
      hilog.info(0x0000, 'StellariumArkUI', 'loadSavedLocations error: %{public}s', (e as Error).message ?? '')
    }
  }
}
