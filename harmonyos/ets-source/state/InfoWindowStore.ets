// 「信息窗 / 天体信息显示级别」域状态簇（review §2.7，2026-10-04）。
//
// 本片边界：原宿主 6 个 `@State private` 字段逐条搬入，保留类型与默认值。宿主以
// `@State private infoWindowStore: InfoWindowStore = new InfoWindowStore()` 持有，
// 宿主全部引用改写为 `this.infoWindowStore.<字段>`。
//
// 字段：
//   - infoWinVisible / infoWinExpanded —— 富化天体详情浮动窗（infoWin*）的可见性与展开态；
//   - informationMode —— 天体信息模式（all / default / short / none / custom）；
//   - informationCustomMask —— 自定义模式下逐字段位掩码（number）；
//   - informationSettingPending —— 模式/掩码桥写入进行中，门控重复请求；
//   - infoLevel —— 由 informationMode 派生的显示级别（0–3），驱动详情卡各信息块显示。
//
// 消费方仍以 @Prop 快照接收、来源改为宿主读 store（不改 @ObjectLink）：
//   - 三个壳层（CompactShell / ExpandedShell / HoverObservatoryShell）的 `infoWinVisible`；
//   - SettingsPanel 的 `informationMode` / `informationSettingPending`。
//   与 PolarScopeStore 的既定取舍一致：宿主因读 store 而重渲染，随后下发 @Prop，
//   行为与改造前逐字等价；也避免改动 SettingsPanel 内约 40 处引用及设置选择测试的字符串断言。
//
// 刻意不搬（非本 store 状态）：fullInspectorRequested / bottomCardIndex / dismissedObjectName /
// lastInfoWinCloseMs —— 与详情卡请求、命中与关闭节流耦合的宿主控制量。
//
// 约束：6 个字段均为标量，只做整体赋值（`informationCustomMask` 的读改写也是整体赋值，
// `infoLevel` 由 applySelectedInfoMode 整体赋值）；改造前已普查确认无原地变更。
//
// 2026-10-05（解散 capability/SettingsController.ets）：信息模式 / 字段开关两个桥动作按「读本域
// store 字段 → 并入该 store 方法」下沉（原 SettingsController.setInformationMode / setInformationField）。
// 桥经 CommandPort；SelectionService 保留族的派生级别写回（applySelectedInfoMode）与选中详情刷新
// （refreshSelectedObject）经 InfoWindowHostHooks 具名回注宿主（§15.7 规则 4）。ObjectDetailStore 的
// 清空动作（清 selectedDetailLoaded）同样经 hook 回注，避免 store 相互 import。
import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import { I18n } from '../pages/I18n'
import { CommandPort } from '../bridge/CommandPort'
import { informationMaskBit } from '../common/derive/skycult'

// 宿主 → InfoWindowStore 回注（§13.1 规则 6 / §15.7 规则 4）。
export interface InfoWindowHostHooks {
  // UI 提示（store 不触碰 UI）。
  flashHint(text: ResourceStr): void
  // SelectionService 保留族（§15.6-6）：信息模式派生级别 / 选中详情刷新本体留宿主。
  applySelectedInfoMode(mode: string): void
  refreshSelectedObject(): void
  // 跨 store（ObjectDetailStore）：清 selectedDetailLoaded。
  clearSelectedDetailLoaded(): void
}

@Observed
export class InfoWindowStore {
  infoWinVisible: boolean = false
  infoWinExpanded: boolean = false
  informationMode: string = 'default'
  informationCustomMask: number = 0
  informationSettingPending: boolean = false
  infoLevel: number = 1

  // —— 桥 / 宿主回注（§14.1 AB-0；2026-10-05 随信息模式动作并入） ——
  private port: CommandPort | null = null
  private hooks: InfoWindowHostHooks | null = null

  // 宿主在 aboutToAppear 注入端口；字段赋值即驱动宿主重绘（store 无 publish* 发布点）。
  attachPort(port: CommandPort): void {
    this.port = port
  }

  attachHooks(hooks: InfoWindowHostHooks): void {
    this.hooks = hooks
  }

  // 加载器统一守卫：未注入端口时静默跳过（不 crash，也不 import 桥）。
  private ensurePort(): CommandPort | null {
    return this.port
  }

  // 天体信息模式切换（原 SettingsController.setInformationMode，函数体逐字搬入；仅
  // this.port.requestInteractive → port.requestInteractive、this.objectDetailStore.selectedDetailLoaded=false
  // → hooks.clearSelectedDetailLoaded、applySelectedInfoMode / refreshSelectedObject → hooks）。
  setInformationMode(mode: string): void {
    const port = this.ensurePort()
    const hooks = this.hooks
    if (port === null || hooks === null) {
      return
    }
    if (this.informationSettingPending || mode === this.informationMode) return
    this.informationSettingPending = true
    port.requestInteractive('setInformationSetting', 'mode|' + mode, (r: StellariumBridgeResponse) => {
      this.informationSettingPending = false
      if (r.ok !== true) { hooks.flashHint(r.error ?? I18n.t('msg_apply_failed')); return }
      this.informationMode = r.infoMode ?? mode
      if (r.customInfoMask !== undefined) this.informationCustomMask = Number(r.customInfoMask)
      hooks.applySelectedInfoMode(this.informationMode)
      hooks.clearSelectedDetailLoaded()
      hooks.refreshSelectedObject()
    }, () => {
      this.informationSettingPending = false
      hooks.flashHint(I18n.t('msg_apply_failed'))
    })
  }

  // 自定义信息模式下单字段开关（原 SettingsController.setInformationField，函数体逐字搬入；
  // 差异同 setInformationMode：桥经 port、清详情经 hooks）。
  setInformationField(key: string, enabled: boolean): void {
    const port = this.ensurePort()
    const hooks = this.hooks
    if (port === null || hooks === null) {
      return
    }
    if (this.informationSettingPending || this.informationMode !== 'custom' || this.informationMaskHas(key) === enabled) return
    const bit = informationMaskBit(key)
    if (bit === 0) return
    const nextMask = enabled ? (this.informationCustomMask | bit) : (this.informationCustomMask & ~bit)
    this.informationSettingPending = true
    port.requestInteractive('setInformationSetting', 'mask|' + nextMask.toString(), (r: StellariumBridgeResponse) => {
      this.informationSettingPending = false
      if (r.ok !== true) { hooks.flashHint(r.error ?? I18n.t('msg_apply_failed')); return }
      this.informationMode = 'custom'
      this.informationCustomMask = r.customInfoMask !== undefined ? Number(r.customInfoMask) : nextMask
      this.infoLevel = 0
      hooks.clearSelectedDetailLoaded()
      hooks.refreshSelectedObject()
    }, () => {
      this.informationSettingPending = false
      hooks.flashHint(I18n.t('msg_apply_failed'))
    })
  }

  // ==== 信息显示「取值/判断」助手（§14 A2-3，原宿主私有方法逐字搬入）====
  //
  // 均读本 store 的 informationMode / informationCustomMask / infoLevel，按 §14.3「读本域
  // store 字段 → 并入该 store 方法（零入参）」下沉；函数体逐字保留（informationMaskHas 依赖
  // A1 纯函数 informationMaskBit）。

  // 自定义模式下某字段位是否开启（原宿主 informationMaskHas）。
  informationMaskHas(key: string): boolean {
    const bit = informationMaskBit(key)
    return bit > 0 && (this.informationCustomMask & bit) === bit
  }

  // 距离信息是否可见（原宿主 distanceInformationVisible）。
  distanceInformationVisible(): boolean {
    return this.infoLevel <= 1 && (this.informationMode !== 'custom' || this.informationMaskHas('distance'))
  }

  // 实时信息块是否可见（原宿主 selectedLiveInfoVisible）。
  selectedLiveInfoVisible(): boolean {
    return this.infoLevel <= 1
  }
}
