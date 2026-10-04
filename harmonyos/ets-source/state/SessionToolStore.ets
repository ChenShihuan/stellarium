import { TonightPlanetRow } from '../pages/MainWindowModels'
import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import { CommandPort } from '../bridge/CommandPort'

// 观测/会话工具区块（观测星球切换、虚拟指星笔、手表陀螺仪模拟、今晚天象、会话续传）的状态簇。
//
// 本片边界（Phase 3as）：原宿主 20 个 `@State private` 字段逐条搬到这里，保留原类型与默认值。
// 宿主以 `@State private sessionToolStore: SessionToolStore = new SessionToolStore()` 持有；
// UI 已下沉为 `panels/astro/SessionToolSections.ets` 下的组件（`@ObjectLink store` + `@Prop` + 回调解入）。
//
// 2026-10-04 追加：会话导出/应用/迁移三字段（sessionJson / sessionExportSig / sessionHint）由宿主并入本
// store（review §2.7）。PlacePanel 早已 `@ObjectLink sessionToolStore`，其 `@Prop sessionHint / sessionJson`
// 已移除，ContinuationSection 就地读 store。
//
// 刻意不搬的宿主职责（跨域 / 桥 / 定时器依赖，§13.1 规则 6）：
//   - native 桥：`setObserverPlanet` / `pointAtSkyTest` / `watchGyroSend` / `watchGyroStart` /
//     `watchGyroStop` / `refreshTonight` / `gotoTonightEvent`；
//   - `watchLastSend`（节流时间戳，每次发送都写、不可观测）留宿主普通字段；
//   - `planetZh()` 与 `nm*()` 主题色留在宿主，以 prop / 回调解入组件。
//
// 只放数据与纯计算，不 import UI / NAPI。
@Observed
export class SessionToolStore {
  // —— 观测星球（可站立星球切换）——
  observerPlanet: string = 'Earth'
  planetList: string[] = []

  // —— 虚拟指星笔（多设备联动）——
  pointAlt: string = '45'
  pointAz: string = '180'
  pointResult: string = ''

  // —— 手表陀螺仪（发射端模拟）——
  watchAlt: number = 45
  watchAz: number = 180
  watchTracking: boolean = false
  watchResult: string = ''

  // —— 今晚天象 ——
  tonightDate: string = ''
  tonightMoon: string = ''
  tonightSun: string = ''
  tonightDark: string = ''
  tonightShowers: string[] = []
  tonightSats: string = ''
  tonightHint: string = ''
  // 点击跳转用：各卡片对应的事件时刻(JD)与锁定对象
  tonightMoonJd: number = 0
  tonightSunJd: number = 0
  tonightShowerJd: number = 0
  tonightPlanetRows: TonightPlanetRow[] = []

  // —— 会话导出 / 应用 / 迁移（原宿主 @State，2026-10-04 并入）——
  // sessionJson 与 sessionExportSig 供 sessionApply 500ms 后二次比对，验证无缝还原；
  // sessionHint 为续传区块即时提示文案。三者均为标量整体赋值（无原地变更）。
  sessionJson: string = ''
  sessionExportSig: string = ''
  sessionHint: string = ''

  // —— 桥注入（§14.1 AB-0；§14 B1-6 起本 store 自持 loadPlanetList） ——
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

  // 「位置」面板观测星球列表：桥拉取全部星球名，仅保留有专属地景、可站立观天的 8 颗
  // （原宿主 loadPlanetList，函数体逐字搬入；仅 this.callInteractive → this.port.requestInteractive、
  // this.sessionToolStore.<f> → this.<f>）。本域无 publish* 发布点，onChanged 为等价空实现。
  loadPlanetList(): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    port.requestInteractive('getObserverPlanetList', '', (r: StellariumBridgeResponse) => {
      if (r.ok === true && r.planets) {
        // 只保留"有专属地景、能站着看天+换地景"的星球；getAllPlanetEnglishNames
        // 还会返回大量彗星/矮行星，列出来既冗长又无对应地景，对切星球毫无意义。
        const standable = ['Earth', 'Moon', 'Mars', 'Jupiter', 'Saturn', 'Uranus', 'Neptune', 'Sun']
        const all = r.planets as string[]
        this.planetList = standable.filter((s) => all.indexOf(s) >= 0)
        this.notifyChanged()
      }
    })
  }
}
