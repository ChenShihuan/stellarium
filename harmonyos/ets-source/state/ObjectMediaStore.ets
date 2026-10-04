import { image } from '@kit.ImageKit'
import hilog from '@ohos.hilog'
import { describeDecodeError } from '../common/derive/labels'
import { I18n } from '../pages/I18n'
import { modelIdentity, modelDrag } from '../pages/DetailModelGeometry'

// 宿主 → ObjectMediaStore 的媒体管线助手（§13.1 规则 6 / §14.8 规则 2：跨域 / NAPI 依赖用注入解决）。
// B2R-1 的 loadObjectInspectorModelRawTexture 读写宿主刻意保留的逐帧裸字段
//（objectInspectorModelTexturePixels / RingTexture*）并复用 fileIo / image / decodeLocalImage，
// 这些职责不下沉 store，经本具名接口注入；store 只保留「侧车优先、PNG 回退」的分支策略与尺寸校验。
export interface ObjectMediaHostHooks {
  // 读原始 RGBA 侧车（宿主用 fileIo 实现；尺寸不符或 IO 失败抛 Error）。label 用于错误文案。
  readRawSidecar(path: string, expectedBytes: number, label: string): ArrayBuffer
  // PNG 回退解码（宿主用 image + decodeLocalImage 实现）。
  decodeObjectInspectorModelTextureFromPng(pngFilePath: string, ringPngFilePath: string, mediaGeneration: number, expectedSelection: string, expectedPath: string): void
  // 提交 CPU 纹理：写宿主逐帧裸字段并触发 CPU 光栅化渲染。
  commitObjectInspectorModelTexture(texture: ArrayBuffer, ringTexture: ArrayBuffer | undefined, mediaGeneration: number, expectedSelection: string, expectedPath: string, sourceLabel: string): void
  // 失败上报：写本 store 失败态并 hilog。
  failObjectInspectorModelTexture(mediaGeneration: number, reason: string): void
}

// 天体检查器的媒体与三维模型状态（原宿主 @State 的 objectInspectorMedia*/Model* 簇）。
// 解码/预热/失败/全屏与模型沉浸等状态由对象详情卡片与平板检查器共用。
@Observed
export class ObjectMediaStore {
  objectInspectorMoreOpen: boolean = false
  objectInspectorMediaPath: string = ''
  objectInspectorMediaKind: string = 'none'
  objectInspectorMediaLabel: string = ''
  objectInspectorMediaLoading: boolean = false
  objectInspectorMediaDecoding: boolean = false
  objectInspectorMediaPixelMap: image.PixelMap | undefined = undefined
  objectInspectorMediaLoadFailed: boolean = false
  objectInspectorMediaPreparationFailed: boolean = false
  objectInspectorMediaNoMatch: boolean = false
  objectInspectorMediaWarmupState: string = 'unknown'
  objectInspectorMediaWarmupInstalled: number = 0
  objectInspectorMediaWarmupTotal: number = 0
  objectInspectorMediaWarmupFailed: number = 0
  objectInspectorMediaFullscreen: boolean = false
  objectInspectorMediaViewportHeight: number = 0
  objectInspectorMediaPreviewPath: string = ''
  objectInspectorMediaPreviewLoading: boolean = false
  objectInspectorMediaPreviewFailed: boolean = false
  objectInspectorModelPixelMap: image.PixelMap | undefined = undefined
  objectInspectorProceduralKind: string = ''
  objectInspectorModelImmersive: boolean = false
  objectInspectorModelOverlayOpacity: number = 0
  objectInspectorModelScale: number = 1
  objectInspectorModelInteracting: boolean = false

  // —— 宿主助手注入（§14 B2R-1）——
  private hooks: ObjectMediaHostHooks | null = null

  attachHooks(hooks: ObjectMediaHostHooks): void {
    this.hooks = hooks
  }

  // 原始模型纹理加载器（原宿主 loadObjectInspectorModelRawTexture，函数体逐字搬入）。
  // 差异仅：内联 fileIo 读取 → hooks.readRawSidecar（store 不 import NAPI），
  // this.decode/commit/failObjectInspectorModelTexture → hooks.*；日志/尺寸常量/分支策略不变。
  loadObjectInspectorModelRawTexture(
    rawFilePath: string,
    ringRawFilePath: string,
    mediaGeneration: number,
    expectedSelection: string,
    expectedPath: string,
    pngFilePath: string,
    ringPngFilePath: string,
  ): void {
    const hooks = this.hooks
    if (hooks === null) {
      return
    }
    const expectedBytes = 512 * 256 * 4
    if (rawFilePath.length === 0) {
      hilog.warn(0x0000, 'StellariumArkUI',
        '[detail-model] sidecar missing, decoding PNG fallback uri=%{public}s png=%{public}s',
        expectedPath, pngFilePath)
      hooks.decodeObjectInspectorModelTextureFromPng(pngFilePath, ringPngFilePath, mediaGeneration, expectedSelection, expectedPath)
      return
    }
    try {
      const pixels = hooks.readRawSidecar(rawFilePath, expectedBytes, 'CPU texture sidecar')
      let ringTexture: ArrayBuffer | undefined = undefined
      if (ringRawFilePath.length > 0) {
        try {
          const ringPixels = hooks.readRawSidecar(ringRawFilePath, 512 * 2 * 4, 'ring sidecar')
          ringTexture = ringPixels
          hilog.info(0x0000, 'StellariumArkUI',
            '[detail-model] ring texture ready path=%{public}s bytes=%{public}s',
            ringRawFilePath, ringPixels.byteLength.toString())
        } catch (ringErr) {
          hilog.warn(0x0000, 'StellariumArkUI',
            '[detail-model] ring texture unavailable path=%{public}s error=%{public}s',
            ringRawFilePath, describeDecodeError(ringErr as Error))
        }
      }
      hooks.commitObjectInspectorModelTexture(pixels, ringTexture, mediaGeneration, expectedSelection, expectedPath, 'sidecar')
    } catch (err) {
      hilog.warn(0x0000, 'StellariumArkUI',
        '[detail-model] sidecar load failed path=%{public}s error=%{public}s',
        rawFilePath, describeDecodeError(err as Error))
      if (pngFilePath.length > 0) {
        hooks.decodeObjectInspectorModelTextureFromPng(pngFilePath, ringPngFilePath, mediaGeneration, expectedSelection, expectedPath)
        return
      }
      hooks.failObjectInspectorModelTexture(mediaGeneration, 'sidecar failed: ' + describeDecodeError(err as Error))
    }
  }

  // 离线图库预热进度文案（原宿主 objectInspectorMediaWarmupText，函数体逐字搬入）。
  // 差异仅：this.objectMediaStore.objectInspectorMediaWarmup* → this.objectInspectorMediaWarmup*。
  objectInspectorMediaWarmupText(): string {
    if (this.objectInspectorMediaWarmupTotal <= 0) {
      return '正在检查离线图库'
    }
    let text = '离线图库已准备 ' + this.objectInspectorMediaWarmupInstalled.toString() + '/' +
      this.objectInspectorMediaWarmupTotal.toString()
    if (this.objectInspectorMediaWarmupFailed > 0) {
      text += ' · ' + this.objectInspectorMediaWarmupFailed.toString() + ' 项失败'
    }
    return text
  }

  // ==== 详情媒体/模型的「取值/文案」助手（§14 A2-3，原宿主私有方法逐字搬入）====
  //
  // 均读本 store 的 objectInspectorProceduralKind / objectInspectorMediaViewportHeight，
  // 按 §14.3「读本域 store 字段 → 并入该 store 方法（零入参）」下沉；函数体逐字保留
  //（defaultObjectInspectorModelRotation 直接 import 纯几何模块 DetailModelGeometry）。

  // 模型基座/光照提示文案（原宿主 objectInspectorModelNotice）。
  objectInspectorModelNotice(): string {
    return this.objectInspectorProceduralKind.length > 0
      ? I18n.t('model_basis_' + this.objectInspectorProceduralKind)
      : I18n.t('model_lighting_note')
  }

  // 模型默认视角（原宿主 defaultObjectInspectorModelRotation）。
  defaultObjectInspectorModelRotation(): number[] {
    return this.objectInspectorProceduralKind === 'quasar' ? modelDrag(modelIdentity(), 0, -100) : modelIdentity()
  }

  // 详情卡内嵌图片高度（原宿主 objectInspectorImageHeight）。
  objectInspectorImageHeight(): number {
    return this.objectInspectorMediaViewportHeight > 0
      ? Math.max(72, Math.min(210, this.objectInspectorMediaViewportHeight - 88)) : 210
  }
}
