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
}
