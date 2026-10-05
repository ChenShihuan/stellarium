// 「大气观测辅助」状态簇（review §2.7）。
//
// 4 个字段全部下沉（原宿主 @State）：气压 / 温度 / 消光（atmoPressure / atmoTemperature /
// atmoExtinction）与大气折射开关（refractionOn）。它们由且仅由时间面板
// （TimePanel → ObservationAidBlock）消费，语义同为「观测点大气条件」。
//
// 为什么 refractionOn 不并入 OverlayStore：其消费方是时间面板（与 atmo* 同一条链），
// 而 OverlayStore 的既定范围是叠层 / 坐标 / 指向线，含天空 / 大气渲染，故与此处成组。
//
// 写点：applyAtmosphereResponse() 已于 2026-10-05 随 capability/SettingsController.ets 解散并入本
// store（写本域 4 字段的纯回包处理）；applyAtmosphere() 动作仍留宿主（§13.1 规则 6）。
//
// 约束：均为标量，只做整体赋值，无原地变更。
import { StellariumBridgeResponse } from '../pages/StellariumTypes'

@Observed
export class AtmosphereStore {
  atmoPressure: number = 1013
  atmoTemperature: number = 10
  atmoExtinction: number = 0.13
  refractionOn: boolean = true

  // 大气参数回包写入（原 SettingsController.applyAtmosphereResponse，函数体逐字搬入；差异仅
  // this.atmosphereStore.<f> → this.<f>）。
  applyAtmosphereResponse(r: StellariumBridgeResponse): void {
    if (r.ok !== true) return
    if (r.pressure !== undefined) this.atmoPressure = r.pressure
    if (r.temperature !== undefined) this.atmoTemperature = r.temperature
    if (r.extinction !== undefined) this.atmoExtinction = r.extinction
    this.refractionOn = (r.refractionOn === true)
  }
}
