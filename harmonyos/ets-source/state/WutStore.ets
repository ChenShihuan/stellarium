import { WutTarget, StellariumBridgeResponse } from '../pages/StellariumTypes'
import { I18n } from '../pages/I18n'
import { CommandPort } from '../bridge/CommandPort'
import { wutCategoryOptions, wutCategoryKey } from '../common/derive/catalog'
// 今晚观测目标（WUT）面板状态（原宿主 @State 的 wut* 簇）。
// 这是 astro 域切片的前置半步：后续把面板内的列表/筛选 UI 抽成组件时，组件直接观察本 store。
// §14 B2A：本域加载器 loadWutTargets 与标题助手 wutCategoryTitle 随桥注入下沉本 store。
@Observed
export class WutStore {
  wutTargets: Array<WutTarget> = []
  wutLoading: boolean = false
  wutProgress: string = ''
  wutCategory: string = 'planets'
  wutCategoriesExpanded: boolean = false
  wutPeriod: string = 'midnight'
  wutMinAltitude: number = 20
  wutMaxMagnitude: number = 6
  wutDirection: string = 'all'
  wutLimitAngularSize: boolean = false
  wutMinAngularSizeArcmin: number = 10
  wutMaxAngularSizeArcmin: number = 600
  wutAngularSizeAvailable: boolean = true
  wutObservationTime: string = ''
  wutHint: string = ''
  wutHasResult: boolean = false

  // —— 桥注入（§14 B2A） ——
  private port: CommandPort | null = null
  private onChanged: (() => void) | null = null
  private wutRequestSequence: number = 0

  attachPort(port: CommandPort, onChanged: () => void): void {
    this.port = port
    this.onChanged = onChanged
  }

  private ensurePort(): CommandPort | null {
    return this.port
  }

  private notifyChanged(): void {
    if (this.onChanged !== null) {
      this.onChanged()
    }
  }

  // Wut 分类按钮的当前标题（原宿主 wutCategoryTitle；读本 store 的 wutCategory + 纯函数模块）。
  wutCategoryTitle(): string {
    const options = wutCategoryOptions()
    for (const option of options) {
      if (wutCategoryKey(option.id) === this.wutCategory) return String(option.label)
    }
    return '天体'
  }

  // 今晚观测目标：原宿主 loadWutTargets，函数体逐字搬入；仅
  // this.callNativeFire → port.fire、this.callLongRunningInteractive → port.requestLongRunning、
  // this.wutStore.<f> → this.<f>、this.publishAstroPanelState() → this.notifyChanged()、
  // this.wutCategoryTitle() → this.wutCategoryTitle()。长任务取消槽 900ms 逐字保留。
  loadWutTargets(): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const requestId = ++this.wutRequestSequence
    // Drop the previous job first: the engine answers "pending" for a mismatching
    // key instead of discarding the running job, so a deliberate category switch
    // has to cancel explicitly.
    port.fire('getWutTargets', '{"cancel":true}')
    this.wutLoading = true
    this.wutHasResult = false
    this.wutProgress = I18n.t('observing_loading') as string
    this.wutHint = ''
    this.notifyChanged()
    const options = JSON.stringify({
      category: this.wutCategory,
      period: this.wutPeriod,
      minAltitude: this.wutMinAltitude,
      maxMagnitude: this.wutMaxMagnitude,
      limitAngularSize: this.wutLimitAngularSize,
      minAngularSizeArcmin: this.wutMinAngularSizeArcmin,
      maxAngularSizeArcmin: this.wutMaxAngularSizeArcmin,
      direction: this.wutDirection
    })
    port.requestLongRunning('getWutTargets', options, (r: StellariumBridgeResponse) => {
      if (requestId !== this.wutRequestSequence) return
      this.wutLoading = false
      this.wutProgress = ''
      this.wutHasResult = true
      if (r.ok === true && r.wutTargets !== undefined) {
        this.wutTargets = r.wutTargets as Array<WutTarget>
        this.wutObservationTime = r.observationTime ?? ''
        this.wutAngularSizeAvailable = r.angularSizeAvailable !== false
        if (!this.wutAngularSizeAvailable) this.wutLimitAngularSize = false
        if (this.wutTargets.length === 0) this.wutHint = I18n.t('observing_no_matches') + this.wutCategoryTitle() + '。'
      } else {
        this.wutTargets = []
        this.wutHint = (r.error ?? '').toString().includes('twilight')
          ? I18n.t('observing_no_twilight')
          : I18n.t('observing_compute_failed')
      }
      this.notifyChanged()
    }, () => {
      if (requestId !== this.wutRequestSequence) return
      this.wutLoading = false
      this.wutProgress = ''
      this.wutHasResult = true
      this.wutTargets = []
      this.wutHint = I18n.t('observing_compute_unavailable')
      this.notifyChanged()
    }, (progress: StellariumBridgeResponse) => {
      if (requestId !== this.wutRequestSequence) return
      const completed = Number(progress.progress ?? 0)
      const total = Number(progress.totalCandidates ?? 0)
      this.wutProgress = total > 0
        ? I18n.t('observing_filtering') + ' ' + completed.toFixed(0) + ' / ' + total.toFixed(0)
        : I18n.t('observing_filtering')
    }, 900, () => requestId !== this.wutRequestSequence)
  }
}
