# pages/ 代码库重构方案（ArkTS / ArkUI）

- **状态：** 待评审。本文只做规划，**未改动任何源码**。
- **日期：** 2026-09-30
- **范围：** `harmonyos/ets-source/pages/**`，主对象 `pages/MainWindowNativeNode.ets`（32,774 行）。
- **正确性来源：** 本文所有数字与结构均由第 9 节命令在当前代码上实测得到，非估计值。
- **与既有规划的关系：** 产品级的面板归属、导航规则、收口规则服从
  `research/PANEL-PLUGIN-ARCHITECTURE-ROADMAP.md`；本文只解决**代码结构**问题，不改变面板的产品定义。

---

## 1. 现状取证

### 1.1 体量

| 文件 | 行数 | 说明 |
|---|---:|---|
| `pages/MainWindowNativeNode.ets` | **32,774** | 唯一主界面实现，占业务 ArkTS 的 **80.8%** |
| `pages/location_hierarchy.ts` | 74,611 | 数据表（行政区划），不参与重构 |
| `pages/location_names_zh.ts` | 7,350 | 数据表 |
| `pages/I18n.ets` | 2,354 | 翻译表 + 语言切换 |
| `pages/StellariumTypes.ets` | 1,122 | 桥接协议类型集合 |
| `qability/StellariumResourceBootstrap.ets` | 943 | 资源预热 |
| `pages/StellariumAudio.ets` | 927 | 音频 |
| `qability/QAbility.ets` | 694 | UIAbility（启动链、隐私门控） |
| 其余 20 余个文件 | < 250 各自 | |
| **业务代码合计（不含 `location_*` 数据表）** | **40,548** | 其中主文件占 80.8% |

### 1.2 单体内部结构（主文件）

| 指标 | 实测值 |
|---|---:|
| `@Component` 结构体 | **1**（`export struct WindowNativeNode`，L806） |
| `@State` 字段 | **1,047**（原始类型 948 / 数组 37 / 自定义类 13） |
| `@Builder` 方法 | **145** |
| `private` 方法 | ≈**1,109** |
| `callInteractive` 调用点 | **203**（定义 1 处，L4081） |
| `setInterval` | **20** |
| 定时器字段 | ≈**38** |
| `ForEach` | **169** |
| `.id()` 锚点 | **41** |
| `activePanel` 取值 | **33** |
| `AppStorage` 引用 | 28 |
| `@Watch` | 2 |

### 1.3 最大的 Builder（拆分靶点，前 12，**2026-10-01 重测**）

> **更正说明：** 本文初版此表用"下一个 `\n  }\n`"启发式测量，该启发式会越过 builder 的真实收尾、把紧随其后的
> 普通方法也算进去，导致**严重高估**（如 `searchFilterMenu` 初版记 3,441 行，实测仅 **48 行**）。
> 下表改用"首个 `^  }$` 收尾"重测；全文件共 **118 个 `@Builder`，合计 9,475 行**。

| 行数 | 起始行 | 名称 |
|---:|---:|---|
| **4,707** | L22128 | `panelContent`（33 个面板的 if/else 分发，**占全部 builder 代码的 50%**） |
| 446 | L26837 | `toolsPanel` |
| 209 | L17151 | `scriptFocusShell` |
| 183 | L18603 | `unifiedObjectDetailCard` |
| 179 | L19683 | `tabletInspectorMedia` |
| 150 | L17588 | `expandedShell` |
| 130 | L21407 | `compactMoreDrawer` |
| 125 | L9786 | （首行为 `if` 的匿名 builder） |
| 109 | L27500 | `cityChipsRow` |
| 99 | L21162 | `gyroCalibPanel` |
| 93 | L21912 | `skyCultureMakerConstellationEditor` |
| 87 | L17740 | `compactShell` |

**推论（影响策略）：** 本文件的 UI **并不分散在众多超大 builder 里**，而是集中在 **`panelContent`（4,707 行）**；
其余 builder 多为几十到几百行。因此 Phase 4 的主战场是**把 `panelContent` 的 33 个面板分支逐个抽成组件**
（每个分支通常只有几十行），而不是先啃若干"巨型 builder"。

### 1.4 状态字段的领域分布（按名称聚类）

| 领域 | 字段数 |
|---|---:|
| 天文计算（astro/wut/phenomenon/eclipse/transit/season/almanac…） | 164 |
| 星空文化（skyCulture/sc*） | 130 |
| 对象与详情（object/selected/detail/inspector…） | 93 |
| 天空与视图（sky/view/grid/line/label/star/constellation…） | 79 |
| 图层开关（equatorialGrid/eclipticGrid/cardinalPoints/asterismLines…） | ≈60 |
| 搜索与分类（search*/category*） | ≈60 |
| 目镜（ocular/eyepiece） | 50 |
| 工具（angle/archaeo/nav/mosaic/pointer/coordinate） | 51 |
| 卫星（sat*） | ≈40 |
| 壳层与面板（panel/dock/chip/shell/layout） | 40 |
| 脚本与自动化 | 26 |
| 望远镜（lx200/telescope） | 24 |
| 时间（time/jd/scrub/clock/rate） | 21 |
| 传感器（gyro/compass/orient/attitude） | 13 |
| 视频与录屏 | 10 |
| 设置（config/settings/option） | 10 |
| 位置（place/city/savedLocations/locSearch*） | 8 |
| 星云 / 极轴镜 / 书签 / 音频 / 流星 / i18n | 6 / 6 / 4 / 3 / 3 / 1 |

### 1.5 跨文件状态与存储（全应用）

| 文件 | AppStorage | `@StorageLink/Prop` | LocalStorage | `@Watch` |
|---|---:|---:|---:|---:|
| `pages/MainWindowNativeNode.ets` | 28 | 5 | 1 | 2 |
| `qability/QAbility.ets` | 26 | 0 | 2 | 0 |
| `pages/ApplicationRoot.ets` | 1 | 6 | 0 | 3 |
| `pages/StartupSky.ets` | 1 | 3 | 0 | 2 |
| `pages/PrivacyBootstrap.ets` | 1 | 1 | 0 | 1 |
| `pages/I18n.ets` | 2 | 1 | 0 | 0 |
| `qability/ClipboardService.ets` | 1 | 0 | 0 | 0 |
| `qability/QtWindowStageAdapter.ets` | 1 | 0 | 9 | 0 |
| `qability/QtUtils.ets` / `LocalStorageTsModule.ets` | 0 | 0 | 4 / 6 | 0 |
| 其余 3 个独立窗口页 | 0 | 0 | 各 1 | 0 |
| **AppStorage 唯一 key 总数** | **17** | | | |

**关键区分：** `LocalStorage` 在本工程**不是应用状态**，而是 Qt/QML 互操作桥面
（`windowStage.loadContent(path, storage)` 把 storage 交给 Qt 内容；
`LocalStorageTsModule.makeNewLocalStorage` 经 `QtUtils.getModulesFactoriesMapForQt()` 暴露给 C++）。
这部分属于 C++/Qt 契约，**不在重构范围内**。

### 1.6 同步链路与测试契约

- `scripts/sync-ohos-build-sources.sh` 用 `find "$src_dir" -type f` **整树递归镜像**
  `harmonyos/ets-source/**` → `build/libstellarium-harmonyos/entry/src/main/ets/**`。
  → **新增子目录无需改脚本**，会被自动同步。
- `main_pages.json` 注册 4 个 `@Entry`：主窗口 `ApplicationRoot` + `FloatWindowNativeNode`
  / `SubWindowNativeNode` / `UiExtensionNativeNode`（三个独立窗口）。新增的组件文件**不需要注册**。
- 依赖 UI 内部标识的测试：`scripts/test-ohos-model-scroll.mjs`（`.id()` 1 处）、
  `scripts/test-ohos-search-browser.mjs`（`.id()` 2 处）；
  `test-ohos-guide-pad.mjs` / `test-ohos-polar-scope-pad.mjs` 走 uitest + dumpLayout。
  其余 `test-ohos-*`（52 个）主要走语义 CLI 与 C++ 层。

---

## 2. 根因分析（为什么会长成这样）

1. **唯一 struct = 唯一组件 = 全局刷新。**
   1,047 个 `@State` 集中在同一个 `struct` 实例上，任何一个变更都在同一棵渲染树上求值。
   代码内 L16156 附近的注释已经自证这个坑：*高频刷新路径不得触碰其他 `@State`，否则触发全局重排、
   拖动星图卡顿*——这正是"状态过度集中"的症状，而不是原因。

2. **`@Builder` 的参数按值捕获，堵死了状态下沉。**
   ArkUI V1 的 `@Builder` 简单类型参数是值拷贝、不回传、不参与变更通知；
   因此所有 builder 只能通过 `this.xxx` 直读宿主状态。
   结果：**状态被物理锁定在唯一宿主里**，无法随 UI 一起下沉到子组件。

3. **推论：单纯按行数切文件无效。**
   切完仍是同一个 `struct`、同一个 `this`、同一棵子树——既没有减少刷新范围，
   也没有减少耦合，只是把 32,774 行变成 10 个互相 `this` 依赖的文件。
   必须同时引入**组件边界**与**状态所有权**。

4. **次生问题：**
   `panelContent()` 5,138 行用 if/else 分发 33 个面板（无表驱动、无懒加载边界）；
   38 个定时器全挂在宿主生命周期上（启动/前台/后台/销毁四处逐个接线）；
   `callInteractive` 203 个裸调用点直接依赖 `libentry.so` 导出。

---

## 3. 目标架构

```
harmonyos/ets-source/
├── pages/                    ← 只留页面入口、类型/资源表
│   ├── ApplicationRoot.ets          @Entry 主窗口（不变）
│   ├── I18n.ets  StellariumTypes.ets  StellariumAudio.ets
│   ├── location_*.ts  *Geometry.ts  *Client.ets  DetailModel*.ets
│   └── FloatWindow/SubWindow/UiExtensionNativeNode.ets（独立窗口，不动）
├── window/                   ← 新增：窗口与壳层
│   ├── WindowNativeNode.ets         原结构名保留（ApplicationRoot 直接引用），瘦身为根容器
│   ├── shell/      ExpandedShell.ets  CompactShell.ets  HoverShell.ets  BottomDock.ets
│   └── overlay/    InfoWindow.ets  UnifiedObjectDetailCard.ets  TimeWheel.ets
│                   DockClock.ets  StartupOverlay.ets
├── panels/                   ← 新增：33 个面板，一文件一组件
│   ├── PanelHost.ets                原 panelContent 的 if/else → 表驱动 + 懒加载
│   ├── time/       TimePanel.ets  TimeScrubberSlider.ets  TimeSpeedChips.ets
│   ├── search/     SearchPanel.ets  SearchBar.ets  SearchFilterMenu.ets
│   ├── astro/      AstroPanel.ets  WutTargetCard.ets  ContinuationSection.ets
│   ├── layers/     LayersPanel.ets  LayerPresetBar.ets  HierColumn.ets
│   ├── object/     ObjectPanel.ets  ObjectInspector.ets  ObjectActionBar.ets
│   ├── skyCulture/ Satellite/ Ocular/ Telescope/ Script/ Settings/ Tools/
│   └── Place/ Observers/ Help/ Catalogs/ Commands/ Bookmarks/ Meteors/
├── state/                    ← 新增：@Observed 领域 store（V1）
│   ├── TimeStore.ets  PanelStore.ets  SearchStore.ets  AstroStore.ets
│   ├── SkyViewStore.ets  ObjectStore.ets  SkyCultureStore.ets  SatelliteStore.ets
│   ├── SensorStore.ets  ScriptStore.ets  TelescopeStore.ets  SessionStore.ets
│   └── ToolStore.ets（angle/archaeo/nav/mosaic/pointer/coordinate）
├── bridge/
│   ├── BridgeClient.ets              `libentry.so` 命令桥的唯一出口（封装 callInteractive）
│   └── (后续) time.ts  astro.ts  …    按域的类型化命令方法
├── common/                   ← 已有：PrivacyStartup / StellariumLifecycle / QtAppConstants
│   └── ui/         UiTokens.ets(UI_RADIUS_* / UI_OPTION_ANIMATION_MS)
│                   IconButton.ets  DockButton.ets  SwitchRow.ets  ChipRow.ets  PanelHost 骨架
└── qability/  process/  qabilitystage/   （不动；QAbility、Qt 桥、隐私门控）
```

要点：

- 新增目录由 sync 脚本自动递归镜像，**无需改 `scripts/sync-ohos-build-sources.sh`，无需改 `main_pages.json`**。
- 目录划分依据是第 1.4 节的状态聚类与第 1.3 节的 Builder 体积，不是凭感觉切分。
- `window/` 与 `panels/` 的边界 = 壳层（跨面板常驻）与面板（一次只显示一个）。

---

## 4. 状态策略：V1 `@Observed` store + 子组件

**继续使用 V1，不迁移 V2**（理由见第 8 节）。

### 4.1 基本形态

```ts
// state/TimeStore.ets —— 纯数据 + 纯方法，不 import 任何 UI
@Observed
export class TimeStore {
  observationTimeText: string = ''
  timeRateText: string = ''
  scrubberJd: number = 0
  // …原 @State 字段整体迁入
}
```

```ts
// panels/time/TimePanel.ets —— 只订阅自己需要的 store
@Component
export struct TimePanel {
  @ObjectLink timeStore: TimeStore      // 变更只刷新本组件
  build() { /* 原 time 分支的 builder 内容 */ }
}
```

```ts
// 根容器持有并向子组件传引用（V1 的 @ObjectLink 初始化规则）
// WindowNativeNode 内：
Comp({ timeStore: this.timeStore })
```

### 4.2 规则

1. **一个 store = 一个领域**，与第 3 节 `state/` 目录一一对应；字段名保持不变，便于对照回滚。
2. store 内**不放 UI 代码**，不 import ArkUI 组件，只做数据与纯逻辑（可被单测覆盖）。
3. **刷新范围必须是"订阅者"**：只有 `@ObjectLink` 了该 store 的子组件才重建；
   这是本方案唯一的性能论据来源。
4. **高频链优先隔离**：1 s / 125 ms 时间链、惯性、传感器分别独立成 store，
   与 `panelVisible` 之类的壳层状态彻底分离（对应 L16156 的既有告警）。
5. **不使用 `@Provide/@Consume` 泛化**（当前为 0，保持）；跨层仅在确有主题/常量需求时逐一评估。
6. **过渡手段（已修订，见 §11 修订 1）**：字段搬入 store 后，根 struct **不能**用同名 getter 委托
   —— V1 的 `@Component` 不允许 getter 访问器（ArkTS 转换会丢弃它们，存在运行期崩溃风险）。
   可行做法只有两条：① 调用点机械替换为 `this.timeStore.xxx`（读写都改，编译器全程把关）；
   ② 把该域的 UI 与 store **同步**抽成子组件（`@ObjectLink` 订阅），一步到位。
   由于未加装饰器的 store 字段在 V1 中不会触发宿主重渲染，**单独搬 store 会在搬完那一刻丢失该域的刷新**，
   因此 Phase 3 必须与 Phase 4 的对应面板同步进行，不能先全量搬 store 再补组件。
7. **定时器随域迁移**：每个 store 自带 `start()/stop()`，
   在现有四个生命周期挂点（初始化 / 前台恢复 / 后台 / `aboutToDisappear`）统一收口，
   不再逐个手动接线。

---

## 5. 分阶段迁移计划（绞杀者模式）

原则：每阶段**独立可编译、可装机、可回滚**；纯搬移与功能改动**不混在同一次提交**。

| Phase | 内容 | 规模 | 验收 |
|---|---|---|---|
| **0 基线** | 固化回归契约：33 个 `activePanel`、41 个 `.id()` 锚点、CLI 冒烟清单、构建/装机基线快照，落成可复跑脚本 | 1 天 | 基线快照入库（不入代码库则放 `docs/harmonyos/json/`） |
| **1 纯叶子** | `UI_RADIUS_*` / `UI_OPTION_ANIMATION_MS` → `common/ui/UiTokens.ets`；无状态 builder（iconButton、dockButton、switchRow、chip、面板骨架）→ `common/ui/*.ets` | 3–5 天 | `arkts_check` + 构建 + 装机 + CLI 冒烟 |
| **2 命令桥** | `bridge/BridgeClient.ets` 封装 `callInteractive`（保留同名薄委托），203 个调用点不动 | 2–3 天 | 同上；重点回归命令回包/错误码 |
| **3 状态 store** | **必须与 Phase 4 的对应面板同步进行**（见 §11 修订 1）：逐域把状态与该域 UI 一起抽成 store + 子组件，`TimeStore`+时间面板先行，再 `PanelStore` → `SearchStore` → `AstroStore` → `SkyViewStore` → `ObjectStore` → `SkyCultureStore` → `SatelliteStore` → `SensorStore` → `ScriptStore` → `TelescopeStore` → `SessionStore` → `ToolStore` | 每域 1–3 天，合计 ≈3 周 | **每域 1 次提交**；重点回归该域面板的交互与刷新 |
| **4 面板组件化** | 按 Builder 体积**从大到小**逐面板抽取为 `@Component`；`panelContent` 改 `PanelHost` 表驱动 + 懒加载 | 每面板 0.5–2 天，合计 ≈3–4 周 | **每面板 1 次提交**；回归该面板全部交互 + 平板/手机断点 |
| **5 Overlay** | 信息窗、详情卡、时间轮、Dock 时钟 → `window/overlay/` | 1 周 | 叠放顺序 / zIndex / HitTestMode 回归（按 `specs/UI-ARCHITECTURE.md` §3 §6） |
| **6 壳层** | expanded / compact / hover 三壳 + bottomDock → `window/shell/` | 1–2 周 | 断点切换（短边 520 / 700 / 900×520）、折叠半折角、220 ms 转场回归 |
| **7 收口** | 删除过渡 getter 与死代码；更新 `specs/UI-ARCHITECTURE.md` 与根 `AGENTS.md`（记录 pages/ 重构后的 UI 结构约定） | 1 周 | 全量回归 + 文档校准 |

**总估时：约 9–12 周**（按每阶段完成后向用户汇报、批准后提交的节奏）。

### 5.1 每阶段统一验收矩阵

| 检查 | 手段 | 通过标准 |
|---|---|---|
| ArkTS 静态 | `arkts_check` | 无 error |
| 编译 | `devecocli build` | BUILD SUCCESSFUL |
| 装机 | install + start | 均成功 |
| 交互冒烟 | 语义 CLI（按 `DEVELOPMENT-MCP-WORKFLOW.md`，**不用坐标点击**） | 关键命令返回正常 |
| 契约 | 33 panel id / 41 个 `.id()` 锚点比对 | 完全一致 |
| 视觉 | 仅在改布局时按 `AGENTS.md` §7.9 | 构建+安装+启动成功即为通过 |
| 回滚 | 每阶段一个提交点 | `git revert` 单次即可回退 |

---

## 6. 不变式与约束（硬性）

1. **行为零变更。** 重构阶段不改任何用户可见行为；发现的问题单独提 issue，不顺手修。
2. **`.id()` 字符串保持稳定**（uitest 依赖：`test-ohos-model-scroll.mjs`、`test-ohos-search-browser.mjs`）。
3. **CLI 命令面不变**（`CLI.md` 契约）；`callInteractive` 的 payload / 返回结构不变。
4. **`main_pages.json` 不变**；`ApplicationRoot` 仍是主窗口唯一 `@Entry`。
5. **保持 V1，禁止 V1/V2 混用**（避免双重代理）。
6. **`LocalStorage` 不动**——它是 Qt 互操作桥面（第 1.5 节），迁移即破坏 C++ 契约。
7. **38 个定时器**的启动/停止时机与现状一致；迁移后用 store 的 `start/stop` 收口并逐一核对生命周期。
8. **产品级面板归属与导航**服从 `PANEL-PLUGIN-ARCHITECTURE-ROADMAP.md` 的收口规则。
9. 注释沿用项目既有中文风格；不新增无关注释。

---

## 7. 风险登记

| 风险 | 影响 | 对策 |
|---|---|---|
| V1 `@Observed` 只观测第一层属性，嵌套对象深层修改不刷新 | 面板局部不刷新（**静默 bug**） | 实测本仓库 `this.X.y =`（状态字段上的就地属性赋值）**为 0 处**，3,259 处赋值里 1,028 个字段全是整体替换 → 风险本就极低；仍需对 37 个数组型 + 13 个自定义类型字段逐个确认 |
| `@ObjectLink` 不能在子组件内重新赋值；父传子需传引用 | 编译报错 / 运行期行为异常 | 统一"父持有 store，子 `@ObjectLink` 只读引用，修改回落 store 方法" |
| 定时器迁移漏 stop | 后台耗电 / 定时器叠加 | store 自带 `start/stop`；四个生命周期挂点统一收口；装机后核对前台/后台往返 |
| 41 个 `.id()` 锚点被误改 | uitest 失效 | Phase 0 固化锚点快照，每阶段比对 |
| 面板体积大（如 `searchFilterMenu` 3,441 行）抽取期间产生大量 diff | 评审困难、回滚粒度粗 | 一面板一提交；纯搬移不掺功能改动 |
| `AppStorage` 17 个 key 在 5 个文件间共享（含 `QAbility` 启动链） | 迁移期状态不同步 | 本方案**不动 AppStorage**（保持 V1）；仅在将来迁 V2 时统一处理（见第 8 节） |
| `specs/UI-ARCHITECTURE.md` 内大量 `文件:行号` 引用 | 重构后文档失真 | Phase 7 统一校正；期间在 CHANGELOG 注明行号漂移 |

---

## 8. 备选方案与否决理由

### 8.1 大爆炸重写（否决）

一次性重写 32,774 行，回归面覆盖 33 个面板 + 4 个 `@Entry` + C++ 桥接 + 隐私启动链，
无法提供可编译的中间态，失败即全量回滚。**否决。**

### 8.2 迁移到状态管理 V2（当前否决）

按官方 `V1-V2迁移概述` 的能力对照表，对本仓库逐项实测：

| 迁移项 | 官方映射 | 本仓库实测 | 成本 |
|---|---|---|---|
| `@Component` → `@ComponentV2` | 1:1 | 全应用 **8 个** `@Component`，**0 个** `@ComponentV2` | 小 |
| `@State` → `@Local` | 1:1 | **1,047 个**，其中 948 个是 `number/string/boolean` | 小（近似纯改名） |
| `@Link` → `@Param`+`@Event` | 官方最大痛点 | **0 个** | 不存在 |
| `@Prop` / `@Provide` / `@Consume` / `@Observed` / `@ObjectLink` / `@Track` | 各有映射 | **全为 0** | 不存在 |
| `$$` / `@BuilderParam` / `LazyForEach` | — | **全为 0** | 不存在 |
| `@Watch` → `@Monitor` | 语义有差异（V2 一次事件内多次变化只触发一次；`@Monitor` 可取变化前后值） | 全应用 8 个（主文件 2 个） | 小，需行为回归 |
| `AppStorage` → `AppStorageV2` | **两套独立存储**，互不相通 | 17 个 key 散在 5 个文件（含 `QAbility` 写入方与 `ApplicationRoot` 启动门控） | **中等，主要风险点** |
| `LocalStorage` → `@ObservedV2/@Trace` | — | 本工程为 **Qt 互操作桥面**（`loadContent(path, storage)`、`makeNewLocalStorage`） | **不可迁移** |
| `ForEach` → `Repeat` | 推荐非强制 | 169 处，V2 下 `ForEach` 仍可用 | 0（可选优化） |

**有利事实（实测）：**
- 状态字段上 `this.X.y =`（就地修改对象属性）为 **0 处**；3,259 处赋值中 **1,028 个字段**为整体替换。
  V2 最典型的坑（深层属性修改不触发刷新，需补 `@ObservedV2`+`@Trace`）在本仓库**不存在**。
- 90.5% 的状态字段是原始类型，`@State` → `@Local` 语义等价。

**否决理由（按权重排序）：**
1. **一个 struct 不能一半 V1 一半 V2**（编译报错）。32,774 行里的 1,047 个状态**只能同时翻代**，
   没有可编译中间态；这是唯一的、也是最大的风险，与"改名便宜"无关。
2. **迁 V2 不减少一行代码**：文件仍是 32,774 行、仍是 1 个组件、仍是全量重排。
   它解决的是"深层观测 / 属性级更新"，而本仓库这两点恰好都没在用。
3. **`AppStorage` ↔ `AppStorageV2` 互不相通**，而 `QAbility`（Ability，无装饰器）
   与 `ApplicationRoot` 共享这些 key，过渡期必须引入 `enableV2Compatibility` /
   `makeV1Observed` 临时胶水。
4. 官方指引：*"对于已使用 V1 的应用，如果 V1 的功能和性能满足需求，无需立即切换至 V2。"*

**估时对比：** 直接迁 V2 ≈ **2–3 周**（2–4 天翻代 + 2–3 天存储迁移 + 3–7 天数组/类字段审计 + 3–5 天全量回归），
且为**一次不可分割的大提交**。

**正确顺序：** 先按本方案拆分（保持 V1），再按模块逐个翻 V2。
拆分后每个面板/壳层是独立文件、独立组件，可单文件翻代、单次提交、单独回归，
把"2–3 周不可分割的大爆炸"变成十几次几分钟的小提交。**若现在先迁 V2，等于在单 struct 上做原子手术，
收益为零、风险最大。**

### 8.3 纯文件切分 / 仅拆 `@Builder` 函数（否决）

见第 2 节第 3、4 条：切完仍是同一 `struct`、同一 `this`、同一棵子树；
`@Builder` 参数按值捕获，拆函数不产生组件边界，也不缩小刷新范围。
**无收益，否决。**

---

## 9. 附录：复现命令

```powershell
# 体量
(Get-Content harmonyos\ets-source\pages\MainWindowNativeNode.ets).Count

# 装饰器与结构统计（主文件）
$c = Get-Content harmonyos\ets-source\pages\MainWindowNativeNode.ets -Raw
([regex]::Matches($c,'@State\s+(?:private\s+)?\w+\s*:')).Count     # 1047
([regex]::Matches($c,'(?m)^  @Builder\s*$')).Count                 # 145
([regex]::Matches($c,'@Observed|@ObjectLink|@Link|@Prop\b')).Count # 0
([regex]::Matches($c,'this\.\w+\.\w+\s*=(?!=)')).Count             # 3（命中状态字段 0）
([regex]::Matches($c,'this\.\w+\s*=(?!=)')).Count                  # 3259

# 面板清单
[regex]::Matches($c,"activePanel\s*===?\s*'(\w+)'") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

# 跨文件存储分布
Get-ChildItem harmonyos\ets-source -Recurse -File -Include *.ets,*.ts |
  ForEach-Object { $t = Get-Content $_.FullName -Raw
    "{0}: AppStorage={1} StorageLink={2} LocalStorage={3}" -f $_.Name,
      ([regex]::Matches($t,'AppStorage\.')).Count,
      ([regex]::Matches($t,'@Storage(Link|Prop)')).Count,
      ([regex]::Matches($t,'LocalStorage')).Count }

# 同步脚本行为（整树递归镜像）
Select-String -Path scripts\sync-ohos-build-sources.sh -Pattern 'find .* -type f'
```

---

## 10. 下一步

1. 用户评审本文；确认范围、阶段划分与是否接受"不做 V2 迁移"。
2. 评审通过后执行 Phase 0（固化回归契约），再从 Phase 1 开始逐阶段推进。
3. 每阶段完成后汇报，**按 `AGENTS.md` §2.6 由用户明确要求后才提交**。

---

## 11. 执行记录与修订（2026-09-30）

用户授权无人值守推进后，已按计划完成以下切片，每片均经 `arkts_check` + 构建 + 模拟器安装启动 + 契约校验后独立提交：

| 切片 | 内容 | 提交 |
|---|---|---|
| Phase 0 | `scripts/check-ohos-ui-contract.mjs` + `docs/harmonyos/json/ui-contract-baseline.json`（33 面板 / 22 静态 id / 17 动态前缀 / 41 锚点） | `405666e626` |
| Phase 1a | `common/ui/UiTokens.ets`（5 个视觉常量，856 处引用不变） | `f65357f8fa` |
| Phase 1b | `common/ui/ShellIcons.ets`（纯函数 `getIcon`，61 处调用点去掉 `this.`） | `5b97eb9b07` |
| Phase 2 | `bridge/BridgeClient.ets`（`request`/`send`/`requestWhenReady`/`requestInteractive`，单体只留薄委托，`libentry.so` 导入移出单体） | `307108f331` |
| Phase 1c | `pages/MainWindowModels.ets`（93 个文件作用域类型/常量，764 行） | `f56751e66e` |

单体行数：**32,705 → 31,961**（净减 744 行；新增 4 个职责单一的文件）。

### 修订 1（重要，推翻原 §4.2 第 6 条）：V1 的 `@Component` 不能用 getter 委托

原方案设想「字段搬入 store 后，根 struct 用同名 getter 委托，调用点零改动」。实测不可行：
V1 `@Component` **不允许 getter 访问器**（ArkTS 转换会丢弃，存在运行期崩溃风险）。同时，
未加装饰器的 store 字段不会触发宿主重渲染，因此**单独搬 store 会让该域失去刷新**。
→ Phase 3 必须与 Phase 4 的对应面板**同步**进行；或采用「调用点机械替换为 `this.store.xxx`」，
由编译器全程把关。§4.2 第 6 条与 §5 表格已按此修订。

### 修订 2：Phase 1 的"无状态 builder"实测多为有状态

`dockButton` 依赖 `isExpandedLayout`、`compactDockIconSize()`、`dockActionActive()`、
`handleDockTouch()`、`activateDockAction()`；`switchRow` 依赖 `actionId`/`cmd` 与宿主回调；
`iconButton` 仅 1 处调用、28 行。三者均不属于无状态叶子，其组件化并入 Phase 4/6，
避免先生成一次会被 store 化推翻的组件。Phase 1 以 UiTokens / ShellIcons / MainWindowModels 三个纯叶子切片收口。

### 修订 3：验收矩阵需要补真机

x86_64 模拟器的 UI-only 通道（见 CHANGELOG 2026-09-30 条目）能验证布局、文案、面板开关与交互，
但**星图与引擎相关状态全部不可验**（`libstellarium.so`/`libQt6*.so` 无 x86_64 构建，时间面板显示 `--`）。
因此 store 与面板阶段的验收矩阵必须包含**真机（Mate 80 Pro）复验**，模拟器只作为快速结构回归。

### 修订 6：系统性死代码普查（39 个不可达方法，约 469 行）与"疑似漏接线"清单

Phase 3h/3i 做了两轮死代码清理，方法可复现：本 struct 的方法**全为 `private`**，因此"文件内零引用 = 不可达"。
对 1,090 个 `private` 方法统计 `this.<name>(`、裸引用 `this.<name>`、字符串 `'<name>'` 三种形式，
排除框架生命周期方法与两个 `@Watch` 按名调用的方法后，**39 个方法三种引用全为 0**（删除后 −498 行，含空行）。
可复现命令见 CHANGELOG 2026-09-30 的 Phase 3h/3i 条目。

**需要产品复核的"疑似漏接线"项**（删除不改变行为，但可能掩盖了未接的意图——若本应接线，应作为**功能缺陷**单独处理）：

| 组 | 方法 | 推测的原意 |
|---|---|---|
| 陀螺仪（7 个，约 197 行） | `onRotationVectorData`(119) / `gyroForwardFromGravityAndMagnetic` / `gyroSlerpUnitVector` / `alignGyroToMagneticNorth` / `gyroParallelTransportUp` / `calibrateGyroscopeQuaternionUnused` / `gyroEffectiveAzOffset` | 传感器回调未注册 |
| 对象卡片定位（4 个，约 103 行） | `placeObjectCardAwayFromTarget`(53) / `easeSelectedObjectTo`(36) / `placeSelectedObjectInCompactSafeArea` / `placeSelectedObjectInExpandedSafeArea` | 卡片避让/缓动未接 |
| 功能入口（4 个） | `pauseScript` / `resumeScript` / `toggleTracking` / `triggerAutoLocate` | 入口未接 |
| 时间相关（3 个） | `advanceTimeWheel` / `setTimeNow` / `adjustTime` | 被时间轮/快捷行取代 |
| 其余（21 个） | 抽屉/信息窗几何、`nm`、`tickPercent`、`skyCulture*FilterIndex`、`defaultSkyCultureMakerDraft` 等 | 多为被后续实现取代的旧版本 |

**探查工具（可复用，已扩展到四类判据）：** 本轮的判据 + 三形式引用统计，可作为**每个 Phase 4 面板切片的前置自检**，
先把该面板区域内的死代码清掉再搬迁，避免把死代码带进新结构。四类判据与实测产出：

| 判据 | 做法 | 本轮产出 |
|---|---|---|
| 不可达方法 | `private` 方法在文件内 `this.<name>(`、裸 `this.<name>`、字符串 `'<name>'` 三种引用全 0（排除生命周期与 `@Watch` 目标） | 48 个（首轮 39 + 级联 9），约 500 行 |
| 零调用 `@Builder` | `this.<name>(` 调用点为 0，并核对标识符全文件出现次数以排除同名前缀干扰 | 13 个（含 `tabletObjectInspector`、`railShell`、`padExploreHome` 等旧抽屉/平板布局变体），约 519 行 |
| 零引用字段 | `this.<name>` 引用全 0（含未写未读） | 31 个（FPS 残留、旧陀螺仪锚定量、旧面板开关等） |
| 级联复扫 | 每轮删除后重扫，直到无新增 | 3 轮收敛；暴露出"按步进推进时间"整条支路（`advanceTimeWheel` → `startTimeWheelTransition`）在清理前已不可达 |

**两条删除脚本的硬性要求（都已踩过）：**
① **单行方法必须特判**（`private f(): T { return x }`），否则以"下一个 `\n  }\n`"为结束标记会越过边界、连带删除相邻成员（首轮误删 `drawerWidth` / `onRailTap`，被构建报错捕获）；
② **删字段必须连同其上方独立装饰器行一起删**（否则留下孤立 `@StorageLink(...)` 叠加到下一个属性，报 `cannot have multiple state management decorators`）。
两者都必须由 `arkts_check` + 构建兜底。

### 修订 5：时间轮的"交互控制器"留在宿主是刻意取舍，后续按注入式拆分

> **状态更新（2026-09-30，Phase 3m）：已完成拆分。** 下文描述的方案已落地为 `state/TimeWheelController.ets`
> （普通类，非 `@Observed`；14 个手势草稿字段 + 1 个惯性定时器 + `start/stop`）。
> 三个注入点按计划实现：`onSeek(jd)`（宿主 `callNativeFire('setTimeToJD')`）、`onStopSpeed()`（宿主 `stopTimeWheelSpeed()`，写速度域）、
> `getUtcOffsetHours()`（宿主只读 getter）。宿主只剩 `wheel()` 懒初始化 + 5 处调用转发 + 3 个生命周期 `stop()` 收口。
> 顺带删除：**从未被启动**的过渡定时器与 `timeWheelTargetMs`、`finishTimeWheelTransition()`（其唯一启动者 `advanceTimeWheel` 已在 Phase 3j 作为死代码删除）。
> 同批完成的速度域迁移见下方"速度/速率域"。

Phase 3g 把时间转轴/时间轮的**状态与视图**迁出（`TimeWheelStore` + `TimeWheelScrubber`），
但把**交互逻辑整体留在宿主**，位置与规模（实测）：

- 方法 13 个，`pages/MainWindowNativeNode.ets` **L11910–L12149，约 228 行**：
  `selectTimeWheelUnit` / `applyTimeWheelDate` / `setTimeWheelStopped` / `startTimeWheelTransition` /
  `finishTimeWheelTransition` / `stopTimeWheelInertia` / `startTimeWheelInertia` / `advanceTimeWheel` /
  `timeWheelVelocityMultiplier` / `rebaseTimeWheelTrack` / `rebaseTimeWheelTrackAtCenter` /
  `handleTimeWheelTouch` / `syncTimeWheelFromSimulation`。
- 配套**普通（非 `@State`）字段 16 个 + 2 个定时器句柄**，L324–L339（手势草稿量、惯性/过渡状态、定时器）。

**为什么这次必须留在宿主（4 条实证理由）：**

1. **跨域写入**：`setTimeWheelStopped()` 写速度域（`timeStore.timeSpeedIndex` / `pendingTimeRate` / `timeRateText`）→ 搬它需先搬速度域。
2. **触碰引擎**：`applyTimeWheelDate()` 调 `callNativeFire('setTimeToJD', …)` 且依赖宿主 `utcOffsetHours`；桥是宿主职责（单一出口 `BridgeClient`），store 不应碰 NAPI。
3. **定时器需生命周期托管**：12 ms 过渡 + 16 ms 惯性两个 `setInterval`，今天搭在宿主既有的「面板关闭 / 后台 / `aboutToDisappear`」收口上；搬走需新增 `start()/stop()` 并重挂这些点，**漏停会导致后台仍在跑定时器并向引擎推时间**。
4. **草稿量不该可观测**：那 16 个字段每个触摸采样都在变；放进 `@Observed` 会让**每次采样触发通知与重渲染**（性能与语义都不对）。因此"可观测数据在 store、不可观测草稿与行为在宿主"是正确的切分。

**后续拆分方案（推荐在速度域迁移之后执行，作为独立切片）：**

```
state/TimeWheelStore.ets          ← 只留可观测数据 + 纯计算（现状已达成）
state/TimeWheelController.ets     ← 新增：普通类（非 @Observed），持有 16 个草稿字段
                                     + 2 个定时器 + 上述 13 个方法 + start()/stop()
panels/time/TimeWheelScrubber.ets ← 视图（现状已达成）
```

三个注入点（把跨域依赖从宿主剥出，store 与控制器都不碰引擎）：

| 依赖 | 注入方式 | 今天的落点 |
|---|---|---|
| 引擎推送 | `onSeek(jd: number): void` | 宿主 `callNativeFire('setTimeToJD')` |
| 暂停速度 | `onStopSpeed(): void` | 宿主 `setTimeWheelStopped()` |
| UTC 偏移 | `utcOffsetHours` 只读传入 / getter | 宿主字段 |

**验收要求**：拖动 + 惯性 + 过渡照旧；面板关闭后无残留定时器；切后台/回前台不丢同步（真机日志确认 `setTimeToJD` 推送已停）。
**估时/风险**：1 片（约半天），风险集中在定时器生命周期，**不改任何交互逻辑**。

### 修订 4（已由真机实验定论）：真正的冻结根因是"参数化 @Builder 按值捕获"，`@ObjectLink`/`@Prop` 实时更新正常

2026-09-30 在**真机 Mate 80 Pro（引擎存活）**上做了三版对照实验，同一交互（打开时间面板 → 点「快进」）：

| 版本 | 副标题 | 「快进」chip 标签 | 结论 |
|---|---|---|---|
| 原生实现（`@State` + 参数化 `@Builder speedChip(...)`） | `2x` / `10x` | 始终「快进」，未高亮 | **既有 bug**（重开面板才更新） |
| `TimeStore` + `TimeSpeedChips`，chip 仍走参数化 `@Builder` | `2x` / `10x` | 始终「快进」 | 与原生**行为等价**（继承同一 bug） |
| `TimeStore` + `TimeSpeedChips`，**chip 内容内联、直接读 store** | `2x` → `10x` | **「快进 2x」→「快进 10x」实时更新且高亮** | **修复 bug**，且证明 store 通路正确 |

结论：

1. **根因**：`@Builder speedChip(id, label, icon, active)` 的简单类型参数**按值捕获**，其子树首帧后即冻结，
   状态变化不会触发该子树更新（与 §2 根因分析一致）。这与"组件是否创建在 `@Builder` 体内"无关。
2. **修正此前（同一轮内）的推断**：曾据模拟器实验怀疑"`panelContent()` 体内创建的子组件拿不到更新"，
   真机三版对照已推翻该推断——`@ObjectLink`（store 字段变化）与 `@Prop`（`rateText` 由父更新）
   **都能实时驱动子组件重渲染**；此前两版"不更新"完全由内层参数化 `@Builder` 冻结造成。
3. **对方案的影响**：
   - (b) 方案（store + 组件）成立，**且能顺带修掉既有冻结 bug**；
   - Phase 3 不必等 Phase 4 的 `PanelHost`；
   - **但每个被搬迁的 builder 都必须去掉"参数化 @Builder 冻结"这一模式**：要么内联直接读状态，
     要么改为子组件（`@Prop`），不能保留原来的参数化 `@Builder` 包一层。
   - 这条要写进后续每个切片的自检项：搬迁后必须实测"点击后是否实时更新"，而不只看布局是否一致。
4. 该实验同时证明：**UI-only 模拟器不适合裁决此类刷新问题**（无引擎数据、定时器不产生写入，
   原生与重构版都会呈现"不刷新"），刷新类验收必须在真机做。

---

## 12. 附录：本轮死代码清理逐项清单（2026-09-30，三次提交）

数据由 `git diff --unified=0 <rev>^ <rev> -- harmonyos/ets-source/pages/MainWindowNativeNode.ets` 提取；
"原行号"为删除前文件中的行号。相邻条目在 diff 中会被合并计为一个区块（下表按区块列出，备注已标注合并项）。
**用户已确认：其中相当一部分是用户本人有意删除的历史代码**，因此下表仅作为"已移除内容"的存档，不再作为缺陷线索。

### 12.1 Phase 3h —— 旧转轴（滑杆）死子系统（提交 `e2f0c6f7e9`，−126 行）

| 区块原行号 | 行数 | 内容 |
|---|---|---|
| L307 | 2 | `scrubberValue` / `scrubberLabel`（均为 `@State`，只写不读） |
| L311 | 5 | `scrubberReferenceJd` / `scrubberPendingOffset` / `scrubberAnchorPending` / `scrubberLastSendMs` / `scrubberInteracting` |
| L323 | 1 | `timeMarkLoading` 由 `@State` 降为普通字段（仅重入守卫，不参与渲染） |
| L11799 | 111 | `updateScrubberLabel` / `beginScrubberInteraction` / `sendScrubberTime` / `applyScrubber` / `syncScrubberToSimulation` / `resetScrubberToRealtime`（入口 `applyScrubber` 无任何调用者） |

> 附带性能收益：两个被删 `@State` 原由 `syncScrubberToSimulation` 在每次模拟时间刷新时写入 → 每次写都扩大重渲染范围。

### 12.2 Phase 3i —— 39 个零引用 `private` 方法（提交 `3301201ef0`，−498 行）

| 原行号 | 行数 | 名称 | 类别 |
|---|---|---|---|
| L1590 | 1 | `drawerLeft`（单行方法） | 抽屉几何 |
| L2386 | 7 | `triggerAutoLocate` | 功能入口 |
| L3197 | 6 | `runOnTouchUp` | 触摸工具 |
| L4143 | 8 | `pauseScript` + `resumeScript`（合并计） | 脚本 |
| L4979 | 3 | `cycleOcular` | 目镜 |
| L5941 | 16 | `adjustTime`（+ `setTimeNow` 合并计） | 时间 |
| L9001 | 4 | `skyCultureRangeModeIndex` | 星空文化 |
| L9045 | 6 | `skyCultureClassificationFilterIndex` | 星空文化 |
| L9066 | 11 | `skyCultureRegionFilterIndex` | 星空文化 |
| L10018 | 18 | `defaultSkyCultureMakerDraft` | 星空文化编辑 |
| L10639 | 4 | `pluginFeaturePanel` | 插件 |
| L11719 | 4 | `tickPercent` | 工具 |
| L11904 | 22 | `advanceTimeWheel` | 时间轮 |
| L13288 | 22 | `gyroSlerpUnitVector` | 陀螺仪旧数学 |
| L13313 | 11 | `gyroParallelTransportUp`（+ `alignGyroToMagneticNorth` 合并计） | 陀螺仪旧数学 |
| L13339 | 11 | `calibrateGyroscopeQuaternionUnused` | 陀螺仪旧数学 |
| L13443 | 23 | `gyroForwardFromGravityAndMagnetic` | 陀螺仪旧数学 |
| L13528 | 17 | `gyroEffectiveAzOffset` | 陀螺仪旧数学 |
| L13671 | 119 | `onRotationVectorData`（旧版旋转回调） | 陀螺仪旧路径 |
| L13861 | 5 | `isConstellationSelection` | 命中判断 |
| L14081 | 54 | `placeObjectCardAwayFromTarget` | 对象卡片布局 |
| L14583 | 8 | `placeSelectedObjectInCompactSafeArea`（+ `placeSelectedObjectInExpandedSafeArea` 合并计） | 对象卡片布局 |
| L14608 | 45 | `easeSelectedObjectTo` | 对象卡片动效 |
| L17172 | 9 | `handleFloatingPanelTouch` | 面板触摸 |
| L18764 | 13 | `infoWinLeft`（+ `infoWinWidth` 合并计） | 信息窗几何 |
| L18818 | 4 | `toggleTracking` | 功能入口 |
| L18948 | 8 | `bottomCardSwiperHeight`（+ `bottomCardHitHeight` 合并计） | 卡片几何 |
| L19101 | 7 | `isTabletObjectInspectorPoint` | 命中判断 |
| L19292 | 20 | `isCompactDrawerPoint`（+ `handleCompactMoreTap` 合并计） | 命中判断 |
| L19892 | 5 | `objectInspectorFileUri` | 文件路径 |
| L21537 | 3 | `nm` | 旧配色助手 |
| L21603 | 4 | `trackStatusZh` | 文案 |

> 活路径对照（用户已验证功能正常）：陀螺仪走 `gyroRotationCallback` / `gyroGravityCallback` / `gyroMagneticCallback` / `onOrientationData`（L12605–L12702）。

### 12.3 Phase 3j —— 13 个零调用 `@Builder` + 31 个零引用字段 + 级联 9 方法（提交 `f82b483d2e`，−650 行）

**A. 零调用 `@Builder`（11 个区块合并计 13 个方法，约 519 行）**

| 原行号 | 行数 | 名称 |
|---|---|---|
| L18157 | 43 | `compactObjectPeek`（+ `compactQuickControls` 合并计） |
| L18604 | 19 | `objectActionBar` |
| L19232 | 39 | `expandedObjectSummary` |
| L19273 | 119 | `tabletObjectInspector` |
| L20776 | 93 | `objInfoFloat`（+ `observerBadge` 合并计） |
| L20939 | 36 | `railShell` |
| L21804 | 29 | `collapseButton` |
| L22363 | 39 | `padExploreHome` |
| L22552 | 25 | `smallRoundButton` |
| L28979 | 24 | `detailInfoRow` |
| L29028 | 53 | `configurationSkyDisplaySettings` |

**B. 零引用字段（31 个，多为 1 行）**

| 原行号 | 行数 | 内容 |
|---|---|---|
| L73 | 2 | `startupPreparing`（含其独立 `@StorageLink(...)` 装饰器行） |
| L285 | 4 | `fpsDisplay` / `fpsFrameCount` / `fpsLastTime` / `fpsVisible` |
| L342 | 1 | `autoLocateStarted` |
| L1050 | 1 | `scriptPanelScroller` |
| L1392 | 1 | `expandedTargetPlacementTimer` |
| L1453 | 1 | `gyroLastDiagnosticMs` |
| L12801 | 5 | `gyroReferenceAz` / `gyroReferenceAlt` / `gyroReferenceViewAz` / `gyroReferenceViewAlt`（+1） |
| L12820 | 4 | `gyroAnchorQuat` / `gyroAnchorUp` / `gyroAnchorFwd` / `gyroAnchorValid` |
| — | 各 1 | `visibleConstellations` / `infoTextExpanded` / `centerSearchText` / `tonightPlanets` / `lightPollution` / `asteroidLines` / `asteroidLabels` / `nightViewTab` / `showConfigPanel` / `showAstroPanel` / `showHelpPanel` / `timeScale` / `railCollapsed` / `gyroHeadingSyncInFlight` |

**C. 级联不可达方法（3 轮收敛，9 个）**

| 原行号 | 行数 | 名称 |
|---|---|---|
| L11734 | 27 | `startTimeWheelTransition`（唯一调用者是同批已删的 `advanceTimeWheel`） |
| L13122 | 6 | `gyroAltAzVector` |
| L13187 | 3 | `gyroEnuFromBridge` |
| L13200 | 40 | `syncGyroAnchor` |
| L13657 | 5 | `rectsOverlap` |
| L14713 | 9 | `pad2` |
| L18330 | 3 | `infoWinDetailH` |
| L19396 | 6 | `objectInspectorSubtitle` |

### 12.4 汇总

| 提交 | 删除行数 | 方法 | Builder | 字段 |
|---|---|---|---|---|
| `e2f0c6f7e9`（3h） | 126 | 6 | 0 | 7（+1 降级） |
| `3301201ef0`（3i） | 498 | 39 | 0 | 0 |
| `f82b483d2e`（3j） | 650 | 9（级联） | 13 | 31（+1 孤立装饰器行） |
| **合计** | **1,274** | **54** | **13** | **39** |

单体行数 32,705 → 30,229。

### 12.5 附：被移除功能块的来龙去脉（git 考古）

方法：`git log -S <标识符> -- harmonyos/ets-source/pages/MainWindowNativeNode.ets` 会列出**该标识符出现次数发生变化的每一次提交**；
序列的**最后一个**（我方的删除提交之外）就是它**失去调用点（失活）**的时刻，其提交信息通常说明了替代者。

#### 模式一：出生即死（引入提交本身就没接线）

| 标识符 | 引入 | 引入提交主题 |
|---|---|---|
| `updateScrubberLabel` | 2026-07-31 | `aa2b2b384f` refine offline HarmonyOS observation controls |
| `easeSelectedObjectTo` | 2026-07-31 | 同上 |
| `syncGyroAnchor` | 2026-07-31 | 同上 |
| `onRotationVectorData` | 2026-07-31 | 同上 |
| `detailInfoRow` | 2026-07-28 | `cb7bf253c6` checkpoint offline HarmonyOS candidate |
| `compactQuickControls` | 2026-07-28 | 同上 |
| `advanceTimeWheel` | 2026-08-11 | `969cd1b33d` stabilize AstroCalc selection flows（连同 `startTimeWheelTransition` 一起，故"按步进推进时间"整条支路从未可用） |

#### 模式二：短命试验（引入后 1–3 天即被替换）

| 标识符 | 引入 | 失活 | 存活 |
|---|---|---|---|
| `objInfoFloat`（选中天体浮动详情窗，93 行） | 2026-07-25 `e1f06f17de` | 2026-07-26 `4d4ae41768` | **1 天** |
| `infoWinLeft`/`infoWinWidth`（浮窗几何） | 2026-07-25 | 2026-07-27 `ba34693f4e` | 2 天 |
| `objectActionBar`（19 行） | 2026-08-29 `9ffed5f759` | 2026-08-30 `eabe2f1c5d` | **1 天** |
| `configurationSkyDisplaySettings`（53 行） | 2026-08-30 `eabe2f1c5d` | 2026-08-31 `626cefea53` | **1 天** |
| `collapseButton`（29 行） | 2026-07-25 `6733da1103` | 2026-07-27 `ba34693f4e` | 2 天 |
| `observerBadge` / `smallRoundButton` | 2026-07-21 `947a1892f3` | 2026-07-28 `cb7bf253c6` | ~7 天 |
| `setTimeNow` / `adjustTime` | 2026-07-22 `0e89bd5ca5` | 2026-07-31 `aa2b2b384f` | ~9 天 |
| `pauseScript` / `resumeScript` | 2026-07-27 `ba34693f4e` | 2026-08-28 `68f9a05be3`（"compact script controls"） | ~1 月 |
| `triggerAutoLocate` | 2026-07-25 `b8dc048eff`（本功能提交） | 2026-08-21 `9a8dd78731` | ~1 月 |

#### 模式三：整代 UI 被替换（替代者可在"失活提交"里定位）

| 家族 | 引入 | 失活（=替代者登场） | 替代者 |
|---|---|---|---|
| **对象详情**（`tabletObjectInspector` 119 行 / `objInfoFloat` 93 / `compactObjectPeek` 43 / `expandedObjectSummary` 39 / `objectActionBar` 19 / `isTabletObjectInspectorPoint` 7 / `toggleTracking` 4） | 08-27 `8cb728a488`（引入平板检查器 + `structuredObjectDetails`/`tabletInspectorMedia`）→ 08-29 `9ffed5f759`（加 peek/动作条 + `selectedLiveInfoRows`） | **08-30 `eabe2f1c5d`**（complete CLI regression and UX audit） | 同一次提交引入 **`unifiedObjectDetailCard`** —— 四套详情变体一同失去调用者 |
| **时间控制**（旧滑杆子系统：`applyScrubber`/`beginScrubberInteraction`/`sendScrubberTime`/`syncScrubberToSimulation`/`resetScrubberToRealtime` 等 117 行 + `scrubberReferenceJd` 等 7 字段） | 07-30 `f87310fbc0`（complete time control redesign — Sky Guide style，同批引入 `timeScrubberSlider`） | 08-11 `969cd1b33d` | `timeScrubberSlider`（字段行 + 刻度轮），即今天的 `TimeWheelScrubber` |
| **左栏 / 抽屉**（`railShell` 36 行） | 07-23 `a9349c9a8e`（星表下载 ArkTS 界面） | 08-22 `ad2a423575` | `expandedShell` 内的常驻侧栏 |
| 抽屉/卡片几何（`drawerLeft`、`drawerWidth` 旁系等） | 07-28 `cb7bf253c6` | 08-28 `68f9a05be3` | 同上 |
| **平板探索首页**（`padExploreHome` 39 行） | 08-22 `ad2a423575` | 09-06 `6245c85b07`（offload detail model rendering…） | 统一后的对象详情/检查器路径 |
| **星空文化筛选索引**（`skyCultureRangeModeIndex`/`ClassificationFilterIndex`/`RegionFilterIndex`） | 08-21 `9a8dd78731`（complete sky culture filtering） | 08-22 `ad2a423575` | 新的筛选状态字段与面板 |
| **配色助手 `nm()`** | 07-21 `947a1892f3` 起被 84 次提交广泛使用 | **由本方案自己的迁移 3d–3g 逐步抽走调用点**（搬进组件后改用 `nmText()`/`@Prop` 传色），最后由 3j 删除 | `nmText()`/`nmSub()`/`nmAccent()` + 组件 `@Prop` 颜色 |

#### 结论与三条可执行改进

1. **堆积的成因：** 本项目 UI 迭代极快（7/21–9/06 期间对象详情就换了三代），每次改版只改"接线"，旧的 `@Builder`/方法留在原地并连同其设计注释一起变成"注释还在、代码已死"的僵尸块。
2. **`nm()` 的教训值得记：** 它在很长一段时间里是**活代码**，是被本方案的迁移抽空了调用者才变成死代码 —— 说明"死代码"是动态状态，**迁移/重构本身也会制造新的死代码**，因此每片迁移后必须复扫（这也是 3j 采用"级联复扫直到收敛"的原因）。
3. **流程建议（已可落地）：** ① 每个改动面板的功能提交里，顺手删掉被替换的旧 builder（改动者最清楚替代关系）；② 本方案 Phase 4 的"每面板前置死代码自检"（§11 修订 6 的四类判据）正好兜住这类堆积；③ 删除时**连同其设计注释一起删**，需要保留的设计意图应移入文档而不是留在代码里。

---

## 13. 续作操作手册（任何后续会话/Agent 都可照此独立推进）

本节把本轮全部**实测结论**固化为可执行规则，避免续作时重新踩坑。

### 13.1 六条已验证的硬规则（违反其一即产生回归）

| # | 规则 | 依据 |
|---|---|---|
| 1 | **`@ObjectLink` 的宿主源必须是 `@State` 持有的实例**；写成普通 `private` 字段会被编译器拒绝 | Phase 3a 报错原文 |
| 2 | **组件成员名不得与 `CustomComponent` 基类属性方法同名** —— 已踩：`borderColor`、`scale`、`onTouch`、`background`（报 `Property 'background' ... is not assignable to the same property in base type 'CustomComponent'`；`background` 与 `backgroundColor` 都中招，因为基类有 `.background()` 属性方法） | 四次编译失败 |
| 3 | **迁移后的 UI 不得保留参数化 `@Builder`**（简单类型参数按值捕获 → 子树首帧后冻结，切档/开关不刷新）。改法：内联直接读 store，或改成子组件用 `@Prop` | 真机三版对照实验 |
| 4 | **宿主改 `@State` 持有的 `@Observed` 实例属性 → 宿主自身也会重绘**（所以让宿主读 store 是安全的） | 夜视模式实测（全应用变红） |
| 5 | **state 与读取它的 UI 必须同片搬迁**：只搬字段不搬读取方 → 宿主观测不到 store → 退化成不刷新 | 恒星时行的处理 |
| 6 | **跨域 / 桥 / 定时器依赖用注入解决，不硬搬**（如 `TimeWheelController` 的 `onSeek` / `onStopSpeed` / `getUtcOffsetHours`） | Phase 3m |
| 7 | **`@Component` 的 `build()` 只能有唯一容器根节点**。原 `@Builder` 允许并列多根（如 `tabletInspectorFallbackVisual` 的 `Stack` + `Text`），下沉成组件后必须包进一个容器：用**与原调用点外层容器相同的 `space`**（该例外层是 `Column({ space: 8 })`），否则间距会变 | Phase 3v 编译报 `build method can have only one root node` |
| 8 | **搬迁会打断"按文本切片单体"的测试脚本**：仓库里 23 个 `scripts/*.mjs` 用 `source.indexOf(...)`/`slice`/正则读 `MainWindowNativeNode.ets`，字段改 `this.store.X`、UI 改组件后它们会成片失败。每片必须跑一次受影响脚本并同步（切到组件文件、注入 `objectDetailStore` 之类的假宿主）。**存量失败（先于本会话、与本轮无关）见 §13.6** | Phase 3v 一次暴露 20+ 处 |
| 9 | **不要把宿主的 `@Builder` 经 `@BuilderParam` 传进子组件**：真机实测**渲染该页即整个应用退出**（hilog 无 ArkTS 报错、`pidof` 直接为空，且 `arkts_check` 与构建均通过，属运行期）。正解是先把该 builder 改写成**组件**，由宿主把数据与回调传进去（Phase 3aa 的"观测/坐标"两页为对照组：同样用 `@ObjectLink` + 回调注入，正常）。 | Phase 3aa 真机 A/B |

### 13.2 每片协议（八步，缺一不可）

> **0（前置，最高优先级）：自动续作，不在片间停。** 用户已授权本队列"全流程自动执行"。一片做完（含构建、真机、测试、CHANGELOG、提交）后，**必须在同一轮内直接开始下一片**，不得输出"本片已完成，下一步打算做 X"这类检查点汇报，也不得请求确认。进度写进 CHANGELOG 与本节 §13.5 队列，而不是写成给用户的片间状态消息。仅在以下情况停：(a) 需要用户才能做的决策；(b) 报阻塞；(c) 队列全部完成。此规则同时写入仓库根 `AGENTS.md`。

1. **量化**：统计该域字段与引用数（`this.<name>`），据此挑最小可自包含的片。
2. **建 store**（`state/*Store.ets`，`@Observed`，只放数据 + 纯计算，不 import UI/NAPI）。
3. **建组件**（`panels/...ets` 或 `common/ui/...ets`）：`@ObjectLink` + `@Prop` + 回调；**不用参数化 `@Builder`**。分支多而每支入参少时（如媒体区八分支），**保留宿主的无参 `@Builder` 做分支判定，每支下沉成小组件**（每个 2–7 个入参），比"一个大组件传十几个 `@Prop`"更稳。
4. **单体手术**：字段 → `@State` store 字段；引用改写；UI 区 → 组件调用；删除已搬走的 builder/方法。
5. **`arkts_check` → `devecocli build`（项目脚本）→ `node scripts/check-ohos-ui-contract.mjs`**。
6. **跑受影响的切片测试**（`node scripts/test-ohos-*.mjs` / `verify-ohos-*.mjs`，见 §13.1 规则 8）并同步。
7. **真机实测**（`192.168.3.95:40565`，IP 可能变，先用 `hdc list targets`）：安装 → 启动 → **逐项交互验证"点按后是否实时更新"**，不要只看布局是否一致；**测试若改了持久化设置，必须测后恢复**。回调链路可用 `hdc shell hilog -x` 过滤日志实证（如点"重试"后应出现 `[detail-media] retry request=...`）。
8. **CHANGELOG + 提交**：CHANGELOG 用 **CRLF 安全脚本**追加（见 13.4）。**不需要**再单独同步 `build/...` 的生成副本 —— 自 §13.7 起 `build/` 下的副本已全部取消跟踪，由构建脚本按需生成。

### 13.3 已知陷阱（都付出过代价）

- **单行方法**：`private f(): T { return x }`。删除脚本若以"下一个 `\n  }\n`"为方法结束标记，会越过其边界并连带删除相邻成员（曾误删 `drawerWidth`/`onRailTap`）→ **必须特判单行方法，并由编译器兜底**。
- **删字段必须连同其独立装饰器行一起删**（否则留下孤立 `@StorageLink(...)`，报 `cannot have multiple state management decorators`）。
- **PowerShell here-string 是 LF 而源码是 CRLF**：用于匹配的 here-string 必须先 `-replace "(?<!`r)`n","`r`n"` 归一，否则匹配失败。
- **超大文档（>100 KB）不要用通用编辑工具插入**：CHANGELOG（687 KB）曾被静默截断到 64 KB 并提交；改用脚本追加并**立即核对字节数/行数/裸 LF 数**。
- **`deveco ui layout` 是简化树，且 TextInput 值可能不显示**；需要视觉确认时用 `snapshot_display` + 读图。
- **面板本身可被拖动**：在面板上滑可能移动面板而非滚动内容；滚动要在 `Scroll` 区域内（先 dump 拿到其 bounds）。
- **列表内滑动**可能被判为点选 → 用 `ui drag`（按压—移动—释放）。
- **替换"外层有条件包裹的块"时必须保留/补回 `if (...) {` 那一行**：若起始标记落在条件语句内部、而替换文本只写了新内容，会把 `if` 的开括号一起删掉，其闭合 `}` 变成孤儿 → 文件括号深度失衡 → 数千行之后爆出上百条 `UI component ... cannot be used in this place` / `Cannot find name 'width'`。**定位法**：脚本扫描全文件括号净深度（与 HEAD 对比应为 0），再逐 diff hunk 统计 `{`/`}` 净差额，锁定"删了一个 `{` 未补回"的 hunk。
- **`arkts_check` 会漏掉结构失衡，绝不可替代构建**：曾出现 `arkts_check` 对四个文件全部报 "No errors"、而 `devecocli build` 立即失败的情况（括号深度 −1）。§13.2 第 5 步的"必须跑构建"因此是硬性要求。
- **"某页一渲染应用就退出"的排查法（A/B + 二分）**：`git stash -u` 回到**上一个已验证提交**重新构建安装，重走完全相同的点击序列 —— 旧构建正常、新构建退出，即锁定为新改动；再把新改动按"最小可删单元"二分（Phase 3aa 保留三页中的两页即恢复正常，从而把差异锁到 `@BuilderParam` 这一处）。运行期退出在 hilog 里可能**没有任何 ArkTS 报错**，所以只能靠 `pidof com.cnchensh.stellarium` 判存活 + A/B 复现，不要浪费时间抓日志。
- **面板内的嵌套滚动会吞掉手势**：如搜索面板"目录天体"网格自身可滚动且占满可视区，`dumpLayout` 下无法把外层滚动拖到网格下方的块（星座 chips / 坐标输入曾因此无法交互验证）→ 需要交互验证尾部内容时，可先切到对象很少的分类让网格变短。
- **批量改引用时必须同时补宿主 store 字段声明**：只把 `this.X` 改成 `this.store.X` 而忘了 `@State private store: XStore = new XStore()`，会让**所有**该引用推断为 `any`，构建报 `arkts-no-any-unknown`，且报错行号散落在毫不相关的业务方法里（13066/13948/18815…），极难一眼定位。**这两步必须成对执行。**
- **类型导入要找对模块**：Phase 1c 的 `pages/MainWindowModels.ets` **只包含原单体序言区**的声明；`ObjectDetailField` / `ObjectDetailModel` / `SatellitePass` / `SkyCultureDescriptionBlock` 等类型的导出仍在 **`pages/StellariumTypes.ets`**。导入错模块会报 `declares 'X' locally, but it is not exported`。
- **真机上同时装着两个 `QAbility` 包，且"看前台"与"跑 CLI"默认不是同一个**（2026-10-01）：仓库 `harmonyos/AppScope/app.json5` 的 `bundleName` 是发布配置 `com.joinother.skyinstrument`（versionCode 1000050），而 `scripts/build-ohos-hap-windows.ps1` 生成工程时把它覆盖为签名配置 **`com.cnchensh.stellarium`**（versionCode 1000054）并 `force-stop`/`aa start` 该包；`devecocli ui *` 作用于**前台窗口**，而 `scripts/stellarium-cli.mjs` 的 `DEFAULT_BUNDLE` 是 `com.joinother.skyinstrument` —— 一句 `openUiPanel` 就会把 skyinstrument 拉到前台，随后所有 `devecocli ui` 点击都落到它身上（曾整段误测到 v1000053）。**验收/复现一律以 `com.cnchensh.stellarium` 为准：CLI 显式带 `--bundle com.cnchensh.stellarium`，并在关键步骤后用 `aa dump -l` 复核 `state #FOREGROUND`。**
- **`devecocli ui layout` 的 `Toggle` 节点不暴露 `checked`**：开关的真实状态只能靠截图 —— 把 ~3MB 全屏图**裁成小区域**（几十~一百 KB）再读，直接读全屏图会撑爆上下文。

### 13.4 常用命令

```powershell
# 构建（默认 debug，含 x86_64；-SkipEngine 表示不重编 C++）
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-ohos-hap-windows.ps1 -SkipEngine -SkipDeploy -SkipResources
# 契约校验（33 面板 / 22 静态 id / 17 动态前缀 / 41 锚点）
node scripts\check-ohos-ui-contract.mjs
# 安装 / 启动
& $hdc -t 192.168.3.95:40565 install -r build\libstellarium-harmonyos\entry\build\default\outputs\default\entry-default-signed.hap
& $hdc -t 192.168.3.95:40565 shell aa start -b com.cnchensh.stellarium -a QAbility
# UI 交互（语义化，优先于坐标点击）
devecocli ui layout --device 192.168.3.95:40565
devecocli ui click/drag/text --device 192.168.3.95:40565 ...
```

**CHANGELOG 追加（CRLF 安全）**：把条目写入临时文件后用脚本前置插入，并核对 `裸LF = 0`（见本轮各次提交的实际命令）。

### 13.6 存量失败（先于本轮重构，续作不要误判为自己引入）

| 脚本 | 现象 | 性质 |
|---|---|---|
| `test-ohos-privacy-startup.mjs` | 11 处 `Cannot use import statement outside a module`，抛自 `new Function(...)`（脚本 L24 夹具 `plain()` 未能剥离 `qability/PrivacyConsent.ets` 的 import） | **夹具缺陷**；`PrivacyConsent.ets` / `QAbility.ets` 最后修改于 `101acf6cd3`，早于本会话 |
| `test-ohos-satellite-panel.mjs` test 7 | `computeOrbitPoints()` 的 `if (!validSample()) return;` 计数期望 3、实际不符 | **纯 C++ 断言**，与 ArkTS 无关 |
| `verify-ohos-location-search.mjs` | 直接 `ENOENT`：路径拼成 `E:\E:\code\...` | **脚本自身路径 bug**，断言都未执行到 |
| `test-ohos-clipboard-pad.mjs` / `test-ohos-guide-pad.mjs` / `test-ohos-mist-horizon-pad.mjs` / `test-ohos-polar-scope-pad.mjs` | 断言抛错（`actual: undefined`）：四个 `-pad` 用例要求显式 `--device`，未传时拿不到设备 | **用例需设备参数**；Phase 3aq 用 `git worktree` 检出 HEAD 复核，基线同样失败 |
| `test-ohos-mist-performance.mjs` | 同上，需在连接设备时运行 | **需设备**，先于本片 |
| `verify-ohos-search.mjs` | 走 macOS hdc 默认路径，Windows 上取不到设备 | **脚本平台假设**，先于本片 |

> **Phase 3aq 复核**：在 HEAD（`fea7652791`）用 `git worktree add --detach` 检出后逐个运行，上表 7 个脚本（含原有 3 个中的 `verify-ohos-location-search.mjs`）**在基线即失败**；`test-ohos-privacy-startup.mjs` 与 `test-ohos-satellite-panel.mjs` 在 HEAD 已不再失败。

> Phase 3v 已顺带清掉 Phase 3t 遗留的 5 处失败（`test-ohos-detail-live-values.mjs` 的假宿主缺 `objectDetailStore`）。
> 其余切片测试在 Phase 3v 结束时全绿：`audit-ohos-resource-coverage`、`test-ohos-astro-motion`、`-detail-image-layout`、`-detail-live-values`、`-detail-model-geometry`、`-distance-ui`、`-guide`、`-information-policy`、`-mist-horizon`、`-model-scroll`、`-plugin-panel-state`、`-polar-scope`、`-procedural-model`、`-search-browser`、`-settings-choice-motion`、`-skyculture-text`、`-startup-stars`、`-wut-layout`、`verify-ohos-julian-date`、`verify-ohos-object-details`。

### 13.7 `build/` 生成物取消跟踪（2026-10-01）

**现象：** 每改一次源码，`git status` 就多出 `build/libstellarium-harmonyos/entry/src/main/ets/pages/MainWindowNativeNode.ets` 等改动，因此每片都要额外做一次“同步生成副本”的提交。

**根因：** git 的 `.gitignore` **只对未跟踪文件生效**。根 `.gitignore` 里确实有 `build` 一行，但这 11 个文件在规则生效前（2026-07-26 的 `3a1bad1e3a` / `0566439884` 等提交）就已被 `git add`，于是一直被跟踪。构建脚本 `scripts/sync-ohos-build-sources.sh` 会把 `harmonyos/ets-source/**` 复制到 `build/.../entry/src/main/ets/**`，所以源码一动、被跟踪的副本就脏。

**核查（取消跟踪前）：** 11 个文件**全部**能在仓内找到被跟踪的源，取消跟踪不丢任何内容 ——

| 类别 | 数量 | 源（均已跟踪） | 关系 |
|---|---:|---|---|
| ArkTS 页面 | 4 | `harmonyos/ets-source/**` | **byte 完全一致**（纯拷贝） |
| 资源 | 5 | `harmonyos/{AppScope,resources,ets-source}/resources/**` | 一致 |
| 数据 | 2 | `stars/hip_gaia3/**`（含 53.2 MB 星表） | 一致 |

**处理：** `git rm --cached` 上述 11 个（文件留在磁盘），`build` 继续被忽略；构建脚本在编译前完成同步，因此新克隆只需跑一次构建。`verify-ohos-object-details.mjs` 的“生成镜像是否过期”检查照常有效（它只要求文件在磁盘上存在）。

**注意：** 仓内还有约 20 个“被忽略但被跟踪”的**上游素材**（`textures/*.tif`、`guide/*.pdf`、`data/*.dat`、`scripts/tests/media/*.mp4` 等），它们是被 `*.tif`/`*.pdf` 这类宽泛规则误伤的真实内容、且**没有别的副本**，属于另一类别，**不要**顺手删除。

### 13.5 剩余队列（按体积，供续作选择；**2026-10-01 用实测行数修正**）

> 初版此表沿用 §1.3 的错误测法，行数普遍高估 10–70 倍（如 `searchFilterMenu` 3,441 → 实测 48）。
> 下表为"首个 `^  }$` 收尾"重测值。**真正的 UI 体量集中在 `panelContent`（4,707 行）**，
> 故 Phase 4 的主线始终是"把 `panelContent` 的 33 个分支逐个抽成组件"。

| 序 | 域 | 实测规模 | 备注 |
|---|---|---|---|
| 1 | **search 筛选器** | `searchFilterMenu` **48** + `searchFilterChips` **30** + `catalogFilterRow`（参数化 UI 函数，需改子组件）；`searchFilterPage` 15 / `searchCategory` 19 / `searchVisibilityFilter` 5 / `searchInstrumentFilter` 6 | 一片可完成 |
| 2 | search 分类浏览 | `category*` 10 字段 / 64 处 | |
| 3 | **object / detail** | ~~`tabletInspectorMedia` 179~~ **已完成（Phase 3v / 3ab，现为 `TabletInspectorMediaGroup` 组件）**；~~`objectDataRow`/`structuredObjectDetailRow`/`tabletInspectorSection`~~ **已完成（Phase 3u）**；~~`objectDataTile`/`objectMetric`/`objectScheduleTile`/`objectDetailTab`/`objectCompactMetric`~~ **已完成（Phase 3x）**；~~`objectDistanceNotice`/`selectedLiveInfoRows`/`selectedCoordinateRow(s)`~~ **已完成（Phase 3y）**；~~`structuredObjectDetails` + 五个段落助手~~ **已完成（Phase 3z）**；~~`satellitePassesDetails`/`satellitePassCard`/`satellitePassTimelineRow` + 四个助手~~ **已完成（Phase 3z2a）**；~~`selectedConstellationCultureDescriptionView` + `skyCultureDescriptionBlockView`~~ **已完成（Phase 3z2b）**；~~卡片"观测/坐标"两页~~ **已完成（Phase 3aa）**。**剩余：** （1）~~先搬"资料"页~~ —— **顺序已调整（Phase 3ad 结论）**：先搬资料页要向 `ObjectDetailDataTab` 转发 26 个入参（媒体区 12 个派生值 + 4 回调），而先把**外壳**组件化后资料页分支将随外壳内收、媒体参数在外壳内部就地计算。已完成的 ``ObjectDetailCardHeader`` / ``ObjectDetailCardTabs`` 即此路径第一步；~~下一步是 ``unifiedObjectDetailCard`` 剩余部分（Scroll + 四个分支）整体内收为 ``UnifiedObjectDetailCard`` 组件~~ **已完成（Phase 3ap：`panels/object/UnifiedObjectDetailCard.ets`，46 个成员——2 个 `@ObjectLink` + 25 个 `@Prop` + 1 个 `Scroller` 成员 + 17 个回调 + 1 个 `distanceSummaryText`；四个页组件的调用点已全部在组件内；`objectInspectorModelRendering` / `objectInspectorModelTexturePixels` 仍留宿主、以 `@Prop` 传入）**。**详情卡域至此收尾。**（2）``objectInspectorModelRendering`` / ``objectInspectorModelTexturePixels`` **刻意不并入 @Observed store**：它们由渲染管线**逐帧写入**，放进被观察的 store 会造成重渲染风暴；保持为宿主字段、以 ``@Prop`` 传入（``modelRendering`` / ``hasModelTexture``）。（3）~~``objectDetailConnector*``(9) 叠层字段簇~~ **已完成（Phase 3an：指向线几何 9 字段按"逐帧写入不入被观察 store"留在宿主、以 ``@Prop`` 传入 ``panels/overlay/ObjectDetailConnectorLayer.ets``；只有开关 ``objectDetailConnectorVisible`` 入 ``state/OverlayStore.ets``）**；``objectInspectorModel*``(5) 仍留宿主。**Phase 3aq**：`tabletInspectorAction`(8) / `tabletInspectorRow`(9) / `expandedSummaryMetric`(8) / `expandedSummaryLine`(8) 经零引用扫描确认为死代码（四类判据全 0），已删除。**Phase 3ad 回归修复（`fix(harmonyos)`，2026-10-02，真机 A/B 定位）**：`ObjectDetailCardHeader` 的三枚摘要（星等/星座/距离）原只经普通成员回调 `resolve`/`distanceSummary` 求值，抽成组件后局部刷新不为该元素登记依赖 → 切换天体时摘要冻结在上一颗天体；已改为直接读 `@ObjectLink store`（距离经带实参的回调，实参即 store 字段）—— 结论：**组件内动态值必须以表达式直读装饰变量**。 | 与 tablet/compact 两壳耦合 |
| 4 | **astro** | ~~`phenomenonRelationMark` 29 / `astroSelectionGuide` 15~~ **已完成（Phase 3af，`panels/astro/AstroGuides.ets`）**；~~`wutTargetCard` 21~~ **已完成（Phase 3ah，`panels/astro/WutTargetCard.ets`）**；~~`continuationSection` 31~~ **已完成（Phase 3ag，`panels/astro/ContinuationSection.ets`）**；**Phase 3aq**：`graphLoadingRow` / `rtsSelectionGuide` / `graphSelectionGuide` **已完成（`panels/astro/GraphGuides.ets`，3 组件 61 行，14 处调用点）**；~~`observerPlanetSection` 24 / `pointingTestSection` 28 / `watchGyroSection` 34 / `tonightEventsSection` 23 / `tonightCard` 16~~ **已完成（Phase 3as：`state/SessionToolStore.ets` + `panels/astro/SessionToolSections.ets`，5 组件 189 行，宿主 80 处 store 引用改写）**；~~`gyroTargetGuide` 19~~ **已完成（Phase 3as：`panels/astro/GyroTargetGuide.ets`）**；≈164 字段（注：前四段在当前构建被 `OFFLINE_APPGALLERY_BUILD = true` 跳过，须在非 appgallery 构建真机走查） **Phase 4l（已完成，2026-10-02）**：`astro` 面板分支（1,980 行）整体下沉 —— `state/AstroStore.ets`（140 字段）+ `panels/astro/AstroPanel.ets`（2,255 行；`@ObjectLink` store/wutStore/objectDetailStore + 5 个颜色 `@Prop` + 普通 `Scroller` 成员 + 114 个注入回调 `AstroPanelHost`），宿主加载/导出/路由/持久化方法保留并改写为 `this.astroStore.X`；单体 21,303 → 19,314 行 | 多为展示 |
| 5 | **layers** | ~~`hierColumn` 75~~ **已完成（Phase 3aj，`panels/common/HierColumn.ets`，通用组件，位置面板四列与图层面板共用）**；~~`layerPresetBar` 19 + `viewTabs` 26 + 参数化 `switchRow` + 图层开关字段簇~~ **已完成（Phase 3ak：`state/LayerStore.ets`（94 字段）+ `panels/layers/LayerSwitchRow.ets` + `LayerPresetBar.ets` + `LayerTabs.ets`，103 处 switchRow 调用点全部改组件）** | 实测 **94 字段 / 103 个 switchRow**（原表「≈60 字段 / 21 个」低估）；7 个视图标签页 `viewXxxTab` builder 留给 Phase 4。**Phase 4f/4g/4h 已完成**：6 个 `view*Tab` → `panels/layers/LayerViewTabs.ets`、`viewSkyCultureTab` → `panels/skyculture/SkyCultureViewTab.ets`、整个 `layers` 分支 → `panels/panels/LayersPanel.ets`（252 行） |
| 6 | **tools** | ~~`toolsPanel` 446~~ **已完成（Phase 3ao：`state/ToolsStore.ets`（25 字段）+ `panels/tools/ToolsPanel.ets`·`RecordingControlBar.ets`·`RecordingFocusShell.ets`，宿主 153 处引用改写）**。实测纠正：原表「446」是把 `toolsPanel` 随后的 `lockRow`/`languageRow`/`gyroscopeRow`/… 一并计入的测量错误，`toolsPanel` 本体仅 **76 行**；本域实测引用约 **190 处**（改写 153）。`recordCount` 与录制引擎字段按"高频写入不入被观察 store"留在宿主；`skyTextureStatus` 状态条 UI 属 Phase 6 壳层，本片只改其字段引用 | |
| 7 | **skyCulture** | ~~`skyCultureMakerConstellationEditor` 93 + `skyCultureMakerArtworkEditor` 63 + maker 向导字段簇 29 字段~~ **已完成（Phase 3am：`state/SkyCultureMakerStore.ets` + `state/SkyCultureViewStore.ets` + `panels/skyculture/SkyCultureMakerFields`·`Tabs`·`Overview`·`ArtworkEditor`·`ConstellationEditor`·`ValidationPanel`，分两个提交 `783593b4da` / `5013516cb6`）**。实测 maker **29 字段 / 247 处引用**（原表「≈130 字段」把整个 skyCulture 域都算进来了）；只读详情视图另拆 **17 字段 / 123 处引用**。**剩余（下一个 skyCulture 切片）**：文化列表/当前选择（`skyCultureList`/`skyCultureListLoading`/`skyCultures`/`currentSkyCulture`/`currentSkyCultureId`，被领地地图与默认文化设置交叉使用）、领地地图簇、面板设置/筛选/标签模式/颜色约 90 字段，以及 `viewSkyCultureTab` 的组装 UI —— 与 `panelContent` 的设置宿主同片（Phase 4）。**Phase 3as**：~~`skyCultureMakerPanel` 68~~ **已完成（`panels/skyculture/SkyCultureMakerPanel.ets`，复用既有 `SkyCultureMakerStore`，19 个桥/定时器回调解入）**。进度驱动的 `skyCultureArtStates`/`skyCultureArtThumbnailPixelMaps`/`skyCultureArtPreviewPixelMap` 刻意不入 store。**Phase 4d 已完成**：叶件 `skyCultureSectionHeader`/`skyCultureMetaItem`/`skyCultureLabelSettingCard`/`skyCultureLabelModePicker`/`skyCultureFilterPicker`/`skyCultureFilterOption` 已下沉 `panels/skyculture/SkyCultureViewParts.ets`（`skyCultureArtPreviewOverlay` 属 Phase 5 叠层，未动）；`satelliteGroupSelector` → `panels/satellite/SatelliteGroupSelector.ets` |
| 8 | **sensors/gyro** | `gyroCalibPanel` 99；13 字段 | 活路径是 `gyroRotationCallback` 等，勿动 |
| 9 | satellite / script / telescope / session / 其余设置标签页 | ~~`scriptFocusShell` 209~~ **已完成（Phase 6a：`panels/shell/ScriptFocusShell.ets`，251 行；`guideState.active` 分发留在宿主调用点，宿主 19,098 → 18,913）** / ~~`compactMoreDrawer` 130~~（**Phase 3aq 零引用扫描确认为死代码，已删除；同批 `actionDrawer` 70 / `verticalRail` 66 / `iconButton` 31 / `moreButton` 32 / `musicButton` 25 / `gyroButton` 28 / `lockRow` 18 / `timeSpeedChips` 6 也一并删除**） / ~~`cityChipsRow` 109~~ **已完成（Phase 3ai）** / ~~`locationSearchPanel` 77~~ **已完成（Phase 3ai）**；~~`locationPickerPanel` 153（含参数化 `@Builder hierColumn` 75 与方法/字段簇）~~ **已完成（Phase 3aj：`panels/location/LocationPickerPanel.ets` + `LocationPickerStore` + `panels/common/HierColumn.ets`，分两个提交）**；~~telescope（`lx200Panel` 214 / `lx200ObjectControls` 60 / 参数化 `ocularSelector` 45 / 参数化 `ocularMetric` 7 + 81 个 `ocular*`·`lx200*`·`equatorialMount` 字段，实测 450 处引用）~~ **已完成（Phase 3al：`state/TelescopeStore.ets` + `panels/telescope/Lx200Panel.ets`·`OcularSelector.ets`·`OcularMetric.ets`·`Lx200ObjectControls.ets`，单片一提交；`oculars` 分支的内联 UI 留给 Phase 4）**；**Phase 3as**：~~参数化 `guideButton` 10（12 调用点） / 参数化 `scriptKeyButton` 12（6 调用点）~~ **已完成（`panels/guide/GuideButton.ets` + `panels/tools/ScriptKeyButton.ets`，可用态由 `phase`/`index`/`action` 在组件内推导）** | |
| 10 | **Phase 4 面板宿主** | `panelContent` **4,707** → 表驱动 `PanelHost` | 主线；逐分支抽组件。**Phase 3aq 先摘走它体内的设置行**：`infoRow`（55 调用点）/ `ephemerisRow` / `informationModeButton` / `informationSwitchRow` / `navigationSwitchRow` / `mosaicCameraMetric` / `languageRow` / `gyroscopeRow` / `deviceAndPrivacySettings` 共 9 个 builder → `common/ui/InfoRow.ets` + `panels/settings/SettingsRows.ets` + `panels/settings/DeviceAndLanguageRows.ets`（合计 313 行）。**Phase 3as 又摘走它体内的 13 个 `@Builder`**（会话工具 5 + 星文化制作器 1 + 面板壳件 4 + 陀螺仪指引 1 + 脚本键 1 + 导览键 1），并删死代码 `padExploreCard`(27)；单体 25,434 → 25,098。**Phase 3at 又摘走它体内的 `guideLibrary`（14 行 → `panels/guide/GuideLibrary.ets`）**；单体 25,098 → 25,063。**Phase 4a（已完成）**：`panelContent` 首批 4 个最小分支抽组件 —— `catalogs` → `panels/panels/CatalogsPanel.ets`、`angleMeasure` → `AngleMeasurePanel.ets`（复用 `ToolsStore` 的 `@ObjectLink`）、`audio` → `AudioPanel.ets`、`scenery3d` → `Scenery3dPanel.ets`（后两者 `@Prop` + 回调注入，`AudioEngine`/`resourceText` 按规则 6 回注）；单体 25,059 → 24,945 行。**Phase 4b（已完成，2026-10-01）**：第二批 5 个次小分支 —— `place` → `PlacePanel.ets`（3 个 `@ObjectLink` + 回调组装既有 7 子组件）、`commands` → `CommandsPanel.ets`、`navStars` → `NavStarsPanel.ets`、`archaeoLines` → `ArchaeoLinesPanel.ets`、`mosaicCamera` → `MosaicCameraPanel.ets`；随 UI 下沉 3 个纯助手（`navStarsSetLabel`/`filteredCommandCatalog`/`mosaicCameraValue`）；单体 24,945 → 24,796 行。**Phase 4c（已完成，2026-10-02）**：重扫剩余分支、排除薄调用 hub 类与 `layers`/`floatingPanel`/`compactPanel` 后，取**最小的 5 个分支** —— `more`(62) → `MorePanel.ets`、`nebulaTextures`(69) → `NebulaTexturesPanel.ets`、`time`(71) → `TimePanel.ets`（装配 5 store + 7 个既有时间子组件）、`meteorshowers`(87) → `MeteorShowersPanel.ets`、`help`(95) → `HelpPanel.ets`；随 UI 下沉 2 个纯助手（`fmtIso`/`nebulaTextureStatusLabel`）；单体 24,796 → 24,497 行。**Phase 4d（已完成，2026-10-02）**：先搬挡着 `skyCultureMaker`/`layers` 分支的 7 个 skyCulture/satellite 叶件 —— 新增 `panels/skyculture/SkyCultureViewParts.ets`（`SkyCultureSectionHeader`/`SkyCultureMetaItem`/`SkyCultureLabelSettingCard`（合并原 `skyCultureLabelModePicker`）/`SkyCultureFilterOption`/`SkyCultureFilterPicker`）+ `panels/satellite/SatelliteGroupSelector.ets`，删死助手 `satGroupZh`/`skyCultureFilterOptionSelected`，22 处调用点改组件；真机验标签模式/筛选器/卫星分组的点按实时刷新；单体 24,497 → 24,440 行。**Phase 4e（已完成，2026-10-02）**：按 §6.2 口径重扫后取剩下最小的 4 个实分支 —— `search`(110) → `panels/panels/SearchPanel.ets`、`observing`(112) → `ObservingPanel.ets`、`object`(145) → `ObjectPanel.ets`、`satellites`(179) → `SatellitesPanel.ets`（复用既有 store 的 `@ObjectLink` 与 `@Prop` 快照，不新建 store）；`layers` 因体内 7 个 `view*Tab` 仍是宿主 `@Builder` 而**跳过**。单体 24,440 → 24,098 行。**Phase 4f（已完成 1/2，2026-10-02）**：先解决 `layers` 的前置 —— 6 个 `view*Tab` 宿主 `@Builder`（`viewSkyTab`/`viewSSOTab`/`viewDSOTab`/`viewMarkingsTab`/`viewLandscapeTab`/`viewSurveysTab`）下沉为 `panels/layers/LayerViewTabs.ets`，并新增 `state/LayerViewStore.ets`（31 个数值/展开态设置，宿主引用全部改写）；单体 24,098 → 23,632 行。`layers` 分支仍未抽出（超出 ≤400 行同片预算）。**Phase 4g（已完成，2026-10-02）**：第 7 个标签页 `viewSkyCultureTab`（819 行）下沉为 `panels/skyculture/SkyCultureViewTab.ets`（940 行，24 个 bridge/定时器/解码回调回注），并新建 `state/SkyCultureSettingsStore.ets`（503 行，82 个设置字段 + 纯计算助手；`currentSkyCulture`/`skyCultureList`/`selectedSkyCultureId`/解码 PixelMap/Canvas 上下文按口径不硬搬）；单体 **23,632 → 22,451 行**，分两个提交（store 与组件）各自全绿；真机已验证该页签渲染、store 实时刷新与引擎 `setSkyCultureLabelStyle` 往返。**Phase 4h（已完成，2026-10-02）**：`layers` 分支整体下沉为 `panels/panels/LayersPanel.ets`（252 行；4 个 `@ObjectLink` store + 25 个 `@Prop`/普通成员 + 43 个回调），判定条件留宿主；单体 **22,451 → 22,380 行**。同时收尾 `floatingPanel`/`compactPanel`：二者体内只是 `this.panelContent()`，组件化必用 `@BuilderParam`（规则 9 真机退出），**保留为宿主薄 `@Builder`**，不影响「分支 ≤8 行单调用」口径（该口径只针对 `panelContent` 的分支）。逐一核对 33 个分支：**26 个已达标**（纯单组件分发）；**Phase 4i（已完成，2026-10-02）**：`telescope`(23) / `settings_quick_legacy`(180) / `oculars`(278) 三个分支下沉为 `panels/panels/TelescopePanel.ets`（60 行）/ `SettingsQuickLegacyPanel.ets`（238 行）/ `OcularsPanel.ets`（316 行），判定条件留宿主；单体 **22,380 → 21,983 行**；真机已验证 `telescope` / `oculars` 渲染与点按后实时刷新（`settings_quick_legacy` 无 UI 入口，临时放开 CLI 白名单取得运行期证据后已还原）。**Phase 4j（已完成，2026-10-02）**：`settings`(406) 下沉为 `panels/panels/SettingsPanel.ets`（548 行；4 个 `@ObjectLink` store + 44 个 `@Prop` + 46 回调 + 1 `Scroller`，8 个子标签页内联 UI 逐字下沉），末尾 `else`（`config` 回退页，219 行；**正常导航不可达** —— `setPanel()` 已把 `config`/`pluginManager` 归一为 `settings`，CLI `isCliPanelName` 白名单亦不含未知名）下沉为 `ConfigFallbackPanel.ets`（277 行；4 store + 8 `@Prop` + 14 回调），判定条件留宿主；单体 **21,983 → 21,485 行**；真机已验证设置面板渲染、逐标签切换与「附加 > 投影」点按后同一 `Text` 文案即时刷新（极射→鱼眼→极射，恢复测前值）。**仍未达标**：`astro`(≈2,000 行) 与 `scripts`(248 行) —— 本片全链复核：29 个分支中**唯此二者仍含内联 UI**，其余全部退化为单次组件调用；4h/4i 清单本就含 `scripts`。**Phase 4k（已完成，2026-10-02）**：`scripts`(248) 下沉为 `panels/panels/ScriptsPanel.ets`（310 行；1 个 `@ObjectLink tools` + 27 个 `@Prop` + 20 个回注回调 + 4 个函数成员（`scriptZh`/`scriptDesc`/`scriptMetaLine`/`scriptSourceLine`，因设置页共用仍留宿主），根为单个 `Scroll`），判定条件留宿主；单体 **21,485 → 21,303 行**；真机已验证面板渲染、脚本列表的 `scriptZh`/`scriptSourceLine` 链路，以及录制名 `TextInput` 点按键入 + 切换面板（组件销毁重建）后值仍由宿主 `@State` 再注入。**剩余**：`astro`(≈2,000 行) —— 29 个分支中**仅此一个仍含内联 UI**。**Phase 4l（已完成，2026-10-02）**：`astro` 分支（1,980 行）下沉为 `state/AstroStore.ets`（140 字段）+ `panels/astro/AstroPanel.ets`（2,255 行；`@ObjectLink` ×3 + 颜色 `@Prop` ×5 + 普通 `Scroller` + 114 个注入回调 `AstroPanelHost`）；宿主方法与持久化仍留宿主，引用改写为 `this.astroStore.X`（140 字段），单体 **21,303 → 19,314 行**；`test-ohos-astro-motion` / `test-ohos-wut-layout` 已同步改读组件文件。**全链达标复核（Phase 4 收口）**：`panelContent` 的全部具名分支除 `floatingPanel`/`compactPanel`（4h 定论：体内即 `this.panelContent()` 的宿主薄 `@Builder`，不迁）外，**全部**已退化为单个组件调用；实测该区段 `Text(`/`Row(`/`Button(`/`ForEach(`/`Toggle(` 构造均为 **0**，无内联 UI 残留。 |
| 11 | **Phase 5 overlay / Phase 6 壳层** | ~~`scriptFocusShell` 209~~ **已完成（Phase 6a：`panels/shell/ScriptFocusShell.ets`，251 行）**；~~`compactShell` 165~~ **已完成（Phase 6b：`panels/shell/CompactShell.ets`，268 行；壳内 `this.compactPanel()` 上移宿主调用点——流程见 Phase 6b CHANGELOG；单体 18,913 → 18,823）**；~~`harmonyShell` 90~~ **已完成（Phase 6b：`panels/shell/HarmonyShell.ets`，90 行；三壳布局分发与顶层 Dock 命中靶上移宿主调用点，组件只承载坐标叠层 / 陀螺仪指引 / 点击反馈气泡）**；~~`hoverObservatoryShell` 142~~ **已完成（Phase 6c：`panels/shell/HoverObservatoryShell.ets`，242 行；壳内 `this.compactPanel()` 上移宿主调用点——流程见 Phase 6c CHANGELOG）**；~~`expandedShell` 128~~ **已完成（Phase 6c：`panels/shell/ExpandedShell.ets`，232 行；`expandedUiAllowed()` 结果以 `@Prop` 入组件、壳内 `this.floatingPanel()` 上移宿主调用点；单体 18,823 → 18,751）**；~~`interactiveGuideShell` 78~~ **已完成（Phase 6d：`panels/shell/InteractiveGuideShell.ets`，116 行；导览按钮已是既有 `GuideButton` 组件、壳内无宿主 @Builder 调用，故无需上移调用点；导览阶段/步序文案由宿主从 `guideState` 与 `currentGuide()/currentGuideStep()` 算好后以 @Prop 下发，卡片几何 `guideCardWidth/Height/X/Y()` 由宿主算好传入；`.id('guide-stop')`/`.id('guide-content')`、`hitTestBehavior` 与过渡逐字保留；单体 18,751 → 18,689）**；~~`viewCenterCoordinateOverlay` 50 / `objectDetailConnectorLayer` 51 / `viewCoordinateSettings` 59 / `pointerCoordinatesPanel` 54 + 参数化 `pointerCoordinateToggle` + 该域 14 个设置字段~~ **已完成（Phase 3an：`state/OverlayStore.ets` + `panels/view/PointerCoordinateToggle.ets`·`PointerCoordinatesPanel.ets`·`ViewCoordinateSettings.ets` + `panels/overlay/ViewCenterCoordinateOverlay.ets`·`ObjectDetailConnectorLayer.ets`，提交 `9cac82c847`）** | ~~`panelHeader` chrome~~ **已完成（Phase 3ap：`panels/shell/PanelHeader.ets`，70 行；`observationTimeText`/`timeRateText` 未搬——仍由宿主 `panelTitle()`/`panelSubtitle()` 算好后以 `@Prop` 传给组件）。同片顺带完成 `dockButton`（`panels/shell/DockButton.ets`，33 行）与 `hubActionList`（`panels/shell/HubActionList.ets`，38 行）**。**Dock 交互修复（已完成，2026-10-02）**：Phase 3at 的普通成员闭包使 `BottomDock` 高亮冻结、`7202d0e1b1` 把激活态并入 `ForEach` 键又让激活入口销毁重建；现改为**稳定键 + `state/DockStore.ets` 经 `@ObjectLink` 注入**（`@Prop` 加 `@Watch` 同步），高亮实时跟随且开/关面板不重建入口（`BottomDock.ets` 79 / `DockButton.ets` 62 / `DockStore.ets` 8）。**Phase 3aq 已删掉本域的三条死壳路径**：`verticalRail` 66 + `actionDrawer` 70 + `compactMoreDrawer` 96，及其 4 个子按钮（`iconButton`/`moreButton`/`musicButton`/`gyroButton`）与 11 个 rail/drawer 辅助成员（`pinnedActions`/`drawerActions`/`compactDrawerActions`/`railHeight`/`drawerWidth`/`onRailTap`/`RAIL_*`×5/`railPinned`/`drawerOpen`）。**Phase 3as**：~~`dockClockChip` 16 / `dockClockLayer` 13 / `panelHandle` 22 / `padPanelHandle` 10~~ **已完成（`panels/shell/PanelChromeExtras.ets`，4 组件 100 行）**。**Phase 3at**：~~`bottomDock` 31~~ **已完成（`panels/shell/BottomDock.ets`，复用 `DockButton`；3 处调用点改组件）**；**同日回归修复（2026-10-01，见 CHANGELOG）**：点按后激活高亮不显示 —— 该组件化把激活判定改成宿主回注的普通闭包，组件因此观测不到 `activePanel`，`ForEach`（键不含 active）也不重建子项，`@Prop active` 冻结；已改为数据化的 `@Prop activePanel` + 组件内 `dockItemActive()`，并把激活态纳入 `ForEach` 键（`BottomDock.ets` 58 → 67 行；宿主 3 处调用点改写、删 `dockActionActive`，25,063 → 25,059 行）。**已 A/B 坐实为 3at 引入的回归**（`d7a2bc9768^` 构建点「位置」后 place 采样 max(B−R)=134，修复前 HEAD=3，修复后=143）；~~`compactTopQuickControls` 20 + 参数化 `compactQuickButton` 25~~ **已完成（`panels/shell/CompactTopQuickControls.ets` + `CompactQuickButton.ets`；参数化 `@Builder` 去除，动作本体回注宿主）**。**仍留宿主（Phase 4h 已定论）**：`floatingPanel` 55 **与 `compactPanel` 46** —— 二者体内都调用宿主 `this.panelContent()`，而 `panelContent` 是 §6.1 要求长期留在宿主的 `activePanel` 分发链；ArkUI 无按名实例化能力，组件化必须用 `@BuilderParam`，违反 §13.1 规则 9（真机退出）。故**保留为宿主薄 `@Builder`**，待 `panelContent` 剩余实分支全部下沉、整体组件化后二者才能随之下沉；**该保留不影响「分支 ≤8 行单调用」达标口径**（口径只针对 `panelContent` 的 `if/else if` 分支）。**Phase 3at 结论**：Phase 3 自身的"非 `private` 域 builder"队列已清空（仅剩上两件待 Phase 4）；但单体仍有 **11 个 `private` builder**（`satelliteGroupSelector` 25、`skyCultureSectionHeader`/`skyCultureMetaItem`/`skyCultureLabelSettingCard`/`skyCultureLabelModePicker`/`skyCultureFilterOption`/`skyCultureFilterPicker` 合计 150、`polarScopeOverlay` 126、`skyCultureArtPreviewOverlay` 60、`objectInspectorMediaPreviewOverlay` 66、`objectInspectorModelOverlay` 45）与 **7 个 `view*Tab`**，经零引用扫描全部为活代码，调用点落在 `panelContent` / `viewSkyCultureTab` / `build()`，归属 Phase 4（面板宿主 + 视图标签页）与 Phase 5（overlay），非 Phase 3 遗留。**Phase 5a（已完成，2026-10-02）**：`polarScopeOverlay`（127 行）→ `panels/overlay/PolarScopeOverlay.ets`（147 行），几何与手工命中路由留宿主机、以 `@Prop` + 回调注入，四个 `polar-scope-*` id 原样保留，单体 19,314 → 19,230 行。**Phase 5b（已完成，2026-10-02）**：~~`objectInspectorMediaPreviewOverlay`（66 行）~~ → `panels/overlay/ObjectInspectorMediaPreviewOverlay.ets`（88 行），可见性判定留宿主、标题/顶部安全区以 `@Prop`（titleText/topInset）传入、媒体数据经 `@ObjectLink objectMediaStore`、四个动作回注宿主（成员名与宿主方法一致），`ImageFit.Contain` 等语义逐字保留，单体 19,230 → 19,173 行。**Phase 5c（已完成，2026-10-02）**：~~`skyCultureArtPreviewOverlay`（60 行）~~ → `panels/overlay/SkyCultureArtPreviewOverlay.ets`（88 行）：可见性判定留宿主、主题色与顶部安全区以 `@Prop` 传入、预览三态与解码结果 `artPreviewPixelMap` 经 `@ObjectLink skyCultureViewStore` 引用语义读取（该 PixelMap 从宿主 `@State` 收进 store —— 真机实测 `@Prop` 会深拷贝 PixelMap 致 `Image.onError`）、关闭/加载完成/失败/重试四个动作回注宿主（新增宿主方法 `retrySkyCultureArtPreview`），单体 19,173 → 19,134 行。**Phase 5d（已完成，2026-10-02）**：~~`objectInspectorModelOverlay`（45 行）~~ → `panels/overlay/ObjectInspectorModelOverlay.ets`（80 行）：可见性判定留宿主、模型数据（PixelMap / proceduralKind / opacity）经 `@ObjectLink objectMediaStore` 引用语义读取（跨组件传 PixelMap 禁止 `@Prop`，见 5c）、标题/模式提示/顶部安全区以 `@Prop`（titleText/noticeText/topInset）传入、关闭/重置/舞台手势三动作回注宿主，`object-model-close` / `object-model-stage` 锚点与 `BLOCK_HIERARCHY` 逐字保留；本片未连真机（改模拟器 UI-only，模型叠层本体待真机走查）。**模型叠层本体已于 2026-10-02 补做真机走查（同一诊断片修复了行星模型"本地资源解码失败"后）：`devecocli ui click` 打开 `object-model-stage` → `drag` 旋转（前后截图表征位移）→ 关闭回 `object-model-inline-stage`，进程存活；双指缩放未走查（`devecocli ui` 无多点触控）**，单体 19,134 → 19,098 行。**Phase 5 收口（2026-10-02）**：4 个 overlay（`polarScopeOverlay` / `objectInspectorMediaPreviewOverlay` / `skyCultureArtPreviewOverlay` / `objectInspectorModelOverlay`）**全部组件化、无遗留**，宿主 `build()` 只剩 `if (可见性) { <Component>({...}) }`，无参数化 `@Builder`、无 `@BuilderParam`。**下一步 Phase 6 六个壳层**：~~`scriptFocusShell`~~（6a）/ ~~`compactShell`~~ / ~~`harmonyShell`~~（6b）已抽出；剩余 `hoverObservatoryShell` 142 / `expandedShell` 128 / `interactiveGuideShell` 78。**构建侧收口（2026-10-02）**：Windows 资源同步脚本 `sync-ohos-resources-windows.ps1` 已用 `System.Drawing` 生成 `.model.rgba` 侧车（50×512×256 + 3×512×2，共 53 个），行星模型恢复“侧车优先”快速路径（应用内 PNG 回退保留为兜底），见 CHANGELOG。 |
| 12 | **Phase 7 收口** | **已完成（Phase 7：删 8 个零引用 `private` 方法 + 2 个零引用字段（含 `TimeTick` 接口与导入）+ 1 处陈旧注释；`observationTimeText` 收入 `TimeStore`；单体 18,689 → 18,593，−42.9% → −43.1%；校正 `UI-ARCHITECTURE.md`、根 `AGENTS.md`；真机开合时间面板验证通过；**队列已空** —— 收口结论见下）** | |
| 13 | **Phase RA 资源覆盖审计（非 UI 切片）** | **已完成（Phase RA：修正 `scripts/audit-ohos-resource-coverage.mjs` 的 skycultures 期望集与陈旧结论、纳入 `scenery3d` 并新增"未随包家族与原因"；以签名 HAP + 真机 `getDeepSkyImageStatus` 逐族核对。结论：**所有应随包的运行时资源均已进包**；FOV 横幅的 N 是视口内纹理**加载中**数量而非缺失（`missingCount=0`、`referenced=onDisk=674`）；仅 `models/`（17.8 MiB）与 `atmosphere/`（58.7 MiB）按默认关闭的配置项启用，属**待决策**不擅自打包。详见 CHANGELOG [2026-10-02] 与 `docs/harmonyos/archive/audits/RESOURCE-COVERAGE-AUDIT-2026-08-24.md`）** | 审计报告已随包提交 |


#### Prop 风格域转 Store 追加队列（review §2.7，2026-10-04）

- **已完成（第三批，2026-10-04）**：`archaeo`（`ArchaeoStore` 18 字段 + `ArchaeoLinesPanel`）、`navStars`（`NavStarsStore` 14 字段 + `NavStarsPanel`）、`polarScope`（`PolarScopeStore` 6 字段 + `PolarScopeOverlay`）三域由 Prop 风格转 Store 风格；宿主 `@State` 266 → 231。
- **viewCoordinate 经核查无字段可迁，不改**：`viewCoordinatePrimaryText/SecondaryText`（50ms 定时器回填）与 `viewCoordinateOffsetX/Y`（拖拽逐帧写）按规则"高频字段不入被观察 store"留宿主；`ViewCoordinateSettings` 早已用 `OverlayStore`，`ViewCenterCoordinateOverlay` 以 `@Prop` 接收读数 —— 故不新建 `ViewCoordinateStore`。
- **已完成（前序，2026-10-04）**：`satellites`（`SatelliteStore`，28 字段）、`script/recording/video`（`ScriptStore`）、`scenery3d`/`catalogs`/`meteorShowers`/`commandConsole`（四簇同批，共 24 字段）。
- **已完成（第四批，2026-10-04）**：`mosaicCamera`（`MosaicStore` 10 字段 + `MosaicCameraPanel`）、`observingList` 残留（`ObservingListStore` 2 字段 + `ObservingPanel`/`ObjectPanel`/`ConfigFallbackPanel` 改 `@ObjectLink`）、`audio`（`AudioStore` 2 字段 + `AudioPanel`）、`eclipse` 起始日期（并入既有 `AstroStore` 3 字段，宿主自用）。宿主 `@State` 238 → 224。`test-ohos-satellite-panel.mjs` / `test-ohos-plugin-panel-state.mjs` 假宿主已随 store 同步，卫星脚本存量失败清除。
- **已完成（第五批，2026-10-04）**：两簇**残留字段并入既有 store**（不新建）—— ① 星空文化列表 / 当前选择：`skyCultures` / `skyCultureList` / `skyCultureListLoading` / `currentSkyCulture` / `currentSkyCultureId`（5 字段）并入 `SkyCultureViewStore`，消费方 `LayersPanel` / `SkyCultureViewTab` / `SettingsQuickLegacyPanel` / `ConfigFallbackPanel` 由 `@Prop` 改 `@ObjectLink`；`skyCultureArtStates` / `skyCultureArtThumbnailPixelMaps` 按"分块/防抖渐进写入＝高频不入 store"仍留宿主。② 脚本播放引擎 / 回放 / 视频导出（16 字段）并入既有 `ScriptStore`，`ScriptFocusShell` 改 `@ObjectLink`（播放/回放四态直接读 store，文案/几何仍宿主算好 `@Prop` 下发）；`recordBuffer` 按"追加型工作缓冲"留宿主。宿主 `@State` 217 → 196；`test-ohos-privacy-startup.mjs` 第 13 项夹具补齐 `fileSize` 形参后 19/19 全绿。
- **已完成（第六批，2026-10-04）**：三簇 Prop 风格域转 Store（均**新建**独立 store）—— ① `ephemeris`（11 字段）→ `state/EphemerisStore.ets`（DE430/431/440/441 的 Available/Active + `ephemerisStartYear/Month/Day`）；因 `AstroStore` 已有同名前缀但语义无关的星历表字段族，故独立不并入；`SettingsPanel` 8 个 DE `@Prop` → 1 个 `@ObjectLink`。② `nebulaTexture`（5 字段）→ `state/NebulaTextureStore.ets`；`NebulaTexturesPanel` 11 个派生 `@Prop` → 1 个 `@ObjectLink`（就地读 `nebulaTextureStatus`）。③ `pluginList`（2 字段）→ `state/PluginStore.ets`；`SettingsPanel` 2 个 `@Prop` → 1 个 `@ObjectLink`。宿主 `@State` 196 → 181。**`dso` 计数（`dsoTotalCount`/`dsoGalaxies`/`dsoClusters`/`dsoNebulae`）经普查确认零读取、`loadDSOCounts` 零调用，属写后即弃死状态，未并入 `LayerViewStore`、留宿主**。`test-ohos-plugin-panel-state.mjs` 假宿主已随 store 同步（4/4 全绿）。

**每个 Phase 4 面板切片前**建议先跑一次第 13.2 步 1 的"零引用扫描"，把死代码清掉再搬迁（§11 修订 6 的四类判据）。

#### Phase 6 收口结论（2026-10-02，Phase 6d 后）

六个壳层全部组件化：`ScriptFocusShell`（6a，251）/ `CompactShell`（6b，268）/ `HarmonyShell`（6b，90）/ `HoverObservatoryShell`（6c，242）/ `ExpandedShell`（6c，232）/ `InteractiveGuideShell`（6d，116）。宿主 `build()` 现只剩五类结构：

1. **顶层 `Stack`**：语言刷新锚点 `Text(i18nLang)`、gl-probe `XComponent`、隐私放行后挂载的 `qohos` NODE `XComponent`、两处触摸反馈 `Row`、全屏触摸承接 `Stack`（`handleOverlayTouch`）。
2. **布局三选一分发**：`if (!scriptPlaybackVisible() && !recording && !polarScopeVisible)` → `Stack { if isFoldHoverLayout → HoverObservatoryShell else if isExpandedLayout → ExpandedShell else → CompactShell }`；每个壳之后的 `if (panelVisible) { Stack { this.compactPanel() / this.floatingPanel() } }` 面板包裹仍在宿主（跨组件不能调用宿主 @Builder，规则 9）。
3. **脚本/导览焦点层**：`if (scriptPlaybackVisible()) { if (guideState.active) InteractiveGuideShell else ScriptFocusShell }` + `RecordingFocusShell`。
4. **Dock 命中区**：Dock 顶层命中靶 `Stack` + `HarmonyShell`（坐标叠层 / 陀螺仪指引 / 点击反馈气泡）。
5. **浮层与状态条**：`RecordingControlBar` + `PolarScopeOverlay` + 三个 Phase 5 Overlay（星空文化美术预览 / 详情媒体全屏 / 详情模型沉浸）+ `skyTextureStatus` 状态条。

#### Phase 7 收口结论（2026-10-02，队列收尾）

> 本节原为"下一片待办"，现已全部执行，队列**清空**。

- **文档校准（已完成）**：`docs/harmonyos/specs/UI-ARCHITECTURE.md` 全量改写 —— §2 行数改为 18,593，删除 §3/§4/§4.4/§5 中**所有易失真的 `文件:行号` 引用**，改为组件名 + `panels/shell/*.ets` 路径；§4.4 由"三种壳层 Builder"改为"壳层组件表"；§6 命中分布改为宿主单体实测并注明其余在 `panels/**`；§10 核对方法补 `check-ohos-ui-contract.mjs`。根 `AGENTS.md` 新增 UI 结构约定条目（`panels/panels/**`、`panels/shell/**`、`state/*Store.ets`、V1-only、`.id()` 契约）。
- **宿主转发层复核（已完成，无需改代码）**：`return this.<store>.<x>` 型纯转发 getter **0 处**（唯一形似者是 `selectedDisplayValue()` 的 `switch` 分派表，不是转发层）。`observationTimeText` **已收入 `state/TimeStore.ets`**（`timeRateText` 早已在其中）；`nmText()`/`nmSub()`/`nmAccent()`/`nmBg()` 等夜视色助手是 `nightMode` 的纯函数，**技术上可并入 `NightModeStore`**，但全部调用点都在宿主（消费方经 `@Prop` 拿颜色），下沉不减少行数；改用它们需让已持有 `nightModeStore` 的组件（`TimePanel`/`ConfigFallbackPanel`/`NightModeToggleRow` 等）就地取色，属**后续可选优化**，本片不做。`floatingPanel`/`compactPanel` 保留定论**仍成立**（体内 `this.panelContent()`，见 §13.1 规则 9），已在源码注释与本文件标注。
- **死代码扫描（已完成）**：用 §11 修订 6 四类判据重扫，确认并删除 **8 个零引用 `private` 方法**（`toggleDrawer` / `orbitColorStyleIndex` / `toggleSkyCultureLabelPicker` / `applySkyCultureCustomColor` / `setSkyCultureFilterValue` / `toggleSkyCultureFilter` / `formatDegrees` / `morePanelActive`，后三个与 `LocationStore`、`LayerViewTabs` 中的同名活实现无关）、**2 个零引用字段**（`gyroSensitivity`、`timeTicks`）及其连带的 `TimeTick` 接口与导入；级联复扫一次收敛，无新增。

#### 终态指标与剩余已知问题（2026-10-02）

- **单体行数**：32,705 → **18,593**（−43.1%）；本轮各提交末态见 CHANGELOG。
- **结构文件数**：`state/*Store.ets` **26 个**（+`TimeWheelController`），`panels/**` **119 个** `.ets`。
- **契约**：`check-ohos-ui-contract.mjs` = 33 面板 / 22 静态 id / 17 动态前缀 / 42 锚点 / 183+ `.ets`，全绿。
- **测试现状**：35 个 `scripts/*ohos*.mjs` 全部扫描，仅 §13.6 的 7 个存量环境类失败（4 个 `-pad` 需显式 `--device`、`mist-performance` 需设备、`verify-ohos-location-search.mjs` 路径 bug、`verify-ohos-search.mjs` macOS 假设），与本轮无关。
- **§13 队列**：**已空** —— §13.5 表内 1–12 全部完成。
- **剩余已知问题（非本轮引入，待后续单独处理）**：
  1. 陀螺仪校准面板 `GyroCalibPanel` 在当前 UI 无入口（活路径是 `gyroRotationCallback`，勿误判死代码）。
  2. `settings_quick_legacy`（`SettingsQuickLegacyPanel`）无入口死分支。
  3. `object` 分支在 expanded 构型不可达。
  4. `OFFLINE_APPGALLERY_BUILD` 跳过 astro 面板前四段，需非 appgallery 构建在真机走查。
  5. `nm*` 夜视色助手可按上文评估结果选择性下沉 `NightModeStore`。
  6. **Phase 3ad 引入、已修复**：详情卡页头三枚摘要（星等/星座/距离）切换天体不刷新 —— 见 §13.5 第 3 行与 CHANGELOG `[2026-10-02] 修复：详情卡页头三枚摘要…`。教训已固化：ArkUI V1 局部刷新按元素登记依赖，组件内动态值不得只经普通成员回调求值。



### 13.8 历史重写：从分支起点剔除 `build/` 跟踪与全部同步提交（2026-10-01，**仅本地**）

**目标（用户要求）：** 从 `997c007e3`（本分支基点）起，`build/` 目录**从一开始就**不被跟踪，并从历史中剔掉所有 `chore(harmonyos): sync the tracked generated copy of MainWindowNativeNode.ets` 提交。

**结果：** 区间提交 **80 → 52**（29 个纯 build 同步提交被剪掉，+1 个专门的取消跟踪提交）；区间内触碰 `build/` 的提交**只剩那一个**；`sync` 提交 **0**；**最终 HEAD 的树与重写前逐字节一致**（源码/脚本/文档/插件/C++ 全 0 差异）。

**做法（可复现）：**

1. `git filter-branch --prune-empty --index-filter "git rm -r --cached --ignore-unmatch build" 997c007e3..HEAD`
   —— 每个提交的索引里都删掉 `build/`；29 个"纯 build"提交因此变为空被 `--prune-empty` 剪掉，其余提交保留（树去掉 build/）。
2. 用 plumbing 在**分支起点**插入一个专门的取消跟踪提交（不切工作区）：临时索引 `GIT_INDEX_FILE` + `git read-tree 997c007e3` + 对 **11 个文件逐个** `git rm --cached` + `git write-tree` + `git commit-tree -p 997c007e3`，然后 `git rebase --onto <U2> <旧U> feat/api26-pages-refactor`。
   —— 这样分支的**第一个提交**就是 `chore(git): stop tracking the generated copies under build`。

**踩坑：** 在临时索引里用**目录 pathspec**（`git rm -r --cached build`）会**静默失败**，树里仍留 11 个 `build/` 条目，于是删除动作被记到了下一个不相关的提交上（表现为"Phase 0 提交也碰 build/"）。改为**显式 11 个文件路径**，并在 `commit-tree` 前断言 `git ls-tree -r <tree> -- build` 为 0。

**与远端：** `origin/feat/api26-pages-refactor`（`55f6ce49f1`）是重写前本地 HEAD 的祖先；重写后所有哈希变化，故同步必须
`git push --force-with-lease origin feat/api26-pages-refactor`。**本次未执行推送**；远端内容均已作为改写后的提交保留（例如 `05f0e93341 docs(harmonyos): trace the provenance of every removed block`）。

**备份与清理：** 重写前的 `eea49e386c` 保留在 `refs/heads/backup/pre-build-untrack-rewrite` 与 `refs/original/refs/heads/feat/api26-pages-refactor`。确认无误后可删（删后旧对象才会被回收）：

```powershell
git update-ref -d refs/original/refs/heads/feat/api26-pages-refactor
git branch -D backup/pre-build-untrack-rewrite
git reflog expire --expire=now --all; git gc --prune=now
```
