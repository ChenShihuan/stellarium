import { BookmarkItem } from '../pages/MainWindowModels'

// 书签域状态：面板（BookmarkPanel）@ObjectLink 订阅，持久化与命令逻辑留在宿主。
@Observed
export class BookmarkStore {
  list: BookmarkItem[] = []
  loading: boolean = false
  draftName: string = ''
}
