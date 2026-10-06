import { I18n } from '../pages/I18n'
// 传感器 / 陀螺仪域状态 store：持有导览姿态（gyroGuide*）、开关与状态（gyroscopeEnabled /
// gyroscopeStatus / gyroscopeSensitivityText）、罗盘读数（gyroCompass*）与校准面板 / 校准偏移。
// 消费方以 @ObjectLink 订阅；字段随传感器事件更新，宿主与组件的刷新语义不变。
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
