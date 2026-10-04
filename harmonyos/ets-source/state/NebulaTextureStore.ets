import { NebulaTextureStatus } from '../pages/MainWindowModels'
import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import { I18n } from '../pages/I18n'
import { CommandPort } from '../bridge/CommandPort'

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
// setNebulaTextureVisible / setNebulaTextureFlag / refreshNebulaTextures /
// gotoNebulaTexture / removeNebulaTexture / importNebulaTextureFile 与文件选择器；
// 这些动作继续写本 store（宿主持有 @State 实例，读 store 会重绘宿主，符合 §13.1 规则 4）。
// loadNebulaTextureStatus（§14 B1-5）已随桥注入搬入本 store。
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

  // —— 桥注入（§14.1 AB-0；§14 B1-5 起本 store 自持 loadNebulaTextureStatus） ——
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

  // 星云贴图面板：桥查询贴图加载状态（原宿主 loadNebulaTextureStatus，函数体逐字搬入；
  // 仅 this.callInteractive → this.port.requestInteractive、this.nebulaTextureStore.<f> → this.<f>）。
  loadNebulaTextureStatus(): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    if (this.nebulaTextureLoading) return
    this.nebulaTextureLoading = true
    port.requestInteractive('getNebulaTextureStatus', '', (r: StellariumBridgeResponse) => {
      this.nebulaTextureLoading = false
      if (r.ok !== true) {
        this.nebulaTextureActionStatus = r.error ?? I18n.t('nebula_texture_status_failed')
        this.notifyChanged()
        return
      }
      this.nebulaTextureStatus = r as NebulaTextureStatus
      this.notifyChanged()
    }, () => {
      this.nebulaTextureLoading = false
      this.nebulaTextureActionStatus = I18n.t('nebula_texture_status_failed')
      this.notifyChanged()
    })
  }
}
