// 儒略日输入域状态：宿主负责与引擎同步与校验，面板组件以 @ObjectLink 订阅。
@Observed
export class JulianDateStore {
  julianDayInput: string = ''
  modifiedJulianDayInput: string = ''
  julianDateEditing: boolean = false
  julianDateError: string = ''
  julianCalendarSystem: string = 'gregorian'
}
