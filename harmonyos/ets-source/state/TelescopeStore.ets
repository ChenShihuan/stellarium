import { I18n } from '../pages/I18n'
import { OcularInstrumentItem, OcularSelInfo, OcularsResponse, TelescopeProfile, TelescopeProfilesResponse, TelescopeControlResponse, TELESCOPE_SIMULATOR_MODEL } from '../pages/MainWindowModels'
import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import { telescopeUpdateTime, telescopeErrorText } from '../common/derive/actions'
import { CommandPort } from '../bridge/CommandPort'

// 宿主 → TelescopeStore 的只读谓词注入（§13.1 规则 6 / §14.8 规则 2：store 不触碰 UI 生命周期）。
// 「是否应刷新实时位置」读宿主 applicationInForeground / panelVisible / activePanel 三个生命周期
// 与 UI 状态字段，宿主保留该谓词，经具名 hooks 注入；store 侧只在 schedule / sync 时调用。
export interface TelescopeHostHooks {
  shouldRefreshTelescopePosition(): boolean
}

// 「望远镜控制」/「目镜（Oculars）」两面板的状态簇。
//
// 本片边界（Phase 3al）：原宿主的
//   - 目镜插件簇（ocularMode / telradOn / crosshairsOn / ccdOn / ocular|telescope|lens|ccd 的
//     Names/Index/Items / ocularLoading / ocularStatusMessage / ocularReady / ocularCcdReady /
//     以及全部 ocular<Setting> 布尔与数值）共 59 个 @State；
//   - LX200 望远镜控制簇（lx200Host/Port/Profiles/SelectedSlot/Name/Protocol/DeviceModel/Equinox/
//     CommandDelayMs/Circles/TargetSource/Busy/EditingNew/Status/Scope/Transport/ConnectionState/
//     Position/LivePositionEnabled/PositionUpdatedAt/PositionUpdateState）共 21 个 @State；
//   - 「赤道仪」开关 equatorialMount（同一 mount 语义，设置持久化与图层面板共用）
// 逐条搬到此处，保留原类型与默认值（含 ResourceStr 的三个本地化默认串）。
//
// 只放数据与纯计算，不 import UI / NAPI。
//
// 不搬的宿主职责（跨域 / native 桥 / 定时器，§13.1 规则 6）：
//   - 原生桥与加载（callNativeWhenReady / getOculars / setOcularMode / setOcularSetting /
//     selectOcularInstrument / rotateOcularReticle / resetOcularInstrument / setTelrad /
//     setCrosshairs / setCCD / getTelescopeProfiles / setTelescopeProfile / testTelescope /
//     readTelescopePosition …）以及全部 LX200 命令方法；
//   - LX200 轮询状态（lx200LivePositionTimer / lx200LivePositionRequestPending /
//     lx200LivePositionRequestId）——它们不是渲染状态；ocularLoadRequestId 已在 §14 B1-1 作为 seq 迁入本 store。
//   - 编辑器校验 validateTelescopeEditorStatus()：它读 store 字段写回 lx200Status/Scope/Transport，
//     由宿主在输入回调里执行，不放进 store（避免 store 内做副作用）。
//
// 三个选择器助手（ocularInstrumentItems / ocularInstrumentIndex / ocularInstrumentSummary /
// ocularSelInfo）是纯查表计算，随字段一起下沉，供 OcularSelector 组件直接调用。
@Observed
export class TelescopeStore {
  // —— 目镜（Oculars）——
  ocularMode: boolean = false
  telradOn: boolean = false
  crosshairsOn: boolean = false
  ccdOn: boolean = false
  ocularNames: string[] = []
  telescopeNames: string[] = []
  lensNames: string[] = []
  ccdNames: string[] = []
  ocularIndex: number = -1
  telescopeIndex: number = -1
  lensIndex: number = -1
  ccdIndex: number = -1
  ocularItems: OcularInstrumentItem[] = []
  telescopeItems: OcularInstrumentItem[] = []
  lensItems: OcularInstrumentItem[] = []
  ccdItems: OcularInstrumentItem[] = []
  ocularLoading: boolean = false
  ocularStatusMessage: string = ''
  ocularReady: boolean = false
  ocularCcdReady: boolean = false
  ocularHasSelection: boolean = false
  ocularRequireSelection: boolean = true
  ocularAutoLimitMagnitude: boolean = true
  ocularHideGridsLines: boolean = true
  ocularAutoScaleTelrad: boolean = true
  ocularAutoScaleCcd: boolean = true
  ocularSemiTransparentMask: boolean = false
  ocularMaskOpacity: number = 85
  ocularShowResolutionCriteria: boolean = false
  ocularAutoSetMountForCcd: boolean = false
  ocularHorizontalCoordinates: boolean = false
  ocularSensorCropOverlay: boolean = false
  ocularSensorPixelGrid: boolean = false
  ocularFocuserOverlay: boolean = false
  ocularScaleImageCircle: boolean = true
  ocularMaxExposureTimeForCcd: boolean = false
  ocularShowContour: boolean = false
  ocularShowCardinals: boolean = false
  ocularAlignCrosshair: boolean = false
  ocularSmallFocuserOverlay: boolean = false
  ocularMediumFocuserOverlay: boolean = true
  ocularLargeFocuserOverlay: boolean = false
  ocularDmsDegrees: boolean = false
  ocularInitFov: boolean = false
  ocularInitDirection: boolean = false
  ocularOagLimits: boolean = true
  ocularCcdCropHSize: number = 250
  ocularCcdCropVSize: number = 250
  ocularCcdPrismRotation: number = 0
  ocularGuiPanelEnabled: boolean = true
  ocularMagnification: number = 0
  ocularActualFov: number = 0
  ocularExitPupil: number = 0
  ocularLimitMagnitude: number = 0
  ocularCcdFovX: number = 0
  ocularCcdFovY: number = 0
  ocularCcdPixelScaleX: number = 0
  ocularCcdPixelScaleY: number = 0
  ocularCcdRotation: number = 0

  // —— LX200 望远镜控制 ——
  lx200Host: string = ''
  lx200Port: string = ''
  lx200Profiles: TelescopeProfile[] = []
  lx200SelectedSlot: number = 1
  lx200Name: string = 'Offline Telescope Simulator'
  lx200Protocol: string = 'simulated'
  lx200DeviceModel: string = TELESCOPE_SIMULATOR_MODEL
  lx200Equinox: string = 'J2000'
  lx200CommandDelayMs: number = 0
  lx200Circles: string = '1, 2, 4'
  lx200TargetSource: string = 'selected'
  lx200Busy: boolean = false
  lx200EditingNew: boolean = false
  lx200Status: ResourceStr = I18n.t('m_telescope_idle')
  lx200Scope: ResourceStr = I18n.t('m_telescope_scope_unknown')
  lx200Transport: ResourceStr = I18n.t('m_telescope_transport_simulated')
  lx200ConnectionState: string = 'not_tested'
  lx200Position: string = ''
  lx200LivePositionEnabled: boolean = false
  lx200PositionUpdatedAt: string = ''
  lx200PositionUpdateState: string = 'idle'

  // —— §14 B3-4：live-position 定时器簇（原宿主裸字段 lx200LivePositionTimer /
  // lx200LivePositionRequestPending / lx200LivePositionRequestId，随定时器整体迁入本 store）。
  // 仅本 store 的 schedule / refresh / sync / stop 读写；reqId 用于作废在途回包。
  private lx200LivePositionTimer: number = 0
  private lx200LivePositionRequestPending: boolean = false
  private lx200LivePositionRequestId: number = 0

  // —— 赤道仪开关 ——
  equatorialMount: boolean = false

  // —— 目镜选择器的纯查表计算 ——
  // 原宿主四个 private 助手方法逐字搬迁（只读本 store 字段）。
  ocularInstrumentItems(kind: string): OcularInstrumentItem[] {
    if (kind === 'Ocular') return this.ocularItems
    if (kind === 'Telescope') return this.telescopeItems
    if (kind === 'Lens') return this.lensItems
    return this.ccdItems
  }

  ocularInstrumentIndex(kind: string): number {
    if (kind === 'Ocular') return this.ocularIndex
    if (kind === 'Telescope') return this.telescopeIndex
    if (kind === 'Lens') return this.lensIndex
    return this.ccdIndex
  }

  ocularInstrumentSummary(kind: string, item: OcularInstrumentItem): string {
    if (kind === 'Ocular') {
      if (item.binocular === true) return I18n.t('ocular_binocular') + ' · ' + (item.apparentFov ?? 0).toFixed(1) + '°'
      return (item.focalLength ?? 0).toFixed(1) + ' mm · ' + (item.apparentFov ?? 0).toFixed(1) + '°'
    }
    if (kind === 'Telescope') return 'D ' + (item.diameter ?? 0).toFixed(0) + ' mm · f/' + (item.focalRatio ?? 0).toFixed(1)
    if (kind === 'Lens') return (item.multiplier ?? 1).toFixed(2) + '×'
    return (item.resolutionX ?? 0).toString() + ' × ' + (item.resolutionY ?? 0).toString()
  }

  ocularSelInfo(kind: string): OcularSelInfo {
    const info = new OcularSelInfo()
    let names: string[] = []
    let idx: number = -1
    if (kind == 'Ocular') { names = this.ocularNames; idx = this.ocularIndex }
    else if (kind == 'Telescope') { names = this.telescopeNames; idx = this.telescopeIndex }
    else if (kind == 'Lens') { names = this.lensNames; idx = this.lensIndex }
    else { names = this.ccdNames; idx = this.ccdIndex }
    if (idx >= 0 && idx < names.length) { info.name = names[idx] }
    else { info.name = '（无）' }
    info.countText = (idx < 0 ? '—' : (idx + 1).toString()) + ' / ' + names.length.toString()
    return info
  }

  // —— 桥注入（§14.1 AB-0 约定；§14 B1-1 起本域加载器自持） ——
  // 宿主在 aboutToAppear 用同一个 HostCommandPort 实例调用 attachPort(port, onChanged) 注入；
  // 请求序号 seq 随加载器搬入 store（§14.8 规则 3，宿主不再持有 ocularLoadRequestId）。
  // 本域无 publish* 发布点、消费方均为 @ObjectLink（字段赋值即刷新），故 onChanged 为空实现。
  private port: CommandPort | null = null
  private seq: number = 0
  private onChanged: (() => void) | null = null
  private hooks: TelescopeHostHooks | null = null

  attachPort(port: CommandPort, onChanged: () => void): void {
    this.port = port
    this.onChanged = onChanged
  }

  // §14 B3-4：宿主注入「是否应刷新实时位置」谓词（读 applicationInForeground / panelVisible /
  // activePanel === 'telescope' / lx200EditingNew 等，宿主保留该谓词）。
  attachHooks(hooks: TelescopeHostHooks): void {
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

  // 目镜插件加载（原宿主 loadOculars，函数体逐字搬入；仅 this.callNativeWhenReady → this.port.requestWhenReady，
  // this.telescopeStore.<f> → this.<f>，this.ocularLoadRequestId → this.seq）。
  loadOculars(showLoading: boolean = true): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const requestId = ++this.seq
    if (showLoading) this.ocularLoading = true
    port.requestWhenReady('getOculars', '', (r: StellariumBridgeResponse) => {
      if (requestId !== this.seq) return
      this.ocularLoading = false
      const resp = r as OcularsResponse
      const o = resp.oculars
      if (!o) {
        this.ocularStatusMessage = I18n.t('ocular_status_unavailable')
        return
      }
      this.ocularMode = o.ocularMode
      this.telradOn = o.telrad
      this.crosshairsOn = o.crosshairs
      this.ccdOn = o.ccd
      this.ocularNames = o.ocularNames
      this.telescopeNames = o.telescopeNames
      this.lensNames = o.lensNames
      this.ccdNames = o.ccdNames
      this.ocularIndex = o.ocularIndex
      this.telescopeIndex = o.telescopeIndex
      this.lensIndex = o.lensIndex
      this.ccdIndex = o.ccdIndex
      this.ocularItems = o.ocularItems ?? []
      this.telescopeItems = o.telescopeItems ?? []
      this.lensItems = o.lensItems ?? []
      this.ccdItems = o.ccdItems ?? []
      this.ocularReady = o.ocularReady
      this.ocularCcdReady = o.ccdReady
      this.ocularHasSelection = o.hasSelection
      this.ocularRequireSelection = o.requireSelection
      this.ocularAutoLimitMagnitude = o.autoLimitMagnitude
      this.ocularHideGridsLines = o.hideGridsLines
      this.ocularAutoScaleTelrad = o.autoScaleTelrad
      this.ocularAutoScaleCcd = o.autoScaleCcd
      this.ocularSemiTransparentMask = o.semiTransparentMask
      this.ocularMaskOpacity = o.maskOpacity
      this.ocularShowResolutionCriteria = o.showResolutionCriteria
      this.ocularAutoSetMountForCcd = o.autoSetMountForCcd
      this.ocularHorizontalCoordinates = o.horizontalCoordinates
      this.ocularSensorCropOverlay = o.sensorCropOverlay
      this.ocularSensorPixelGrid = o.sensorPixelGrid
      this.ocularFocuserOverlay = o.focuserOverlay
      this.ocularScaleImageCircle = o.scaleImageCircle
      this.ocularMaxExposureTimeForCcd = o.maxExposureTimeForCcd
      this.ocularShowContour = o.showContour
      this.ocularShowCardinals = o.showCardinals
      this.ocularAlignCrosshair = o.alignCrosshair
      this.ocularSmallFocuserOverlay = o.smallFocuserOverlay
      this.ocularMediumFocuserOverlay = o.mediumFocuserOverlay
      this.ocularLargeFocuserOverlay = o.largeFocuserOverlay
      this.ocularDmsDegrees = o.dmsDegrees
      this.ocularInitFov = o.initFov
      this.ocularInitDirection = o.initDirection
      this.ocularOagLimits = o.oagLimits
      this.ocularCcdCropHSize = o.ccdCropHSize ?? 250
      this.ocularCcdCropVSize = o.ccdCropVSize ?? 250
      this.ocularCcdPrismRotation = o.ccdPrismRotation ?? 0
      this.ocularGuiPanelEnabled = o.guiPanelEnabled
      this.ocularMagnification = o.magnification ?? 0
      this.ocularActualFov = o.actualFov ?? 0
      this.ocularExitPupil = o.exitPupil ?? 0
      this.ocularLimitMagnitude = o.limitMagnitude ?? 0
      this.ocularCcdFovX = o.ccdFovX ?? 0
      this.ocularCcdFovY = o.ccdFovY ?? 0
      this.ocularCcdPixelScaleX = o.ccdPixelScaleX ?? 0
      this.ocularCcdPixelScaleY = o.ccdPixelScaleY ?? 0
      this.ocularCcdRotation = o.ccdRotation ?? 0
      this.ocularStatusMessage = this.ocularReady ? '' : I18n.t('ocular_status_no_config')
      this.notifyChanged()
    }, () => {
      if (requestId === this.seq) this.ocularLoading = false
      this.ocularStatusMessage = I18n.t('ocular_status_unavailable')
    }, 0, 100, 15)
  }

  // ===== §14 B3-4：LX200 实时位置（live-position）定时器簇整体下沉 =====
  // 原宿主 shouldRefreshTelescopePosition / stopTelescopeLivePosition / scheduleTelescopeLivePosition /
  // refreshTelescopeLivePosition / syncTelescopeLivePosition / setTelescopeLivePosition / lx200Payload /
  // applyTelescopeProfile / applyTelescopeProfiles / applyTelescopeEndpointStatus /
  // loadTelescopeControlStatus 逐字搬入。宿主只保留生命周期谓词 shouldRefreshTelescopePosition
  // 经 hooks 注入；面板开合 / 前后台 / 动作站点改调本 store 方法（§14.6 B3-4）。

  // 原宿主 shouldRefreshTelescopePosition 的语义（读宿主生命周期字段的部分）经 hooks 注入；
  // store 侧读自身 lx200LivePositionEnabled / lx200EditingNew 由宿主谓词一并计算。
  private shouldRefreshLivePosition(): boolean {
    return this.hooks !== null && this.hooks.shouldRefreshTelescopePosition()
  }

  stopTelescopeLivePosition(markStale: boolean = true): void {
    if (this.lx200LivePositionTimer !== 0) {
      clearTimeout(this.lx200LivePositionTimer)
      this.lx200LivePositionTimer = 0
    }
    this.lx200LivePositionRequestPending = false
    this.lx200LivePositionRequestId++
    if (markStale && this.lx200Position.length > 0) {
      this.lx200PositionUpdateState = 'stale'
    }
  }

  scheduleTelescopeLivePosition(delayMs: number = 1000): void {
    if (!this.shouldRefreshLivePosition() || this.lx200LivePositionTimer !== 0) return
    this.lx200LivePositionTimer = setTimeout(() => {
      this.lx200LivePositionTimer = 0
      this.refreshTelescopeLivePosition()
    }, delayMs) as number
  }

  refreshTelescopeLivePosition(): void {
    const port = this.ensurePort()
    if (port === null) return
    if (!this.shouldRefreshLivePosition() || this.lx200LivePositionRequestPending) return
    this.lx200LivePositionRequestPending = true
    this.lx200PositionUpdateState = 'updating'
    const requestId = ++this.lx200LivePositionRequestId
    port.requestInteractive('getTelescopePosition', this.lx200Payload(), (result: TelescopeControlResponse) => {
      if (requestId !== this.lx200LivePositionRequestId) return
      this.lx200LivePositionRequestPending = false
      if (result.ok === true) {
        this.lx200ConnectionState = 'available'
        this.lx200Position = (result.ra ?? '--:--:--') + ' / ' + (result.dec ?? '--°--:--')
        this.lx200PositionUpdatedAt = telescopeUpdateTime()
        this.lx200PositionUpdateState = 'fresh'
        this.scheduleTelescopeLivePosition(1000)
        return
      }
      if (result.state === 'available' || result.state === 'unavailable') this.lx200ConnectionState = result.state
      this.lx200PositionUpdateState = 'error'
      this.lx200Status = telescopeErrorText(result, I18n.t('m_telescope_position_failed'))
      this.scheduleTelescopeLivePosition(1800)
    }, (result: StellariumBridgeResponse) => {
      if (requestId !== this.lx200LivePositionRequestId) return
      this.lx200LivePositionRequestPending = false
      this.lx200PositionUpdateState = 'error'
      this.lx200Status = result.error ?? I18n.t('m_telescope_position_failed')
      this.scheduleTelescopeLivePosition(1800)
    })
  }

  syncTelescopeLivePosition(): void {
    if (!this.shouldRefreshLivePosition()) {
      this.stopTelescopeLivePosition()
      return
    }
    if (this.lx200LivePositionRequestPending || this.lx200LivePositionTimer !== 0) return
    this.refreshTelescopeLivePosition()
  }

  setTelescopeLivePosition(enabled: boolean): void {
    this.lx200LivePositionEnabled = enabled
    if (enabled) {
      this.lx200PositionUpdateState = 'updating'
      this.syncTelescopeLivePosition()
    } else {
      this.stopTelescopeLivePosition()
    }
  }

  lx200Payload(): string {
    return JSON.stringify({
      slot: this.lx200SelectedSlot,
      targetSource: this.lx200TargetSource
    })
  }

  applyTelescopeProfile(profile: TelescopeProfile): void {
    this.stopTelescopeLivePosition(false)
    this.lx200SelectedSlot = profile.slot
    this.lx200Name = profile.name
    this.lx200Protocol = profile.protocol
    this.lx200DeviceModel = profile.deviceModel
    this.lx200Host = profile.host
    this.lx200Port = profile.port.toString()
    this.lx200Equinox = profile.equinox
    this.lx200CommandDelayMs = profile.commandDelayMs
    this.lx200Circles = profile.circles.join(', ')
    this.lx200ConnectionState = profile.protocol === 'simulated' ? 'available' : (profile.state ?? 'not_tested')
    this.lx200Position = ''
    this.lx200PositionUpdatedAt = ''
    this.lx200PositionUpdateState = 'idle'
    if (profile.protocol === 'simulated') {
      this.lx200Transport = I18n.t('m_telescope_transport_simulated')
      this.lx200Scope = I18n.t('m_telescope_scope_offline')
      this.lx200Status = I18n.t('m_telescope_simulator_ready')
    } else if (this.lx200ConnectionState === 'unavailable') {
      this.lx200Status = profile.lastError ?? I18n.t('m_telescope_unavailable')
    } else if (this.lx200ConnectionState === 'available') {
      this.lx200Status = I18n.t('m_telescope_available')
    } else {
      this.lx200Status = I18n.t('m_telescope_not_tested')
    }
    this.lx200EditingNew = false
    this.scheduleTelescopeLivePosition(500)
  }

  applyTelescopeProfiles(result: TelescopeProfilesResponse): void {
    const profiles = result.profiles ?? []
    this.lx200Profiles = profiles
    const selectedSlot = result.selectedSlot ?? (profiles.length > 0 ? profiles[0].slot : 1)
    this.lx200SelectedSlot = selectedSlot
    const selected = profiles.find((profile: TelescopeProfile) => profile.slot === selectedSlot)
    if (selected !== undefined) {
      this.applyTelescopeProfile(selected)
    }
  }

  applyTelescopeEndpointStatus(result: TelescopeControlResponse): void {
    if (result.ok !== true) {
      this.lx200Scope = I18n.t('m_telescope_scope_invalid')
      this.lx200Transport = I18n.t('m_telescope_transport_tcp')
      return
    }
    if (result.simulated === true || result.scope === 'offline_simulator') {
      this.lx200Transport = I18n.t('m_telescope_transport_simulated')
      this.lx200Scope = I18n.t('m_telescope_scope_offline')
      this.lx200ConnectionState = 'available'
      return
    }
    this.lx200Transport = I18n.t('m_telescope_transport_tcp')
    const scope = result.scope as string
    if (scope === 'local_device') this.lx200Scope = I18n.t('m_telescope_scope_local')
    else if (scope === 'local_or_lan') this.lx200Scope = I18n.t('m_telescope_scope_lan')
    else if (scope === 'public_or_unclassified' || scope === 'hostname_or_unclassified') this.lx200Scope = I18n.t('m_telescope_scope_blocked')
    else this.lx200Scope = I18n.t('m_telescope_scope_unknown')
    this.lx200ConnectionState = result.state ?? this.lx200ConnectionState
  }

  loadTelescopeControlStatus(): void {
    const port = this.ensurePort()
    if (port === null) return
    port.requestInteractive('getTelescopeProfiles', '', (result: TelescopeProfilesResponse) => {
      if (result.ok !== true) {
        this.lx200Status = result.error ?? I18n.t('m_telescope_load_failed')
        return
      }
      this.applyTelescopeProfiles(result)
      port.requestInteractive('getTelescopeControl', this.lx200Payload(), (endpoint: TelescopeControlResponse) => {
        this.applyTelescopeEndpointStatus(endpoint)
        this.scheduleTelescopeLivePosition(500)
      })
    })
  }

  // 从 lx200Circles 解析出赤道仪刻度环取值（plan §14.3 A2-2）。原先读宿主
  // telescopeStore.lx200Circles 的函数体逐字迁入本 store，改为零宿主引用；宿主保存档位
  // 调用点改为 this.telescopeStore.telescopeCircleValues()。
  telescopeCircleValues(): number[] {
    const values: number[] = []
    const parts = this.lx200Circles.split(',')
    for (let index = 0; index < parts.length; index += 1) {
      const value = Number(parts[index].trim())
      if (Number.isFinite(value) && value > 0 && value <= 180 && !values.includes(value)) {
        values.push(value)
      }
      if (values.length >= 10) break
    }
    values.sort((left: number, right: number) => left - right)
    return values
  }
}
