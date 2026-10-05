import { MeteorShowerItem, MeteorShowersResponse } from '../pages/MainWindowModels'
import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import { CommandPort } from '../bridge/CommandPort'

// 流星雨（meteor showers）域的面板状态（原宿主 8 个 @State）。
//
// review §2.7 第三批（小簇批处理）之一。本簇面板入参与宿主字段**同名**，因此机械替换即可。
// 已确认本域数组（msShowerList）无原地变更 ⇒ @ObjectLink 语义等价。
//
// §14 B3-1：加载器 loadMeteorShowers 与其配对写方 setMeteorShowersFlag 同片搬入本 store，
// 请求序号 meteorShowersLoadRequestId 随之入 store 的 `seq`（**单一持有者**，宿主零副本、
// 零双写，§14.8 规则 3）。setMeteorShowersFlag 自增 seq 以作废在途载入，语义逐字保留。
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

  // —— 桥注入（§14.1 AB-0 / §14 B3-1） ——
  private port: CommandPort | null = null
  // 原宿主请求序号 meteorShowersLoadRequestId 搬入 store（§14.8 规则 3）。
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

  // 流星雨面板：桥查询当前设置与本月活跃流星雨（原宿主 loadMeteorShowers，§14 B3-1 搬入；函数体逐字）。
  // 差异仅：this.callNativeWhenReady → port.requestWhenReady、this.meteorStore.<f> → this.<f>、
  // this.meteorShowersLoadRequestId → this.seq（与 setMeteorShowersFlag 共用同一序号）。
  loadMeteorShowers(): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    const requestId = ++this.seq
    port.requestWhenReady('getMeteorShowers', '', (r: StellariumBridgeResponse) => {
      if (requestId !== this.seq) return
      const resp = r as MeteorShowersResponse
      const m = resp.meteorShowers
      if (!m) { return }
      this.msEnabled = m.enabled
      this.msLabels = m.labels
      this.msActiveOnly = m.activeOnly
      this.msMarker = m.marker
      this.msCatalogVersion = m.catalogVersion ?? ''
      this.msCatalogName = m.catalogName ?? ''
      this.msCatalogSource = m.catalogSource ?? ''
      // Parse active shower list
      if (resp.showerList && resp.showerList.length > 0) {
        this.msShowerList = resp.showerList.map((s): MeteorShowerItem => ({
          name: s.name ?? '',
          englishName: s.englishName ?? '',
          zhr: s.zhr ?? 0,
          status: s.status ?? '',
          speed: s.speed ?? 0,
          popIdx: s.popIdx ?? 0,
          parent: s.parent ?? '',
          peakDate: s.peakDate ?? '',
          activeStart: s.activeStart ?? '',
          activeEnd: s.activeEnd ?? ''
        }))
      } else {
        this.msShowerList = []
      }
    })
  }

  // 写流星雨开关（原宿主 setMeteorShowersFlag，§14 B3-1 与加载器同片搬入；函数体逐字）。
  // 差异仅：this.meteorShowersLoadRequestId → this.seq、this.meteorStore.<f> → this.<f>、
  // this.callNativeWhenReady → port.requestWhenReady（重试档 0/100/15 逐字保留）、
  // this.loadMeteorShowers → 同 store 方法。
  setMeteorShowersFlag(name: string, v: boolean): void {
    const port = this.ensurePort()
    if (port === null) {
      return
    }
    this.seq++
    if (name == 'enabled') { this.msEnabled = v }
    else if (name == 'labels') { this.msLabels = v }
    else if (name == 'activeOnly') { this.msActiveOnly = v }
    else if (name == 'marker') { this.msMarker = v }
    port.requestWhenReady('setMeteorShowersFlag', name + ':' + (v ? '1' : '0'), (r: StellariumBridgeResponse) => {
      if (r.ok !== true) this.loadMeteorShowers()
    }, () => { this.loadMeteorShowers() }, 0, 100, 15)
  }
}
