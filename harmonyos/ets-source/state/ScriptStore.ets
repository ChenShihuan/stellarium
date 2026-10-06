import { RecordingEntry, RecordingsResponse, RecordingDetailResponse } from '../pages/MainWindowModels'
import { ScriptMetadata, StellariumBridgeResponse } from '../pages/StellariumTypes'
import { I18n } from '../pages/I18n'
import { resourceText } from '../common/derive/labels'
import { scriptControlWidth } from '../common/derive/geometry'
import { CommandPort } from '../bridge/CommandPort'

// 宿主 → ScriptStore 的 UI 提示 / 动作注入（store 不触碰 UI）。
// loadRecordingByName 回包后经宿主 flashHint 提示；视频轮询发现录制结束时，
// 经 stopVideoRecording 回注让宿主收尾。
export interface ScriptHostHooks {
  flashHint(text: ResourceStr): void
  stopVideoRecording(): void
}

// 宿主 → ScriptStore 的原生脚本播放注入。
// 会话忙判定、UI 叠层关闭、宿主后台定时器收口、脚本状态轮询、等待动画（animateTo）与
// 回放/收尾动作经具名回注（store 不 import UI / 他 store）。
export interface ScriptPlaybackHooks {
  flashHint(text: ResourceStr): void
  // 是否已有脚本/录制/导览会话。
  sessionBusy(): boolean
  // 交互导览是否进行中。
  guideActive(): boolean
  // 停止导览。
  requestStopGuide(): void
  // 回放收尾。
  finishReplay(message: string): void
  // 原生脚本 UI 收尾。
  finishNativeScriptUi(message: string): void
  // 关闭脚本相关叠层（时间 / 信息窗 / 陀螺仪等）。
  dismissScriptOverlays(): void
  // 停止与脚本互斥的宿主后台定时器（时间面板 / 星空文化时间跟随 / 极轴镜）。
  stopBackgroundTimers(): void
  startStatusPolling(): void
  stopStatusPolling(): void
  refreshStatus(): void
  // 在 animateTo 动画中执行「等待态清空」（store 不触碰 UI 上下文）。
  runWaitingAnimation(action: () => void): void
  // 脚本启动失败诊断日志。
  logScriptError(filename: string, error: string): void
}

// 脚本 / 录制 / 视频导出域 store：持有面板可见的脚本列表、录制条目、视频与屏幕录制状态、
// 播放引擎/回放四态（scriptWaiting / scriptRunning / replaying / replayPaused）等，
// 由 ScriptsPanel / ScriptFocusShell 经 @ObjectLink 观察。桥经 attachPort 注入 CommandPort，
// 宿主提示 / 播放动作经 ScriptHostHooks / ScriptPlaybackHooks 回注。
//
// 所有字段更新都必须整体赋值：@ObjectLink 观测不到数组原地 push/splice 或对象改属性。
// 录制引擎的追加型工作缓冲 `recordBuffer`（每次命令 push、整体清空）不入被观察 store，留在宿主。
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

  // —— 脚本播放引擎 / 回放 / 视频导出 ——
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

  // —— 原生脚本启动后的宽限期 ——
  // refreshScriptStatus 读它以免刚启动就被判为已结束；playScriptByName 与 CLI 事件写它。
  scriptStartGraceUntil: number = 0

  // —— 视频状态轮询定时器 ——
  private videoStateTimer: number = -1

  // —— 桥注入 ——
  private port: CommandPort | null = null
  // 本加载器无并发抑制需求，seq 预留未用。
  private seq: number = 0
  private onChanged: (() => void) | null = null
  // 宿主 UI 提示注入（loadRecordingByName 回包后提示）。
  private hooks: ScriptHostHooks | null = null
  // 原生脚本播放注入。
  private playbackHooks: ScriptPlaybackHooks | null = null

  // 宿主在 aboutToAppear 注入端口与发布回调；重复注入会覆盖旧值（幂等）。
  // 本域无发布点，onChanged 为宿主空实现。
  attachPort(port: CommandPort, onChanged: () => void): void {
    this.port = port
    this.onChanged = onChanged
  }

  attachHooks(hooks: ScriptHostHooks): void {
    this.hooks = hooks
  }

  attachPlaybackHooks(hooks: ScriptPlaybackHooks): void {
    this.playbackHooks = hooks
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

  // 脚本面板「已保存录制」列表：桥拉取录制条目。
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

  // 脚本面板列表：桥拉取脚本名与资源元数据。
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

  // 脚本资源元数据表：按文件名索引。
  setScriptMetadata(raw: Object | undefined): void {
    if (!Array.isArray(raw)) { return }
    const next: Record<string, ScriptMetadata> = {}
    for (const item of raw as Array<ScriptMetadata>) {
      if (item.file) { next[item.file] = item }
    }
    this.scriptMetadata = next
  }

  // 按文件名载入录制并提示命令条数。
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

  // 视频帧序列录制状态轮询。
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

  // 视频状态轮询定时器开启。
  startVideoStatePolling(): void {
    this.stopVideoStatePolling()
    this.videoStateTimer = setInterval(() => { this.loadVideoRecordingState() }, 450) as number
  }

  // 视频状态轮询定时器收口。
  stopVideoStatePolling(): void {
    if (this.videoStateTimer >= 0) {
      clearInterval(this.videoStateTimer)
      this.videoStateTimer = -1
    }
  }

  // ==== 脚本元数据 / 字幕的取值与文案助手 ====
  //
  // 均读本 store 的 scriptMetadata / scriptCaptions / scriptWaitMessage；resourceText 为
  // 外部纯函数 import。

  // 按文件名取脚本元数据。
  scriptMeta(filename: string): ScriptMetadata | undefined {
    return this.scriptMetadata[filename]
  }

  // 脚本作者/许可/版本行。
  scriptMetaLine(filename: string): string {
    const metadata = this.scriptMeta(filename)
    if (metadata === undefined) { return I18n.t('resource_not_provided') }
    const values: string[] = []
    values.push(I18n.t('resource_author') + ': ' + resourceText(metadata.author, I18n.t('resource_not_provided')))
    values.push(I18n.t('resource_license') + ': ' + resourceText(metadata.license, I18n.t('resource_not_provided')))
    if (metadata.version && metadata.version.trim().length > 0) { values.push(I18n.t('resource_version') + ': ' + metadata.version.trim()) }
    return values.join(' · ')
  }

  // 脚本来源行。
  scriptSourceLine(filename: string): string {
    const metadata = this.scriptMeta(filename)
    return metadata !== undefined && metadata.source ? I18n.t('resource_source') + ': ' + metadata.source : ''
  }

  // 脚本等待提示。
  scriptWaitDisplayText(): string {
    const message = this.scriptWaitMessage.trim()
    if (message.length === 0 || /press\s+(any\s+)?key\s+to\s+continue/i.test(message)) {
      return I18n.t('script_wait_hint')
    }
    return message
  }

  // 最近三条脚本字幕。
  visibleScriptCaptions(): Array<string> {
    return this.scriptCaptions.slice(-3)
  }

  // 最近三条脚本字幕拼接文本。
  visibleScriptCaptionText(): string {
    return this.visibleScriptCaptions().join('\n')
  }

  // 脚本控制条高度：只读本 store 的 replaying。
  scriptControlHeight(): number {
    return this.replaying ? 176 : 224
  }

  // 脚本/导览播放可见性：读本 store 三标志 + 导览 active；后者跨 store 故以显式入参传入。
  scriptPlaybackVisible(guideActive: boolean): boolean {
    return guideActive || this.scriptFocusActive || this.scriptLaunching || this.replaying
  }

  // 是否有脚本会话：读录制标志 + 播放可见性；recording / guideActive 属他 store，以显式入参传入。
  scriptSessionActive(recording: boolean, guideActive: boolean): boolean {
    return recording || this.scriptPlaybackVisible(guideActive)
  }

  // 脚本控制条是否为紧凑档：skyWidth 由调用方传入。
  scriptControlCompact(skyWidth: number): boolean {
    return scriptControlWidth(skyWidth, this.replaying) < 390
  }

  // 脚本按键宽度：skyWidth 由调用方传入。
  scriptKeyButtonWidth(skyWidth: number): number {
    return Math.max(32, Math.min(44, (scriptControlWidth(skyWidth, this.replaying) - 49) / 6))
  }

  // 回放时间轴位置（ms）：开始/暂停/累计耗时由调用方传入；replayPaused/replayRate 读本 store。
  replayTimelineMs(pauseStartedAt: number, startedAt: number, pausedTotal: number): number {
    const now = this.replayPaused && pauseStartedAt > 0 ? pauseStartedAt : Date.now()
    return Math.max(0, now - startedAt - pausedTotal) * this.replayRate
  }

  // ── 原生脚本播放：跨域/UI/定时器经 playbackHooks 具名回注。

  // 按文件名启动原生脚本。
  playScriptByName(filename: string): void {
    const hooks = this.playbackHooks
    const port = this.ensurePort()
    if (hooks === null || port === null) {
      return
    }
    if (hooks.sessionBusy()) {
      return
    }
    this.scriptLaunching = true
    this.scriptLaunchingName = filename
    this.scriptFocusActive = true
    this.scriptId = filename
    this.scriptRate = 1
    this.scriptWaiting = false
    this.scriptWaitMessage = ''
    this.scriptStartGraceUntil = Date.now() + 2500
    hooks.dismissScriptOverlays()
    hooks.stopBackgroundTimers()
    hooks.startStatusPolling()
    hooks.flashHint('正在启动脚本…')
    port.requestInteractive('playScript', filename, (r: StellariumBridgeResponse) => {
      this.scriptLaunching = false
      this.scriptLaunchingName = ''
      if (r.ok === true) {
        hooks.flashHint(I18n.t('msg_script_running'))
        hooks.refreshStatus()
      } else {
        this.scriptFocusActive = false
        this.scriptWaiting = false
        this.scriptWaitMessage = ''
        hooks.stopStatusPolling()
        hooks.logScriptError(filename, r.error ?? '')
        hooks.flashHint(I18n.t('msg_apply_failed'))
      }
    }, () => {
      this.scriptLaunching = false
      this.scriptLaunchingName = ''
      this.scriptFocusActive = false
      this.scriptWaiting = false
      this.scriptWaitMessage = ''
      hooks.stopStatusPolling()
      hooks.flashHint('脚本启动超时，请重试')
    })
  }

  // 继续原生脚本等待。
  continueNativeScript(): void {
    const hooks = this.playbackHooks
    const port = this.ensurePort()
    if (hooks === null || port === null) {
      return
    }
    if (!this.scriptRunning || this.replaying) return
    port.requestInteractive('continueScript', '', (r: StellariumBridgeResponse) => {
      if (r.ok === true) {
        hooks.runWaitingAnimation(() => {
          this.scriptWaiting = false
          this.scriptWaitMessage = ''
        })
        hooks.flashHint(I18n.t('script_continue'))
      } else {
        hooks.flashHint(I18n.t('script_continue_failed'))
      }
    })
  }

  // 停止脚本播放 / 导览。
  stopScriptPlayback(): void {
    const hooks = this.playbackHooks
    const port = this.ensurePort()
    if (hooks === null || port === null) {
      return
    }
    if (hooks.guideActive()) {
      hooks.requestStopGuide()
      return
    }
    if (this.replaying) {
      hooks.finishReplay('回放已停止')
    }
    port.requestInteractive('stopScript', '', (r: StellariumBridgeResponse) => {
      hooks.finishNativeScriptUi(r.ok === true ? I18n.t('script_stopped') : I18n.t('script_stop_failed'))
    })
  }

  // 向原生脚本发送按键。
  sendScriptKey(key: string): void {
    const hooks = this.playbackHooks
    const port = this.ensurePort()
    if (hooks === null || port === null) {
      return
    }
    if (!this.scriptRunning || this.replaying) return
    port.requestInteractive('sendKey', key, (r: StellariumBridgeResponse) => {
      if (r.ok !== true) {
        hooks.flashHint('脚本按键不可用')
      }
    })
  }
}
