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
// 动作仍在宿主（loadNavStars / applyNavStarsSetting / setNavStarsSetting 与 navStarsLoadRequestId /
// navStarsMutationId），面板只回注回调；星表名翻译助手 navStarsSetLabel 仍在组件内（纯函数）。
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
}
