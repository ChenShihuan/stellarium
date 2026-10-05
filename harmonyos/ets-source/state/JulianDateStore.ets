// 儒略日输入域状态：面板组件以 @ObjectLink 订阅。
//
// D16（PLAN §15 D 轨道 / STATE-REVIEW §10.2）：儒略日行为并入本 store（P2，不新建控制器）。
// 原宿主三法 syncJulianDateFields / applyJulianDateInput / adjustJulianDate 与草稿字段
// julianDateApplyInFlight 逐字迁入；桥（callInteractive → CommandPort.requestInteractive）经
// attachPort 注入；跨域/UI 两个动作（时间转轴 syncFromSimulation、轻量时间读数刷新）经
// JulianDateHostHooks 具名回注（§13.1 规则 6 / §15.7 规则 1：store 不 import UI）。
import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import { I18n } from '../pages/I18n'
import { CommandPort } from '../bridge/CommandPort'

// 宿主 → store 回注：时间转轴同步与时间读数刷新（二者都触碰 UI/控制器，归宿主）。
export interface JulianDateHostHooks {
  // 对应宿主 this.wheel().syncFromSimulation(jd)。
  syncWheelFromSimulation(jd: number): void
  // 对应宿主 refreshSimTimeLight()。
  refreshSimTimeLight(): void
}

@Observed
export class JulianDateStore {
  julianDayInput: string = ''
  modifiedJulianDayInput: string = ''
  julianDateEditing: boolean = false
  julianDateError: string = ''
  julianCalendarSystem: string = 'gregorian'

  // 原宿主私有草稿字段（请求在途标志）随行为迁入，不入可观测语义。
  private julianDateApplyInFlight: boolean = false
  private port: CommandPort | null = null
  private hooks: JulianDateHostHooks | null = null

  attachPort(port: CommandPort): void {
    this.port = port
  }

  attachHooks(hooks: JulianDateHostHooks): void {
    this.hooks = hooks
  }

  // 原宿主 syncJulianDateFields 逐字迁入（this.julianStore.<f> → this.<f>）。
  syncJulianDateFields(response: StellariumBridgeResponse, jd: number): void {
    const mjd = response.mjd !== undefined ? Number(response.mjd) : jd - 2400000.5
    this.julianCalendarSystem = response.calendarSystem === 'julian' ? 'julian' : 'gregorian'
    if (!this.julianDateEditing) {
      this.julianDayInput = jd.toFixed(5)
      this.modifiedJulianDayInput = mjd.toFixed(5)
    }
  }

  // 原宿主 applyJulianDateInput 逐字迁入；差异仅 this.callInteractive → port.requestInteractive、
  // wheel()/refreshSimTimeLight() → hooks（store 不触碰控制器/UI）。
  applyJulianDateInput(scale: string): void {
    if (this.julianDateApplyInFlight) { return }
    const port = this.port
    if (port === null) { return }
    const text = (scale === 'mjd' ? this.modifiedJulianDayInput : this.julianDayInput).trim()
    const value = Number(text)
    if (!Number.isFinite(value)) {
      this.julianDateError = I18n.t('julian_date_invalid')
      return
    }
    this.julianDateError = ''
    this.julianDateApplyInFlight = true
    port.requestInteractive('setJulianDate', scale + '|' + value.toString(), (r: StellariumBridgeResponse) => {
      this.julianDateApplyInFlight = false
      if (r.ok !== true || r.jd === undefined) {
        this.julianDateError = r.error ?? I18n.t('julian_date_invalid')
        return
      }
      this.julianDateEditing = false
      this.syncJulianDateFields(r, Number(r.jd))
      const hooks = this.hooks
      if (hooks !== null) {
        hooks.syncWheelFromSimulation(Number(r.jd))
        hooks.refreshSimTimeLight()
      }
    }, (r: StellariumBridgeResponse) => {
      this.julianDateApplyInFlight = false
      this.julianDateError = r.error ?? I18n.t('julian_date_invalid')
    })
  }

  // 原宿主 adjustJulianDate 逐字迁入（翻档后复用 applyJulianDateInput）。
  adjustJulianDate(scale: string, direction: number): void {
    const text = scale === 'mjd' ? this.modifiedJulianDayInput : this.julianDayInput
    const value = Number(text)
    if (!Number.isFinite(value)) {
      this.julianDateError = I18n.t('julian_date_invalid')
      return
    }
    const adjusted = value + direction * 0.00001
    if (scale === 'mjd') this.modifiedJulianDayInput = adjusted.toFixed(5)
    else this.julianDayInput = adjusted.toFixed(5)
    this.applyJulianDateInput(scale)
  }
}
