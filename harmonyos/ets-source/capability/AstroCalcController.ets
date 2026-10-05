// 天文计算（astro）行为控制器（STATE-REVIEW §10.2 D7，PLAN §15 D 轨道 D7）。
//
// 原宿主 MainWindowNativeNode 的 astro 计算面板动作逐字下沉：
//   jumpToRts / jumpToRtsCalendar / jumpToEphemerisRow / jumpToObservabilityDay /
//   jumpToPhenomenon / jumpToWutTarget / jumpToMoonPhase / jumpToAlmanacSeason /
//   chooseRtsCalendarStartDate / chooseEphemerisStartDate / chooseGraphStartDate / chooseEclipseStartDate /
//   openAstroTargetPicker / openGraphTargetPicker / openRtsTargetPicker / openEphemerisTargetPicker /
//   reloadCurrentGraph / selectAstroFilter / selectAstroGroup / selectAstroTab /
//   exportCurrentAstroCsv / applyAtmosphere / loadPlanetPositions /
//   shouldRefreshAstroCalcContext / syncAstroCalcContextTimer / stopAstroCalcContextTimer /
//   fmtDateTime / fmtClock / fmtEphemerisDate / fmtNum。
//
// STATE-REVIEW §10.1 记「32 法」；工作区实测为 29 个行为法 + 1 个 publish*（保留宿主）：
//   - `publishAstroPanelState` 属 §15.6-4 publish* 保留项 —— 只迁调用方，本体留宿主，经
//     AstroCalcHostHooks 回注；宿主 publishAstroPanelState 经 requestedAstroTab() /
//     astroTransitionSerial() 回读本控制器的 astroRequestedTab / astroTransitionId（§10.2 字段）。
//   - STATE-REVIEW 估的「5 个 chooseXxxStartDate / 3 个 openXxxTargetPicker」实测为 4 / 4
//     （无 chooseWutStartDate；RTS 的为 chooseRtsCalendarStartDate）。
//   - 4 个格式化纯函数（fmtDateTime/fmtClock/fmtEphemerisDate/fmtNum）选择留在本控制器
//     （而非 common/derive/）：AstroStore 已以 AstroHostHooks.fmtDateTime 消费同一实现，
//     留此可零改动 store 接口（§10.2 许可的二选一，理由记于 CHANGELOG）。
//
// **不 import NAPI/UI**（§15.7 规则 1）：桥经 CommandPort；picker/fileIo 经 MediaPort；
// DatePickerDialog / animateTo / Scroller / 壳层路由 / 保留宿主方法（publishAstroPanelState /
// applyAtmosphereResponse / applySelectedObject）经 AstroCalcHostHooks 具名回注（§13.1 规则 6）。
// 定时器 `/ astroContextTimer` 由控制器自持（syncAstroCalcContextTimer / stopAstroCalcContextTimer）。
import { StellariumBridgeResponse, EphemerisRow, RtsCalendarDay, ObservabilityDay, PhenomenonItem, WutTarget, MoonPhaseItem, SeasonEvent, PlanetPosition, TabItem } from '../pages/StellariumTypes'
import { CommandPort } from '../bridge/CommandPort'
import { MediaPort, MediaSaveResult } from '../bridge/MediaPort'
import { AstroStore } from '../state/AstroStore'
import { EphemerisStore } from '../state/EphemerisStore'
import { WutStore } from '../state/WutStore'
import { SearchStore } from '../state/SearchStore'
import { astroTabItemsForGroup, astroGroupForTab } from '../common/derive/astro'
import { BehaviorHostHooks } from './ControllerHooks'

// 宿主 → 控制器回注（§13.1 规则 6 / §15.7 规则 1）：UI（DatePicker / animateTo / Scroller）、
// 壳层路由与 §15.6 保留宿主方法。
export interface AstroCalcHostHooks extends BehaviorHostHooks {
  // §15.6-4 保留的 CLI 发布点（宿主 publishAstroPanelState，写 AppStorage）。
  publishAstroPanelState(): void
  // 天文面板是否处于前台上下文（applicationInForeground && activePanel==='astro' && panelVisible）。
  astroPanelContextActive(): boolean
  // 天文面板是否在屏（panelVisible && activePanel==='astro'，供 tab 过渡判定）。
  astroPanelOnScreen(): boolean
  // 标签切换后把天文面板滚回顶部（宿主 astroPanelScroller.scrollTo）。
  scrollAstroPanelToTop(): void
  // tab 切换完成后的持久化（宿主 saveAppSettings）。
  saveAppSettings(): void
  // 标签切换两段动画（宿主 getUIContext().animateTo；curve 由宿主按原调用点固定）。
  animateAstroIn(durationMs: number, onFinish: () => void, action: () => void): void
  animateAstroOut(durationMs: number, onFinish: () => void, action: () => void): void
  // 「指定日期」DatePickerDialog（宿主 getUIContext().showDatePickerDialog；控制器不触碰 UI）。
  showDatePicker(selected: Date, onAccept: (year: number | undefined, month: number | undefined, day: number | undefined) => void): void
  // WUT 目标跳转的选中放置（宿主保留方法 applySelectedObject，§15.6-6 SelectionService 族）。
  applySelectedObject(result: StellariumBridgeResponse, fromRefresh: boolean, placement: string, userReselect: boolean): void
  // 目标选择器路由到搜索面板（壳层路由 §15.6-4）。
  setPanel(panel: string): void
  // 大气参数回包写入 AtmosphereStore（§13.1 规则 6 保留宿主实现，与 TimeStore 共用）。
  applyAtmosphereResponse(result: StellariumBridgeResponse): void
}

export class AstroCalcController {
  private port: CommandPort
  private media: MediaPort
  private astroStore: AstroStore
  private ephemerisStore: EphemerisStore
  private wutStore: WutStore
  private searchStore: SearchStore
  private hooks: AstroCalcHostHooks
  // 草稿/瞬时字段随控制器（§15.7 规则 2，不入 @Observed store）。
  private astroTransitionId: number = 0
  private astroRequestedTab: number = -1
  private planetPositionsRequestSequence: number = 0
  private graphTargetPickerActive: boolean = false
  private rtsTargetPickerActive: boolean = false
  private ephemerisTargetPickerActive: boolean = false
  private astroContextTimer: number = 0

  constructor(
    port: CommandPort,
    media: MediaPort,
    astroStore: AstroStore,
    ephemerisStore: EphemerisStore,
    wutStore: WutStore,
    searchStore: SearchStore,
    hooks: AstroCalcHostHooks
  ) {
    this.port = port
    this.media = media
    this.astroStore = astroStore
    this.ephemerisStore = ephemerisStore
    this.wutStore = wutStore
    this.searchStore = searchStore
    this.hooks = hooks
  }

  // —— 宿主读取的控制器状态（§10.2：astroRequestedTab / astroTransitionId 随控制器） ——
  requestedAstroTab(): number {
    return this.astroRequestedTab
  }

  astroTransitionSerial(): number {
    return this.astroTransitionId
  }

  graphPickerActive(): boolean {
    return this.graphTargetPickerActive
  }

  rtsPickerActive(): boolean {
    return this.rtsTargetPickerActive
  }

  ephemerisPickerActive(): boolean {
    return this.ephemerisTargetPickerActive
  }

  // 搜索面板回跳后清除三个目标选择器标志（原宿主仅在命中分支内置单标志，实测同一时刻至多一真）。
  clearTargetPickerFlags(): void {
    this.graphTargetPickerActive = false
    this.rtsTargetPickerActive = false
    this.ephemerisTargetPickerActive = false
  }

  // 原宿主 jumpToRts()：RTS 事件跳转到对应 JD。
  jumpToRts(key: string): void {
    const jd = this.astroStore.rtsData.get(key) ?? '0'
    if (parseFloat(jd) <= 0) {
      this.hooks.flashHint('该天体在当前位置没有这个事件。')
      return
    }
    this.port.requestInteractive('setJD', jd, (r: StellariumBridgeResponse) => {
      if (r.ok === true) this.hooks.refreshState()
    })
  }

  // 原宿主 jumpToRtsCalendar()：RTS 日历行跳转（取 transit/rise/set 中首个有效 JD）。
  jumpToRtsCalendar(day: RtsCalendarDay): void {
    const jd = day.transitJD ?? day.riseJD ?? day.setJD ?? 0
    if (jd <= 0) return
    this.port.requestInteractive('setJD', jd.toString(), (r: StellariumBridgeResponse) => {
      if (r.ok === true) this.hooks.refreshState()
    })
  }

  // 原宿主 chooseRtsCalendarStartDate()：RTS 日历「指定日期」DatePickerDialog。
  chooseRtsCalendarStartDate(): void {
    this.hooks.showDatePicker(
      new Date(this.astroStore.rtsCalendarStartYear, this.astroStore.rtsCalendarStartMonth - 1, this.astroStore.rtsCalendarStartDay),
      (year: number | undefined, month: number | undefined, day: number | undefined): void => {
        if (year !== undefined) this.astroStore.rtsCalendarStartYear = year
        if (month !== undefined) this.astroStore.rtsCalendarStartMonth = month + 1
        if (day !== undefined) this.astroStore.rtsCalendarStartDay = day
        this.astroStore.rtsCalendarStartOffsetDays = -1
        this.astroStore.markRtsCalendarForRegeneration()
      })
  }

  // 原宿主 chooseEphemerisStartDate()：星历「指定日期」DatePickerDialog。
  chooseEphemerisStartDate(): void {
    this.hooks.showDatePicker(
      new Date(this.ephemerisStore.ephemerisStartYear, this.ephemerisStore.ephemerisStartMonth - 1, this.ephemerisStore.ephemerisStartDay),
      (year: number | undefined, month: number | undefined, day: number | undefined): void => {
        if (year !== undefined) this.ephemerisStore.ephemerisStartYear = year
        if (month !== undefined) this.ephemerisStore.ephemerisStartMonth = month + 1
        if (day !== undefined) this.ephemerisStore.ephemerisStartDay = day
        this.astroStore.ephemerisStartOffsetDays = -1
        this.astroStore.loadEphemeris()
      })
  }

  // 原宿主 jumpToEphemerisRow()：星历行跳转并重载星历。
  jumpToEphemerisRow(row: EphemerisRow): void {
    if (row.jd === undefined || row.jd <= 0) return
    this.port.requestInteractive('setJD', String(row.jd), (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        this.hooks.refreshState()
        this.astroStore.loadEphemeris()
      }
    })
  }

  // 原宿主 chooseGraphStartDate()：高度曲线「指定日期」DatePickerDialog。
  chooseGraphStartDate(): void {
    this.hooks.showDatePicker(
      new Date(this.astroStore.graphStartYear, this.astroStore.graphStartMonth - 1, this.astroStore.graphStartDay),
      (year: number | undefined, month: number | undefined, day: number | undefined): void => {
        if (year !== undefined) this.astroStore.graphStartYear = year
        if (month !== undefined) this.astroStore.graphStartMonth = month + 1
        if (day !== undefined) this.astroStore.graphStartDay = day
        this.astroStore.graphStartOffsetDays = -1
        this.reloadCurrentGraph()
      })
  }

  // 原宿主 reloadCurrentGraph()：按当前图形模式重载对应曲线。
  reloadCurrentGraph(): void {
    if (this.astroStore.graphMode === 2) this.astroStore.loadAnnualElevation()
    else if (this.astroStore.graphMode === 3) this.astroStore.loadObservabilityCalendar()
    else if (this.astroStore.graphMode === 4) this.astroStore.loadLunarElongation()
    else if (this.astroStore.graphMode === 5) this.astroStore.loadPlanetTimeSeries()
    else this.astroStore.loadAltAzCurve()
  }

  // 原宿主 openGraphTargetPicker()：进入搜索面板选择高度曲线目标。
  openGraphTargetPicker(): void {
    this.graphTargetPickerActive = true
    this.searchStore.searchText = ''
    this.searchStore.searchSuggestions = []
    this.searchStore.loadCategoryObjects('planet')
    this.hooks.setPanel('search')
  }

  // 原宿主 openRtsTargetPicker()：进入搜索面板选择 RTS 目标。
  openRtsTargetPicker(): void {
    this.rtsTargetPickerActive = true
    this.searchStore.searchText = ''
    this.searchStore.searchSuggestions = []
    this.searchStore.loadCategoryObjects('planet')
    this.hooks.setPanel('search')
  }

  // 原宿主 openEphemerisTargetPicker()：进入搜索面板选择星历目标。
  openEphemerisTargetPicker(): void {
    this.ephemerisTargetPickerActive = true
    this.searchStore.searchText = ''
    this.searchStore.searchSuggestions = []
    this.searchStore.loadCategoryObjects('planet')
    this.hooks.setPanel('search')
  }

  // 原宿主 jumpToObservabilityDay()：可观测日历最佳日跳转。
  jumpToObservabilityDay(day: ObservabilityDay): void {
    if (day.bestJD === undefined || day.bestJD <= 0) return
    this.port.requestInteractive('setJD', String(day.bestJD), (r: StellariumBridgeResponse) => {
      if (r.ok === true) this.hooks.refreshState()
    })
  }

  // 原宿主 chooseEclipseStartDate()：食相「指定日期」DatePickerDialog。
  chooseEclipseStartDate(): void {
    this.hooks.showDatePicker(
      new Date(this.astroStore.eclipseStartYear, this.astroStore.eclipseStartMonth - 1, this.astroStore.eclipseStartDay),
      (year: number | undefined, month: number | undefined, day: number | undefined): void => {
        if (year !== undefined) this.astroStore.eclipseStartYear = year
        if (month !== undefined) this.astroStore.eclipseStartMonth = month + 1
        if (day !== undefined) this.astroStore.eclipseStartDay = day
        this.astroStore.eclipseStartOffsetDays = -1
        this.astroStore.reloadEclipses()
      })
  }

  // 原宿主 jumpToPhenomenon()：天象行跳转。
  jumpToPhenomenon(item: PhenomenonItem): void {
    if (item.jd === undefined || item.jd <= 0) return
    this.port.requestInteractive('setJD', String(item.jd), (r: StellariumBridgeResponse) => {
      if (r.ok === true) this.hooks.refreshState()
    })
  }

  // 原宿主 jumpToWutTarget()：今晚观测目标行跳转 + 选中并居中。
  jumpToWutTarget(target: WutTarget): void {
    if (target.jd === undefined || target.jd <= 0 || target.englishName === undefined) return
    const targetName = target.englishName
    this.port.requestInteractive('setJD', String(target.jd), (timeResult: StellariumBridgeResponse) => {
      if (timeResult.ok !== true) { return }
      // Selecting is not centring. searchObject only marks the target; the
      // engine's own handler never moves the view, so this row button looked
      // dead. Run the same post-selection placement the global search uses -
      // applySelectedObject with placement 'center' - so the row centres like
      // every other entry point.
      this.port.requestInteractive('searchObject', targetName, (selectResult: StellariumBridgeResponse) => {
        if (selectResult.found !== true) { return }
        this.hooks.applySelectedObject(selectResult, false, 'center', true)
      })
    })
  }

  // 原宿主 applyAtmosphere()：大气参数写回（回包交给保留宿主实现 applyAtmosphereResponse）。
  applyAtmosphere(pressure: number, temperature: number, extinction: number): void {
    this.hooks.applyAtmosphereResponse(this.port.request('setAtmosphereParams',
      JSON.stringify({ pressure: pressure, temperature: temperature, extinction: extinction })))
  }

  // ---- 通用格式化：把 ISO 时间截成 "MM-DD HH:MM" / "HH:MM" ----
  fmtDateTime(s: string | undefined): string {
    if (s === undefined || s.length === 0) return '--'
    return s.replace('T', ' ').slice(0, 16)
  }

  fmtClock(s: string | undefined): string {
    if (s === undefined || s.length < 16) return '--:--'
    return s.slice(11, 16)
  }

  fmtEphemerisDate(s: string | undefined): string {
    if (s === undefined || s.length < 16) return '--'
    return s.slice(5, 16).replace('T', ' ')
  }

  fmtNum(v: number | undefined, digits: number, suffix: string): string {
    if (v === undefined) return '--'
    return v.toFixed(digits) + suffix
  }

  // 原宿主 selectAstroFilter()：今晚观测目标筛选写回 + 重新加载 + CLI 发布。
  selectAstroFilter(key: string, value: string): void {
    if (key === 'period' && ['evening', 'midnight', 'morning', 'night'].includes(value)) {
      if (this.wutStore.wutPeriod === value) return
      this.wutStore.wutPeriod = value
    } else if (key === 'altitude' && ['0', '10', '20', '30', '45'].includes(value)) {
      if (this.wutStore.wutMinAltitude === Number(value)) return
      this.wutStore.wutMinAltitude = Number(value)
    } else if (key === 'magnitude' && ['4', '6', '8', '10'].includes(value)) {
      if (this.wutStore.wutMaxMagnitude === Number(value)) return
      this.wutStore.wutMaxMagnitude = Number(value)
    } else if (key === 'direction' && ['all', 'north', 'east', 'south', 'west'].includes(value)) {
      if (this.wutStore.wutDirection === value) return
      this.wutStore.wutDirection = value
    } else return
    this.hooks.publishAstroPanelState()
    this.wutStore.loadWutTargets()
  }

  // 原宿主 selectAstroGroup()：一级分组切换（转对应默认标签）。
  selectAstroGroup(group: number): void {
    if (group < 0 || group > 2) return
    const tabs = astroTabItemsForGroup(group)
    const currentTab = tabs.find((item: TabItem) => item.id === this.astroStore.astroTab)
    this.selectAstroTab(currentTab !== undefined ? currentTab.id : tabs[0].id)
  }

  // 原宿主 selectAstroTab()：子标签切换（两段 animateTo 时序逐字保留；动画本体归宿主）。
  selectAstroTab(tab: number): void {
    if (!Number.isInteger(tab) || tab < 0 || tab > 9 || tab === this.astroRequestedTab) return
    if (tab === this.astroStore.astroTab && this.astroRequestedTab < 0) return
    const order: number[] = [5, 2, 4, 9, 0, 1, 6, 3, 7, 8]
    const direction: number = order.indexOf(tab) >= order.indexOf(this.astroStore.astroTab) ? 1 : -1
    const transitionId = ++this.astroTransitionId
    this.astroRequestedTab = tab
    this.hooks.publishAstroPanelState()
    this.hooks.animateAstroIn(100, (): void => {
      if (transitionId !== this.astroTransitionId) return
      if (!this.hooks.astroPanelOnScreen()) {
        this.astroRequestedTab = -1
        this.astroStore.astroContentOpacity = 1
        this.astroStore.astroContentOffsetX = 0
        this.hooks.publishAstroPanelState()
        return
      }
      this.astroStore.astroTab = tab
      this.astroStore.astroGroup = astroGroupForTab(tab)
      this.hooks.scrollAstroPanelToTop()
      this.astroStore.astroContentOffsetX = direction * 10
      this.hooks.animateAstroOut(170, (): void => {
        if (transitionId !== this.astroTransitionId) return
        this.astroRequestedTab = -1
        this.hooks.publishAstroPanelState()
        if (!this.hooks.astroPanelOnScreen()) return
        this.hooks.saveAppSettings()
        this.astroStore.loadAstroTab(tab)
      }, (): void => {
        this.astroStore.astroContentOpacity = 1
        this.astroStore.astroContentOffsetX = 0
      })
    }, (): void => {
      this.astroStore.astroContentOpacity = 0
      this.astroStore.astroContentOffsetX = (0 - direction) * 8
    })
  }

  // 原宿主 openAstroTargetPicker()：按当前标签分派到对应目标选择器。
  openAstroTargetPicker(): void {
    if (this.astroStore.astroTab === 2) {
      this.openRtsTargetPicker()
    } else if (this.astroStore.astroTab === 4) {
      this.openGraphTargetPicker()
    } else {
      this.openEphemerisTargetPicker()
    }
  }

  // 原宿主 jumpToMoonPhase()：月相行跳转。
  jumpToMoonPhase(item: MoonPhaseItem): void {
    if (item.jd === undefined || item.jd <= 0) return
    this.port.requestInteractive('setJD', String(item.jd), () => { this.hooks.refreshState() })
  }

  // 原宿主 jumpToAlmanacSeason()：季节节点行跳转。
  jumpToAlmanacSeason(event: SeasonEvent): void {
    if (event.jd === undefined || event.jd <= 0) return
    this.port.requestInteractive('setJD', String(event.jd), (r: StellariumBridgeResponse) => {
      if (r.ok === true) this.hooks.refreshState()
    })
  }

  // 原宿主 shouldRefreshAstroCalcContext()：天文面板前台且可见。
  private shouldRefreshAstroCalcContext(): boolean {
    return this.hooks.astroPanelContextActive()
  }

  // 原宿主 stopAstroCalcContextTimer()：停上下文轮询并取消在途请求。
  stopAstroCalcContextTimer(): void {
    if (this.astroContextTimer !== 0) {
      clearInterval(this.astroContextTimer)
      this.astroContextTimer = 0
    }
    this.astroStore.cancelAstroCalcContext()
  }

  // 原宿主 syncAstroCalcContextTimer()：按面板可见性启停 1s 上下文轮询（定时器自持）。
  syncAstroCalcContextTimer(): void {
    if (!this.shouldRefreshAstroCalcContext()) {
      this.stopAstroCalcContextTimer()
      return
    }
    if (this.astroContextTimer !== 0) return
    this.astroStore.loadAstroCalcContext()
    this.astroContextTimer = setInterval(() => { this.astroStore.loadAstroCalcContext() }, 1000)
  }

  // 原宿主 loadPlanetPositions()：行星位置刷新（请求序号防止旧回包覆盖）。
  loadPlanetPositions(): void {
    this.astroStore.updateAstroCalcSnapshot()
    const requestId = ++this.planetPositionsRequestSequence
    this.astroStore.planetPositions = []
    this.astroStore.planetPositionsError = ''
    this.astroStore.planetPositionsLoading = true
    this.port.requestInteractive('getObjectPositions', '', (r: StellariumBridgeResponse) => {
      if (requestId !== this.planetPositionsRequestSequence) return
      this.astroStore.planetPositionsLoading = false
      if (r.ok === true && Array.isArray(r.items)) {
        const positioned = r.items as Array<PlanetPosition>
        this.astroStore.planetPositions = positioned.map((p: PlanetPosition): PlanetPosition => ({
          name: p.name,
          englishName: p.englishName,
          rightAscension: p.rightAscension,
          declination: p.declination,
          altitude: Math.round(p.altitude * 10) / 10,
          azimuth: Math.round(p.azimuth * 10) / 10,
          magnitude: Math.round(p.magnitude * 100) / 100,
          distanceAU: p.distanceAU,
          angularSizeArcmin: p.angularSizeArcmin,
          transit: p.transit,
        }))
        if (this.astroStore.planetPositions.length === 0) this.astroStore.planetPositionsError = '当前没有可显示的行星位置。'
      } else {
        this.astroStore.planetPositionsError = r.error ?? '行星位置计算失败，请点刷新后重试。'
      }
    }, () => {
      if (requestId !== this.planetPositionsRequestSequence) return
      this.astroStore.planetPositionsLoading = false
      this.astroStore.planetPositionsError = '行星位置计算失败，请点刷新后重试。'
    })
  }

  // 原宿主 exportCurrentAstroCsv()：当前页 CSV 导出（picker/fileIo 经 MediaPort.saveTextFileAs）。
  async exportCurrentAstroCsv(): Promise<void> {
    this.astroStore.updateAstroCalcSnapshot()
    const exportData = this.astroStore.astroCsvExport(this.wutStore.wutTargets, this.wutStore.wutObservationTime)
    if (exportData === undefined || exportData.rows.length === 0) {
      this.hooks.flashHint('当前页没有可导出的计算结果，请先生成数据。')
      return
    }
    this.astroStore.astroExporting = true
    try {
      const csv = this.astroStore.makeAstroCsv(exportData)
      const title = exportData.title
      await new Promise<void>((resolve) => {
        this.media.saveTextFileAs(csv, 'astrocalc-' + Date.now().toString() + '.csv', 'CSV 表格|.csv', (result: MediaSaveResult) => {
          if (result === MediaSaveResult.Cancelled) this.hooks.flashHint('已取消保存。')
          else if (result === MediaSaveResult.Saved) this.hooks.flashHint('已保存 ' + title + ' CSV。')
          else this.hooks.flashHint('保存失败，请检查文件管理权限后重试。')
          resolve()
        })
      })
    } finally {
      this.astroStore.astroExporting = false
    }
  }
}
