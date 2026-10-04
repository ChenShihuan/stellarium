import { I18n } from '../pages/I18n'

// 「界面语言」域状态簇（review §2.7，2026-10-04）。
//
// 本片边界：原宿主 2 个 `@State private` 字段搬入，保留类型与默认值。宿主以
// `@State private languageStore: LanguageStore = new LanguageStore()` 持有，
// 全部引用改写为 `this.languageStore.<字段>`。
//
// 字段：
//   - selectedLanguage —— 当前界面语言（Stellarium 语言码，默认取系统语言）；
//   - languageRevision —— 语言刷新锚点：setLanguage 里 `languageStore.languageRevision++`，
//     以 ForEach 键后缀强制语言相关列表/文案重建。**该字段的刷新语义不得改动。**
//
// 消费方仍以 @Prop 快照接收、宿主在下发点读 store（`this.languageStore.X`）：
//   - selectedLanguage：SettingsPanel / SettingsQuickLegacyPanel / ConfigFallbackPanel
//     以及 LanguageRow（经面板下发）；
//   - languageRevision：MorePanel / SearchPanel / SearchCategoryBrowse / SearchConstellationChips /
//     SearchFilterMenu / 三个壳层 / BottomDock / HubActionList。
//   languageRevision 经多层组件以 @Prop 串接（14 个文件），保持既有链路
//   「宿主自增 → 宿主重渲染 → @Prop 下发 → ForEach 重建」逐字不变，故不改 @ObjectLink。
//
// 约束：均为标量整体赋值；languageRevision 的 `++` 亦为整体赋值，可被 @State 宿主观测。
@Observed
export class LanguageStore {
  selectedLanguage: string = I18n.systemLanguage()
  languageRevision: number = 0
}
