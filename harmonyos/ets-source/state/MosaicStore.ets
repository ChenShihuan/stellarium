import { MosaicCameraData } from '../pages/MainWindowModels'
import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import { I18n } from '../pages/I18n'
import { CommandPort } from '../bridge/CommandPort'

// 相机拼接视场（mosaicCamera）面板状态（review §2.7："Prop 风格 → Store 风格"）。
//
// 本域原为 10 个宿主 @State（mosaicCamera* 簇），以 10 个 @Prop 快照传入
// MosaicCameraPanel；改为 @Observed store + 面板 @ObjectLink 后，刷新粒度
// 收缩到订阅该 store 的面板。
//
// 字段沿用宿主原名（保留 mosaicCamera 前缀），与既有调用点机械对应。
// 加载器 loadMosaicCamera（§14 B1-4）已随桥注入搬入本 store；写回动作 setMosaicCamera 仍在宿主，
// 面板只读 + 回调注入。
//
// 普查确认：10 个字段全部是"字段整体赋值"（`= data.enabled`、`= data.names ?? []` …），
// 无数组原地 push/splice、无对象原地改属性，故可安全放进被观察 store。
@Observed
export class MosaicStore {
  mosaicCameraEnabled: boolean = false
  mosaicCameraNames: string[] = []
  mosaicCameraCurrent: string = ''
  mosaicCameraRA: number = 0
  mosaicCameraDec: number = 0
  mosaicCameraRotation: number = 0
  mosaicCameraVisible: boolean = false
  mosaicCameraLoading: boolean = false
  mosaicCameraPending: boolean = false
  mosaicCameraStatus: string = ''

  // —— 桥注入（§14.1 AB-0；§14 B1-4 起本 store 自持 loadMosaicCamera） ——
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

  // 相机拼接面板：桥查询拼接相机配置（原宿主 loadMosaicCamera，函数体逐字搬入；
  // 仅 this.callNativeWhenReady → this.port.requestWhenReady、this.mosaicStore.<f> → this.<f>；
  // 原重试档 0 / 100 / 15 与 onFailure 回调逐字保留，仅按端口签名把 onFailure 前移）。
  loadMosaicCamera(initial: boolean = true): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    this.mosaicCameraLoading = initial
    port.requestWhenReady('getMosaicCamera', '', (r: StellariumBridgeResponse) => {
      const data = r.mosaicCamera as MosaicCameraData | undefined
      if (r.ok !== true || data === undefined) {
        this.mosaicCameraStatus = I18n.t('plugin_status_unavailable')
      } else {
        this.mosaicCameraEnabled = data.enabled
        this.mosaicCameraNames = data.names ?? []
        this.mosaicCameraCurrent = data.currentCamera
        this.mosaicCameraRA = data.ra
        this.mosaicCameraDec = data.dec
        this.mosaicCameraRotation = data.rotation
        this.mosaicCameraVisible = Boolean(data.visible)
        this.mosaicCameraStatus = ''
      }
      this.mosaicCameraLoading = false
      this.mosaicCameraPending = false
      this.notifyChanged()
    }, () => {
      this.mosaicCameraLoading = false
      this.mosaicCameraPending = false
      this.mosaicCameraStatus = I18n.t('plugin_status_unavailable')
      this.notifyChanged()
    }, 0, 100, 15)
  }
}
