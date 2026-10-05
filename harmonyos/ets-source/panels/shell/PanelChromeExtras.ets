import { UI_RADIUS_PILL } from '../../common/ui/UiTokens'

// 面板/Dock 壳层的四个小组件（原宿主的 dockClockChip / dockClockLayer / padPanelHandle / panelHandle）。
//
// 都是无状态外观件：时钟文本、几何参数与拖拽回调由宿主以 @Prop / 回调解入（§13.1 规则 6）。
// 参数化 @Builder 的 `padExploreCard`（27 行）同批经零引用扫描确认死亡后删除，不在此列。
// 视觉与几何逐字保留。

// 主界面 Dock 右上常驻时钟（HH:mm）：点按直接打开时间面板。
@Component
export struct DockClockChip {
  @Prop clockText: string
  onOpenTime: () => void = () => {}

  build() {
    Row() {
      Text(this.clockText)
        .fontSize(22)
        .fontColor('rgba(229, 255, 255, 0.85)')
    }
      .height(36)
      .padding({ left: 14, right: 14 })
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('rgba(10, 14, 26, 0.55)')
      .backdropBlur(20)
      .borderRadius(UI_RADIUS_PILL)
      .clickEffect({ level: ClickEffectLevel.LIGHT })
      .onClick(() => { this.onOpenTime() })
  }
}

// Dock 时钟定位层：右端与 dock 栏对齐；空白区触摸穿透回星图，仅时钟本体拦截点击。
@Component
export struct DockClockLayer {
  @Prop clockText: string
  @Prop layerWidth: number
  @Prop posX: number
  @Prop posY: number
  onOpenTime: () => void = () => {}

  build() {
    Row() {
      Stack() { DockClockChip({ clockText: this.clockText, onOpenTime: this.onOpenTime }) }
        .hitTestBehavior(HitTestMode.Block)
    }
      .width(this.layerWidth)
      .height(44)
      .justifyContent(FlexAlign.End)
      .padding({ right: 4 })
      .position({ x: this.posX, y: this.posY })
      .hitTestBehavior(HitTestMode.Transparent)
      .zIndex(40)
  }
}

// 星图缩放按钮层：Dock 左端、与常驻时钟（DockClockLayer）左右对称，竖排 +放大 / −缩小。
// 非手势缩放：直接走原生 zoomStep（与键盘快捷键同一命令，factor<1 放大、>1 缩小），
// 空白区触摸穿透回星图，仅按钮本体拦截点击。视觉与 DockClockChip 同族。
@Component
export struct SkyZoomLayer {
  @Prop layerWidth: number
  @Prop posX: number
  @Prop posY: number
  @Prop textColor: string
  onZoomIn: () => void = () => {}
  onZoomOut: () => void = () => {}

  build() {
    Row() {
      Column({ space: 8 }) {
        Stack({ alignContent: Alignment.Center }) {
          Text('+')
            .fontSize(24)
            .fontColor(this.textColor.length > 0 ? this.textColor : 'rgba(229, 255, 255, 0.85)')
        }
          .width(44)
          .height(44)
          .backgroundColor('rgba(10, 14, 26, 0.55)')
          .backdropBlur(20)
          .borderRadius(22)
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .onClick(() => { this.onZoomIn() })
          .id('skyZoomInButton')
        Stack({ alignContent: Alignment.Center }) {
          Text('−')
            .fontSize(24)
            .fontColor(this.textColor.length > 0 ? this.textColor : 'rgba(229, 255, 255, 0.85)')
        }
          .width(44)
          .height(44)
          .backgroundColor('rgba(10, 14, 26, 0.55)')
          .backdropBlur(20)
          .borderRadius(22)
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .onClick(() => { this.onZoomOut() })
          .id('skyZoomOutButton')
      }
        .hitTestBehavior(HitTestMode.Block)
    }
      .width(this.layerWidth)
      .height(96)
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 4 })
      .position({ x: this.posX, y: this.posY })
      .hitTestBehavior(HitTestMode.Transparent)
      .zIndex(40)
  }
}

// 平板/折叠布局的面板抓手（纯装饰）。
@Component
export struct PadPanelHandle {
  build() {
    Row()
      .width(58)
      .height(5)
      .backgroundColor('rgba(255, 255, 255, 0.58)')
      .borderRadius(3)
      .alignSelf(ItemAlign.Center)
      .margin({ top: 2, bottom: 10 })
      .hitTestBehavior(HitTestMode.None)
  }
}

// 手机紧凑面板的抓手：垂直拖拽由宿主接管（更新/结算面板高度）。
@Component
export struct PanelHandle {
  onDrag: (offsetY: number) => void = () => {}
  onDragFinish: () => void = () => {}

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(58)
        .height(5)
        .backgroundColor('rgba(255, 255, 255, 0.30)')
        .borderRadius(3)
    }
      .width('100%')
      .height(28)
      .alignSelf(ItemAlign.Center)
      .margin({ bottom: 2 })
      .gesture(
        PanGesture()
          .onActionUpdate((event: GestureEvent) => {
            this.onDrag(event.offsetY)
          })
          .onActionEnd(() => {
            this.onDragFinish()
          })
      )
  }
}
