# Dock 沉浸光感（HdsTabs / TabBar 方案）可行性与改造设计

> 状态：待 review（未实现）
> 结论先行：技术上能在不提升 minSdk 的前提下拿到系统沉浸材质（HdsTabs 悬浮页签，6.1.0(23) 起），
> 但需要接受系统页签的排版/配色，并先验证两件事：星图 XComponent 不受 Tabs 影响、Tabs 内容区不吞星空手势。
> 建议只做 S0 spike（约 1 人日）再决定是否进入正式改造。

## 0. 给 review 的三句话

1. **能拿到真材质**：`HdsTabs` + `barPosition(End)` + `barOverlap(true)` + `barFloatingStyle({ systemMaterialEffect })` 从 6.1.0(23) 提供系统沉浸材质，正好等于本仓库的 `compatibleSdkVersion`。
2. **代价不是"加个组件"**：Tabs 的语义是"页签切换 TabContent"，而我们是"星图常驻 + 面板浮层"，需要 bar-only 的取巧结构；同时会失去现有自绘 Dock 的图标/标签/夜间红色调可控性。
3. **风险集中在两处**：把 Tabs 叠到星图上会不会吞掉星空手势（高），以及任何 reparent 是否会让 XComponent 重建 surface（高）。两点都必须先用 spike 证实，不能靠推断。

## 1. 背景

当前 Dock 是自绘 `Stack`（`panels/shell/BottomDock.ets`）：

| 现状 | 代码 | 结果 |
|---|---|---|
| 材质近似 | `BackgroundEffectOptions`（radius / saturation / brightness / color，`BottomDock.ets:108`） | 有毛玻璃观感，**没有**系统折射、边缘流光、按压弹性光效 |
| 触点高光 | `radialGradient` + `updateGlow`（`BottomDock.ets:59,97`） | 近似"手电筒"高亮，不是系统 lightEffect |
| 形状 | `UI_RADIUS_PILL` 全胶囊 + 12/8 内边距 | 与系统悬浮页签形态接近，但圆角/间距由我们自己维护 |
| 系统日志 | `Material inactive: out of scope. Use component in navigation title bar or Tabbar.` | 证明沉浸光感对普通自绘组件不生效 |

用户此前的诉求是"让 Dock 拿到系统级的沉浸光感"，讨论过的路线就是**把 Dock 迁移到 Tabs / HdsTabs**。本文把该讨论整理成可评审的方案。

## 2. 现状约束（代码事实）

### 2.1 结构

```
MainWindowNativeNode.build()               // ets-source/pages/MainWindowNativeNode.ets:7245
└─ WithTheme(stellariumTheme(nightMode))   // 夜间主题唯一入口
   └─ Stack                                // 根：星图 + 面板 + chrome + 命中层
      ├─ XComponent (Qt/GL 星图)           // 由宿主持有，位置/生命周期不能随便变
      ├─ HarmonyShell → CompactShell / ExpandedShell / HoverObservatoryShell
      │   └─ BottomDock (纯视觉)           // 见 2.2
      ├─ 顶部命中层 Stack (zIndex 80)      // 宿主自己分发 Dock 点击，7747 附近
      ├─ 面板浮层（底部对齐，锚 dockTop）
      └─ 读数行 / 缩放按钮（CHROME_* 常量）
```

### 2.2 Dock 的实际几何

| 布局 | 视觉位置 | 视觉高度 | 宿主基线 |
|---|---|---|---|
| 展开/平板 | `ExpandedShell.ets:170`，`y = skyHeight - 62` | `54`（内容 48） | `dockTop() = skyHeight - 62`，`dockHeight() = 54` |
| 折叠悬停 | `HoverObservatoryShell.ets:191`，`y = skyHeight - 62` | `54` | 同上 |
| 手机紧凑 | `CompactShell.ets:176`，`y = skyHeight - 80` | `66` | `dockTop() = skyHeight - dockHeight - 清晰度间距` |

> 上一次修复已经把 `dockTop()/dockHeight()` 与 ExpandedShell 的真实绘制对齐（提交 `5d99ca6e87`）。任何 TabBar 方案都必须继续保证"视觉位置 = 命中位置 = 面板锚点"三者同源。

### 2.3 依赖 Dock 几何的地方

| 依赖 | 位置 | 数量 |
|---|---|---|
| `dockLeft / dockWidthPixels / isDockPoint` | `common/derive/geometry.ets`，宿主 + `capability/SkyInputController.ets` | 宿主 27 处、输入 2 处 |
| `dockTop()` | 宿主（面板锚定、命中层、chrome 行、obstacle 矩形） | 26 处 |
| 读数行 / 缩放层 | `common/ui/ChromeGeometry.ets`（`CHROME_CHIP_HEIGHT=36`、`CHROME_GAP=10`、`CHROME_ROW_OFFSET=46`、`chromeZoomLayerTop`）；读数行 X 还依赖 Dock 两端（`chromeRowPosXLeft/Right`、`expandedDockLeft/Width`） | 宿主 + PanelChromeExtras |
| 面板底部锚定 | `expandedPanelTop() / expandedPanelUsableHeight()` | 宿主 |
| 主题 | `ThemeSlots`（`BottomDock` 通过 `onWillApplyTheme` 取 `c.dockActive` 等） | `BottomDock` / `DockButton` |

### 2.4 材质与主题的矛盾点

夜间模式当前是"红黑"配色，全部来自 `ThemeSlots`。系统材质由 HDS 组件渲染，颜色跟随系统深浅色与材质等级；`HdsTabsFloatingStyle` 只暴露 `lightColor`（高光色）、`thermoCtrl`、透明度等微调，**不能**把整块材质改成自定义红色调。这是本方案最大的产品取舍。

## 3. 可选的四种方案

| 维度 | A. bar-only HdsTabs（推荐 spike） | B. Tabs 作为根容器 | C. 维持自绘（现状） | D. uiMaterial（API 26） |
|---|---|---|---|---|
| 系统材质 | 有（系统页签自带） | 有 | 无（仅 backgroundEffect 近似） | 有 |
| 结构改动 | 中：底部新增 HdsTabs，星图不动 | 大：星图进 TabContent，面板变成页签内容 | 无 | 小～中 |
| XComponent 风险 | 低（不 reparent） | **高**（重建 surface/GL 上下文） | 无 | 低 |
| 手势风险 | 中（Tabs 内容区可能盖住星图） | 中（Tabs 滑动切页竞争） | 无 | 低 |
| 视觉可控 | 低（系统页签样式） | 低 | 高 | 高 |
| 夜间红色调 | 不可控 | 不可控 | 完全可控 | 可控（自定义材质色） |
| 最小 API | 23（`compatibleSdkVersion` 已满足） | 23 | — | 26（需 canIUse 降级） |
| 预估工作量 | 3–4 人日 | 5–7 人日 | 0 | 2–3 人日（但要提升 minSdk 或长期双轨） |

### 3.1 为什么 B 不推荐

- 星图必须进入某个 `TabContent`；面板也是页签内容，于是"关闭面板"没有对应的页签状态。
- 切换页签会卸载/重建 `TabContent`，`XComponent` 的 surface 与 Qt GL 上下文是否保活没有保证，一旦重建就是黑屏 + 纹理重载。
- 现有返回栈、`panelRouteDirection`、面板动画全部围绕"浮层"设计，改成页签等于重写交互模型。

### 3.2 D 为什么暂不选

`@ohos.arkui.uiMaterial`（`ImmersiveMaterial` / `systemMaterial`）属于 API 26。本仓库 `compatibleSdkVersion = 6.1.0(23)`、`compileSdkVersion/targetSdkVersion = 26.0.0`，在 23/24/25 设备上只能 `canIUse` 降级为无材质——那等于"新设备有、老设备退回自绘"，视觉双轨。除非明确只支持 26+，否则不如直接用 23 起可用的 HDS。

## 4. 关键技术事实（本机 SDK 已核对）

来源：`@kit.UIDesignKit`（HMS SDK `sdk/default/hms/ets`）、`@hms.hds.hdsBaseComponent.d.ets`、`@hms.hds.hdsMaterial.d.ets`，以及本地文档 `API参考/UI_Design_Kit_UI设计套件/ArkTS组件/HdsTabs_底部页签/ui-design-hdstabs`。

| 事实 | 值/约束 |
|---|---|
| 组件 | `HdsTabs`，子组件只能是 `TabContent`，`@since 6.0.0(20)` |
| 悬浮样式 | `HdsTabsFloatingStyle`，`@since 6.1.0(23)` |
| 启用条件 | `barPosition(BarPosition.End)` + `vertical(false)` + `barOverlap(true)` + `barFloatingStyle({...})` |
| 材质参数 | `systemMaterialEffect: { materialType: hdsMaterial.MaterialType.IMMERSIVE, materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE }` |
| 材质枚举 | `MaterialType`: `NONE(0)` / `ADAPTIVE(100)` / `IMMERSIVE(101)`；`MaterialLevel`: `EXQUISITE(0)` / `GENTLE(1)` / `SMOOTH(2)` / `ADAPTIVE(10)` |
| 能力查询 | `hdsMaterial.getSystemMaterialTypes()`；PC/2in1 调用前必须查询，不支持 IMMERSIVE 时退回 `SMOOTH` |
| 尺寸 | `barWidth: { smallWidth, mediumWidth, largeWidth }`；`barSideMargin` 默认 16/24/32vp（<600 / 600–840 / >840）；`barBottomMargin` 默认 0 |
| 默认宽度 | 页签数 ≥4 时，默认栏宽**上限 328vp**（<440 / 440–600 / 600–840 且高宽比≥0.8 / >840 分档）；当前自绘 Dock 在平板可用到 640vp，宽度会明显收窄，`barWidth` 能否突破上限需 spike |
| 迷你栏 | `miniBar.miniBarBuilder` 可自定义内容区（`@since 6.1.0(23)`） |
| 系统能力 | `SystemCapability.UIDesign.HDSComponent.Core`（HMS 能力，OpenHarmony 纯开源设备不提供） |
| 页签项 | 文档示例使用 `BottomTabBarStyle(icon, label)`；`bleedIconStyle(CustomTabBuilder)` 只能做"出血图标"，不是整项自绘 |

> 待 spike 确认（文档未写死）：① `TabContent.tabBar(@Builder)` 完全自定义页签时，系统材质是否仍然生效；若不生效，则只能使用系统页签样式。② `barWidth` 自定义值能否突破默认 328vp 上限（当前平板 Dock 可用到 640vp）。

## 5. 方案 A 的结构设想

> 正式落地时按 **§12** 拆成"App 定义的 `BottomNav` 基底 + 可替换皮肤"；本节只示意**系统皮肤**的内部结构。

```
WithTheme { Stack {
  XComponent(sky)                       // 保持原位，绝不 reparent
  HdsTabs({ barPosition: BarPosition.End }) {
    5 × TabContent() { }                // 内容区留空（透明），只提供页签项
  }
    .vertical(false)
    .barOverlap(true)
    .scrollable(false)                  // 禁止横滑切页
    .barFloatingStyle({ barWidth, barBottomMargin, systemMaterialEffect })
    .hitTestBehavior(HitTestMode.None)  // 仅视觉；点击仍由现有 zIndex 80 命中层分发
  panels / chrome / 现有命中层
} }
```

要点：

1. **页签数量 = 5**（搜索 / 时间 / 快捷开关 / 图层 / 更多功能），与 `actions` 同源，避免第二套入口表。
2. **页签选中态与 `activePanel` 双向同步**：点击页签 → `setPanel(...)`；面板关闭时页签仍保持上次索引（Tabs 没有"无选中"状态）。
3. **视觉与命中分离**：bar 设 `hitTestBehavior(None)`，继续用现有顶部命中层 + `isDockPoint` 分发，避免 Tabs 吞掉星空手势；代价是失去系统自带的按压弹性动效。
4. **几何单一来源**：把 `dockTop()/dockHeight()` 改为"由 bar 参数推导"的常量（`barBottomMargin + barHeight`、`barSideMargin`、`barWidth` 分档），chrome 行、面板锚点、命中层继续引用同一函数。
5. **夜间模式**：先按"系统材质 + `lightColor` 微调"实现；若必须保持红黑色调，只能在材质上叠一层半透明红（会削弱材质通透感），需要产品决策。

## 6. 影响面清单（若进入 S1）

| 文件 | 改动 | 风险 |
|---|---|---|
| `pages/MainWindowNativeNode.ets` | 根部插入 HdsTabs；`dockTop/dockHeight/chromeRowY` 改为 bar 推导；命中层与 panel 锚点跟随 | 中（26 处 dockTop 引用） |
| `panels/shell/BottomDock.ets` | 退役或改为"夜间材质遮罩层"；`DockButton` 自绘样式不再使用 | 中（视觉全换） |
| `panels/shell/ExpandedShell.ets` / `HoverObservatoryShell.ets` / `CompactShell.ets` | 移除自绘 Dock 的定位与高度 | 低 |
| `common/derive/geometry.ets` | `dockLeft/dockWidthPixels/isDockPoint` 参数改为 bar 几何 | 中（宿主 27 处 + 输入 2 处） |
| `common/ui/ChromeGeometry.ets` | `CHROME_ROW_OFFSET` 等随 bar 高度重算 | 低 |
| `capability/SkyInputController.ets` | Dock 命中/面板拖拽分支跟随新几何 | 低 |
| `state/DockStore.ets` / `LanguageStore` | 页签文案与语言切换联动 | 低 |
| `docs/harmonyos/json/ui-contract-baseline.json` | 若新增页签 `.id()`（建议加 `dock-tab-<panel>`）需更新契约 | 低（`.id()` 是跨会话契约） |

> 若采用 **§12** 的"基底 + 皮肤"结构：`dockTop/width/isDockPoint` 先收口到 `common/nav/BottomNavMetrics.ets`，旧文件 `BottomDock.ets` 保留为皮肤 B；上表的"根部插入 HdsTabs"改为"在 `BottomNav` 分发器里渲染皮肤 A"。

## 7. 风险登记

| 编号 | 风险 | 等级 | 缓解 |
|---|---|---|---|
| R1 | XComponent surface 重建（黑屏/纹理重载） | 高 | A 方案不移动 XComponent；spike 中连续开关页签 50 次并检查首帧 |
| R2 | Tabs 内容区拦截星空手势（拖动/缩放/点选失效） | 高 | `hitTestBehavior(None)` + 现有命中层；spike 用真实星图拖拽验证 |
| R3 | 系统页签视觉不可控（字体、图标尺寸、选中胶囊、间距、默认栏宽 328vp 上限） | 中 | 先出对比截图再决定；不接受则回退 C |
| R4 | 夜间模式失去红黑主题 | 中 | `lightColor` 微调 / 半透明红遮罩；需产品确认 |
| R5 | 面板/读数行几何回归 | 中 | 几何常量单一来源 + 契约检查 + 三布局（手机/平板/悬停）回归 |
| R6 | "面板关闭"无对应页签状态 | 中 | 保留上次索引；如需"无高亮"，只能自绘 |
| R7 | PC/2in1 材质能力差异 | 低-中 | `getSystemMaterialTypes()` + `canIUse` 降级 |
| R8 | 非 HMS 设备无 HDS | 低 | 只在 HarmonyOS NEXT 发行；运行时能力检查后回退自绘 |

## 8. 验证与切片建议

| 切片 | 内容 | 验收 | 估时 |
|---|---|---|---|
| **S0 spike** | 独立 scratch 页面：`XComponent` + `HdsTabs` 悬浮页签（5 项、空内容、`hitTestBehavior(None)`） | ① 材质可见；② 星图连续拖拽 60s 不掉帧、不黑屏；③ 页签点击不吞星空事件；④ 夜间模式下截图确认可接受度 | 1 人日 |
| S1 | 正式接入 bar-only，页签 ↔ `activePanel` 联动 | 三布局下点击/高亮/关闭行为一致 | 1–1.5 人日 |
| S2 | 几何统一（dockTop/chrome/panel/命中/输入） | `check-ohos-ui-contract.mjs` 通过；宿主 27 处引用全部改为新函数 | 0.5–1 人日 |
| S3 | 清理自绘 Dock、回归 | 真机 + 模拟器：启动 60s 无崩溃、面板定位、夜间模式、返回栈 | 0.5 人日 |

**S0 的 go / no-go 标准**：四项验收全过且视觉评审接受系统页签样式，才进入 S1；任一不过则保留现状（成本 0）。

## 9. 工作量估算

- A 方案（bar-only）：**3–4 人日**（不含视觉返工与真机长稳回归）。
- A 方案 + `BottomNav` 基底抽象（§12，推荐）：**+1 人日**（T0 纯重构可单独提交），后续换皮/回退成本显著降低。
- B 方案（Tabs 作为根）：5–7 人日，且带 XComponent 重建风险，不建议。
- 现状 C：0；D（uiMaterial）：2–3 人日 + 视觉双轨或提升 minSdk。

## 10. 待 review 的决策点

1. 是否接受**系统页签的图标/标签排版与选中态**（现有 `DockButton` 的自绘样式无法完全保留）？以及默认栏宽上限 328vp（平板当前可用到 640vp），读数行会跟着重新对齐。
2. 夜间模式下，系统材质**不会变成红色**；是否接受？如不接受，是否接受"材质上叠半透明红"导致通透感下降？
3. 面板关闭时是否接受**始终有一个页签高亮**？
4. 先做 S0 spike（1 人日）还是维持现状、把精力放在其他体验项？
5. 是否愿意为了 `uiMaterial`（API 26）提升 `compatibleSdkVersion`，还是坚持 23 起可用？
6. 若走双轨：按**能力**分轨（HDS 6.1.0(23)+，推荐）还是按**版本**分轨（23–25 旧 / 26+ 新）？两者的差异、代码骨架与额外成本见 **§11**。
7. 是否接受 **§12 的"基底 + 皮肤"结构**：官方导航构件作为皮肤 A，自绘作为皮肤 B，`auto/system/custom` 可切？若接受，建议先做 T0（纯重构、零视觉变化），再评估系统皮肤的实际效果。

## 11. 双轨制（API 23 旧皮肤 / API 26 新皮肤）评估

### 11.1 结论

**可以做，但"按版本分轨"不是最优切法**，原因有两条：

1. **26 的 `uiMaterial` 也不能给普通自绘组件直接加材质**。官方《开启沉浸光感》明确写了生效范围：
   > Slider、Toggle、Select 可在全页面生效；**其他组件仅在 Navigation/NavDestination 标题栏，或横向 Tabs 且 `barPosition = BarPosition.End` 的底部 TabBar 中生效。在其他区域中设置沉浸光感效果不生效。**

   也就是说，26+ 仍然要换成 Tabs（或 Navigation 标题栏）结构，不是"在现有 Stack 上加一个属性"。
2. **HDS 的 `HdsTabs` 从 6.1.0(23) 就提供同一套系统材质的封装**（`systemMaterialEffect`）。如果只为了材质，23 就能用，按 26 分界的收益只剩 26 独有的 `ImmersiveStyle` / `materialColor` / 反色适配等细节。

因此更稳的切法是**按能力分轨**而不是按版本号分轨：

| 轨道 | 判定条件（运行时） | 皮肤 | 材质来源 |
|---|---|---|---|
| 新皮肤 | `canIUse('SystemCapability.UIDesign.HDSComponent.Core')`（HDS 从 6.1.0(23) 起，无需再查版本号） | HdsTabs 悬浮页签（bar-only） | HDS `systemMaterialEffect` |
| 新皮肤增强（可选） | 上一行成立，且 `deviceInfo.sdkApiVersion >= 26` 且 `uiMaterial.isImmersiveMaterialSupported()` | 同上 | 26 的材质等级/赋色微调 |
| 旧皮肤 | 以上不成立 | 当前自绘 Dock（`backgroundEffect` + 触点高光） | 无（近似） |

> 我们 `compatibleSdkVersion = 6.1.0(23)`，所以**正常情况下所有支持设备都会走新皮肤**；旧皮肤只在非 HMS 设备或能力被裁剪时兜底。这比"23–25 旧 / 26+ 新"更省事，也避免维护两套结构。

### 11.2 如果坚持按版本分轨（23–25 旧 / 26+ 新）

- **版本判定（重要）**：`deviceInfo.apiAvailable` 本身是 **6.1.0(26)** 才新增的方法，在 23–25 设备上调用会因缺少该方法而崩溃，**不能**用它做低版本分流。本项目判定 26 能力请用 `deviceInfo.sdkApiVersion >= 26`（`uiMaterial` 属于 OpenHarmony 底座接口，`sdkApiVersion` 正是它的版本号）。
- 如果某段代码已经确定运行在 26+（例如在 `sdkApiVersion >= 26` 分支内），需要更细的版本判断时再使用 `apiAvailable('26.0.0')`：版本号必须是**字面量**、**直接写在 `if` 条件里**（不能封装成变量/函数，不能用 `&&`/`||`/`!`/三元），否则编译期告警消除失效。
- **能力判定**：26+ 也要再查 `uiMaterial.isImmersiveMaterialSupported()`；低算力设备可能返回 false，此时材质不生效，仍应回退旧皮肤。
- **结构不随版本分叉**：Tabs 结构在 23 就已引入（HdsTabs），26 只改材质参数（`ImmersiveStyle`、`materialColor`、材质等级），避免"两套布局"。
- **几何必须单一来源**：两套皮肤都必须把 `dockTop()/dockHeight()/dockWidth` 作为唯一出口喂给面板锚点、读数行、命中层；一旦皮肤各自算一份，chrome 行和面板命中会漂。
- **导入风险**：`@kit.UIDesignKit` 的静态导入按官方示例是允许的（示例就是 `import { HdsActionBar } from '@kit.UIDesignKit'` + `apiAvailable(20)` 条件渲染）；但 `@ohos.arkui.uiMaterial` 是 26 才有的模块，**必须在 23–25 设备上验证模块加载不报错**。规避办法：把 26 专用调用集中到单个 adapter 文件，且优先只用 HDS 的 `systemMaterialEffect`（23 起即有），完全不碰 `uiMaterial`。

### 11.3 代码骨架（ArkTS）

```typescript
import { deviceInfo } from '@kit.BasicServicesKit'

// 只做能力判断，不在这里写布局；皮肤二选一由 build() 的条件渲染决定。
private useMaterialDock(): boolean {
  return canIUse('SystemCapability.UIDesign.HDSComponent.Core')
}
```

```typescript
// build() 内：结构二选一，几何仍由宿主统一计算
if (this.useMaterialDock()) {
  // HdsTabs bar-only 皮肤
} else {
  // 现有 BottomDock（当前线上皮肤）
}
```

26 的分支只允许出现在材质参数上（例如材质等级由 `SMOOTH` 提升到 `ADAPTIVE/EXQUISITE`），不要再多一套布局：

```typescript
if (deviceInfo.sdkApiVersion >= 26) {
  // 26+：可用 uiMaterial 的材质等级/赋色（前提是 isImmersiveMaterialSupported()）
} else {
  // 23–25：HDS systemMaterialEffect 默认档位
}
```

### 11.4 双轨制的额外成本与风险

| 项 | 说明 |
|---|---|
| 维护面 | 两套皮肤 = 两套视觉回归清单；`DockButton` 的自绘样式在旧皮肤继续存在 |
| 测试缺口 | 当前只有 API 26 真机 + API 26 模拟器；23–25 分支无法真机验证，必须让旧皮肤保持"当前已上线代码"以降低风险 |
| 结构一致性 | 两套皮肤共用 `dockTop/width`、`activePanel`、`isDockPoint`，否则面板锚点/命中必然漂移 |
| 主题 | 旧皮肤仍有夜间红黑；新皮肤由系统材质控制，两套观感差异明显，需要产品确认是否接受 |
| 构建 | 两套代码都进包（静态编译），无法按 API 版本裁剪体积 |

## 12. 导航构件抽象（推荐的落地形态）

这一节把"**官方导航构件只是实现，App 自己定义底部导航基底**"的思路落成可执行的结构。核心是：先抽象，再换皮。

### 12.1 设计原则

1. **基底是 App 的 `BottomNav`，不是 HdsTabs**。HdsTabs / Tabs / 自绘 Dock 都只是 `BottomNav` 的一个"皮肤实现"。
2. **语义与视觉分离**：条目（5 个）、选中面板、点击回调、语言切换属于基底；材质、圆角、阴影、动效属于皮肤。
3. **几何单一来源**：`dockTop / dockHeight / dockWidth / dockLeft / isDockPoint` 由基底计算，皮肤只负责"填满给定盒子"，禁止皮肤自己算位置。
4. **皮肤可替换、可回退**：系统皮肤不满意时可整块切回自绘皮肤，不改调用方。

### 12.2 分层与文件

```
common/nav/BottomNavModel.ets        // 数据：items、activePanel、languageRevision（无 UI）
common/nav/BottomNavMetrics.ets      // 几何：dockTop/dockHeight/dockWidth/dockLeft/isDockPoint
common/nav/BottomNav.ets             // 分发器 @Component：按 surface 选择皮肤，接收统一回调
panels/shell/nav/SystemBottomNav.ets // 皮肤 A：HdsTabs 悬浮页签（系统材质）
panels/shell/BottomDock.ets          // 皮肤 B：现有自绘（保留，作为回退/对照）
```

> 注意宿主既有约束：宿主 `@Builder` 不能传进子组件（会渲染整页导致退出）。因此 `BottomNav` 必须是真正的 `@Component`，用数据 + 回调通信，不能靠传 `@Builder` 进去。

### 12.3 两套皮肤的共同契约

| 契约 | 说明 |
|---|---|
| 盒子 | 宿主把 `BottomNav` 放在 `(dockLeft, dockTop)`，尺寸 `(dockWidth, dockHeight)`；皮肤内部 `width/height 100%`，不得越界 |
| 回调 | `onSelect(panelId)`、`onTouch(event)`（用于触点高光/面板拖拽分发） |
| 选中态 | 由 `activePanel` 驱动；两套皮肤都必须支持"面板关闭时保持上次选中" |
| 命中 | 皮肤可自绘，但**命中仍由基底的 `isDockPoint` 判定**；系统皮肤设 `hitTestBehavior(None)`，避免吞星空手势 |
| id | 新增皮肤时统一 `dock-tab-<panel>`，并同步 `ui-contract-baseline.json` |
| 主题 | 皮肤各自实现；基底不下发颜色 |

### 12.4 皮肤选择与回退

| 模式 | 行为 | 用途 |
|---|---|---|
| `auto`（默认） | 能力满足 → 系统皮肤；否则自绘皮肤 | 线上默认 |
| `system` | 强制系统皮肤（能力不足时仍回退并记日志） | 评审/对比 |
| `custom` | 强制自绘皮肤 | 效果不满意时的兜底、低端机省电 |

- 选择依据：`canIUse('SystemCapability.UIDesign.HDSComponent.Core')`；26+ 再叠加 `sdkApiVersion >= 26` 与材质能力检查。
- 存储：**先做内部调试开关**（不落盘/仅 debug），避免 `UiSettings` schema 从 2 升到 3；若确认要用户可选，再升 schema。
- 回退必须无副作用：两套皮肤共享同一 `activePanel`/几何，切换只影响绘制。

### 12.5 系统皮肤（HdsTabs）的实现要点

1. **bar-only**：`HdsTabs` 只提供页签栏，`TabContent` 留空；星图 `XComponent` 保持原位，绝不 reparent。
2. **宽度回填**：系统栏宽度由 HDS 决定（≥4 项默认上限 328vp），用 `onBarStyleChange` 回调里的 `tabBarWidth` 回填 `BottomNavMetrics.dockWidth`，让读数行/命中层/面板锚点跟着走，而不是假设等于容器宽度。
3. **命中分离**：bar 设 `hitTestBehavior(HitTestMode.None)`，点击仍由现有 zIndex 80 命中层 + `isDockPoint` 分发；代价是没有系统自带的按压弹性动效（可选：在命中层上加自制按压反馈）。
4. **夜间模式**：材质由系统渲染，`lightColor` 只能微调高光；若要红黑观感，只能叠半透明红（会削弱通透感），需产品确认。
5. **26 增强**：仅在 `deviceInfo.sdkApiVersion >= 26` 且 `uiMaterial.isImmersiveMaterialSupported()` 时调整材质等级/赋色，不改变结构。

### 12.6 保留自绘皮肤的价值

- 效果不满意时的**即时回退**，不需要回滚版本。
- 低端机/非 HMS 设备的**兜底**。
- 作为系统皮肤的**对照基线**：同一套验收用例跑两遍，差异一眼可见。

### 12.7 落地切片（先抽象、再换皮）

| 切片 | 内容 | 视觉变化 | 验收 |
|---|---|---|---|
| **T0** | 抽出 `BottomNavModel / BottomNavMetrics / BottomNav`，宿主只接基底；**只保留自绘皮肤** | 无 | 三布局回归、`ui-contract` 通过、面板锚点/命中不变 |
| **T1** | 新增 `SystemBottomNav` 皮肤（bar-only），`surface=system` 时启用 | 有 | 材质可见、星图手势不受影响、页签↔面板联动、连续开关 50 次 surface 不重建 |
| **T2** | `auto` 默认 + `custom` 回退 + 内部切换开关 | 视能力 | 两套皮肤跑同一验收矩阵 |
| **T3**（可选） | 26 材质等级/赋色增强；用户可见的"导航栏样式"设置 | 微调 | 真机截图评审、省电模式回归 |

> T0 是关键：它是**纯重构、零视觉变化**，可以独立提交并回归，把风险与"换皮"解耦。

### 12.8 验收矩阵（两套皮肤共用）

| 用例 | 期望 |
|---|---|
| 冷启动 60s | 无崩溃、无 appfreeze；星图首帧正常 |
| 5 个入口点击 | 打开对应面板；选中态正确；面板关闭后保持上次选中 |
| 星空拖拽/缩放/点选 | 不被 Dock/Tabs 拦截 |
| 面板锚点 | 面板下沿 = `dockTop - 10`；读数行位于 `dockTop - 46` |
| 夜间模式切换 | 无残留、无闪白；两套皮肤各自观感确认 |
| 折叠/悬停/手机/平板 | 四类布局几何一致 |
| `check-ohos-ui-contract.mjs` | 通过（新增 `dock-tab-*` 需入基线） |

### 12.9 实施记录（2026-10-25）

**T0 已完成（纯重构，零视觉变化）**

| 新增/修改 | 内容 |
|---|---|
| `common/nav/BottomNavMetrics.ets` | `NAV_EXPANDED_BASELINE=62`、`NAV_EXPANDED_HEIGHT=54`、`NAV_COMPACT_HEIGHT=66`、`NAV_PANEL_GAP=10`；`bottomNavTop/Height/Rect` 统一几何 |
| `common/nav/BottomNavModel.ets` | `BottomNavSurface{auto,system,custom}`、`systemBottomNavAvailable()`（仅 syscap）、`resolveBottomNavSurface()`、`DEFAULT_BOTTOM_NAV_SURFACE` |
| `common/nav/BottomNav.ets` | 皮肤分发器，当前默认 `custom`；`surface` 可注入 |
| `panels/shell/{Expanded,Compact,HoverObservatory}Shell.ets` | 由 `BottomDock` 改为 `BottomNav`，定位/高度不变 |
| `pages/MainWindowNativeNode.ets` | `dockTop/dockHeight` 改由 metrics 推导；面板间距统一 `NAV_PANEL_GAP` |

验证：`arkts_check` 通过、`devecocli build` 成功、`check-ohos-ui-contract.mjs` 通过（295 文件）、MatePad 模拟器上 Dock 位置/面板锚点/点击行为与改造前一致。

**T1 已实现（opt-in），但默认未启用**

`panels/shell/nav/SystemBottomNav.ets`：`HdsTabs` + `BarPosition.End` + `barOverlap(true)` + `barFloatingStyle({ systemMaterialEffect })`，`TabContent` 留空，`hitTestBehavior(None)`，点击仍由宿主命中层分发。

实测（MatePad Pro 13 模拟器，API 26，surface=system）：

| 观察 | 结论 |
|---|---|
| 组件可渲染 5 个页签，点击 Dock 能正常打开对应面板 | 结构可用；`hitTestBehavior(None)` 没有影响宿主命中层 |
| 默认 `gradientMask` 在黑色星空上显示为**白色渐变带** | 已用 `barBackgroundStyle({ maskColor: '#00000000' })` + `gradientMask.maskHeight: 0` 关闭，深色胶囊观感可接受 |
| 页签栏宽度约 **330vp**（命中 328vp 上限），而自绘 Dock 为 640vp | 会导致读数行/面板锚点横向错位；启用前必须做 `onBarStyleChange` 宽度回填（T2） |
| 选中态/图标使用系统配色（浅色胶囊），夜间红色主题不生效 | 视觉需产品确认；当前默认仍用自绘皮肤 |
| 纯黑背景下无法判断材质强弱 | 需真机 + 有星图的亮背景再验收 |
| `deviceInfo.apiAvailable` 为 26 才有的方法 | 已在实现中改用 `canIUse` 判定 HDS，避免 23–25 崩溃（同时修正了 §11 的代码骨架） |

**结论**：T0 可上线（行为不变）；T1 保留为可切换皮肤，`DEFAULT_BOTTOM_NAV_SURFACE` 仍为 `CUSTOM`。剩余 T2 工作：栏宽回填 → 读数行/命中/面板锚点跟随；夜间主题取舍；`auto` 默认切换与验收矩阵全跑。

**真机补充实测（SGT-AL00B / HarmonyOS 7.0.0 / API 26，surface=system 临时切换）**

| 观察 | 结论 |
|---|---|
| 连接方式 | `hdc tconn <ip>:<port>` 可用；`devecocli run --skip-build --device <serial>` 可直接安装/拉起 |
| 明亮地景上材质清晰可见，但整条栏被染成**黄绿色** | 系统材质的互补色适配生效；与当前中性/夜间红色调冲突，需产品确认或用 26 的 `materialColor` 压制 |
| 页签栏盒子 `[0,2552,1280,2783]`（66vp），宿主 `dockTop` 对应 713–779vp，实际视觉在 729–795vp | 视觉与命中基线相差 **16vp**（CompactShell 绘制在 `skyHeight - 80`，宿主按 `skyHeight - 96` 计算），栏底部约 16vp 不可点 |
| 点按页签（y=2715）能打开“图层”面板 | 宿主命中层仍生效；`hitTestBehavior(None)` 未拦截 |
| 手机端栏宽 ≈350vp，与 chrome 行宽度接近 | 手机端偶然对齐；平板端 328vp vs 640vp 的偏差仍需宽度回填 |
| 真机在测试尾声锁屏，`aa start` 返回 10106102 | 与代码无关；后续手势/夜间模式验收需解锁后继续 |

> 真机结论：**材质确实存在且效果明显**，但"视觉盒子 ≠ 命中盒子"和配色是启用前必须解决的问题；这也是 §12.7 把 T2 单独列出的原因。

## 13. 参考

- 本地文档：`API参考/UI_Design_Kit_UI设计套件/ArkTS组件/HdsTabs_底部页签/ui-design-hdstabs`
- 本地文档：`开发指南/UI_Design_Kit_UI设计套件/沉浸光感/ui-design-hds-component-material`
- 本地文档：`开发指南/ArkUI_方舟UI框架/UI开发_ArkTS声明式开发范式/沉浸光感/沉浸光感简介/arkts-immersive-light-sense-overview`
- 本地文档：`开发指南/ArkUI_方舟UI框架/UI开发_ArkTS声明式开发范式/沉浸光感/沉浸光感开发指导/开启沉浸光感/arkts-immersive-light-sense-enable`（生效范围与开关）
- 本地文档：`版本说明/应用兼容性说明/应用开发中的兼容性场景开发指导/API兼容性保护和告警屏蔽/ArkTS_API兼容性保护/arkts-api-compatibility-warning-elim`（`apiAvailable` 用法与限制）
- 代码：`harmonyos/ets-source/pages/MainWindowNativeNode.ets`、`panels/shell/BottomDock.ets`、`panels/shell/ExpandedShell.ets`、`common/derive/geometry.ets`、`common/ui/ChromeGeometry.ets`
- 相关提交：`5d99ca6e87`（Dock 胶囊/高光 + 平板面板底部对齐）
