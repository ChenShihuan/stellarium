import hilog from '@ohos.hilog'
import { BookmarkItem, BookmarkRaw, BookmarksResponse } from '../pages/MainWindowModels'
import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import { I18n } from '../pages/I18n'
import { CommandPort } from '../bridge/CommandPort'

// 宿主 → BookmarkStore 的 Preferences 读写注入（§13.1 规则 6 / §14.8 规则 2：store 不得
// import NAPI/UI 上下文，故 preferences + getUIContext 职责整体经 hooks 提供；先例
// ObjectMediaHostHooks.readRawSidecar）。
export interface BookmarkHostHooks {
  // 读 Preferences 'bookmarks' 原始 JSON（无则 '[]'）；宿主用 @ohos.data.preferences 实现。
  readBookmarksStorage(): Promise<string>
  // 持久化当前列表到 Preferences；宿主实现（原宿主 saveBookmarksToStorage）。
  saveBookmarksToStorage(): void
}

// 书签域状态：面板（BookmarkPanel）@ObjectLink 订阅，持久化与命令逻辑留在宿主。
// §14 B2R-4：loadBookmarks / loadBookmarksFromStorage 由本 store 自持（宿主不再持有同名方法）。
@Observed
export class BookmarkStore {
  list: BookmarkItem[] = []
  loading: boolean = false
  draftName: string = ''

  // —— 桥注入（§14.1 AB-0） ——
  private port: CommandPort | null = null
  // 本加载器不使用请求序号（无并发抑制需求）；预留以满足 §14.8 规则 3 的统一约定。
  private seq: number = 0
  private hooks: BookmarkHostHooks | null = null

  attachPort(port: CommandPort): void {
    this.port = port
  }

  attachHooks(hooks: BookmarkHostHooks): void {
    this.hooks = hooks
  }

  // 桥拉取书签列表（原宿主 loadBookmarks，函数体逐字搬入）。
  // 差异仅：this.callNativeWhenReady → port.requestWhenReady、this.bookmarkStore.<f> → this.<f>、
  // this.saveBookmarksToStorage() → hooks.saveBookmarksToStorage()。
  loadBookmarks(): void {
    const hooks = this.hooks
    const port = this.port
    if (hooks === null || port === null) {
      return
    }
    this.loading = true
    port.requestWhenReady('getBookmarks', '', (r: StellariumBridgeResponse) => {
      const resp = r as BookmarksResponse
      const list = resp.items ?? []
      this.list = list.map((b: BookmarkRaw): BookmarkItem => ({
        id: b.id ?? '',
        name: b.name ?? I18n.t('bookmark_fallback'),
        fov: b.fov ?? 60,
        object: b.object ?? '',
      }))
      this.loading = false
      hooks.saveBookmarksToStorage()
    })
  }

  // 首次启动从 Preferences 载入书签（原宿主 loadBookmarksFromStorage，函数体逐字搬入）。
  // 差异仅：getUIContext + preferences → hooks.readBookmarksStorage（store 不 import NAPI/UI）。
  async loadBookmarksFromStorage(): Promise<void> {
    const hooks = this.hooks
    try {
      const jsonStr: string = hooks !== null ? await hooks.readBookmarksStorage() : '[]'
      const parsed: BookmarkItem[] = JSON.parse(jsonStr)
      if (parsed.length > 0) {
        this.list = parsed
      }
    } catch (e) {
      hilog.warn(0xD002, 'Stellarium', 'load bookmarks failed: %{public}s', String(e))
    }
  }
}
