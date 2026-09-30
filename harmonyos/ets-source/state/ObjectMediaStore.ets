import { image } from '@kit.ImageKit'
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
}
