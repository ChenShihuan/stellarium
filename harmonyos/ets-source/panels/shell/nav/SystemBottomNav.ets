import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit'
import { ShellAction } from '../../../pages/StellariumTypes'
import { getIcon } from '../../../common/ui/ShellIcons'

// 皮肤 A：官方 HdsTabs 悬浮页签（系统沉浸材质）。
//
// 只提供页签栏：TabContent 留空，星图仍由宿主持有；点击经 onChange 回给宿主，
// 命中由宿主的 isDockPoint 判定（本组件 hitTestBehavior(None)，不吞星空手势）。
//
// 注意：页签宽度由 HDS 决定（≥4 项默认上限 328vp），与自绘 Dock 的 640vp 不同，
// 因此启用该皮肤前必须把实际栏宽回填给 BottomNavMetrics（T2）。

@Component
export struct SystemBottomNav {
  @Prop actions: ShellAction[]
  @Prop activePanel: string
  @Prop languageRevision: number
  onDockTap: (item: ShellAction) => void = () => {}

  private controller: HdsTabsController = new HdsTabsController()

  private activeIndex(): number {
    const index = this.actions.findIndex((item: ShellAction) => item.panel === this.activePanel)
    return index >= 0 ? index : 0
  }

  build() {
    HdsTabs({ barPosition: BarPosition.End, controller: this.controller, index: this.activeIndex() }) {
      ForEach(this.actions, (item: ShellAction) => {
        TabContent() {
        }
        .tabBar(new BottomTabBarStyle(getIcon(item.icon, false), item.label))
      }, (item: ShellAction) => item.panel + '/' + this.languageRevision.toString())
    }
      .width('100%')
      .height('100%')
      .vertical(false)
      .barOverlap(true)
      .scrollable(false)
      .barBackgroundStyle({ maskColor: '#00000000' })
      .barFloatingStyle({
        // 默认的渐变遮罩在深色星空上会显示成白带，这里关掉，只保留页签材质。
        gradientMask: { maskColor: '#00000000', maskHeight: 0 },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      })
      .onChange((index: number) => {
        if (index >= 0 && index < this.actions.length) {
          this.onDockTap(this.actions[index])
        }
      })
      .hitTestBehavior(HitTestMode.None)
  }
}
