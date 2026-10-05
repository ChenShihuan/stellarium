import { RecordingEntry, RecordingsResponse, RecordingDetailResponse } from '../pages/MainWindowModels'
import { ScriptMetadata, StellariumBridgeResponse } from '../pages/StellariumTypes'
import { I18n } from '../pages/I18n'
import { resourceText } from '../common/derive/labels'
import { CommandPort } from '../bridge/CommandPort'

// 宿主 → ScriptStore 的 UI 提示 / 动作注入（§13.1 规则 6 / §14.8 规则 2：store 不触碰 UI）。
// loadRecordingByName 回包后经宿主 flashHint 提示（原宿主 this.flashHint 逐字语义）。
// §14 B3-4：视频状态轮询发现录制已结束（wasRecording && !recording）时，原宿主以
// setTimeout(() => this.stopVideoRecording(), 0) 收尾，该动作经 stopVideoRecording 回注。
export interface ScriptHostHooks {
  flashHint(text: ResourceStr): void
  stopVideoRecording(): void
}

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
//
// §14 B1-6：`loadRecordings` 随桥注入搬入本 store（宿主不再持有同名方法）；本域无 publish*
// 发布点，故宿主注入的 onChanged 为等价空实现，notifyChanged() 为无副作用调用。
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

  // —— §14 B3-4：视频状态轮询定时器（原宿主 videoStateTimer 裸字段，随加载器收口迁入本 store） ——
  private videoStateTimer: number = -1

  // —— 桥注入（§14.1 AB-0；§14 B1-6 起本 store 自持 loadRecordings） ——
  private port: CommandPort | null = null
  // 本加载器不使用请求序号（无并发抑制需求）；预留以满足 §14.8 规则 3 的统一约定。
  private seq: number = 0
  private onChanged: (() => void) | null = null
  // 宿主 UI 提示注入（§14 B2R-4 loadRecordingByName）。
  private hooks: ScriptHostHooks | null = null

  // 宿主在 aboutToAppear 注入端口与发布回调；重复注入会覆盖旧值（幂等）。
  attachPort(port: CommandPort, onChanged: () => void): void {
    this.port = port
    this.onChanged = onChanged
  }

  attachHooks(hooks: ScriptHostHooks): void {
    this.hooks = hooks
  }

  // 加载器统一守卫：未注入端口时静默跳过（不 crash，也不 import 桥）。
  private ensurePort(): CommandPort | null {
    return this.port
  }

  private notifyChanged(): void {
    if (this.onChanged !== null) {
      this.onChanged()
    }
  }

  // 脚本面板「已保存录制」列表：桥拉取录制条目（原宿主 loadRecordings，函数体逐字搬入；
  // 仅 this.callInteractive → this.port.requestInteractive、this.scriptStore.<f> → this.<f>）。
  loadRecordings(): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    port.requestInteractive('listRecordings', '', (r: StellariumBridgeResponse) => {
      const resp = r as RecordingsResponse
      this.recordings = resp.items ?? []
      this.notifyChanged()
    })
  }

  // 脚本面板列表：桥拉取脚本名 + 资源元数据（原宿主 loadScriptList，函数体逐字搬入）。
  // 差异仅：this.callInteractive → port.requestInteractive、this.scriptStore.<f> → this.<f>、
  // this.setScriptMetadata → this.setScriptMetadata（同 store 方法）。
  loadScriptList(): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    port.requestInteractive('getScriptList', '', (r: StellariumBridgeResponse) => {
      if (r.ok === true && Array.isArray(r.items)) {
        this.scriptList = r.items as string[]
        this.setScriptMetadata(r.details)
      }
    })
  }

  // 脚本资源元数据表（原宿主 setScriptMetadata，函数体逐字搬入；this.scriptStore.scriptMetadata → this.scriptMetadata）。
  setScriptMetadata(raw: Object | undefined): void {
    if (!Array.isArray(raw)) { return }
    const next: Record<string, ScriptMetadata> = {}
    for (const item of raw as Array<ScriptMetadata>) {
      if (item.file) { next[item.file] = item }
    }
    this.scriptMetadata = next
  }

  // 按文件名载入录制并提示命令条数（原宿主 loadRecordingByName，函数体逐字搬入）。
  // 差异仅：this.callInteractive → port.requestInteractive、this.flashHint → hooks.flashHint。
  loadRecordingByName(file: string, name: string): void {
    const hooks = this.hooks
    const port = this.ensurePort()
    if (hooks === null || port === null) {
      return
    }
    port.requestInteractive('loadRecording', file, (r: StellariumBridgeResponse) => {
      const resp = r as RecordingDetailResponse
      const cmds = resp.commands ?? []
      if (r.ok === true) {
        hooks.flashHint('已加载录制：' + name + '（' + cmds.length + ' 条命令）')
      } else {
        hooks.flashHint('加载录制失败')
      }
    })
  }

  // 视频帧序列录制状态轮询（原宿主 loadVideoRecordingState，函数体逐字搬入；差异仅：
  // this.callInteractive → port.requestInteractive、this.scriptStore.<f> → this.<f>、
  // this.stopVideoStatePolling 为同 store 方法、this.stopVideoRecording 经 hooks 回注）。
  loadVideoRecordingState(): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    port.requestInteractive('getVideoRecordingState', '', (r: StellariumBridgeResponse) => {
      const wasRecording = this.videoRecording
      this.videoRecording = r.recording === true
      this.videoDir = r.dir as string ?? ''
      this.videoFrameCount = r.frameCount as number ?? 0
      this.videoFailedFrames = r.failedFrames as number ?? 0
      this.videoMaxFrames = r.maxFrames as number ?? 0
      if (wasRecording && !this.videoRecording) {
        this.stopVideoStatePolling()
        setTimeout(() => {
          const hooks = this.hooks
          if (hooks !== null) hooks.stopVideoRecording()
        }, 0)
      }
    })
  }

  // 视频状态轮询定时器开启（原宿主 startVideoStatePolling，逐字搬入）。
  startVideoStatePolling(): void {
    this.stopVideoStatePolling()
    this.videoStateTimer = setInterval(() => { this.loadVideoRecordingState() }, 450) as number
  }

  // 视频状态轮询定时器收口（原宿主 stopVideoStatePolling，逐字搬入）。
  stopVideoStatePolling(): void {
    if (this.videoStateTimer >= 0) {
      clearInterval(this.videoStateTimer)
      this.videoStateTimer = -1
    }
  }

  // ==== 脚本元数据/字幕的「取值/文案」助手（§14 A2-3，原宿主私有方法逐字搬入）====
  //
  // 均读本 store 的 scriptMetadata / scriptCaptions / scriptWaitMessage，按 §14.3「读本域
  // store 字段 → 并入该 store 方法（零入参除文件名/保留入参外）」下沉；函数体逐字保留
  //（resourceText 直接 import A1 纯函数模块）。

  // 按文件名取脚本元数据（原宿主 scriptMeta）。
  scriptMeta(filename: string): ScriptMetadata | undefined {
    return this.scriptMetadata[filename]
  }

  // 脚本作者/许可/版本行（原宿主 scriptMetaLine）。
  scriptMetaLine(filename: string): string {
    const metadata = this.scriptMeta(filename)
    if (metadata === undefined) { return I18n.t('resource_not_provided') }
    const values: string[] = []
    values.push(I18n.t('resource_author') + ': ' + resourceText(metadata.author, I18n.t('resource_not_provided')))
    values.push(I18n.t('resource_license') + ': ' + resourceText(metadata.license, I18n.t('resource_not_provided')))
    if (metadata.version && metadata.version.trim().length > 0) { values.push(I18n.t('resource_version') + ': ' + metadata.version.trim()) }
    return values.join(' · ')
  }

  // 脚本来源行（原宿主 scriptSourceLine）。
  scriptSourceLine(filename: string): string {
    const metadata = this.scriptMeta(filename)
    return metadata !== undefined && metadata.source ? I18n.t('resource_source') + ': ' + metadata.source : ''
  }

  // 脚本等待提示（原宿主 scriptWaitDisplayText）。
  scriptWaitDisplayText(): string {
    const message = this.scriptWaitMessage.trim()
    if (message.length === 0 || /press\s+(any\s+)?key\s+to\s+continue/i.test(message)) {
      return I18n.t('script_wait_hint')
    }
    return message
  }

  // 最近三条脚本字幕（原宿主 visibleScriptCaptions）。
  visibleScriptCaptions(): Array<string> {
    return this.scriptCaptions.slice(-3)
  }

  // 最近三条脚本字幕拼接文本（原宿主 visibleScriptCaptionText）。
  visibleScriptCaptionText(): string {
    return this.visibleScriptCaptions().join('\n')
  }

  // 脚本控制条高度（§14 A2-4，原宿主 scriptControlHeight；只读本 store 的 replaying）。
  scriptControlHeight(): number {
    return this.replaying ? 176 : 224
  }
}
