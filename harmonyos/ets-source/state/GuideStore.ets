import { GuideState } from '../pages/AstronomyGuide'

// 「交互导览 / 语音播报」域状态簇（review §2.7 残留并入，2026-10-04）。
//
// 本批从宿主并入 2 个 `@State` 字段（字段名沿用宿主原名，便于与既有引用机械对应）：
//   - guideState —— 导览播放器（GuidePlayer）的会话快照：phase / guideId / index / count /
//     automatic / remaining / error。宿主多处以 `guideState.active` 做门控分发，`InteractiveGuideShell`
//     经 `@Prop` 逐项接收 phase/index/count/automatic/remaining（简单类型按值下发，规则 3）；
//   - speechStatus —— `getObjectSpokenText` 回包生成的朗读文本。当前构建基于 OpenHarmony 基础 SDK
//     （API 24），未含 CoreSpeechKit，故仅在各详情面板内显示，不做真实 TTS。
//
// 为何**新建** GuideStore 而不并入既有 store：`state/` 下无同义 store —— `ToolsStore` 是工具/帮助/
// 角度测量/录制，`ScriptStore` 是脚本播放/录制/视频，`SessionToolStore` 是会话续传；导览与播报同属
// 独立的一条「交互导览 + 朗读」链，故合并为独立 store。消费方仍以 `@Prop` 快照接收、来源改为宿主读
// store（与 `InfoWindowStore` / `PolarScopeStore` 的既定取舍一致，行为逐字等价）。
//
// 刻意留在宿主（非本 store 状态）：`guidePlayer`（GuidePlayer 引擎实例）、`guideLastRequest` /
//   `guideLastResult`（请求序号与结果）、`guideTimer` / `guideGyroWasEnabled` / `guidePanelWasVisible`
//   （定时器与生命周期），以及 `currentGuide()/currentGuideStep()` 纯查表方法。
//
// 约束：`guideState` 只做**整体赋值**（宿主 `guideState = state`，含 animateTo 内赋值），
//   `speechStatus` 只做整体赋值；改造前已普查确认无 `this.guideState.<prop> =` 之类的原地变更。
@Observed
export class GuideStore {
  guideState: GuideState = { active: false, phase: 'idle', guideId: '', index: 0, count: 0, automatic: false, remaining: 0, error: '' }
  speechStatus: string = ''
}
