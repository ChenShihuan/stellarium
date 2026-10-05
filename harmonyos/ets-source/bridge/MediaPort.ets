// 媒体能力端口（PLAN §15.1 Enabler，M1-A）。
//
// 目的：让媒体服务（common/media/ImageDecoder.ets、common/platform/Screenshot.ets、
// common/platform/Share.ets）能处理 `fileIo` / `image` / `picker` / `media` /
// `photoAccessHelper`，而**不 import 这些设备能力模块本身**（§15.7 规则 1：控制器/服务
// 不 import NAPI/UI，只依赖端口接口；先例 bridge/CommandPort.ets 与宿主顶层 HostCommandPort）。
//
// 本文件是**纯接口**：不 import `@ohos.*`。仅引用图片像素图/source 类型（与
// state/ObjectMediaStore.ets 同源的 `image.PixelMap`，多一个 `image.ImageSource`）与应用类型
// ImageDecodeSize。宿主在 aboutToAppear 注入一个具名适配器（见 MainWindowNativeNode.ets 顶层的
// HostMediaPort），把下面各方法与宿主的 fileIo/image/picker 调用一一对应转发。
import { image } from '@kit.ImageKit'
import { ImageDecodeSize } from '../pages/MainWindowModels'

// 「另存为」结果：Saved = 用户已落盘；Cancelled = 用户取消选择；Failed = 写文件/弹选择器失败。
export enum MediaSaveResult {
  Saved = 0,
  Cancelled = 1,
  Failed = 2,
}

export interface MediaPort {
  // 文件是否存在（对应 fileIo.accessSync）。
  fileExists(path: string): boolean
  // 以只读方式打开文件并返回文件描述符 fd（对应 fileIo.openSync(path, READ_ONLY).fd）。
  openReadOnlyFile(path: string, label: string): number
  // 关闭文件描述符（对应 fileIo.closeSync(fd)，内部吞异常并记日志）。
  closeFile(fd: number, label: string): void
  // 由 fd 创建 image source（对应 image.createImageSource(fd)，内部记日志）。
  createImageSource(fd: number, label: string): image.ImageSource
  // 由 source 创建像素图（对应 source.createPixelMap()/createPixelMapUsingAllocator()）：
  // label === 'model' 时用 SHARE_MEMORY 分配器 + RGBA_8888/SDR（与宿主逐字一致）。
  createPixelMap(source: image.ImageSource, label: string, desiredSize?: ImageDecodeSize): Promise<image.PixelMap>
  // 释放 image source（对应 source.release()，内部吞异常并记日志）。
  releaseImageSource(source: image.ImageSource, label: string): void
  // 释放像素图（对应 pixelMap.release()，内部吞异常并记日志；undefined 时静默返回）。
  releasePixelMap(pixelMap: image.PixelMap | undefined, label: string): void
  // 另存为：弹出 DocumentViewPicker.save 并把 sourcePath 拷到用户选择的位置。
  // onDone(result) 区分落盘/取消/失败；由调用方决定提示与收尾（对应宿主 exportScreenshotToUserStorage
  // 的 picker + fileIo.copy 段）。
  saveFileAs(sourcePath: string, fileName: string, suffixLabel: string, onDone: (result: MediaSaveResult) => void): void
  // 删除文件（对应 fileIo.unlinkSync，用于截图导出后的临时文件清理）。
  deleteFile(path: string): void
}
