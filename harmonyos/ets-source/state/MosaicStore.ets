// 相机拼接视场（mosaicCamera）面板状态（review §2.7："Prop 风格 → Store 风格"）。
//
// 本域原为 10 个宿主 @State（mosaicCamera* 簇），以 10 个 @Prop 快照传入
// MosaicCameraPanel；改为 @Observed store + 面板 @ObjectLink 后，刷新粒度
// 收缩到订阅该 store 的面板。
//
// 字段沿用宿主原名（保留 mosaicCamera 前缀），与既有调用点机械对应。
// 写方仍是宿主（loadMosaicCamera / setMosaicCamera 桥回调），面板只读 + 回调注入。
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
}
