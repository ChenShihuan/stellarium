# pages/ 重构终态架构评审（MainWindowNativeNode.ets 及其拆分结构）

- **状态：** 待用户评审。本文只做分析与评价，未改动任何源码。
- **日期：** 2026-10-04（§2.7 域状态下沉完成后首轮复测）
- **评审对象：** `harmonyos/ets-source/pages/MainWindowNativeNode.ets` 当前形态（**18,582 行**）及
  `state/`（**48 文件 / 3,075 行**）、`panels/`、`bridge/`、`common/` 拆分目录。
- **对照基准：** `docs/harmonyos/research/ARKTS-PAGES-REFACTOR-PLAN.md`（§3 目标架构、§13 执行记录）。
- **数据来源：** 全部数字为本轮在当前 HEAD 上实测（命令见附录），非计划文档转录。

---

## 1. 摘要

重构队列（Phase 0 → Phase 7 + Phase RA）**已全部完成**，`check-ohos-ui-contract.mjs` 全绿
（33 面板 / 22 静态 id / 17 动态前缀 / 42 锚点 / 184+ 文件）。终态指标：

| 指标 | 重构前（计划 §1.2 实测） | 当前实测 | 变化 |
|---|---:|---:|---|
| 主文件行数 | 32,774 | **18,582** | −43.3% |
| `@Builder` | 145 | **3** | −97.9% |
| `@State` 字段 | 1,047 | **132** | −87.4% |
| `private` 方法 | ≈1,109 | **940** | −15% |
| `setInterval` | 20 | **19** | 定时器全部宿主收口 |
| `panelContent` 体量 | 4,707 | **898** | −80.9% |
| 组件/Store 文件 | 0 | **state 48**（+ panels 119 / bridge+common 10） | — |

> 注：计划终态记载 18,593 行。2026-10-04 完成 **§2.7「域状态下沉」**后，宿主 `@State` 由 333 → **132**
> （46 个 store 实例 + 86 个刻意保留的裸字段，登记于 §2.7.1），`state/` 由 27 → **48** 文件；
> 随后 **A/B 类方法下沉**（PLAN §14，38 片）完成，宿主降至 **14,347 行 / 593 私有方法 / 3 个 `load*`**，
> `bridge/CommandPort.ets` 建成。**A/B 之后的"剩余功能模块"普查与下沉候选见 §9。**

主文件从「单体上帝组件」转型为**页面壳/胶水层**：状态所有权已下沉到 **46 个 `@Observed` store 实例**
（`state/` 共 48 文件），UI 已下沉到 119 个组件文件，宿主保留的是生命周期编排、桥薄委托、面板路由与回调仓库。

---

## 2. MainWindowNativeNode.ets 当前框架与逻辑

### 2.1 物理分区（实测行号）

```
L1–224      import 区 + 文件级常量（SKY_TEXTURE_STATUS_* / BODY_DETAIL_TEXTURE_PATHS）
L225        @Component struct WindowNativeNode
L226–1146   字段声明区（≈920 行）
              ├─ @State 132 个：store 实例（46 个）+ 壳层/布局/路由/逐帧裸字段（86 个，见 §2.7.1）
              └─ private 字段：定时器句柄、请求序号、手势草稿、渲染管线逐帧字段
L1147       aboutToAppear：取 createInfo → 隐私门控启动（startPageAfterPrivacyIfNeeded）
L1642       aboutToDisappear：全量定时器/传感器 stop 收口
L2471–2566  桥薄委托层（callNative / callNativeFire / callNativeWhenReady / callInteractive
            → 全部转发 bridge/BridgeClient，宿主不 import libentry.so）
L14190      build()：根 Stack（667 行，五类结构见 2.3）
L17103      @Builder floatingPanel()
L17160      @Builder compactPanel()
L17208      @Builder panelContent()（898 行，33 分支 if/else 组件装配）
L18106–尾部  残留领域方法（JD 输入处理、handleChip、panelTitle/Subtitle、图层预设、
            viewTab/configTab 切换动画）
```

### 2.2 三个幸存 `@Builder` 的职责

| Builder | 行数 | 职责 | 保留原因 |
|---|---:|---|---|
| `floatingPanel()` | 56 | expanded 构型的右侧面板包裹：PadPanelHandle + PanelHeader + Scroll 路由宿主 | 体内调用 `this.panelContent()`，**不能**作为 `@BuilderParam` 传入子组件（规则 9：真机实测渲染即应用退出） |
| `compactPanel()` | 47 | compact/fold-hover 构型的底部面板包裹（拖拽沉降、snap） | 同上 |
| `panelContent()` | 1,046 | 33 个 `activePanel` 分支 → 组件装配（每分支传入 store 引用 + `@Prop` + 回调） | 分支入参高度异构（object 分支 25 `@Prop` + 17 回调；time 分支 5 store + 12 参数），未做表驱动（见 §4.2-3） |

### 2.3 宿主 `build()` 结构（与计划 Phase 6 收口结论逐条吻合）

```
Stack（根）
├─ 语言刷新锚点 Text(i18nLang) + gl-probe XComponent + qohos NODE XComponent（隐私放行后）
├─ 触摸反馈气泡 ×2（单指/双指）+ 全屏触摸承接 Stack（handleOverlayTouch）
├─ 脚本/导览焦点层：scriptPlaybackVisible → InteractiveGuideShell | ScriptFocusShell
│   + RecordingFocusShell（录制沉浸态）
├─ 三壳分发：isFoldHover → HoverObservatoryShell │ isExpanded → ExpandedShell │ else CompactShell
│   每壳之后：if (panelVisible) { this.compactPanel() / this.floatingPanel() }（宿主包裹）
├─ Dock 命中区：顶层命中靶 Stack + HarmonyShell（坐标叠层/陀螺仪指引/反馈气泡）
└─ 浮层与状态条：RecordingControlBar + PolarScopeOverlay + 3 个 Phase 5 Overlay
    + skyTextureStatus 横幅
```

### 2.4 宿主残留职责清单（"胶水"的实际含义）

1. **生命周期编排**：隐私门控启动、前后台切换（`applicationInForeground`）、
   `aboutToDisappear` 里对 19 个 `setInterval` 与传感器统一 stop。
2. **桥薄委托**：4 个委托方法（L2603–2698）转发 `BridgeClient`；195 处 `callInteractive`
   类调用点仍在宿主（计划 Phase 2 的既定形态：桥实现唯一化，调用点不强制改写）。
3. **面板路由**：`openPanel` / `closePanel` / `openSubPanel` / 返回栈（`panelNavigationStack`）、
   `panelRouteOpacity` 转场动画状态、`panelTitle()` / `panelSubtitle()` 纯函数。
4. **回调仓库**：供下沉组件注入的回调方法（如 `AstroPanelHost` 的 114 个回调、
   `UnifiedObjectDetailCard` 的 17 个回调）——组件化"参数按值捕获"约束下的必然形态。
5. **渲染管线逐帧字段**：`objectInspectorModelRendering`、`objectDetailConnector*` 几何等
   **刻意不入 `@Observed` store**（逐帧写入会引发重渲染风暴），以 `@Prop` 快照传入组件。
6. **CLI 事件分发**：`onCliUiEventChanged` 把语义 CLI 事件路由到面板/搜索/卫星联动。

### 2.5 总体心智模型：这不是 UI 文件，而是"控制器"

主文件已从「单体上帝组件」转型为 **Composition Root + 事件路由器 + 领域编排层**
（相当于 Activity 与全部 ViewModel 的合体）。UI 树与状态所有权已搬走（119 组件 + 46 store），
留下的是**控制器质量**：**940 个 `private` 方法**服务约 15 个领域。
用一句话读它：**"接线层声明 UI，其余全是把外部事件翻译成桥调用与状态写入"**。

### 2.6 纵向五层解剖（18,582 行的构成，实测）

```
┌──────────────────────────────────────────────────────────────┐
│ L1 接线层        ≈ 1,800 行  10%                             │
│   import 区(224) + build()(667) + 3 个 @Builder(panelContent 898) │
│   纯声明式：组件装配、@Prop 参数快照传递，不含业务逻辑          │
├──────────────────────────────────────────────────────────────┤
│ L2 状态表面      ≈ 920 行  5%（L226–1146 字段区）             │
│   46 个 store 实例 + 132 @State + 裸字段                       │
│   private 字段三类：定时器句柄 / 请求序号 / 手势草稿            │
├──────────────────────────────────────────────────────────────┤
│ L3 事件入口层    ≈ 2,000 行  11%（六条入口通道，见 2.8）       │
│   lifecycle / touch / CLI / sensor / fold / timer             │
├──────────────────────────────────────────────────────────────┤
│ L4 领域编排层    ≈ 13,800 行  74%  ← 体积的真正来源            │
│   约 15 个领域簇 × 每簇一套 loader/handler/publisher           │
│   940 个 private 方法的主体在这里（见 2.9 域地图）             │
├──────────────────────────────────────────────────────────────┤
│ L5 桥委托层      ≈ 30 行  0.2%（L2471–2566）                  │
│   callNative/callNativeFire/callNativeWhenReady/             │
│   callInteractive → 全部转发 bridge/BridgeClient              │
└──────────────────────────────────────────────────────────────┘
```

**核心认知：约 3/4 的行数是 L4，这不是"没拆干净"**，而是 ArkUI V1 的结构性约束——
没有 Composition 函数、组件回调必须是宿主方法、`@Builder` 不能传子组件
（规则 9），因此"控制器代码"在 V1 下**只能**长在宿主 struct 上。

**最大方法 TOP 8（实测）**：`panelContent`(898) / `build`(667) / `handleSkyTouch`(282) /
`onCliUiEventChanged`(266) / `applySelectedObject`(230) / `refreshStateNow`(183) /
`refreshObjectInspectorMedia`(175) / `refreshObjectDetailConnector`(138)。
前两个是接线，其余全部是领域编排——印证 L4 主导。

### 2.7 两种组件接入风格：Store 风格 vs Prop 风格（历史分类，2026-10-04 已收敛）

拆分期曾并存两种接法；**2026-10-04 的"域状态下沉"把 Prop 风格域全部转为 Store 风格**，
宿主 `@State` 由 333 → **132**（46 个 store + 86 个刻意保留的裸字段，见 §2.7.1）。下表为历史分类留档：

| 风格 | 机制 | 原适用域 | 现状 |
|---|---|---|---|
| **Store 风格** | 状态入 `@Observed` store，组件 `@ObjectLink` 实时订阅 | 队列按体积优先处理过的大域（`AstroPanel`/`LayersPanel`/`TelescopePanel`） | 保持 |
| **Prop 风格** | 状态**仍留宿主** `@State`，`@Prop` 快照 + 回调回注 | 卫星 / 脚本录制 / navStars / archaeo / mosaic / catalogs / meteorShowers / scenery3d | **已建 store**（`SatelliteStore`/`ScriptStore`/`NavStarsStore`/`ArchaeoStore`/`MosaicStore`/`CatalogStore`/`MeteorStore`/`SceneryStore`…），转为 Store 风格 |

**历史取舍依据**（组件头注）：`panels/panels/SatellitesPanel.ets` 曾注
"*本片不搬状态（搬动会牵动 160 处引用），全部以 @Prop 快照传入*"。
**收敛后的含义：** 全部域的**状态所有权都已在 store**，"刷新范围=订阅者"覆盖全应用；
宿主仅剩 §2.7.1 登记的机制类 / 高频逐帧 / 跨域共用裸字段（刻意不搬）。

#### 2.7.1 宿主保留字段登记（不迁移）

> 2026-10-04 收尾批实测：宿主 `MainWindowNativeNode.ets` 的 `@State` 为 **132 个 = 46 个 store 实例 + 86 个裸字段**。
> 下表把这 **86 个刻意留在宿主的裸字段**逐类登记，避免后续重复评估"这个字段为什么不搬"。
> 迁移判据：① `@ObjectLink` 只观测字段赋值、观测不到原地变更；② 高频写入（定时器/拖拽逐帧/渐进写入）
> 不入被观察 store（否则重渲染风暴）；③ 只搬面板入参，宿主自用的路由/几何/引擎字段不搬。
> 理由类型：**机制类**（路由/生命周期/请求序号）、**高频逐帧**（每帧或毫秒级写入）、
> **跨域共用**（被两个以上域或全局管线读取）、**引擎自用**（驱动桥/播放器/传感器）、**已登记约定**（既有定论）。

| 类别 | 字段 | 理由类型 |
|---|---|---|
| A 折叠屏 / 响应式布局分发 | `createInfo`、`isExpandedLayout`、`isFoldHoverLayout`、`isFoldableDevice`、`isFoldTabletLayout`、`foldStatusValue`、`foldDisplayModeValue`、`foldAngleValue`、`hasUsableFoldAngle`、`responsiveLayoutMode` | 机制类 |
| B 面板路由 / 壳层机制 | `activePanel`、`panelVisible`、`panelNavigationDepth`、`panelContentKey` | 机制类 |
| C 布局几何 | `skyWidth`、`skyHeight`、`panelWidth`、`panelMaxHeight` | 跨域共用 |
| D 面板 / 卡片转场、空闲淡出与拖拽瞬时量 | `panelIdleOpacity`、`panelIdleGlass`、`panelRouteOpacity`、`panelRouteOffsetX`、`panelPresentationOpacity`、`panelPresentationOffsetY`、`viewTabContentOpacity`、`viewTabContentOffsetX`、`configTabContentOpacity`、`configTabContentOffsetX`、`panelOffsetX`、`panelOffsetY`、`compactPanelSnapRatio`、`compactPanelDragOffsetY`、`objectDetailContentOpacity`、`objectDetailContentTranslateX` | 高频逐帧 |
| E 天体详情指向线几何 | `objectDetailConnectorX/Y/Length/Angle/EndX/EndY/TargetX/TargetY/TargetOnScreen/AnimateGeometry` | 高频逐帧 |
| F 详情卡宿主控制量 | `fullInspectorRequested`、`cardOffsetX`、`cardOffsetY` | 机制类 / 跨域共用 |
| G 视图中心坐标叠层读数 | `viewCoordinatePrimaryText`、`viewCoordinateSecondaryText`、`viewCoordinateOffsetX`、`viewCoordinateOffsetY` | 高频逐帧 |
| H 触摸反馈圈 / 压缩版快捷控件按压 | `skyTouchFeedback`、`skyTouchFeedbackMulti`、`skyTouchX`、`skyTouchY`、`skyTouchX2`、`skyTouchY2`、`compactQuickPressed` | 高频逐帧 |
| I 定时器回填的状态读数 | `locationText`、`coordinateText`、`altitudeText`、`fovText`、`currentFovText`、`trackingText`、`dockClockText` | 高频逐帧 / 跨域共用 |
| J 请求进行中标志 / 桥同步状态 | `trackingRequestPending`、`timeSettingsPending`、`bridgeSyncStarted`、`canUseDistributed` | 机制类 |
| K 时间 / 日期跨域共用 | `pickedDate` | 跨域共用 |
| L 星空文化美术渐进写入 | `skyCultureArtStates`、`skyCultureArtThumbnailPixelMaps` | 高频逐帧 |
| M 目录健康（与卫星面板共用） | `catalogHealthLoaded`、`catalogManifestPresent` | 跨域共用 |
| N 视图 / 设置标签与投影 | `fovSliderValue`、`currentProjection`、`viewTab`、`configTab` | 跨域共用 / 机制类 |
| O 启动 / 加载 / 提示 | `isLoading`、`splashGone`、`actionHint` | 机制类 |
| P 引擎自用 / 已登记约定 | `watchLastSend`、`recordBuffer`、`scenery3dCurrentId`、`landscapeDetailOpen`、`planetLabels` | 引擎自用 / 已登记约定 |

> **本批（2026-10-04 收尾批）从中迁出 4 个裸字段**：`guideState`+`speechStatus` → 新建 `state/GuideStore.ets`；
> `bottomCardIndex` → `state/ObjectDetailStore.ets`；`uiLocked` → `state/ViewSettingsStore.ets`；并删死字段 `moduleList`。
> 其余按类别与理由保留（详见 `docs/harmonyos/CHANGELOG.md` 同日条目）。

##### 2.7.1.1 宿主控制器逻辑（永久保留）——§14 A2 的 A-保留组（2026-10-04，A2-3 片登记）

> **子类定义**：宿主 `private` 方法，满足 §14.0 的 A 类形状（非 `void`/`Promise` 返回、名字非动作动词、
> 无成员写 / 无 IO / 无桥 / 无路由 / 无定时器 / 无 `AppStorage`/`localStorage` / 无 `hilog`），且
> **其全部宿主字段读取项均 ⊆ 上表 §2.7.1 的 86 个保留字段，且不读任何 store**。这类方法的输入全是
> **宿主控制器状态**（布局分发、面板路由、转场/拖拽瞬态、坐标叠层读数等），按 §2.5"宿主是控制器"与
> §14.3.1 的既定处置**登记为永久保留，不再评估下沉**（`this.EDGE_MARGIN` 等**未登记的只读常量**
> 不计入保留集合，故读它的布局方法归 A2-4，不属于本子类）。
>
> **判据固定**：`reads(m) ⊆ §2.7.1 保留集合 ∧ reads(m) ∩ stores = ∅`（`reads` 为含被调宿主方法的
> 传递闭包）。A2-3 开工逐名重测得 **49 个 / 210 行**（原 §14.3.1 占位值 31 系估值且有误抄，以本表为准）。
>
> **A2-4 补登记（2026-10-04）**：+2 —— `dockTop`（只读 `isExpandedLayout`+`skyHeight`）、`guideCardWidth`（只读 `skyWidth`），
> 均为布局/几何族重测时发现的"全部读取项 ⊆ 保留集合且零 store"方法，**合计 51 个**。

| # | 方法 | 读取的保留字段 | 判据命中说明 |
|---:|---|---|---|
| 1 | `compactQuickIdAt` | `isExpandedLayout` `skyWidth` | 读布局分发 + 画布宽，无 store |
| 2 | `responsiveFoldAngle` | `isFoldableDevice` `foldStatusValue` `hasUsableFoldAngle` `foldAngleValue` | 折叠屏机制字段 |
| 3 | `catalogHealthText` | `catalogHealthLoaded` `catalogManifestPresent` | M 类跨域共用标志 |
| 4 | `catalogHealthColor` | `catalogHealthLoaded` `catalogManifestPresent` | 同上 |
| 5 | `bottomCardWidth` | `isExpandedLayout` `isFoldHoverLayout` `skyWidth` | 转场/布局瞬态 |
| 6 | `locationMapWidth` | `isExpandedLayout` `skyWidth` | 同上 |
| 7 | `dragFollowAlpha` | `isFoldTabletLayout` `isExpandedLayout` | 布局分发 |
| 8 | `isCompactTopQuickPoint` | `isExpandedLayout` `skyWidth` | 布局分发 + 画布宽 |
| 9 | `compactObjectPeekWidth` | `skyWidth` | 画布宽 |
| 10 | `compactPanelUsableHeight` | `isFoldHoverLayout` `skyHeight` | 布局瞬态 |
| 11 | `compactPanelHeight` | `isFoldHoverLayout` `skyHeight` `compactPanelSnapRatio` `compactPanelDragOffsetY` | D 类逐帧拖拽瞬态 |
| 12 | `isCompactMorePoint` | `isExpandedLayout` `skyHeight` `skyWidth` | 布局分发 |
| 13 | `expandedUiAllowed` | `isExpandedLayout` | 布局分发 |
| 14 | `compactDockWidthPercent` | `isFoldHoverLayout` `panelVisible` | 布局 + 面板路由 |
| 15 | `bottomCardHeight` | `isExpandedLayout` `skyHeight` `isFoldHoverLayout` `isFoldableDevice` `foldStatusValue` `hasUsableFoldAngle` `foldAngleValue` | 布局 + 折叠机制 |
| 16 | `baseCompactObjectPeekX` | `skyWidth` | 画布宽 |
| 17 | `hoverSkyPaneHeight` | `isFoldableDevice` `foldStatusValue` `hasUsableFoldAngle` `foldAngleValue` `skyHeight` | 折叠机制 + 画布高 |
| 18 | `viewCoordinateOverlayLeft` | `skyWidth` `isExpandedLayout` `viewCoordinateOffsetX` | G 类逐帧读数 |
| 19 | `viewCoordinateOverlayTop` | `isFoldHoverLayout` `isExpandedLayout` `viewCoordinateOffsetY` `skyHeight` | G 类逐帧读数 |
| 20 | `clampedViewCoordinateOffsetX` | `isExpandedLayout` `skyWidth` `viewCoordinateOffsetX` | G 类逐帧读数 |
| 21 | `clampedViewCoordinateOffsetY` | `viewCoordinateOffsetY` `skyHeight` | G 类逐帧读数 |
| 22 | `objectDetailMarkerSize` | `fovSliderValue` | N 类投影/视场设置 |
| 23 | `compactObjectPeekX` | `skyWidth` `cardOffsetX` | 画布宽 + F 类卡片拖拽量 |
| 24 | `compactObjectPeekY` | `cardOffsetY` `skyHeight` | F 类卡片拖拽量 |
| 25 | `hoverBottomCardY` | 折叠机制 + `skyHeight` + 布局 + `cardOffsetY` | 折叠 + F 类 |
| 26 | `isHalfFoldedStatus` | `foldStatusValue` | 折叠机制 |
| 27 | `polarScopeControlWidth` | `skyWidth` | 画布宽 |
| 28 | `polarScopeFooterHeight` | `isExpandedLayout` | 布局分发 |
| 29 | `viewCoordinateOverlayWidth` | `isExpandedLayout` `skyWidth` | 布局 + 画布宽 |
| 30 | `locationMapHeight` | `isExpandedLayout` | 布局分发 |
| 31 | `compactTopQuickX` | `skyWidth` | 画布宽 |
| 32 | `detailCardWidth` | `isExpandedLayout` `isFoldHoverLayout` `skyWidth` | 布局分发 |
| 33 | `detailCardHeight` | 布局分发 + `skyHeight` + 折叠机制 | 布局 + 折叠 |
| 34 | `clampedObjectCardOffsetX` | `cardOffsetX` `skyWidth` | F 类卡片拖拽量 |
| 35 | `clampedObjectCardOffsetY` | `cardOffsetY` `skyHeight` | F 类卡片拖拽量 |
| 36 | `tabletInspectorWidth` | `skyWidth` | 画布宽 |
| 37 | `baseHoverBottomCardY` | 折叠机制 + `skyHeight` + 布局 | 布局 + 折叠 |
| 38 | `hoverConsoleTop` | 折叠机制 + `skyHeight` | 折叠 + 画布高 |
| 39 | `hoverPanelTop` | 折叠机制 + `skyHeight` + `isFoldHoverLayout` + `compactPanelSnapRatio` `compactPanelDragOffsetY` | 折叠 + D 类逐帧 |
| 40 | `chromeRowY` | `isExpandedLayout` `skyHeight` | 布局分发 |
| 41 | `chromeZoomHorizontal` | `isExpandedLayout` | 布局分发 |
| 42 | `compactDockLabelFontSize` | `isFoldHoverLayout` | 布局分发 |
| 43 | `compactDockIconSize` | `isFoldHoverLayout` | 布局分发 |
| 44 | `compactDockItemHeight` | `isFoldHoverLayout` | 布局分发 |
| 45 | `compactPanelHorizontalPadding` | `isFoldHoverLayout` | 布局分发 |
| 46 | `dockTop` | `isExpandedLayout` `skyHeight` | 布局分发 |
| 47 | `objectInspectorInlineModelSize` | `isExpandedLayout` `isFoldHoverLayout` `skyWidth` | 布局分发 |
| 48 | `phoneChromeOpacity` | `isExpandedLayout` `isFoldHoverLayout` `panelIdleOpacity` | 布局 + D 类空闲淡出瞬态 |
| 49 | `phoneChromeIsGlass` | `isExpandedLayout` `isFoldHoverLayout` `panelIdleGlass` | 布局 + D 类空闲淡出瞬态 |
| 50 | `dockTop` | `isExpandedLayout` `skyHeight` | 布局分发 + 画布高（A2-4 补登记） |
| 51 | `guideCardWidth` | `skyWidth` | 画布宽（A2-4 补登记） |

> **与 §14.3.1 A2-4/A2-6 目标表的关系**：A2-4/A2-6 示例中的 `bottomCardWidth` `objectActionBarY`（读 `EDGE_MARGIN`，非本组）
> `locationMapWidth` `responsiveFoldAngle` `compactPanelUsableHeight` `expandedUiAllowed` `isCompactMorePoint` `dragFollowAlpha`
> `clampedViewCoordinateOffset*` `objectDetailMarkerSize` `compactQuickIdAt` 等**同时命中本组判据**，续作按"本组永久保留、
> A2-4/A2-6 只处理**非**保留读取项（读 `EDGE_MARGIN` / `screenSafeTopPixels` / `getUIContext` 者）"的口径收敛。

### 2.8 运行时控制流：四个引擎驱动整个文件

**① 启动链（一次性瀑布）**
```
aboutToAppear → 取 createInfo → 隐私门控（@StorageLink watch）
  → 放行 → qohos NODE XComponent onAttach（Qt 引擎挂载）
  → restoreStartupSettings + 串行引导查询瀑布：
     getSkyCultures / getScriptList / getProjectionList / getConfigString…
     （每个回包点亮一个域的初始数据，约 L1629–1688）
```

**② 轮询引擎（19 个 `setInterval`，按面板可见性挂摘）** —— 频率分层刻意隔离：
180ms 选中对象详情、1s Dock 时钟 / 时间面板轻量、3s 时间面板全量兜底、
天体媒体预热、skyTextureStatus（快轮 24 次 → 慢轮 2s → 停滞升级重试）。
**纪律**：`openPanel` 挂、`closePanel`/后台/`aboutToDisappear` 摘（防耗电与定时器叠加）。

**③ 触摸/手势流（高频连续）**
```
handleOverlayTouch → isUiPoint(84) 命中路由
  ├─ 星图：handleSkyTouch(282，最大处理器)
  │    拖动：滤波+速度采样 → callNativeFire('dragView')
  │    捏合：FOV 节流提示 → setFieldOfView
  │    点按：requestInteractive('selectAt') → applySelectedObject(230)
  └─ UI：handleUiTap(95) 分发面板动作
```
惯性滚动刻意放在 **Qt 渲染循环**里跑，ArkTS 只传释放速度——避免跨界拖动命令风暴。

**④ 推送流（C++ → ArkTS，两条通道）**
`@StorageLink('stellariumCliUiEvent')` → `onCliUiEventChanged`(266，语义 CLI 路由器)；
4 个 sensor 回调 → `onOrientationData`/`onRotationVectorDirect` → 陀螺仪数学 → `callNativeFire('panBy')`。

### 2.9 横向解剖：领域地图（L4 的内部结构）

约 15 个领域簇，每簇在宿主内重复同一套 **"七件套解剖"**：

```
① 字段：@State store 实例 或 @State 标量簇 + 基础设施字段
        （请求序号 requestId/mutationId + pending 标志 + 定时器句柄）
② load*()     — 经桥拉数据、解析回包、写状态
③ apply*()    — 把回包摊铺到 store/@State（applySelectedObject 230 行）
④ handle*()   — 面板动作回调（被下沉组件注入，如 handleChip 118 行）
⑤ refresh*()  — 定时器/事件驱动的状态重算
⑥ publish*()  — 状态回发 CLI（AppStorage.setOrCreate）
⑦ 定时器挂摘  — 面板开合/前后台生命周期接线
```

| 领域簇 | 状态归属 | 宿主残留代表方法（实测行数） |
|---|---|---|
| **对象详情/检查器** | ObjectDetailStore + ObjectMediaStore | `applySelectedObject`(230)、`refreshObjectInspectorMedia`(175)、指向线(138)、**模型渲染簇**（render/decode/touch ≈500，逐帧字段刻意不入 store） |
| **触摸/视图交互** | 留宿主 | `handleSkyTouch`(282)、`handleUiTap`(95)、`isUiPoint`(84)、拖动滤波/惯性 |
| **媒体解码管线** | 留宿主（共享子系统） | `decodeLocalImage`(70)、PNG→纹理、`BODY_DETAIL_TEXTURE_PATHS` 预热 |
| **壳层/面板路由** | DockStore | `setPanel`(96)、`closePanel`(47)、`panelTitle`(101)、`schedulePanelDataLoad`(88)、`updateResponsiveLayout`(67) |
| **天文计算** | AstroStore + WutStore | `updateAstroCalcSnapshot`、`hecLayoutPositions`、`currentAstroCsvExport`(76) |
| **传感器/陀螺仪** | GyroStore | `startGyroscope`(121)、`stopGyroscope`(56)、4 个回调、`updateGyroTargetGuide`(109) |
| **脚本/导览/录制** | ToolsStore（部分） | `executeGuideRequest`(63)、`playScriptByName`(44)、录制/回放/录屏引擎、`guideState` |
| **时间** | **6 个 store + Controller**（拆得最彻底） | 仅剩时间轮转发与 JD 输入处理 |
| **搜索** | SearchStore | `searchObject`(70)、分类分页 `loadMoreCategoryObjects`(51) |
| **星空文化** | 3 个 store | `loadSkyCultureDetails`(69)、美术资源管线(71) |
| **卫星** | **SatelliteStore**（原 25+ 字段已下沉） | `loadSatellites`(55)、`publishSatellitePanelState` |
| **望远镜/目镜** | TelescopeStore | `loadOculars`(75)、lx200 goto/sync/abort + 实时位置定时器 |
| **位置** | LocationStore + LocationPickerStore | `setLocation`(47)、`useDeviceLocation`(43)、增量扫描(74) |
| **CLI 入口** | — | `onCliUiEventChanged`(266) + `publish*` 系列 |
| **设置/杂项面板** | 各自 store（NavStars/Archaeo/Mosaic/Catalog/Meteor/Scenery…） | 对应 loader（多数已转 B1/B2，见 §2.13） |

### 2.10 横切机制与阅读导航

**四个惯用法（不理解就读不懂这个文件）：**

1. **请求序号防过期**：每个异步域都有 `xxxRequestSequence`/`xxxMutationId`，回包到达时比对序号、
   丢弃过期响应（快速切面板/连点时的正确性根基）。
2. **`callNativeWhenReady` 重试**：启动期 Qt 未就绪时桥返回 `ok:false`，
   按 200ms×60 退避重试而不是崩溃。
3. **`@Prop` 快照 + 回调回注**：所有下沉组件的统一接口（`nm*()` 夜视色也按此传入）；
   组件自身不改宿主状态，单向数据流。
4. **逐帧字段隔离**：模型渲染像素/指向线几何由渲染管线**逐帧写入**，绝不进 `@Observed` store
   （否则重渲染风暴），只以 `@Prop` 快照进组件。

**阅读导航（按目的找入口）：**

| 想理解什么 | 去哪里 |
|---|---|
| 页面长什么样 | `build()` L14291 + 三壳组件 + `panelContent()` L17181 |
| 面板怎么开合/路由 | `setPanel`(L2299)、`closePanel`(L2567)、返回栈 `handlePanelBackTap` |
| 某个域怎么工作 | 字段区找它的字段簇 → `load*` → `apply*` → `handle*` → `publish*` |
| 状态在哪 | 字段区 L201–1287（宿主部分）+ `state/*Store.ets`（已下沉部分） |
| 引擎怎么被调 | `bridge/BridgeClient.ets`（唯一出口）+ 宿主 4 个薄委托 L2603–2698 |
| 刷新为何发生/不发生 | 先查该域是 Store 风格（`@ObjectLink` 实时）还是 Prop 风格（依赖宿主 `@State` 重渲染） |

### 2.11 术语：host 端口对象（port object）与动作的三类归属

**定义。** "端口对象" = 把一个组件需要从宿主得到的**一整套回调/能力**，用一个**具名接口**描述，
再作为**一个成员**传入；调用点只写一个 `host: { … }`，而非几十上百个并列参数。
术语来自"端口-适配器/六边形架构"：**端口**是组件声明"我需要什么"的接口，**适配器**是宿主提供的实现。

本工程存在两种写法：

**写法 A：扁平回调（多数面板）**——每个回调是独立成员/参数：
```ts
// SatellitesPanel.ets
@Prop satOffline: boolean
onPublishState: () => void = () => {}
onDeleteSource: (index: number) => void = () => {}
onRefreshCatalog: () => void = () => {}   // …约 18 个 onX
// 调用点：SatellitesPanel({ satOffline: …, onPublishState: …, onDeleteSource: … }) 全部平铺
```

**写法 B：单一 host 端口对象（全项目唯一，`AstroPanel`）**：
```ts
// AstroPanel.ets:23 —— 端口：声明"我需要这 114 个能力"
export interface AstroPanelHost { jumpToWutTarget: (t: WutTarget) => void; loadRTS: () => void; /* …114 */ }
// AstroPanel.ets:270 —— 单个成员 + 默认实现
host: AstroPanelHost = noopAstroPanelHost()
// 调用点 MainWindowNativeNode.ets:17771 —— 适配器：一个 host 参数包住全部实现
AstroPanel({ store: …, wutStore: …, host: { jumpToWutTarget: (t) => this.jumpToWutTarget(t), /* …114 */ } })
```

**好处**：签名收窄（1 项 vs N 项）、契约具名（编译器校验遗漏/拼错）、可给默认实现（`noopAstroPanelHost()`，
宿主不传也能渲染/单测）、来源清晰（`this.host.loadRTS()`）、便于换实现。
**必须澄清**：端口对象**不是**性能优化——它不减少回调数、也不减少重渲染，只是**打包形态**；
真正减少重渲染的是 §7.3 的属性级刷新，端口对象主要改善 §7.4 的可维护性。

**动作/回调的三类归属**（以 `AstroPanelHost` 114 键为样本）：

| 类别 | 成分 | 归属判断 | 去向 |
|---|---|---|---|
| **A 纯派生/格式化** | ~44（`altAzMaxLabel`/`fmtClock`/`hecPointLeft`…） | **不该在宿主**——纯函数、零副作用 | 搬进组件 / `@Computed` |
| **B 域内加载器** | 20 个 `load*` | **可下沉**——只做"桥调用→写域 store" | 给 store 注入桥端口即可迁入域 model |
| **C 跨域动作/桥/路由** | ~17 `jump*` + `callNative` + `open*Picker` | **原则性留宿主** | 保留，或提升为共享 `SelectionService` |

**C 类为何必须留宿主——以 `jumpToWutTarget` 为例（`MainWindowNativeNode.ets:6656`）：**
```ts
private jumpToWutTarget(target: WutTarget): void {
  this.callInteractive('setJD', …)          // ① 时间域
  → this.callInteractive('searchObject', …) // ② 搜索/选中
  → this.applySelectedObject(…, 'center')   // ③ 对象详情+居中的全应用唯一管线
}
```
它**不是"WUT 面板的操作"，而是全应用选中/居中管线的一个入口**——一次调用横跨 **时间 → 搜索 → 对象详情**
三个域，终点 `applySelectedObject`（230 行）被全局搜索/星图点选/书签/WUT/RTS 共同复用。
任何单一面板都不拥有这条管线，故它必须住在所有入口的共同祖先——宿主。
这也是"+4 条 host-only 依赖（桥接收口/面板路由/定时器生命周期/CLI 回发）"的体现。
**根因**见 §2.5/§7.4：重构搬走的是"状态所有权 + 视图树"，不是"控制器"；V1 无 Composition 函数，
`@Builder` 按值捕获又锁死状态，于是动作执行器只能留在宿主。

### 2.12 A 类（纯派生方法）普查：宿主内共 305 个

**判据**：`private` 方法，且满足全部——非 `void`/非 `Promise` 返回、名字非动作动词
（load/apply/handle/…）、无成员写（`this.x=`/`this.store.x=`）、无 IO（fileIo/image/picker/media）、
无桥（`callNative*`/`callInteractive`）、无路由（`openPanel`/`closePanel`/`setPanel`/`activePanel`）、
无定时器、无 `AppStorage`/`localStorage`、无 `hilog`。命令见附录。

**结果（实测，宿主 940 个 private 方法）：**

| 类别 | 数量 |
|---|---:|
| 几何/尺寸（`*Width/Height/Top/Left/Size/*Bar*`） | 112 |
| 其他派生（查找表/几何数学/动作数组构造） | 88 |
| 标签/文案/命名（`*Label/*Text/*Name/*Zh/*Of`） | 64 |
| 判断/索引（`is*/has*/*Index/*Count/*Bit`） | 34 |
| 颜色（`*Color/*Tint/*Opacity`） | 5 |
| 格式化（`fmt*`/`*Rate`） | 2 |
| **合计** | **305 ≈ 宿主 private 方法的 1/3** |

**按"是否读取宿主状态字段"再分：**

| 子类 | 数量 | 含义 | 处理 |
|---|---:|---|---|
| **A1 零宿主状态读取** | **91** | 只依赖入参/静态/纯计算 | **可直接移出**（甚至不经 V2）；宿主端口随之减 91 |
| **A2 读取宿主字段** | **214** | 派生自宿主 `@State`（几何/布局/文案） | 需该状态在组件侧可用（传参或 V2 模型） |

**端口暴露**：305 个中 **218 个**已在宿主 UI 装配区（`build()`+`panelContent()`）以 `this.<name>` 形式
被引用（即作为端口/参数传给组件）；其余 87 个目前仅在宿主内部链式调用。

**A1 全清单（91 个，零宿主依赖，可直接下沉）：**
```
scriptZh, timezoneDisplayName, pluginZh, scriptDesc, pluginFeatureRoute, informationMaskBit,
getCityPreset, pluginDesc, formatRate, astroTabItemsForGroup, catalogIconForModule,
catalogIconForObjectType, wutCategoryOptions, pluginHostName, planetZh, gyroRotateAboutAxis,
planetPairBodyName, planetMetricLabel, phenomenonCaption, hecPointSize, parseObservingList,
telescopeErrorText, observingHubActions, dateToJD, validationFromResponse, moreActions,
skyDataHubActions, isSafeSkyCultureArtPath, isCliPanelName, zhNameOf, hourOffsetLabel, fmtDegMin,
sensZh, primaryDockActions, gyroMultiplyQuaternions, gyroFilterDeviceVector,
rtsCalendarDurationLabel, isRecordable, graphModeLabel, planetMetricUnit, sessionSignature,
jdToLocalTimeText, gyroCross, automationHubActions, wutDirectionLabel, astroGroupItems,
gyroRotateAboutVertical, telescopeUpdateTime, messierNumberOf, normalizeLocationSearchText,
gyroScreenAxisForDisplay, hecPlanetOrbitRadius, shortestGyroAzimuthDelta, configDitheringLabel,
officialLocationAliases, distance, wrapGyroAzimuth, describeDecodeError, gyroNormalizeVector,
astroGroupForTab, gyroNormalizeQuaternion, planetPairLinearLabel, graphStartOptionLabel, csvCell,
pointOverlapsUiObstacle, azBarHeight, minorPlanetNumberOf, wutCategoryKey, useTabletObjectInspector,
cleanSkyCultureDescription, useExpandedDetailSummary, expandedDetailSummaryHeight, isPhoneDetailPeek,
hecDistanceLabel, cleanSkyCultureNarration, resourceText, baseCompactObjectPeekY, hecPointAngle,
compactTopQuickY, gyroDot, planetTimeSeriesBarHeight, clamp, lunarElongationBarHeight,
pointInsideRect, zhType, touchScreenY, planetPairBarHeight, gyroConjugateQuaternion, touchWindowX,
touchWindowY, touchScreenX
```

**A2 行数最大的 25 个（读取宿主字段，需数据配套）：**
`isUiPoint`(84) / `objectInspectorPlanetTexturePath`(28) / `gyroMagneticHeadingFromDeviceVectors`(25) /
`archaeoLineSettingValue`(21) / `objectInspectorDeepSkyImageName`(21) / `currentSkyCultureMakerDraft`(21) /
`searchCategoryOptions`(18) / `objectInspectorFallbackVisualKind`(17) / `inferredPanelRouteDirection`(16) /
`expandedSafeTargetPoint`(16) / `locationSearchMatchScore`(14) / `pluginFeatureDestination`(14) /
`dockActionAt`(14) / `objectInspectorPlanetRingSpec`(14) / `hecPointColor`(13) / `objectInspectorMediaWarmupText`(11) /
`gyroOrthonormalizeUp`(10) / `objectDistanceNoticeText`(10) / `skyZoomButtonAt`(9) / `objectInspectorStarColor`(9) /
`categoryModuleIdFor`(9) / `canonicalDockActions`(9) / `compactQuickIdAt`(9) / `searchCategoryIcon`(9) / `searchCategoryLabel`(9)

**结论与建议：**
1. **A1 的 91 个是零风险的第一步**——它们是纯函数，搬到消费它们的组件（或提为独立纯函数模块）
   即可减少宿主 91 个方法与对应端口项，**不需要 V2、不需要注入**。建议作为独立"低风险瘦身"切片先做。
2. **A2 的 214 个**是 §7.5 Phase A/C 的标的：几何/布局类随其渲染组件下沉（组件本就持有 `skyWidth`、
   `bottomCardIndex` 等所需数据）；文案/命名类随域 store 下沉。
3. A/B/C 合计说明：宿主 940 个 private 方法里，**约 1/3 是"本可归组件"的派生逻辑**，
   这是"宿主继续瘦身"最明确、最有据的空间（强于 §5 的定性描述）。

### 2.13 B 类（域内加载器）可下沉端口清单：70 个 `load*` 的 V1 可沉性（2026-10-04 复测）

**B 类** = 域内加载器（`load*`）：只做"桥调用 → 解析回包 → 写本域状态"。
**V1 下沉机制**（计划 §13.1 规则 6 明确授权："跨域/桥/定时器依赖用注入解决，不硬搬"；
先例 `TimeWheelController` 的 `onSeek`/`onStopSpeed`/`getUtcOffsetHours`）：
把桥剥离为一个**注入的 `CommandPort` 接口**，store 只依赖接口、不 import NAPI/UI，宿主在 `aboutToAppear` 里实现它。

**判据（按依赖足迹）：**

| 足迹 | 判定 |
|---|---|
| 仅桥 + 本域 store | **B1 直接沉** |
| ＋本域助手 / 他域 store 引用 / CLI `publish*` | **B2 注入依赖** |
| ＋写宿主 `@State` 字段 / 面板路由 / 定时器 | **B3 暂留**（多为写"刻意保留"的裸字段） |

**总账（实测 70 个 `private load*`，2026-10-04 §2.7 域状态下沉后复测）：**

| 判定 | 数量 | 含义 |
|---|---:|---|
| **B1 直接沉** | **24** | 域 store 已存在，只需注入 `CommandPort` 即可搬 |
| **B2 注入依赖** | **35** | 需一并注入本域助手/他域引用/publish 回调 |
| **B3 暂留** | **11** | 加载器写 §2.7.1 保留的裸宿主字段（请求序号/跨域共用/逐帧）→ 需拆分或注入该字段 |

> **变化（vs 上一版 69 = 13/30/26）**：§2.7 把 Prop 风格域的状态抽成 store 后，
> 原 B3 的 15 个加载器（卫星/考古线/导航星/拼贴/流星/星表/插件/命令台/星云…）已转为 B1/B2；
> 余下 11 个 B3 只因仍写**刻意保留**的裸宿主字段（§2.7.1）。

#### B1 直接沉（24 个，无前置，最先做）

| 方法 | 行 | 目标 store | 方法 | 行 | 目标 store |
|---|---:|---|---|---:|---|
| `loadOculars` | 75 | TelescopeStore | `loadCommandCatalog` | 28 | CommandStore |
| `loadPluginList` | 34 | PluginStore | `loadConstellationNavigation` | 27 | SearchStore |
| `loadMeteorShowers` | 33 | MeteorStore | `loadMosaicCamera` | 24 | MosaicStore |
| `loadNavStars` | 31 | NavStarsStore | `loadPointerCoordinates` | 23 | OverlayStore |
| `loadArchaeoLines` | 30 | ArchaeoStore | `loadSavedLocations` | 20 | LocationStore |
| `loadEquationOfTime` | 19 | EquationOfTimeStore | `loadObjectInfo` | 18 | ObjectDetailStore |
| `loadStarCatalogs` | 18 | CatalogStore | `loadNebulaTextureStatus` | 15 | NebulaTextureStore |
| `loadTrailDisplaySettings` | 13 | LayerViewStore | `loadLandscapeList` | 12 | LayerViewStore |
| `loadOrbitDisplaySettings` | 12 | LayerViewStore | `loadAngleMeasure` | 11 | ToolsStore |
| `loadPlanetList` | 11 | SessionToolStore | `loadSatelliteSources` | 10 | SatelliteStore |
| `loadAboutInfo` | 9 | ToolsStore | `loadSkyCultureConstellationSelectionFlags` | 8 | SkyCultureSettingsStore |
| `loadLog` | 7 | ToolsStore | `loadRecordings` | 6 | ScriptStore |

#### B2 注入依赖（35 个，按簇）

**Astro 簇（19 个）**——共同依赖 `AstroStore`/`WutStore` + Astro 域助手
（`updateAstroCalcSnapshot` / `beginGraphLoad` / `finishGraphLoad` / `resolveGraphStartJD` /
`clearRtsSelectionResults` / `hasSelectedObject` / `hecLayoutPositions` / `wutCategoryTitle` /
`planetPairBodyName` / `updatePlanetPairDistanceRanges` / `updatePlanetTimeSeriesRanges` /
`publishAstroPanelState`）→ **整簇同片搬**：
`loadAlmanac` `loadAltAzCurve` `loadAnnualElevation` `loadAstroTab` `loadCelestialPositions` `loadEclipses`
`loadEphemeris` `loadHeliocentricPositions` `loadLunarElongation` `loadObservabilityCalendar` `loadPhenomena`
`loadPlanetaryTransits` `loadPlanetCalc` `loadPlanetPairDistance` `loadPlanetTimeSeries` `loadRTS`
`loadRtsCalendar` `loadTonightAstro` `loadWutTargets`

**其余（16 个）：**

| 方法 | 行 | 目标 store | 额外注入 |
|---|---:|---|---|
| `loadObjectInspectorModelRawTexture` | 72 | （媒体管线） | `commit/fail/decode` 媒体助手 |
| `loadConfigurationSettings` | 49 | Ephemeris+InfoWindow+Navigation+TimeSettings+ViewSettings（5 store） | `applySelectedInfoMode`、`applyTimeSettings` |
| `loadSkyCultureList` | 42 | SkyCultureViewStore | `loadSkyCultureDetails` |
| `loadSkyCultureVisualSettings` | 40 | SkyCultureSettingsStore | `skyCultureActiveColorTarget` |
| `loadObjectCatalogCategories` | 32 | CatalogStore + SearchStore | `catalogIconForModule`、`loadCategoryObjects`、`publishSearchBrowserState` |
| `loadSkyCultureTerritoryMap` | 21 | SkyCultureSettingsStore | `drawSkyCultureTerritoryMap` |
| `loadSkyCultureMakerDraft` | 21 | SkyCultureMakerStore | `applySkyCultureMakerDraft`、`ensurePluginLoaded`、`skyCultureMakerDraftFromResponse` |
| `loadObservingListFromStorage` | 19 | ObservingListStore | `getUIContext`、`parseObservingList` |
| `loadObserverInfo` | 17 | LocationPicker + SessionTool + SkyCultureSettings（3 store） | 时区助手 |
| `loadBookmarks` | 15 | BookmarkStore | `saveBookmarksToStorage` |
| `loadTelescopeControlStatus` | 13 | TelescopeStore | `lx200Payload`、`scheduleTelescopeLivePosition`（**含定时器 → store 需自持 start/stop**） |
| `loadBookmarksFromStorage` | 13 | BookmarkStore | `getUIContext` |
| `loadRecordingByName` | 11 | （录制域） | `flashHint` |
| `loadTimeExtras` | 9 | TimeStore | `applyAtmosphereResponse`、`syncNightModeFromEngine` |
| `loadScriptList` | 8 | ScriptStore | `setScriptMetadata` |
| `loadSelectedSatellitePasses` | 5 | ObjectDetailStore | `requestSatellitePasses`、`selectedObjectIsArtificialSatellite` |

#### B3 暂留（11 个）——仍写 §2.7.1 保留的裸宿主字段

| 加载器 | 行 | 目标 store | 仍写的保留裸字段 |
|---|---:|---|---|
| `loadSkyCultureDetails` | 69 | SkyCultureView + Settings | `skyCultureArtStates`（渐进写入） |
| `loadSatellites` | 55 | SatelliteStore | `satelliteListElapsedMs` / `satelliteLoadTimer`（计时器） |
| `loadMoreCategoryObjects` | 51 | SearchStore | `categoryOffset`（跨页游标） |
| `loadCategoryObjects` | 35 | SearchStore | `categoryOffset`、`satelliteCatalogReady` |
| `loadMoonPhases` | 35 | AstroStore | `moonPhaseLoadingDays`（请求进度） |
| `loadAstroCalcContext` | 35 | AstroStore | `astroContextRequestPending`（进行中标志） |
| `loadPolarScopeData` | 19 | PolarScopeStore | `polarScopeRequestPending`（进行中标志） |
| `loadVideoRecordingState` | 14 | ScriptStore | `stopVideoStatePolling`（定时器收口） |
| `loadSearchHistoryFromStorage` | 13 | （搜索历史） | `searchHistory`（跨域共用） |
| `loadScenery3d` | 12 | SceneryStore | `scenery3dCurrentId`（引擎自用，已登记约定） |
| `loadCatalogHealth` | 9 | CatalogStore + SatelliteStore | `catalogHealthLoaded` / `catalogManifestPresent`（跨域共用） |

> B3 只剩"加载器要写某个**刻意保留**的宿主裸字段"这一类：把该字段一并处理（搬入 store 或注入端口）
> 即可降为 B1/B2。**已不再是"域状态还没建 store"**——§2.7 已把该前置条件清空。

#### V1 机制（enabler，简短）

```ts
// bridge/CommandPort.ets —— 纯接口，无 libentry.so import
export interface CommandPort {
  request(name: string, payload?: string): StellariumBridgeResponse
  requestInteractive(name: string, payload: string, onOk: (r) => void, onFailure?: (r) => void): void
  requestLongRunning(name: string, payload: string, onOk, onFailure, onProgress, intervalMs: number, cancelled: () => boolean): void
  fire(name: string, payload?: string): void
}
// store：private port + private seq（原宿主请求序号搬入）+ onChanged（原 publish 注入）
// 宿主 aboutToAppear：this.<store>.attachPort({ request: (n,p) => this.callNative(n,p), … }, () => this.publishXxx())
```
刷新语义不变（同一 `@Observed` 实例仍由宿主 `@State` 持有、组件 `@ObjectLink` 消费）；
store 仍不碰 NAPI（只依赖接口，可用假 port 单测）。

#### 分阶段建议

1. **B1 的 24 个**——无前置，最先（`loadOculars` 75 行收益最大）。
2. **B2 Astro 簇（19）**——一域一片；Astro 助手多为域内逻辑，同片搬。
3. **B2 其余（16）**——逐域。
4. **B3 的 11 个**——处理其保留裸字段（搬入 store 或注入端口）后降为 B1/B2。

---

## 3. 已拆分逻辑与拆分方式分析

### 3.1 目录总账（实测行数）

| 目录 | 文件数 | 行数 | 内容 |
|---|---:|---:|---|
| `state/` | **48** | **3,075** | `@Observed` store 集合（宿主持有 46 个实例）+ `TimeWheelController`（普通类） |
| `panels/panels/` | 25 | 3,830 | **一面板一组件**（`panelContent` 分支的落地件，59–548 行/文件） |
| `panels/shell/` | 13 | 1,707 | 六壳 + Dock/PanelHeader/把手等壳件 |
| `panels/<domain>/**` | 81 | 11,225 | 领域子组件（astro/object/search/time/layers/skyculture/telescope/tools/overlay/view/location/satellite/sensors/settings/guide/common） |
| `bridge/` | 1 | 51 | `BridgeClient`（`libentry.so` 唯一出口） |
| `common/` + `common/ui/` | 10 | 263 | UiTokens / ShellIcons / InfoRow / SettingsChoiceButton 等通用件 |

**store 粒度分布**（合理性）：`SkyCultureSettingsStore` 528 行 / `LocationPickerStore` 445 行 /
`TimeWheelController` 225 行 到 `DeltaTStore` 8 行 / `BookmarkStore` 9 行 —— 粒度不均但
**与领域复杂度正相关**，未见"为拆而拆"的空壳 store。

### 3.2 拆分方式：六条已固化的模式（均经真机验证，见计划 §13.1）

| # | 模式 | 典型落地 | 评价 |
|---|---|---|---|
| 1 | **store + 读取方 UI 同片搬迁** | `TimeStore`+`TimePanel`、`LayerStore`(94 字段)+103 个 switchRow 调用点改写 | 正确执行了修订 1 的结论（只搬 store 会丢刷新）；每片可独立回归 |
| 2 | **注入式拆分**（跨域/桥/定时器依赖不硬搬） | `TimeWheelController`：`onSeek(jd)`/`onStopSpeed()`/`getUtcOffsetHours()` 三注入点，控制器不碰 NAPI | 边界干净；store 保持"纯数据+纯计算"可测 |
| 3 | **逐帧字段不进被观察 store** | `objectInspectorModelRendering`、`objectDetailConnector*`(9 字段) 以 `@Prop` 快照传入 | 性能护栏；避免每帧重渲染风暴（计划 §13.5 第 3 行明确此定论） |
| 4 | **参数化 `@Builder` 全部消灭** | `switchRow`/`speedChip`/`guideButton` 等 → 子组件或内联读 store | 修复了既有的"首帧冻结"bug 族（修订 4）；当前宿主仅剩 3 个无参 `@Builder` |
| 5 | **搬迁前先清死代码**（四类判据零引用扫描） | 三轮清理 54 方法 + 13 builder + 39 字段（−1,274 行），级联复扫至收敛 | 防止死代码进入新结构；`git log -S` 考古确认多为历史迭代残骸 |
| 6 | **高频链隔离** | Dock 时钟 1s 定时器独立于时间面板 125ms 链；`recordCount`/录制引擎字段留宿主 | 对应原 L16156 的全局重排告警；刷新范围=订阅者 |

### 3.3 拆分顺序的实际路径（与计划的偏离与修正）

计划原定 Phase 3（store）→ Phase 4（面板）分离推进；实际执行为 **3/4 交织的切片队列**
（3a→3av、4a→4l、5、6a→6d、7），每片"量化→建 store→建组件→单体手术→五步验收→提交"。
这个偏离是**被修订 1/修订 4 逼出来的正确选择**：V1 下单独搬 store 必然丢刷新，
必须与组件同片。执行记录完整可追溯（计划 §13.5 表 1–12 逐片记载提交哈希与行数变化）。

---

## 4. 路径与结构合理性评估

### 4.1 与计划 §3 蓝图的偏差清单

| # | 计划蓝图 | 实际落地 | 评价 |
|---|---|---|---|
| 1 | `window/shell/`、`window/overlay/`（窗口域独立目录） | `panels/shell/`、`panels/overlay/` | **可接受**。壳层/叠层与面板同属 `panels/` 弱化了"跨面板常驻 vs 一次一个"的语义边界，但避免了一个只有十余文件的新顶层目录；根 `AGENTS.md` 已固化此约定，成本是一次性认知 |
| 2 | `panels/PanelHost.ets` 表驱动 + 懒加载 | `panelContent()` 保留 if/else（1,046 行），每分支已是组件 | **部分未达**，见 4.2-3 |
| 3 | `state/` 13 个 store（Time/Panel/Search/Astro/SkyView/Object/SkyCulture/Satellite/Sensor/Script/Telescope/Session/Tool） | **48 文件 / 47 store**，粒度更细（Gyro/SessionTool/Dock/ObjectMedia/Overlay/LocationPicker/LayerView/Satellite/Archaeo/NavStars/Mosaic/Meteor/Catalog/Plugin/Command/Scenery…） | **优于蓝图**。细粒度匹配"刷新范围=订阅者"的性能论据（如 `DockStore` 12 行让 Dock 高亮不再冻结）；代价是 import 区变长，但可接受 |
| 4 | `panels/<domain>/` 平级领域目录 | 出现 `panels/panels/` 双层目录（Phase 4 面板级组件） | **命名笨拙但语义自洽**：`panels/panels/XxxPanel.ets` = 面板分支本体，`panels/<domain>/` = 面板内/跨面板的领域子组件。见 4.2-1 |
| 5 | `panels/common/HierColumn.ets` 等通用件 | 实际在 `panels/common/`（1 个）+ `common/ui/`（7 个） | 轻微分裂：通用件在两处。见 4.2-4 |
| 6 | `bridge/BridgeClient.ets` + 后续 `time.ts/astro.ts` 按域类型化方法 | 仅 `BridgeClient`（51 行，request/send/requestWhenReady/requestInteractive） | 按域类型化未做，但宿主 195 个调用点已全部经薄委托走唯一出口，契约（payload 不变）达成；后续类型化属可选优化 |

### 4.2 逐项分析

**1. `panels/panels/` 双层目录 —— 可用，不建议现在改名。**
起源是 Phase 4a 抽取 `panelContent` 分支时需要与既有 `panels/<domain>/` 区分。
当前 25 个文件全部是 `XxxPanel` 命名，语义"一个 activePanel 取值一个组件"，与契约脚本
的 33 面板清单可直接对照。改名收益（少一层语义噪音）小于成本（156 处 import 改写 +
测试脚本文本切片风险，规则 8 已证明脚本会成片失败）。**建议保持，仅在 AGENTS.md
（已做）与本文固化语义。**

**2. `state/` 粒度 —— 合理，一处命名不一致。**
`TimeWheelController` 是普通类（草稿字段+定时器+注入点），不是 `@Observed` store，
但住在 `state/` 目录。这是**正确的物理位置**（它就是状态机），但目录名暗示"全是 store"。
`DockStore`(12 行)/`BookmarkStore`(9 行) 等小文件不是碎片化——它们各自对应一个独立的
刷新订阅域（Dock 高亮冻结 bug 的修复件）。**不建议动。**

**3. `panelContent` 未表驱动 + 未懒加载 —— 唯一实质性的"未完成目标"，风险中低。**
- 现状：1,046 行 if/else，33 分支每支是"store 引用 + @Prop + 回调"的组件装配。
- 未拿到懒加载收益：119 个组件文件全部在 import 区静态引入（L37–L161），
  面板未打开时模块也已加载。但 ArkUI V1 编译模型下这主要是启动期模块解析成本，
  实测启动链正常（`test-ohos-startup-stars.mjs` 17/17）。
- 未做表驱动的现实原因：分支入参高度异构（object 分支 25 @Prop + 17 回调 vs
  hub 分支 4 参数），统一签名需要引入参数装箱层，复杂度反超收益。
- 残余风险：新增面板仍要在 if/else 链尾加分支，且装配参数（如 `this.nmText()` 系列
  颜色快照）逐分支手写。**建议**：面板数若继续增长（>40）再评估表驱动；
  当前维持现状是合理取舍。

**4. 通用件分裂两处（`common/ui/` 与 `panels/common/`）—— 微瑕。**
`common/ui/`（UiTokens/ShellIcons/InfoRow/SettingsChoiceButton/SettingsSwitchRow/
NightModeToggleRow）是**跨面板通用**；`panels/common/HierColumn.ets` 是**位置/图层两域共用**
的领域件。按"通用度"分层的意图可辨，但边界薄（`InfoRow` 也被面板直接用）。
不影响正确性，**建议后续新文件统一进 `common/ui/`**，`panels/common/` 冻结不再增长。

**5. 壳层在 `panels/shell/` 而非 `window/shell/` —— 语义妥协，无功能代价。**
六壳（Compact/Expanded/HoverObservatory/Harmony/ScriptFocus/InteractiveGuide）+
Dock/PanelHeader 等 13 件已全部组件化，`build()` 内只保留"三选一分发 + 面板包裹"
（规则 9 约束 `this.panelContent()` 必须留在宿主）。叠层（Phase 5）在 `panels/overlay/`，
zIndex/HitTestMode 契约由 `specs/UI-ARCHITECTURE.md` §3/§6 锚定。**结构健康。**

**6. 宿主仍是 18,582 行 —— 数字未达"瘦身"直觉，但性质已变。**
- 940 个 private 方法中，大量是"组件回调实现 + 桥调用编排"，它们**必须**留在
  某个地方；ArkUI V1 无 Composition 函数，回调仓库归宿主是模式内代价。
- 132 个 @State 中 46 个是 store 实例（供 `@ObjectLink` 初始化的必要形态，规则 1），
  余 86 个是壳层/路由/逐帧快照——均已按 §2.7.1 登记为刻意保留（下沉需新的注入层）。
- **判断：宿主已到"组件化模式下的合理稳态"**。进一步减行需要翻 V2
  （计划 §8.2 已论证：拆分后可按模块逐个翻代，把大爆炸变成十几次小提交），
  属于后续独立决策，不在本队列。

### 4.3 质量护栏现状（实测确认）

| 护栏 | 状态 |
|---|---|
| `check-ohos-ui-contract.mjs`（33 面板 / 22 静态 id / 17 动态前缀 / 42 锚点） | **全绿**（本轮实测） |
| V1/V2 不混用 | 确认：0 个 `@ComponentV2`/`@ObservedV2`/`@Local`；`@ObjectLink`+`@Observed` 纯 V1 |
| `.id()` 锚点稳定 | 契约内 42 锚点未漂移（动态前缀 `panel-content-<lang>` 等在包裹 builder 中保留） |
| `libentry.so` 唯一出口 | 确认：宿主不 import `libentry.so`，仅 `bridge/BridgeClient.ets` L1 |
| `LocalStorage`（Qt 桥面）未动 | 确认：宿主仅 `getSharedLocalStorage()` 取 createInfo，未触碰 Qt 互操作 storage |
| 文档同步 | `UI-ARCHITECTURE.md` §2/§4.4/§6/§10 已改写为组件名+路径；根 `AGENTS.md` 已固化结构约定 |

---

## 5. 风险登记与建议

| # | 事项 | 性质 | 建议 |
|---|---|---|---|
| 1 | `panelContent` if/else 链 + 全量静态 import（无懒加载） | 中低 | 面板数 >40 或启动耗时劣化时再做表驱动/动态 import；当前不做 |
| 2 | 宿主回调仓库规模（AstroPanelHost 114 回调等） | 中 | 组件签名已达 V1 `@Prop`+回调的表达上限；若回调继续膨胀，优先考虑该域翻 V2（`@ObservedV2`+`@Trace` 消灭回调快照）而不是继续加参数 |
| 3 | `nm*()` 夜视色助手留宿主，每分支手动传色 | 低 | 计划 §13.5 已评估：让已持有 `nightModeStore` 的组件就地取色，属可选优化 |
| 4 | 已知死分支（`settings_quick_legacy` 无入口、`object` 分支 expanded 构型不可达、GyroCalibPanel 无 UI 入口） | 低 | 产品决策项：确认后走删除流程（四类判据 + 契约脚本同步），勿在重构提交里混做 |
| 5 | `OFFLINE_APPGALLERY_BUILD` 跳过 astro 面板前四段 | 中 | 需在非 appgallery 构建真机走查一次（计划终态遗留项 #4） |
| 6 | 35 个测试脚本中 7 个存量环境类失败（需设备/macOS 假设/路径 bug） | 低 | 与重构无关（基线即失败，Phase 3aq worktree 复核过）；按 §13.6 单独修 |
| 7 | `panels/common/` 与 `common/ui/` 双通用件目录 | 低 | 冻结前者，新通用件统一进 `common/ui/` |

---

## 6. 结论

1. **拆分方式正确且已闭环**：六条模式（同片搬迁/注入/逐帧隔离/消灭参数化 builder/
   先清死码/高频隔离）全部经真机验证并固化在计划 §13.1，契约护栏全绿。
2. **路径体系与蓝图三处偏差均为理性取舍**（`window/`→`panels/shell`、13 store→48 文件 / 47 store、
   平级→`panels/panels` 双层），已由根 `AGENTS.md` 固化为现行约定；无功能性代价。
3. **唯一未达的目标架构项**是 `PanelHost` 表驱动+懒加载；按当前面板规模与入参异构度，
   维持 if/else 是合理决策，已列入风险登记带触发条件。
4. **宿主 18,582 行是组件化模式的合理稳态**，继续减行的下一步是"按模块逐个翻 V2"
   （计划 §8.2 的既定路线），属独立决策，建议另行立项。
5. **域状态下沉已完成（§2.7）**：Prop 风格域全部转为 Store 风格，宿主 `@State` 333 → 132
   （46 store + 86 刻意保留，§2.7.1）；"刷新范围=订阅者"已覆盖全应用。
   剩余 A 类 305 / B 类 70 的 V1 下沉是**独立于 V2 的可选瘦身项**（§2.12 / §2.13）。

---

## 7. V1 → V2 演进评审（目标形态、收益与路径）

> **前提事实：** 工程 `compileSdkVersion 26.0.0` / `compatibleSdkVersion 6.0.2(22)`，
> V2 全能力 + API 19 混用放宽 + API 22 `animateTo` 缓解均可用。
> 官方 FAQ 明确把 V2 推荐给**本仓库正在遭遇的三个症状**——
> "深度状态观测""计算属性重复计算""状态变量修改监听"（`faqs-arkui-885`）。
> 本节是计划 §8.2 既定路线"先拆分、再逐模块翻 V2"的兑现评估；拆分已完成，前置条件已具备。

### 7.1 现状量化：V1 的"浪费面"（实测，184 个 `.ets`）

| 装饰器/模式 | 数量 | 说明 |
|---|---:|---|
| `@Component` / `@ComponentV2` | **纯 V1 / 0** | 全工程无 V2 组件 |
| `@State` | **230** | 宿主 132 + 组件 98 |
| `@Prop` | **1,183** | 参数快照负担（较 1,324 下降） |
| 回调型成员（`onX`） | **1,280** | 单个 `LayersPanel` 即 93 个 |
| `@ObjectLink` / `@Observed` | **260 / 63** | 较 197 / 34 上升，随 store 化 |
| `@Watch` | **12** | 宿主 2 |
| `@BuilderParam` | 16 | 规则 9 的遗留面 |
| `@Computed` / `@Param` / `@Event` / `@Provider` / `@Consumer` / `Repeat` | **全为 0** | V2 能力零使用 |
| 宿主 `AppStorage.` / `nm*()` 颜色快照调用 | 26 / **145** | 存储与主题快照 |

**宿主 `@State` 现状（132 = 46 store 实例 + 86 裸字段）：** 域状态已全部转为 store，
裸字段不再按"域"统计；其类别与保留理由（机制类 / 高频逐帧 / 跨域共用）见 §2.7.1。

**官方 V1→V2 装饰器映射（`arkts-v1-v2-migration-inner-component`）：**

| V1 | V2 |
|---|---|
| `@State` | `@Local`（需外部初始化时 `@Param`/`@Once`） |
| `@Prop` | `@Param` |
| `@Link` | `@Param`/`@Event` |
| `@ObjectLink` | `@Param` |
| `@Provide` / `@Consume` | `@Provider` / `@Consumer` |
| `@Watch` | `@Monitor` |
| （无对应能力） | `@Computed` |

### 7.2 目标形态：`@ObservedV2 模型 + @ComponentV2 视图`

```
state/     @ObservedV2 class XxxModel {
             @Trace field: T          // 属性级可观测
             @Computed get derived()  // 依赖变化才重算一次
             method()                 // 纯逻辑，可单测
           }
panels/    @ComponentV2 struct XxxPanel {
             @Param model: XxxModel   // 1 个 @Param 取代 N 个 @Prop 状态快照
             @Param port: XxxPort     // 1 个端口对象取代 N 个回调
             @Event onClose: () => void   // 类型化事件（真正的动作）
           }
host       @ComponentV2 WindowNativeNode {
             @Local  壳层/路由状态（原 132 中保留的裸字段，见 §2.7.1）
             @Provider appModels / themeModel
             build() 读 @Computed，不再有 1,183 个 @Prop 转发
           }
bridge/    BridgeClient 不变；每域新增 Port 适配器注入模型（守住"store 不碰 NAPI"）
```

关键差别：**状态同步不再走回调**——子组件直接改模型（或 `!!` 双向），
`@Trace` 只通知"真正读了该属性的那个 UI 元素"。

### 7.3 性能收益（机制均有官方文档依据）

| # | V1 现状（本仓库） | V2 机制 | 依据（本地文档） |
|---|---|---|---|
| 1 | 宿主 132 `@State` 集中一个 struct，任一变更重跑整棵 `build()`(667 行)+3 builder | `@Trace` **属性级**刷新 | "被 `@Trace` 装饰的属性变化时，**仅会通知 property 关联的组件**进行刷新" |
| 2 | 派生值每次重渲染重复计算（`panelTitle` 101 行、尺寸/颜色等） | `@Computed` 缓存，依赖变化才计算一次 | "依赖的状态变量变化时，**只会计算一次**" |
| 3 | 域状态已入 store（§2.7），但宿主仍持 46 store 实例 + 86 裸字段 → 任一写入仍重跑 `build()` | 状态入 `@Trace` 模型、宿主不读取 → **变更彻底不过宿主** | 同上 |
| 4 | loader 连续写 N 个字段 → N 次重渲染 | `@Monitor` 一次事件合并 + 可取变化前值 | "不仅感知变化后数据，还能获取**变化前**的数据" |
| 5 | 组件内 `ForEach` 列表 | `Repeat` 键控 diff | "V2 **推荐**使用 `Repeat` 替代 `ForEach`" |
| 6 | 深度数据需 `@ObjectLink` 逐层拆解（197 处） | `@ObservedV2`+`@Trace` 直接观测嵌套 | "提供对嵌套类对象属性变化**直接观测**的能力" |

**最核心的是 #1**：计划 §2 的根因原文即"1,047 个 `@State` 集中在同一个 struct 实例上，
任何一个变更都在同一棵渲染树上求值"——V2 属性级刷新是**对该根因的直接解**。

**诚实边界：**
1. V2 不自动更快；收益 ∝ 当前"浪费的重渲染量"。本仓库宿主 `build()` 巨大、19 条定时器各频率写入、
   域标量高度集中 → **浪费量确实大**，但**必须逐域真机实测**（UI-only 模拟器验不了刷新，计划 §13.1 规则 4）。
2. **逐帧字段仍须排除 `@Trace`**（`objectInspectorModel*`、`objectDetailConnector*` 几何）：
   每帧写 `@Trace` 属性同样逐帧发通知，"逐帧字段留宿主"的护栏必须保留。
3. `@Computed` 仅在 V2 上下文生效。

### 7.4 可维护性收益

| # | 现状（V1） | V2 后 | 规模 |
|---|---|---|---|
| 1 | **回调仓库** 1,280 个 `onX`（LayersPanel 93 / CompactShell 48 / ExpandedShell 43 / Hover 35 / SkyCultureViewTab 35 / UnifiedObjectDetailCard 24） | 状态同步型回调**整体消失**（直接改模型）；真动作收敛为**每域一个 Port**（`@Param`） | 1,280 → ≈15 个 Port |
| 2 | `@Prop` 快照 1,183（较 1,324 已降；壳层 61–67 个/个） | `@Param model`（1 个）+ `@Computed` 读派生 | 数量级下降 |
| 3 | 145 处 `nmText()/nmSub()/nmAccent()` 颜色快照逐分支传参 | 1 个 `@ObservedV2 ThemeModel(@Trace nightMode)` 经 `@Consumer` 就地取色 | 145 → ≈1 |
| 4 | 壳层 61–67 个 `@Prop` 多为把 store/状态**逐层转发** | `@Provider/@Consumer` 后代直读，删除转发链 | 壳层签名大幅收缩 |
| 5 | `@Watch` 12 处（一事件多变化多次触发） | `@Monitor` 合并 + 前后值 | 12 |
| 6 | 派生靠手写方法 + 手动 publish 胶水 | `@Computed` / `@Monitor` | — |
| 7 | `@Component` 禁 getter（V1 转换会丢弃，有崩溃风险） | V2 无此限制，`@Computed get` 即派生 | 消除一类隐性坑 |

**最大项是 #1**：宿主 12,500 行 L4 编排层含大量 `onX: () => this.doX()` 转发胶水；
回调仓库坍缩会同时缩小宿主与每个面板的签名。注意：这不减少业务方法数，
但消除"参数管道"与"每渲染分配箭头函数"的开销，并让宿主不再因这些域重渲染。

### 7.5 迁移路径：粒度与顺序（非大爆炸）

**粒度单位 = "模型 + 它的全部读取方"，一次提交整体翻代**（V1 不能一半一半；
只翻 store 不翻读取方会丢刷新，见计划修订 1）。仍远小于 18.7k 单体。

**关键洞察（避免大爆炸）：宿主可作为"挂载点"而不翻代。**
V1 `@Component` 中放 `@ComponentV2` 子组件、并传入 `@ObservedV2` 模型是允许的（API 19 起放宽混用）；
只要**宿主自身不读取该模型字段**，宿主就不会因该域变更而重渲染 → 域刷新被限制在 V2 子组件内。
跨代传递按混用指导处理：V1→V2 用 `UIUtils.enableV2Compatibility(...)`，
V2→V1 用 `makeV1Observed(...)`。

| 阶段 | 内容 | 目标域 |
|---|---|---|
| **A：V2 叶子 + V2 模型，宿主不动** | 把现有 `@Observed` store 改为 `@ObservedV2`+`@Trace`、交 `@ComponentV2` 叶子持有；宿主以普通成员持有、不读取 | 已 store 化的域（卫星 / 流星 / 星表 / 导航星 / 考古线 / 拼贴 / 插件命令 / 陀螺仪 / 叠层 / Dock / 对象媒体…）——**§2.7 已完成"先建 store"的前置，A 阶段现在可直接进行** |
| **B：翻宿主** | `@State`→`@Local`；`@Prop`→`@Param`；`@Watch`→`@Monitor`；`AppStorage`→`AppStorageV2`（经 `enableV2Compatibility` 过渡） | 宿主、`ApplicationRoot`、`QAbility`（启动门控 + CLI 事件通道 + `i18nLang`，共 17 key）——**最高风险，放最后** |
| **C：收口** | `@Prop` 快照→`@Computed`/`@Consumer`；回调→Port；`ForEach`→`Repeat`；删兼容胶水 | 全量 |

前置条件：A 阶段要求**宿主不再读这些字段**。现状 `panelTitle()`/`panelSubtitle()` 与部分布局助手
会读少数状态——这几处与该域**同片翻代**，或暂留 V1。

### 7.6 成本与风险

| 风险 | 说明 | 对策 |
|---|---|---|
| **`AppStorage` ↔ `AppStorageV2` 不互通** | 宿主 26 处引用、17 个 key 含 `QAbility`（无装饰器）隐私门控、CLI 事件通道、`i18nLang` | 过渡期用 `enableV2Compatibility`/`makeV1Observed`；**唯一高风险项，须专片** |
| **`animateTo`/`transition` 动效异常** | 官方："V2 中使用 `animateTo` 可能出现动画效果异常" | 项目 API 26，可用 API 22+ 的 `applySync`/`flushUpdates`/`flushUIUpdates` 规避；宿主弹簧转场须逐条回归 |
| **V1 装饰器不能与 `@ObservedV2` 混用** | 官方混用限制条件 1 | 翻代时一并替换读取方装饰器 |
| **V2→V1 不能直接用装饰器接收 `@ObservedV2` 类** | 编译报错（限制条件 2） | 中间期走 `makeV1Observed` |
| **store 翻代是原子提交** | 大 store（`SkyCultureSettingsStore` 528 / `LocationPickerStore` 445）读取方多 | 按域分片，单域可回滚 |
| **真机验证必需** | 模拟器无引擎数据，验不了刷新 | 每片真机 A/B（计划 §13.1） |
| **`LocalStorage`（Qt 桥面）** | 不可迁移 | 保持不动 |
| **`@Watch`→`@Monitor` 语义差异** | 合并/前后值 | 12 处行为回归 |

**工作量：** 计划 §8.2 对"单体原子翻代"估 2–3 周；拆分完成后改为**分域增量**，
粗估 3–5 周，但**每片独立可编译、可装机、可回滚**——把原来"一次不可分割的大提交"
变成十几次小提交。

### 7.7 收益量化总表

| 指标 | 现状（V1 实测） | V2 目标 | 收益类型 |
|---|---|---|---|
| 触发宿主整树重渲染的状态数 | **132**（46 store + 86 裸字段） | ≈50–80（仅壳层/路由） | 性能 |
| 域标量变更路径 | 经宿主重渲染 | `@Trace` 属性级，不过宿主 | 性能 |
| 重复派生计算 | 每次 build 重算 | `@Computed` 一次 | 性能 |
| 回调型成员 | **1,280** | ≈15 个 Port | 可维护性 |
| `@Prop` 快照 | **1,183** | `@Param` 模型引用 | 可维护性 |
| 颜色快照调用 | **145** | 1 个 `@Consumer ThemeModel` | 可维护性 |
| `@ObjectLink` 逐层拆解 | **197** | `@Param`+`@Trace` 直读 | 可维护性 |
| 列表渲染 | `ForEach` | `Repeat` 键控 diff | 性能 |

### 7.8 建议

1. **不做全量翻代**。V1 目前正确、契约全绿；V2 是**性能/可维护性投资**，非缺陷修复。
2. **先做 A 阶段 1–2 个独立域试点**（推荐**卫星域**：`SatelliteStore` 已建、含 20+ 字段，
   且无 `AppStorage` 依赖），用真机量化"属性级刷新"的实际帧率/重排收益，**拿数据再决定是否扩大**。
3. **B 阶段（`AppStorage` 桥）单独立项**：它触碰隐私门控与 CLI 通道，风险与收益须单独评估。
4. **`animateTo` 回归列入 A 阶段验收**——这是官方明示的 V2 已知异常点。

---

## 8. UI 性能测试方法与计划

> 目的：为 §7 的 V1→V2 演进提供**可复现、可比对**的性能基线与 A/B 方法。
> 原则：**真机 + 语义 CLI + 引擎遥测**，不使用坐标点击；所有场景可重放、可恢复现场。
> 本节只定义方法与计划，**不修改任何代码**；实测数据待执行后登记。

### 8.1 指标分层（三个互补通道）

| 层 | 指标 | 采集通道 | 语义边界 |
|---|---|---|---|
| L1 引擎帧遥测 | 每帧 `total/cmd/update/draw/submit` (ms) | hilog tag **`StellariumFps`**，行 `frame: total=… cmd=… update=… draw=… submit=…` | 最细，用于拖动/时间高频链的帧成本分布 |
| L1' 引擎 FPS | 瞬时帧率 | CLI `getFPS`（C++ 原子 `s_ohosRenderFps`=1.0/dt） | 粗粒度单点读数，仅作交叉印证 |
| L2 启动/交互时序 | 首帧就绪、面板切换完成、模型帧完成 | `getPresentationState.ready`、`getAstroPanelState.transitioning`、`getObjectModelView.renderedAt`；hilog `presented-frame-ready`/`title-assembled`/`sky-revealed` | 端到端时延 |
| L2' 主线程健康 | `uiPulseCount`/`uiMaxDelayMs`、`computeMs`/`pixelMapMs`/`totalMs` | `getObjectModelView` | **≠ FPS、≠ 触摸延迟**（`DETAIL-MODEL-PERFORMANCE.md` 明确）；仅区分"后台计算耗时"与"主线程被堵" |

### 8.2 工具链与前置

- **驱动**：`node scripts/stellarium-cli.mjs --device <id> --command <name> [--payload …] --json`
- **包名陷阱（必须）**：CLI 默认 `--bundle com.joinother.skyinstrument`，而验收/前台是
  **`com.cnchensh.stellarium`**（计划 §13.3）。每次显式 `--bundle com.cnchensh.stellarium`，
  并用 `aa dump -l` 复核 `state #FOREGROUND`，否则会整段测到另一个包。
- **设备**：真机（Mate 80 Pro）。x86_64 模拟器无 `libstellarium.so`，引擎遥测全为 `--`，
  **只可用于结构回归，不可用于性能结论**。
- **日志**：每轮前 `hdc shell hilog -r` 清缓冲，窗口内采样，避免回绕污染。
- **可选系统级（尚未在本仓库使用，按需）**：`hitrace`（render service 帧时序）、
  `hidumper`（内存）。需先在设备上验证可用性与权限。

### 8.3 场景矩阵（确定性、可重放）

| ID | 场景 | 步骤要点 | 主指标 |
|---|---|---|---|
| **S0** | 冷启 | `force-stop` → `aa start` → 计时到 `getPresentationState.ready==true` | 启动→首帧 (ms) |
| **S1** | 星图空转 | `setTimeRate 0`、`clearSelection`、固定 `setJD`/`setFOV 70` | `total`/`draw` 中位数（静态基线） |
| **S2** | 拖动/惯性 | `moveToAltAz` → `startPanInertia` ×4 → `stopPanInertia`（既有脚本做法） | `total` 分布 p50/p95、丢帧 |
| **S3** | 时间高频链 | `setTimeRate` 高速 + 打开时间面板 | `total`/p95（宿主 125ms 链影响） |
| **S4** | 面板开/切 | `openUiPanel <panel>` → 等 `getAstroPanelState.transitioning=false` | 打开时延 + 打开后帧成本 |
| **S5** | 详情媒体/模型 | `getObjectModelView`（Moon/Saturn/Jupiter，worker 帧） | `computeMs`/`totalMs`/`uiPulseCount`/`uiMaxDelayMs` |
| **S6** | 叠层密集 | `actionShow_MistHorizon` 0/1、网格/标签/星座线开关 | `total` 差值与 p95 劣化 |

### 8.4 采集协议

1. **统一条件**：同一真机、同一构建（记录 HAP 版本/提交 hash）、固定 JD/FOV/location、
   `setTimeRate 0`、关闭无关叠层。
2. **冷启**每轮 `force-stop` 后 `aa start`；**稳定态**场景先预热 ≥1.5s 再丢弃。
3. **增量采样**：`before = Set(hilog 行)` → 施加载荷 → 取新增行
   （既有 `test-ohos-mist-performance.mjs` 的做法），避免把历史帧计入统计。
4. **重复**：每场景 ≥3 次独立运行，报告 `median(p50)/p95/max` 与样本数。
5. **恢复现场**：脚本改动的持久化设置（图层/时间/位置）必须复原。
6. **产物**：JSON 报告（含原始帧行）写入 `docs/harmonyos/json/perf/`，便于版本间比对。

### 8.5 基线采集（现在，V1）

- **复用既有范式**：`scripts/test-ohos-mist-performance.mjs`（帧遥测 + `summarize()` median/p95/max +
  增量采样）、`scripts/test-ohos-model-performance-pad.py`（模型 worker 指标 + `renderedAt` 异步等待）。
- **产出建议**：新增 `scripts/measure-ohos-ui-performance.mjs`（通用场景运行器：
  `--scenario S0..S6 --device <id> --bundle com.cnchensh.stellarium --output <json>`），
  首轮生成 `docs/harmonyos/json/perf/baseline-v1-<date>.json` 并登记到 CHANGELOG。
- 基线必须**可复跑**：记录设备 SN 简写、构建提交、完整命令序列。

### 8.6 A/B 对比（V2 试点后）

- 同一设备、同一场景脚本、同一构建开关（**仅差 V1/V2 代码**）。
- **交替运行**（V1→V2→V1→V2）以抵消热漂移；报告 p50/p95 差值。
- 判据建议：
  - **不回退**：任一场景 p95 劣化 > 10% 视为回归，须解释或阻回。
  - **改进目标**：V2 试点域对应场景（如 S4 打开卫星面板、S3 时间高频链）p95 应有可测改善。
  - **交互正确性**（点击后是否实时更新）以真机 A/B 判定，不能只看布局一致（计划 §13.1 规则 4）。

### 8.7 已知限制

1. UI-only 模拟器验不了引擎与刷新 → 性能/刷新类结论**必须真机**。
2. `totalMs`/`uiPulseCount` 等**不是 FPS 或触摸延迟**（`DETAIL-MODEL-PERFORMANCE.md` 明确）——
   禁止跨语义混用与拼凑结论。
3. 双包名与前台切换会污染测量（计划 §13.3）——全程显式 `--bundle` + `aa dump -l` 复核。
4. 热/温控与系统负载会抖动 p95——交替 A/B + 多轮取中位数。
5. hilog 缓冲回绕——每轮 `hilog -r`，控制采样窗口。

### 8.8 与 §7 的衔接

§7 建议先做**卫星域** V2 试点；对应性能验证即 **S4（打开卫星面板）+ S1/S2（面板打开前后星图帧成本）
+ 该域状态切换（如 `setSatellitesFlag`）的 p95**。V1 基线（S0–S6）应在试点**之前**采集入库，
作为唯一对照来源。

---

## 9. A/B 类下沉之后的剩余功能模块普查与下沉候选（2026-10-04）

### 9.0 基线（本节的数字口径）

**A/B 轨道已全部完成**（记录见 PLAN §14 + git `8f86709d96`→`5ea945005f`）：`bridge/CommandPort.ets`
建成、A1 91 个纯函数迁入 `common/derive/*`、A2 160/214 下沉（余为登记保留）、B1/B2/B3 加载器下沉。
宿主由 18,582 → **14,347 行**、`private` 由 940 → **593**、`private load*` 由 70 → **3**
（`loadSkyCultureDetails` 登记 + `loadFov`/`loadPlanetPositions` 非 A/B）。**本节所有数字取自该 593-方法文件。**

> 说明：本文 §1/§2.12/§2.13 的数字是 **A/B 之前**（18,582 / 940）的历史基线；续作以 §9 与 PLAN §14 为准。
> 本次普查口径：按方法名与所属字段做**用途归类**（脚本见附录），逐模块判断"能否再封装/下沉"。

### 9.1 剩余功能模块总表（按用途，593 个 `private`）

| 模块 | 方法 / 行 | 现状归属 | 能否再封装/下沉 | 目标形态 |
|---|---:|---|---|---|
| 触摸/手势/视图 | ~31 / ~800（含 `handleSkyTouch` 318） | 宿主 + **89 手势/视图字段** | **可**（高价值 / 高风险） | P1 `SkyInputController` |
| 传感器/陀螺仪 | 22 / ~650 + **48 字段** | 宿主（`GyroStore` 仅 19 行） | **可** | P1 `SensorController` + 扩充 `GyroStore` |
| 录制/回放/视频/截图 | 23 / 411 + 13 字段 + 定时器 | 宿主 + `ScriptStore` 部分 | **可** | P1 `RecordingController` |
| 对象模型渲染 | ~29 / 636 | 宿主 + `ObjectMediaStore` + `DetailModelRenderClient` | **可** | P1 `ObjectModelRenderer` |
| 选中/详情管线 | 47 / 1,225（含 `applySelectedObject` 230） | 宿主（C 类跨域管线） | **部分**（服务化或保留） | P4 `SelectionService` |
| 星空文化 | 66 / 1,040 | 宿主 + 3 store | **部分**（美术解码管线） | P4 `ImageDecoder` + 保留 `loadSkyCultureDetails` |
| 媒体解码（图像/纹理） | `decodeLocalImage`(70) 等 | 宿主 | **可** | P4 `common/media/ImageDecoder` |
| 启动/桥/会话/隐私/平台 | ~18 / ~330 | 宿主 | **可** | P1 `StartupBridge` + P4 `common/platform/*` |
| 语音 / TTS | 1 / 11（`speakSelectedObject`） | 宿主 | **可** | P4 `common/SpeechService` |
| 交互导览 | 8 / 209 | 宿主 + `GuideStore` | **可** | P2 → `GuideStore` 方法 |
| 脚本播放 | 14 / 262 | 宿主 + `ScriptStore` | **可** | P2 → `ScriptStore` 方法 |
| 壳层 / 面板路由 | 57 / 734 | 宿主 + `DockStore` | **基本保留**（路由/响应式） | 保留；几何 → `derive/geometry` |
| 叠层 / 信息窗 | 32 / 309 | 宿主 + 各 store | **部分** | 几何 → derive；状态已在 store |
| 刷新 / 同步 / 收口 | 25 / 567 | 宿主（`publish*`/`schedule*`） | **保留**（生命周期收口） | — |
| 生命周期 / 回调 | 10 / 543 | 宿主 | **保留**（编排） | — |
| 天文 / 时间 / 搜索 / 图层 / 位置 / 设置 / 插件 / 望远镜 / 卫星 | 各域 | 已 store 化 | **基本到位** | 既有 store + hooks |
| 其他 / 未归类 | 60 / 1,029 | 宿主（命中 / 平台 / 杂项） | **部分** | 见 9.3 / 9.6 |

**模式说明**：P1＝控制器类（普通类 + 注入端口 + 自持定时器，形如既有 `TimeWheelController`）；
P2＝并入既有域 store 的方法；P4＝跨域服务（`common/` 或 `capability/` 单例）。

### 9.2 控制器型（P1）候选 —— 剩余最大、最内聚的四块

| 控制器 | 代表方法（行） | 私有字段 | NAPI 依赖（需注入端口） | 定时器 | 风险 |
|---|---|---:|---|---|---|
| **`SensorController`** | `onRotationVectorDirect`(122) `startGyroscope`(121) `onOrientationData`(113) `updateGyroTargetGuide`(109) `stopGyroscope`(56) `watchGyro*` `emitGyroPoseProbe` | **48** | `sensor.*`（订阅/退订） | — | 中 |
| **`SkyInputController`** | `handleSkyTouch`(318) `handleSkyMouse`(51) `handleSkyKey`(31) `handleSkyAxis`(23) `handleSkyTap`(11) `startSkyInertia`/`stopSkyInertia`(25) `emitFluidDrag`(36) | **89**（touch/drag/pinch/inertia） | 无（→ `callNativeFire`） | `skyInertiaTimer` | **高**（命中/拖动热路径） |
| **`RecordingController`** | `startScreenVideoRecording`(51) `playRecording`(25) `saveCurrentRecording`(22) `replayNextCommand`(22) `startRecording`(21) `finalizeScreenVideo`(21) `stopScreenCapture`/`saveScreenshot` | 13 | `MediaKit` / `fileIo` / `photoAccessHelper` | `videoStateTimer` / `recordViewCheckpointTimer` | 中 |
| **`ObjectModelRenderer`** | `renderObjectInspectorModel`(106) `decodeObjectInspectorModelTextureFromPng`(46) `commitObjectInspectorModelTexture`(36) `clearObjectInspectorModelRenderer`(35) `requestObjectInspectorModelRender`(25) `handleObjectInspectorModelTouch`(57) `refreshObjectInspectorModelLighting`(11) | ~25（`objectInspectorModel*`） | 无（经既有 `DetailModelRenderClient` worker） | `objectInspectorModelRenderTimer` | 中高 |

**判定依据**：均为"状态机 + 定时器 + 一组同域方法 + 一批私有字段"——正是 `TimeWheelController`
（Phase 3m）已验证过的 P1 形态：可观测数据留在 `@Observed` store（`@ObjectLink` 消费），
**不可观测草稿字段与行为**（手势采样、逐帧写入）搬入普通类并自持 `start()/stop()`。
`SkyInputController` 独占 89 个字段，是**当前宿主最大的一块未拆控制器**；
`SensorController` 独占 48 个字段 + 22 个方法，是**第二大**。

### 9.3 服务型（P4）候选

| 服务 | 代表方法（行） | 依赖（端口） | 落点建议 |
|---|---|---|---|
| **`SelectionService`** | `applySelectedObject`(230) `refreshSelectedObject`(29) `requestSelectedDetails`(28) `moveToSelectedObject`(19) `navigateSelectedObjectTo`(33) `scheduleSelectedObjectForUiChange`(15) | `CommandPort` + 多个域 store | 跨域选中/居中管线的单例；或按 §14.3.1 判据**保留宿主**（含 4 热路径） |
| **`ImageDecoder`** | `decodeLocalImage`(70) `decodeSkyCultureArtThumbnail`(33) `decodeSkyCultureArtPreview`(27) `releaseDecodedImage`(11) | `fileIo` / `image`（`MediaPort`） | `common/media/ImageDecoder.ets` |
| **`PlatformServices`** | `shareFile`(22) `copyTextToClipboard`(13) `saveScreenshot`(17) `exportScreenshotToUserStorage`(25) | `systemShare` / pasteboard / `photoAccessHelper` | `common/platform/{Share,Clipboard,Screenshot}.ets` |
| **`SpeechService`** | `speakSelectedObject`(11) | TTS `MediaKit`/`CoreSpeechKit` | `common/SpeechService.ets`（或并入 `GuideStore`） |
| **`StartupBridge`** | `restoreStartupSettings`(65) `runStartupBridgeTasks`(37) `startupBridgeSync`(11) `saveCurrentViewAsStartup`(10) | `CommandPort` + Preferences | `capability/StartupBridge.ets` |
| **`SessionService` / store** | `sessionApply`(24) `sessionExport`(20) `sessionHandoff`(14) `sessionSummary`(6) | `getSessionState`/`applySessionState` 桥 + AppStorage | `state/SessionStore.ets` |

### 9.4 并入既有 store（P2）候选

| 域 | 方法 | 目标 store |
|---|---|---|
| 脚本播放 | `playScriptByName`(44) `continueNativeScript` `toggleReplayPause`(20) `changePlaybackRate` `stopScriptPlayback` `sendScriptKey` | `ScriptStore`（+ `ScriptHostHooks` 注入） |
| 交互导览 | `executeGuideRequest`(63) `continueNativeScript` 相关 | `GuideStore`（guide 请求/定时器） |
| 跟踪 | `setTrackingState`(37) `toggleTracking` 相关 | `ViewSettingsStore` / 保留 |

### 9.5 建议新增的端口类型（对称于 `CommandPort`）

A/B 已为"桥"建立 `CommandPort`；剩余子系统依赖**非桥 NAPI**，需同形态端口以满足 §14.8 规则 2：

| 端口 | 覆盖 NAPI | 供哪些候选使用 |
|---|---|---|
| `MediaPort` | `fileIo` / `image` / `picker` / `media` / `photoAccessHelper` | `ImageDecoder`、`RecordingController`、`PlatformServices` |
| `SensorPort` | `sensor.*` 订阅/退订 | `SensorController` |
| `PlatformPort` | `systemShare` / pasteboard / TTS | `PlatformServices`、`SpeechService` |

端口为**纯接口**（不 import NAPI），宿主在 `aboutToAppear` 做具名适配器（同 `HostCommandPort` 先例）。

### 9.6 明确保留项（勿再动）

1. §2.7.1 登记的 **86 个保留裸字段**（机制类 / 高频逐帧 / 跨域共用 / 引擎自用）。
2. A2 的 **51 个 A-保留** + **4 个热路径登记**（`isUiPoint`/`skyZoomButtonAt`/`dockActionAt`/`expandedSafeTargetPoint`）+ **13 个宿主控制器**（`objectDetailConnectorObstacles` 等）。
3. `loadSkyCultureDetails`（跨序号线 + 美术管线 + 逐帧字段，永久登记）。
4. 壳层/路由（`setPanel`/`updateResponsiveLayout`/`closePanel`/`open*` 族）、生命周期、`publish*`/`schedule*` 收口。
5. `floatingPanel`/`compactPanel`/`panelContent` 三个 `@Builder`（规则 9）。

### 9.7 建议顺序与风险

1. **低风险高价值（先做）**：`SensorController`（隔离 48 字段 + 22 方法）→ `RecordingController`（13 字段 + 定时器）→ `SpeechService`/`PlatformServices`（小而独立）。
2. **中风险**：`ObjectModelRenderer` → `ImageDecoder` → `StartupBridge` → `SessionStore`；`ScriptStore`/`GuideStore` 方法并入。
3. **高风险（最后，须真机命中 + 截图对照）**：`SkyInputController`（89 字段 + `handleSkyTouch` 318，命中/拖动热路径）；`SelectionService`（`applySelectedObject` 230，全应用选中管线，多入口）。

> 通用约束沿用 PLAN §14.8：控制器**不 import NAPI/UI**（经端口注入）；可观测数据入 `@Observed` store，
> 逐帧/草稿字段留控制器且不入被观察对象；定时器由控制器 `start()/stop()` 自持并在生命周期收口；
> 每片 `arkts_check` → 构建 → 契约（锚点不变）→ 受影响测试 → 真机 → CHANGELOG（CRLF、裸 LF=0）→ 独立提交。

---

## 附录：本文数字的复现命令

```powershell
# 主文件体量与结构指标
(Get-Content harmonyos\ets-source\pages\MainWindowNativeNode.ets).Count          # 18582
$c = Get-Content harmonyos\ets-source\pages\MainWindowNativeNode.ets -Raw
([regex]::Matches($c,'(?m)^  @Builder\s*$')).Count                              # 3
([regex]::Matches($c,'@State\s+(?:private\s+)?\w+\s*:')).Count                  # 132
([regex]::Matches($c,'(?m)^  private\s+(?:async\s+)?\w+\s*\(')).Count           # 940
([regex]::Matches($c,'setInterval')).Count                                      # 19
([regex]::Matches($c,'callInteractive')).Count                                  # 195（薄委托调用点）

# 三个幸存 Builder 定位 + panelContent 体量
Select-String -Path harmonyos\ets-source\pages\MainWindowNativeNode.ets -Pattern '^  @Builder\s*$' -Context 0,1

# 目录总账
Get-ChildItem harmonyos\ets-source\state -File | Measure-Object                  # 48
Get-ChildItem harmonyos\ets-source\panels -Recurse -File -Filter *.ets | Measure-Object  # 119

# 逐方法归域（§2.6/§2.9 的五层占比与领域地图）
#   解析式：以 `^  (private )?(async )?\w+\(` 为方法起、`^  }$` 为方法止，
#   累加每个方法体行数并按名称前缀归域（bridge/sensor/time/search/object/astro/…）。
#   实测：940 个方法；L4（load/apply/refresh/handle/publish 类）≈13,800 行、74%。

# 全工程装饰器普查（§7.1）
$all = (Get-ChildItem harmonyos\ets-source -Recurse -File -Filter *.ets |
  ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }) -join "`n"
foreach($p in '@State\b','@Prop\b','@ObjectLink\b','@Observed\b','@ObservedV2\b','@Watch\b',
  '@Computed\b','@Param\b','@Event\b','@Provider\b','@Consumer\b','@ComponentV2\b','Repeat\('){
  "{0,-16} {1}" -f $p, ([regex]::Matches($all,$p)).Count
}
# 回调型成员：(?m)^\s*on[A-Z]\w*\??\s*:  → 合计 1280

# A 类纯派生方法普查（§2.12）
#   解析每个 `private` 方法体（`^\s*private\s+name(` 起、`^  }$` 止），保留同时满足：
#   ① 返回非 void / 非 Promise；② 名字非动作动词（load|apply|handle|set|jump|…）；
#   ③ 体内无 `this.x=`/`this.store.x=`（成员写）、无 fileIo/image/picker/media、
#      无 callNative*/callInteractive、无 openPanel/closePanel/setPanel/activePanel、
#      无 setInterval/setTimeout、无 AppStorage/LocalStorage、无 hilog。
#   实测：940 个 private → A 类 305（几何 112 / 其他派生 88 / 标签 64 / 判断 34 / 颜色 5 / 格式化 2）；
#   其中 A1 零宿主状态读取（体不出现 `this.<字段>`）91 个可**直接移出**；
#   A2 读取宿主字段 214 个；305 个中 218 个已在 build+panelContent 区被引用为端口/参数。

# B 类加载器可沉性普查（§2.13）
#   对每个 `private load*` 方法体提取：桥调用（callNative*/callInteractive）、
#   写哪些 store（`this.<store>.<field> =`）、写哪些宿主字段（`this.<field> =`）、
#   调用的其他宿主方法（`this.<name>(`）、定时器、面板路由、publish。
#   判定：仅桥+本域 store → B1；+助手/他域/publish → B2；+宿主字段写/路由/定时器 → B3。
#   实测：70 个 load* = B1 24 + B2 35 + B3 11。

# 契约护栏
node scripts\check-ohos-ui-contract.mjs
# → UI contract intact: 33 panels, 22 static ids, 17 dynamic prefixes, 42 id anchors, over 184 files.
```
