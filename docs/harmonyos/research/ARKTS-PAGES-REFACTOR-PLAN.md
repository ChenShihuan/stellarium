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

### 1.3 最大的 Builder（拆分靶点，前 15）

| 行数 | 起始行 | 名称 |
|---:|---:|---|
| **5,138** | L24531 | `panelContent`（33 个面板的 if/else 分发） |
| 3,441 | L12362 | `searchFilterMenu` |
| 1,970 | L5948 | 匿名 `Column` |
| 1,399 | L10695 | 匿名 `Stack` |
| 1,331 | L31444 | `layerPresetBar` |
| 1,141 | L17710 | `hierColumn` |
| 1,003 | L15811 | `wutTargetCard` |
| 893 | L20805 | `tabletObjectInspector` |
| 760 | L4966 | `scriptKeyButton` |
| 715 | L8202 | `phenomenonRelationMark` |
| 592 | L17021 | `continuationSection` |
| 525 | L8917 | `astroSelectionGuide` |
| 459 | L9495 | 匿名 `Column` |
| 448 | L29669 | `toolsPanel` |
| 368 | L9977 | 匿名 `Column` |

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
| **7 收口** | 删除过渡 getter 与死代码，主文件降至 ≤2k 行；更新 `specs/UI-ARCHITECTURE.md` 与 `AGENTS.md` §2.2 | 1 周 | 全量回归 + 文档行号校正 |

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
