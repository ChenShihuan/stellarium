// 平台能力端口（PLAN §15.1 Enabler，M1-A）。
//
// 目的：让平台服务（common/platform/Clipboard.ets、common/platform/Share.ets、
// common/SpeechService.ets）能使用 `systemShare` / pasteboard / TTS，而**不 import
// 这些设备能力模块本身**（§15.7 规则 1）。先例 bridge/CommandPort.ets 与宿主顶层 HostCommandPort。
//
// 本文件是**纯接口**：不 import `@ohos.*`。宿主在 aboutToAppear 注入具名适配器
// （MainWindowNativeNode.ets 顶层 HostPlatformPort）。
export interface PlatformPort {
  // 写系统剪贴板（对应 qability/ClipboardService.writeClipboardText，底层 @ohos.pasteboard）。
  // 返回是否写入成功。
  writeClipboardText(text: string): Promise<boolean>
  // 打开系统分享面板（对应 @kit.ShareKit systemShare）。onDone(ok) 表示分享面板是否成功弹出，
  // false = 打开失败，由调用方提示。anchorId 仅在有扩展布局时作为锚点生效（expanded 为真时）。
  shareFile(
    path: string,
    utd: string,
    title: string,
    description: string,
    anchorId: string,
    expanded: boolean,
    onDone: (ok: boolean) => void
  ): void
  // 语音合成（TTS）。当前基础 SDK（API 24）不含 @kit.CoreSpeechKit，宿主实现为「仅生成可读文本」，
  // 留待切换到含语音合成的 SDK 后接真实播报。
  speak(text: string): void
}
