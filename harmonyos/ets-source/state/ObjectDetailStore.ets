import { ObjectDetailField, ObjectDetailModel, SatellitePass, SkyCultureDescriptionBlock } from '../pages/StellariumTypes'

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
}
