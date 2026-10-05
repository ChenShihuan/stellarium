## [2026-09-30] DevEco Code - Phase 3j：死代码清扫第二轮（13 个零调用 @Builder + 31 个零引用字段 + 级联 9 方法，−650 行）

- **触发：** 用户反馈"陀螺仪功能正常"，据此把扫描**扩大到 @Builder 与字段**（第一轮只扫 `private` 方法），并加入**级联复扫**（删除后重新扫描，直到收敛）。
- **反向验证（重要）：** 活着的陀螺仪路径是 `sensor.on(ROTATION_VECTOR, this.gyroRotationCallback)` / `gyroGravityCallback` / `gyroMagneticCallback` / `onOrientationData`（L12605–L12702）；被删的 `onRotationVectorData` 是**旧版同职责残留**。这既解释了"功能正常"，也反向验证了"零引用=不可达"判据成立。
- **A. 零调用的 `@Builder`：13 个（约 519 行）** —— `collapseButton` / `compactObjectPeek` / `compactQuickControls` / `configurationSkyDisplaySettings` / `detailInfoRow` / `expandedObjectSummary` / `objectActionBar` / `objInfoFloat` / `observerBadge` / `padExploreHome` / `railShell` / `smallRoundButton` / `tabletObjectInspector`。
  - 判据：`this.<name>(` 调用点为 0；并逐个核对"全文件出现次数"，排除同名前缀干扰（`compactObjectPeek` 出现 16 次、`objectActionBar` 7 次，但都是 `compactObjectPeekX/Y/Width`、`objectActionBarX/Y/Width/isObjectActionBarPoint` 等**活助手**，其本身只出现 1 次）。
  - 其中包括初始调研中体积最大的 `tabletObjectInspector`（当时 893 行）与整套 `railShell`/`padExploreHome`/`objInfoFloat`/`observerBadge` **旧抽屉/平板布局变体**。
- **B. 零引用字段：31 个** —— 第一轮 25 个（`fpsDisplay`/`fpsFrameCount`/`fpsLastTime`/`fpsVisible` FPS 残留、`gyroReferenceAz/Alt/ViewAz/ViewAlt`、`showAstroPanel`/`showConfigPanel`/`showHelpPanel`、`scriptPanelScroller`、`expandedTargetPlacementTimer`、`nightViewTab`、`timeScale`、`visibleConstellations`、`tonightPlanets`、`lightPollution`、`asteroidLines`/`asteroidLabels`、`startupPreparing`、`autoLocateStarted`、`centerSearchText`、`infoTextExpanded`、`gyroLastDiagnosticMs`），级联轮再加 `railCollapsed` 与 `gyroAnchorFwd`/`gyroAnchorQuat`/`gyroAnchorUp`/`gyroAnchorValid`/`gyroHeadingSyncInFlight`。
- **C. 级联复扫（3 轮收敛）：9 个方法** —— 第 1 轮：`formatLocalDateTime` / `infoWinDetailH` / `objectInspectorSubtitle` / `rectsOverlap` / `startTimeWheelTransition` / `syncGyroAnchor`；第 2 轮：`gyroAltAzVector` / `gyroEnuFromBridge` / `pad2`。
  - 值得注意的是 `startTimeWheelTransition`：它的唯一调用者是第一轮已删的 `advanceTimeWheel`，说明**"按步进推进时间"这条支路（含其 12 ms 过渡定时器）在清理前就已经不可达**；其定时器 `timeWheelTransitionTimer` 因此永不被启动（`finishTimeWheelTransition` 恒早退），行为不变。
- **过程教训（已在文档记录）：** 删除字段时若其声明**上方有独立装饰器行**（本例 `@StorageLink('stellariumStartupPreparing')`），只删声明行会留下孤立装饰器并叠加到下一个属性，构建立刻报 `cannot have multiple state management decorators`；已补扫"非 `@Watch` 装饰器紧邻另一个装饰器"并以该模式修掉 1 行。**即：删字段必须连同其装饰器行一起删。**
- **验证结果：** `arkts_check` 无错误；`BUILD SUCCESSFUL`；契约校验通过；真机安装启动成功；时间面板渲染、刻度轮拖动（速度转「已暂停」）与「实时」恢复（`1x`）回归通过；右上角陀螺仪按钮点按不崩溃（进程 pid 不变）。
- **单体行数：** 30,879 → **30,229**（本片 −650）。

## [2026-09-30] DevEco Code - Phase 3i：系统性死代码普查并删除 39 个不可达方法（−498 行）

- **普查方法：** 该 struct 的**全部方法都是 `private`**（不可能有外部调用者），因此"文件内零引用 = 不可达"。对 1,090 个 `private` 方法逐个统计三种引用形式：`this.<name>(`、裸引用 `this.<name>`、字符串 `'<name>'`（含 `@Watch('…')` 按名调用、以及可能的字符串分派），并排除框架生命周期方法（`aboutToAppear` / `aboutToDisappear` 等）与 `@Watch` 引用的两个方法（`onPrivacyNativeStartupAllowedChanged`、`onCliUiEventChanged`）。
- **结果：39 个方法三种引用形式**全部为 0**，合计约 469 行方法体（删除后文件 −498 行，含空行）。按用途分组：**
  - **陀螺仪（7 个，约 197 行）：** `onRotationVectorData`(119) / `gyroForwardFromGravityAndMagnetic`(22) / `gyroSlerpUnitVector`(21) / `alignGyroToMagneticNorth`(12) / `gyroParallelTransportUp`(10) / `calibrateGyroscopeQuaternionUnused`(10) / `gyroEffectiveAzOffset`(3)
  - **对象卡片定位（4 个，约 103 行）：** `placeObjectCardAwayFromTarget`(53) / `easeSelectedObjectTo`(36) / `placeSelectedObjectInCompactSafeArea`(7) / `placeSelectedObjectInExpandedSafeArea`(7)
  - **抽屉/信息窗几何（9 个）：** `isCompactDrawerPoint` / `handleCompactMoreTap` / `handleFloatingPanelTouch` / `isTabletObjectInspectorPoint` / `bottomCardHitHeight` / `bottomCardSwiperHeight` / `drawerLeft`（单行方法） / `infoWinLeft` / `infoWinWidth`
  - **时间相关（3 个）：** `advanceTimeWheel`(21) / `setTimeNow`(8) / `adjustTime`(6)
  - **其余杂项（16 个）：** `nm` / `tickPercent` / `runOnTouchUp` / `toggleTracking` / `trackStatusZh` / `triggerAutoLocate` / `cycleOcular` / `pauseScript` / `resumeScript` / `pluginFeaturePanel` / `objectInspectorFileUri` / `isConstellationSelection` / `skyCultureRangeModeIndex` / `skyCultureClassificationFilterIndex` / `skyCultureRegionFilterIndex`(10) / `defaultSkyCultureMakerDraft`(17)
- **需要产品复核的"疑似漏接线"项（删除不改变行为，但可能掩盖了未接的意图）：** ① `onRotationVectorData` 及整套陀螺仪四元数数学——像是**传感器回调未注册**；② `pauseScript` / `resumeScript`——脚本暂停/继续入口未接；③ `toggleTracking` / `triggerAutoLocate` / `setTimeNow` / `adjustTime`——功能入口未接；④ `placeSelectedObjectIn*SafeArea` / `easeSelectedObjectTo` / `placeObjectCardAwayFromTarget`——对象卡片避让逻辑未接。以上已记入方案文档 §11 修订 6，**若本应接线，应作为功能缺陷单独处理，而不是继续躺在死代码里**。
- **过程记录（教训）：** 首轮脚本用"下一个 `\n  }\n`"作为方法结束标记，遇到**单行方法**（`private drawerLeft(): number { return this.EDGE_MARGIN }`）时越过其边界，把中间的 `drawerWidth` / `onRailTap` 等一并删除，构建立即报 `Property 'onRailTap' does not exist` 捕获；已还原并对单行方法特判后重做，编译与真机回归均通过。**结论：删除脚本必须处理单行成员，且必须由编译器兜底。**
- **验证结果：** `arkts_check` 无错误；`BUILD SUCCESSFUL`；契约校验通过；真机安装启动成功；时间面板渲染、刻度轮拖动（速度变「已暂停」）与「实时」恢复（`1x`）回归通过。
- **单体行数：** 31,377 → **30,879**（本片 −498）。

## [2026-09-30] DevEco Code - Phase 3h：清理旧转轴死子系统（−126 行，并消除高频链上的无效重渲染）

- **调查结论（可证明死代码）：** 旧滑杆入口 `applyScrubber(secondOffset, mode)` **没有任何调用者**（滑杆 UI 早已被 Sky Guide 风格时间轮取代）；顺着它往下，`beginScrubberInteraction` / `sendScrubberTime` / `updateScrubberLabel` 只被彼此调用，而 `syncScrubberToSimulation` / `resetScrubberToRealtime` 虽被活代码调用，但其**写入目标全是只写不读的字段**（`scrubberValue` / `scrubberLabel` / `scrubberReferenceJd` / `scrubberPendingOffset` / `scrubberAnchorPending` / `scrubberLastSendMs` / `scrubberInteracting` 全部无读取点）。因此整条链是死代码。
- **删除内容：** 7 个字段声明（其中 `scrubberValue` / `scrubberLabel` 是 `@State`）、6 个方法（`updateScrubberLabel` / `beginScrubberInteraction` / `sendScrubberTime` / `applyScrubber` / `syncScrubberToSimulation` / `resetScrubberToRealtime`，原 L11799–L11908 区块）、5 处调用点（`jumpToTimeMark` 内 2 行、`refreshSimTimeLight` 内的 `if (!this.scrubberInteracting)` 整块、`applyJulianDateInput` 1 行、`handleChip('now'/'realtime')` 各 1 行）。
- **附带修复（性能）：** 被删的两个 `@State` 字段原本由 `syncScrubberToSimulation` 在**每次模拟时间刷新**时写入——每次写都让整个 31k 行 struct 的重渲染范围被打脏。删除后这条高频路径不再产生无效重渲染（符合方案"高频链隔离"的目标）。
- **另一处收口：** `timeMarkLoading` 只是 `jumpToTimeMark` 的重入守卫、不参与渲染，已由 `@State` 降为普通 `private` 字段（少一个无谓的响应式变量）。
- **验证结果：** `arkts_check` 无错误；`BUILD SUCCESSFUL`；契约校验通过；真机安装启动成功；回归拖动（小时单位下改时间不改日期，符合预期）与「实时」恢复（`2026-09-30 · 1x`）均正常。
- **单体行数：** 31,503 → **31,377**（本片 −126）。

## [2026-09-30] DevEco Code - Phase 3g：时间转轴 + 时间轮整体迁移（真机调试：点字段、拖动、切单位、引擎同步全部通过）

- **新增文件：** `state/TimeWheelStore.ets`（11 个原 `@State` 字段 + `timeWheelTrackBaseMs` + 两个刻度常量 + 纯计算方法：`majorInterval` / `isCalendar` / `shiftDate` / `dateAtOffset` / `dateAtFraction` / `tickValue` / `tickLabel` / `refreshTicks` / `visibleTickOffset` / `isVisibleMajorTick`）、`panels/time/TimeWheelScrubber.ets`（字段行 6 个按钮 + 刻度条 + 触摸层；刻度几何 `tickDistance/visibleTickLabel/tickScale/tickOpacity/tickBlur/tickHeight` 内联为组件私有方法）。
- **修改文件：** `pages/MainWindowNativeNode.ets` —— 11 个 `@State` 合并为 `@State private timeWheelStore`；两个 `readonly` 刻度常量与 `timeWheelTrackBaseMs` 字段移入 store；**88 处引用**改写为 `this.timeWheelStore.*`（含 `tickSpacing` / `centerTick`）；搬出 9 个纯计算方法与 7 个 builder（`timeScrubberSlider` + 6 个字段 builder）；调用点换成 `TimeWheelScrubber({ store, onSelectUnit, onWheelTouch })`；顺带删除**无调用者**的 `timeWheelCurrentLabel()`。
- **边界取舍（关键，保证行为路径零改写）：** store 只放"数据 + 纯计算"；**手势拖动、惯性、过渡、轨道重基准、引擎推送共 13 个方法（约 228 行，位置 `pages/MainWindowNativeNode.ets` L11910–L12149）+ 16 个手势草稿字段与 2 个定时器（L324–L339）全部留在宿主**，只把字段引用改为 store。这样这次迁移**没有重写任何一条交互逻辑**，只是状态归属与视图位置改变。（初版本条写为"约 400 行"，实测为 228 行方法体 + 字段，已更正。）
- **第四次命中同名冲突：** `onTouch` 与 `CustomComponent` 内置属性方法冲突（编译报 `Property 'onTouch' ... is not assignable to the same property in base type 'CustomComponent'`），改名 `onWheelTouch`。累记：`borderColor`、`scale`、`onTouch` 均不可作组件成员名。
- **真机调试（`192.168.3.95:40565`，全部通过）：**
  1. 渲染：字段行与刻度条节点坐标与迁移前**逐像素一致**（`2026 / 09月 / 30日 / 22: / 53: / 03`，刻度 `19时…01时`）。
  2. 点字段：点「2026」后刻度条**实时**切成 `2023 / 2024 / 2025 / 2026 / 2027 / 2028`，选中字段字号放大 → 组件→回调→store→@ObjectLink 实时链路成立。
  3. 拖动：左拖刻度条后日期**实时**变为 `2026-12-10`（字段行 12月/10日 同步、副标题与速度状态同步为「已暂停」），引擎推送生效。
  4. 切单位：点「22:」刻度条实时切回 `19时…`；点「实时」恢复现场为 `2026-09-30 · 1x`。
- **构建结果：** `arkts_check` 三文件无错误；`BUILD SUCCESSFUL`（一次同名冲突修正后）；契约校验通过。
- **单体行数：** 31,786 → **31,503**（本片净减 283 行；新增文件另计）。
- **范围约束：** 状态归属 + 视图位置迁移，交互逻辑零改写；除"字段/刻度现在实时刷新"外无行为变更。

## [2026-09-30] DevEco Code - Phase 3f：ΔT 算法块迁移（真机验证选择实时生效）

- **新增文件：** `state/DeltaTStore.ets`（`deltaTAlgorithm` / `timeDeltaTAlgorithms` / `timeDeltaTCustom` / `deltaTDescription`，字段名沿用原 `@State` 名）、`panels/time/DeltaTSettingsBlock.ets`（当前算法 + 算法列表 + 自定义系数输入 + 说明；`deltaTLabel()` 从单体方法搬入组件，store 保持无 UI 逻辑）。
- **修改文件：** `pages/MainWindowNativeNode.ets` —— 4 个 `@State` 合并为 `@State private deltaTStore`；8 处引用改写；`configTab === 3` 内的整段 ΔT UI（原 L24919–L24956）替换为 `DeltaTSettingsBlock({...})` 调用；删除 `deltaTLabel()`。
- **边界取舍（重要）：** `timeSettingsPending` **刻意不并入本 store**——它同时被「启动时间设置」区（同一标签页）与**其他面板**（`configTab` 之外的 L30057/L30089）读取；若并入 store，宿主体内那些读取将无法观测、`enabled` 状态会失去刷新。因此改由 `@Prop pending` 传入本组件，宿主保留该 `@State`。
- **验证结果（真机 `192.168.3.95:40565`）：** `arkts_check` 三文件无错误；`BUILD SUCCESSFUL`；契约校验通过；安装启动成功。
  - 路径：更多功能 → 设置 → 「时间」标签页 → 下滑至 ΔT 区块；区块由新组件渲染（`ΔT 算法` 标题 + 提示 + 当前算法「修订的 Espenak-Meeus（推荐）」+ 可选择列表）。
  - **实时联动：** 点选列表中的「不进行修正」后，上方「当前算法」行**立即**由「修订的 Espenak-Meeus（推荐）」变为「不进行修正」——子组件写 store 经 `@ObjectLink` 实时驱动。
  - 验证后已把算法**恢复原值**（列表行重新带 ✓）。
- **更正（用户澄清）：** 本条原记「在可点击列表上用 `ui swipe` 会被判为点选、本次误触改了两次算法」有误——那两次选择是**用户手动操作**设备所致，不是滑动误触。实际操作教训仅保留后半条：任何会写引擎设置的验证都必须在测后恢复原值（本次已恢复）。
- **范围约束：** 纯搬移 + 状态归属迁移，行为零变更。

## [2026-09-30] DevEco Code - Phase 3e：恒星时行 + 时间方程块迁移（真机验证数值实时与开关联动）

- **新增文件：** `state/EquationOfTimeStore.ets`（7 字段：`equationOfTimeEnabled/MsFormat/Inverted/Startup/Minutes/Loading/Status`，字段名沿用原 `@State` 名）、`panels/time/SiderealTimeRow.ets`（恒星时行 + 说明，`@ObjectLink TimeStore`）、`panels/time/EquationOfTimeBlock.ets`（标题开关 + 当前值 + 三个显示选项 + 失败提示；格式化逻辑 `displayText()` 从单体方法搬入组件，store 保持不含 UI 逻辑）。
- **修改文件：** `pages/MainWindowNativeNode.ets` —— 删除 `@State siderealTimeText`（并入既有 `TimeStore.siderealTimeText`）与 7 个 `equationOfTime*` `@State`（合并为 `@State private equationOfTimeStore`）；28 处引用改写（`this.equationOfTimeX` → `this.equationOfTimeStore.equationOfTimeX`；`equationOfTimeMutationId` 是普通字段仍留在宿主）；恒星时行/说明/时间方程块的整段 UI 替换为 `SiderealTimeRow({...})` 与 `EquationOfTimeBlock({...})` 两个组件调用；删除已搬入组件的 `equationOfTimeDisplay()`。
- **注意点（迁移顺序陷阱）：** 恒星时数值在旧实现下**本来就是实时**的（builder 内直接读状态）。若只把它移入 store 而不把读取它的 UI 一起搬进组件，宿主无法观测 store → 反而会**退化成不刷新**。本片因此把该行一并组件化。
- **验证结果（真机 `192.168.3.95:40565`）：** `arkts_check` 五文件无错误；`BUILD SUCCESSFUL`；契约校验通过；安装启动成功。
  - **数值实时：** 恒星时连续 3 次采样（间隔约 7.5 s）`22h 54m 05s → 22h 54m 11s → 22h 54m 17s`，随时间推进，无回归。
  - **开关联动：** 点「显示分钟和秒」后当前值由 `+10:04`（mm:ss）**立即**变为 `+10.1 分钟`，再点回恢复 `+10:04` —— 证明子组件写 store 经 `@ObjectLink` 实时驱动自身重渲染。
  - 测试后已把该设置点回原值（该开关经引擎持久化）。
- **范围约束：** 纯搬移 + 状态归属迁移，行为零变更。

## [2026-09-30] DevEco Code - Phase 3d：儒略日块迁移为 JulianDateStore + 两级组件（真机验证 JD 实时跳动）

- **新增文件：** `state/JulianDateStore.ets`（`@Observed`：`julianDayInput` / `modifiedJulianDayInput` / `julianDateEditing` / `julianDateError` / `julianCalendarSystem`）、`panels/time/JulianDateControls.ets`（容器：历法提示 + 两行输入 + 校验错误 + 说明）、`panels/time/JulianDateInputRow.ets`（行组件：标签 + 「-」/「+」+ 输入框）。
- **修改文件：** `pages/MainWindowNativeNode.ets` —— 5 个 `@State` 合并为 `@State private julianStore`；16 处引用改写为 `this.julianStore.*`；调用点 `this.julianDateControls()` 换成 `JulianDateControls({...})`（传 `nmText()/nmSub()/nmInput()` 主题色与 `onAdjust`/`onApply` 回调）；删除已迁走的 `julianDateControls()` 与**参数化** `julianDateInputRow(label, value, scale)` 两个 builder。
- **为什么用两级组件而非内联：** 本片避免重复代码（两行结构完全相同），改为 `@Prop` 行组件。真机实测确认 `@Prop` 能实时驱动（上一片的 chips 已验证同机制），因此无需像 chips 那样内联。
- **又一次命中同名冲突（第三次）：** `@Prop scale` 与 `CustomComponent` 内置属性方法 `.scale()` 冲突，编译报 `Property 'scale' ... is not assignable to the same property in base type 'CustomComponent'`；改名 `scaleKey` 后通过。已累记为规则：`borderColor`、`scale` 都不能作组件成员名。
- **验证结果：** `arkts_check` 四文件无错误；`BUILD SUCCESSFUL`；契约校验通过；真机安装启动成功。**实时刷新实测：** 滚动面板到儒略日块，连续 5 次采样（间隔约 6.8 s）输入框数值 `2461314.10052 → .10060 → .10067 → .10075 → .10083`（MJD 同步 `61313.60052 → .60083`），与经过时间一致——证明数值随时间实时刷新；旧实现的参数化 `@Builder` 会冻结该值（同机制已在速度 chips 上实测确认，本块未单独回测旧版）。
- **顺带确认（未改动）：** 恒星时行（`恒星时 22h 47m 17s`）与时间方程块（`当前值 +10:03`）在旧实现下即实时刷新——它们是在 builder 内直接读状态，不受参数化陷阱影响。
- **环境变更记录：** 真机 DHCP 换网段，串号由 `192.168.1.4:40565` 变为 **`192.168.3.95:40565`**（后续验证用新串号）。
- **范围约束：** 纯搬移 + 状态归属迁移；除 JD 值现在实时刷新（修复既有冻结）外无行为变更。

## [2026-09-30] DevEco Code - 修两个真机问题：速度 chip 标签去掉倍率（超宽）+ 消除「实时→倒带→实时」抖动

- **来源：** 用户在真机实测 store 版后反馈的两个问题。
- **修复 1（按钮行超宽）：** `panels/time/TimeSpeedChips.ets` 的 `倒带` / `减速` / `快进` 三个标签不再拼接倍率（删除三处 `+ ' ' + this.rateText`），并移除因此不再使用的 `@Prop rateText` 与调用点的传参。真机实测：五个 chip 标签为纯文案，最右「快进」右边界 **1137 < 1280**，整行不再超宽。倍率反馈仍由既有通道提供——点击时的顶部提示（`flashHint`，实测显示「倒带 -1时/秒」）与面板副标题（`2026-09-30 · 1x`）。
- **修复 2（高亮抖动）：** 现象为「倒带 → 实时」后界面走 `实时(乐观) → 倒带 → 实时`。根因在 `syncTimeRateState()`：它在引擎回报速率时**反推档位并写回 store**，而换挡瞬间引擎仍会回报上一档速率；超过既有 500 ms `pendingTimeRateUntilMs` 窗口后旧速率就会被接受，于是档位跳回旧档再跳回新档。此前 chip 子树的参数化 `@Builder` 冻结，该问题被掩盖，现在 chip 能实时刷新才暴露。
  - **改法：** 新增 `private lastSyncedTimeRate`，`syncTimeRateState` 在「引擎速率与上次同步值相同」时**直接 return**，不再重写 `timeRateText` 与 `timeStore.timeSpeedIndex`；仅在速率**真正变化**时同步文本与档位。两个方向（倒带→实时 / 实时→倒带）的旧速率回报都会被该去重吸收。
- **验证结果：** `arkts_check` 无错误；`BUILD SUCCESSFUL in 1 min 5 s 933 ms`；`node scripts/check-ohos-ui-contract.mjs` 通过；真机 `install bundle successfully` / `start ability successfully`；点「实时」后连续 8 次采样副标题稳定为 `1x`（采样粒度约 3.6 s，**瞬态抖动需用户肉眼复测确认**）。
- **范围约束：** 仅两处行为修复（去掉标签倍率、去重引擎速率回报），未改面板结构、未改 `.id()` 与 CLI 契约。

## [2026-09-30] DevEco Code - 真机三版对照实验定论：冻结根因是参数化 @Builder；store + 组件实时刷新成立并修复既有 bug

- **背景：** 上一轮两片 store 因"无法证明实时刷新等价"被回退。用户指示在真机做实验，遂在 **Mate 80 Pro（SGT-AL00 / arm64-v8a / API 26，引擎存活，`192.168.1.4:40565`）** 上做同一交互（打开时间面板 → 点「快进」）的三版对照。
- **实验数据（`devecocli ui layout` 实测）：**
  | 版本 | 副标题 | 「快进」chip | 判定 |
  |---|---|---|---|
  | ① 原生（`@State` + 参数化 `@Builder speedChip(...)`） | `2x` / `10x` | 始终「快进」、未高亮 | **既有 bug**（重开面板才更新） |
  | ② `TimeStore`+`TimeSpeedChips`，chip 仍走参数化 `@Builder` | `2x` / `10x` | 始终「快进」 | 与①**行为等价**（继承同一 bug） |
  | ③ `TimeStore`+`TimeSpeedChips`，chip **内容内联、直接读 store** | `2x` → `10x` | **「快进 2x」→「快进 10x」实时更新且高亮**（宽度随标签变化） | **修复 bug**，store 通路正确 |
- **定论（修正上一轮的推断）：** 冻结根因是**参数化 `@Builder` 的简单类型参数按值捕获**（`speedChip(id,label,icon,active)` 子树首帧后冻结），与"组件是否创建在 `panelContent()` 这个 @Builder 体内"**无关**。`@ObjectLink`（store 字段变化）与 `@Prop`（父传 `rateText`）**都能实时驱动子组件重渲染**——③ 版实时更新即为证据。因此上一轮"Phase 4 的 PanelHost 可能必须先于 Phase 3"的推断被推翻：**Phase 3 不必等 Phase 4**。
- **对后续每个切片的强制自检项：** 搬迁 UI 时必须**去掉参数化 `@Builder`**（改为子组件 `@Prop` 或直接读状态），并且验收必须包含"点击后是否实时更新"的交互实测，不能只看布局是否一致。
- **UI-only 模拟器的适用范围修正：** 该实验证明模拟器（无引擎、定时器不产生写入）**不能裁决刷新类问题**——原生与重构版在模拟器上都表现为"不刷新"。刷新类验收必须在真机执行。
- **本轮改动：** 保留 ③ 版（`state/TimeStore.ets`、`panels/time/TimeSpeedChips.ets`、单体 `timeSpeedIndex` → `@State timeStore` 与 21 处引用改写、删除已迁走的 `speedChip` 参数化 builder）；文档更新 `research/ARKTS-PAGES-REFACTOR-PLAN.md` §11 修订 4。
- **构建/验证：** `arkts_check` 无错误；`BUILD SUCCESSFUL in 1 min 331 ms`；真机 `install bundle successfully` / `start ability successfully`；上述三版数据均在同一台真机、同一交互下实测。
- **已知取舍：** ③ 版内联写法有重复代码（5 个 chip 各一份属性），后续清洗为子组件 `SpeedChip`（`@Prop`）时**必须重做真机实时刷新实测**。
- **行为变更声明：** 本轮**有意**改变了用户可见行为——「快进」等速度 chip 的标签与高亮现在会实时更新（原先需重开面板）。这是修复既有 bug，不是等价重构。

## [2026-09-30] DevEco Code - Phase 3 首两片尝试后回退：store + 组件的实时刷新路径未证实（既有现象）

- **经过：** 按 (b) 方案试做两片并各自单独提交 —— ① `BookmarkStore` + `BookmarkPanel`（3 字段 / 12 引用 / 85 行面板分支）；② `TimeStore` + `TimeSpeedChips`（`timeSpeedIndex` / 21 处引用 / 速度 chips）。两片均通过 `arkts_check`、`BUILD SUCCESSFUL`、契约校验与模拟器安装启动，并实证了**状态归属正确**：书签面板输入后切走再切回（组件销毁重建），输入内容仍在。
- **未通过项（实时刷新）：** 抽成组件后点击「快进」，`applySpeedStep` 确实写入 store（重开面板显示「快进 2x」）、副标题立即变 `2x`，但**面板开着的期间 chip 标签与高亮都不更新**；点「停止」同理（未变「继续」）。即子组件的 `@ObjectLink` 与 `@Prop` 都未触发重渲染，而该组件由 `panelContent()` 这个 `@Builder` 体创建。
- **关键对照实验：** `git revert` 回原生实现后重装实测，**原生版本行为完全相同**（副标题 `2x`、chips 仍「快进」未高亮，截图确认 99,283 B）。因此这是**既有现象**（推断：面板实时刷新依赖 `timePanelTimer` 等周期性定时器写入 @State，UI-only 模拟器无引擎数据、定时器不产生写入），**不是本次重构引入的回归**；但本次重构同样**无法证明刷新等价**，故按"行为零变更"不变式回退，不保留未证实等价的重构。
- **动作：** `git revert` 两片（`c1a4ae7dca` 回退生成副本同步、`71a524ffbe` 回退 bookmark store 与面板），同时删除 `state/BookmarkStore.ets`、`panels/BookmarkPanel.ets`、`state/TimeStore.ets`、`panels/time/TimeSpeedChips.ets` 与对应的 CHANGELOG 条目；回退后重建复测，契约校验通过，工作区与本轮起点（`c0e9402b4a`）差异为 **0 行**。
- **仍沉淀的两条 ArkTS 规则（后续复用）：** ① `@ObjectLink` 的宿主源必须是可观察状态（`private` 字段会被编译器拒绝，须 `@State`）；② 组件成员不能与 `CustomComponent` 基类属性方法同名（`borderColor` → `cardBorderColor`）。
- **后续依据：** 结论已写入 `research/ARKTS-PAGES-REFACTOR-PLAN.md` §11 修订 4 —— 先在**真机**做受控实验建立实时刷新基线（原生 chips 是否实时更新、`@ObjectLink` 组件是否等价），据此决定 **Phase 4 的 `PanelHost`（面板宿主改为由 `build()` 直接实例化的组件）是否必须先于 Phase 3**。
- **范围约束：** 本轮最终净改动仅为文档；应用源码回到 Phase 1c 状态，行为零变更。

## [2026-09-30] DevEco Code - Phase 1c：抽出 MainWindowModels（93 个文件作用域类型与常量）

- **新增文件：** `harmonyos/ets-source/pages/MainWindowModels.ets`（764 行）—— 原单体序言区（`interface CityPreset` 起、`@Component` 前）的全部文件作用域声明整体搬移，共 93 个（interface / const / class），逐条加 `export`；并复制单体的 `./StellariumTypes` 导入，因为 `Scenery3dResponse` 等引用了 `Scenery3dItem` 等类型。
- **修改文件：** `harmonyos/ets-source/pages/MainWindowNativeNode.ets` —— 序言区替换为一条折行的 `import { ... } from './MainWindowModels'`（93 个符号、16 行，按 6 个/行折行）。
- **过程中修正：** 首轮构建报 `Cannot find name 'Scenery3dItem'`（模型模块内 `Scenery3dResponse` 的字段类型来自 StellariumTypes）→ 把单体的 `./StellariumTypes` 导入整条复制进模型模块后构建通过。
- **验证结果：** `arkts_check` 两文件无错误；`BUILD SUCCESSFUL in 58 s 212 ms`；`node scripts/check-ohos-ui-contract.mjs` 通过；模拟器 `127.0.0.1:5555` 安装启动成功，点击 Dock「时间」仍能打开时间面板（标题「时间 --」、`panel-close`、速度 chips 倒带/实时/快进），且截图字节数与改动前完全相同（70,061 B）。
- **范围约束：** 纯搬移（只有类型与常量声明，无运行时代码改动），行为零变更。

## [2026-09-30] DevEco Code - Phase 2：抽出命令桥 BridgeClient（libentry.so 唯一出口）

- **新增文件：** `harmonyos/ets-source/bridge/BridgeClient.ets` —— `request()`（发送并解析回包，失败统一 `{ ok:false, error:'bridge parse failed' }`）、`send()`（fire-and-forget 原始回包）、`requestWhenReady()`（未就绪时短退避重试）、`requestInteractive()`（50 ms × 40 交互轮询）。
- **修改文件：** `harmonyos/ets-source/pages/MainWindowNativeNode.ets` —— `callNative` / `callNativeFire` / `callNativeWhenReady` 改为薄委托并保留录制钩子 `recordAcceptedCommand`；`callInteractive` 及其 203 个调用点完全不动；删除 `import { command } from 'libentry.so'`，改为 `import { BridgeClient } from '../bridge/BridgeClient'`（ArkTS 侧不再直接触碰 NAPI 导出）。
- **行为等价性核对：** ① `callNative`——原来在 try 内 parse 后记录，现由 `BridgeClient.request` 负责 parse、宿主在 `ok === true` 时记录，parse 失败同样不记录；② `callNativeFire`——原来 `command()` 抛错即静默忽略，现 `send()` 返回空串即早退，同样不记录；③ `callNativeWhenReady`——重试循环搬入桥，成功时仍只经宿主包装函数记录一次再回调 `onOk`，记录与回调顺序不变。
- **验证结果：** `arkts_check` 无错误；`BUILD SUCCESSFUL in 57 s 858 ms`；`node scripts/check-ohos-ui-contract.mjs` 通过；模拟器 `127.0.0.1:5555` 安装启动成功，点击 Dock「时间」仍能打开时间面板（标题「时间 --」、`panel-close` 锚点、速度 chips 倒带/实时/快进 均在），说明经桥的命令链在 UI-only 模式下行为未变。
- **遗留（待后续切片）：** `qability/QAbility.ets` 仍直接 `import { command } from 'libentry.so'` 用于 `setApplicationForeground` 生命周期通知，未纳入本次桥封装。

## [2026-09-30] DevEco Code - Phase 1b：把纯函数 getIcon 抽到 common/ui/ShellIcons

- **新增文件：** `harmonyos/ets-source/common/ui/ShellIcons.ets` —— `export function getIcon(icon: string, isActive: boolean): Resource`，图标名到 `$r('app.media.*')` 的纯映射（原方法体逐行搬移）。
- **修改文件：** `harmonyos/ets-source/pages/MainWindowNativeNode.ets` —— 删除 52 行私有方法 `private getIcon(...)`，改为 `import { getIcon } from '../common/ui/ShellIcons'`；61 处调用点由 `this.getIcon(` 机械改为 `getIcon(`（保留 `isActive` 形参以免改动 61 个调用点的实参）。
- **与方案的偏差（实测结论）：** Phase 1 原计划一并抽 `dockButton` / `switchRow` / `iconButton`，实测前两者都带宿主状态与事件回调（`isExpandedLayout`、`compactDockIconSize()`、`dockActionActive()`、`handleDockTouch()`、`activateDockAction()`、`switchRow` 的 `actionId`/`cmd`），不属于「无状态叶子」；`iconButton` 只有 1 处调用、仅 28 行。三者的组件化统一并入 Phase 4/6（届时以 `@ObjectLink` 接 store，避免先做一次会被推翻的组件化）。已把该偏差记入本条目，Phase 1 的叶子抽取到此收口。
- **验证结果：** `arkts_check` 无错误；`BUILD SUCCESSFUL in 58 s 837 ms`；`node scripts/check-ohos-ui-contract.mjs` 通过；模拟器 `127.0.0.1:5555` 安装启动成功，Dock 五项文本与坐标与改动前逐项一致，且截图字节数与改动前完全相同（70,061 B）——渲染未发生变化。
- **范围约束：** 纯搬移 + 机械改名，行为零变更；未改 `main_pages.json`。

## [2026-09-30] DevEco Code - Phase 1a：抽出 UI 视觉常量到 common/ui/UiTokens

- **新增文件：** `harmonyos/ets-source/common/ui/UiTokens.ets`（`UI_RADIUS_CONTROL` 14 / `UI_RADIUS_PANEL` 22 / `UI_RADIUS_SHEET` 28 / `UI_RADIUS_PILL` 999 / `UI_OPTION_ANIMATION_MS` 180）。
- **修改文件：** `harmonyos/ets-source/pages/MainWindowNativeNode.ets` —— 删除 5 个文件作用域常量，改为 `import ... from '../common/ui/UiTokens'`；文件内 856 处引用（663/22/7/94/70）写法不变。
- **依据：** `ARKTS-PAGES-REFACTOR-PLAN.md` Phase 1（先用最低风险的纯叶子走通「新增子目录 → sync → 构建 → 装机 → 契约校验 → 提交」管线，同时验证新增 `common/ui/` 子目录能被 `sync-ohos-build-sources.sh` 的整树递归镜像自动带到生成工程）。
- **验证结果：** `arkts_check` 两文件无错误；`BUILD SUCCESSFUL in 58 s 56 ms`；`node scripts/check-ohos-ui-contract.mjs` → `UI contract intact: 33 panels, 22 static ids, 17 dynamic prefixes, 41 id anchors.`；模拟器 `127.0.0.1:5555` 安装并启动成功，`devecocli ui layout` 的节点与坐标与改动前逐项一致（底部 Dock 五项 + 右上两按钮）。
- **范围约束：** 纯搬移，行为零变更；未改 `main_pages.json`、未改 sync 脚本。

## [2026-09-30] DevEco Code - Phase 0：固化 UI 契约基线（pages/ 重构）

- **新增文件：** `scripts/check-ohos-ui-contract.mjs`、`docs/harmonyos/json/ui-contract-baseline.json`。
- **目的：** 落实 `ARKTS-PAGES-REFACTOR-PLAN.md` 的硬性不变式之一——`.id()` 节点 id 与 33 个面板名不得被改动（uitest / dumpLayout / CLI 依赖）。基线把契约固化为可比对数据，`--update` 只在**有意**增删锚点时使用。
- **基线内容：** 33 个面板名（`activePanel` 比较 + `setPanel` 调用 + `panelId` 三处来源合并）、22 个静态 `.id()` 锚点、17 个动态 id 前缀（如 `panel-content-` + `i18nLang`）、`.id(` 出现总数 41；脚本默认模式会分别报告「被删除/改名」与「新增」的项并以非零码退出。
- **验证结果：** `node scripts/check-ohos-ui-contract.mjs --update` 生成基线后立即复跑校验，输出 `UI contract intact: 33 panels, 22 static ids, 17 dynamic prefixes, 41 id anchors.`。
- **范围约束：** 仅新增脚本与基线数据，未改动任何应用源码。

## [2026-09-30] DevEco Code - 新增 x86_64 模拟器「仅界面」调试通道（debug-only）

- **修改文件：** `harmonyos/ets-source/qability/QAbility.ets`、`harmonyos/ets-source/pages/ApplicationRoot.ets`（镜像；经 `scripts/sync-ohos-build-sources.sh` 同步到生成工程，生成目录不入库）、`docs/harmonyos/CHANGELOG.md`。
- **背景（用户要求）：** 现有 Mate 80 Pro 真机之外，需要一条在 Windows 上跑 Pura 手机模拟器、只验证 ArkUI 界面（布局/文案/交互）而不依赖 Stellarium/Qt 引擎的通道。实测该模拟器此前无法启动（内存/摄像头），且应用即使能启动也被两道门控挡住。
- **修改内容（QAbility.ets）：** ① 新增文件作用域判定 `engineLessEmulatorUiOnly()`：`BuildProfile.DEBUG && deviceInfo.productModel === 'emulator' && deviceInfo.abiList.includes('x86_64')`；② 新增私有方法 `releaseUiOnlyStartupGates()`，按序放开四个启动门控键（`stellariumPrivacyNativeStartupAllowed` → `stellariumQtContentReady` → `stellariumStartupSkyReady` → `stellariumStartupArtComplete`）；③ 在 `preparePrivacyHostPage()` 中 `loadContent('pages/ApplicationRoot')` 与 `rootContentLoaded = true` 之后调用它；④ 新增导入 `@ohos.deviceInfo`、`BuildProfile`。
- **修改内容（ApplicationRoot.ets）：** `aboutToAppear()` 末尾补 `this.onSkyReady()` —— 启动门控若在页面挂载前就已放开，`@Watch` 不会触发，加载层会永久盖住界面；该调用在门控仍为 false 时立即返回，冷启动路径行为不变。
- **安全边界：** 条件在真机与 release 包上恒为假（`productModel` 仅模拟器为 `emulator`，`DEBUG` 仅 debug 包为 true，引擎库只随 `entry/libs/arm64-v8a` 发布），因此发布链路不受影响；模拟器星图区域全黑属预期（`libstellarium.so`/`libQt6*.so` 无 x86_64 构建，native 桥回退为 `bridge not available`）。
- **模拟器本机配置调整（仅本机，不涉及仓库）：** Pura 90 Pro 实例 `hw.ramSize` 4096→3072（`config.ini` + `hardware-qemu.ini`），镜像 `features.ini` 的 `camera.feature` / `camera.front.back.enable` 改为 `off`；三处均已备份为 `*.deveco-bak`。原因：崩溃包 `detail.txt` 显示崩溃时宿主仅剩 4,713 MB 空闲而 guest 需 4 GB；09-28 那次模拟器自检直接报 `"Commit charge is not enough!"`；且崩溃前 0.6 s 刚打开宿主摄像头。
- **构建结果：** 两次 `BUILD SUCCESSFUL`（31 s 831 ms / 32 s 56 ms，`scripts/build-ohos-hap-windows.ps1 -SkipEngine -SkipDeploy -SkipResources`，默认 debug 模式），签名 HAP 681.2 MB；`arkts_check` 对两个改动文件均无错误。
- **验证结果：** Pura 90 Pro 模拟器（`127.0.0.1:5555`，`abilist=x86_64`，API 26，`productModel=emulator`）`install bundle successfully` / `start ability successfully`；界面外壳完整渲染（底部 Dock 搜索/时间/位置/图层/更多功能 + 右上陀螺仪与音频按钮）；点击「时间」成功打开时间面板（标题「时间 --」、副标题 `1x`、日期转轮 `2026 / 08月 / 11日 / 20: / 00: / 00`、速度 chips 倒带/停止/实时/减速/快进），`.id()` 锚点 `panel-close`、`panel-scroll-zh_CN`、`panel-content-zh_CN` 均在。
- **备注：** 按 §2.6 未提交，待用户明确要求。`docs/harmonyos/testing/PLATFORM-MATRIX.md` 中「Windows 模拟器无法运行本应用」的结论需补充本条 debug-only 例外（待确认后更新）。

## [2026-09-30] DevEco Code - 新增 pages/ 代码库重构方案（预研文档，未改代码）

- **新增文件：** `docs/harmonyos/research/ARKTS-PAGES-REFACTOR-PLAN.md`；同步更新 `docs/harmonyos/AGENTS.md` §2.2 结构树中 `research/` 的条目。
- **背景：** 用户指出 `pages/MainWindowNativeNode.ets`（32,774 行）把整个界面塞进单一 struct 属"代码工程大忌"，要求先给出重构方案；本轮只做取证与规划，不动源码。
- **文档内容：** ① 现状取证（体量、单体内部结构、前 15 大 Builder 体积表、1,047 个状态字段的领域聚类、跨文件存储分布、同步链路与测试契约）；② 根因分析；③ 目标架构（`window/` 壳层与 overlay、`panels/` 33 面板、`state/` @Observed 领域 store、`bridge/` 命令桥、`common/ui/` 原子件）；④ V1 `@Observed` + `@ObjectLink` 状态策略与 7 条规则；⑤ 8 阶段绞杀者迁移计划与统一验收矩阵；⑥ 9 条硬性不变式；⑦ 风险登记表；⑧ 备选方案否决理由；⑨ 可复现命令附录。
- **关键实测数据：** 主文件 32,774 行占业务 ArkTS（40,548 行，不含 `location_*` 数据表）的 80.8%；`@Component` 仅 1 个、`@State` 1,047（原始类型 948 / 数组 37 / 自定义类 13）、`@Builder` 145、私有方法 ≈1,109、`callInteractive` 调用点 203、定时器字段 38、`setInterval` 20、`ForEach` 169、`.id()` 锚点 41、`activePanel` 取值 33；`panelContent()` 单个 builder 5,138 行；`@Link`/`@Prop`/`@Provide`/`@Observed`/`@ObjectLink`/`$$`/`@BuilderParam`/`LazyForEach` 全为 0。
- **两条决定性结论：** ① 根因是 V1 `@Builder` 参数按值捕获导致状态下沉不了、1,047 个 `@State` 只能集中在唯一 struct，故**纯文件切分无收益**，必须引入组件边界 + 状态所有权；② 状态字段上的就地属性赋值（`this.X.y =`）实测 **0 处**、3,259 处赋值中 1,028 个字段为整体替换，即 V1→V2 在本仓库近于机械改名（估 2–3 周），但**一个 struct 不能半 V1 半 V2**，只能原子翻代，故否决"现在迁 V2"，正确顺序是先拆分再按模块翻代。
- **另记录：** `LocalStorage` 在本工程是 Qt 互操作桥面（`windowStage.loadContent(path, storage)`、`LocalStorageTsModule.makeNewLocalStorage` 经 `QtUtils.getModulesFactoriesMapForQt()` 暴露给 C++），**不可迁移**，已写入不变式。
- **范围约束：** 仅新增文档与结构树条目，未改动任何应用源码、未修改 `build-profile.json5`/签名材料/隐私门控/联网配置；未提交（按 §2.6 待用户明确要求）。

## [2026-09-30] DevEco Code - 时间面板重排、时间/速率入标题栏、主界面 Dock 常驻时钟；新增两条协作规则

- **修改文件：** `harmonyos/ets-source/pages/MainWindowNativeNode.ets`（镜像；经 `scripts/sync-ohos-build-sources.sh` 同步到生成工程，生成目录不入库）、`docs/harmonyos/AGENTS.md`、`docs/harmonyos/CHANGELOG.md`。
- **修改内容（时间面板）：** ① 上轮已完成：`timeScrubberSlider()`（时间转轴）移至 `activePanel === 'time'` 分支最前，手机端打开面板即可直接拖动（上轮改动未单独记录，并入本条）；② 本轮：`timeSpeedChips()`（倒带/现在/停止/实时/快进/超快）与日出日落跳转 `quickChips`（-12h/+12h/日出/中天/日落/天文昏）两行上移到时间转轴正下方，保持「转轴 → 速度 → 太阳跳转」顺序；③ 删除正文中「观测时间」「时间速率」两行，改由 `panelSubtitle()` 在 `activePanel === 'time'` 时返回 `观测时间 · 速率`，渲染进面板标题栏副标题（`panelHeader()` 早已支持非空副标题）；④ 面板头高度由固定 44 改为 `panelSubtitle().length > 0 ? 52 : 44`（Column 与外层 Row 两处同步），副标题加 `maxLines(1)` + 省略号防窄屏溢出；⑤ `julianDateControls()`、恒星时行、均时差块位置不变。
- **修改内容（Dock 时钟）：** 新增 `@State dockClockText` 与独立 `dockClockTimer`（1s），配 `stopDockClockTimer()`/`syncDockClockTimer()`/`refreshDockClock()`，完全照抄 `viewCoordinateTimer` 生命周期范本接线（初始化、前台恢复各启一次；`aboutToDisappear` 与后台分支各停一次）；新增 `dockClockChip()`（HH:mm 胶囊）与 `dockClockLayer()`（复用 `dockLeft()/dockWidthPixels()/dockTop()`，右端与 dock 栏对齐，空白区 `HitTestMode.Transparent` 穿透回星图、仅时钟本体 `Block`），挂载到 `expandedShell`（`expandedUiAllowed()` 内）与 `compactShell`；显示条件 `!panelVisible && !polarScopeVisible && dockClockText.length > 0`，点按时钟 `setPanel('time')` 直接打开时间面板；`hoverObservatoryShell` 不挂（顶部已有时间条）。
- **修改内容（AGENTS.md）：** 新增 §2.6 提交策略（Agent 不得自动 `git commit`/`git push`，仅用户明确要求「整理代码并提交」时才提交）；新增 §7 第 9 条（仅改 ArkTS 界面布局/文案的调试装机，构建+安装+启动成功即算验证通过，无需再拉渲染链日志或截图；涉及 C++/引擎、桥接、渲染管线、权限、资源仍需完整启动链验证）。
- **修改内容（用户复核后的二次微调）：** ① 删除 `timeScrubberSlider()` 内「时间转轴」小标题行（连同其 Row 容器）；② 面板标题行改为 `时间 + 时分秒`（`panelTitle()` 的 time 分支拼接 `timePanelClockText()`），副标题改为单独显示年月日（`timePanelDateText()`，附当前速率 ` · 1x`），新增两个私有拆分方法（按 `observationTimeText` 第一个空格切分，避免依赖 locale 格式）；③ 副标题字号 11 → 14，面板头高度 52 → 56；④ 主界面 Dock 时钟字号 12 → 22（大于面板主标题 18），胶囊高度 26 → 36、内边距 10 → 14，定位层高度 30 → 44、上移量 34 → 48 以保持与 dock 栏的间距。
- **修改原因：** 用户要求——手机端时间面板首屏应直接可用（转轴+控制按钮前置），时间/速率不必占用正文空间；主界面在未打开时间面板时需常驻 hh:mm 显示（建议置于 Dock 右上）；并把「界面布局类调试免渲染确认」「不自动提交」固化为项目规则；随后复核要求：去掉转轴小标题、时分秒与主标题同行、副标题单独显示年月日且字号加大、Dock 时钟字号需大于面板主标题。
- **设计要点：** 时钟用独立 1s 定时器 + 独立 @State，不并入时间面板 125ms 高频刷新链（`refreshSimTimeLight()` 注释明确警告高频路径勿改其他 @State，否则全局重排、拖星图卡顿）；时钟文本固定由 `jdToLocalTimeText(jd + utcOffsetHours/24)` 截取 `substring(11,16)` 得到（定长格式，不解析 locale 不定的 `formattedTime`）。
- **构建结果：** BUILD SUCCESSFUL in 58 s 816 ms（`scripts/build-ohos-hap-windows.ps1 -SkipEngine -SkipDeploy -SkipResources`），签名 HAP 681.2 MB；二次微调后再次 BUILD SUCCESSFUL in 58 s 465 ms；`arkts_check` 对镜像文件无错误。
- **验证结果：** 真机 `192.168.1.4:40565`（包名 `com.cnchensh.stellarium`，Ability `QAbility`）两轮均安装并启动成功：`install bundle successfully` / `start ability successfully`。按新增 §7.9 规则，本轮为纯 ArkTS 布局改动，未再拉渲染链日志或截图确认。
- **备注：** 本仓库工作区仍有未提交改动（上轮转轴前移 + 本轮全部改动），按 §2.6 由用户明确要求后再提交。

## [2026-09-29] DevEco Code - 重构工程总览 HTML（浅色·图形化·新增 Qt/C++ 工程师知识地图）

- **修改文件：** `docs/harmonyos/specs/CODEBASE-OVERVIEW.html` 整页重写（v2：31 KB/397 行 → 45 KB/614 行）。
- **重写动机（用户反馈）：** ① 换浅色底色；② 减少文字化叙述、增加图形化；③ 第一章排版混乱需修正；④ 读者为 C++/Qt/嵌入式工程师，需要总览全局、打通 ArkTS/移动端框架知识体系的内容。
- **版式改造：** ① 全站浅色主题（`--bg:#f5f7fa` 白卡片 + 蓝/青/紫/琥珀四色系）；② §1 重做为「工程形态流程图 + 8 张统一规格统计卡」（大数字 + 标签 + 副注，替代原先混排的卡片）；③ 目录强化：12 项目录锚点 + 「建议阅读路径」chips + 每章标题右侧「↑ 目录」回链；④ §5 启动时序从表格改为三色相位的竖向时间线（系统与权限 / 引擎与首帧 / 上线完成）；⑤ §6 新增「一次调用的旅程」步骤流与 RTLD_NOLOAD 成败分支图；⑥ §8 新增资源 bootstrap 流程图；⑦ §9 产物链从 ASCII 图改为 CSS 流程节点；⑧ QML↔ArkTS、桌面 Qt↔本工程的对照均为双栏图。
- **新增 §2「Qt/C++ 工程师知识地图」：** 一句话心智模型（Qt 应用原样变 `.so`，移植的本质是造系统级宿主外壳 + 命令翻译层）；15 行概念映射表（main→AbilityStage、QApplication+exec→UIAbility、QML→ArkTS/ArkUI、QML 绑定→@State、JNI→NAPI、QQuickWidget→XComponent、qeglfs→libqohos、deployqt→harmonydeployqt、qrc→rawfile+沙箱解包、交叉工具链→ohos.toolchain.cmake、vcpkg→ohpm、qputenv→setEnv、.qm 原样复用、dlopen→RTLD_NOLOAD、多窗口→zIndex 叠放）；桌面 Qt 应用 vs 本工程的 5 层对照图；ArkTS 60 秒速览（QML 与 ArkTS 代码并排）；移动端三件套卡片（生命周期托管 / 沙箱权限 / 签名分发）。
- **事实修正：** 原文「ApplicationRoot 为唯一 @Entry」不准确——`main_pages.json` 实际注册 4 个 @Entry 页（ApplicationRoot 主窗口 + FloatWindow/SubWindow/UiExtension 三个独立窗口），已改为「主窗口只加载 ApplicationRoot，其余 3 个属独立窗口」并落入统计卡；确认壳层为 V1 状态体系（`@Component`/`@State`，主文件近千处装饰器）。
- **验证结果：** 乱码/损坏实体 0、Markdown `**` 误用 0、23 类标签全部配平、13 个锚点与 13 个 id 一一对应（12 章 + #toc）、无外部资源引用（离线自包含）、目录 12 项 = 章节 12 个、CSS 花括号 97/97、`git diff --check` 通过。
- **范围约束：** 仅改文档，未触碰应用源码、`build-profile.json5`、签名材料、隐私门控或联网配置。

## [2026-09-28] DevEco Code - 新增 HAP 工程代码库与代码框架总览（HTML）

- **新增文件：** `docs/harmonyos/specs/CODEBASE-OVERVIEW.html`（397 行 / 31 KB，纯内联样式、无外部资源，可离线打开）；同步更新 `docs/harmonyos/AGENTS.md` 结构树中 `specs/` 的条目。
- **文档内容：** ① 一页速览（8 组实测数字）；② 三层运行时架构图（ArkTS/ArkUI ↔ NAPI 命令桥 ↔ Qt/Stellarium 引擎）与两条 XComponent 通道（SURFACE 探针 / NODE 原生节点）的声明与作用；③ `harmonyos/` 镜像与 `build/libstellarium-harmonyos/` 生成工程的目录职责逐项说明；④ 九步启动时序（AbilityStage → 单次 loadContent → 沉浸式与安全区 → 隐私门控 → 资源 bootstrap → Qt 上下文 → 首帧 → 命令桥上线 → 启动层淡出）；⑤ 命令桥契约：三个导出（`add`/`setEnv`/`command`）、`napi_module` 注册方式、**必须用 `RTLD_NOLOAD` 只查已加载库**的原因与后果、静默命令、回包格式，以及 **358 条命令目录**（`get*` 154 / `set*` 100）；⑥ 界面与窗口层级摘要（指向 `UI-ARCHITECTURE.md`）；⑦ 资源与离线数据（rawfile 3,634 文件 / 549 MB 的六个子目录、`data/ohos/` 六个契约文件、Qt `.qm` 与 ArkTS string.json 两条翻译路径）；⑧ 构建系统三条独立链、引擎交叉编译的三个必需参数、四个同步/校验脚本与产物链图；⑨ 测试与语义 CLI（150 个脚本、52 个 `test-ohos-*`）；⑩ 十条关键约束与常见坑速查；⑪ 术语表与文档索引。
- **数据来源：** 全部数字与行为均实测——`MainWindowNativeNode.ets` 32,693 行、`hello.cpp` 788 行、HAP 内 native 库 45 个、`libstellarium.so` 41.0 MB、`StelOhosCommandCatalog.hpp` 命令数与分类、各 ABI 的 `libentry.so` 等。
- **验证结果：** 无外部资源引用（离线自包含）、11 个目录锚点与 `id` 全部对应、标签配平检查通过（div/table/tr/td/pre/ul/li 等 17 类标签开闭数量一致）、`git diff --check` 通过；未改动任何应用源码。
- **范围约束：** 仅新增文档与结构树条目，未修改 `build-profile.json5`、签名材料、隐私门控或联网配置。

## [2026-09-28] DevEco Code - 补写界面与窗口层级总览（以代码为准）

- **新增文件：** `docs/harmonyos/specs/UI-ARCHITECTURE.md`；同步更新 `docs/harmonyos/AGENTS.md` 结构树中 `specs/` 的条目。
- **背景：** 文档库中没有任何一份描述「Ability → WindowStage → ApplicationRoot → 四种 NativeNode → 壳层」完整链路的文档，界面设计分散在 `HANDOFF.md`、`archive/MOBILE-UI-HANDOVER.md`、`policy/PRIVACY-REVIEW-2026-09-08.md` 与代码四处，且 `MOBILE-UI-HANDOVER.md` 处于回退态。本次从当前 ArkTS 源码逐条核验后补齐。
- **文档内容（全部标注代码出处与行号）：** ① 窗口层：`QAbility.preparePrivacyHostPage()` → `loadContent('pages/ApplicationRoot')` → `enterImmersive()`，以及 `QtWindowStageAdapter` 不再二次 `loadContent` 的单窗口约束；② `ApplicationRoot` 的三个互斥子层（主界面 / 启动汇字覆盖层 / 隐私宿主）及各自的 AppStorage 门控键；③ `MainWindowNativeNode.build()` 根 Stack 的完整叠放表（zIndex -1 隐藏语言锚点、-1 Qt NODE、0 探针与触摸反馈、条件壳层与四类 Overlay、92 状态条、98/99 夜间模式膜）与实测 zIndex 取值分布；④ 响应式断点：`compactWindow` 短边 < 520、`tabletCanvas` 短边 ≥ 700、`desktopCanvas` 900×520、半折角 158/140/68/55，以及 220ms 切换与 `springMotion(0.55, 0.88)` 转场；⑤ Dock（`dockButton(ShellAction)`）与 `setPanel` 的 6 个面板 id、跨设备唯一入口约定；⑥ `HitTestMode` 实测分布（Block 36 / None 23 / Default 23 / Transparent 10 / BLOCK_HIERARCHY 7）与命中规则及历史教训；⑦ 视觉常量 `UI_RADIUS_CONTROL/PANEL/SHEET/PILL` 与 `UI_OPTION_ANIMATION_MS=180`，并标注"项目选择而非官方强制值"；⑧ 沉浸式与顶部安全区（`stellariumScreenSafeTopPixels`）链路；⑨ 与既有文档的差异表（明确 `MOBILE-UI-HANDOVER.md` 为回退态、`DESIGN-VISION.html` 参数与落地实现不同、`HANDOFF.md` 的 API 版本描述滞后）；⑩ 可复现的核对命令。
- **验证结果：** 文中每条结论均附 `文件:行号` 或 `Select-String` 命令；`git diff --check` 通过；未改动任何应用源码。
- **范围约束：** 仅新增文档与结构树条目，未修改 `build-profile.json5`、签名材料、隐私门控或联网配置。

## [2026-09-27] DevEco Code - 记录平台与验证环境矩阵（模拟器/真机/云调试）

- **新增文件：** `docs/harmonyos/testing/PLATFORM-MATRIX.md`；同步更新 `docs/harmonyos/AGENTS.md` 的文档结构树。
- **查证结论：** Windows 本机的 HarmonyOS 模拟器**无法运行本应用**。官方《使用环境》限定模拟器宿主只有 Windows(x86_64) 与 macOS(Apple Silicon)（原文含"不支持采用 ARM CPU 的 Windows 计算机""支持 Apple Silicon 芯片，不支持 intel 芯片"）；本机 4 个模拟器 profile 实测全为 `abi: x86` / `hw.cpu.arch=x86_64`，且 `tools/emulator/pc-bios/` 只含 x86 固件、无 aarch64 固件。官方要求 x86 模拟器必须提供"已 x86 化"的 so，没有任何 arm→x86 转译能力。
- **组件层面：** `libentry.so` 可编 x86_64（OHOS NDK 自带 x86_64 sysroot），但 `libstellarium.so` 与 15 个 `libQt6*.so` 不能——Qt for HarmonyOS 只发布 `harmonyos_arm64_v8a`（已核对 `E:\Qt\components.xml` 组件元数据与 `libQt6Core.so` 的 ELF 头）。因此仅"为 OHOS x86_64 从源码编译整个 Qt"这一条理论路径，成本以周计，不建议。
- **可用组合：** 真机（已实测 Mate 80 Pro 渲染星图）、Apple Silicon Mac 上的官方 arm64 模拟器、AGC 云调试/云测试。另记录低成本"半验证"：`abiFilters` 加 `x86_64` 可在 x86 模拟器看到 ArkUI 外壳，但 Qt 星图必然加载失败。
- **云调试：** 整理 5 项硬约束（HAP 格式、机型系统版本须匹配、形态匹配、证书类型、实名+额度）与能力边界（官方记录云调试下折叠状态监听失效，传感器类验证必须留真机）。额度方面确认本地文档库无计费页（已穷举检索 8 组关键词），仅两条有依据的事实：额度形态为"免费体验时长"，且**上传时间计入同一份额度**（官方建议"在 云调试-我的信息-应用 中提前上传"）；查询入口、4 项待确认项与 3 分钟自测办法一并记录。
- **树莓派 4B：** 评估为不可行——模拟器无 Linux/ARM 宿主；树莓派只能刷 OpenHarmony（社区 22 款开发板之一），而本项目是 `runtimeOS: HarmonyOS` 且依赖 HarmonyOS SDK 26.0.0，两者运行环境不通用（官方 FAQ 记录"改为 OpenHarmony 后加载 so 闪退"）；且 OHOS SDK 原生工具链只有 x86_64 二进制，无法当构建机。
- **验证结果：** 文档内每条结论均附官方文档 ID 与本地复现命令（`lists.json` / `pc-bios` / `components.xml` / `devecocli docs search`）；本文件不改动任何应用代码、签名或系统配置。
- **范围约束：** 仅新增文档与结构树条目，未修改 `build-profile.json5`、签名材料、隐私门控或联网配置。

## [2026-09-27] DevEco Code - 文档分层归集、清理冗余 JSON 并修复脚本编码

- **修改文件：** `docs/harmonyos/`（61 个文档 + 34 个 JSON 重新分层）、`docs/harmonyos/AGENTS.md`、`docs/harmonyos/DEBUGGING-GUIDE.md`、`docs/harmonyos/NETWORK-INVENTORY.md`、`docs/harmonyos/KNOWN-ISSUES.md`、`scripts/review-skyculture-passages.py`、`scripts/audit-ohos-resource-coverage.mjs`、`scripts/generate-deep-sky-inventory.mjs`。
- **重组原则（目标是降低新人接入负担）：** 根目录只保留 9 个「必读/常查」文档 —— `AGENTS`、`HANDOFF`、`KNOWN-ISSUES`、`CHANGELOG`、`DEVELOPMENT-MCP-WORKFLOW`、`BUILD-WINDOWS`、`DEBUGGING-GUIDE`、`CLI`、`NETWORK-INVENTORY`；其余按用途分层：`release/`（构建·发布·签名·上架）、`policy/`（合规与政策）、`specs/`（现行实现规格 16 篇）、`research/`（预研与路线图 10 篇）、`json/`（全部保留的数据文件，含 `json/culture-review-batches/`）、`archive/`（`audits/` 20 篇历史审计与复核报告、`design/` 4 篇早期设计稿、`MOBILE-UI-HANDOVER.md`）；`skills/`、`workbuddy/` 保持原位。
- **已移除：** `screenshots/`（48 张桌面版 + 16 张 Sky Guide 参考截图，216 MB）、`harmonyos-project/`（7 月的 ArkTS 源码旧副本）、`codex/`、`trae/`、`releases/`、`workbuddy/{device-tests,outputs}`（7 月测试产物 115 个文件）及 3 篇被现役 `HANDOFF.md` 取代的旧交接文档；`docs/harmonyos` 由 435 个文件 / 242.8 MB 降为 238 个文件 / 16.0 MB。
- **依赖保护：** `json/` 下 4 类数据（`skyculture-corpus/passage/section-revisions` 等 3 个 JSON + `json/culture-review-batches/*.json` 整目录）仍被 `scripts/review-skyculture-passages.py` 读取，脚本路径已同步更新；`specs/DEEP-SKY-RESOURCE-INVENTORY.md` 与 `archive/audits/RESOURCE-COVERAGE-AUDIT-2026-08-24.md` 是脚本的生成产物，输出路径同样更新。
- **顺带修复：** `review-skyculture-passages.py` 原先用 `Path.read_text()` 的默认编码读取 UTF-8 数据，在中文 Windows（GBK 区域）下必报 `UnicodeDecodeError`；6 处读写已显式指定 `encoding='utf-8'`。
- **验证结果：** 重组后 `scripts/review-skyculture-passages.py --check` EXIT=0（18 条规则、63 个 section、7 个批次文件、85 个目录全部加载，`changedFiles: 0`）；`git diff --check` 通过。
- **范围约束：** 未改动任何应用源码、签名材料、隐私门控或联网配置；`CHANGELOG.md` 既有历史条目保持原样（其中的旧路径按追加式历史保留）。
- **备注：** `CHANGELOG` 历史条目提到的 `STARGAZING-HUB-RESEARCH-2026-09-08.md` 在仓库中从未存在，属既有悬空引用，本轮未处理。

## [2026-09-27] DevEco Code - Windows 平台打通 API 26 编译链并真机验证星图

- **修改文件：** `harmonyos/oh-package.json5`、`harmonyos/build-profile.json5`、`harmonyos/hvigor/hvigor-config.json5`、`harmonyos/resources/base/profile/easy_go.json`、`harmonyos/ets-source/qability/QtWindowStageAdapter.ets`、`scripts/sync-ohos-build-sources.sh`、`scripts/check-ohos.sh`、`scripts/build-ohos-hap-windows.ps1`、`scripts/sync-ohos-resources-windows.ps1`、`docs/harmonyos/BUILD-WINDOWS.md`、`.gitignore`。
- **工具链对齐：** 本机只有 DevEco Studio 26.0.0.821 与 HarmonyOS 26.0.0（API 26）SDK，原工程 `compileSdkVersion: 6.1.1(24)` 无法解析。按 IDE 迁移结果把 `modelVersion`、`compileSdkVersion`、`targetSdkVersion` 统一为 `26.0.0`，`hvigor/hvigor-config.json5` 与 `oh-package.json5` 成对修正。`build-profile.json5` 仅改这两行，并移除其中他人本机的证书路径引用与悬空的 `signingConfig`：签名一律由 DevEco Studio 自动签名在 `~/.ohos/config` 生成，本仓库不保存任何证书路径或口令。
- **API 26 适配：** `easy_go.json` 的 `multiModalInputOptions.mouse2TouchEventMode` 在 API 26 schema 中已移除（实测触发 `00303038 Schema validate failed`）；`QtWindowStageAdapter` 补齐 API 26 新增的 `setImageForRecent` / `removeImageForRecent`，否则 ArkTS 编译报 `incorrectly implements interface 'WindowStage'`。
- **构建脚本修复：** `sync-ohos-build-sources.sh` 由显式文件清单改为整目录镜像——旧清单漏了 34 个媒体图标与 34 个 ets/ts 模块，导致 `Unknown resource name 'ic_globe'` 与 `Cannot find module '../process/QChildProcess'`；并停止覆盖 `AppScope/app.json5`，否则本地包名被还原、自动签名随即失配。`check-ohos.sh` 的 JPEG 检查改为按实际 `DT_NEEDED` 判定：Qt 6.12.0 的 `libqjpeg.so` 静态链接了 libjpeg，旧逻辑在官方 Qt 上必然误报缺少 `libjpeg.so`。
- **Windows 链路（新增）：** 原 `CODEX_BUILD_AND_INSTALL.md` 全为 macOS 路径、且依赖 `rsync`/`ffmpeg`。新增 `scripts/build-ohos-hap-windows.ps1`（引擎交叉编译 → 修 `DT_NEEDED` → `harmonydeployqt` → 灌资源 → 同步源码 → `hvigorw assembleHap --no-daemon` → 可选装机）与 `scripts/sync-ohos-resources-windows.ps1`（`robocopy` 替 `rsync`、`System.Drawing` 替 `ffmpeg`），并附 `docs/harmonyos/BUILD-WINDOWS.md` 记录三个必需编译参数与全部实测报错。
- **验证结果：** 引擎以 Qt 6.12.0 `harmonyos_arm64_v8a` 交叉编译出 41.1 MB `libstellarium.so`（AArch64）；`rawfile/stellarium` 灌入 549 MB（63 个星空文化、84 个 `.ssc`）；签名 HAP 679.8 MB 安装到 HUAWEI Mate 80 Pro（SGT-AL00，HarmonyOS 7.0.0 / API 26，`arm64-v8a`），`aa start` 成功且进程存活，hilog 出现 `StelRootItem paint reached`、`zero-copy frame bridge resolved`、`startOhosRenderPump entered`、`command on Qt thread: "setLanguage" "zh_CN"`、`ohosDrainCommandQueue`，截图为真实星场与银河，选中天体显示「河鼓二 Altair」、方位显示「南」。`build-ohos-hap-windows.ps1` 的构建路径与 `-Install` 路径均 EXIT=0，`git diff --check` 通过。
- **范围约束：** 未改动签名材料、隐私门控、联网与画质配置，仓库内未新增任何证书、密钥或口令；`build-profile.json5` 的改动仅限 SDK 版本与移除他人本机证书引用（本机仅存 API 26 SDK，属用户明确要求的编译修复）。本机调试包名 `com.cnchensh.stellarium` 只存在于被忽略的生成工程内，镜像仍保持上游 `com.joinother.skyinstrument`。未以 `check-ohos.sh` 作为通过依据（该脚本在 Windows 无法整脚本运行）。
- **未解决项：** 见 `KNOWN-ISSUES.md` 的「Windows 构建链遗留技术债（2026-09-27）」。

## [2026-09-01] Codex - 天空文化名称选择与资料布局修复

- **修改文件：** `harmonyos/ets-source/pages/MainWindowNativeNode.ets`、`build/libstellarium-harmonyos/entry/src/main/ets/pages/MainWindowNativeNode.ets`
- **交互修复：** 移除星图、资料、黄道和月宿名称选择器的固定展开高度，选项命令与收起动画分离；Builder 改为直接读取目标对应的 `@State`，解决选中后原生命令已生效但标题仍保留旧值的问题。
- **视觉整理：** 名称选择器标题、展开项以及类型/地区筛选项统一使用 `UI_RADIUS_CONTROL` 圆角和点击反馈；当前文化元数据改为间距稳定的两列布局，文化概述重排为标题、分段正文和独立展开操作区。
- **验证结果：** `scripts/sync-ohos-build-sources.sh`、`scripts/check-ohos.sh`、CompileArkTS/HAP 和 `git diff --check` 通过；最新 Debug HAP 已覆盖安装到平板 `192.168.1.30:33805`。在“中国”星空文化下真机点击验证“资料中的名称”和“月宿系统名称”均可从“中文译名”切换为“文化原名”，布局树即时更新，日志确认 `info|Native`、`lunar|Native`。设备保持亮度 `1`、息屏超时 `86400000 ms`。
- **范围约束：** 未修改签名、证书、Profile、`build-profile.json5`、隐私、联网、画质或分辨率配置。
