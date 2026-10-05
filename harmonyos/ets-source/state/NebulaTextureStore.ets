import { NebulaTextureStatus } from '../pages/MainWindowModels'

// 星云贴图（nebulaTextures）面板状态（原宿主 @State，Phase 4m）。
//
// review §2.7：本域原为 "Prop 风格" —— 宿主把 NebulaTextureStatus 拆成若干 @Prop 标志/计数/条目
// 传给 NebulaTexturesPanel。现改为 @Observed store + 面板 @ObjectLink，面板就地读
// nebulaTextureStatus 与加载/导入态，刷新范围收窄到本面板。
//
// 本域 5 个字段全部下沉：状态对象 nebulaTextureStatus、加载态 nebulaTextureLoading、
// 待确认 nebulaTexturePending、导入中 nebulaTextureImporting、动作提示 nebulaTextureActionStatus。
//
// 刻意留在宿主（非本 store 状态）：宿主私有动作
// loadNebulaTextureStatus / setNebulaTextureVisible / setNebulaTextureFlag / refreshNebulaTextures /
// gotoNebulaTexture / removeNebulaTexture / importNebulaTextureFile 与文件选择器；
// 这些动作继续写本 store（宿主持有 @State 实例，读 store 会重绘宿主，符合 §13.1 规则 4）。
//
// 约束：所有更新必须是"字段整体赋值"。改造前已普查确认
// nebulaTextureStatus 只被整体赋值（`= r as NebulaTextureStatus` / `= status`），
// 其余 4 个标量无原地变更。
@Observed
export class NebulaTextureStore {
  nebulaTextureStatus: NebulaTextureStatus | undefined = undefined
  nebulaTextureLoading: boolean = false
  nebulaTexturePending: boolean = false
  nebulaTextureImporting: boolean = false
  nebulaTextureActionStatus: string = ''
}
