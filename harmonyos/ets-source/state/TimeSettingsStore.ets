// 时间设置（设置面板「时间」标签页）域状态：日期/时间格式与启动时间来源。
// `timeSettingsPending` 刻意不并入：它同时被启动时间设置区与其他面板读取，
// 仍由宿主持有并以 @Prop 传入。
@Observed
export class TimeSettingsStore {
  configDateFormat: string = 'yyyymmdd'
  configTimeFormat: string = '24h'
  startupTimeMode: string = 'actual'
  startupTimeStop: boolean = false
  startupTodayTime: string = '12:00:00'
  startupPresetLocalTime: string = ''
  timeSettingsZone: string = ''
  // 「预设天空时间」（JD）：宿主 applyTimeSettings 从配置回包写入。当前无 ArkTS 读取方，
  // 按 review §2.7 随本域下沉保留（原宿主 @State，默认 0）。
  presetSkyTime: number = 0
}
