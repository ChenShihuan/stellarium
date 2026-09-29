// 时间面板域状态。字段名沿用原 @State 名，便于逐片搬迁与对照回滚。
@Observed
export class TimeStore {
  timeSpeedIndex: number = 7  // 7=1x realtime (default, new index)
}
