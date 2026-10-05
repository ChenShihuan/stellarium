import hilog from '@ohos.hilog'
import { parseObservingList } from '../common/derive/skycult'

// 宿主 → ObservingListStore 的 Preferences 读写注入（§13.1 规则 6 / §14.8 规则 2：store 不得
// import NAPI/UI 上下文，故 preferences + getUIContext 职责整体经 hooks 提供；先例
// ObjectMediaHostHooks.readRawSidecar）。parseObservingList 是 A1 纯函数，store 直接 import。
export interface ObservingListHostHooks {
  // 读 Preferences 'observingList' 原始 JSON（无则 ''）；宿主用 @ohos.data.preferences 实现。
  readObservingListStorage(): Promise<string>
  // 首次读取时把内存值迁移写回 Preferences；宿主用 @ohos.data.preferences 实现。
  writeObservingListStorage(json: string): Promise<void>
  // D15：持久化当前观测列表到 Preferences（原宿主 saveObservingListToStorage）；宿主用
  // @ohos.data.preferences 实现，store 不 import NAPI/UI。
  saveObservingListStorage(): void
}

// 观测列表（observing list）域状态（review §2.7："Prop 风格 → Store 风格"）。
//
// 原宿主 2 个 @State：observingList（用户收藏的天体英文名列表，持久化于 Preferences /
// AppStorage 的 'observingList' 键）、observingListReady（列表首次加载完成标志）。
//
// 为何新建独立 store 而不并入 ObjectDetailStore / AstroStore：
//   - ObjectDetailStore 承载的是"当前选中天体"的瞬时详情，而观测列表是跨选中天体的
//     独立用户数据（有自己的持久化键与增删/清空动作），与选中状态无生命周期绑定；
//   - AstroStore 是天体派生计算（食相/星历/观测量）的状态，与用户收藏列表不同域。
//   二者语义均不相符，故独立成 store（消费面板：ObservingPanel / ObjectPanel /
//   ConfigFallbackPanel，均改为 @ObjectLink）。
//
// 普查确认：observingList 的全部写入都是字段整体赋值（`= filter(...)` / `= concat(...)` /
// `= parseObservingList(...)` / `= []`），无 Array 原地 push/splice，@ObjectLink 可观测。
@Observed
export class ObservingListStore {
  observingList: string[] = []
  observingListReady: boolean = false

  // 宿主 Preferences / UI 上下文注入（§14 B2R-4 loadObservingListFromStorage）。
  private hooks: ObservingListHostHooks | null = null

  attachHooks(hooks: ObservingListHostHooks): void {
    this.hooks = hooks
  }

  // D15：持久化观测列表（原宿主 persistObservingList，函数体逐字搬入）。
  // 差异仅：AppStorage 写入不变；this.saveObservingListToStorage() → hooks.saveObservingListStorage()
  //（Preferences NAPI 收在宿主实现）。
  persistObservingList(): void {
    AppStorage.setOrCreate('observingList', JSON.stringify(this.observingList))
    const hooks = this.hooks
    if (hooks !== null) {
      hooks.saveObservingListStorage()
    }
  }

  // 首次启动从 Preferences 载入观测列表（原宿主 loadObservingListFromStorage，函数体逐字搬入）。
  // 差异仅：getUIContext + preferences I/O → hooks.read/writeObservingListStorage（store 不 import
  // NAPI/UI）；this.obsListStore.<f> → this.<f>；parseObservingList 改由本 store import。
  // 空库时把内存值迁移写回的行为逐字保留。
  async loadObservingListFromStorage(): Promise<void> {
    const hooks = this.hooks
    try {
      const jsonStr: string = hooks !== null ? await hooks.readObservingListStorage() : ''
      if (jsonStr.length > 0) {
        this.observingList = parseObservingList(jsonStr)
      } else if (this.observingList.length > 0 && hooks !== null) {
        // Migrate the pre-existing in-memory value on the first durable read.
        await hooks.writeObservingListStorage(JSON.stringify(this.observingList))
      }
      AppStorage.setOrCreate('observingList', JSON.stringify(this.observingList))
    } catch (e) {
      hilog.warn(0xD002, 'Stellarium', 'load observing list failed: %{public}s', String(e))
    } finally {
      this.observingListReady = true
    }
  }
}
