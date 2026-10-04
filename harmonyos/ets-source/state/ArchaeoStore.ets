// 古天文辅助线（archaeoLines）域的状态。
//
// review §2.7：本域原为 "Prop 风格" —— 18 个 @State 全留宿主、以 @Prop 快照传入
// ArchaeoLinesPanel，任一开关变化都会让宿主整棵重渲染。现改为 @Observed store +
// 面板 @ObjectLink，刷新粒度收缩到订阅该 store 的组件（与 SatelliteStore / SceneryStore 同法）。
//
// 本域 18 个字段全部是面板入参，无字段需要留在宿主：
//   - 载入态与提示 archaeoLoading / archaeoStatus；
//   - 总开关 archaeoLinesEnabled 与线宽 archaeoLineWidth；
//   - 13 个线条开关 + 当前行星档位 archaeoCurrentPlanet。
//
// 动作仍在宿主（setArchaeoLineSetting / loadArchaeoLines / archaeoLineSettingValue /
// applyArchaeoLineSetting 及 archaeoMutationId），面板只回注回调；store 只承载状态。
//
// 约束：所有更新必须是"字段整体赋值"。改造前已普查确认本域无数组/对象字段，不存在
// 原地 push/splice 或 `this.<f>.<prop> =`（@ObjectLink 观测不到原地变更）。
@Observed
export class ArchaeoStore {
  archaeoLoading: boolean = false
  archaeoStatus: string = ''
  archaeoLinesEnabled: boolean = false
  archaeoEquinox: boolean = false
  archaeoSolstices: boolean = false
  archaeoCrossquarters: boolean = false
  archaeoMajorStandstills: boolean = false
  archaeoMinorStandstills: boolean = false
  archaeoPolarCircles: boolean = false
  archaeoZenithPassage: boolean = false
  archaeoNadirPassage: boolean = false
  archaeoSelectedObject: boolean = false
  archaeoSelectedObjectAzimuth: boolean = false
  archaeoSelectedObjectHourAngle: boolean = false
  archaeoCurrentSun: boolean = false
  archaeoCurrentMoon: boolean = false
  archaeoCurrentPlanet: number = 0
  archaeoLineWidth: number = 1
}
