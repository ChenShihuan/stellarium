import { image } from '@kit.ImageKit'
import { I18n } from '../pages/I18n'
import { SkyCultureMakerArtworkAnchor, SkyCultureMakerConstellation, SkyCultureMakerValidation } from '../pages/MainWindowModels'

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
}
