import { SkyCultureArtItem, SkyCultureDescriptionBlock } from '../pages/StellariumTypes'

// 「星空文化」面板的**只读详情视图**状态簇（查看器侧）。
//
// 本片边界（Phase 3am）：原宿主的 17 个只读详情字段（解说/描述段落/离线艺术图列表与预览弹层标记/
// 详情加载三态/两处展开标记）逐条搬到这里，保留原类型与默认值。宿主以
// `@State private skyCultureViewStore: SkyCultureViewStore = new SkyCultureViewStore()` 持有。
//
// 明确**不**属于本 store（各自留在宿主）：
//   - 文化列表与当前选择：`skyCultureList` / `skyCultureListLoading` / `skyCultures` /
//     `currentSkyCulture` / `currentSkyCultureId` —— 被领地地图、默认文化设置、若干面板头部交叉使用，
//     不属于"详情视图"，等 Phase 4 面板宿主切片一起收口；
//   - 进度驱动的资源字段：`skyCultureArtStates` / `skyCultureArtThumbnailPixelMaps` /
//     `skyCultureArtPreviewPixelMap` —— 由逐张图片解码回调渐进写入（§13.2 的"高频写入不入 store"），
//     留在宿主以免重渲染风暴；
//   - 面板设置/筛选/标签模式/领地地图等约 90 个 `skyCulture*` 字段 —— 与 `panelContent`
//     的设置 UI 同片（Phase 4）。
//
// 只放数据，不 import UI / NAPI。
@Observed
export class SkyCultureViewStore {
  // —— 详情加载三态 ——
  detailsLoading: boolean = false
  detailsReady: boolean = false
  pendingId: string = ''
  detailError: string = ''

  // —— 解说与描述 ——
  narration: string = ''
  description: string = ''
  descriptionBlocks: Array<SkyCultureDescriptionBlock> = []
  narrationExpanded: boolean = false
  descriptionExpanded: boolean = false

  // —— 离线艺术图列表 ——
  artItems: Array<SkyCultureArtItem> = []
  artExpanded: boolean = false

  // —— 艺术图预览弹层标记（像素图本身留在宿主）——
  artPreviewOpen: boolean = false
  artPreviewPath: string = ''
  artPreviewName: string = ''
  artPreviewRawPath: string = ''
  artPreviewLoading: boolean = false
  artPreviewFailed: boolean = false
}
