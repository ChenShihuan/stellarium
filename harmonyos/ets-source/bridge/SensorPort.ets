// 传感器能力端口（PLAN §15.1 Enabler，M1-A；M1-B 子组①按控制器需要细化）。
//
// 目的：让后续的 SensorController（M1-B）能订阅/退订 `sensor.*` 并接收上报，
// 而**不 import @ohos.* 设备能力模块本身**（§15.7 规则 1）。先例 bridge/CommandPort.ets。
//
// 本文件是**纯接口**：不 import `@ohos.*`。为保持与宿主现有回调（sensor.RotationVectorResponse /
// OrientationResponse / GravityResponse / MagneticFieldResponse）逐字兼容、便于 M1-B 整块搬迁，
// 这里引用 @kit.SensorServiceKit 的类型并再导出短别名（与 state/ObjectMediaStore.ets 引用
// @kit.ImageKit 的 image.PixelMap 同源做法；非 @ohos.* 直接导入）。控制器只从本文件导入类型，
// 不直接触碰 `sensor.on/off`。
//
// 宿主在 aboutToAppear 注入具名适配器（MainWindowNativeNode.ets 顶层 HostSensorPort）。
import { sensor } from '@kit.SensorServiceKit'

// 传感器可用性查询结果（对应 sensor.getSingleSensorSync 的返回信息）。
export interface SensorProbeInfo {
  sensorName: string
  vendorName: string
}

// 上报数据类型短别名：控制器经这些别名声明回调字段，无需 import 设备能力模块命名空间。
export type RotationVectorSample = sensor.RotationVectorResponse
export type OrientationSample = sensor.OrientationResponse
export type GravitySample = sensor.GravityResponse
export type MagneticFieldSample = sensor.MagneticFieldResponse

export interface SensorPort {
  // 查询某传感器是否可用（对应 sensor.getSingleSensorSync）；不可用返回 undefined。
  // label 同时用于适配器侧诊断日志与 SensorId 映射：
  // 'rotation-vector' / 'gravity' / 'magnetic-field' / 'orientation-fallback'。
  probeSensor(label: string): SensorProbeInfo | undefined
  // 旋转矢量（对应 sensor.on/off(ROTATION_VECTOR)）。
  subscribeRotationVector(callback: (data: RotationVectorSample) => void, intervalNs: number): void
  unsubscribeRotationVector(callback: (data: RotationVectorSample) => void): void
  // 方向（对应 sensor.on/off(ORIENTATION)）。
  subscribeOrientation(callback: (data: OrientationSample) => void, intervalNs: number): void
  unsubscribeOrientation(callback: (data: OrientationSample) => void): void
  // 重力（对应 sensor.on/off(GRAVITY)）。
  subscribeGravity(callback: (data: GravitySample) => void, intervalNs: number): void
  unsubscribeGravity(callback: (data: GravitySample) => void): void
  // 磁场（对应 sensor.on/off(MAGNETIC_FIELD)）。
  subscribeMagneticField(callback: (data: MagneticFieldSample) => void, intervalNs: number): void
  unsubscribeMagneticField(callback: (data: MagneticFieldSample) => void): void
}
