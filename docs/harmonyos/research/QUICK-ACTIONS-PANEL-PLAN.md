# 快捷操作面板（Dock 中间入口）设计与实施计划

状态：已按 §8 切片实施完毕，真机验收通过（实施结果见 §12，含验收追加修订 §12.6）。
适用工程：`harmonyos/`（ArkTS 侧）；不改引擎 C++。

## 0. 目标

1. Dock 栏**中间**按钮由「位置」改为「快捷操作」，点开一个 2×6 = **12 个图标开关**的面板。
2. 12 个图标用 Stellarium **官方图标**（`data/gui/bt*-off.png`）；ON 态按移动端做法 = **用「灭」图标着色高亮**，不使用官方 `-on` 图标。
3. 「位置」入口迁到「更多功能」，位置在**工作区入口与天体数据与扩展入口之间**。
4. 快捷面板标题栏显示当前位置，且该显示框**本身是按钮**，点按直接进入位置设置（细则见 §11）。

参考图（排布样式依据）：`docs/harmonyos/image/com.noctuasoftware.stellarium.jpg`——官方 Stellarium Mobile（Noctua Software）截图，由用户提供；该图片目前**尚未纳入版本控制**。

## 1. 事实勘查（先于设计，逐条有据）

| # | 事实 | 依据 |
| --- | --- | --- |
| 1 | 官方图标 `data/gui/bt*-off.png` ↔ `bt*-on.png` 成对，**160×160 PNG、3–13 KB** | 目录清单 + `System.Drawing` 实测尺寸 |
| 2 | `-off` 是暗灰、`-on` 是白（已看图确认 `btAtmosphere`）→「用灭图标高亮」= 读 `-off` 再着色 | 读 `btAtmosphere-off/on.png` |
| 3 | `data/gui` **未打进 HAP**（`rawfile/` 只有 `stellarium/` 与 `worldmap.jpg`）→ 必须新增资源或改构建 | `build/libstellarium-harmonyos/entry/src/main/resources/rawfile` |
| 4 | 着色官方依据：`colorBlend` 会把**透明背景变白**，ArkUI FAQ 明确「采用 `colorFilter` 替代」（颜色矩阵只改非透明像素、保留 alpha） | `devecocli docs read FAQ/UI框架/组件使用/如何对PNG图标进行着色/faqs-arkui-1328` |
| 5 | 移动端现有图标机制 = 单色 SVG + `.fillColor()`（77 个 `ic_*.svg`）；`getIcon(icon, isActive)` 的 `isActive` 目前未被使用 | `common/ui/ShellIcons.ets` |
| 6 | 12 项状态**全已存在**：`LayerStore`(9 项) / `SatelliteStore.satHints` / `GyroStore.gyroscopeEnabled` / `NightModeStore.nightMode` | 各 store 实读 |
| 7 | Dock = `canonicalDockActions()` = `primaryDockActions()[0..3]` + 更多；中间即 index 2 = `place`；Dock 按钮**无 `.id()` 锚点** | `pages/MainWindowNativeNode.ets` `canonicalDockActions()` |
| 8 | `MorePanel` 按 `item.section` 变化插小标题 → `place` 放进 `moreActions()` 中 `more_workspace_observing` 之后并沿用 `more_section_workspace`，即「工作区」组第 2 行、压在天体数据组标题之前 | `panels/panels/MorePanel.ets` + `common/derive/actions.ets` |
| 9 | 面板路由表须同步 3 处：`panelRouteRoot` 的 `mainPanels`、`inferredPanelRouteDirection` 的 `routeOrder`、`common/derive/skycult.ets` 的面板清单 | `common/derive/actions.ets`、`common/derive/skycult.ets` |
| 10 | 人造卫星官方 action = `actionShow_Satellite_Hints`（插件 `flagHintsVisible`，即"显示人造卫星"总开关）→ 正对应 `SatelliteController.setSatelliteFlag('hints', v)` | `plugins/Satellites/src/*.cpp` |
| 11 | 官方 `data/gui` **没有** `人造卫星` / `陀螺仪` 的 `bt*` 图标 | 目录清单核对 |

## 2. 12 项映射表

| # | 名称（提示文案） | 动作 | 状态源 | 图标 |
| --- | --- | --- | --- | --- |
| 1 | 星座连线 | `actionShow_Constellation_Lines` | `layerStore.constellationLines` | `bt_constellation_lines.png` |
| 2 | 星座标识 | `actionShow_Constellation_Labels` | `constellationLabels` | `bt_constellation_labels.png` |
| 3 | 星座图绘 | `actionShow_Constellation_Art` | `constellationArt` | `bt_constellation_art.png` |
| 4 | 赤道坐标 | `actionShow_Equatorial_Grid` | `equatorialGrid` | `bt_equatorial_grid.png` |
| 5 | 地平坐标 | `actionShow_Azimuthal_Grid` | `azimuthGrid` | `bt_azimuthal_grid.png` |
| 6 | 地景 | `actionShow_Ground` | `ground` | `bt_ground.png` |
| 7 | 大气层 | `actionShow_Atmosphere` | `atmosphere` | `bt_atmosphere.png` |
| 8 | 方位基点 | `actionShow_Cardinal_Points` | `cardinalPoints` | `bt_cardinal_points.png`（内容取自官方 `data/gui/bbtLocation-off.png`，见 §12.6） |
| 9 | 深空天体 | `actionShow_Nebulas` | `nebulas` | `bt_nebula.png` |
| 10 | 人造卫星 | `setSatellitesFlag hints:1/0` | `satelliteStore.satHints` | `ic_satellite.svg`（自研，`kind: vector`） |
| 11 | 陀螺仪 | gyro 启停（`setGyroView` 链路） | `gyroStore.gyroscopeEnabled` | `ic_gyro.svg`（自研，`kind: vector`） |
| 12 | 夜间模式 | `setNightMode` | `nightModeStore.nightMode` | `bt_night_view.png` |

网格排布（与用户截图一致）：**第 1 行 = #1–#6**（星座×3 → 坐标×2 → 地景），**第 2 行 = #7–#12**（大气 → 方位基点 → 深空 → 卫星 → 陀螺仪 → 夜间模式）。

## 3. 图标与着色方案（本次核心）

```
ON :  Image(bt_xxx.png).colorFilter(TINT_ON)    // 矩阵把 RGB 统一压成 #EAF7FF，alpha 保留
OFF:  Image(bt_xxx.png).colorFilter(TINT_OFF)   // 压成暗灰 #7E8896（不再叠加 opacity，见 §12.6）
向量 :  Image(ic_xxx.svg).fillColor(on ? '#EAF7FF' : '#7E8896')   // 沿用既有 SVG 机制
```

- 颜色矩阵形如 `[0,0,0,0,R, 0,0,0,0,G, 0,0,0,0,B, 0,0,0,1,0]`（只改 RGB、保留 alpha）；写成文件级
  `const TINT_ON: number[] = [...]` / `const TINT_OFF: number[] = [...]`，显式定型以符合 ArkTS 禁裸字面量。
- **矩阵值必须归一化到 0.0–1.0**（1.0 对应 255，官方 FAQ `faqs-arkui-1353`）；填 0–255 会被截断成近白 —— 实机踩过，见 §12。
- 10 个官方 PNG 拷入 `harmonyos/ets-source/resources/base/media/` 并改蛇形名（`bt_*.png`），合计约 71 KB。
- 组件按 `kind: 'raster' | 'vector'` 走双路径着色；两种路径都产出同一套 `#EAF7FF` / `#7E8896` 观感。
- 官方 `-off` PNG 自带柔和阴影，`colorFilter` 会把阴影一并着色成半透明同色 → 视觉上是轻微光晕，可接受；
  若真机实测偏脏，退路是 `.brightness()` / 直接调 `TINT_OFF` 的亮度档。

## 4. 结构（按仓库分层，力求零新增 store / 零新增 controller）

| 层 | 文件 | 职责 |
| --- | --- | --- |
| derive | `common/derive/quickActions.ets`（新） | 12 项**纯描述表**（`id` / `labelKey` / `icon` / `kind` / `actionId`），零 store、零 IO、零桥 |
| panel | `panels/quick/QuickActionGrid.ets`（新） | 2×6 网格 + 双路径着色 + 长按 `flashHint(名称)` |
| panel | `panels/panels/QuickPanel.ets`（新） | 只装配图标网格；标题栏由宿主 `PanelHeader` 渲染（`titleAsButton` 显示位置并跳「位置」） |
| 宿主 | `pages/MainWindowNativeNode.ets` | `activePanel === 'quick'` 分支 + `quickToggle(id, value)` 分发到 4 个既有控制器/store |
| 入口 | `common/derive/actions.ets` | Dock 中间项替换、`moreActions()` 插入 place、路由表 2 处 |
| 入口 | `common/derive/skycult.ets` | 面板清单同步 |
| 图标 | `common/ui/ShellIcons.ets` | 注册 `'quick_actions'` → 新增 `ic_quick_actions.svg`（Dock 中间项用） |
| 文案 | `capability/I18n.ets` | 缺失标签键（见 §5）＋ `loc_source_gps` |

关键点：**状态与动作全部已存在**，宿主只做一次 `id → 目标` 的分发，因此不需要新 store、不需要新 controller。

`quickToggle` 分发（宿主内）：
- `layerStore` 系（#1–#9）→ `layerCtl().applyLayerSwitch(actionId, '', value)`（`setLayer` 是 private，公开入口才是它）
- #10 → `satelliteCtl().setSatelliteFlag('hints', value)`
- #11 → 陀螺仪启停（复用位置面板已有的 `gyroCtl()` 入口）
- #12 → `nightModeStore.applyNightMode(value, true)`（与时间面板同一入口）

## 5. 文案

- 面板标题 = **观测点文本**（用户决策：标题栏直接显示观测点），副标题沿用 `timeStore.panelSubtitle()`。
- `common/derive/labels.ets` 的 `panelTitleFor(...)` 增加一个 `locationText` 入参（仅 `quick` 用），保持纯函数。
- 12 个提示文案**全部复用既有键**（零新增项文案，落地后逐条列证见 §12.2）：星座线 `s0522` / 星座标签 `s0523` /
  星座艺术 `s0525` / 赤道网格 `s0323` / 方位网格 `s0324` / 地面 `s0306` / 大气 `s0305` / 方位基点 `s0533` /
  深空天体 `s0320` / 人造卫星 `plugin_satellites` / 陀螺仪 `i0060` / 夜间模式 `s0300`。
- Dock 标签新增 `dock_quick`（zh_CN「快捷开关」）；位置来源标签新增 `loc_source_gps`（`GPS`）。
  注：既有 `i0217` = 「快捷操作」已被帮助面板占用，故 Dock 用「快捷开关」避免重名。

## 6. 布局规格（对齐截图）

| 项 | 值 |
| --- | --- |
| 网格 | 6 列 × 2 行 |
| 图标 | raster 30 vp / vector 26 vp（官方 PNG 留白更多，故取略大） |
| 单元格 | 宽度由行均分（`layoutWeight(1)`）+ `aspectRatio(1)` 成正方形（本机实测 ≈ 52 vp），圆角 `UI_RADIUS_CONTROL` |
| 间距 | 横向 8 vp，纵向 10 vp |
| 面板高度 | **只显示两行**：`quickPanelContentHeight()` = 12 + 30（抓手）+ 头部（有副标题 56 / 无 44）+ 14 + 两行图标 + 16；详见 §12.6 |
| 底色 | **未选中不画底框**（透明；夜间模式下浅底框几乎不可辨）；选中 `rgba(107,163,214,0.12)` + 边框（与 `LayerSwitchRow` 同一套语汇）。边框宽度恒为 1（颜色透明）以免切换时格子尺寸跳动 |
| 文字 | 网格内**不显示**逐项文字（同截图）；长按出 `flashHint` 名称 |
| 无障碍 | `.accessibilityText(名称)` |

## 7. 已确认决策

1. 载体 = **标准面板**（标题栏显示观测点）。
2. `星空连线` = `actionShow_Constellation_Lines`（星座连线）。
3. `人造卫星` / `陀螺仪` 用**现有自研 SVG**（官方无 `bt*` 对）。
4. 官方 PNG **拷入 `resources/base/media/`**（不改构建脚本、不打包整个 `data/gui`）。
5. `陀螺仪` 点按 = **直接启停**（等同位置面板陀螺仪按钮）。
6. 本设计**落成计划文档**（本文件）。
7. Dock 中间入口图标 = 新增 `ic_quick_actions.svg`（Material `dashboard`，4 块**不等大小**方块的面板语汇），经 `ShellIcons` 注册为 `'quick_actions'`。该文件已先期存入 `harmonyos/ets-source/resources/base/media/`（24×24、单行、CRLF、无 BOM，与 `ic_layers.svg` 同规格）。选它的理由：仓库现有 76 枚图标本就是 Material 家族（`ic_search`/`ic_settings`/`ic_layers` 的 path 与官方逐字节一致），新增同族图标零许可面变化（Apache-2.0）、零风格断层。
8. 快捷面板标题栏的**位置显示框本身即按钮**：点按直接跳转「位置」面板；判定按**来源 + 观测星球**而非名称字符串：GPS 且观测星球为地球 → `GPS`；地图点选 → 「自定义位置」（复用既有键 `custom_location`）；其余（含非地球星球）→ 位置名。两处文案与位置面板「位置」行**同源**（都读宿主 `locationText`）。细则见 §11。
9. 「自定义位置」措辞**沿用仓库既有键**（用户确认），不引入「自定义地点」新文案。

## 8. 切片清单（实施）

- **QA1 图标落盘**：从 `data/gui/` 拷 10 个 `bt*-off.png` → `resources/base/media/bt_*.png`；跑 `audit-ohos-resource-coverage`。（Dock 用的 `ic_quick_actions.svg` 已先期存入，见 §7.7。）
- **QA2 描述表 + 文案**：新增 `common/derive/quickActions.ets`；补/复用 12 个文案键与 `dock_quick`。
- **QA3 网格组件**：`panels/quick/QuickActionGrid.ets`（双路径着色、长按提示、无障碍）。
- **QA4 面板 + 宿主分发**：`panels/panels/QuickPanel.ets`；宿主 `activePanel === 'quick'` 分支 + `quickToggle()` + `panelTitleFor` 观测点。
- **QA4b 位置来源与标题栏按钮**：`LocationPickerStore` 增 `locationSource`；`useDeviceLocation` / 地图点选 / 城市与搜索三处分别写 `gps` / `map` / `named`；`ObserverLocationRecord` 增 `source` 字段并由 `restoreObserverLocation` 回读（旧记录缺该字段回落 `named`）；`PanelHeader` 增 `titleAsButton` + `onTitleTap` 与 `panel-title-action` 锚点；宿主按来源推导标题标签，点按走 `openSubPanel('place')`。
- **QA5 入口改造**：Dock 中间项替换为 `quick`；`moreActions()` 插入 `place`（工作区组）；路由表 2 处 + `skycult.ets` 同步。
- **QA6 验证与提交**：`arkts_check` → 构建 → `check-ohos-ui-contract`（新增锚点走 `--update`）→ 资源审计 → 真机 12 项逐一点按 + 引擎侧回读 → CHANGELOG → commit。

## 9. 验证口径

1. 静态：`arkts_check` 0 error；`devecocli build` SUCCESSFUL。
2. 契约：`node scripts/check-ohos-ui-contract.mjs` intact（新增锚点须 `--update` 再生并说明）。
3. 资源：`node scripts/audit-ohos-resource-coverage.mjs` 通过（新增 10 个 media 计入）。
4. 真机（`--bundle com.cnchensh.stellarium`，勿用默认发布包名）：
   - Dock 中间按钮打开快捷操作面板，标题显示观测点；
   - 12 项逐一点按 → 图标亮/灭切换正确；
   - 用 `getState` 回读 `actionShow_Constellation_Lines` / `..._Labels` / `..._Art` / `..._Equatorial_Grid` / `..._Azimuthal_Grid` / `..._Ground` / `..._Atmosphere` / `..._Cardinal_Points` / `..._Nebulas` / `nightMode`，用卫星面板或 `setSatellitesFlag` 回执核对 `hints`，陀螺仪看 `gyroscopeEnabled` 与权限提示；
   - 「更多功能」中位置入口位于「观测工作区」与「天体数据与扩展」之间，点按进入位置面板；
   - 标题栏位置按钮：点按进入位置面板；**两处（位置面板「位置」行与快捷面板标题）必须显示同一字符串**；GPS 定位且观测星球为地球时显示 `GPS`，其余星球回落位置名（如「火星表面」），地图点选显示「自定义位置」（见 §11.3），城市选择显示城市名；杀进程重启后标签保持（来源随观测点持久化）。
5. `eol`：新增 `.ets` 与文档一律 CRLF；`write` 工具产物须归一回 CRLF。

## 10. 风险与对策

| 风险 | 对策 |
| --- | --- |
| `colorFilter` 把官方 PNG 的柔阴影一并着色，观感偏脏 | 先按本方案实现，真机看效果；退路 `.brightness()` 或调 `TINT_OFF` |
| 12 项里 `赤道坐标` 等会与图层页既有措辞（`赤道网格`）不一致 | 面板内不显示文字，仅长按提示；文案在 QA2 逐条定稿并记录 |
| 新面板进入 `panelRouteRoot` 主链，返回手势/路由方向可能错位 | QA5 同步 3 处路由表，QA6 真机走查返回栈（含系统返回手势） |
| 陀螺仪启停涉及权限弹窗 | 真机走查权限路径，未授权时保留"提示 + 不改状态"的既有降级 |

## 11. 位置来源与标题栏按钮（补充设计）

### 11.1 现状（事实）

| 事实 | 依据 |
| --- | --- |
| 位置文案当前由引擎回读驱动：`locationText = locationDisplayName(engine.locationName) + ' · ' + planetZh(planet)`，且宿主的 `locationText` **会被轮询覆写** | `MainWindowNativeNode` 引擎状态分支 + `@State locationText` |
| GPS 路径落地的名字 = `I18n.t('m_current_location')`；GPS 与地图点选**共用** `LocationPickerStore.setPickerLocation(name, …)` | `LocationController.useDeviceLocation()`、`LocationPickerStore.setPickerLocation()` |
| 观测点已持久化：`ObserverLocationRecord{ name, latitude, longitude, altitude, planet }`，启动由 `restoreObserverLocation()` 静默重建 | `LocationController.restoreObserverLocation()` |
| 应用**没有**记录"位置来源"，只能从名称字符串猜 | 全仓无 source / tag 字段 |
| 面板跳转入口 = 宿主 `openSubPanel(panel)`（「更多功能」各处都走它） | `MainWindowNativeNode` 的 `onOpenPanel: (panel) => this.openSubPanel(panel)` |

结论：要按来源显示，必须**新增来源标记**；不能靠字符串匹配——`m_current_location` 是本地化文案，切语言即失效。

### 11.2 来源标记

- `state/LocationPickerStore.ets` 新增 `locationSource: 'gps' | 'map' | 'named' = 'named'`。
- 三个写入点：

| 入口 | 写入 | 备注 |
| --- | --- | --- |
| `LocationController.useDeviceLocation()` GPS 成功落地 | `'gps'` | 与 `setPickerLocation(...)` 同一处 |
| `LocationPickerPanel` 地图点选 / 拖动落地 | `'map'` | 与 `setPickerLocation(...)` 同一处 |
| `selectCityByName()` / 搜索点选 / 预设 / 恢复 | `'named'` | 默认值，可省写 |

- 持久化：`ObserverLocationRecord` 增 `source?: string`；`setLocation()` 透传并在写盘时带上；`restoreObserverLocation()` 读回，**非法或缺失一律回落 `named`**（保证旧记录兼容）。

### 11.3 显示规则

判定顺序（最终实现 = 纯函数 `quickLocationLabel(source, displayName, planetName)`）：

| 条件 | 显示 | 文案键 |
| --- | --- | --- |
| 来源 `gps` **且观测星球 = 地球** | `GPS` | 新增 `loc_source_gps`（zh_CN `GPS`）。**不要复用**既有 `gps` 键——它是「GPS导航」，卫星类别名 |
| 来源 `map` | 自定义位置 | 复用既有键 `custom_location`（zh_CN 即「自定义位置」） |
| 其余（含 `gps` + 非地球星球） | 该位置名 | — |

- 「非地球观测点」的位置名由引擎按星球给（实测为 `Mars surface` 这类英文串），在 `LocationPickerStore.surfaceLocationName`
  折到既有 `land_mars` / `land_moon` / `land_jupiter` 键 → 「火星表面」/「月球表面」/「木星表面」。
- 位置面板「位置」行与快捷面板标题**共读宿主 `locationText`**，保证两处逐字一致（见 §12.6）。

**措辞已定（用户确认）**：`map` 来源沿用仓库既有键 `custom_location` = 「自定义位置」，**不引入**「自定义地点」新文案——位置面板头部与保存对话框用的都是「自定义位置」，保持全应用一致。

### 11.4 标题栏按钮

- `panels/shell/PanelHeader.ets` 新增：
  - `@Prop titleAsButton: boolean = false`
  - `onTitleTap: () => void = () => {}`
  - `titleAsButton === true` 时标题文本外包为按钮化容器：`backgroundColor('rgba(255,255,255,0.06)')`、`borderRadius(UI_RADIUS_PILL)`、`height(32)`、`padding({ left: 12, right: 8 })`，右侧配 `getIcon('chevron_right')`（着色 `rgba(184,228,255,0.72)`），并加 `.stateStyles({ pressed: … })` 与 `.accessibilityText(...)`。
  - 新增跨会话静态 id 锚点 **`panel-title-action`**（契约静态 id 24 → 25，须 `--update` 并说明）。
- 宿主：仅 `activePanel === 'quick'` 传 `titleAsButton: true`，`onTitleTap: () => { this.openSubPanel('place') }`。
- 标题文本**直接用宿主的 `locationText`**（`quickPanelLocationLabel()` 就是它的读取器），与位置面板「位置」行完全同源。
  原设计曾担心轮询会把 `GPS` 冲掉，但把取值规则做进轮询分支后该顾虑已不成立（见 §12.6）；取值逻辑在纯函数
  `quickLocationLabel(source, displayName, planetName)`（`common/derive/labels.ets`），`panelTitleFor(...)` 只负责组装标题。
- 副标题沿用 `timeStore.panelSubtitle('quick')`，作为按钮文案的补充（可显示观测坐标）。

## 12. 实施结果（QA1–QA6 全部完成）

### 12.1 切片结论

| 切片 | 结论 |
| --- | --- |
| QA1 图标落盘 | 10 枚 `bt*-off.png` → `resources/base/media/bt_*.png`（~71 KB）；`ic_quick_actions.svg` 先期存入 |
| QA2 描述表与文案 | `common/derive/quickActions.ets` + `ShellIcons` 注册 11 个键 + `dock_quick` / `loc_source_gps` |
| QA3 网格组件 | `panels/quick/QuickActionCell.ets`（双路径着色 + 长按提示 + accessibilityText）、`panels/quick/QuickActionGrid.ets`（两行 Row，每格 `layoutWeight(1)` + `aspectRatio(1)`） |
| QA4 面板与宿主分发 | `panels/panels/QuickPanel.ets` + 宿主 `activePanel === 'quick'` 分支、`quickActionValues()`、`quickToggle()` |
| QA4b 位置来源与标题按钮 | `LocationPickerStore.locationSource` + `ObserverLocationRecord.source`（持久化 / 回读，旧记录回落 `named`）+ `PanelHeader.titleAsButton` / `onTitleTap` / `panel-title-action` + `quickLocationLabel` + `openSubPanel('place')` |
| QA5 入口改造 | Dock 第 3 项改为 `quick` / `quick_actions`；`moreActions()` 在工作区组插入 `place`；路由表两处 + CLI 面板白名单加 `quick` |
| QA6 验证 | 见 §12.3 |

### 12.2 12 项文案（最终，全部复用既有键）

| # | 项 | 键 | zh_CN |
| --- | --- | --- | --- |
| 1 | 星座连线 | `s0522` | 星座线 |
| 2 | 星座标识 | `s0523` | 星座标签 |
| 3 | 星座图绘 | `s0525` | 星座艺术 |
| 4 | 赤道坐标 | `s0323` | 赤道网格 |
| 5 | 地平坐标 | `s0324` | 方位网格 |
| 6 | 地景 | `s0306` | 地面 |
| 7 | 大气层 | `s0305` | 大气 |
| 8 | 方位基点 | `s0533` | 方位基点 |
| 9 | 深空天体 | `s0320` | 深空天体 |
| 10 | 人造卫星 | `plugin_satellites` | 人造卫星 |
| 11 | 陀螺仪 | `i0060` | 陀螺仪 |
| 12 | 夜间模式 | `s0300` | 夜间模式 |

第 1–6 项与用户清单的措辞差异（星座线 / 星座标签 / 星座艺术、赤道网格 / 方位网格、地面）属仓库既有命名，
按「优先复用仓库既有键」处理；面板内不显示文字，仅长按提示会读到。

### 12.3 实机验证（192.168.3.95:36717 —— 设备换网后的新 IP）

- Dock 中间 = 「快捷开关」+ dashboard 图标；面板 2×6 = 12 图标全部正确（含卫星 / 陀螺仪两枚自研 SVG）。
- 亮 / 灭对比正确：官方 PNG 路（`colorFilter`）与自研 SVG 路（`fillColor`）观感一致。
- 点星云格 → `getState` 回读 `actionShow_Nebulas` false → true；点夜间模式 → `nightMode` true → false（已复原）；
  点卫星格 → 格子点亮，`longClickable` 亦为 true（长按提示已注册）。
- 标题栏位置按钮点按进入「位置」面板；当时标题显示 `GPS ▸`（§12.6 起两处统一为同一字符串，见该节）。
- 「更多功能」顺序：工作区 → 观测工作区 → **位置** → 天体数据与扩展。
- 契约：47 锚点 / 34 面板 / 26 静态 id / 18 动态前缀（已 `--update`）。测试期间改动的开关均已复原。

### 12.4 本片新踩的坑（会重复踩）

1. **`colorFilter` 矩阵值必须归一化到 0.0–1.0**（1.0 = 255，官方 FAQ `faqs-arkui-1353`）：首版填 0–255 被截断，
   「灭」态图标整片发白，只剩格子底色可辨。
2. **`getIcon()` 未命中键会静默回落 `ic_search`**（放大镜）：描述表里误写资源名 `ic_satellite` / `ic_gyro`
   而非映射键 `satellite` / `gyro`，真机上一眼看到两格是放大镜。
3. **`arkts_check` 不查跨文件可见性**：`LayerController.setLayer` 是 private，只有完整 hvigor 构建才报错；
   公开入口是 `applyLayerSwitch`。
4. `scripts/stellarium-cli.mjs` 必须显式 `--bundle com.cnchensh.stellarium`（默认是发布身份）。

### 12.5 未纳入本次改动

`node scripts/audit-ohos-resource-coverage.mjs` 已跑过（作为资源校验），但其再生报告同时包含**与本功能无关的既有漂移**
（`stars` 的 rawfile 计数、若干静态入口判定、`src` 体积），故已 `git checkout` 回退该报告文件，避免把无关变化混入本次改动。

### 12.6 验收追加修订（同日第二轮）

用户验收时提出的六点，全部并入同一次提交：

1. **位置面板与快捷面板必须是同一字符串**：改为单一来源 —— 快捷面板标题直接复用宿主 `locationText`
   （引擎轮询在 `handleEngineState` 里按规则持续刷新它），不再各算一份。
2. **`GPS` 需要星球前提**：`quickLocationLabel(source, displayName, planetName)` 仅在「来源 = gps 且观测星球 = 地球」
   时返回 `GPS`；切到火星后自动定位语义不成立，回落位置名。
3. **引擎的星球默认点名称要本地化**：引擎给的是 `Mars surface` 这类英文串（位置面板实测可见），
   在 `LocationPickerStore.surfaceLocationName` 折到既有 `land_mars` / `land_moon` / `land_jupiter` 键 →
   `火星表面` / `月球表面` / `木星表面`。两处最终都显示 `火星表面 · 火星`。
4. **快捷面板高度按内容**：`quickPanelContentHeight()` = 12（面板上内边距）+ 30（PanelHandle）+ 头部
   （有副标题 56 / 无 44）+ 14（头部 margin）+ 两行图标（2 × 单元格 + 10 行距）+ 16（下内边距）；
   单元格宽 =（面板内宽 − 5 × 8 间距）/ 6，由 `QuickActionCell` 的 `layoutWeight(1)` + `aspectRatio(1)` 保证正方。
   同时把该面板 Scroll 内容的下内边距 34 归零，并让 `compactPanelHeight()` 在 `activePanel === 'quick'` 时
   直接返回它 —— 面板定位、面板返回热区、拖拽夹取都跟着一致。
   - **关键机制**：ArkUI 的 `Scroll` 会把「比视口短」的内容**垂直居中**。实测内容 152.3vp、视口 203.3vp、
     内容顶边比视口顶边低 25.5vp（恰好是差值的一半），这也解释了改前图标下方那段空白。
     让容器高度等于内容高度，图标才会贴着标题栏。
   - 修复后实测：`panel-scroll` 高 338px（= 112.7vp ≈ 两行图标 113.3vp），第一行顶边与视口顶边 0 偏移。
5. **灭态不画底框**：夜间模式下灭态的浅底框几乎不可辨，改为只有「开」有底色 + 边框；
   边框宽度恒为 1（颜色透明）以免切换时格子尺寸跳动。
6. **方位基点图标**换用官方 `data/gui/bbtLocation-off.png`（真名就是双 b，一枚星形罗盘），仍是 raster + `colorFilter` 路径。

验证：`arkts_check` 0 error、`BUILD SUCCESSFUL`、UI 契约 47 锚点 / 26 静态 id / 34 面板 / 18 动态前缀**不变**
（未增删 id 锚点）；真机实证 —— 地球 + 名称时两处都是 `广州 · 地球`；火星 + GPS 时（修订中间构建）
位置面板已不再显示 `GPS` 而是 `自定义位置 · 火星`，证明星球前提生效；面板高度紧贴两行、灭态无框、
方位基点显示星形罗盘。
说明：最终构建上「火星」分支未再复验（设备当时已切回地球 + 广州），该分支由「同一函数 +
实测确认的引擎串 `Mars surface` + 既有键 `land_mars` = 火星表面」推得。



