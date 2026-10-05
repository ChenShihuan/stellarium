// 「目镜（Oculars）」面板的单个结果指标（原宿主参数化 `@Builder ocularMetric(label, value)`，7 行）。
//
// 为什么必须改成组件（§13.1 规则 3）：原 @Builder 用简单类型形参 label/value，参数按值捕获，
// 首帧后冻结 —— 换目镜/CCD 后放大率、视场、出瞳等结果数字不会刷新。
//
// 视觉逐字保留：标签 10 号 subColor、值 14 号 Medium textColor、纵向 2 间距、左对齐、layoutWeight(1)。
@Component
export struct OcularMetric {
  @Prop label: string
  @Prop value: string
  @Prop subColor: string
  @Prop textColor: string

  build() {
    Column({ space: 2 }) {
      Text(this.label).fontSize(10).fontColor(this.subColor).maxLines(1)
      Text(this.value).fontSize(14).fontColor(this.textColor).fontWeight(FontWeight.Medium).maxLines(1)
    }.alignItems(HorizontalAlign.Start).layoutWeight(1)
  }
}
