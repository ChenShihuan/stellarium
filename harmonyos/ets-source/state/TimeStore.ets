// 时间面板域状态。字段名沿用原 @State 名，便于逐片搬迁与对照回滚。
//
// 覆盖两块：① 速度/速率（`timeSpeedIndex` + `timeRateText` + 换挡待定窗口）；
// ② 恒星时显示。时间轮的交互草稿状态在 `TimeWheelStore`，交互行为在 `TimeWheelController`。
@Observed
export class TimeStore {
  timeSpeedIndex: number = 7  // 7=1x realtime (default, new index)
  siderealTimeText: string = '--'

  // ==== 速度/速率（原宿主 @State / 普通字段）====
  timeRateText: string = '1x'
  pendingTimeRate: number = Number.NaN
  pendingTimeRateUntilMs: number = 0
  lastSyncedTimeRate: number = Number.NaN
  lastNonZeroSpeedIndex: number = 7

  // 记录一次"用户主动换挡"：待定窗口内忽略引擎回报的旧速率。
  // 与 syncTimeRateState 的既有 500 ms 窗口同源，集中在这里以免两处各写一遍。
  beginRateChange(rate: number, windowMs: number): void {
    this.pendingTimeRate = rate
    this.pendingTimeRateUntilMs = Date.now() + windowMs
  }

  // 引擎回报的速率是否应被忽略（陈旧或重复）。
  // 返回 true 表示调用方不要据此改写档位与文本。
  shouldIgnoreEngineRate(rate: number): boolean {
    const now = Date.now()
    if (!Number.isNaN(this.pendingTimeRate)) {
      const matchesPending = Math.abs(rate - this.pendingTimeRate) < 1e-9
      if (!matchesPending && now < this.pendingTimeRateUntilMs) {
        return true
      }
      this.pendingTimeRate = Number.NaN
      this.pendingTimeRateUntilMs = 0
    }
    // 换挡瞬间引擎仍会回报上一档速率：同一速率重复回报时不做任何反推，
    // 否则界面会先跳到旧档位再跳回新档位（真机实测到的「实时→倒带→实时」抖动）。
    return !Number.isNaN(this.lastSyncedTimeRate) && Math.abs(rate - this.lastSyncedTimeRate) < 1e-9
  }
}
