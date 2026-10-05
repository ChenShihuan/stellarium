import { image } from '@kit.ImageKit'
import { I18n } from '../pages/I18n'
import { SkyCultureMakerArtworkAnchor, SkyCultureMakerConstellation, SkyCultureMakerDraft, SkyCultureMakerValidation } from '../pages/MainWindowModels'
import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import { CommandPort } from '../bridge/CommandPort'

// 宿主 → SkyCultureMakerStore 的加载助手（§14.5 B2R-3「额外注入」）。
// 三者均为宿主内**被多个动作方法共用**的实现（applySkyCultureMakerDraft 亦被保存/校验/重置/撤销等
// 回包消费，skyCultureMakerDraftFromResponse 亦然，ensurePluginLoaded 为宿主通用插件加载器），
// 故保留宿主、经具名 hooks 回注（store 不 import 桥/插件管理层）。
export interface SkyCultureMakerHostHooks {
  applySkyCultureMakerDraft(draft: SkyCultureMakerDraft): void
  ensurePluginLoaded(pluginName: string, callback: () => void, failureCallback?: () => void): void
  skyCultureMakerDraftFromResponse(response: StellariumBridgeResponse): SkyCultureMakerDraft | undefined
}

// 星文化制作器（activePanel === 'skyCultureMaker'）的向导状态簇。
//
// 本片边界（Phase 3am）：原宿主的 29 个 `@State private skyCultureMaker*` 字段逐条搬到这里，
// 保留原类型与默认值。宿主以 `@State private skyCultureMakerStore: SkyCultureMakerStore = new SkyCultureMakerStore()`
// 持有；向导 UI 已下沉为 `panels/skyculture/` 下的组件（`@ObjectLink store` + 回调注入）。
//
// 不搬的宿主职责（跨域/桥/定时器依赖，§13.1 规则 6）：
//   - native 桥（getSkyCultureMakerDraft / saveSkyCultureMakerDraft / validateSkyCultureMakerDraft /
//     resetSkyCultureMakerDraft / undoSkyCultureMakerEdit / import/exportSkyCultureMaker /
//     addSkyCultureMakerSelectedStar / import/removeSkyCultureMakerArtwork / setSkyCultureMakerArtworkAnchor）、
//     ensurePluginLoaded、以及主题色与 panelWidth；
//   - 自动保存定时器（skyCultureMakerSaveTimer + scheduleSkyCultureMakerSave）；
//   - 图片解码与释放（decodeLocalImage / releaseDecodedImage / skyCultureMakerArtworkDecodeGeneration）
//     与 `skyCultureMakerArtworkTouchStartX/Y`、`skyCultureMakerArtworkTouchMoved` 这类手势瞬态。
//
// 只放数据与纯计算，不 import UI / NAPI（image 仅用于 PixelMap 类型）。
@Observed
export class SkyCultureMakerStore {
  // —— 向导骨架与反馈 ——
  tab: number = 0
  loading: boolean = false
  draftReady: boolean = false
  saving: boolean = false
  status: string = ''
  canUndo: boolean = false

  // —— 元数据字段 ——
  id: string = ''
  name: string = ''
  author: string = ''
  license: string = 'CC BY 4.0'
  region: string = ''
  classification: string = 'traditional'
  nativeLang: string = 'zh_CN'
  beginTime: string = '0'
  endTime: string = '0'
  introduction: string = ''
  description: string = ''

  // —— 星座编辑 ——
  constellations: SkyCultureMakerConstellation[] = []
  selectedConstellation: number = -1
  hipLine: string = ''

  // —— 校验与导出 ——
  validation: SkyCultureMakerValidation | undefined = undefined
  exportPath: string = ''
  exportFileName: string = ''

  // —— 星座配图（角点绑定）——
  artworkImporting: boolean = false
  artworkAnchorIndex: number = 0
  artworkRenderWidth: number = 1
  artworkRenderHeight: number = 1
  artworkPixelMap: image.PixelMap | undefined = undefined
  artworkPreviewState: string = 'empty'

  // —— 桥 / 宿主助手注入（§14.1 AB-0；§14 B2R-3 自持 loadSkyCultureMakerDraft）——
  private port: CommandPort | null = null
  // 本加载器使用启动期重试（0/100/150），无并发抑制序号；预留以满足 §14.8 规则 3 的统一约定。
  private seq: number = 0
  private onChanged: (() => void) | null = null
  private hooks: SkyCultureMakerHostHooks | null = null

  // 宿主在 aboutToAppear 注入端口与发布回调；重复注入会覆盖旧值（幂等）。
  attachPort(port: CommandPort, onChanged: () => void): void {
    this.port = port
    this.onChanged = onChanged
  }

  attachHooks(hooks: SkyCultureMakerHostHooks): void {
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

  // —— 纯派生/纯变换（无桥、无定时器、无解码）——

  selected(): SkyCultureMakerConstellation | undefined {
    const index = this.selectedConstellation
    if (index < 0 || index >= this.constellations.length) return undefined
    return this.constellations[index]
  }

  updateConstellation(updated: SkyCultureMakerConstellation): void {
    const index = this.selectedConstellation
    if (index < 0 || index >= this.constellations.length) return
    this.constellations = this.constellations.map((item: SkyCultureMakerConstellation, itemIndex: number) => {
      return itemIndex === index ? updated : item
    })
  }

  artworkAnchor(index: number): SkyCultureMakerArtworkAnchor | undefined {
    const anchors = this.selected()?.image?.anchors ?? []
    return index >= 0 && index < anchors.length ? anchors[index] : undefined
  }

  artworkAnchorHipText(index: number): string {
    const hip = this.artworkAnchor(index)?.hip ?? 0
    return hip > 0 ? hip.toString() : '--'
  }

  artworkPreviewHeight(panelWidth: number): number {
    const artwork = this.selected()?.image
    const width = artwork?.size?.[0] ?? 1
    const height = artwork?.size?.[1] ?? 1
    const availableWidth = Math.max(220, panelWidth - 48)
    return Math.min(228, Math.max(128, availableWidth * height / Math.max(1, width)))
  }

  artworkAnchorX(index: number): number {
    const artwork = this.selected()?.image
    const anchor = this.artworkAnchor(index)
    if (artwork === undefined || anchor === undefined || artwork.size.length !== 2 || anchor.pos.length !== 2) return -20
    return anchor.pos[0] / Math.max(1, artwork.size[0]) * this.artworkRenderWidth - 12
  }

  artworkAnchorY(index: number): number {
    const artwork = this.selected()?.image
    const anchor = this.artworkAnchor(index)
    if (artwork === undefined || anchor === undefined || artwork.size.length !== 2 || anchor.pos.length !== 2) return -20
    return anchor.pos[1] / Math.max(1, artwork.size[1]) * this.artworkRenderHeight - 12
  }

  issueText(code: string, fallback: string): string {
    const key = 'sky_culture_maker_issue_' + code
    const localized = I18n.t(key)
    return localized === key ? fallback : localized
  }

  // 星文化制作器：桥读草稿并落状态（原宿主 loadSkyCultureMakerDraft，函数体逐字搬入；仅
  // this.callNativeWhenReady → this.port.requestWhenReady、this.skyCultureMakerStore.<f> → this.<f>、
  // this.skyCultureMakerDraftFromResponse / this.applySkyCultureMakerDraft / this.ensurePluginLoaded →
  // hooks.*；重试档 0/100/150 逐字保留）。
  loadSkyCultureMakerDraft(): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const hooks = this.hooks
    if (hooks === null) {
      return
    }
    if (this.loading) return
    this.loading = true
    this.draftReady = false
    port.requestWhenReady('getSkyCultureMakerDraft', '', (response: StellariumBridgeResponse) => {
      this.loading = false
      const draft = hooks.skyCultureMakerDraftFromResponse(response)
      if (response.ok !== true || draft === undefined) {
        this.status = response.error ?? I18n.t('sky_culture_maker_load_failed')
        return
      }
      hooks.applySkyCultureMakerDraft(draft)
      const values = response as Record<string, Object>
      this.canUndo = values['canUndo'] === true
      this.status = ''
      hooks.ensurePluginLoaded('SkyCultureMaker', () => {})
    }, () => {
      this.loading = false
      this.status = I18n.t('sky_culture_maker_load_failed')
    }, 0, 100, 150)
  }
}
