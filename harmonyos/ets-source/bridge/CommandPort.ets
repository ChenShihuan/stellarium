// 桥调用端口（§14.1 Enabler，轨道 B 硬前置，AB-0）。
//
// 目的：让域 store 能自持「桥调用 → 解析回包 → 写本域状态」的加载逻辑，而**不 import**
// NAPI / UI / libentry.so / @ohos.*（§13.1 规则 6：跨域 / 桥 / 定时器依赖用注入解决；
// 先例 state/TimeWheelController.ets 的 onSeek / onStopSpeed / getUtcOffsetHours）。
//
// 本文件是**纯接口**：只 import 回包类型 StellariumBridgeResponse，不含任何实现、
// 不触碰 libentry.so。宿主在 aboutToAppear 注入一个具名适配器（见 MainWindowNativeNode.ets
// 顶层的 HostCommandPort），把下面五个方法与宿主既有的桥方法一一对应转发：
//   request            ↔ callNative
//   requestWhenReady   ↔ callNativeWhenReady（启动期重试，默认 200ms × 60）
//   requestInteractive ↔ callInteractive（100ms × 15，交互命令）
//   requestLongRunning ↔ callLongRunningInteractive（长任务进度）
//   fire               ↔ callNativeFire
//
// 与计划 §14.1 示例的差异（以宿主真实签名为准）：示例只列了 request /
// requestInteractive / requestLongRunning / fire 四个方法；实际宿主加载器（如
// loadAboutInfo）走的是 callNativeWhenReady，故补出 requestWhenReady；requestLongRunning
// 的参数名对齐真实宿主（maxAttempts / isCancelled，而非示例的 intervalMs / cancelled）。
import { StellariumBridgeResponse } from '../pages/StellariumTypes'

export interface CommandPort {
  // 同步请求：宿主 callNative（含录制记录），桥未就绪时返回 { ok: false }。
  request(name: string, payload?: string): StellariumBridgeResponse
  // 启动期重试请求：对应宿主 callNativeWhenReady（默认 200ms × 60）。
  requestWhenReady(name: string, payload: string, onOk: (r: StellariumBridgeResponse) => void, onFailure?: (r: StellariumBridgeResponse) => void): void
  // 交互命令（tap-select / search / get-info / move-to）：快速轮询。
  requestInteractive(name: string, payload: string, onOk: (r: StellariumBridgeResponse) => void, onFailure?: (r: StellariumBridgeResponse) => void): void
  // 长任务：进度回调 + 最大尝试次数 + 取消判定。
  requestLongRunning(name: string, payload: string, onOk: (r: StellariumBridgeResponse) => void, onFailure?: (r: StellariumBridgeResponse) => void, onProgress?: (r: StellariumBridgeResponse) => void, maxAttempts?: number, isCancelled?: () => boolean): void
  // Fire-and-forget：不解析回包，减少拖动时的 GC 压力。
  fire(name: string, payload?: string): void
}
