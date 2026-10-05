// 位置能力端口（PLAN §15.12 位置域行为下沉）。
//
// 目的：让位置域控制器（capability/LocationController.ets）能申请定位权限、取当前位置、读写
// 持久化观测点，而**不 import 定位/权限/preferences 设备能力模块本身**（§15.7 规则 1：控制器/
// 服务不 import NAPI/UI，只依赖端口接口；先例 bridge/CommandPort.ets、bridge/MediaPort.ets）。
//
// 本文件是**纯接口**：不 import `@ohos.*`。宿主在 MainWindowNativeNode.ets 顶层用具名 class
// HostLocationPort 实现（aboutToAppear 注入 UI 上下文工厂），逐字转发宿主原 NAPI 调用。

// 一次定位结果（对应 geoLocationManager.getCurrentLocation 的 latitude/longitude/altitude；
// altitude 非有限值时由适配器映射为 0，与宿主原 `Number.isFinite(current.altitude) ? ... : 0` 一致）。
export interface LocationFix {
  latitude: number
  longitude: number
  altitude: number
}

export interface LocationPort {
  // 申请定位权限（宿主用 abilityAccessCtrl.requestPermissionsFromUser +
  // ohos.permission.APPROXIMATELY_LOCATION / ohos.permission.LOCATION）。
  // 返回 true 表示用户已授予任一权限（等价宿主原 authResults.some(result => result === 0)）。
  requestLocationPermissions(): Promise<boolean>
  // 取当前位置（宿主用 geoLocationManager.getCurrentLocation：priority=ACCURACY、
  // scenario=DAILY_LIFE_SERVICE、maxAccuracy=2000、timeoutMs=5000）。
  getCurrentLocation(): Promise<LocationFix>
  // 读持久化观测点 JSON（宿主用 @ohos.data.preferences，store 名 LOCATION_STORE，key 'location'；失败返回 ''）。
  readObserverLocation(): Promise<string>
  // 写持久化观测点 JSON（同上；失败只记一条 warn，不抛）。
  writeObserverLocation(json: string): Promise<void>
}
