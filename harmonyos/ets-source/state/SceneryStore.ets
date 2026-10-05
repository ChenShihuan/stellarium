import { Scenery3dItem, StellariumBridgeResponse } from '../pages/StellariumTypes'
import { Scenery3dResponse } from '../pages/MainWindowModels'
import { CommandPort } from '../bridge/CommandPort'

// 宿主 → SceneryStore 的回注（§13.1 规则 6 / §14.8 规则 2：store 不 import 桥/UI/他 store）。
// `scenery3dCurrentId` 是 §2.7.1 登记「引擎自用 / 已登记约定」的宿主保留字段（宿主自用：记住
// 当前场景以做恢复），**不搬进 store**；本加载器只经此 setter 回注上报（§14 B3-5）。
export interface SceneryHostHooks {
  setScenery3dCurrentId(id: string): void
}

// 3D 场景（scenery3d）域中"面板可见"的状态（原宿主 4 个 @State）。
//
// review §2.7 第三批（小簇批处理：scenery3d / catalogs / meteorShowers / commandConsole）之一。
//
// 命名说明：本面板的 @Prop 名与宿主字段名**不同**（`pluginEnabled←scenery3dEnabled`、
// `loading←scenery3dLoading`、`items←scenery3dItems`、`loadingId←scenery3dLoadingId`）。
// 这里沿用**宿主字段名**，面板改按 store 字段读取 —— 若改成面板名，就要同时重命名宿主里
// 16 处引用，收益为零而改错风险显著。
//
// `scenery3dCurrentId` 不是本面板入参（宿主自用：记住当前场景以做恢复），刻意留在宿主。
//
// §14 B3-5：`loadScenery3d` 由本 store 自持（宿主不再持有同名方法）。桥经 attachPort 注入的
// CommandPort 调用（requestWhenReady ↔ callNativeWhenReady，默认 200ms × 60 逐字保留）；
// 宿主保留 `scenery3dCurrentId` 经 SceneryHostHooks.setScenery3dCurrentId 回注。
@Observed
export class SceneryStore {
  scenery3dItems: Scenery3dItem[] = []
  scenery3dLoading: boolean = false
  scenery3dEnabled: boolean = false
  scenery3dLoadingId: string = ''

  // —— 桥 / 宿主回注注入（§14.1 AB-0） ——
  private port: CommandPort | null = null
  // 本加载器不使用请求序号（无并发抑制需求）；预留以满足 §14.8 规则 3 的统一约定。
  private seq: number = 0
  private hooks: SceneryHostHooks | null = null

  // 宿主在 aboutToAppear 注入端口；重复注入会覆盖旧值（幂等）。
  attachPort(port: CommandPort): void {
    this.port = port
  }

  attachHooks(hooks: SceneryHostHooks): void {
    this.hooks = hooks
  }

  // 加载器统一守卫：未注入端口时静默跳过（不 crash，也不 import 桥）。
  private ensurePort(): CommandPort | null {
    return this.port
  }

  // 3D 场景列表：桥读场景清单并写入本域状态（原宿主 loadScenery3d，函数体逐字搬入；
  // 仅 this.callNativeWhenReady → port.requestWhenReady、this.sceneryStore.<f> → this.<f>、
  // this.scenery3dCurrentId → hooks.setScenery3dCurrentId）。
  loadScenery3d(): void {
    const hooks = this.hooks
    const port = this.ensurePort()
    if (hooks === null || port === null) {
      return
    }
    this.scenery3dLoading = true
    port.requestWhenReady('getScenery3dList', '', (r: StellariumBridgeResponse) => {
      this.scenery3dLoading = false
      const response = r as Scenery3dResponse
      if (response.ok !== true) return
      this.scenery3dItems = response.items ?? []
      hooks.setScenery3dCurrentId(response.current ?? '')
      this.scenery3dLoadingId = response.loading ?? ''
      this.scenery3dEnabled = response.enabled === true
    })
  }
}
