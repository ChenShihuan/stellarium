// DE 行星历表（JPL 数值星历）配置状态（原宿主 @State 的 "ephemeris" 域字段，Phase 4m）。
//
// 为何独立成 store（不并入 AstroStore）：
//   - AstroStore 里已有一族**同名前缀但语义完全不同**的字段 ——
//     ephemerisData / ephemerisName / ephemerisMeta / ephemerisError / ephemerisDays /
//     ephemerisStepHours / ephemerisStartOffsetDays / ephemerisMode / ephemerisPrimary /
//     ephemerisSecondary / ephemerisLoading，那是 AstroPanel「星历表」自身的数据。
//   - 本 store 的 ephemerisDe4xxAvailable / Active 是「设置 > 主设置」里的 DE 内核开关，
//     ephemerisStartYear/Month/Day 是 AstroPanel 星历表的起始日期（经 ephemerisStartOptionLabel /
//     chooseEphemerisStartDate / resolveEphemerisStartJD 回调读写）。并入 AstroStore 会造成
//     前缀语义混淆与字段名冲突，故独立。
//
// 消费方：SettingsPanel（@ObjectLink，读 8 个 DE 开关）、AstroPanel（经宿主回调读起始日期）。
// 刻意留在宿主（非本 store 状态）：请求序号、load / toggle / picker 等方法与 pickedDate；
// dsoTotalCount / dsoGalaxies / dsoClusters / dsoNebulae 亦留在宿主（见本次切片报告：
// 零读取、loadDSOCounts 未被调用，无面板消费）。
//
// 约束：所有更新必须是"字段整体赋值"。改造前已普查确认无
// `this.ephemerisDe4xx.push|sort` 或 `this.ephemerisDe4xx.<prop> =` 之类的原地变更。
//
// 2026-10-05（解散 capability/SettingsController.ets）：DE 内核开关动作 setEphemerisEnabled 按
// 「写本域 store 字段 → 并入该 store 方法」下沉；桥经 CommandPort，UI 提示经 EphemerisHostHooks 回注。
import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import { I18n } from '../pages/I18n'
import { CommandPort } from '../bridge/CommandPort'

// 宿主 → EphemerisStore 回注（§13.1 规则 6 / §15.7 规则 4）。
export interface EphemerisHostHooks {
  flashHint(text: ResourceStr): void
}

@Observed
export class EphemerisStore {
  ephemerisDe430Available: boolean = false
  ephemerisDe431Available: boolean = false
  ephemerisDe440Available: boolean = false
  ephemerisDe441Available: boolean = false
  ephemerisDe430Active: boolean = false
  ephemerisDe431Active: boolean = false
  ephemerisDe440Active: boolean = false
  ephemerisDe441Active: boolean = false
  ephemerisStartYear: number = new Date().getFullYear()
  ephemerisStartMonth: number = new Date().getMonth() + 1
  ephemerisStartDay: number = new Date().getDate()

  // —— 桥 / 宿主回注（§14.1 AB-0；2026-10-05 随 DE 开关动作并入） ——
  private port: CommandPort | null = null
  private hooks: EphemerisHostHooks | null = null

  attachPort(port: CommandPort): void {
    this.port = port
  }

  attachHooks(hooks: EphemerisHostHooks): void {
    this.hooks = hooks
  }

  private ensurePort(): CommandPort | null {
    return this.port
  }

  // DE 内核启用开关（原 SettingsController.setEphemerisEnabled，函数体逐字搬入；差异仅
  // this.ephemerisStore.<f> → this.<f>、提示经 hooks.flashHint、桥经 port）。
  setEphemerisEnabled(key: string, available: boolean, enabled: boolean): void {
    const port = this.ensurePort()
    const hooks = this.hooks
    if (port === null || hooks === null) {
      return
    }
    if (!available && enabled) {
      hooks.flashHint('该星历文件未安装，无法启用')
      return
    }
    port.requestInteractive('setEphemerisSetting', key + '|' + (enabled ? '1' : '0'), (r: StellariumBridgeResponse) => {
      if (r.ok !== true) { hooks.flashHint(r.error ?? I18n.t('msg_apply_failed')); return }
      if (key === 'de430') this.ephemerisDe430Active = enabled
      else if (key === 'de431') this.ephemerisDe431Active = enabled
      else if (key === 'de440') this.ephemerisDe440Active = enabled
      else if (key === 'de441') this.ephemerisDe441Active = enabled
    })
  }

  // 星历表起始日期选项标签（原宿主 ephemerisStartOptionLabel，§14 A2-3 逐字搬入）。
  // 读本 store 的 ephemerisStartYear/Month/Day，按 §14.3「读本域 store 字段 → 并入该 store 方法」。
  ephemerisStartOptionLabel(offsetDays: number): string {
    if (offsetDays < 0) {
      return this.ephemerisStartYear.toString() + '-' + this.ephemerisStartMonth.toString().padStart(2, '0') + '-' + this.ephemerisStartDay.toString().padStart(2, '0')
    }
    if (offsetDays === 0) return '当前'
    return '+' + offsetDays.toString() + ' 天'
  }
}
