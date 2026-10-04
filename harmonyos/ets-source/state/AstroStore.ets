// 天文计算面板（astro）状态（原宿主 @State 的 astro 域字段，Phase 4l）。
//
// 面板 UI 已下沉到 panels/astro/AstroPanel.ets，以 @ObjectLink 观察本 store；
// 宿主保留 astro 域的加载/导出/路由/持久化方法（它们继续写本 store），
// 组件通过注入的回调（AstroPanelHost）驱动这些方法。
// 高频/跨域字段（夜视三色、objectDetailStore、wutStore、Scroller）不进本 store。
//
// review §2.7 续作：食相起始日期 eclipseStartYear/Month/Day 属天文派生域，并入本 store
// （原宿主 @State，仅被 eclipseStartOptionLabel / chooseEclipseStartDate / resolveEclipseStartJD
// 读写；AstroPanel 经 eclipseStartOptionLabel 回调展示该日期，故放被观察 store 一致）。
// 续作第二批：RTS 日历起始日期 rtsCalendarStartYear/Month/Day 与年度高度图起始日期
// graphStartYear/Month/Day（原宿主 @State，宿主日期选择器回调读写，AstroPanel 经 host 回调消费）。
import { TonightEvents, EphemerisRow, AstroCalcContext, RtsCalendarDay, AltAzPoint, AnnualElevationPoint, ObservabilityDay, LunarElongationPoint, PlanetTimeSeriesPoint, PlanetPairDistancePoint, PlanetCalcItem, PhenomenonItem, EclipseItem, PlanetaryTransitItem, MoonPhaseItem, SeasonEvent, PlanetPosition, HeliocentricPosition, CelestialPosition, StellariumBridgeResponse } from '../pages/StellariumTypes'
import { EphemerisOptions, RtsCalendarOptions, EclipseOptions, PhenomenaOptions, HeliocentricPositionOptions, CelestialPositionOptions, AstroCsvExport } from '../pages/MainWindowModels'
import { CommandPort } from '../bridge/CommandPort'
import { dateToJD, graphModeLabel, graphStartOptionLabel, hourOffsetLabel, planetPairBodyName } from '../common/derive/astro'
import { zhNameOf } from '../common/derive/labels'
import { csvCell } from '../common/derive/skycult'

// 本域辅助端口接口（§14.8：store 不 import NAPI/UI，跨 store / 未下沉宿主逻辑经具名回调注入）。
export interface AstroHostHooks {
  // 跨域读取（objectDetailStore：选中天体）
  hasSelectedObject(): boolean
  selectedObjectName(): string
  // 跨 store 读取（WutStore：astro tab5 摘要 / 今晚观测联动）
  wutCategory(): string
  wutObservationTime(): string
  loadWutTargets(): void
  // 跨 store 读取（EphemerisStore：星历「指定日期」起始 JD）
  ephemerisCustomStartJD(): number
  // 未随本片下沉的宿主助手 / 加载器
  fmtDateTime(s: string | undefined): string
  hecLayoutPositions(positions: Array<HeliocentricPosition>): Array<HeliocentricPosition>
  loadPlanetPositions(): void
}

@Observed
export class AstroStore {
  astroTab: number = 5   // 天文计算面板子标签索引
  astroGroup: number = 0 // 天文计算一级导航分组
  astroContentOpacity: number = 1
  astroContentOffsetX: number = 0
  rtsData: Map<string, string> = new Map()
  rtsError: string = ''
  rtsLoading: boolean = false
  rtsCalendarData: Array<RtsCalendarDay> = []
  rtsCalendarName: string = ''
  rtsCalendarError: string = ''
  rtsCalendarDays: number = 14
  rtsCalendarStartOffsetDays: number = 0
  // RTS 日历「指定日期」起始模型（原宿主 @State，review §2.7）。
  // 宿主 resolveRtsCalendarStartJD / rtsCalendarStartOptionLabel / chooseRtsCalendarStartDate 读写，
  // AstroPanel 经 host.rtsCalendarStartOptionLabel / host.chooseRtsCalendarStartDate 消费。
  rtsCalendarStartYear: number = new Date().getFullYear()
  rtsCalendarStartMonth: number = new Date().getMonth() + 1
  rtsCalendarStartDay: number = new Date().getDate()
  rtsCalendarLoading: boolean = false
  rtsCalendarNeedsGeneration: boolean = false
  rtsCalendarProgress: number = 0
  rtsCalendarTotalDays: number = 0
  almanacData: Map<string, string> = new Map()
  almanacLoading: boolean = false
  almanacError: string = ''
  almanacSeasons: Array<SeasonEvent> = []
  almanacSeasonYear: string = ''
  planetPositions: Array<PlanetPosition> = []
  planetPositionsLoading: boolean = false
  planetPositionsError: string = ''
  positionMode: number = 0
  hecPositions: Array<HeliocentricPosition> = []
  hecPositionsLoading: boolean = false
  hecPositionsError: string = ''
  hecTime: string = ''
  hecIncludeSelectedMinor: boolean = false
  hecIncludeBrightComets: boolean = false
  hecCometMagnitudeLimit: number = 9
  celestialPositions: Array<CelestialPosition> = []
  celestialPositionsLoading: boolean = false
  celestialPositionsError: string = ''
  celestialPositionCategory: string = 'planets'
  celestialPositionMagnitude: number = 6
  celestialPositionHorizontal: boolean = true
  celestialPositionTime: string = ''
  ephemerisData: Array<EphemerisRow> = []
  ephemerisName: string = ''
  ephemerisMeta: string = ''
  ephemerisError: string = ''
  ephemerisDays: number = 14
  ephemerisStepHours: number = 24
  ephemerisStartOffsetDays: number = 0
  ephemerisMode: number = 0
  ephemerisPrimary: string = 'Moon'
  ephemerisSecondary: string = 'Sun'
  ephemerisLoading: boolean = false
  planetCalcData: Array<PlanetCalcItem> = []
  planetCalcLoading: boolean = false
  planetCalcError: string = ''
  planetCalcMode: number = 0
  planetPairDistanceData: Array<PlanetPairDistancePoint> = []
  planetPairDistanceError: string = ''
  planetPairDistanceLoading: boolean = false
  planetPairFirst: string = 'Sun'
  planetPairSecond: string = 'Moon'
  planetPairFirstName: string = '太阳'
  planetPairSecondName: string = '月亮'
  planetPairDays: number = 40
  planetPairStepDays: number = 4
  planetPairAngularAvailable: boolean = true
  planetPairLinearMin: number = 0
  planetPairLinearMax: number = 1
  planetPairAngularMin: number = 0
  planetPairAngularMax: number = 180
  altAzCurve: Array<AltAzPoint> = []
  altAzName: string = ''
  altAzError: string = ''
  altAzHours: number = 24
  altAzStepMin: number = 30
  altAzShowSun: boolean = false
  altAzShowMoon: boolean = false
  altAzMinimum: number = -90
  graphStartOffsetDays: number = 0
  // 年度高度图「指定日期」起始模型（原宿主 @State，review §2.7）。
  // 宿主 resolveGraphStartJD / graphCustomStartLabel / chooseGraphStartDate 读写，
  // AstroPanel 经 host.graphCustomStartLabel / host.chooseGraphStartDate 消费。
  graphStartYear: number = new Date().getFullYear()
  graphStartMonth: number = new Date().getMonth() + 1
  graphStartDay: number = new Date().getDate()
  graphMode: number = 0
  graphLoading: boolean = false
  annualElevationData: Array<AnnualElevationPoint> = []
  annualElevationName: string = ''
  annualElevationError: string = ''
  annualElevationHour: number = 0
  annualElevationMinimum: number = -90
  observabilityData: Array<ObservabilityDay> = []
  observabilityName: string = ''
  observabilityError: string = ''
  observabilityProgress: string = ''
  observabilityDays: number = 30
  observabilityMinAltitude: number = 20
  lunarElongationData: Array<LunarElongationPoint> = []
  lunarElongationName: string = ''
  lunarElongationError: string = ''
  lunarElongationDays: number = 30
  lunarElongationStepHours: number = 12
  lunarElongationLimit: number = 40
  planetTimeSeriesData: Array<PlanetTimeSeriesPoint> = []
  planetTimeSeriesName: string = ''
  planetTimeSeriesError: string = ''
  planetTimeSeriesDays: number = 30
  planetTimeSeriesStepHours: number = 24
  planetTimeSeriesLeftMetric: string = 'angularSize'
  planetTimeSeriesRightMetric: string = 'magnitude'
  planetTimeSeriesLeftMin: number = 0
  planetTimeSeriesLeftMax: number = 1
  planetTimeSeriesRightMin: number = 0
  planetTimeSeriesRightMax: number = 1
  eclipseData: Array<EclipseItem> = []
  eclipseMonths: number = 36
  eclipseStartOffsetDays: number = 0
  eclipseStartYear: number = new Date().getFullYear()
  eclipseStartMonth: number = new Date().getMonth() + 1
  eclipseStartDay: number = new Date().getDate()
  eclipseLoading: boolean = false
  eclipseError: string = ''
  eclipseKindFilter: number = 0
  eclipseTypeFilter: number = 0
  eclipseMode: number = 0
  planetaryTransitData: Array<PlanetaryTransitItem> = []
  planetaryTransitYears: number = 20
  planetaryTransitLoaded: boolean = false
  planetaryTransitLoading: boolean = false
  planetaryTransitError: string = ''
  moonPhaseData: Array<MoonPhaseItem> = []
  moonPhaseDays: number = 30
  moonPhaseLoading: boolean = false
  moonPhaseError: string = ''
  phenomenaData: Array<PhenomenonItem> = []
  phenomenaHint: string = ''
  phenomenaLoading: boolean = false
  phenomenaPrimary: string = 'all'
  phenomenaTarget: string = 'all'
  phenomenaDays: number = 400
  phenomenaStartOffsetMonths: number = 0
  phenomenaMaxSeparation: number = 4
  phenomenaIncludeOppositions: boolean = true
  phenomenaIncludePerihelionAphelion: boolean = true
  phenomenaIncludeElongationsQuadratures: boolean = true
  phenomenaIncludeStations: boolean = true
  astroExporting: boolean = false
  astroContext: AstroCalcContext | undefined = undefined
  astroCalcSnapshot: string = ''
  tonightAstro: TonightEvents | null = null

  // —— §14 B2A：Astro 簇加载器下沉（19 个中的 18 个；loadWutTargets 见 state/WutStore.ets） ——
  //
  // 桥端口复用宿主同一 HostCommandPort 实例；store 只依赖 CommandPort 接口（不 import NAPI/UI）。
  // 跨 store（WutStore / EphemerisStore / objectDetailStore）与未随本片下沉的宿主加载器
  // （loadPlanetPositions）经 AstroHostHooks 具名注入；月相 / 天文计算上下文加载器已在
  // §14 B3-2 连同其请求态一起下沉本 store（宿主计时器只调用，不再持有请求态裸字段）。
  // 请求序号/代际随对应加载器搬入本 store（各自独立字段；宿主不再保留同名序号）。
  private port: CommandPort | null = null
  private onChanged: (() => void) | null = null
  private hooks: AstroHostHooks | null = null
  private rtsRequestSequence: number = 0
  private rtsCalendarLoadSequence: number = 0
  private ephemerisLoadSequence: number = 0
  private planetCalcRequestSequence: number = 0
  private planetPairDistanceRequestSequence: number = 0
  private graphLoadSequence: number = 0
  private eclipseLoadSequence: number = 0
  private planetaryTransitRequestSequence: number = 0
  private phenomenaRequestSequence: number = 0
  private almanacRequestSequence: number = 0
  private hecPositionsRequestSequence: number = 0
  private celestialPositionsRequestSequence: number = 0
  // §14 B3-2：月相 / 天文计算上下文的请求态（原宿主裸字段 moonPhaseRequestId /
  // moonPhaseLoadingDays / astroContextRequestId / astroContextRequestPending 随加载器搬入）。
  private moonPhaseRequestSequence: number = 0
  private moonPhaseLoadingDays: number = 0
  private astroContextRequestSequence: number = 0
  private astroContextRequestPending: boolean = false

  // 宿主在 aboutToAppear 注入端口与发布回调（onChanged 即 publishAstroPanelState；幂等）。
  attachPort(port: CommandPort, onChanged: () => void): void {
    this.port = port
    this.onChanged = onChanged
  }

  attachHooks(hooks: AstroHostHooks): void {
    this.hooks = hooks
  }

  private ensurePort(): CommandPort | null {
    return this.port
  }

  private notifyChanged(): void {
    if (this.onChanged !== null) {
      this.onChanged()
    }
  }

  private hasSelected(): boolean {
    const hooks = this.hooks
    return hooks !== null && hooks.hasSelectedObject()
  }

  graphTargetLabel(): string {
    const hooks = this.hooks
    if (hooks === null) {
      return '尚未选择天体'
    }
    const name = hooks.selectedObjectName()
    if (name.length === 0) {
      return '尚未选择天体'
    }
    return zhNameOf(name)
  }

  phenomenaBodyName(body: string): string {
    return body === 'all' ? '全部行星' : planetPairBodyName(body)
  }

  updateAstroCalcSnapshot(): void {
    if (this.astroTab === 0) {
      const mode = this.positionMode === 0 ? '地平位置' : (this.positionMode === 1 ? '日心黄道' : '目录天体')
      this.astroCalcSnapshot = mode + (this.positionMode === 2 ? ' · 星等 ≤ ' + this.celestialPositionMagnitude.toFixed(1) : '')
      return
    }
    if (this.astroTab === 1) {
      const target = this.ephemerisMode === 0 ? '当前选中天体' : (this.ephemerisMode === 1 ? '两个天体' : '全部肉眼行星')
      this.astroCalcSnapshot = target + ' · ' + this.ephemerisDays.toString() + ' 天 · 每 ' + this.ephemerisStepHours.toString() + ' 小时'
      return
    }
    if (this.astroTab === 2) {
      this.astroCalcSnapshot = '升中天落 · ' + this.rtsCalendarDays.toString() + ' 天 · ' + (this.hasSelected() ? this.graphTargetLabel() : '未选择天体')
      return
    }
    if (this.astroTab === 3) {
      this.astroCalcSnapshot = this.phenomenaBodyName(this.phenomenaPrimary) + ' / ' + this.phenomenaBodyName(this.phenomenaTarget) + ' · ' + this.phenomenaDays.toString() + ' 天'
      return
    }
    if (this.astroTab === 4) {
      let detail = ''
      if (this.graphMode === 0 || this.graphMode === 1) {
        detail = this.altAzHours.toString() + ' 小时 · 每 ' + this.altAzStepMin.toString() + ' 分钟'
      } else if (this.graphMode === 2) {
        detail = '每日 ' + this.annualElevationHour.toString().padStart(2, '0') + ':00'
      } else if (this.graphMode === 3) {
        detail = this.observabilityDays.toString() + ' 天 · 最低 ' + this.observabilityMinAltitude.toString() + '°'
      } else if (this.graphMode === 4) {
        detail = this.lunarElongationDays.toString() + ' 天 · 每 ' + this.lunarElongationStepHours.toString() + ' 小时'
      } else {
        detail = this.planetTimeSeriesDays.toString() + ' 天 · 每 ' + this.planetTimeSeriesStepHours.toString() + ' 小时'
      }
      this.astroCalcSnapshot = graphModeLabel(this.graphMode) + ' · ' + this.graphTargetLabel() + ' · '
        + graphStartOptionLabel(this.graphStartOffsetDays) + ' · ' + detail
      return
    }
    if (this.astroTab === 5) {
      const hooks = this.hooks
      this.astroCalcSnapshot = '今晚可观测 · ' + (hooks !== null ? hooks.wutCategory() : '') + ' · ' + (hooks !== null ? hooks.wutObservationTime() : '')
      return
    }
    if (this.astroTab === 6) {
      this.astroCalcSnapshot = this.planetCalcMode === 0 ? '行星实时位置' : planetPairBodyName(this.planetPairFirst)
        + ' / ' + planetPairBodyName(this.planetPairSecond) + ' · ' + this.planetPairDays.toString() + ' 天'
      return
    }
    if (this.astroTab === 7) {
      this.astroCalcSnapshot = (this.eclipseMode === 0 ? '日月食' : '行星凌日') + ' · ' + (this.eclipseMode === 0 ? this.eclipseMonths.toString() + ' 个月' : this.planetaryTransitYears.toString() + ' 年')
      return
    }
    if (this.astroTab === 9) {
      this.astroCalcSnapshot = '月相 · 未来 ' + this.moonPhaseDays.toString() + ' 天'
      return
    }
    if (this.astroTab === 8) {
      this.astroCalcSnapshot = '年历 · 当前模拟日期 · 当前观测地点'
      return
    }
    this.astroCalcSnapshot = ''
  }

  // 升中天落（RTS）：原宿主 loadRTS，函数体逐字搬入；仅 this.callInteractive → port.requestInteractive、
  // this.astroStore.<f> → this.<f>、this.hasSelectedObject() → this.hasSelected()。
  loadRTS(): void {
    this.updateAstroCalcSnapshot()
    const requestId = ++this.rtsRequestSequence
    this.rtsError = ''
    this.rtsLoading = true
    if (!this.hasSelected()) {
      this.rtsLoading = false
      this.clearRtsSelectionResults()
      return
    }
    const port = this.ensurePort()
    if (port === null) {
      this.rtsLoading = false
      return
    }
    port.requestInteractive('getRTS', '', (r: StellariumBridgeResponse) => {
      if (requestId !== this.rtsRequestSequence) return
      this.rtsLoading = false
      if (r.ok === true && r.rts !== undefined) {
        const rv = r.rts as Record<string, Object>
        const data = new Map<string, string>()
        data.set('name', rv['name'] !== undefined ? rv['name'] as string : 'N/A')
        data.set('nextRiseJD', rv['nextRiseJD'] !== undefined ? String(rv['nextRiseJD']) : '0')
        data.set('nextTransitJD', rv['nextTransitJD'] !== undefined ? String(rv['nextTransitJD']) : '0')
        data.set('nextSetJD', rv['nextSetJD'] !== undefined ? String(rv['nextSetJD']) : '0')
        data.set('prevRiseJD', rv['prevRiseJD'] !== undefined ? String(rv['prevRiseJD']) : '0')
        data.set('prevTransitJD', rv['prevTransitJD'] !== undefined ? String(rv['prevTransitJD']) : '0')
        data.set('prevSetJD', rv['prevSetJD'] !== undefined ? String(rv['prevSetJD']) : '0')
        data.set('nextRiseText', rv['nextRiseText'] !== undefined ? String(rv['nextRiseText']) : (rv['nextRiseJD'] !== undefined ? String(rv['nextRiseJD']) : '0'))
        data.set('nextTransitText', rv['nextTransitText'] !== undefined ? String(rv['nextTransitText']) : (rv['nextTransitJD'] !== undefined ? String(rv['nextTransitJD']) : '0'))
        data.set('nextSetText', rv['nextSetText'] !== undefined ? String(rv['nextSetText']) : (rv['nextSetJD'] !== undefined ? String(rv['nextSetJD']) : '0'))
        data.set('prevRiseText', rv['prevRiseText'] !== undefined ? String(rv['prevRiseText']) : (rv['prevRiseJD'] !== undefined ? String(rv['prevRiseJD']) : '0'))
        data.set('prevTransitText', rv['prevTransitText'] !== undefined ? String(rv['prevTransitText']) : (rv['prevTransitJD'] !== undefined ? String(rv['prevTransitJD']) : '0'))
        data.set('prevSetText', rv['prevSetText'] !== undefined ? String(rv['prevSetText']) : (rv['prevSetJD'] !== undefined ? String(rv['prevSetJD']) : '0'))
        this.rtsData = data
      } else {
        this.rtsData = new Map()
        this.rtsError = r.error ?? '请先在星图上选中一个天体，再计算升中天落。'
      }
    }, () => {
      if (requestId !== this.rtsRequestSequence) return
      this.rtsLoading = false
      this.rtsData = new Map()
      this.rtsError = '升中天落计算失败，请点刷新后重试。'
    })
  }

  clearRtsSelectionResults(): void {
    ++this.rtsRequestSequence
    this.rtsLoading = false
    this.rtsData = new Map()
    this.rtsError = '升起、中天和落下时间需要先选择一个天体。'
    this.rtsCalendarData = []
    this.rtsCalendarName = ''
    this.rtsCalendarLoading = false
    this.rtsCalendarError = '请先选择一个天体，再生成升中天落日期表。'
    this.rtsCalendarNeedsGeneration = false
    this.rtsCalendarProgress = 0
    ++this.rtsCalendarLoadSequence
  }

  loadRtsCalendar(): void {
    this.updateAstroCalcSnapshot()
    const requestId = ++this.rtsCalendarLoadSequence
    this.rtsCalendarData = []
    this.rtsCalendarError = ''
    this.rtsCalendarNeedsGeneration = false
    if (!this.hasSelected()) {
      this.clearRtsSelectionResults()
      return
    }
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    this.rtsCalendarLoading = true
    this.rtsCalendarProgress = 0
    this.rtsCalendarTotalDays = this.rtsCalendarDays
    this.resolveRtsCalendarStartJD(requestId, (startJD: number) => {
      const options: RtsCalendarOptions = { days: this.rtsCalendarDays }
      if (startJD > 0) options.jd = startJD
      port.requestLongRunning('getRTSCalendar', JSON.stringify(options), (r: StellariumBridgeResponse) => {
        if (requestId !== this.rtsCalendarLoadSequence) return
        this.rtsCalendarLoading = false
        if (r.ok === true && r.rtsCalendar !== undefined) {
          this.rtsCalendarData = r.rtsCalendar as Array<RtsCalendarDay>
          this.rtsCalendarName = r.name ?? ''
          this.rtsCalendarProgress = this.rtsCalendarDays
        } else {
          this.rtsCalendarError = '请先在星图上选中一个天体，再生成升中天落日期表。'
        }
      }, () => {
        if (requestId !== this.rtsCalendarLoadSequence) return
        this.rtsCalendarLoading = false
        this.rtsCalendarError = '日期表计算时间较长，请缩短时长后重试。'
      }, (progress: StellariumBridgeResponse) => {
        if (requestId !== this.rtsCalendarLoadSequence) return
        const completed = Number(progress.progress)
        const total = Number(progress.totalDays)
        if (Number.isFinite(completed) && completed > 0) this.rtsCalendarProgress = completed
        if (Number.isFinite(total) && total > 0) this.rtsCalendarTotalDays = total
      }, 480)
    }, () => {
      if (requestId !== this.rtsCalendarLoadSequence) return
      this.rtsCalendarLoading = false
      this.rtsCalendarError = '无法读取当前模拟时间，请点生成日期表后重试。'
    })
  }

  markRtsCalendarForRegeneration(): void {
    ++this.rtsCalendarLoadSequence
    this.rtsCalendarLoading = false
    this.rtsCalendarData = []
    this.rtsCalendarError = ''
    this.rtsCalendarNeedsGeneration = true
    this.rtsCalendarProgress = 0
    this.rtsCalendarTotalDays = 0
  }

  private resolveRtsCalendarStartJD(requestId: number, onReady: (startJD: number) => void, onFailure: () => void): void {
    if (this.rtsCalendarStartOffsetDays < 0) {
      onReady(dateToJD(this.rtsCalendarStartYear, this.rtsCalendarStartMonth, this.rtsCalendarStartDay, 0, 0))
      return
    }
    if (this.rtsCalendarStartOffsetDays === 0) {
      onReady(0)
      return
    }
    const port = this.ensurePort()
    if (port === null) {
      onFailure()
      return
    }
    port.requestInteractive('getState', '', (state: StellariumBridgeResponse) => {
      if (requestId !== this.rtsCalendarLoadSequence) return
      const currentJD = Number(state.jd)
      if (state.ok === true && Number.isFinite(currentJD) && currentJD > 0) {
        onReady(currentJD + this.rtsCalendarStartOffsetDays)
        return
      }
      onFailure()
    }, () => {
      if (requestId !== this.rtsCalendarLoadSequence) return
      onFailure()
    })
  }

  // 星历表：原宿主 loadEphemeris。callNativeWhenReady 的 (name,payload,onOk,attempt,intervalMs,maxAttempts,onFailure)
  // 按端口签名前移为 (name,payload,onOk,onFailure,attempt,intervalMs,maxAttempts)；原重试档 0/100/80 保留。
  loadEphemeris(): void {
    this.updateAstroCalcSnapshot()
    const requestId = ++this.ephemerisLoadSequence
    this.ephemerisData = []
    this.ephemerisName = ''
    this.ephemerisError = ''
    this.ephemerisLoading = true
    const port = this.ensurePort()
    if (port === null) {
      this.ephemerisLoading = false
      return
    }
    this.resolveEphemerisStartJD(requestId, (startJD: number) => {
      const options: EphemerisOptions = { days: this.ephemerisDays, stepHours: this.ephemerisStepHours }
      if (startJD > 0) options.jd = startJD
      if (this.ephemerisMode === 1) options.names = [this.ephemerisPrimary, this.ephemerisSecondary]
      if (this.ephemerisMode === 2) options.allNakedEye = true
      port.requestWhenReady('getEphemeris', JSON.stringify(options), (r: StellariumBridgeResponse) => {
        if (requestId !== this.ephemerisLoadSequence) return
        this.ephemerisLoading = false
        if (r.ok === true && r.ephemeris !== undefined) {
          this.ephemerisData = r.ephemeris as Array<EphemerisRow>
          this.ephemerisName = r.name !== undefined ? String(r.name) : ''
          const location = r.observerLocation !== undefined ? String(r.observerLocation) : ''
          const timeZone = r.timeZone !== undefined ? String(r.timeZone) : ''
          const frame = r.coordinateFrame !== undefined ? String(r.coordinateFrame) : 'J2000'
          const hooks = this.hooks
          const calculatedAt = r.calculationTime !== undefined && hooks !== null ? hooks.fmtDateTime(String(r.calculationTime)) : ''
          this.ephemerisMeta = '坐标系 ' + frame + (location.length > 0 ? ' · 观测地 ' + location : '')
            + (timeZone.length > 0 ? ' · 时区 ' + timeZone : '')
            + (calculatedAt.length > 0 ? ' · 计算于 ' + calculatedAt : '')
        } else {
          this.ephemerisMeta = ''
          this.ephemerisError = r.error ?? '请先在星图上选中一个天体，再生成它的星历。'
        }
      }, () => {
        if (requestId !== this.ephemerisLoadSequence) return
        this.ephemerisLoading = false
        this.ephemerisMeta = ''
        this.ephemerisError = '星历计算时间较长，请缩短时间范围或增大采样间隔后重试。'
      }, 0, 100, 80)
    }, () => {
      if (requestId !== this.ephemerisLoadSequence) return
      this.ephemerisLoading = false
      this.ephemerisMeta = ''
      this.ephemerisError = '无法读取当前模拟时间，请点刷新后重试。'
    })
  }

  private resolveEphemerisStartJD(requestId: number, onReady: (startJD: number) => void, onFailure: () => void): void {
    if (this.ephemerisStartOffsetDays < 0) {
      const hooks = this.hooks
      onReady(hooks !== null ? hooks.ephemerisCustomStartJD() : 0)
      return
    }
    if (this.ephemerisStartOffsetDays === 0) {
      onReady(0)
      return
    }
    const port = this.ensurePort()
    if (port === null) {
      onFailure()
      return
    }
    port.requestInteractive('getState', '', (state: StellariumBridgeResponse) => {
      if (requestId !== this.ephemerisLoadSequence) return
      const currentJD = Number(state.jd)
      if (state.ok === true && Number.isFinite(currentJD) && currentJD > 0) {
        onReady(currentJD + this.ephemerisStartOffsetDays)
        return
      }
      onFailure()
    }, () => {
      if (requestId !== this.ephemerisLoadSequence) return
      onFailure()
    })
  }

  loadPlanetCalc(): void {
    this.updateAstroCalcSnapshot()
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const requestId = ++this.planetCalcRequestSequence
    this.planetCalcData = []
    this.planetCalcError = ''
    this.planetCalcLoading = true
    port.requestInteractive('getPlanetCalc', '', (r: StellariumBridgeResponse) => {
      if (requestId !== this.planetCalcRequestSequence) return
      this.planetCalcLoading = false
      if (r.ok === true && r.planetCalc !== undefined) {
        this.planetCalcData = r.planetCalc as Array<PlanetCalcItem>
        if (this.planetCalcData.length === 0) this.planetCalcError = '当前没有可显示的行星数据。'
      } else {
        this.planetCalcError = r.error ?? '行星实时数据计算失败，请点刷新后重试。'
      }
    }, () => {
      if (requestId !== this.planetCalcRequestSequence) return
      this.planetCalcLoading = false
      this.planetCalcError = '行星实时数据计算失败，请点刷新后重试。'
    })
  }

  loadPlanetPairDistance(): void {
    this.updateAstroCalcSnapshot()
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const requestId = ++this.planetPairDistanceRequestSequence
    this.planetPairDistanceData = []
    this.planetPairDistanceError = ''
    this.planetPairDistanceLoading = true
    const options = JSON.stringify({
      first: this.planetPairFirst,
      second: this.planetPairSecond,
      days: this.planetPairDays,
      stepDays: this.planetPairStepDays
    })
    port.requestInteractive('getPlanetPairDistanceCurve', options, (r: StellariumBridgeResponse) => {
      if (requestId !== this.planetPairDistanceRequestSequence) return
      this.planetPairDistanceLoading = false
      if (r.ok === true && r.planetPairDistance !== undefined) {
        const data = r.planetPairDistance as Array<PlanetPairDistancePoint>
        this.planetPairDistanceData = data
        this.planetPairFirstName = planetPairBodyName(this.planetPairFirst)
        this.planetPairSecondName = planetPairBodyName(this.planetPairSecond)
        this.planetPairAngularAvailable = r.angularAvailable === true
        this.updatePlanetPairDistanceRanges(data)
      } else {
        this.planetPairDistanceData = []
        this.planetPairDistanceError = r.error ?? '请选择两个不同的太阳系天体。'
      }
    }, () => {
      if (requestId !== this.planetPairDistanceRequestSequence) return
      this.planetPairDistanceLoading = false
      this.planetPairDistanceError = '距离曲线计算失败，请点刷新后重试。'
    })
  }

  private updatePlanetPairDistanceRanges(data: Array<PlanetPairDistancePoint>): void {
    let linearMin: number = Number.MAX_VALUE
    let linearMax: number = -Number.MAX_VALUE
    let angularMin: number = Number.MAX_VALUE
    let angularMax: number = -Number.MAX_VALUE
    for (const point of data) {
      const linear: number = point.linearDistance ?? 0
      linearMin = Math.min(linearMin, linear)
      linearMax = Math.max(linearMax, linear)
      if (point.angularDistance !== undefined) {
        angularMin = Math.min(angularMin, point.angularDistance)
        angularMax = Math.max(angularMax, point.angularDistance)
      }
    }
    this.planetPairLinearMin = linearMin === Number.MAX_VALUE ? 0 : linearMin
    this.planetPairLinearMax = linearMax <= linearMin ? linearMin + 1 : linearMax
    this.planetPairAngularMin = angularMin === Number.MAX_VALUE ? 0 : angularMin
    this.planetPairAngularMax = angularMax <= angularMin ? angularMin + 1 : angularMax
  }

  loadAltAzCurve(): void {
    this.updateAstroCalcSnapshot()
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const requestId = this.beginGraphLoad()
    this.altAzCurve = []
    this.altAzError = ''
    this.resolveGraphStartJD(requestId, (startJD: number) => {
      port.requestInteractive('getAltAzCurve', JSON.stringify({
        jd: startJD,
        hours: this.altAzHours,
        stepMin: this.altAzStepMin,
        includeSun: this.graphMode === 0 && this.altAzShowSun,
        includeMoon: this.graphMode === 0 && this.altAzShowMoon
      }), (r: StellariumBridgeResponse) => {
        if (requestId !== this.graphLoadSequence) return
        this.finishGraphLoad(requestId)
        if (r.ok === true && r.curve !== undefined) {
          this.altAzCurve = r.curve as Array<AltAzPoint>
          this.altAzName = r.name !== undefined ? r.name : ''
          this.altAzError = ''
        } else {
          this.altAzCurve = []
          this.altAzError = '请先在星图上选中一个天体，再来看它的' + (this.graphMode === 0 ? '高度' : '方位角') + '曲线。'
        }
      }, () => {
        if (requestId !== this.graphLoadSequence) return
        this.finishGraphLoad(requestId)
        this.altAzError = '计算等待超时，请点刷新后重试。'
      })
    }, () => {
      this.altAzError = '无法读取当前模拟时间，请点刷新后重试。'
    })
  }

  loadObservabilityCalendar(): void {
    this.updateAstroCalcSnapshot()
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const requestId = this.beginGraphLoad()
    this.observabilityData = []
    this.observabilityError = ''
    this.observabilityProgress = '准备计算…'
    this.resolveGraphStartJD(requestId, (startJD: number) => {
      const options = JSON.stringify({ jd: startJD, days: this.observabilityDays, minAltitude: this.observabilityMinAltitude })
      port.requestLongRunning('getObservabilityCalendar', options, (r: StellariumBridgeResponse) => {
        if (requestId !== this.graphLoadSequence) return
        this.finishGraphLoad(requestId)
        this.observabilityProgress = ''
        if (r.ok === true && r.observability !== undefined) {
          this.observabilityData = r.observability as Array<ObservabilityDay>
          this.observabilityName = r.name ?? ''
        } else {
          this.observabilityData = []
          this.observabilityError = (r.error ?? '').toString().includes('no object')
            ? '请先在星图上选中一个天体，再查看它未来多晚的可见性。'
            : '观测窗口计算失败，请稍后重试。'
        }
      }, () => {
        if (requestId !== this.graphLoadSequence) return
        this.finishGraphLoad(requestId)
        this.observabilityProgress = ''
        this.observabilityError = '计算等待超时，请稍后重试。'
      }, (progress: StellariumBridgeResponse) => {
        if (requestId !== this.graphLoadSequence) return
        const completed = Number(progress.progress ?? 0)
        const total = Number(progress.totalDays ?? this.observabilityDays)
        this.observabilityProgress = '正在计算：' + Math.min(completed, total).toFixed(0) + ' / ' + total.toFixed(0) + ' 天'
      })
    }, () => {
      this.observabilityProgress = ''
      this.observabilityError = '无法读取当前模拟时间，请点刷新后重试。'
    })
  }

  loadAnnualElevation(): void {
    this.updateAstroCalcSnapshot()
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const requestId = this.beginGraphLoad()
    this.annualElevationData = []
    this.annualElevationError = ''
    port.requestInteractive('getAnnualElevation', JSON.stringify({ hour: this.annualElevationHour }), (r: StellariumBridgeResponse) => {
      if (requestId !== this.graphLoadSequence) return
      this.finishGraphLoad(requestId)
      if (r.ok === true && r.annualElevation !== undefined) {
        this.annualElevationData = r.annualElevation as Array<AnnualElevationPoint>
        this.annualElevationName = r.name ?? ''
      } else {
        this.annualElevationData = []
        this.annualElevationError = '请先在星图上选中一个天体，再生成全年高度曲线。'
      }
    }, () => {
      if (requestId !== this.graphLoadSequence) return
      this.finishGraphLoad(requestId)
      this.annualElevationError = '计算等待超时，请点刷新后重试。'
    })
  }

  loadLunarElongation(): void {
    this.updateAstroCalcSnapshot()
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const requestId = this.beginGraphLoad()
    this.lunarElongationData = []
    this.lunarElongationError = ''
    this.resolveGraphStartJD(requestId, (startJD: number) => {
      const options = JSON.stringify({ jd: startJD, days: this.lunarElongationDays, stepHours: this.lunarElongationStepHours })
      port.requestInteractive('getLunarElongationCurve', options, (r: StellariumBridgeResponse) => {
        if (requestId !== this.graphLoadSequence) return
        this.finishGraphLoad(requestId)
        if (r.ok === true && r.lunarElongation !== undefined) {
          this.lunarElongationData = r.lunarElongation as Array<LunarElongationPoint>
          this.lunarElongationName = r.name ?? ''
        } else {
          this.lunarElongationData = []
          this.lunarElongationError = '请先选中除月亮和人造卫星之外的天体，再生成月距曲线。'
        }
      }, () => {
        if (requestId !== this.graphLoadSequence) return
        this.finishGraphLoad(requestId)
        this.lunarElongationError = '计算等待超时，请点刷新后重试。'
      })
    }, () => {
      this.lunarElongationError = '无法读取当前模拟时间，请点刷新后重试。'
    })
  }

  loadPlanetTimeSeries(): void {
    this.updateAstroCalcSnapshot()
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const requestId = this.beginGraphLoad()
    this.planetTimeSeriesData = []
    this.planetTimeSeriesError = ''
    this.resolveGraphStartJD(requestId, (startJD: number) => {
      const options = JSON.stringify({
        jd: startJD,
        days: this.planetTimeSeriesDays,
        stepHours: this.planetTimeSeriesStepHours,
        leftMetric: this.planetTimeSeriesLeftMetric,
        rightMetric: this.planetTimeSeriesRightMetric
      })
      port.requestInteractive('getPlanetTimeSeries', options, (r: StellariumBridgeResponse) => {
        if (requestId !== this.graphLoadSequence) return
        this.finishGraphLoad(requestId)
        if (r.ok === true && r.timeSeries !== undefined) {
          const data = r.timeSeries as Array<PlanetTimeSeriesPoint>
          this.planetTimeSeriesData = data
          this.planetTimeSeriesName = r.name ?? ''
          this.updatePlanetTimeSeriesRanges(data)
        } else {
          this.planetTimeSeriesData = []
          this.planetTimeSeriesError = '请先选中一个太阳系天体（行星、太阳或月亮），再生成双曲线。'
        }
      }, () => {
        if (requestId !== this.graphLoadSequence) return
        this.finishGraphLoad(requestId)
        this.planetTimeSeriesError = '计算等待超时，请点刷新后重试。'
      })
    }, () => {
      this.planetTimeSeriesError = '无法读取当前模拟时间，请点刷新后重试。'
    })
  }

  private beginGraphLoad(): number {
    this.graphLoadSequence += 1
    this.graphLoading = true
    return this.graphLoadSequence
  }

  private finishGraphLoad(requestId: number): void {
    if (requestId === this.graphLoadSequence) this.graphLoading = false
  }

  private resolveGraphStartJD(requestId: number, onReady: (startJD: number) => void, onFailure: () => void): void {
    if (this.graphStartOffsetDays < 0) {
      onReady(dateToJD(this.graphStartYear, this.graphStartMonth, this.graphStartDay, 0, 0))
      return
    }
    if (this.graphStartOffsetDays === 0) {
      onReady(0)
      return
    }
    const port = this.ensurePort()
    if (port === null) {
      this.finishGraphLoad(requestId)
      onFailure()
      return
    }
    port.requestInteractive('getState', '', (state: StellariumBridgeResponse) => {
      if (requestId !== this.graphLoadSequence) return
      const currentJD = Number(state.jd)
      if (state.ok === true && Number.isFinite(currentJD) && currentJD > 0) {
        onReady(currentJD + this.graphStartOffsetDays)
        return
      }
      this.finishGraphLoad(requestId)
      onFailure()
    }, () => {
      if (requestId !== this.graphLoadSequence) return
      this.finishGraphLoad(requestId)
      onFailure()
    })
  }

  private updatePlanetTimeSeriesRanges(data: Array<PlanetTimeSeriesPoint>): void {
    let leftMin: number = Number.MAX_VALUE
    let leftMax: number = -Number.MAX_VALUE
    let rightMin: number = Number.MAX_VALUE
    let rightMax: number = -Number.MAX_VALUE
    for (const point of data) {
      const left: number = point.left ?? 0
      const right: number = point.right ?? 0
      leftMin = Math.min(leftMin, left)
      leftMax = Math.max(leftMax, left)
      rightMin = Math.min(rightMin, right)
      rightMax = Math.max(rightMax, right)
    }
    this.planetTimeSeriesLeftMin = leftMin === Number.MAX_VALUE ? 0 : leftMin
    this.planetTimeSeriesLeftMax = leftMax <= leftMin ? leftMin + 1 : leftMax
    this.planetTimeSeriesRightMin = rightMin === Number.MAX_VALUE ? 0 : rightMin
    this.planetTimeSeriesRightMax = rightMax <= rightMin ? rightMin + 1 : rightMax
  }

  // 日月食：原宿主 loadEclipses（callNativeWhenReady 重试档 0/100/200 保留）。
  loadEclipses(): void {
    this.updateAstroCalcSnapshot()
    if (this.eclipseData.length > 0 || this.eclipseLoading) return
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const requestId = ++this.eclipseLoadSequence
    this.eclipseLoading = true
    this.eclipseError = ''
    this.resolveEclipseStartJD(requestId, (startJD: number) => {
      const options: EclipseOptions = { months: this.eclipseMonths }
      if (startJD > 0) options.jd = startJD
      port.requestWhenReady('getEclipses', JSON.stringify(options), (r: StellariumBridgeResponse) => {
        if (requestId !== this.eclipseLoadSequence) return
        this.eclipseLoading = false
        if (r.ok === true && r.eclipses !== undefined) {
          this.eclipseData = r.eclipses as Array<EclipseItem>
          return
        }
        this.eclipseError = r.error ?? '日月食计算未能完成，请重试。'
      }, () => {
        if (requestId !== this.eclipseLoadSequence) return
        this.eclipseLoading = false
        this.eclipseError = '日月食计算时间较长，请缩短预测范围后重试。'
      }, 0, 100, 200)
    }, () => {
      if (requestId !== this.eclipseLoadSequence) return
      this.eclipseLoading = false
      this.eclipseError = '无法读取当前模拟时间，请重试。'
    })
  }

  reloadEclipses(): void {
    ++this.eclipseLoadSequence
    this.eclipseLoading = false
    this.eclipseData = []
    this.eclipseError = ''
    this.loadEclipses()
  }

  private resolveEclipseStartJD(requestId: number, onReady: (startJD: number) => void, onFailure: () => void): void {
    if (this.eclipseStartOffsetDays < 0) {
      onReady(dateToJD(this.eclipseStartYear, this.eclipseStartMonth, this.eclipseStartDay, 0, 0))
      return
    }
    if (this.eclipseStartOffsetDays === 0) {
      onReady(0)
      return
    }
    const port = this.ensurePort()
    if (port === null) {
      onFailure()
      return
    }
    port.requestInteractive('getState', '', (state: StellariumBridgeResponse) => {
      if (requestId !== this.eclipseLoadSequence) return
      const currentJD = Number(state.jd)
      if (state.ok === true && Number.isFinite(currentJD) && currentJD > 0) {
        onReady(currentJD + this.eclipseStartOffsetDays)
        return
      }
      onFailure()
    }, () => {
      if (requestId !== this.eclipseLoadSequence) return
      onFailure()
    })
  }

  // 行星凌日：原宿主 loadPlanetaryTransits（callNativeWhenReady 重试档 0/100/200 保留）。
  loadPlanetaryTransits(): void {
    this.updateAstroCalcSnapshot()
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    if (!this.planetaryTransitLoaded && !this.planetaryTransitLoading) {
      const requestId = ++this.planetaryTransitRequestSequence
      this.planetaryTransitLoading = true
      this.planetaryTransitError = ''
      port.requestWhenReady('getPlanetaryTransits', JSON.stringify({ years: this.planetaryTransitYears }), (r: StellariumBridgeResponse) => {
        if (requestId !== this.planetaryTransitRequestSequence) return
        this.planetaryTransitLoading = false
        if (r.ok === true && r.planetaryTransits !== undefined) {
          this.planetaryTransitData = r.planetaryTransits as Array<PlanetaryTransitItem>
          this.planetaryTransitError = ''
        } else {
          this.planetaryTransitError = '行星凌日只能按地球上的当前观测地点计算。'
        }
        this.planetaryTransitLoaded = true
      }, () => {
        if (requestId !== this.planetaryTransitRequestSequence) return
        this.planetaryTransitLoading = false
        this.planetaryTransitLoaded = true
        this.planetaryTransitError = '行星凌日计算时间较长，请缩短预测范围后重试。'
      }, 0, 100, 200)
    }
  }

  // 天象预报：原宿主 loadPhenomena（callNativeWhenReady 重试档 0/100/300 保留）。
  loadPhenomena(): void {
    this.updateAstroCalcSnapshot()
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const requestId = ++this.phenomenaRequestSequence
    this.phenomenaData = []
    this.phenomenaHint = ''
    this.phenomenaLoading = true
    const options: PhenomenaOptions = {
      bodyA: this.phenomenaPrimary,
      bodyB: this.phenomenaTarget,
      days: this.phenomenaDays,
      startOffsetMonths: this.phenomenaStartOffsetMonths,
      maxSeparation: this.phenomenaMaxSeparation,
      includeOppositions: this.phenomenaIncludeOppositions,
      includePerihelionAphelion: this.phenomenaIncludePerihelionAphelion,
      includeElongationsQuadratures: this.phenomenaIncludeElongationsQuadratures,
      includeStations: this.phenomenaIncludeStations,
    }
    port.requestWhenReady('getPhenomena', JSON.stringify(options), (r: StellariumBridgeResponse) => {
      if (requestId !== this.phenomenaRequestSequence) return
      this.phenomenaLoading = false
      if (r.ok === true && r.phenomena !== undefined) {
        this.phenomenaData = r.phenomena as Array<PhenomenonItem>
        if (this.phenomenaData.length === 0) this.phenomenaHint = '所选时段内没有符合角距条件的天象。'
      } else {
        this.phenomenaHint = r.error ?? '暂时无法完成天象计算，请稍后重试。'
      }
    }, () => {
      if (requestId !== this.phenomenaRequestSequence) return
      this.phenomenaLoading = false
      this.phenomenaHint = '计算时间较长，请缩短预测范围或减少比较对象后重试。'
    }, 0, 100, 300)
  }

  // 今晚观测：先取今晚事件（首段），再联动 Wut 目标加载（经 hooks，loadWutTargets 属 WutStore）。
  loadTonightAstro(): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    if (this.tonightAstro === null) {
      port.requestInteractive('getTonightEvents', '', (r: StellariumBridgeResponse) => {
        if (r.ok === true && r.tonight !== undefined) this.tonightAstro = r.tonight as TonightEvents
      })
    }
    const hooks = this.hooks
    if (hooks !== null) {
      hooks.loadWutTargets()
    }
  }

  // 年历：原宿主 loadAlmanac。
  loadAlmanac(): void {
    this.updateAstroCalcSnapshot()
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const requestId = ++this.almanacRequestSequence
    this.almanacSeasons = []
    this.almanacSeasonYear = ''
    this.almanacData = new Map()
    this.almanacError = ''
    this.almanacLoading = true
    port.requestInteractive('getAlmanac', '', (r: StellariumBridgeResponse) => {
      if (requestId !== this.almanacRequestSequence) return
      this.almanacLoading = false
      if (r.ok === true && r.almanac !== undefined) {
        const av = r.almanac as Record<string, Object>
        const textValue = (name: string): string => av[name + 'Text'] !== undefined ? String(av[name + 'Text']) : (av[name] !== undefined ? String(av[name]) : '0')
        const data = new Map<string, string>()
        data.set('sunRise', textValue('sunRise'))
        data.set('sunTransit', textValue('sunTransit'))
        data.set('sunSet', textValue('sunSet'))
        data.set('moonRise', textValue('moonRise'))
        data.set('moonTransit', textValue('moonTransit'))
        data.set('moonSet', textValue('moonSet'))
        data.set('civilRise', textValue('civilRise'))
        data.set('civilSet', textValue('civilSet'))
        data.set('nauticalRise', textValue('nauticalRise'))
        data.set('nauticalSet', textValue('nauticalSet'))
        data.set('astronomicalRise', textValue('astronomicalRise'))
        data.set('astronomicalSet', textValue('astronomicalSet'))
        data.set('daylightHours', av['daylightHours'] !== undefined ? String(av['daylightHours']) : '')
        data.set('nightHours', av['nightHours'] !== undefined ? String(av['nightHours']) : '')
        data.set('moonPhase', av['moonPhase'] !== undefined ? String(av['moonPhase']) : '0')
        this.almanacData = data
        if (Array.isArray(av['seasonEvents'])) this.almanacSeasons = av['seasonEvents'] as Array<SeasonEvent>
        if (av['seasonYear'] !== undefined) this.almanacSeasonYear = String(av['seasonYear'])
        if (this.almanacData.size === 0) this.almanacError = '当前没有可显示的年历数据。'
      } else {
        this.almanacError = r.error ?? '年历计算失败，请点刷新后重试。'
      }
    }, () => {
      if (requestId !== this.almanacRequestSequence) return
      this.almanacLoading = false
      this.almanacError = '年历计算失败，请点刷新后重试。'
    })
  }

  // 日心黄道位置：原宿主 loadHeliocentricPositions；hecLayoutPositions 属宿主渲染几何，经 hooks 注入。
  loadHeliocentricPositions(): void {
    this.updateAstroCalcSnapshot()
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const requestId = ++this.hecPositionsRequestSequence
    this.hecPositions = []
    this.hecPositionsError = ''
    this.hecPositionsLoading = true
    const options: HeliocentricPositionOptions = {
      includeSelectedMinor: this.hecIncludeSelectedMinor,
      includeBrightComets: this.hecIncludeBrightComets,
      cometMagnitudeLimit: this.hecCometMagnitudeLimit,
    }
    port.requestInteractive('getHeliocentricEclipticPositions', JSON.stringify(options), (r: StellariumBridgeResponse) => {
      if (requestId !== this.hecPositionsRequestSequence) return
      this.hecPositionsLoading = false
      if (r.ok === true && r.hecPositions !== undefined) {
        const positions = (r.hecPositions as Array<HeliocentricPosition>).map((p: HeliocentricPosition): HeliocentricPosition => ({
          name: p.name,
          englishName: p.englishName,
          latitude: p.latitude,
          longitude: p.longitude,
          distanceAU: p.distanceAU,
          isComet: p.isComet === true,
          isSelectedMinor: p.isSelectedMinor === true,
        }))
        const hooks = this.hooks
        this.hecPositions = hooks !== null ? hooks.hecLayoutPositions(positions) : positions
        this.hecTime = r.hecTime ?? ''
        if (this.hecPositions.length === 0) this.hecPositionsError = '当前没有可显示的日心位置。'
      } else {
        this.hecPositionsError = r.error ?? '日心黄道位置计算失败，请点刷新后重试。'
      }
    }, () => {
      if (requestId !== this.hecPositionsRequestSequence) return
      this.hecPositionsLoading = false
      this.hecPositionsError = '日心黄道位置计算失败，请点刷新后重试。'
    })
  }

  // 目录天体位置：原宿主 loadCelestialPositions。
  loadCelestialPositions(): void {
    this.updateAstroCalcSnapshot()
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const requestId = ++this.celestialPositionsRequestSequence
    this.celestialPositions = []
    this.celestialPositionsError = ''
    this.celestialPositionsLoading = true
    const options: CelestialPositionOptions = {
      category: this.celestialPositionCategory,
      horizontal: this.celestialPositionHorizontal,
      magnitudeLimit: this.celestialPositionMagnitude,
      maximumRows: 80,
    }
    port.requestInteractive('getCelestialPositions', JSON.stringify(options), (r: StellariumBridgeResponse) => {
      if (requestId !== this.celestialPositionsRequestSequence) return
      this.celestialPositionsLoading = false
      if (r.ok === true && r.celestialPositions !== undefined) {
        this.celestialPositions = r.celestialPositions as Array<CelestialPosition>
        this.celestialPositionTime = r.positionTime ?? ''
        if (this.celestialPositions.length === 0) this.celestialPositionsError = '当前筛选条件下没有可显示的目录天体。'
      } else {
        this.celestialPositionsError = r.error ?? '目录天体位置计算失败，请点刷新后重试。'
      }
    }, () => {
      if (requestId !== this.celestialPositionsRequestSequence) return
      this.celestialPositionsLoading = false
      this.celestialPositionsError = '目录天体位置计算失败，请点刷新后重试。'
    })
  }

  // §14 B3-2：月相加载器（原宿主 loadMoonPhases，函数体逐字搬入；仅
  // this.callLongRunningInteractive → port.requestLongRunning、this.astroStore.<f> → this.<f>、
  // this.moonPhaseRequestId/moonPhaseLoadingDays → 本 store 私有请求态）。
  loadMoonPhases(): void {
    this.updateAstroCalcSnapshot()
    const days = this.moonPhaseDays
    if (this.moonPhaseLoading && this.moonPhaseLoadingDays === days) return
    const port = this.ensurePort()
    if (port === null) return
    const requestId = ++this.moonPhaseRequestSequence
    this.moonPhaseLoadingDays = days
    this.moonPhaseData = []
    this.moonPhaseError = ''
    this.moonPhaseLoading = true
    const finish = (callback: () => void): void => {
      if (requestId !== this.moonPhaseRequestSequence) return
      callback()
    }
    // 90 天会在原生线程中逐日推进天体模型，不能使用普通交互命令的
    // 1.5 秒超时；长任务通道会持续读取异步结果，避免首次点击误报超时。
    port.requestLongRunning('getMoonPhases', JSON.stringify({ days: days }), (r: StellariumBridgeResponse) => {
      finish(() => {
        this.moonPhaseLoading = false
        if (r.ok === true && r.moonPhases !== undefined) {
          this.moonPhaseData = r.moonPhases as Array<MoonPhaseItem>
        } else {
          this.moonPhaseError = r.error ?? '月相计算未能完成，请稍后重试。'
        }
      })
    }, (r: StellariumBridgeResponse) => {
      finish(() => {
        this.moonPhaseLoading = false
        this.moonPhaseError = r.error ?? '月相计算等待超时，请稍后重试。'
      })
    }, (r: StellariumBridgeResponse) => {
      finish(() => {
        this.moonPhaseError = ''
      })
    }, days >= 90 ? 600 : 240)
  }

  // §14 B3-2：天文计算上下文加载器（原宿主 loadAstroCalcContext，函数体逐字搬入；仅
  // this.callInteractive → port.requestInteractive、this.astroStore.astroContext → this.astroContext、
  // this.astroContextRequestId/astroContextRequestPending → 本 store 私有请求态）。
  loadAstroCalcContext(): void {
    if (this.astroContextRequestPending) return
    const port = this.ensurePort()
    if (port === null) return
    this.astroContextRequestPending = true
    const requestId = ++this.astroContextRequestSequence
    port.requestInteractive('getAstroCalcContext', '', (r: StellariumBridgeResponse) => {
      this.astroContextRequestPending = false
      if (requestId !== this.astroContextRequestSequence) return
      if (r.ok !== true) {
        this.astroContext = undefined
        return
      }
      this.astroContext = {
        jd: r.jd as number,
        localTime: r.localTime as string,
        observerLocation: r.observerLocation as string,
        timeZone: r.timeZone as string,
        latitude: Number(r.latitude),
        longitude: Number(r.longitude),
        altitude: Number(r.altitude),
        meanSiderealTime: r.meanSiderealTime as string,
        apparentSiderealTime: r.apparentSiderealTime as string,
        meanSiderealHours: Number(r.meanSiderealHours),
        apparentSiderealHours: Number(r.apparentSiderealHours),
        equationOfTimeMinutes: Number(r.equationOfTimeMinutes),
        sunAltitude: Number(r.sunAltitude),
        sunAzimuth: Number(r.sunAzimuth),
        moonAltitude: Number(r.moonAltitude),
        moonAzimuth: Number(r.moonAzimuth),
        moonIllumination: Number(r.moonIllumination),
        offline: r.offline === true
      }
    }, () => {
      this.astroContextRequestPending = false
    })
  }

  // §14 B3-2：宿主关闭天文面板时作废在途上下文请求（原宿主 stopAstroCalcContextTimer 的
  // `++astroContextRequestId`；只递增序号、不复位 pending，逐字保留原语义）。
  cancelAstroCalcContext(): void {
    ++this.astroContextRequestSequence
  }

  // 标签页分发：原宿主 loadAstroTab；loadPlanetPositions 未随本片下沉（经 hooks 注入）；
  // loadMoonPhases / loadAstroCalcContext 已于 §14 B3-2 下沉本 store。
  loadAstroTab(id: number): void {
    this.updateAstroCalcSnapshot()
    this.loadAstroCalcContext()
    const hooks = this.hooks
    if (id === 0) {
      if (this.positionMode === 0) {
        if (hooks !== null) hooks.loadPlanetPositions()
      }
      else if (this.positionMode === 1) this.loadHeliocentricPositions()
      else this.loadCelestialPositions()
    }
    else if (id === 1) this.loadEphemeris()
    else if (id === 2) this.loadRTS()
    else if (id === 3) this.loadPhenomena()
    else if (id === 4) {
      if (this.graphMode === 2) this.loadAnnualElevation()
      else if (this.graphMode === 3) this.loadObservabilityCalendar()
      else if (this.graphMode === 4) this.loadLunarElongation()
      else if (this.graphMode === 5) this.loadPlanetTimeSeries()
      else this.loadAltAzCurve()
    }
    else if (id === 5) this.loadTonightAstro()
    else if (id === 6) {
      if (this.planetCalcMode === 1) this.loadPlanetPairDistance()
      else this.loadPlanetCalc()
    }
    else if (id === 7) {
      if (this.eclipseMode === 0) this.loadEclipses()
      else this.loadPlanetaryTransits()
    }
    else if (id === 8) this.loadAlmanac()
    else if (id === 9) {
      this.loadMoonPhases()
    }
  }

  // ===== A2-2：读本 store 字段的派生取值方法（plan §14.3 A2-D）=====
  // 以下方法原先在宿主中读取 this.astroStore.*；函数体逐字迁入本 store，改为零宿主引用。
  // 宿主 AstroPanel 端口对象与 exportCurrentAstroCsv 调用点改为 this.astroStore.<name>()。

  makeAstroCsv(exportData: AstroCsvExport): string {
    const lines: Array<string> = []
    lines.push('# ' + exportData.title)
    const hooks = this.hooks
    if (this.astroContext !== undefined) {
      const location = this.astroContext.observerLocation !== undefined && this.astroContext.observerLocation.length > 0
        ? this.astroContext.observerLocation : '当前观测位置'
      lines.push('# 观测地点: ' + location)
      lines.push('# 本地时间: ' + (hooks !== null ? hooks.fmtDateTime(this.astroContext.localTime) : '--'))
      lines.push('# 时区: ' + (this.astroContext.timeZone ?? '--'))
      lines.push('# 平恒星时: ' + (this.astroContext.meanSiderealTime ?? '--'))
      lines.push('# 视恒星时: ' + (this.astroContext.apparentSiderealTime ?? '--'))
    }
    if (this.astroCalcSnapshot.length > 0) lines.push('# 参数: ' + this.astroCalcSnapshot)
    lines.push(exportData.headers.map((header: string) => csvCell(header)).join(','))
    for (const row of exportData.rows) {
      lines.push(row.map((cell: string | number | boolean | undefined) => csvCell(cell)).join(','))
    }
    return lines.join('\r\n') + '\r\n'
  }

  filteredEclipses(): Array<EclipseItem> {
    const filtered: Array<EclipseItem> = []
    for (const eclipse of this.eclipseData) {
      if (this.eclipseKindFilter === 1 && eclipse.kind !== 'solar') continue
      if (this.eclipseKindFilter === 2 && eclipse.kind !== 'lunar') continue
      const type = eclipse.type ?? ''
      if (this.eclipseTypeFilter === 1 && type !== '全食') continue
      if (this.eclipseTypeFilter === 2 && type !== '环食') continue
      if (this.eclipseTypeFilter === 3 && type !== '偏食') continue
      if (this.eclipseTypeFilter === 4 && type !== '半影食') continue
      filtered.push(eclipse)
    }
    return filtered
  }

  altAzMaxLabel(): string {
    let m: number = -999
    let t: number = 0
    for (let i = 0; i < this.altAzCurve.length; i++) {
      const p: AltAzPoint = this.altAzCurve[i]
      const v: number = p.altitude !== undefined ? p.altitude : -999
      if (v > m) { m = v; t = p.t !== undefined ? p.t : 0 }
    }
    if (m < -90) return '--'
    return m.toFixed(1) + '°（' + hourOffsetLabel(t) + '）'
  }

  altAzVisibleHours(): string {
    let hours: number = 0
    for (let i = 0; i + 1 < this.altAzCurve.length; i++) {
      const p: AltAzPoint = this.altAzCurve[i]
      const next: AltAzPoint = this.altAzCurve[i + 1]
      if (p.altitude !== undefined && p.altitude > 0 && p.t !== undefined && next.t !== undefined) {
        hours += next.t - p.t
      }
    }
    return hours.toFixed(1) + ' 小时'
  }

  altAzNowLabel(): string {
    if (this.altAzCurve.length === 0) return '--'
    const p: AltAzPoint = this.altAzCurve[0]
    const alt: number = p.altitude !== undefined ? p.altitude : 0
    const az: number = p.azimuth !== undefined ? p.azimuth : 0
    return '高度 ' + alt.toFixed(1) + '° / 方位 ' + az.toFixed(1) + '°'
  }

  annualMaxLabel(): string {
    let maximum: number = -91
    let date: string = ''
    for (const point of this.annualElevationData) {
      const altitude: number = point.altitude ?? -91
      if (altitude > maximum) {
        maximum = altitude
        date = point.date ?? ''
      }
    }
    return maximum < -90 ? '--' : maximum.toFixed(1) + '°（' + (date.length >= 10 ? date.slice(5) : date) + '）'
  }

  lunarElongationClosestLabel(): string {
    let closest: number = 181
    let time: number = 0
    for (const point of this.lunarElongationData) {
      const separation: number = point.separation ?? 181
      if (separation < closest) {
        closest = separation
        time = point.t ?? 0
      }
    }
    return closest > 180 ? '--' : closest.toFixed(1) + '°（' + hourOffsetLabel(time) + '）'
  }

  rtsCalendarStartOptionLabel(offsetDays: number): string {
    if (offsetDays < 0) {
      return this.rtsCalendarStartYear.toString() + '-' + this.rtsCalendarStartMonth.toString().padStart(2, '0') + '-' + this.rtsCalendarStartDay.toString().padStart(2, '0')
    }
    if (offsetDays === 0) return '当前'
    return '+' + offsetDays.toString() + ' 天'
  }

  eclipseStartOptionLabel(offsetDays: number): string {
    if (offsetDays < 0) {
      return this.eclipseStartYear.toString() + '-' + this.eclipseStartMonth.toString().padStart(2, '0') + '-' + this.eclipseStartDay.toString().padStart(2, '0')
    }
    if (offsetDays === 0) return '当前'
    return '+' + offsetDays.toString() + ' 天'
  }

  graphCustomStartLabel(): string {
    if (this.graphStartOffsetDays >= 0) return '指定日期'
    return this.graphStartYear.toString() + '-' + this.graphStartMonth.toString().padStart(2, '0') + '-' + this.graphStartDay.toString().padStart(2, '0')
  }
}
