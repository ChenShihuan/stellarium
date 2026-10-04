import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import { I18n } from '../pages/I18n'
import { CommandPort } from '../bridge/CommandPort'

// 航海星（navStars）域的状态。
//
// review §2.7：本域原为 "Prop 风格" —— 14 个 @State 全留宿主、以 @Prop 快照传入
// NavStarsPanel。现改为 @Observed store + 面板 @ObjectLink，刷新粒度收缩到订阅方
// （与 SatelliteStore / SceneryStore 同法）。
//
// 本域 14 个字段全部是面板入参：
//   - 请求态 navStarsLoading / navStarsStatus；
//   - 总开关 navStarsEnabled 与星表选择 navStarsSetKey / navStarsSetDescription / navStarsSetKeys；
//   - 计数 navStarsCount 与 8 个开关 highlight / limitInfo / upperLimb / tabulated /
//     extraDecimals / useUtc / startup。
//
// §14 B3-1：加载器 loadNavStars 与其配对写方 setNavStarsSetting（含助手 applyNavStarsSetting）
// 同片搬入本 store，两个请求序号 navStarsLoadRequestId / navStarsMutationId 随之入 store
// 作**单一持有者**（宿主零副本、零双写，§14.8 规则 3）。序号保留原语义名（不并作单一 seq），
// 因为二者语义不同：前者只护 loadNavStars 的并发回包，后者护"动作 + 其后重新载入"的代际。
// 面板只回注回调；星表名翻译助手 navStarsSetLabel 仍在组件内（纯函数）。
//
// 约束：所有更新必须是"字段整体赋值"。navStarsSetKeys 只被整体赋值（`= r.setKeys ?? []`），
// 改造前已普查确认无 push/splice 等原地变更。
@Observed
export class NavStarsStore {
  navStarsLoading: boolean = false
  navStarsStatus: string = ''
  navStarsEnabled: boolean = false
  navStarsSetKey: string = 'AngloAmerican'
  navStarsSetDescription: string = ''
  navStarsSetKeys: string[] = []
  navStarsCount: number = 0
  navStarsHighlight: boolean = false
  navStarsLimitInfo: boolean = false
  navStarsUpperLimb: boolean = false
  navStarsTabulated: boolean = false
  navStarsExtraDecimals: boolean = false
  navStarsUseUtc: boolean = false
  navStarsStartup: boolean = false

  // —— 桥注入（§14.1 AB-0 / §14 B3-1） ——
  private port: CommandPort | null = null
  // 原宿主的两个请求序号搬入 store（§14.8 规则 3：单一持有者，宿主不留副本）。
  private navStarsLoadRequestId: number = 0
  private navStarsMutationId: number = 0
  private onChanged: (() => void) | null = null

  // 宿主在 aboutToAppear 注入端口与发布回调；重复注入会覆盖旧值（幂等）。
  attachPort(port: CommandPort, onChanged: () => void): void {
    this.port = port
    this.onChanged = onChanged
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

  // 航海星面板：桥查询当前设置与星表（原宿主 loadNavStars，§14 B3-1 搬入；函数体逐字）。
  // 差异仅：this.callNativeWhenReady → port.requestWhenReady（重试档 0/100/15 逐字保留、
  // onFailure 由第 4 参传入）、this.navStarsStore.<f> → this.<f>。
  loadNavStars(showLoading: boolean = true): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const requestId = ++this.navStarsLoadRequestId
    const mutationId = this.navStarsMutationId
    if (showLoading) this.navStarsLoading = true
    port.requestWhenReady('getNavStars', '', (r: StellariumBridgeResponse) => {
      if (requestId !== this.navStarsLoadRequestId) return
      this.navStarsLoading = false
      if (mutationId !== this.navStarsMutationId) return
      if (r.ok !== true) {
        this.navStarsStatus = I18n.t('plugin_status_unavailable')
      } else {
        this.navStarsEnabled = r.enabled === true
        this.navStarsSetKey = r.setKey ?? 'AngloAmerican'
        this.navStarsSetDescription = r.setDescription ?? ''
        this.navStarsSetKeys = r.setKeys ?? []
        this.navStarsCount = r.starCount ?? 0
        this.navStarsHighlight = r.highlightWhenVisible === true
        this.navStarsLimitInfo = r.limitInfo === true
        this.navStarsUpperLimb = r.upperLimb === true
        this.navStarsTabulated = r.tabulatedDisplay === true
        this.navStarsExtraDecimals = r.extraDecimals === true
        this.navStarsUseUtc = r.useUtc === true
        this.navStarsStartup = r.enableAtStartup === true
        this.navStarsStatus = ''
      }
    }, () => {
      if (requestId !== this.navStarsLoadRequestId) return
      this.navStarsLoading = false
      this.navStarsStatus = I18n.t('plugin_status_unavailable')
    }, 0, 100, 15)
  }

  // 航海星设置项即时回填（原宿主 applyNavStarsSetting，随写方同片搬入；函数体逐字）。
  applyNavStarsSetting(setting: string, value: string): void {
    const enabled = value === '1' || value.toLowerCase() === 'true'
    if (setting === 'enabled') this.navStarsEnabled = enabled
    else if (setting === 'set') this.navStarsSetKey = value
    else if (setting === 'highlightWhenVisible') this.navStarsHighlight = enabled
    else if (setting === 'limitInfo') this.navStarsLimitInfo = enabled
    else if (setting === 'upperLimb') this.navStarsUpperLimb = enabled
    else if (setting === 'tabulatedDisplay') this.navStarsTabulated = enabled
    else if (setting === 'extraDecimals') this.navStarsExtraDecimals = enabled
    else if (setting === 'useUtc') this.navStarsUseUtc = enabled
    else if (setting === 'enableAtStartup') this.navStarsStartup = enabled
  }

  // 写航海星设置（原宿主 setNavStarsSetting，§14 B3-1 搬入；函数体逐字）。
  // 差异仅：this.callInteractive → port.requestInteractive、this.applyNavStarsSetting → 同 store 方法、
  // this.navStarsStore.<f> → this.<f>、this.navStarsMutationId → this.navStarsMutationId（store 序号）。
  setNavStarsSetting(setting: string, value: string): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const mutationId = ++this.navStarsMutationId
    this.applyNavStarsSetting(setting, value)
    port.requestInteractive('setNavStarsSetting', setting + '|' + value, (r: StellariumBridgeResponse) => {
      if (mutationId !== this.navStarsMutationId) return
      if (r.ok === true) {
        if (setting === 'set') this.loadNavStars(false)
      } else {
        this.navStarsStatus = I18n.t('plugin_action_failed')
        this.loadNavStars(false)
      }
    }, () => {
      if (mutationId !== this.navStarsMutationId) return
      this.navStarsStatus = I18n.t('plugin_action_failed')
      this.loadNavStars(false)
    })
  }
}
