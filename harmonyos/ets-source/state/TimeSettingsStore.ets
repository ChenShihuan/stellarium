// 时间设置（设置面板「时间」标签页）域状态：日期/时间格式与启动时间来源；消费方以 @ObjectLink 观察。
// `timeSettingsPending` 刻意不并入：它同时被启动时间设置区与其他面板读取，仍由宿主持有并以 @Prop 传入。
// 自持 CommandPort；设置面板打开时的配置回读加载器 loadConfigurationSettings 跨 5 个 store 写入，
// 本 store 作主要归属，其余 store 经 TimeSettingsHostHooks 具名 setter 写入（store 不持有他域 store）。
// applySelectedInfoMode / applyTimeSettings 等与宿主动作共享的助手同样经 hooks 注入。
import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import { CommandPort } from '../bridge/CommandPort'

// 宿主 → TimeSettingsStore 的加载助手注入（store 不持有他域 store，跨域写入经具名 setter）。
export interface TimeSettingsHostHooks {
  // ViewSettingsStore
  setUseMetricUnits(value: boolean): void
  setConfigDitheringMode(mode: string): void
  setAutoZoomResets(value: boolean): void
  // NavigationSettingsStore
  setNavigationMouseEnabled(value: boolean): void
  setNavigationMouseZoomEnabled(value: boolean): void
  setNavigationMoveKeysEnabled(value: boolean): void
  setNavigationZoomKeysEnabled(value: boolean): void
  setNavigationGravityLabelsEnabled(value: boolean): void
  setNavigationStartupFov(value: number): void
  setNavigationStartupAzimuth(value: number): void
  setNavigationStartupAltitude(value: number): void
  setNavigationMaxFov(value: number): void
  // EphemerisStore
  setEphemerisAvailability(de430Available: boolean, de431Available: boolean, de440Available: boolean, de441Available: boolean): void
  setEphemerisActive(de430Active: boolean, de431Active: boolean, de440Active: boolean, de441Active: boolean): void
  // InfoWindowStore
  informationMode(): string
  setInformationMode(mode: string): void
  setInformationCustomMask(mask: number): void
  // 与宿主动作共享的助手（经注入调用）
  applySelectedInfoMode(mode: string): void
  applyTimeSettings(response: StellariumBridgeResponse): void
}

@Observed
export class TimeSettingsStore {
  configDateFormat: string = 'yyyymmdd'
  configTimeFormat: string = '24h'
  startupTimeMode: string = 'actual'
  startupTimeStop: boolean = false
  startupTodayTime: string = '12:00:00'
  startupPresetLocalTime: string = ''
  timeSettingsZone: string = ''
  // 「预设天空时间」（JD）：由宿主 applyTimeSettings 从配置回包写入；当前无 ArkTS 读取方，
  // 保留以供后续使用（默认 0）。
  presetSkyTime: number = 0

  // —— 桥 / 宿主助手注入 ——
  private port: CommandPort | null = null
  // 本加载器不使用请求序号（交互读，无并发抑制需求）；预留以统一各 store 的桥注入约定。
  private seq: number = 0
  private onChanged: (() => void) | null = null
  private hooks: TimeSettingsHostHooks | null = null

  // 宿主在 aboutToAppear 注入端口与发布回调；重复注入会覆盖旧值（幂等）。
  attachPort(port: CommandPort, onChanged: () => void): void {
    this.port = port
    this.onChanged = onChanged
  }

  attachHooks(hooks: TimeSettingsHostHooks): void {
    this.hooks = hooks
  }

  // 加载器统一守卫：未注入端口时静默跳过（不 crash，也不 import 桥）。
  private ensurePort(): CommandPort | null {
    return this.port
  }

  private notifyChanged(): void {
    if (this.onChanged !== null) {
      this.onChanged()
    }
  }

  // 设置面板配置回读：时间格式字段写本 store，其余 store 字段经 hooks 具名 setter 写入。
  loadConfigurationSettings(): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const hooks = this.hooks
    if (hooks === null) {
      return
    }
    port.requestInteractive('getDateFormat', '', (r: StellariumBridgeResponse) => {
      if (r.ok === true && r.format !== undefined) { this.configDateFormat = r.format as string }
    })
    port.requestInteractive('getTimeFormat', '', (r: StellariumBridgeResponse) => {
      if (r.ok === true && r.format !== undefined) { this.configTimeFormat = r.format as string }
    })
    port.requestInteractive('getConfigString', 'astronomy/flag_use_km_for_distance', (r: StellariumBridgeResponse) => {
      if (r.ok === true && r.value !== undefined) {
        hooks.setUseMetricUnits((r.value as string).toLowerCase() === 'true' || r.value === '1')
      }
    })
    port.requestInteractive('getDitheringMode', '', (r: StellariumBridgeResponse) => {
      if (r.ok === true && r.mode !== undefined) { hooks.setConfigDitheringMode(r.mode as string) }
    })
    port.requestInteractive('getNavigationSettings', '', (r: StellariumBridgeResponse) => {
      if (r.ok !== true) return
      if (r.mouseNavigation !== undefined) hooks.setNavigationMouseEnabled(r.mouseNavigation === true)
      if (r.mouseZooming !== undefined) hooks.setNavigationMouseZoomEnabled(r.mouseZooming === true)
      if (r.moveKeys !== undefined) hooks.setNavigationMoveKeysEnabled(r.moveKeys === true)
      if (r.zoomKeys !== undefined) hooks.setNavigationZoomKeysEnabled(r.zoomKeys === true)
      if (r.gravityLabels !== undefined) hooks.setNavigationGravityLabelsEnabled(r.gravityLabels === true)
      if (r.autoZoomResets !== undefined) hooks.setAutoZoomResets(r.autoZoomResets === true)
      if (r.startupFov !== undefined) hooks.setNavigationStartupFov(Number(r.startupFov))
      if (r.startupAzimuth !== undefined) hooks.setNavigationStartupAzimuth(Number(r.startupAzimuth))
      if (r.startupAltitude !== undefined) hooks.setNavigationStartupAltitude(Number(r.startupAltitude))
      if (r.maxFov !== undefined) hooks.setNavigationMaxFov(Number(r.maxFov))
    })
    port.requestInteractive('getEphemerisSettings', '', (r: StellariumBridgeResponse) => {
      if (r.ok !== true) return
      hooks.setEphemerisAvailability(r.de430Available === true, r.de431Available === true, r.de440Available === true, r.de441Available === true)
      hooks.setEphemerisActive(r.de430Active === true, r.de431Active === true, r.de440Active === true, r.de441Active === true)
    })
    port.requestInteractive('getInformationSettings', '', (r: StellariumBridgeResponse) => {
      if (r.ok !== true) return
      hooks.setInformationMode(r.infoMode ?? hooks.informationMode())
      if (r.customInfoMask !== undefined) hooks.setInformationCustomMask(Number(r.customInfoMask))
      hooks.applySelectedInfoMode(hooks.informationMode())
    })
    port.requestInteractive('getTimeSettings', '', (r: StellariumBridgeResponse) => {
      hooks.applyTimeSettings(r)
    })
  }
}
