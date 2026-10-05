import { PluginItem, StellariumBridgeResponse } from '../pages/StellariumTypes'
import { I18n } from '../pages/I18n'
import { CommandPort } from '../bridge/CommandPort'

// 插件管理（设置 > 插件管理）列表状态（原宿主 @State，Phase 4m）。
//
// review §2.7：本域原为 "Prop 风格" —— pluginList / pluginListLoading 以 @Prop 快照传入
// SettingsPanel。现改为 @Observed store + 面板 @ObjectLink，列表/加载态变更只重绘插件页。
//
// 刻意留在宿主（非本 store 状态）：宿主私有动作 updatePluginLoadedItem /
// pluginZh / pluginDesc / pluginMetaLine / pluginFeatureRoute / pluginFeatureDestination /
// pluginFeatureIsActionable / pluginFeatureActionLabel 与 pluginFeatureLoading（瞬时动作串）。
// loadPluginList（§14 B1-5）已随桥注入搬入本 store。
//
// 约束：所有更新必须是"字段整体赋值"。改造前已普查确认 pluginList 只被整体赋值
// （`= list` 与 `= this.pluginList.map(...)`），改动前无 push/splice 等原地变更；
// 改造后 `updatePluginLoadedItem` 仍以 `= this.<store>.pluginList.map(...)` 整体赋值。
@Observed
export class PluginStore {
  pluginList: Array<PluginItem> = []
  pluginListLoading: boolean = false

  // —— 桥注入（§14.1 AB-0；§14 B1-5 起本 store 自持 loadPluginList） ——
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

  // 插件管理列表：桥查询插件清单（原宿主 loadPluginList，函数体逐字搬入；
  // 仅 this.callInteractive → this.port.requestInteractive、this.pluginStore.<f> → this.<f>）。
  loadPluginList(): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    this.pluginListLoading = true
    port.requestInteractive('getPluginList', '', (r: StellariumBridgeResponse) => {
      this.pluginListLoading = false
      if (r.ok === true && r.items !== undefined && Array.isArray(r.items)) {
        const arr = r.items as Array<Record<string, Object>>;
        const list: Array<PluginItem> = [];
        for (let i = 0; i < arr.length; i++) {
          const obj = arr[i];
          const id = obj['id'] !== undefined ? obj['id'] as string : '';
          const name = obj['name'] !== undefined ? obj['name'] as string : id;
          const loaded = obj['loaded'] !== undefined ? obj['loaded'] as boolean : false;
          const startup = true
          list.push({
            id: id,
            name: name,
            loaded: loaded,
            loadAtStartup: startup,
            description: obj['description'] as string | undefined,
            authors: obj['authors'] as string | undefined,
            contact: obj['contact'] as string | undefined,
            version: obj['version'] as string | undefined,
            license: obj['license'] as string | undefined,
            acknowledgements: obj['acknowledgements'] as string | undefined,
            hasPreviewImage: obj['hasPreviewImage'] as boolean | undefined,
            source: obj['source'] as string | undefined
          });
        }
        this.pluginList = list;
      }
      this.notifyChanged()
    }, () => {
      this.pluginListLoading = false
      this.notifyChanged()
    })
  }
}
