# privacy-v2 → pr-upstream-20261008 功能迁移计划（含代码逻辑提取）

> **状态：** P0–P13 已完成并入 `pr-upstream-20261008`（见 CHANGELOG 2026-10-11 条目）；P12 剩余（指针坐标防抖、`uiLayoutOverride`）与 P14 尾部（`ArPreviewBridgeResponse` 归位 types）留待后续
> **日期：** 2026-10-11
> **源分支：** `joinother/fix/api22-privacy-v2`（HEAD `aae34f085e`，基线后 2 提交）
> **目标分支：** `pr-upstream-20261008`（HEAD `89a16b6089`，基线后 ~140 提交）
> **共同祖先：** `9797d13f2b`

---

## §0 核心困难与策略

upstream 将 16k 行单体 `MainWindowNativeNode.ets` 拆为 ~270 文件（bridge/6 + capability/30 + state/48 + common/37 + panels/若干），隐私分支在该单体上新增 ~3200 行。

**策略：不 merge，按功能域手工迁移，每片闭环。**

---

## §1 P0：C++ 引擎命令

### 1.1 变更提取

**`src/StelMainView.cpp`**（+966/−124）新增以下桥命令处理器：

| 命令组 | 新命令 | 核心逻辑 |
|---|---|---|
| 通知 | `getNotificationStatus` / `requestNotificationAuthorization` / `publishAstronomyNotification` / `cancelAstronomyNotification` | 仅回显 ArkUI 已处理的结果（`{ok: true, handled: "ArkUI"}`），不调 C++ 通知 API |
| 提醒 | `getAstronomyReminderStatus` / `getAstronomyReminders` / `scheduleAstronomyReminder` / `scheduleNextSolarTermReminder` / `cancelAstronomyReminder` / `clearAstronomyReminders` | 同上，回显 |
| 协作 | `createCollaborationSession` / `exportCollaborationSession` / `previewCollaborationSession` / `importCollaborationSession` / `applyCollaborationSession` / `getCollaborationState` | 生成/验证 JSON 会话信封；`applyCollaborationSession` 是 restricted |
| 卡片 | `getFormSnapshot` / `refreshFormSnapshot` | 回显 `getTonightEvents` / `getAlmanac` 的结果 |
| ICP 备案 | `getAppFilingInfo` | 返回 `APP_ICP_FILING_NUMBER` + `APP_ICP_FILING_URL` |
| AR | `setARMode` / `setARRevealProgress` / `getARState` / `getARCapabilities` | 回显 + 管理模式状态 |
| 巡天 | `getSurveyState` / `setSpectralView` / `closeSpectralView` | 调 `HipsMgr` 方法 |
| 多波段 | `getSpectralDatasets` / `listSpectralDatasets` / `getSpectralState` | 调 `HipsMgr` 方法 |
| 键盘 | `getKeyboardShortcuts` / `setKeyboardShortcut` / `resetKeyboardShortcuts` | 调 `StelActionMgr` |
| 特定时间 | `getTimeNavigationTarget` | 调 `SpecificTimeMgr` |
| 指针位置 | `setPointerPosition` | 调 `StelMovementMgr::setPointerPosition` |
| 布局 | `getUiLayout` / `setUiLayoutMode` | 读取 AppStorage + 回显 |
| 地图 | `getLocationMapState` / `setLocationMapProvider` | 读取 AppStorage + 回显 |
| 缩放锚定 | `getViewAnchorState` / `setViewAnchorProbe` | 管理 `s_ohosAnchorProbe*` 变量 |
| 配置分享 | `shareConfigBackup` → 走 `exportConfig` | 已有命令，无新逻辑 |

**缩放锚定重构**（~150 行新 C++）：
- 旧：`ohosCaptureSelectedZoomAnchor()` 仅记录 object name + 屏幕比例
- 新：`ohosAnchorSkyDirection(directionJ2000, xRatio, yRatio)` 用逆投影重建屏幕朝向，支持 pinch 中保持锚定
- 新增字段：`s_ohosPinchEndPending` / `s_ohosPinchStartFov` / `s_ohosAnchorProbeEnabled` / `s_ohosAnchorProbeSamples` / `s_ohosAnchorProbeMaxErrorPixels` / `s_ohosAnchorProbeMaxSolveMs`

**`src/StelOhosCommandCatalog.hpp`**（+64/−12）：命令元数据并集 + restricted 标记扩展。

**新增文件**：
- `src/core/modules/SpecificTimeMgr.cpp`（+71）/ `SpecificTimeMgr.hpp`（+7）：节气/特定时间查询

**`src/core/modules/HipsMgr.cpp`**（+158）/ `HipsMgr.hpp`（+10）：巡天状态查询 + 多波段数据集管理。

**插件**（6 个 `*.cpp` 各 +6 行）：隐私声明回调注册。

### 1.2 迁移做法

1. 生成补丁：`git diff 9797d13f2b..aae34f085e -- src/ > /tmp/p0-cpp.patch`
2. 切到 `pr-upstream-20261008`，手工 apply
3. 冲突点：`StelMainView.cpp` 的 `selectAt` 附近（upstream 改了搜索半径 44→60）。取**两边并集**（星座回退守卫 + 60px + 新桥命令）
4. 其余文件无冲突
5. 验证：引擎编译 + `check-ohos-command-catalog` 基线更新

---

## §2 P1：隐私合规

### 2.1 变更提取

**`PrivacyConsent.ets`**（完全重写）：

旧逻辑：仅检查 `PRIVACY_STATEMENT_LINK` 一个链接类型
新逻辑：
- `allHostedAgreementsAccepted()`：遍历 **所有** `privacyInfo` 链接（含 `USER_AGREEMENT_LINK`），每个都需匹配
- 请求去重：`pendingConsentRequest` 防止并发弹出多个隐私对话框
- 错误码：返回 `errorCode`（`1006700003` = 无 AGC 配置，`-1` = 未知）
- `BusinessError` 导入

**`PrivacyBootstrap.ets`**（重写，从 ~30 行扩到 ~107 行）：

旧逻辑：简单查询 + 弹对话框
新逻辑：
- `CommonEvent` 订阅 `usual.event.PRIVACY_STATE_CHANGED`，实时监听系统隐私状态变化
- `finishVerifiedConsent()`：判 `hasCurrentPrivacyConsent()` → 设置 `AppStorage('stellariumPrivacyConsentVerifiedUi')` → 调 `notifyConsentAccepted()`
- 重复请求保护：`consentCompleted` 标志
- 帮助链接：`helpAvailable` + 延迟 5 秒显示的帮助按钮
- 错误码显示
- `disposed` 标志防止 aboutToDisappear 后继续操作

**`QAbility.ets` 隐私部分**（~80 行新增）：

- `pendingPrivacyWindowRestore: boolean` — 隐私同意后恢复窗口
- `restoreWindowAfterConsent()` — 调 `qpa.handleAbilityOnWindowStageRestore` + 设置 `AppStorage('stellariumPrivacyNativeStartupAllowed')`
- `rootContentLoading: Promise<boolean> | undefined` — 防止重复加载
- `desktopWindowRepairAttempts: number` — 桌面窗口修复计数
- `onWindowStageRestore` 中：先检查隐私同意 → 同意则恢复，否则设 `pendingPrivacyWindowRestore = true`
- `onCreate` / `onWindowStageCreate` 中：隐私检查门控

**`StartupSky.ets`**（~10 行改动）：

新增 `@StorageLink('stellariumPrivacyNativeStartupAllowed')` → 控制启动动画的 reveal 进度：
- `nativeStartupAllowed = false` 时：星体粒子不组装（`assemblyElapsed` 不推进）
- `nativeStartupAllowed = true` 但 `skyPrepared = false` 时：缓慢推进到 `STARTUP_REVEAL_AT_MS`
- 绘制：`reveal = skyPrepared ? startupReveal(assemblyElapsed) : 0`

**`QtWindowStageAdapter.ets`**（+9 行）：

- 新增 `setImageForRecent(imageResource, value)` / `removeImageForRecent()` — 任务管理器快照

### 2.2 迁移做法

1. **`PrivacyConsent.ets`**：直接用 privacy 版本替换 upstream 版本
2. **`PrivacyBootstrap.ets`**：直接用 privacy 版本替换（upstream 中此文件位于 `pages/`，路径不变）
3. **`QAbility.ets`**：在 upstream 版本（~65 行改动）上叠加 privacy 的隐私窗口恢复逻辑
4. **`StartupSky.ets`**：在 upstream 版本上叠加 `nativeStartupAllowed` + 绘制逻辑
5. **`QtWindowStageAdapter.ets`**：在 upstream 版本上追加两个方法

---

## §3 P2：通知与提醒

### 3.1 变更提取

**新增 Service 类**（直接加入，无冲突）：

`AstronomyNotificationService.ets`（80 行）：
- `isEnabled(): Promise<boolean>` — 调 `notificationManager.isNotificationEnabled()`
- `requestAuthorization(context): Promise<boolean>` — 调 `notificationManager.requestEnableNotification(context)`
- `publish(payload): Promise<boolean>` — 调 `notificationManager.publish(request)`，支持 BASIC_TEXT 和 MULTILINE
- `cancel(id): void` — 调 `notificationManager.cancel(id)`

`AstronomyReminderService.ets`（173 行）：
- `status(): Promise<AstronomyReminderListResult>` — 调 `reminderAgentManager.getValidReminders()`
- `schedule(request): Promise<AstronomyReminderResult>` — 调 `reminderAgentManager.publishReminder()`
- `cancelAll(): Promise<AstronomyReminderResult>` — 遍历取消
- 内部用 `Want` 参数传递 `panel` / `tab` / `eventId` / `kind`，点击提醒后跳转对应面板

**宿主状态字段**（在旧单体 `MainWindowNativeNode` 中）：

```
astronomyNotificationEnabled: boolean = false
astronomyNotificationBusy: boolean = false
astronomyReminderCount: number = 0
astronomyNotificationStatus: string = '尚未检查通知权限'
```

**宿主方法**（提取到 Controller）：

```
refreshAstronomyNotificationStatus() — 调 AstronomyReminderService.status()
requestAstronomyNotificationAccess() — 调 AstronomyNotificationService.requestAuthorization()
scheduleNextSolarTermReminderFromUi() — 从 almanacSolarTerms 找下一节气，调 AstronomyReminderService.schedule()
clearAstronomyRemindersFromUi() — 调 AstronomyReminderService.cancelAll()
```

**QAbility 命令路由**（提取到 Controller）：

```
getNotificationStatus → AstronomyNotificationService.isEnabled()
requestNotificationAuthorization → AstronomyNotificationService.requestAuthorization()
publishAstronomyNotification → AstronomyNotificationService.publish()
cancelAstronomyNotification → AstronomyNotificationService.cancel()
getAstronomyReminderStatus → AstronomyReminderService.status()
getAstronomyReminders → AstronomyReminderService.status()（含 items）
scheduleAstronomyReminder → AstronomyReminderService.schedule()
scheduleNextSolarTermReminder → 需 getAlmanac 结果 → AstronomyReminderService.schedule()
cancelAstronomyReminder → AstronomyReminderService.cancel(id)
clearAstronomyReminders → AstronomyReminderService.cancelAll()
```

### 3.2 迁移做法

1. 直接加入 `AstronomyNotificationService.ets` / `AstronomyReminderService.ets`
2. 新建 `state/NotificationStore.ets`（4 个字段）
3. 新建 `capability/NotificationController.ets`（4 个方法 + QAbility 命令路由 10 个 + `NotificationHostHooks` 接口含 `flashHint` / `loadAlmanac`）
4. 宿主 `aboutToAppear` 注入 Controller 实例
5. QAbility 中移除直接路由代码，改为 Controller 处理
6. 设置面板加"通知与卡片"行（I18n key 已在 P14 追加）

---

## §4 P3：天象卡片

### 4.1 变更提取

**新增文件**（全部直接加入）：

| 文件 | 行数 | 功能 |
|---|---|---|
| `form/AstronomyCardData.ts` | 126 | `CardTonightData` / `CardMoonData` / `CardSunData` / `CardPlanetData` / `CardShowerData` / `CardSatelliteData` + `cardClock()` |
| `form/AstronomyCardSurface.ets` | 378 | 卡片渲染公共组件：月相图 / 暗夜窗口 / 行星列表 / 流星雨条目 |
| `form/SkyInstrumentCompactCard.ets` | 29 | 2×2 紧凑卡片 |
| `form/SkyInstrumentMoonCard.ets` | 25 | 月相卡片 |
| `form/SkyInstrumentMeteorCard.ets` | 25 | 流星雨卡片 |
| `form/SkyInstrumentSatelliteCard.ets` | 25 | 卫星卡片 |
| `form/SkyInstrumentTonightCard.ets` | 25 | 今晚天象卡片 |
| `form/SkyInstrumentCard.ets` | +25 | 基类扩展 |
| `form/SkyInstrumentFormAbility.ets` | +58 | FormAbility 生命周期：`onCreate` / `onUpdateForm` / `onFormEvent` |
| `qability/AstronomyCardService.ets` | 50 | `readAstronomyCard(context)` / `publishAstronomyCard(context, data)` |

**宿主方法**：

```
persistAlmanacCardSnapshot() — 调 getTonightEvents → publishAstronomyCard
consumeCardRoute() — 解析 AppStorage('stellariumCardRoute') → openPanelFromCli + selectAstroTab
onCardRouteChanged() — Watch 回调
```

**QAbility 命令路由**：

```
getFormSnapshot → readAstronomyCard → 返回 JSON
refreshFormSnapshot → 调 getTonightEvents / getAlmanac → publishAstronomyCard
```

**配置**：
- `module.json5`：加 `extensionAbilities`（FormAbility，`type: "form"`，`metadata: ohos.extension.form`）
- `form_config.json`：6 个卡片定义（2×4 / 4×4 / 2×2 尺寸）

### 4.2 迁移做法

1. 直接加入 `form/` 下所有新文件 + `AstronomyCardService.ets`
2. 合并 `module.json5` 的 `extensionAbilities` 段 + `form_config.json`
3. `persistAlmanacCardSnapshot()` → 移入 `NotificationController`（或新建 `CardController`）
4. `consumeCardRoute()` → 移入宿主（Watch `stellariumCardRoute`）
5. QAbility 加 FormAbility 生命周期方法

---

## §5 P4：协作会话

### 5.1 变更提取

**`CollaborationSessionService.ets`**（192 行，直接加入）：

- `SESSION_KIND = 'stellarium.collaboration.session'`，`CURRENT_SCHEMA = 2`
- `createCollaborationSession(options)` → 生成 `CollaborationSessionEnvelope`（sessionId/createdAt/expiresAt/state）
- `previewCollaborationSession(json)` → 解析 + 返回 `CollaborationSessionPreview`
- `importCollaborationSession(json)` → 验证 + 解析
- `exportCollaborationSession(state)` → 序列化
- `collaborationNativeState(response)` → 提取 `state` 字段

**宿主方法**：

```
sessionShare() — 调 createCollaborationSession → shareFile
sessionHandoff() — 类似但设置 copy: true
```

**QAbility 命令路由**：

```
createCollaborationSession → createCollaborationSession(options) → 返回 envelope
exportCollaborationSession → exportCollaborationSession(state) → 若 copy 则写剪贴板
previewCollaborationSession → previewCollaborationSession(json)
importCollaborationSession → importCollaborationSession(json)
applyCollaborationSession → restricted；推 state 到引擎
getCollaborationState → 回显
```

**StellariumTypes 扩展**：

```
StellariumBridgeResponse { session?: Object; preview?: Object; accepted?: boolean; conflictAction?: string }
```

### 5.2 迁移做法

1. 直接加入 `CollaborationSessionService.ets`
2. 新建 `state/CollaborationStore.ets`（预览状态 / 进度）
3. 新建 `capability/CollaborationController.ets`（5 个方法 + QAbility 命令路由）
4. `CollaborationHostHooks` 含 `flashHint` / `applyState`
5. 设置面板加"协作与分享"行

---

## §6 P5：HiPS 巡天

### 6.1 变更提取

**宿主状态字段**：

```
surveyStateText: string = ''
spectralDatasets: Array<SpectralDataset> = []
spectralActiveId: string = ''
spectralStateText: string = ''
```

**宿主方法**：

```
loadSurveyState() — 调 getSurveyState → 更新 hipsSurveys / toastSurvey / surveyStateText
loadSpectralDatasets() — 调 getSpectralDatasets → 更新 spectralDatasets
setSpectralDataset(id) — 调 setSpectralView → 更新 spectralActiveId
closeSpectralView() — 调 closeSpectralView → 清空
```

**新增接口**（从旧单体提取）：

```
SurveyStateResponse { hipsEnabled/hipsLoaded/hipsLoading/hipsSurveyCount/hipsVisibleCount/toastEnabled }
SpectralDataset { id/title/band/source/coverage/license/attribution/licenseReviewRequired/networkPolicy/timeoutSeconds/surveyUrl/available/enabled/loading/ready/error }
SpectralState { enabled/datasetId/loading/ready/error }
```

**I18n key**（5 个）：`survey_usage` / `survey_selected` / `survey_no_selection` / `survey_refresh` / `survey_alignment_hint`

**面板列表扩展**：`isCliPanelName` 加 `'surveys'`（upstream 的 `LayerSurveysTab` 已有巡天 tab）

### 6.2 迁移做法

1. 新建 `state/SurveyStore.ets`（4 个字段 + SurveyStateResponse / SpectralDataset / SpectralState 类型）
2. 新建 `capability/SurveyController.ets`（4 个方法）
3. 类型追加到 `common/types/StellariumTypes.ets`
4. I18n key 追加到 `capability/I18n.ets`
5. 巡天面板 UI：upstream 已有 `LayerSurveysTab`，扩展其内容即可

---

## §7 P6：AR 预览

### 7.1 变更提取

**宿主状态字段**：

```
arPreviewMode: string = 'portal'  // 'off' | 'overlay' | 'portal' | 'depth' | 'sky-only'
arRevealProgress: number = 0.62
arPreviewStatus: string = ''
```

**宿主方法**：

```
loadArCapabilities() — 调 getARCapabilities → 返回可用模式
setArPreviewMode(mode) — 调 setARMode → 更新 arPreviewMode / arPreviewStatus
setArRevealProgress(value) — 调 setARRevealProgress → 更新 arRevealProgress
```

**新增接口**：

```
ArPreviewModeOption { id: string; label: string }
ArPreviewBridgeResponse extends StellariumBridgeResponse { previewShell?: boolean; previewOnly?: boolean }
```

**面板列表扩展**：`isCliPanelName` 加 `'ar'`，面板路由列表加 `{ label: 'AR 预研', icon: 'gyro', panel: 'ar' }`

**CLI 路由**：`setARMode` + `setARRevealProgress` 的响应处理

### 7.2 迁移做法

1. 新建 `state/ARStore.ets`（3 个字段 + ArPreviewModeOption / ArPreviewBridgeResponse）
2. 新建 `capability/ARController.ets`（3 个方法 + 相机权限请求）
3. `ARHostHooks` 含 `flashHint` / `requestCameraPermission`
4. 宿主加 AR 叠层组件（相机预览 + 星图叠加，参照 privacy 的 `build()` 中的 AR 叠层块）
5. `module.json5` 无需加相机权限（AR 预研模式暂不用真实相机，仅 `sky-only` 无相机模式）

---

## §8 P7：在线地图

### 8.1 变更提取

**`LocationOnlineMap.ets`**（183 行）：

- `MapComponent` from `@kit.MapKit`
- `@Prop latitude/longitude` + `onPick/.onFallback` 回调
- 隐私检查：`hasCurrentPrivacyConsent()` 门控
- 预备阶段：`map.MapComponentController` 初始化
- 超时降级：3 秒后切回离线

**`MapCoordinate.ts`**（24 行）：

- `MapPoint { latitude: number; longitude: number }`
- `validMapPoint(p)` / `inverseMapPoint(p)` — 坐标转换

**宿主状态/方法**：

```
locationMapProvider: string = 'offline'  // 'offline' | 'huawei'
setLocationMapProvider(provider) — 隐私检查 + AppStorage('stellariumLocationMapState') 写入
locationSearchRegionFilter(query) — 台湾/香港/澳门特殊地区过滤
```

**QAbility 命令路由**：`getLocationMapState` / `setLocationMapProvider`

### 8.2 迁移做法

1. 直接加入 `LocationOnlineMap.ets` / `MapCoordinate.ts`，修正 import 路径
2. `locationMapProvider` → 追加到 `LocationStore`
3. `setLocationMapProvider()` → 移入 `LocationController`
4. `locationSearchRegionFilter()` → 移入 `LocationController` 或 `common/derive/`
5. `LocationOnlineMap` 嵌入 `LocationPickerPanel`（upstream 已有此面板组件）
6. `module.json5` 加 `ohos.permission.INTERNET`

---

## §9 P8：键盘快捷键编辑器

### 9.1 变更提取

**宿主状态字段**：

```
keyboardShortcuts: KeyboardShortcutItem[] = []
keyboardShortcutQuery: string = ''
keyboardShortcutSelectedId: string = ''
keyboardShortcutPrimary: string = ''
keyboardShortcutAlternate: string = ''
keyboardShortcutsLoading: boolean = false
```

**新增接口**：

```
KeyboardShortcutItem { id/group/text/shortcut/alternateShortcut/defaultShortcut/defaultAlternateShortcut/checkable/global }
```

**宿主方法**：

```
loadKeyboardShortcuts() — 调 getKeyboardShortcuts → 更新列表
selectKeyboardShortcut(item) — 设置 selectedId / primary / alternate
saveKeyboardShortcut() — 调 setKeyboardShortcut → 检查 conflictAction
resetSelectedKeyboardShortcut() — 调 resetKeyboardShortcuts(id)
resetAllKeyboardShortcuts() — 调 resetKeyboardShortcuts('')
```

**I18n key**（12 个）：`settings_shortcuts_title` / `settings_shortcuts_hint` / `settings_shortcuts_search` / `settings_shortcuts_primary` / `settings_shortcuts_alternate` / `settings_shortcuts_save` / `settings_shortcuts_restore` / `settings_shortcuts_restore_all` / `settings_shortcuts_saved` / `settings_shortcuts_restored` / `settings_shortcuts_restored_all` + `settings_view_input_guide_title` / `settings_view_input_guide_touchpad` / `settings_view_input_guide_mouse` / `settings_view_input_guide_keyboard`

**宿主手势**（键盘事件处理）：

```
keyboardModifierPrefix(event) — 提取 Ctrl/Alt/Shift 前缀
keyboardToken(event) — 映射键码到标准名（Space/Enter/Tab/Esc/F1-F12/方向键/字母数字）
fallbackKeyboardToken(token) — 兼容旧格式
handleSkyKey(event) — 主键盘事件分发（方向键平移、+/-缩放、Space居中、F搜索、N夜间模式、Esc关面板）
```

**宿主新增字段**：`keyboardTextInputFocused: boolean = false` — 面板切换时重置

### 9.2 迁移做法

1. 新建 `state/KeyboardShortcutStore.ets`（6 个字段 + KeyboardShortcutItem 类型）
2. 新建 `capability/KeyboardShortcutController.ets`（5 个方法 + 键盘事件分发 4 个方法）
3. I18n key 追加到 `capability/I18n.ets`
4. 类型追加到 `common/types/StellariumTypes.ets`
5. 宿主 `build()` 中的键盘处理 → 移入 Controller + `onKeyEvent` 调用

---

## §10 P9：缩放锚定增强

### 10.1 变更提取

**C++ 侧**：P0 已合入。

**.ets 侧**：privacy 在旧单体中调用 `getViewAnchorState` / `setViewAnchorProbe`。

upstream 的 `SkyInputController` 已持有 pinch/pan 逻辑，需在该 Controller 中叠加锚定调用。

### 10.2 迁移做法

1. 在 `SkyInputController` 中加 `anchorProbeEnabled` / `anchorProbeSamples` 等字段
2. 在 pinch 开始时调 `setViewAnchorProbe`
3. 在 pinch 结束后读 `getViewAnchorState` 验证

---

## §11 P10：卫星来源编辑 + 本地化

### 11.1 变更提取

**宿主新增状态**：

```
expandedSatelliteSourceIndex: number = -1
editingSatelliteSourceIndex: number = -1
satelliteSourceScroller: Scroller = new Scroller()
```

**宿主新增方法**：

```
editSatelliteSource(index) — 设置 editingSatelliteSourceIndex + expandedSatelliteSourceIndex + satSourceInput
confirmRestoreSatelliteSources() — 弹确认对话框
restoreSatelliteSources() — 调 restoreSatelliteSources 命令
satelliteUpdateStatusText() — 返回更新状态文本（禁用/更新中/错误/倒计时）
setSatelliteSourceEnabled(index, enabled) — 修改 sources 数组中 addNew 字段 → 调 setSatelliteSources
satelliteSourcePreview(url) — 返回预览文本（本地文件 / 域名·路径）
satelliteLocalizedName(raw) — 中文卫星名本地化（ISS→国际空间站、CSS→中国空间站、Starlink→星链等 19 个前缀）
```

**卫星列表类型扩展**：

```
SatelliteNamePrefix { token: string; label: string }
```

**I18n key**（~20 个）：`sat_source_enabled_hint` / `sat_source_edit` / `sat_source_save` / `sat_source_restore` / `sat_source_restore_title` / `sat_source_restore_message` / `sat_source_cancel` / `sat_next_update` / `sat_updates_disabled` / `sat_updating` / `sat_update_error` / `sat_update_less_minute` / `sat_update_minutes` / `sat_update_hours` / `sat_source_enabled` / `sat_source_disabled` / `sat_source_local_file`

**`zhNameOf()` 修改**：优先调 `satelliteLocalizedName()` 匹配

### 11.2 迁移做法

1. 扩展 `SatelliteStore`（3 个字段 + SatelliteNamePrefix 类型）
2. 扩展 `SatelliteController`（7 个方法）
3. `satelliteLocalizedName()` → 移入 `common/derive/labels.ets`
4. I18n key 追加
5. upstream 已有卫星面板组件，扩展其来源编辑 UI

---

## §12 P11：时间平滑过渡

### 12.1 变更提取

这是 privacy 分支中**最大的单个逻辑变更**，替换了所有 `callInteractive('setJD', ...)` 直接跳变为平滑动画。

**宿主新增状态**：

```
timeWheelTransitionStartMs: number = 0
timeWheelTransitionStartedAtMs: number = 0
timeWheelTransitionDurationMs: number = 0
astroTimeTransitionTimer: number = 0
astroTimeTransitionSerial: number = 0
astroTimeTransitionRestoreRate: number = 0
astroTimeTransitionLastPushMs: number = 0
astroTimeTransitionUsesNativeRate: boolean = false
astroTimeTransitionTargetJd: number = 0
timeNavigationRequestActive: boolean = false
```

**核心新方法**：

```
timeTransitionDurationMs(distanceDays) — 对数尺度：900ms + log10^1.45 * 1200ms，上限 7000ms
stopAstroTimeTransition(restoreRate) — 清理定时器 + 可选恢复速率
animateTimeToJD(targetJd, label, onFinished?) — 核心方法：
  1. 调 getSimulationTime 获取当前 JD
  2. 若距离 < 1 秒 → 直接 fire setTimeToJD
  3. 否则：暂停速率 → 启动 setInterval(16ms)
  4. 短跳（< 3 天）：逐帧 ease 计算 JD，每 48ms 推送 setTimeToJD
  5. 长跳（≥ 3 天）：设原生速率让引擎自动推进，进度满后 commit 精确 JD
  6. 完成后恢复原速率 + 刷新 UI
```

**被替换的调用点**（7 处）：

```
setTimeNow() → animateTimeToJD(jd, '当前时间')
jumpToRtsCalendar(day) → animateTimeToJD(jd, '升中天落时刻')
jumpToEphemerisRow(row) → animateTimeToJD(jd, '星历时刻', loadEphemeris)
jumpToObservabilityDay(day) → animateTimeToJD(jd, '最佳观测时刻')
jumpToPhenomenon(item) → animateTimeToJD(jd, '天象时刻')
jumpToMoonPhase(item) → animateTimeToJD(jd, phase)
jumpToAlmanacSeason(event) → animateTimeToJD(jd, label)
applyManualTime() → animateTimeToJD(jd, '指定时间')
jumpToWutTarget(target) → animateTimeToJD(jd, '最佳观测时刻', searchObject)
时间标记定位 → animateTimeToJD(targetJD, label, syncScrubber)
```

**时间滚轮过渡重构**：`startTimeWheelTransition` 从线性递进改为 ease 曲线 + 自适应时长。

**新命令**：`jumpToTimeNavigationAction(actionId, label)` — 调 `getTimeNavigationTarget`

**防冲突**：

```
refreshSelectedObject() / detailTimer — 若 timeNavigationRequestActive 或 astroTimeTransitionTimer ≠ 0 则跳过
```

### 12.2 迁移做法

1. 新建 `state/TimeTransitionStore.ets`（10 个字段）
2. 新建 `capability/TimeTransitionController.ets`（3 个方法 + 替换 7 处调用点）
3. `TimeTransitionHostHooks` 含 `flashHint` / `syncScrubber` / `syncTimeWheel` / `refreshTimeNow` / `refreshState` / `callNativeFire` / `setTimeRate` / `syncTimeRateState`
4. upstream 已有 `TimeController` / `TimeStore` / `TimeWheelController`，需在这些中嵌入过渡逻辑
5. `startTimeWheelTransition` 重构：在 `TimeWheelController` 中替换

---

## §13 其他杂项变更

### 13.1 陀螺仪防抖

**新增状态**：`gyroscopePending: boolean` / `gyroscopePendingTarget: boolean` / `lastGyroUiRequestMs: number`

**新增方法**：
- `requestGyroscopeToggle(enabled)` — 280ms 防抖 + pending 状态检查
- `gyroscopeVisualEnabled()` — 返回 pending 目标或实际状态
- `gyroIndicatorColor()` — pending=#FFD36E / on=#72E0A0 / off=rgba(255,255,255,0.42)

**修改**：`toggleGyroscope` / `startGyroscope` / `stopGyroscope` 中每处成功/失败都设置 `gyroscopePending = false`

**迁移**：移入 `GyroStore`（3 个字段）+ `SensorController`（3 个方法）

### 13.2 指针坐标防抖

**新增状态**：`pointerCoordinatesLoadId: number` / `pointerCoordinatesMutationId: number`

**修改**：
- `loadPointerCoordinates(showLoading)` — 请求 ID 防过时
- `setPointerCoordinates(setting, value)` — 乐观更新 UI + mutation ID 防过时
- `updateNativePointerPosition(x, y)` — 节流 48ms

**迁移**：移入 `OverlayStore` + `ViewCoordinateController`

### 13.3 布局增强

**新增**：
- `uiLayoutOverride: string = 'auto'` — 布局强制模式
- `screenSafeBottomPixels: number` — 底部安全区
- `windowEnvironment: string` — 窗口环境 Watch
- `getUiLayout` / `setUiLayoutMode` 命令
- 响应式布局动画优化：桌面切紧凑时 duration=0
- `compactPanelBottom()` / `dockBottom()` / `dockHeight()` 等辅助几何方法
- 字号缩放：`panelFontSize(base)` / `objectDetailFontSize(base, emphasis)` 等

**迁移**：`uiLayoutOverride` → `DockStore`；几何辅助 → `common/derive/geometry.ets`

### 13.4 配置分享

**新增方法**：`shareConfigBackup()` — 调 `exportConfig` → 写临时文件 → `shareFile()`

**迁移**：移入 `SettingsController`

### 13.5 卫星本地化名称

**新增方法**：`satelliteLocalizedName(raw)` — 19 个中文前缀映射

**迁移**：移入 `common/derive/labels.ets`

### 13.6 位置搜索区域过滤

**新增方法**：`locationSearchRegionFilter(query)` — 台湾/香港/澳门特殊地区 → 限制扫描到亚洲

**迁移**：移入 `LocationController` 或 `common/derive/`

### 13.7 StellariumResourceBootstrap 改进

**改动**：所有 `writeRawFile` 改为 `writeRawFileAsync`（循环写入防截断）；`getRawFileListSync` → `getRawFileList`（异步）；4 个 `refresh*` 函数改为 `async`

**迁移**：直接在 upstream 版本上 apply（upstream 此文件改动极小）

### 13.8 build-profile.json5

**privacy**：移除签名配置 + 升 API 版本
**upstream**：仅升 API 版本

**迁移**：采用 upstream 的签名配置清理 + privacy 的 `compatibleSdkVersion: "6.1.0(23)"`

### 13.9 搜索排序修复

**改动**：`locationSearchMatchScore` 排序方向修正（`left - right` → `right - left`，高分在前）

**迁移**：在 upstream 的 `actions.ets` 中修正

---

## §14 配置与资源汇总

| 文件 | privacy 增量 | upstream 现状 | 迁移 |
|---|---|---|---|
| `module.json5` | +INTERNET +PUBLISH_AGENT_REMINDER +FormAbility +窗口约束 | 基线版本 | 手工叠加 |
| `build-profile.json5` | 移除签名 +升 API | 升 API | 取 upstream 的签名清理 + 两边的 API 升级 |
| `form_config.json` | 全新 112 行 | 无 | 直接加入 |
| `easy_go.json` | 碰撞修正 | 基线版本 | apply |
| `QtAppConstants.ets` | +APP_ICP_FILING_NUMBER/URL | 基线版本 | apply |

---

## §15 I18n + StellariumTypes 汇总

### I18n（~40 个新 key，追加到 `capability/I18n.ets`）

| 域 | key 数 |
|---|---|
| 通知/卡片 | 2 |
| 巡天 | 5 |
| 键盘快捷键 | 12 |
| 输入教程 | 4（touchpad/mouse/keyboard/guide_title） |
| 卫星来源 | ~20 |
| 指针坐标 | 1 |
| AR | 0（硬编码中文字符串，待 i18n 化） |

### StellariumTypes（追加到 `common/types/StellariumTypes.ets`）

```
StellariumBridgeResponse 新增字段：session?: Object; preview?: Object; accepted?: boolean; conflictAction?: string; datasets?: Object[]; spectral?: Object
SeasonEvent 新增字段：key?: string; index?: number
```

新增接口：`ArPreviewModeOption` / `ArPreviewBridgeResponse` / `SurveyStateResponse` / `SpectralDataset` / `SpectralState` / `KeyboardShortcutItem` / `SatelliteNamePrefix`

---

## §16 验证矩阵

| 检查项 | 预期 |
|---|---|
| `devecocli build` | BUILD SUCCESSFUL |
| `check-ohos-command-catalog` | 当前值 + ~60 |
| `check-ohos-ui-contract` | 当前值 + 新面板锚点 |
| 隐私启动 | 首次弹隐私框 → 同意后进入 |
| 时间平滑 | 点击年历事件 → 星空平滑过渡 |
| 通知 | 授权 → 发布 → 取消 |
| 提醒 | 节气提醒 → 查看 → 取消 |
| 卡片 | 添加今晚卡片到桌面 |
| 巡天 | 开启 HiPS → 选择波段 → 关闭 |
| AR | 进入无相机预览 → 调节透明度 |
| 在线地图 | 切到地图模式 → 选点 |
| 协作 | 创建会话 → 分享 |
| 键盘快捷键 | 编辑 → 保存 → 恢复 |
| 卫星来源 | 编辑 → 保存 → 恢复默认 |

---

## §17 执行顺序与依赖图

```
P0 (C++)  ──────────────────────────────────────────┐
                                                      │
P1 (隐私) ─── 依赖 P0 的 QAbility 隐私路由          │
  │                                                   │
  ├── P2 (通知/提醒) ── 依赖 P1 的隐私门控           │
  ├── P3 (卡片) ────── 依赖 P1                       │
  ├── P4 (协作) ────── 依赖 P1                       │
  └── P7 (在线地图) ─── 依赖 P1 的隐私门控           │
                                                      │
P5 (巡天) ─── 依赖 P0 的 HipsMgr                     │
P6 (AR) ───── 依赖 P0 的 AR 命令                     │
P8 (键盘) ─── 依赖 P0 的 action 命令                 │
P9 (锚定) ─── 依赖 P0 的 C++ + upstream SkyInput     │
P10 (卫星) ── 依赖 P0 的卫星命令                     │
P11 (时间) ── 依赖 P0 的 getTimeNavigationTarget      │
P12 (杂项) ── 依赖各域                               │
P13 (配置) ── 依赖 P2/P3/P6                          │
P14 (I18n) ── 依赖 P2–P11，做最终对齐                │
```

**推荐执行序**：P0 → P1 → P12(陀螺仪/指针/布局/配置分享/搜索排序) → P11(时间平滑) → P2 → P3 → P4 → P5 → P6 → P7 → P8 → P9 → P10 → P13 → P14

每片闭环：`arkts_check` → `devecocli build` → `check-ohos-ui-contract` → `check-ohos-command-catalog` → 提交
