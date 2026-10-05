// 音频（audio）域状态（review §2.7："Prop 风格 → Store 风格"）。
//
// 原宿主 2 个 @State：
//   - musicEnabled：背景音乐开关（持久化于 AppStorage 的 'stellariumSettings' 键，
//     写读经 persistMusicEnabled / loadSavedSettings；播放/静音副作用仍由宿主注入，
//     AudioEngine 是原生桥，按 §13.1 规则 6 不进 store）；
//   - audioVolume：背景音乐音量（AudioPanel 滑块，写回经宿主 onVolumeChange）。
// 二者同为 AudioPanel 的入参，一并下沉使该面板单 store 化。
//
// 普查确认：两字段均为布尔/数值整体赋值，无原地变更。
//
// E4（PLAN §15.12，2026-10-05）：音乐开关行为 toggleMusic / persistMusicEnabled 自宿主下沉。
// 播放/静音副作用（AudioEngine 是原生桥）经 AudioStoreHooks 具名回注，store 不 import NAPI
//（与 LocationStore / NightModeStore / TelescopeStore 的 AppStorage 持久化同例）。
export interface AudioStoreHooks {
  // 背景音乐引擎开关（宿主 AudioEngine.start()/setMuted）。
  setMusicPlaying(enabled: boolean): void
  // UI 提示（宿主 flashHint）。
  flashHint(text: ResourceStr): void
}

@Observed
export class AudioStore {
  musicEnabled: boolean = false
  audioVolume: number = 0.7

  private hooks: AudioStoreHooks | null = null
  // 350ms 防抖时间戳：避免坐标命中与 onClick 双触发导致来回跳（不可观测，不入 store 数据面）。
  private lastMusicToggle: number = 0

  attachHooks(hooks: AudioStoreHooks): void {
    this.hooks = hooks
  }

  // 原宿主 toggleMusic()：防抖后翻转开关、下发引擎、持久化并提示。
  toggleMusic(): void {
    const now = Date.now()
    if (now - this.lastMusicToggle < 350) { return }
    this.lastMusicToggle = now
    this.musicEnabled = !this.musicEnabled
    const hooks = this.hooks
    if (hooks !== null) { hooks.setMusicPlaying(this.musicEnabled) }
    this.persistMusicEnabled()
    if (hooks !== null) { hooks.flashHint(this.musicEnabled ? '音乐：开 ♪' : '音乐：静音') }
  }

  // 原宿主 persistMusicEnabled()：写 AppStorage 的 'stellariumSettings'（AppStorage 非 NAPI）。
  persistMusicEnabled(): void {
    let obj: Record<string, boolean | string> = {}
    const cur = AppStorage.get<string>('stellariumSettings')
    if (cur) {
      try { obj = JSON.parse(cur) as Record<string, boolean | string> } catch (e) { }
    }
    obj['musicEnabled'] = this.musicEnabled
    AppStorage.setOrCreate('stellariumSettings', JSON.stringify(obj))
  }
}
