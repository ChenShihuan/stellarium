import { GuidePlayer, GuideState, GuideResult, AstronomyGuide, ASTRONOMY_GUIDES } from '../pages/AstronomyGuide'
import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import { I18n } from '../pages/I18n'
import { CommandPort } from '../bridge/CommandPort'

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
// M1-A 子组④（PLAN §15.4 P2-2 / §15.11 M1-A）：`executeGuideRequest`(63) 与导览引擎/请求序号/
// 定时器（guidePlayer / guideTimer / guideLastRequest / guideLastResult / guideGyroWasEnabled /
// guidePanelWasVisible）整体并入本 store。**定时器由本 store 自持 start/stop**（§15.7 规则 3）：
// `startGuideTimer()` / `stopGuideTimer()` 在 executeGuideRequest 与宿主生命周期（aboutToDisappear /
// 前台切换）收口。跨域/UI/引擎动作经 GuideHostHooks 具名注入（store 不 import UI/他 store）。
//
// 约束：`guideState` 只做**整体赋值**（含 animateTo 内赋值），`speechStatus` 只做整体赋值；
// 改造前已普查确认无 `this.guideState.<prop> =` 之类的原地变更。
export interface GuideHostHooks {
  flashHint(text: ResourceStr): void
  publishGuideState(): void
  // 是否已有脚本/录制裁会话（原宿主 scriptStore.scriptSessionActive(tools.recording, guideState.active)）。
  sessionBusy(): boolean
  polarScopeVisible(): boolean
  panelVisible(): boolean
  setPanelVisible(value: boolean): void
  hideInfoWindow(): void
  applicationInForeground(): boolean
  gyroscopeEnabled(): boolean
  setGyroscopeEnabled(value: boolean): void
  startGyroscope(): void
  stopGyroscope(updateStatus: boolean): void
  stopSkyInertia(): void
  // 停止与导览互斥的宿主后台任务（详情自动刷新 / 时间面板 / 星空文化时间跟随 / 天文计算上下文 / 望远镜实时位置）。
  stopCompetingTasks(): void
  refreshState(): void
  reloadObserverInfo(): void
  // 在 animateTo 动画中应用导览状态（store 不触碰 UI 上下文）。
  animateTo(action: () => void): void
}

@Observed
export class GuideStore {
  guideState: GuideState = { active: false, phase: 'idle', guideId: '', index: 0, count: 0, automatic: false, remaining: 0, error: '' }
  speechStatus: string = ''

  // —— 导览引擎 / 请求 / 定时器（原宿主私有字段，M1-A 子组④迁入） ——
  guidePlayer: GuidePlayer | undefined = undefined
  guideTimer: number = -1
  guideGyroWasEnabled: boolean = false
  guidePanelWasVisible: boolean = false
  guideLastRequest: string = ''
  guideLastResult: GuideResult = { ok: true }

  private port: CommandPort | null = null
  private hooks: GuideHostHooks | null = null

  attachPort(port: CommandPort): void {
    this.port = port
  }

  attachHooks(hooks: GuideHostHooks): void {
    this.hooks = hooks
  }

  // 导览 tick 定时器（原宿主 executeGuideRequest 内的 setInterval，逐字搬入；由本 store 自持）。
  startGuideTimer(): void {
    const hooks = this.hooks
    this.stopGuideTimer()
    this.guideTimer = setInterval(() => {
      if (hooks !== null && hooks.applicationInForeground()) this.guidePlayer?.tick(0.25)
    }, 250) as number
  }

  stopGuideTimer(): void {
    if (this.guideTimer >= 0) {
      clearInterval(this.guideTimer)
      this.guideTimer = -1
    }
  }

  // 宿主生命周期收口：停止播放器与定时器（原宿主 aboutToDisappear / 后台切换调用点，逐字等价）。
  stopPlayer(): void {
    this.guidePlayer?.stop()
  }

  pausePlayer(): void {
    this.guidePlayer?.action('pause')
  }

  // 执行导览请求（原宿主 executeGuideRequest，逐字搬入）。差异仅：this.callInteractive →
  // port.requestInteractive、this.guideStore.<f> → this.<f>、getUIContext().animateTo → hooks.animateTo、
  // publishGuideState/panelVisible/gyro*/stop* → hooks 具名回注、guideTimer → 本 store 自持。
  async executeGuideRequest(commandName: string, payload: string, requestId: string = ''): Promise<void> {
    const hooks = this.hooks
    const port = this.port
    if (hooks === null || port === null) {
      return
    }
    if (!this.guidePlayer) {
      this.guidePlayer = new GuidePlayer((name: string, value: string): Promise<GuideResult> => {
        return new Promise<GuideResult>((resolve) => {
          port.requestInteractive(name, value,
            (response: StellariumBridgeResponse) => resolve({ ok: response.ok === true, error: response.error }),
            () => resolve({ ok: false, error: 'bridge_timeout' }))
        })
      }, (state: GuideState) => {
        const ended = this.guideState.active && !state.active
        if (this.guideState.phase !== state.phase || this.guideState.index !== state.index) {
          hooks.animateTo(() => { this.guideState = state })
        } else {
          this.guideState = state
        }
        hooks.publishGuideState()
        if (ended) {
          this.stopGuideTimer()
          hooks.setPanelVisible(this.guidePanelWasVisible)
          if (this.guideGyroWasEnabled && hooks.applicationInForeground()) {
            hooks.setGyroscopeEnabled(true)
            hooks.startGyroscope()
          }
          this.guideGyroWasEnabled = false
          hooks.refreshState()
          hooks.reloadObserverInfo()
        }
      })
    }
    let result: GuideResult
    if (commandName === 'startGuide') {
      if (hooks.sessionBusy() || hooks.polarScopeVisible() || !ASTRONOMY_GUIDES.some((guide: AstronomyGuide): boolean => guide.id === payload)) {
        result = { ok: false, error: 'session_busy_or_unknown_guide' }
      } else {
        this.guidePanelWasVisible = hooks.panelVisible()
        this.guideGyroWasEnabled = hooks.gyroscopeEnabled()
        hooks.stopGyroscope(false)
        hooks.setGyroscopeEnabled(false)
        hooks.stopSkyInertia()
        hooks.setPanelVisible(false)
        hooks.hideInfoWindow()
        hooks.stopCompetingTasks()
        this.startGuideTimer()
        result = await this.guidePlayer.start(payload)
      }
    } else {
      if (['return', 'next', 'previous', 'stop', 'retry', 'center', 'closer', 'wider'].includes(payload)) {
        hooks.stopSkyInertia()
      }
      result = await this.guidePlayer.action(payload)
    }
    this.guideLastRequest = requestId
    this.guideLastResult = result
    hooks.publishGuideState()
    if (!result.ok) hooks.flashHint(I18n.t('guide_error'))
  }
}
