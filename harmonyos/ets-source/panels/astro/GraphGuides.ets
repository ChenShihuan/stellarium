import { UI_RADIUS_PILL } from '../../common/ui/UiTokens'

// 星图/图表区域的三个小引导块。
//
// 都是纯展示 + 一个"打开目标选择器"回调：加载行收夜视两色，两个引导收夜视三色与回调。
// 错误文案/进度文案由 @Prop 驱动实时刷新。

// 计算中：转圈 + 进度文案。
@Component
export struct GraphLoadingRow {
  @Prop label: string
  @Prop accentColor: string
  @Prop subColor: string

  build() {
    Row({ space: 8 }) {
      LoadingProgress().width(22).height(22).color(this.accentColor)
      Text(this.label).fontSize(11).fontColor(this.subColor)
    }.width('100%').padding({ left: 8 }).margin({ top: 8, bottom: 6 })
  }
}

// 升中天落：未选天体时的引导。
@Component
export struct RtsSelectionGuide {
  @Prop textColor: string
  @Prop subColor: string
  @Prop panelColor: string
  onPick: () => void = () => {}

  build() {
    Column({ space: 5 }) {
      Text('先选择一个天体，才能按当前观测地点计算它的升起、中天和落下时间。')
        .fontSize(10).fontColor(this.subColor).width('100%').padding({ left: 8 })
      Button('选择天体').fontSize(10).fontColor(this.textColor).backgroundColor(this.panelColor)
        .borderRadius(UI_RADIUS_PILL).height(28).padding({ left: 10, right: 10 })
        .onClick(() => { this.onPick() })
    }.width('100%').padding({ left: 4 }).margin({ top: 5, bottom: 6 }).alignItems(HorizontalAlign.Start)
  }
}

// 各类观测曲线：未选天体 / 超时时的引导。
@Component
export struct GraphSelectionGuide {
  @Prop error: string
  @Prop textColor: string
  @Prop subColor: string
  @Prop panelColor: string
  onPick: () => void = () => {}

  build() {
    Column({ space: 5 }) {
      Text(this.error.indexOf('超时') >= 0 ? '若尚未选择天体，先选择一个；已选择时可点刷新重试。' : '先选择一个天体，才能按当前观测地点生成曲线。')
        .fontSize(10).fontColor(this.subColor).width('100%').padding({ left: 8 })
      Button('去选择天体').fontSize(10).fontColor(this.textColor).backgroundColor(this.panelColor)
        .borderRadius(UI_RADIUS_PILL).height(28).padding({ left: 10, right: 10 })
        .onClick(() => { this.onPick() })
    }.width('100%').padding({ left: 4 }).margin({ top: 5, bottom: 6 }).alignItems(HorizontalAlign.Start)
  }
}
