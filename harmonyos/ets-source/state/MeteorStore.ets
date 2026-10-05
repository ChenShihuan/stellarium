import { MeteorShowerItem } from '../pages/MainWindowModels'

// 流星雨（meteor showers）域的面板状态（原宿主 8 个 @State）。
//
// review §2.7 第三批（小簇批处理）之一。本簇面板入参与宿主字段**同名**，因此机械替换即可。
// 已确认本域数组（msShowerList）无原地变更 ⇒ @ObjectLink 语义等价。
@Observed
export class MeteorStore {
  msEnabled: boolean = false
  msLabels: boolean = false
  msActiveOnly: boolean = false
  msMarker: boolean = false
  msShowerList: MeteorShowerItem[] = []
  msCatalogVersion: string = ''
  msCatalogName: string = ''
  msCatalogSource: string = ''
}
