import { HierCity, LocSearchItem, SavedLocation } from '../pages/StellariumTypes'
import { I18n } from '../pages/I18n'
import { LOCATION_HIERARCHY } from '../common/location/hierarchy'
import { LOCATION_COUNTRY_NAMES } from '../common/location/countries'
import { LOCATION_ZH_NAMES } from '../common/location/names_zh'
import { locationSearchMatchScore, officialLocationAliases } from '../common/derive/actions'
import { CommandPort } from '../bridge/CommandPort'
import hilog from '@ohos.hilog'

// 位置域（「位置」面板）状态：离线地点搜索簇 + 已保存位置簇。
//
// 持有搜索框字段（locSearchQuery/Results/Searching/Debounce）与 savedLocations，以及离线分块
// 搜索的私有草稿；被位置面板的 cityChipsRow / locationSearchPanel 以 @ObjectLink 观察。
// 加载器 loadSavedLocations 与搜索/保存点为 store 方法，跨域读与跨 store 动作经
// LocationStoreHostHooks 具名回注（store 不 import 他 store）。
//
// 只放数据与纯计算，不 import UI / NAPI。
@Observed
export class LocationStore {
  locSearchQuery: string = ''
  locSearchResults: LocSearchItem[] = []
  locSearching: boolean = false
  locSearchDebounce: number = 0
  savedLocations: SavedLocation[] = []

  // —— 离线分块搜索草稿（不对 UI 直接暴露）——
  private locSearchRequestId: number = 0
  private locationSearchScanContinents: Array<string> = []
  private locationSearchScanRegions: Array<string> = []
  private locationSearchScanContinentIndex: number = 0
  private locationSearchScanRegionIndex: number = 0
  private locationSearchScanCityIndex: number = 0
  private locationSearchScanQuery: string = ''
  private locationSearchScanResults: Array<LocSearchItem> = []
  private locationSearchScanKeys: Set<string> = new Set<string>()
  private locationSearchScanTimer: number = -1
  private locationSearchLastPublishMs: number = 0

  // 经纬度格式化为「绝对值°方向」（N/S、E/W），位置域共用。
  formatDegrees(value: number, positive: string, negative: string): string {
    const direction = value >= 0 ? positive : negative
    return Math.abs(value).toFixed(2) + '°' + direction
  }

  // —— 桥注入 ——
  // 本 store 的加载器读 AppStorage 持久化（`stellariumPrefs`）而非桥，故当前不调用 port；
  // port/seq/onChanged 按统一约定预留，供本域后续加载器复用。
  private port: CommandPort | null = null
  private seq: number = 0
  private onChanged: (() => void) | null = null
  // 离线搜索 / 保存点的跨域读写回注。
  private hooks: LocationStoreHostHooks | null = null

  attachPort(port: CommandPort, onChanged: () => void): void {
    this.port = port
    this.onChanged = onChanged
  }

  attachHooks(hooks: LocationStoreHostHooks): void {
    this.hooks = hooks
  }

  private notifyChanged(): void {
    if (this.onChanged !== null) {
      this.onChanged()
    }
  }

  // 已保存位置（持久化在 AppStorage 的 `stellariumPrefs` 键）：把原始条目规整为 SavedLocation[]。
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

  // 离线搜索入口；跨域助手经 hooks。
  searchLocations(query: string): void {
    const hooks = this.hooks
    if (hooks === null) return
    const q = query.trim()
    const requestId = ++this.locSearchRequestId
    if (this.locationSearchScanTimer >= 0) {
      clearTimeout(this.locationSearchScanTimer)
      this.locationSearchScanTimer = -1
    }
    if (q.length < 1) {
      this.locSearchResults = []
      this.locSearching = false
      return
    }
    const quickResults = hooks.quickLocationSearch(q, hooks.observerPlanet())
    if (quickResults.length > 0) {
      this.locSearchResults = quickResults.slice(0, 20)
      this.locSearching = false
      return
    }
    this.locSearching = true
    this.locationSearchScanQuery = q
    this.locationSearchScanResults = []
    this.locationSearchScanKeys = new Set<string>()
    this.locationSearchScanContinents = Object.keys(LOCATION_HIERARCHY)
    this.locationSearchScanRegions = []
    this.locationSearchScanContinentIndex = 0
    this.locationSearchScanRegionIndex = 0
    this.locationSearchScanCityIndex = 0
    this.locationSearchLastPublishMs = 0
    this.locSearchResults = []
    this.locationSearchScanTimer = setTimeout(() => { this.scanLocationSearchChunk(requestId) }, 0)
  }

  // 离线搜索分块扫描；跨域助手经 hooks。
  scanLocationSearchChunk(requestId: number): void {
    const hooks = this.hooks
    if (hooks === null) return
    if (requestId !== this.locSearchRequestId) return
    const startedAt = Date.now()
    let changed = false
    while (this.locationSearchScanContinentIndex < this.locationSearchScanContinents.length && Date.now() - startedAt < 5) {
      const continent = this.locationSearchScanContinents[this.locationSearchScanContinentIndex]
      if (this.locationSearchScanRegions.length === 0) {
        this.locationSearchScanRegions = Object.keys(LOCATION_HIERARCHY[continent])
      }
      if (this.locationSearchScanRegionIndex >= this.locationSearchScanRegions.length) {
        this.locationSearchScanContinentIndex++
        this.locationSearchScanRegions = []
        this.locationSearchScanRegionIndex = 0
        this.locationSearchScanCityIndex = 0
        continue
      }
      const region = this.locationSearchScanRegions[this.locationSearchScanRegionIndex]
      const cities = LOCATION_HIERARCHY[continent][region]
      if (this.locationSearchScanCityIndex >= cities.length) {
        this.locationSearchScanRegionIndex++
        this.locationSearchScanCityIndex = 0
        continue
      }
      const city = cities[this.locationSearchScanCityIndex++]
      if (!hooks.isCurrentObserverPlanet(city, hooks.observerPlanet())) continue
      const chinese = LOCATION_ZH_NAMES[city.n] ?? ''
      const displayName = hooks.locationDisplayName(city.n)
      const countryCode = city.country
      const country = hooks.locationSearchCountryName(countryCode, hooks.observerPlanet())
      const province = hooks.translateProvince(city.province ?? '')
      // Search accepts the source name, official Chinese name, and the name
      // rendered for the active language. Display itself remains single-language.
      const sourceCountry = LOCATION_COUNTRY_NAMES[countryCode]
      const text = city.n + ' ' + chinese + ' ' + displayName + ' ' +
        (city.province ?? '') + ' ' + province + ' ' + region + ' ' + country + ' ' +
        (sourceCountry?.zh ?? '') + ' ' + (sourceCountry?.en ?? '') + officialLocationAliases(countryCode)
      const matchScore = locationSearchMatchScore(this.locationSearchScanQuery,
        [city.n, chinese, displayName, city.province ?? '', province, region, country], text)
      if (matchScore <= 0) continue
      const item: LocSearchItem = {
        name: city.n,
        displayName: displayName,
        lat: city.la,
        lon: city.lo,
        alt: city.al,
        planet: hooks.locationPlanet(city),
        country: countryCode,
        region: region,
        province: city.province ?? '',
        searchScore: matchScore,
      }
      const key = city.n + '|' + city.la.toFixed(4) + '|' + city.lo.toFixed(4)
      if (this.locationSearchScanKeys.has(key)) continue
      this.locationSearchScanKeys.add(key)
      this.locationSearchScanResults.push(item)
      this.locationSearchScanResults.sort((left: LocSearchItem, right: LocSearchItem) =>
        (right.searchScore ?? 0) - (left.searchScore ?? 0))
      if (this.locationSearchScanResults.length > 20) this.locationSearchScanResults.pop()
      changed = true
    }
    if (requestId !== this.locSearchRequestId) return
    const finished = this.locationSearchScanContinentIndex >= this.locationSearchScanContinents.length
    const now = Date.now()
    if (changed && (finished || now - this.locationSearchLastPublishMs >= 120)) {
      this.locSearchResults = this.locationSearchScanResults.slice()
      this.locationSearchLastPublishMs = now
    }
    if (finished) {
      this.locSearching = false
      this.locationSearchScanTimer = -1
      return
    }
    this.locationSearchScanTimer = setTimeout(() => { this.scanLocationSearchChunk(requestId) }, 16)
  }

  // 搜索选中落地；setLocation / pickerMode 经 hooks。
  selectSearchLocation(item: LocSearchItem): void {
    const hooks = this.hooks
    if (hooks === null) return
    hooks.applyLocation(item.name, item.lat, item.lon, item.alt, item.planet)
    this.locSearchQuery = ''
    this.locSearchResults = []
    hooks.setPickerMode('map')
  }

  // 保存当前 picker 位置；picker 草稿与 flashHint 经 hooks。
  saveCurrentLocation(): void {
    const hooks = this.hooks
    if (hooks === null) return
    const draft = hooks.currentDraft()
    const name = draft.name
    // 检查是否已存在
    const exists = this.savedLocations.some((s: SavedLocation) => s.name === name)
    if (exists) {
      hooks.flashHint(I18n.t('loc_already_saved'))
      return
    }
    const item: SavedLocation = {
      name: name,
      lat: draft.latitude,
      lon: draft.longitude,
      alt: draft.altitude,
      planet: draft.planet,
    }
    this.savedLocations = [...this.savedLocations, item]
    this.persistSavedLocations()
    hooks.flashHint(I18n.t('loc_saved_success'))
  }

  // 删除已保存位置。
  deleteSavedLocation(name: string): void {
    this.savedLocations = this.savedLocations.filter((s: SavedLocation) => s.name !== name)
    this.persistSavedLocations()
  }

  // 持久化已保存位置（存储方式保持 AppStorage 原样）。
  persistSavedLocations(): void {
    try {
      let prefs = AppStorage.get<Record<string, Object>>('stellariumPrefs')
      if (!prefs) {
        prefs = {} as Record<string, Object>
      }
      prefs['savedLocations'] = this.savedLocations
      AppStorage.setOrCreate<Record<string, Object>>('stellariumPrefs', prefs)
    } catch (e) {
      hilog.info(0x0000, 'StellariumArkUI', 'persistSavedLocations error: %{public}s', (e as Error).message ?? '')
    }
  }
}

// 宿主 → LocationStore 的回注。离线搜索 / 保存点的跨域读（LocationPickerStore 的
// 名称/坐标/层级过滤助手、SessionToolStore 的 observerPlanet）与跨 store 动作经此具名注入，
// store 不 import 他 store。
export interface LocationDraft {
  name: string
  latitude: number
  longitude: number
  altitude: number
  planet: string
}

export interface LocationStoreHostHooks {
  flashHint(text: ResourceStr): void
  // 当前 picker 草稿（LocationPickerStore 的名称/坐标 + SessionToolStore 的 observerPlanet）。
  currentDraft(): LocationDraft
  observerPlanet(): string
  quickLocationSearch(query: string, observerPlanet: string): Array<LocSearchItem>
  isCurrentObserverPlanet(city: HierCity, observerPlanet: string): boolean
  locationDisplayName(name: string): string
  locationSearchCountryName(countryCode: string, observerPlanet: string): string
  translateProvince(name: string): string
  locationPlanet(city: HierCity): string
  // selectSearchLocation 的落地（宿主 this.locationCtl().setLocation）与 picker 模式写。
  applyLocation(name: string, lat: number, lon: number, alt: number, planet: string): void
  setPickerMode(mode: string): void
}
