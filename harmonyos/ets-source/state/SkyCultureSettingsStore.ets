import { I18n } from '../pages/I18n'
import { SkyCultureItem, SkyCultureTerritoryEntry, SkyCultureTerritoryPolygon } from '../pages/StellariumTypes'
import { ConfigurationOption, SkyCultureVisualColors } from '../pages/MainWindowModels'

// 「星空文化」面板（`activePanel === 'layers'` 的第 7 个视图标签页 `viewSkyCultureTab`）的
// **设置字段簇 + 纯计算**。
//
// 本片边界（Phase 4g）：
//   - 迁移原宿主 82 个 builder 专用 `skyCulture*` @State 字段（视觉 24、标签模式/组合名称 12、
//     目录筛选 15、领地地图 11、详情元信息 14、默认文化 1 等），逐条保留原类型与默认值；
//     宿主以 `@State private skyCultureSettingsStore: SkyCultureSettingsStore = new SkyCultureSettingsStore()`
//     持有，组件经 @ObjectLink 实时读，宿主自身也读它（规则 4 安全）。
//   - 迁移只读/纯计算助手（标签模式名、配色、地区/分类文案、年代筛选、领地档案筛选、
//     年份格式化、`filteredSkyCultureList(list)`、`applySkyCultureVisualSetting` 等）。
//
// 明确**不**属于本 store（留在宿主，理由见协议 §13.1 规则 5/6）：
//   - 文化列表与当前选择 `skyCultureList` / `skyCultureListLoading` / `skyCultures` /
//     `currentSkyCulture` / `currentSkyCultureId` —— 跨域共享，以 @Prop 传入组件；
//   - 进度驱动的解码结果 `skyCultureArtStates` / `skyCultureArtThumbnailPixelMaps` /
//     `skyCultureArtPreviewPixelMap` —— 逐张图片解码渐进写入，按"高频写入不入被观察 store"留在宿主，
//     以 @Prop 传入组件；
//   - Canvas 绘图上下文与画布尺寸 `skyCultureMapContext*` / `skyCultureMapRender*` ——
//     由宿主 `drawSkyCultureTerritoryMap()` 持有并回注；
//   - 定时器 / 请求序号 / 锚点校正字段；
//   - native 桥动作（setSkyCultureVisualSetting / setSkyCultureLabelStyle / setConstellationFlag /
//     triggerAction / setSkyCultureDefault / getSkyCultureTerritoryGeometry / setSkyCulture / …）
//     仍留宿主，由组件回调触发。
//
// 只放数据与纯计算；不 import ArkUI / NAPI。
@Observed
export class SkyCultureSettingsStore {
  // —— 领地区域档案 ——
  skyCultureTerritoryArchive: Array<SkyCultureTerritoryEntry> = []
  skyCultureHasTerritoryArchive: boolean = false
  skyCultureTerritorySegmentCount: number = 0
  skyCultureTerritoryExpanded: boolean = false
  skyCultureTerritoryMapExpanded: boolean = false
  skyCultureTerritoryMapLoading: boolean = false
  skyCultureTerritoryMapError: string = ''
  skyCultureTerritoryMapPolygons: Array<SkyCultureTerritoryPolygon> = []
  skyCultureTerritoryMapYear: number = new Date().getFullYear()
  skyCultureTerritoryMapYearInput: string = new Date().getFullYear().toString()
  skyCultureMapUseLocationRotation: boolean = false
  skyCultureObserverLatitude: number = 0

  // —— 当前文化的只读元信息 ——
  skyCultureRegions: string[] = []
  skyCultureClassification: string = ''
  skyCultureLicense: string = ''
  skyCultureBoundariesType: string = 'none'
  skyCultureUsesCommonNames: boolean = false
  skyCultureBeginTime: number = 0
  skyCultureEndTime: number = 0
  skyCultureConstellationCount: number = 0
  skyCultureAsterismCount: number = 0
  skyCultureNativeNameCount: number = 0
  skyCultureArtCount: number = 0
  skyCultureHasAsterisms: boolean = false
  skyCultureHasZodiac: boolean = false
  skyCultureHasLunarSystem: boolean = false

  // —— 标签模式与组合名称 ——
  skyCultureScreenLabelMode: number = 0
  skyCultureInfoLabelMode: number = 0
  skyCultureZodiacLabelMode: number = 0
  skyCultureLunarLabelMode: number = 0
  skyCultureLabelPickerOpen: string = ''
  skyCultureScreenStyleMask: number = 4
  skyCultureInfoStyleMask: number = 4
  skyCultureNameCombinationExpanded: boolean = false
  skyCultureShortLabels: boolean = false
  skyCultureOverrideCommonNames: boolean = false
  skyCultureIsolateSelected: boolean = false
  skyCultureSinglePick: boolean = false

  // —— 视觉设置（字号 / 粗细 / 亮度 / 过渡时长）——
  skyCultureConstellationFontSize: number = 14
  skyCultureConstellationLineThickness: number = 1
  skyCultureConstellationBoundaryThickness: number = 1
  skyCultureConstellationHullsThickness: number = 1
  skyCultureZodiacThickness: number = 1
  skyCultureLunarSystemThickness: number = 1
  skyCultureConstellationArtIntensity: number = 0.5
  skyCultureConstellationLinesFadeDuration: number = 1
  skyCultureConstellationLabelsFadeDuration: number = 1
  skyCultureConstellationArtFadeDuration: number = 1
  skyCultureConstellationBoundariesFadeDuration: number = 1
  skyCultureConstellationHullsFadeDuration: number = 1
  skyCultureZodiacFadeDuration: number = 1
  skyCultureLunarSystemFadeDuration: number = 1
  skyCultureAsterismFontSize: number = 14
  skyCultureAsterismLineThickness: number = 1
  skyCultureRayHelperThickness: number = 1
  skyCultureAsterismLinesFadeDuration: number = 1
  skyCultureAsterismLabelsFadeDuration: number = 1
  skyCultureRayHelperFadeDuration: number = 1
  skyCultureColorsExpanded: boolean = false
  skyCultureVisualColors: SkyCultureVisualColors = {
    constellationLines: '#B9D8FF', constellationLabels: '#D9E9FF', constellationBoundaries: '#DB8B8B',
    constellationHulls: '#A66C6C', zodiac: '#FFE36E', lunarSystem: '#7DE7B5',
    asterismLines: '#B1C7FF', asterismLabels: '#D5DEFF', rayHelpers: '#A9E2D2'
  }
  skyCultureColorTarget: string = 'constellationLines'
  skyCultureColorInput: string = '#B9D8FF'

  // —— 默认文化 ——
  skyCultureDefaultId: string = ''

  // —— 目录筛选 ——
  skyCultureSearchText: string = ''
  skyCultureClassificationFilter: string = 'all'
  skyCultureRegionFilter: string = 'all'
  skyCultureClassificationFilterOpen: boolean = false
  skyCultureRegionFilterOpen: boolean = false
  skyCultureTimeFiltering: boolean = false
  skyCultureRangeFiltering: boolean = false
  skyCultureTimeYear: number = new Date().getFullYear()
  skyCultureTimeYearInput: string = new Date().getFullYear().toString()
  skyCultureRangeStart: number = -40000
  skyCultureRangeEnd: number = new Date().getFullYear()
  skyCultureRangeStartInput: string = '-40000'
  skyCultureRangeEndInput: string = new Date().getFullYear().toString()
  skyCultureSimulationYear: number = new Date().getFullYear()
  skyCultureTimeFollowSimulation: boolean = false

  // —— 纯计算：bridge 风格串 → 档位 ——
  skyCultureScreenLabelModeFromBridge(style: string | undefined): number {
    const normalized = style !== undefined ? style.toLowerCase() : ''
    if (normalized === 'modern') return 4
    if (normalized.includes('translit')) return 3
    if (normalized.includes('pronounce')) return 2
    if (normalized.includes('native')) return 1
    return 0
  }

  skyCultureStyleMaskFromBridge(style: string | undefined): number {
    if (style === undefined) return 4
    const parts = style.replace(/_/g, ',').split(',')
    let mask = 0
    for (let index = 0; index < parts.length; index++) {
      const name = parts[index].trim().toLowerCase()
      const names: string[] = ['modern', 'ipa', 'translated', 'translit', 'pronounce', 'native', 'byname']
      const optionIndex = names.indexOf(name)
      if (optionIndex >= 0) mask |= (1 << optionIndex)
    }
    return mask
  }

  skyCultureStyleOptions(): Array<ConfigurationOption> {
    return [
      { id: 'Modern', label: '现代名称' },
      { id: 'IPA', label: '国际音标' },
      { id: 'Translated', label: '中文译名' },
      { id: 'Translit', label: '学术转写' },
      { id: 'Pronounce', label: '通俗读音' },
      { id: 'Native', label: '文化原名' },
      { id: 'Byname', label: '别称' }
    ]
  }

  skyCultureStyleMaskHas(mask: number, optionIndex: number): boolean {
    return (mask & (1 << optionIndex)) !== 0
  }

  skyCultureStyleSummary(mask: number): string {
    const options = this.skyCultureStyleOptions()
    const labels: string[] = []
    for (let index = 0; index < options.length; index++) {
      if (this.skyCultureStyleMaskHas(mask, index)) labels.push(options[index].label)
    }
    return labels.length > 0 ? labels.join('、') : '不显示文化名称'
  }

  skyCultureStyleValue(mask: number): string {
    const options = this.skyCultureStyleOptions()
    const values: string[] = []
    for (let index = 0; index < options.length; index++) {
      if (this.skyCultureStyleMaskHas(mask, index)) values.push(options[index].id)
    }
    return values.length > 0 ? values.join(',') : 'None'
  }

  skyCultureLabelModeOptions(target: string): string[] {
    const options: string[] = [I18n.t('culture_translated_name'), I18n.t('culture_native_name'), I18n.t('culture_pronunciation'), I18n.t('culture_transliteration')]
    if (target === 'zodiac' || target === 'lunar') {
      return options
    }
    return options.concat([I18n.t('culture_modern_name')])
  }

  skyCultureLabelModeForTarget(target: string): number {
    const mode = target === 'screen' ? this.skyCultureScreenLabelMode
      : (target === 'info' ? this.skyCultureInfoLabelMode
        : (target === 'zodiac' ? this.skyCultureZodiacLabelMode : this.skyCultureLunarLabelMode))
    return mode >= 0 && mode < this.skyCultureLabelModeOptions(target).length ? mode : 0
  }

  // —— 纯计算：配色 ——
  skyCultureVisualColor(setting: string): string {
    if (setting === 'constellationLabels') return this.skyCultureVisualColors.constellationLabels
    if (setting === 'constellationBoundaries') return this.skyCultureVisualColors.constellationBoundaries
    if (setting === 'constellationHulls') return this.skyCultureVisualColors.constellationHulls
    if (setting === 'zodiac') return this.skyCultureVisualColors.zodiac
    if (setting === 'lunarSystem') return this.skyCultureVisualColors.lunarSystem
    if (setting === 'asterismLines') return this.skyCultureVisualColors.asterismLines
    if (setting === 'asterismLabels') return this.skyCultureVisualColors.asterismLabels
    if (setting === 'rayHelpers') return this.skyCultureVisualColors.rayHelpers
    return this.skyCultureVisualColors.constellationLines
  }

  selectSkyCultureColorTarget(setting: string): void {
    this.skyCultureColorTarget = setting
    this.skyCultureColorInput = this.skyCultureVisualColor(setting)
  }

  applySkyCultureVisualSetting(setting: string, value: number): void {
    if (setting === 'constellationFontSize') this.skyCultureConstellationFontSize = value
    else if (setting === 'constellationLineThickness') this.skyCultureConstellationLineThickness = value
    else if (setting === 'constellationBoundaryThickness') this.skyCultureConstellationBoundaryThickness = value
    else if (setting === 'constellationHullsThickness') this.skyCultureConstellationHullsThickness = value
    else if (setting === 'zodiacThickness') this.skyCultureZodiacThickness = value
    else if (setting === 'lunarSystemThickness') this.skyCultureLunarSystemThickness = value
    else if (setting === 'constellationArtIntensity') this.skyCultureConstellationArtIntensity = value
    else if (setting === 'constellationLinesFadeDuration') this.skyCultureConstellationLinesFadeDuration = value
    else if (setting === 'constellationLabelsFadeDuration') this.skyCultureConstellationLabelsFadeDuration = value
    else if (setting === 'constellationArtFadeDuration') this.skyCultureConstellationArtFadeDuration = value
    else if (setting === 'constellationBoundariesFadeDuration') this.skyCultureConstellationBoundariesFadeDuration = value
    else if (setting === 'constellationHullsFadeDuration') this.skyCultureConstellationHullsFadeDuration = value
    else if (setting === 'zodiacFadeDuration') this.skyCultureZodiacFadeDuration = value
    else if (setting === 'lunarSystemFadeDuration') this.skyCultureLunarSystemFadeDuration = value
    else if (setting === 'asterismFontSize') this.skyCultureAsterismFontSize = value
    else if (setting === 'asterismLineThickness') this.skyCultureAsterismLineThickness = value
    else if (setting === 'rayHelperThickness') this.skyCultureRayHelperThickness = value
    else if (setting === 'asterismLinesFadeDuration') this.skyCultureAsterismLinesFadeDuration = value
    else if (setting === 'asterismLabelsFadeDuration') this.skyCultureAsterismLabelsFadeDuration = value
    else if (setting === 'rayHelperFadeDuration') this.skyCultureRayHelperFadeDuration = value
  }

  // —— 纯计算：目录筛选与文案 ——
  filteredSkyCultureList(list: Array<SkyCultureItem>): Array<SkyCultureItem> {
    const query = this.skyCultureSearchText.trim().toLowerCase()
    const filtered = list.filter((item: SkyCultureItem) => {
      if (this.skyCultureClassificationFilter !== 'all' && item.classification !== this.skyCultureClassificationFilter) return false
      if (this.skyCultureRegionFilter !== 'all' && !(item.region ?? []).includes(this.skyCultureRegionFilter)) return false
      if (this.skyCultureTimeFiltering) {
        const matchesTime = this.skyCultureRangeFiltering
          ? this.skyCultureIncludesRange(item, this.skyCultureRangeStart, this.skyCultureRangeEnd)
          : this.skyCultureIncludesYear(item, this.skyCultureTimeYear)
        if (!matchesTime) return false
      }
      if (query.length === 0) return true
      const text = this.skyCultureDisplayName(item.id, item.name) + ' ' + item.name + ' ' + item.id + ' ' + (item.region ?? []).join(' ')
      return text.toLowerCase().includes(query)
    })
    filtered.sort((first: SkyCultureItem, second: SkyCultureItem) => {
      const firstRegion = this.skyCultureRegionKey(first)
      const secondRegion = this.skyCultureRegionKey(second)
      if (firstRegion !== secondRegion) return firstRegion.localeCompare(secondRegion)
      return this.skyCultureDisplayName(first.id, first.name).localeCompare(this.skyCultureDisplayName(second.id, second.name))
    })
    return filtered
  }

  skyCultureRegionKey(item: SkyCultureItem): string {
    const regions = item.region ?? []
    return regions.length > 0 ? regions[0] : 'Other'
  }

  skyCultureRegionHeader(list: Array<SkyCultureItem>, index: number): string {
    if (index < 0 || index >= list.length) return ''
    const current = this.skyCultureRegionKey(list[index])
    if (index > 0 && this.skyCultureRegionKey(list[index - 1]) === current) return ''
    return current === 'Other' ? '其他地区' : this.skyCultureRegionText([current])
  }

  skyCultureIncludesYear(item: SkyCultureItem, year: number): boolean {
    const begin = item.beginTime ?? 0
    const end = item.endTime ?? 0
    if (begin === 0 && end === 0) return true
    const earliest = begin === 0 ? -40000 : begin
    const latest = end === 0 || end >= 9000 ? this.skyCultureFilterMaxYear() : end
    return year >= earliest && year <= latest
  }

  skyCultureIncludesRange(item: SkyCultureItem, startYear: number, endYear: number): boolean {
    const begin = item.beginTime ?? 0
    const end = item.endTime ?? 0
    if (begin === 0 && end === 0) return true
    const earliest = begin === 0 ? -40000 : begin
    const latest = end === 0 || end >= 9000 ? this.skyCultureFilterMaxYear() : end
    return earliest <= endYear && latest >= startYear
  }

  skyCultureFilterMaxYear(): number {
    return Math.max(new Date().getFullYear(), this.skyCultureSimulationYear)
  }

  skyCultureRangeLabel(): string {
    const format = (year: number): string => year < 0 ? '公元前 ' + Math.abs(year) + ' 年' : '公元 ' + year + ' 年'
    return format(this.skyCultureRangeStart) + ' 至 ' + format(this.skyCultureRangeEnd)
  }

  skyCultureTimeFilterLabel(): string {
    if (this.skyCultureTimeYear < 0) return '公元前 ' + Math.abs(this.skyCultureTimeYear) + ' 年'
    return '公元 ' + this.skyCultureTimeYear + ' 年'
  }

  skyCultureClassificationFilterLabels(): string[] {
    return ['全部类型', '传统传承', '民族志记录', '历史复原', '单一史料', '比较呈现', '个人创作', '资料待完善']
  }

  skyCultureClassificationFilterValues(): string[] {
    return ['all', 'traditional', 'ethnographic', 'historical', 'single', 'comparative', 'personal', 'incomplete']
  }

  skyCultureClassificationFilterLabel(): string {
    const values = this.skyCultureClassificationFilterValues()
    const labels = this.skyCultureClassificationFilterLabels()
    const index = values.indexOf(this.skyCultureClassificationFilter)
    return labels[index >= 0 ? index : 0]
  }

  skyCultureRegionFilterLabels(): string[] {
    return [
      I18n.t('culture_all_regions'), '澳大拉西亚', '中美洲', '东亚', '东欧', '美拉尼西亚', '北非', '北美洲',
      '北亚', '北欧', '波利尼西亚', '南美洲', '东南亚', '南部非洲', '南亚', '南欧', '西亚', '西欧', '全球'
    ]
  }

  skyCultureRegionFilterValues(): string[] {
    return [
      'all', 'Australasia', 'Central America', 'Eastern Asia', 'Eastern Europe', 'Melanesia',
      'Northern Africa', 'Northern America', 'Northern Asia', 'Northern Europe', 'Polynesia',
      'South America', 'South-eastern Asia', 'Southern Africa', 'Southern Asia', 'Southern Europe',
      'Western Asia', 'Western Europe', 'World'
    ]
  }

  skyCultureRegionFilterLabel(): string {
    const values = this.skyCultureRegionFilterValues()
    const labels = this.skyCultureRegionFilterLabels()
    const index = values.indexOf(this.skyCultureRegionFilter)
    return labels[index >= 0 ? index : 0]
  }

  skyCultureFilterOpen(kind: string): boolean {
    return kind === 'classification' ? this.skyCultureClassificationFilterOpen : this.skyCultureRegionFilterOpen
  }

  skyCultureFilterLabels(kind: string): string[] {
    return kind === 'classification' ? this.skyCultureClassificationFilterLabels() : this.skyCultureRegionFilterLabels()
  }

  skyCultureFilterValues(kind: string): string[] {
    return kind === 'classification' ? this.skyCultureClassificationFilterValues() : this.skyCultureRegionFilterValues()
  }

  skyCultureFilterValue(kind: string): string {
    return kind === 'classification' ? this.skyCultureClassificationFilter : this.skyCultureRegionFilter
  }

  skyCultureFilterLabel(kind: string): string {
    return kind === 'classification' ? this.skyCultureClassificationFilterLabel() : this.skyCultureRegionFilterLabel()
  }

  skyCultureFilterSelectedIndex(kind: string): number {
    const index = this.skyCultureFilterValues(kind).indexOf(this.skyCultureFilterValue(kind))
    return index >= 0 ? index : 0
  }

  skyCultureDisplayName(id: string, rawName: string): string {
    if (id !== 'tibetan') return rawName
    const language = I18n.getLanguage()
    if (language === 'zh_CN') return '中国藏族星空文化'
    if (language === 'zh_HK' || language === 'zh_TW') return '中國藏族星空文化'
    if (language === 'en') return 'Tibetan Sky Culture (China)'
    const qualifiers: Record<string, string> = {
      'ar': 'الصين', 'bn': 'চীন', 'cs': 'Čína', 'da': 'Kina', 'de': 'China',
      'el': 'Κίνα', 'es': 'China', 'fa': 'چین', 'fi': 'Kiina', 'fr': 'Chine',
      'gu': 'ચીન', 'he': 'סין', 'hi': 'चीन', 'hr': 'Kina', 'hu': 'Kína',
      'id': 'Tiongkok', 'it': 'Cina', 'ja': '中国', 'ko': '중국', 'ml': 'ചൈന',
      'mr': 'चीन', 'ms': 'China', 'nb': 'Kina', 'ne': 'चीन', 'nl': 'China',
      'pl': 'Chiny', 'pt': 'China', 'pt_BR': 'China', 'ro': 'China', 'ru': 'Китай',
      'si': 'චීනය', 'sk': 'Čína', 'sl': 'Kitajska', 'sv': 'Kina', 'ta': 'சீனா',
      'te': 'చైనా', 'th': 'จีน', 'uk': 'Китай', 'vi': 'Trung Quốc'
    }
    const qualifier = qualifiers[language] ?? 'China'
    return rawName + ' (' + qualifier + ')'
  }

  // —— 纯计算：元信息文案 ——
  skyCultureRegionText(regions: string[]): string {
    const translated: Record<string, string> = {
      'Australasia': '澳大拉西亚', 'Central America': '中美洲', 'Eastern Asia': '东亚',
      'Eastern Europe': '东欧', 'Melanesia': '美拉尼西亚', 'Northern Africa': '北非',
      'Northern America': '北美洲', 'Northern Asia': '北亚', 'Northern Europe': '北欧',
      'Polynesia': '波利尼西亚', 'South America': '南美洲', 'South-eastern Asia': '东南亚',
      'Southern Africa': '南部非洲', 'Southern Asia': '南亚', 'Southern Europe': '南欧',
      'Western Asia': '西亚', 'Western Europe': '西欧', 'World': '全球',
    }
    const names: string[] = []
    for (let index = 0; index < regions.length; index++) {
      names.push(translated[regions[index]] ?? regions[index])
    }
    return names.length > 0 ? names.join('、') : '未标注地区'
  }

  skyCultureClassificationText(classification: string): string {
    const translated: Record<string, string> = {
      'traditional': '传统传承', 'ethnographic': '民族志记录', 'historical': '历史复原',
      'single': '单一史料', 'comparative': '比较呈现', 'personal': '个人创作', 'incomplete': '资料待完善',
    }
    return translated[classification] ?? '资料待完善'
  }

  skyCultureBoundaryTypeText(boundariesType: string): string {
    if (boundariesType === 'iau') return '国际天文学联合会边界'
    if (boundariesType === 'own') return '本文化自定义边界'
    return '未定义边界'
  }

  skyCultureTimeRange(): string {
    if (this.skyCultureBeginTime === 0 && this.skyCultureEndTime === 0) return '年代范围未标注'
    const start = this.skyCultureBeginTime === 0 ? '早期' : this.skyCultureFormatYear(this.skyCultureBeginTime)
    const end = this.skyCultureEndTime >= 9000 ? '至今' : (this.skyCultureEndTime === 0 ? '至今' : this.skyCultureFormatYear(this.skyCultureEndTime))
    return start + ' 至 ' + end
  }

  skyCultureSimulationTimeMatches(): boolean {
    if (this.skyCultureBeginTime === 0 && this.skyCultureEndTime === 0) return true
    const beginsBeforeYear = this.skyCultureBeginTime === 0 || this.skyCultureSimulationYear >= this.skyCultureBeginTime
    const endsAfterYear = this.skyCultureEndTime === 0 || this.skyCultureEndTime >= 9000 || this.skyCultureSimulationYear <= this.skyCultureEndTime
    return beginsBeforeYear && endsAfterYear
  }

  skyCultureSimulationTimeStatus(): string {
    if (this.skyCultureBeginTime === 0 && this.skyCultureEndTime === 0) return '当前模拟时间：该文化未标注适用年代'
    return this.skyCultureSimulationTimeMatches()
      ? '当前模拟时间：在该文化适用年代内'
      : '当前模拟时间：不在该文化适用年代内'
  }

  skyCultureFormatYear(year: number): string {
    return year < 0 ? '公元前 ' + Math.abs(year) + ' 年' : '公元 ' + year + ' 年'
  }

  // —— 纯计算：年代输入 ——
  setSkyCultureTimeYear(year: number): void {
    const clamped = Math.max(-40000, Math.min(this.skyCultureFilterMaxYear(), Math.round(year)))
    this.skyCultureTimeYear = clamped
    this.skyCultureTimeYearInput = clamped.toString()
  }

  setSkyCultureRange(startYear: number, endYear: number): void {
    const maxYear = this.skyCultureFilterMaxYear()
    const start = Math.max(-40000, Math.min(maxYear, Math.round(startYear)))
    const end = Math.max(start, Math.min(maxYear, Math.round(endYear)))
    this.skyCultureRangeStart = start
    this.skyCultureRangeEnd = end
    this.skyCultureRangeStartInput = start.toString()
    this.skyCultureRangeEndInput = end.toString()
  }

  applySkyCultureRangeInput(): void {
    const start = parseInt(this.skyCultureRangeStartInput, 10)
    const end = parseInt(this.skyCultureRangeEndInput, 10)
    if (Number.isNaN(start) || Number.isNaN(end)) {
      this.skyCultureRangeStartInput = this.skyCultureRangeStart.toString()
      this.skyCultureRangeEndInput = this.skyCultureRangeEnd.toString()
      return
    }
    this.setSkyCultureRange(start, end)
  }

  applySkyCultureTimeYearInput(): void {
    const year = parseInt(this.skyCultureTimeYearInput, 10)
    if (Number.isNaN(year)) {
      this.skyCultureTimeYearInput = this.skyCultureTimeYear.toString()
      return
    }
    this.setSkyCultureTimeYear(year)
  }

  // —— 纯计算：领地地图 ——
  skyCultureTerritoryIncludesYear(entry: SkyCultureTerritoryEntry, year: number): boolean {
    const beginsBeforeYear = entry.beginTime === 0 || year >= entry.beginTime
    const endsAfterYear = entry.endTime === 0 || entry.endTime >= 9000 || year <= entry.endTime
    return beginsBeforeYear && endsAfterYear
  }

  skyCultureTerritoryEntriesForSelectedYear(): Array<SkyCultureTerritoryEntry> {
    return this.skyCultureTerritoryArchive.filter((entry: SkyCultureTerritoryEntry) => this.skyCultureTerritoryIncludesYear(entry, this.skyCultureTimeYear))
  }

  skyCultureTerritoryMapMaxYear(): number {
    return Math.min(10000, this.skyCultureFilterMaxYear())
  }

  setSkyCultureTerritoryMapYear(year: number): void {
    const clamped = Math.max(-40000, Math.min(this.skyCultureTerritoryMapMaxYear(), Math.round(year)))
    this.skyCultureTerritoryMapYear = clamped
    this.skyCultureTerritoryMapYearInput = clamped.toString()
  }

  applySkyCultureTerritoryMapYearInput(): void {
    const year = parseInt(this.skyCultureTerritoryMapYearInput, 10)
    if (Number.isNaN(year)) {
      this.skyCultureTerritoryMapYearInput = this.skyCultureTerritoryMapYear.toString()
      return
    }
    this.setSkyCultureTerritoryMapYear(year)
  }

  syncSkyCultureTerritoryMapYearToSimulation(): void {
    this.setSkyCultureTerritoryMapYear(this.skyCultureSimulationYear)
  }

  skyCultureMapRotationAngle(): number {
    return this.skyCultureMapUseLocationRotation && this.skyCultureObserverLatitude < 0 ? 180 : 0
  }

  skyCultureTerritoryRange(entry: SkyCultureTerritoryEntry): string {
    const start = entry.beginTime === 0 ? '早期' : this.skyCultureFormatYear(entry.beginTime)
    const end = entry.endTime === 0 || entry.endTime >= 9000 ? '至今' : this.skyCultureFormatYear(entry.endTime)
    return start + ' 至 ' + end
  }
}
