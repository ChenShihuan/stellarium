import { image } from '@kit.ImageKit'
import { SkyCultureArtItem, SkyCultureDescriptionBlock, SkyCultureItem, SkyCultureRawItem, StellariumBridgeResponse } from '../pages/StellariumTypes'
import { cleanSkyCultureNarration } from '../common/derive/skycult'
import { CommandPort } from '../bridge/CommandPort'

// 宿主 → SkyCultureViewStore 的加载助手（§14.5 B2R-3「额外注入」）。
// 二者均指向宿主内**未随本片下沉**的 B3 加载器 loadSkyCultureDetails（写 §2.7.1 保留的
// 渐进写入字段 skyCultureArtStates 等，§14.6 已登记 B3）—— 本片只让其作为 hooks 被调用，
// 保持 B3 的登记不变。
export interface SkyCultureViewHostHooks {
  // 使宿主内 in-flight 的详情请求失效（原宿主 `++this.skyCultureDetailsRequestId` 的预增，
  // 该序号与 selectSkyCulture / handleSkyCultureRowArea / 艺术图解码共用，仍归宿主 B3）。
  invalidateSkyCultureDetails(): void
  // 触发宿主 B3 详情加载器（本片不搬）。
  loadSkyCultureDetails(): void
}

// 「星空文化」面板的**只读详情视图**状态簇（查看器侧）。
//
// 本片边界（Phase 3am）：原宿主的 17 个只读详情字段（解说/描述段落/离线艺术图列表与预览弹层标记/
// 详情加载三态/两处展开标记）逐条搬到这里，保留原类型与默认值。宿主以
// `@State private skyCultureViewStore: SkyCultureViewStore = new SkyCultureViewStore()` 持有。
//
// 本片（Phase 4 residual）：文化列表与当前选择（`skyCultures` / `skyCultureList` /
// `skyCultureListLoading` / `currentSkyCulture` / `currentSkyCultureId`）由宿主并入本 store；
// 消费方 `LayersPanel` / `SkyCultureViewTab` / `SettingsQuickLegacyPanel` / `ConfigFallbackPanel`
// 经 @ObjectLink 实时读，宿主自身也改读 store（规则 4）。
//
// 明确**不**属于本 store（各自留在宿主）：
//   - 进度驱动的资源字段：`skyCultureArtStates` / `skyCultureArtThumbnailPixelMaps` —— 由逐张图片解码
//     回调分块/防抖渐进写入（§13.2 的「高频写入不入 store」），留在宿主以免重渲染风暴；
//   - 例外（Phase 5c）：`artPreviewPixelMap`（单张大图）虽同为解码结果，但下沉到预览叠层组件后，
//     组件必须以引用语义（@ObjectLink）拿到 PixelMap 才能渲染 —— @Prop 会拷贝 PixelMap，真机实测
//     导致 Image.onError「绘图资源无法显示」；每张图解码只写一次，不构成重渲染风暴，故收进本 store。
//   - 面板设置/筛选/标签模式/领地地图等约 90 个 `skyCulture*` 字段 —— 与 `panelContent`
//     的设置 UI 同片（Phase 4）。
//
// 只放数据与纯计算，不 import UI / NAPI（image 仅用于 PixelMap 类型）。
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

  // —— 艺术图预览弹层标记与解码结果 ——
  artPreviewOpen: boolean = false
  artPreviewPath: string = ''
  artPreviewName: string = ''
  artPreviewRawPath: string = ''
  artPreviewLoading: boolean = false
  artPreviewFailed: boolean = false
  // 单张大图解码结果：由解码回调渐进写入（每张只写一次），以 @ObjectLink 引用语义供叠层组件渲染。
  artPreviewPixelMap: image.PixelMap | undefined = undefined

  // —— 文化列表与当前选择（Phase 4 residual）——
  skyCultures: string[] = []
  skyCultureList: Array<SkyCultureItem> = []
  skyCultureListLoading: boolean = false
  currentSkyCulture: string = ''
  currentSkyCultureId: string = ''

  // —— 桥 / 宿主助手注入（§14.1 AB-0；§14 B2R-3 自持 loadSkyCultureList）——
  private port: CommandPort | null = null
  // 列表请求序号（原宿主 skyCultureListRequestId 搬入本 store，§14.8 规则 3）。
  private seq: number = 0
  private onChanged: (() => void) | null = null
  private hooks: SkyCultureViewHostHooks | null = null

  // 宿主在 aboutToAppear 注入端口与发布回调；重复注入会覆盖旧值（幂等）。
  attachPort(port: CommandPort, onChanged: () => void): void {
    this.port = port
    this.onChanged = onChanged
  }

  attachHooks(hooks: SkyCultureViewHostHooks): void {
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

  // 星空文化列表：桥读文化清单并触发详情加载（原宿主 loadSkyCultureList，函数体逐字搬入；
  // 仅 this.callInteractive → this.port.requestInteractive、this.skyCultureViewStore.<f> → this.<f>、
  // this.skyCultureListRequestId → this.seq、this.loadSkyCultureDetails() →
  // hooks.loadSkyCultureDetails()、`++this.skyCultureDetailsRequestId` → hooks.invalidateSkyCultureDetails()）。
  loadSkyCultureList(): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const hooks = this.hooks
    if (hooks === null) {
      return
    }
    const requestId = ++this.seq
    hooks.invalidateSkyCultureDetails()
    this.pendingId = ''
    this.skyCultureListLoading = true
    port.requestInteractive('getSkyCultureList', '', (r: StellariumBridgeResponse) => {
      if (requestId !== this.seq) return
      if (r.ok === true && r.items !== undefined && Array.isArray(r.items)) {
        const arr = r.items as Array<SkyCultureRawItem>
        const list: Array<SkyCultureItem> = []
        for (let i = 0; i < arr.length; i++) {
          const obj: SkyCultureRawItem = arr[i]
          const id = obj.id !== undefined ? obj.id : ''
          const name = obj.name !== undefined ? obj.name : id
          const regions: string[] = obj.region !== undefined ? obj.region : []
          list.push({
            id: id,
            name: name,
            region: regions,
            classification: obj.classification !== undefined ? obj.classification : '',
            beginTime: obj.beginTime !== undefined ? obj.beginTime : 0,
            endTime: obj.endTime !== undefined ? obj.endTime : 0,
            constellationCount: obj.constellationCount !== undefined ? obj.constellationCount : 0,
            asterismCount: obj.asterismCount !== undefined ? obj.asterismCount : 0,
            nativeNameCount: obj.nativeNameCount !== undefined ? obj.nativeNameCount : 0,
            artCount: obj.artCount !== undefined ? obj.artCount : 0,
            hasZodiac: obj.hasZodiac === true,
            hasLunarSystem: obj.hasLunarSystem === true,
          });
        }
        this.skyCultureList = list;
        if (r.current !== undefined) {
          this.currentSkyCultureId = r.current as string;
        }
        hooks.loadSkyCultureDetails()
      }
      this.skyCultureListLoading = false
    }, () => {
      if (requestId !== this.seq) return
      this.skyCultureListLoading = false
    })
  }

  // 文化解说段落（原宿主 skyCultureNarrationParagraphs，§14 A2-3 逐字搬入）。
  // 读本 store 的 narration，按 §14.3「读本域 store 字段 → 并入该 store 方法」；
  // cleanSkyCultureNarration 直接 import A1 纯函数模块。
  skyCultureNarrationParagraphs(): string[] {
    return cleanSkyCultureNarration(this.narration).split(/\n+/).map((item: string) => item.trim()).filter((item: string) => item.length > 0)
  }
}
