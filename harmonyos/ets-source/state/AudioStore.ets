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
@Observed
export class AudioStore {
  musicEnabled: boolean = false
  audioVolume: number = 0.7
}
