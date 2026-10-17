import { CommandPort } from '../bridge/CommandPort'


// 夜间模式状态：布尔开关 + AppStorage 镜像 + 引擎/持久化桥。
// 颜色不再由本 store 提供；组件统一经 WithTheme → onWillApplyTheme → ThemeSlots 取色。

@Observed
export class NightModeStore {
  nightMode: boolean = false

  private port: CommandPort | null = null
  private pendingNightMode: boolean | undefined = undefined
  private pendingNightModeUntilMs: number = 0
  private persistFn: ((nightMode: boolean) => void) | null = null

  attachPort(port: CommandPort): void {
    this.port = port
  }

  attachPersistFn(fn: (nightMode: boolean) => void): void {
    this.persistFn = fn
  }

  syncNightModeFromEngine(engineNight: boolean): void {
    if (this.pendingNightMode !== undefined) {
      const matches = engineNight === this.pendingNightMode
      if (!matches && Date.now() < this.pendingNightModeUntilMs) { return }
      this.pendingNightMode = undefined
      this.pendingNightModeUntilMs = 0
    }
    this.nightMode = engineNight
    AppStorage.setOrCreate('stellariumNightMode', engineNight)
  }

  // 夜间模式写回：用带回执的交互请求，失败自动重试一次，避免首击命令丢失。
  private sendNightMode(enabled: boolean, allowRetry: boolean): void {
    const port = this.port
    if (port === null) return
    port.requestInteractive('setNightMode', enabled ? 'true' : 'false', (r) => {
      if (r.ok !== true) {
        if (allowRetry) this.sendNightMode(enabled, false)
        return
      }
      const actual = r.night === true
      this.pendingNightMode = undefined
      this.pendingNightModeUntilMs = 0
      this.nightMode = actual
      AppStorage.setOrCreate('stellariumNightMode', actual)
    }, () => {
      if (allowRetry) this.sendNightMode(enabled, false)
    })
  }

  applyNightMode(enabled: boolean, persist: boolean): void {
    this.pendingNightMode = enabled
    this.pendingNightModeUntilMs = Date.now() + 1000
    this.nightMode = enabled
    AppStorage.setOrCreate('stellariumNightMode', enabled)
    if (persist) { this.persistNightMode() }
    this.sendNightMode(enabled, true)
  }

  persistNightMode(): void {
    let obj: Record<string, boolean | string> = {}
    const cur = AppStorage.get<string>('stellariumSettings')
    if (cur) {
      try { obj = JSON.parse(cur) as Record<string, boolean | string> } catch (e) { }
    }
    obj['nightMode'] = this.nightMode
    AppStorage.setOrCreate('stellariumSettings', JSON.stringify(obj))
    AppStorage.setOrCreate('stellariumNightMode', this.nightMode)
    if (this.persistFn) { this.persistFn(this.nightMode) }
  }

}
