import { NightModeStore } from '../../state/NightModeStore'

// 夜视模式开关行（红光模式）。
//
// 状态经 NightModeStore 以 @ObjectLink 订阅，因此本行与"未来的主界面夜视按钮"读同一份状态；
// 变更经 onToggle 交回宿主统一处理（写入 store + 持久化 + 下发原生命令）。
@Component
export struct NightModeToggleRow {
  @ObjectLink store: NightModeStore
  @Prop textColor: string
  @Prop subColor: string
  onToggle: (enabled: boolean) => void = () => {}

  build() {
    Row() {
      Column({ space: 1 }) {
        Text('夜视模式').fontSize(12).fontColor(this.textColor).width('100%')
        Text('整个界面转成红光，夜里看不刺眼、也不影响眼睛适应黑暗').fontSize(9).fontColor(this.subColor).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.store.nightMode })
        .onChange((v: boolean) => {
          // 程序化改写 isOn（例如引擎轮询把状态同步回来）也会触发 onChange，
          // 这里只在"用户改变"（与当前状态不一致）时才回调，避免反向再发一条命令。
          if (v !== this.store.nightMode) { this.onToggle(v) }
        })
    }.width('100%').padding({ left: 10, right: 10, top: 4, bottom: 4 })
  }
}
