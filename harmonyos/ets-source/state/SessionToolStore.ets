import { TonightPlanetRow } from '../pages/MainWindowModels'

// 观测/会话工具区块（观测星球切换、虚拟指星笔、手表陀螺仪模拟、今晚天象）的状态簇。
//
// 本片边界（Phase 3as）：原宿主 20 个 `@State private` 字段逐条搬到这里，保留原类型与默认值。
// 宿主以 `@State private sessionToolStore: SessionToolStore = new SessionToolStore()` 持有；
// UI 已下沉为 `panels/astro/SessionToolSections.ets` 下的组件（`@ObjectLink store` + `@Prop` + 回调解入）。
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
}
