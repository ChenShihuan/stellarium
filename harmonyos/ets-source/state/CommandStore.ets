import { CommandCatalogEntry } from '../pages/MainWindowModels'

// 命令控制台（command console）域的面板状态（原宿主 7 个 @State）。
//
// review §2.7 第三批（小簇批处理）之一。本簇面板入参与宿主字段**同名**，机械替换即可。
// 已确认本域无原地变更（`commandNameInput` 上报的那处实为 `length === 0` 读取，是普查
// 正则把 `===` 误判为赋值）⇒ @ObjectLink 语义等价。
@Observed
export class CommandStore {
  commandCatalog: Array<CommandCatalogEntry> = []
  commandSearchText: string = ''
  commandNameInput: string = ''
  commandPayloadInput: string = ''
  commandResultText: string = ''
  commandPendingConfirmation: string = ''
  commandBusy: boolean = false
}
