// DE 行星历表（JPL 数值星历）配置状态（原宿主 @State 的 "ephemeris" 域字段，Phase 4m）。
//
// 为何独立成 store（不并入 AstroStore）：
//   - AstroStore 里已有一族**同名前缀但语义完全不同**的字段 ——
//     ephemerisData / ephemerisName / ephemerisMeta / ephemerisError / ephemerisDays /
//     ephemerisStepHours / ephemerisStartOffsetDays / ephemerisMode / ephemerisPrimary /
//     ephemerisSecondary / ephemerisLoading，那是 AstroPanel「星历表」自身的数据。
//   - 本 store 的 ephemerisDe4xxAvailable / Active 是「设置 > 主设置」里的 DE 内核开关，
//     ephemerisStartYear/Month/Day 是 AstroPanel 星历表的起始日期（经 ephemerisStartOptionLabel /
//     chooseEphemerisStartDate / resolveEphemerisStartJD 回调读写）。并入 AstroStore 会造成
//     前缀语义混淆与字段名冲突，故独立。
//
// 消费方：SettingsPanel（@ObjectLink，读 8 个 DE 开关）、AstroPanel（经宿主回调读起始日期）。
// 刻意留在宿主（非本 store 状态）：请求序号、load / toggle / picker 等方法与 pickedDate；
// dsoTotalCount / dsoGalaxies / dsoClusters / dsoNebulae 亦留在宿主（见本次切片报告：
// 零读取、loadDSOCounts 未被调用，无面板消费）。
//
// 约束：所有更新必须是"字段整体赋值"。改造前已普查确认无
// `this.ephemerisDe4xx.push|sort` 或 `this.ephemerisDe4xx.<prop> =` 之类的原地变更。
@Observed
export class EphemerisStore {
  ephemerisDe430Available: boolean = false
  ephemerisDe431Available: boolean = false
  ephemerisDe440Available: boolean = false
  ephemerisDe441Available: boolean = false
  ephemerisDe430Active: boolean = false
  ephemerisDe431Active: boolean = false
  ephemerisDe440Active: boolean = false
  ephemerisDe441Active: boolean = false
  ephemerisStartYear: number = new Date().getFullYear()
  ephemerisStartMonth: number = new Date().getMonth() + 1
  ephemerisStartDay: number = new Date().getDate()
}
