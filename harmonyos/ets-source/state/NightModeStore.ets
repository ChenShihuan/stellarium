// 夜视模式（红光）状态 —— 独立模块。
//
// 为什么单独一份 store：夜视模式是**全局视觉模式**，后续要在主界面添加独立按钮，
// 因此它的状态必须能被宿主之外的组件共享（`NightModeToggleRow` 与未来的主界面按钮）。
// 宿主以 @State 持有本 store，`nm*()` 系列配色方法读 `this.nightModeStore.nightMode`；
// 组件以 @ObjectLink 订阅同一实例。
//
// 注：原先还存在一个只被时间面板一行读取的镜像字段 `nightModeOn`，已随本次拆分删除，
// 使"真源"只剩一个（避免双写不同步）。
//
// D16（PLAN §15 D 轨道 / STATE-REVIEW §10.2）：夜视模式行为并入本 store（P2，不新建控制器）。
// 原宿主的三法 syncNightModeFromEngine / applyNightMode / persistNightMode 与两个草稿字段
// pendingNightMode / pendingNightModeUntilMs 逐字迁入；桥（callNative → CommandPort.request）
// 经 attachPort 注入，AppStorage 持久化在 store 内直接完成（与 LocationStore 的持久化同例）。
// 只 import 纯接口 CommandPort（不触碰 libentry.so / @ohos.*）。
import { CommandPort } from '../bridge/CommandPort'

@Observed
export class NightModeStore {
  nightMode: boolean = false

  // —— 桥注入（§14.1；本 store 唯一桥调用是同步 request('setNightMode')） ——
  private port: CommandPort | null = null
  // 换挡瞬间 / 轮询（约每 3 s）可能回报旧值，故设"待定窗口"（原宿主私有字段逐字迁入）。
  private pendingNightMode: boolean | undefined = undefined
  private pendingNightModeUntilMs: number = 0

  attachPort(port: CommandPort): void {
    this.port = port
  }

  // 引擎回报的夜视状态落库。换挡瞬间 / 轮询（约每 3 s）可能回报旧值，
  // 因此在"待定窗口"内忽略与待定值不一致的回报，避免刚打开又被旧值翻回去
  //（与 syncTimeRateState 的去重窗口同一套路）。原宿主 syncNightModeFromEngine 逐字迁入。
  syncNightModeFromEngine(engineNight: boolean): void {
    if (this.pendingNightMode !== undefined) {
      const matches = engineNight === this.pendingNightMode
      if (!matches && Date.now() < this.pendingNightModeUntilMs) { return }
      this.pendingNightMode = undefined
      this.pendingNightModeUntilMs = 0
    }
    this.nightMode = engineNight
  }

  // 夜视模式统一入口：写状态 + 可选持久化 + 下发原生命令。
  // 时间面板的夜视开关与主界面独立按钮都走这一个入口。原宿主 applyNightMode 逐字迁入，
  // 仅 this.callNative → port.request（同步请求）。
  applyNightMode(enabled: boolean, persist: boolean): void {
    this.pendingNightMode = enabled
    this.pendingNightModeUntilMs = Date.now() + 3500
    this.nightMode = enabled
    if (persist) { this.persistNightMode() }
    const port = this.port
    if (port !== null) {
      port.request('setNightMode', enabled ? 'true' : 'false')
    }
  }

  // 原宿主 persistNightMode 逐字迁入（AppStorage 读写不属 NAPI，store 内直接完成）。
  persistNightMode(): void {
    let obj: Record<string, boolean | string> = {}
    const cur = AppStorage.get<string>('stellariumSettings')
    if (cur) {
      try { obj = JSON.parse(cur) as Record<string, boolean | string> } catch (e) { }
    }
    obj['nightMode'] = this.nightMode
    AppStorage.setOrCreate('stellariumSettings', JSON.stringify(obj))
  }

  // 夜视模式颜色方案（计划 §14.3 A2-5；原宿主 private nm* 族逐字迁入）。
  // 原读 this.nightModeStore.nightMode，入本 store 后读 this.nightMode，其余一字未改。
  nmText(): string {
    return this.nightMode ? '#FF6644' : '#E5FFFFFF'
  }
  nmSub(): string {
    return this.nightMode ? '#CC5533' : '#99FFFFFF'
  }
  nmAccent(): string {
    return this.nightMode ? '#FF5533' : '#5B93BF'
  }
  nmBg(): string {
    return this.nightMode ? 'rgba(180, 40, 20, 0.12)' : 'rgba(255,255,255,0.04)'
  }
  nmBorder(): string {
    return this.nightMode ? 'rgba(200, 60, 30, 0.20)' : 'rgba(255,255,255,0.08)'
  }
  nmInput(): string {
    return this.nightMode ? 'rgba(120, 30, 15, 0.50)' : 'rgba(255,255,255,0.06)'
  }
  nmInputBorder(): string {
    return this.nightMode ? 'rgba(200, 60, 30, 0.25)' : 'rgba(214, 238, 255, 0.14)'
  }
  nmPickerSurface(): string {
    return this.nightMode ? '#32120D' : '#101A2B'
  }
  nmPickerHeader(): string {
    return this.nightMode ? '#48170F' : '#18263B'
  }
  nmPickerHeaderActive(): string {
    return this.nightMode ? '#5D1D12' : '#1E3A54'
  }
  nmPickerSelected(): string {
    return this.nightMode ? '#8A2B1B' : '#285F84'
  }
  nmPickerOption(): string {
    return this.nightMode ? '#41160F' : '#172338'
  }
}
