import { RecordingEntry } from '../pages/MainWindowModels'
import { ScriptMetadata } from '../pages/StellariumTypes'

// 脚本 / 录制 / 视频导出域中"面板可见"的状态（原宿主的 21 个 @State）。
//
// review §2.7 的第二片（Prop 风格 → Store 风格）。本片只搬**面板入参**字段：这 21 个此前以
// @Prop 快照传给 ScriptsPanel，任一处变化都会让宿主整棵重渲染；改为 @Observed store +
// 面板 @ObjectLink 后刷新粒度收缩到该组件。面板上的录屏开关本就走 ToolsStore，与本 store 并存。
//
// **刻意留在宿主、不搬进来的字段（附理由）**：
//   - `recordBuffer: Array<RecordCmd>`：录制引擎的**追加型工作缓冲**（每次录制命令 `push`，
//     整体重赋值清空）。它不是任何面板的入参；放进观测 store 要么因"只观测字段赋值、观测不到
//     原地 push"而失去刷新，要么被迫每追加一次就整体拷贝数组 —— 两者都不可接受。
//
// 本片（Phase 4 residual）：脚本**播放引擎 / 回放 / 视频导出**残留字段一并迁入本 store。
// 它们此前被列为 review §2.13 的 B3 类（前置＝先把域状态抽成 store），本片正是这个前置：
// `ScriptFocusShell` 经 @ObjectLink 直接订阅播放/回放四态（scriptWaiting / scriptRunning /
// replaying / replayPaused），其余为宿主引擎/回放计算所读。改造前已普查确认全部字段仅整体赋值
// （无 `push/splice/pop/shift/sort/reverse`、无下标赋值、无 `this.<f>.<prop> =`）。
//
// 字段名沿用宿主原名，以便与既有 124 处引用机械对应；动作仍走宿主注入的回调。
// 所有更新都必须是对字段整体赋值（本片已确认 recordings / scriptList 等数组无原地变更）。
@Observed
export class ScriptStore {
  scriptList: string[] = []
  scriptLaunching: boolean = false
  scriptLaunchingName: string = ''
  scriptImporting: boolean = false
  recordCount: number = 0
  recordName: string = ''
  recordMsg: string = ''
  recordings: Array<RecordingEntry> = []
  videoRecording: boolean = false
  videoDir: string = ''
  videoFrameCount: number = 0
  videoMaxFrames: number = 0
  videoFailedFrames: number = 0
  videoArchivePath: string = ''
  videoFps: string = '1'
  videoDuration: string = '5'
  screenVideoRecording: boolean = false
  screenVideoPath: string = ''
  screenVideoBytes: number = 0
  screenVideoStatus: string = ''
  screenCaptureFinalizing: boolean = false

  // —— 脚本播放引擎 / 回放 / 视频导出（review §2.13 B3 前置，Phase 4 residual）——
  scriptMetadata: Record<string, ScriptMetadata> = {}
  scriptFocusActive: boolean = false
  scriptRunning: boolean = false
  scriptWaiting: boolean = false
  scriptWaitMessage: string = ''
  scriptCaptions: Array<string> = []
  scriptId: string = ''
  scriptRate: number = 1
  scriptControlOffsetX: number = 0
  scriptControlOffsetY: number = 0
  replaying: boolean = false
  replayPaused: boolean = false
  replayRate: number = 1
  replayName: string = ''
  videoArchiveFileName: string = ''
  screenVideoFileName: string = ''
}
