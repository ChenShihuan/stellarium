import { I18n } from '../pages/I18n'
// 传感器/陀螺仪状态（原宿主 @State 的 gyro*/gyroscope* 簇）。
// 这些字段本就由宿主 @State 承载并随传感器事件更新，迁入 @Observed 后宿主与组件的刷新语义不变（§13.1 规则 4）。
@Observed
export class GyroStore {
  gyroGuideVisible: boolean = false
  gyroGuideAngle: number = 0
  gyroGuideX: number = 0
  gyroGuideY: number = 0
  gyroscopeEnabled: boolean = false
  gyroscopeStatus: ResourceStr = I18n.t('m_gyro_off')
  gyroscopeSensitivityText: string = 'Standard'
  gyroCalibPanelOpen: boolean = false
  gyroCompassText: string = '罗盘 --'
  gyroCompassAngle: number = 0
  gyroOffsetAz: number = 0    // 方位角校准偏移（度）
  gyroOffsetAlt: number = 0   // 高度角校准偏移（度）
  gyroCompassAzAlignment: number = 0
}
