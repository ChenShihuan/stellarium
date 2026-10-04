import { I18n } from '../pages/I18n'
import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import { PointerCoordinatesResponse } from '../pages/MainWindowModels'
import { CommandPort } from '../bridge/CommandPort'

// 「视图中心坐标」叠层、「指针坐标」插件面板与「天体详情指向线」开关的状态簇。
//
// 本片边界（Phase 3an）：只搬**设置类**字段 —— 开关、档位（字符串枚举选项）。
//   - 视图坐标叠层：viewCoordinatesVisible / viewCoordinateFamily / viewEquatorialEpoch（3 个，随 saveAppSettings 持久化）；
//   - 指针坐标插件：pointerCoordinatesEnabled / Startup / Button / Constellation / CrossedLines / Elongation /
//     System / Place（8 个持久化设置）+ Loading / Status（2 个瞬时请求态，只被该面板读取）；
//   - 天体详情指向线：objectDetailConnectorVisible（1 个持久化开关）。
//   合计 14 个字段；宿主原有 70 处 `this.<field>` 直接引用，其中 42 处改写为 `this.overlayStore.<field>`，
//   余 28 处随被删的 4 个 @Builder 与 6 个纯查表方法一并消失。
//
// 刻意**不入 store**（§13.1 规则 4 / 叠层实时位置字段不入被观察 store）：
//   - viewCoordinatePrimaryText / viewCoordinateSecondaryText —— 由 50ms 定时器（syncViewCoordinateTimer）
//     从 native `getViewCenterCoordinates` 回填，属逐帧级读数，放进被观察 store 会造成重渲染风暴；
//   - viewCoordinateOffsetX / Y 与拖拽瞬时量（viewCoordinateDragging / DragStartX / DragStartY /
//     DragStartOffsetX / DragStartOffsetY / Snapshot / Timer / RequestPending）—— 触摸移动时每帧写；
//   - objectDetailConnectorX / Y / Length / Angle / EndX / EndY / TargetX / TargetY / TargetOnScreen /
//     AnimateGeometry，以及 objectDetailConnectorTimer / AnimationTimer / LastPanelVisible /
//     LastActivePanel / LastClippedByUi —— 指向线几何由 refreshObjectDetailConnector 按动画帧节流写入。
//   以上一律留在宿主，由组件以 @Prop 接收。
//
// 同域但**未搬**：objectInspectorModelOverlay() 与 objectInspectorModel* 字段簇 —— 属渲染管线（逐帧写回
// 纹理与像素），按既有取舍留在宿主（§13.5 第 3 项备注 2）。
// 本仓不存在 `coordinateGrid*` 字段（网格开关早已在 Phase 3ak 归入 LayerStore）。
//
// 只放数据与纯查表/纯计算，不 import UI / NAPI。
@Observed
export class OverlayStore {
  // —— 视图中心坐标叠层（设置） ——
  viewCoordinatesVisible: boolean = false
  viewCoordinateFamily: string = 'equatorial'
  viewEquatorialEpoch: string = 'j2000'

  // —— 指针坐标插件（设置 + 请求态） ——
  pointerCoordinatesLoading: boolean = false
  pointerCoordinatesStatus: string = ''
  pointerCoordinatesEnabled: boolean = false
  pointerCoordinatesStartup: boolean = false
  pointerCoordinatesButton: boolean = false
  pointerCoordinatesConstellation: boolean = false
  pointerCoordinatesCrossedLines: boolean = false
  pointerCoordinatesElongation: boolean = false
  pointerCoordinatesSystem: string = 'RaDecJ2000'
  pointerCoordinatesPlace: string = 'TopCenter'

  // —— 天体详情指向线（设置） ——
  objectDetailConnectorVisible: boolean = true

  // —— 桥注入（§14.1 AB-0；§14 B1-6 起本 store 自持 loadPointerCoordinates） ——
  private port: CommandPort | null = null
  // 本加载器不使用请求序号（无并发抑制需求）；预留以满足 §14.8 规则 3 的统一约定。
  private seq: number = 0
  private onChanged: (() => void) | null = null

  // 宿主在 aboutToAppear 注入端口与发布回调；重复注入会覆盖旧值（幂等）。
  attachPort(port: CommandPort, onChanged: () => void): void {
    this.port = port
    this.onChanged = onChanged
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

  // 叠层标题：赤道坐标会带历元后缀（原宿主私有方法，逐字搬运）。
  viewCoordinateTitle(): string {
    if (this.viewCoordinateFamily === 'horizontal') { return I18n.t('view_coord_horizontal') }
    if (this.viewCoordinateFamily === 'galactic') { return I18n.t('view_coord_galactic') }
    return I18n.t('view_coord_equatorial') + ' · ' +
      I18n.t(this.viewEquatorialEpoch === 'ofDate' ? 'view_coord_of_date' : 'view_coord_j2000')
  }

  viewCoordinateFamilyLabel(family: string): string {
    if (family === 'horizontal') { return I18n.t('view_coord_horizontal') }
    if (family === 'galactic') { return I18n.t('view_coord_galactic') }
    return I18n.t('view_coord_equatorial')
  }

  viewCoordinatePrimaryLabel(): string {
    if (this.viewCoordinateFamily === 'horizontal') { return I18n.t('view_coord_azimuth') }
    if (this.viewCoordinateFamily === 'galactic') { return I18n.t('view_coord_galactic_longitude') }
    return I18n.t('view_coord_ra')
  }

  viewCoordinateSecondaryLabel(): string {
    if (this.viewCoordinateFamily === 'horizontal') { return I18n.t('view_coord_altitude') }
    if (this.viewCoordinateFamily === 'galactic') { return I18n.t('view_coord_galactic_latitude') }
    return I18n.t('view_coord_dec')
  }

  pointerCoordinateSystemLabel(key: string): string {
    switch (key) {
      case 'RaDecJ2000': return I18n.t('pointer_coord_radec_j2000')
      case 'RaDec': return I18n.t('pointer_coord_radec_date')
      case 'HourAngle': return I18n.t('pointer_coord_hour_angle')
      case 'Ecliptic': return I18n.t('pointer_coord_ecliptic')
      case 'EclipticJ2000': return I18n.t('pointer_coord_ecliptic_j2000')
      case 'AltAzi': return I18n.t('pointer_coord_altaz')
      case 'Galactic': return I18n.t('pointer_coord_galactic')
      case 'Supergalactic': return I18n.t('pointer_coord_supergalactic')
      default: return key
    }
  }

  pointerCoordinatesPlaceLabel(key: string): string {
    switch (key) {
      case 'TopCenter': return I18n.t('pointer_coord_place_top_center')
      case 'TopRight': return I18n.t('pointer_coord_place_top_right')
      case 'RightBottomCorner': return I18n.t('pointer_coord_place_bottom_right')
      case 'NearMouseCursor': return I18n.t('pointer_coord_place_near_pointer')
      case 'Custom': return I18n.t('pointer_coord_place_custom')
      default: return key
    }
  }

  // 指针坐标插件：桥读全部设置项与请求态（原宿主 loadPointerCoordinates，函数体逐字搬入；
  // 仅 this.callNativeWhenReady → this.port.requestWhenReady、this.overlayStore.<f> → this.<f>；
  // 启动期重试档 0/100/15 逐字保留）。本域无 publish* 发布点，onChanged 为等价空实现。
  loadPointerCoordinates(): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    this.pointerCoordinatesLoading = true
    port.requestWhenReady('getPointerCoordinates', '', (r: StellariumBridgeResponse) => {
      this.pointerCoordinatesLoading = false
      const data = (r as PointerCoordinatesResponse).pointerCoordinates
      if (r.ok !== true || data === undefined) {
        this.pointerCoordinatesStatus = I18n.t('plugin_status_unavailable')
        this.notifyChanged()
        return
      }
      this.pointerCoordinatesEnabled = data.enabled
      this.pointerCoordinatesStartup = data.enableAtStartup
      this.pointerCoordinatesButton = data.showCoordinatesButton
      this.pointerCoordinatesConstellation = data.showConstellation
      this.pointerCoordinatesCrossedLines = data.showCrossedLines
      this.pointerCoordinatesElongation = data.showElongation
      this.pointerCoordinatesSystem = data.coordinateSystem
      this.pointerCoordinatesPlace = data.coordinatesPlace
      this.pointerCoordinatesStatus = ''
      this.notifyChanged()
    }, () => {
      this.pointerCoordinatesLoading = false
      this.pointerCoordinatesStatus = I18n.t('plugin_status_unavailable')
      this.notifyChanged()
    }, 0, 100, 15)
  }
}
