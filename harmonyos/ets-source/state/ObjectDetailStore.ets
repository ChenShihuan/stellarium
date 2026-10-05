import { StellariumBridgeResponse, ObjectDetailField, ObjectDetailModel, SatellitePass, SkyCultureDescriptionBlock } from '../pages/StellariumTypes'
import { CommandPort } from '../bridge/CommandPort'

// 宿主 → ObjectDetailStore 的卫星过境助手注入（§13.1 规则 6 / §14.8 规则 2）。
// loadSelectedSatellitePasses 复用未随本片下沉的宿主助手（requestSatellitePasses 走交互桥，
// selectedObjectIsArtificialSatellite 读本 store 字段）；按 §14.5「额外注入」具名回注。
export interface ObjectDetailHostHooks {
  selectedObjectIsArtificialSatellite(): boolean
  requestSatellitePasses(expectedName: string): void
}

// 选中天体的详情数据（原宿主 @State 的 selected*/objectInfo 簇）。
// 详情卡片、信息行与平板检查器都读这份数据，故独立成一个 store。
@Observed
export class ObjectDetailStore {
  selectedName: string = ''
  selectedEnglishName: string = ''
  selectedCatalogId: string = ''
  selectedDetailMediaPath: string = ''
  selectedDetailMediaKind: string = ''
  selectedDetailMediaLabel: string = ''
  selectedDetailModel: ObjectDetailModel | undefined = undefined
  selectedConstellationCultureId: string = ''
  selectedConstellationCultureName: string = ''
  selectedConstellationCultureDescription: string = ''
  selectedConstellationCultureDescriptionBlocks: Array<SkyCultureDescriptionBlock> = []
  selectedConstellationCultureDescriptionSource: string = ''
  selectedConstellationCultureDescriptionExpanded: boolean = false
  selectedObjectType: string = ''
  selectedTemperatureK: number = 0
  selectedType: string = ''
  selectedStatus: string = ''
  selectedInfo: string = ''
  selectedMagnitude: string = ''
  selectedApparentMagnitude: string = ''
  selectedAirmass: string = ''
  selectedExtinction: string = ''
  selectedDetailFields: Array<ObjectDetailField> = []
  selectedDetailLoaded: boolean = false
  selectedSatellitePasses: Array<SatellitePass> = []
  selectedSatellitePassesLoaded: boolean = false
  selectedSatellitePassesRequested: boolean = false
  selectedCoordEq: string = ''
  selectedCoordEqJ2000: string = ''
  selectedCoordApparentAltAz: string = ''
  selectedCoordGeometricAltAz: string = ''
  selectedCoordEcliptic: string = ''
  selectedCoordEclipticJ2000: string = ''
  selectedCoordGalactic: string = ''
  selectedCoordSupergalactic: string = ''
  selectedCoordParallactic: string = ''
  selectedCoordAlt: string = ''
  selectedHourAngle: string = ''
  selectedMeanSiderealTime: string = ''
  selectedApparentSiderealTime: string = ''
  selectedConstellation: string = ''
  selectedDistance: string = ''
  selectedDistanceCompact: string = ''
  selectedDistanceStatus: string = ''
  selectedTleOutdated: boolean = false
  selectedSize: string = ''
  selectedRise: string = ''
  selectedSet: string = ''
  selectedTransit: string = ''
  selectedPhase: string = ''
  selectedElongation: string = ''
  objectInfo: Map<string, string> = new Map()
  selectedLandscapeName: string = ''
  selectedDetailTimer: number = 0
  selectedDetailRequestPending: boolean = false
  selectedUiLayoutTimer: number = 0

  // 详情主卡片当前页索引（0/1/2/3；2 = 资料页）。2026-10-04 review §2.7 残留并入：
  // 原宿主 @State，被三个壳层以 `@Prop activeIndex` 消费（宿主读 store 后下发）；
  // 与 `InfoWindowStore` 刻意不搬的同类宿主控制量区分 —— 本字段语义属详情卡页签。
  bottomCardIndex: number = 0

  // —— 桥注入（§14.1 AB-0；§14 B1-6 起本 store 自持 loadObjectInfo） ——
  private port: CommandPort | null = null
  // 本加载器不使用请求序号（无并发抑制需求）；预留以满足 §14.8 规则 3 的统一约定。
  private seq: number = 0
  private onChanged: (() => void) | null = null
  // 宿主卫星过境助手注入（§14 B2R-4 loadSelectedSatellitePasses）。
  private hooks: ObjectDetailHostHooks | null = null

  // 宿主在 aboutToAppear 注入端口与发布回调；重复注入会覆盖旧值（幂等）。
  attachPort(port: CommandPort, onChanged: () => void): void {
    this.port = port
    this.onChanged = onChanged
  }

  attachHooks(hooks: ObjectDetailHostHooks): void {
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

  // 选中天体资料（`getObjectInfo`）：桥回包解析为 name/坐标/星等字段映射（原宿主 loadObjectInfo，
  // 函数体逐字搬入；仅 this.callInteractive → this.port.requestInteractive、
  // this.objectDetailStore.<f> → this.<f>）。本域无 publish* 发布点，onChanged 为等价空实现。
  loadObjectInfo(): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    port.requestInteractive('getObjectInfo', '', (r: StellariumBridgeResponse) => {
      if (r.ok === true && r.objectInfoData !== undefined) {
        const obj = r.objectInfoData as Record<string, Object>;
        const m = new Map<string, string>();
        if (obj['name'] !== undefined) m.set('name', obj['name'] as string);
        if (obj['nameI18'] !== undefined) m.set('nameI18', obj['nameI18'] as string);
        if (obj['englishName'] !== undefined) m.set('englishName', obj['englishName'] as string);
        if (obj['type'] !== undefined) m.set('type', obj['type'] as string);
        if (obj['ra'] !== undefined) m.set('ra', (obj['ra'] as number).toFixed(4));
        if (obj['dec'] !== undefined) m.set('dec', (obj['dec'] as number).toFixed(4));
        if (obj['alt'] !== undefined) m.set('alt', (obj['alt'] as number).toFixed(2));
        if (obj['az'] !== undefined) m.set('az', (obj['az'] as number).toFixed(2));
        if (obj['magnitude'] !== undefined) m.set('magnitude', (obj['magnitude'] as number).toFixed(2));
        this.objectInfo = m;
        this.notifyChanged()
      }
    })
  }

  // 选中天体为人工卫星且尚未请求过时触发过境查询（原宿主 loadSelectedSatellitePasses，函数体逐字搬入）。
  // 差异仅：this.selectedObjectIsArtificialSatellite() → hooks.selectedObjectIsArtificialSatellite()、
  // this.objectDetailStore.<f> → this.<f>、this.requestSatellitePasses → hooks.requestSatellitePasses。
  loadSelectedSatellitePasses(): void {
    const hooks = this.hooks
    if (hooks === null) {
      return
    }
    if (!hooks.selectedObjectIsArtificialSatellite() || this.selectedName.length === 0 || this.selectedSatellitePassesRequested) return
    this.selectedSatellitePassesRequested = true
    hooks.requestSatellitePasses(this.selectedName)
  }
}
