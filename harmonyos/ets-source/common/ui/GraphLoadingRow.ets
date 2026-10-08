// 计算中：转圈 + 进度文案。
//
// 原在 `panels/astro/GraphGuides.ets`，因被 skyculture 域（`SkyCultureViewTab`）共用，
// 2026-10-08 按 STATE-REVIEW §9 P2 抽到 `common/ui/`（通用加载行，无天文域硬编码）。
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
