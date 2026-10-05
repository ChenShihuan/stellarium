import { Scenery3dItem } from '../pages/StellariumTypes'

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
@Observed
export class SceneryStore {
  scenery3dItems: Scenery3dItem[] = []
  scenery3dLoading: boolean = false
  scenery3dEnabled: boolean = false
  scenery3dLoadingId: string = ''
}
