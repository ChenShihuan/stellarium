// 时间方程（均时差）域状态：宿主负责与引擎同步与乐观回滚，面板组件以 @ObjectLink 订阅。
@Observed
export class EquationOfTimeStore {
  equationOfTimeEnabled: boolean = false
  equationOfTimeMsFormat: boolean = false
  equationOfTimeInverted: boolean = false
  equationOfTimeStartup: boolean = false
  equationOfTimeMinutes: number = 0
  equationOfTimeLoading: boolean = false
  equationOfTimeStatus: string = ''
}
