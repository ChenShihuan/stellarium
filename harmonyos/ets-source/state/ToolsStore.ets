// 「工具 / 帮助 / 角度测量 / 录制控制」域的状态簇（Phase 3ao）。
//
// 本片边界：只搬**数据**字段（原宿主 `@State`），不搬任何副作用：
//   - 帮助 / 工具面板：about*（4）、log*（2）、configExport* / configImport*（4）、
//     screenshotSaving（1）、sessionExportText / sessionImportText / sessionImportMsg（3），共 14 个；
//   - 角度测量工具（面板 `angleMeasure`）：angleMeasure*（5）；
//   - 天空资料图加载状态提示：skyTextureStatus*（3）；
//   - 录制控制条的 UI 状态：recording / recordingPaused / recordingUiExpanded（3）。
//   合计 25 个字段。
//
// 刻意**不入 store**（§13.1 规则 4 / 高频进度字段以 @Prop 传入）：
//   - recordCount —— 录制过程中每个可录制命令都写一次，属高频进度读数，保持宿主字段、以 @Prop 传入
//     `RecordingControlBar`；
//   - 录制引擎其余字段（recordBuffer / recordMsg / recordings / replay* / video* / screenVideo* /
//     screenCapture* / scriptControl* 拖拽瞬时量）—— 由桥回调、定时器与触摸每帧写入，留在宿主；
//   - skyTextureStatusTimer / DelayTimer / Polls 与 angleMeasureRequestId —— 定时器/请求标识，非 UI 状态；
//   - sessionJson / sessionExportSig / sessionHint —— 与会话续传（`sessionApply` 500ms 后二次比对）及
//     `ContinuationSection`（astro 域）共享，刻意**不并入 ToolsStore**；2026-10-04 已并入语义更贴的
//     `SessionToolStore`（PlacePanel 早已 `@ObjectLink sessionToolStore`）。
//
// 只放数据与纯计算，不 import UI / NAPI。
@Observed
export class ToolsStore {
  // —— 帮助 / 工具面板（原宿主注释：关于 / 日志 / 配置导入导出） ——
  aboutVersion: string = ''
  aboutQt: string = ''
  aboutUserDir: string = ''
  aboutConfigFile: string = ''
  logText: string = ''
  logVisible: boolean = false
  configExportText: string = ''
  configExportVisible: boolean = false
  configImportText: string = ''
  configImportMsg: string = ''
  screenshotSaving: boolean = false
  sessionExportText: string = ''
  sessionImportText: string = ''
  sessionImportMsg: string = ''

  // —— 角度测量工具（点击两个位置量角） ——
  angleMeasureEnabled: boolean = false
  angleMeasureHasStart: boolean = false
  angleMeasureHasEnd: boolean = false
  angleMeasureText: string = ''
  angleMeasurePending: boolean = false

  // —— 天空资料图加载状态提示（工具状态条，UI 仍在 harmonyShell 内） ——
  skyTextureStatusVisible: boolean = false
  skyTextureStatusText: string = ''
  skyTextureStatusError: boolean = false

  // —— 脚本录制控制条（显示/暂停/展开，属 UI 状态；进度计数不入 store） ——
  recording: boolean = false
  recordingPaused: boolean = false
  recordingUiExpanded: boolean = true
}
