import { WutTarget } from '../pages/StellariumTypes'
// 今晚观测目标（WUT）面板状态（原宿主 @State 的 wut* 簇）。
// 这是 astro 域切片的前置半步：后续把面板内的列表/筛选 UI 抽成组件时，组件直接观察本 store。
@Observed
export class WutStore {
  wutTargets: Array<WutTarget> = []
  wutLoading: boolean = false
  wutProgress: string = ''
  wutCategory: string = 'planets'
  wutCategoriesExpanded: boolean = false
  wutPeriod: string = 'midnight'
  wutMinAltitude: number = 20
  wutMaxMagnitude: number = 6
  wutDirection: string = 'all'
  wutLimitAngularSize: boolean = false
  wutMinAngularSizeArcmin: number = 10
  wutMaxAngularSizeArcmin: number = 600
  wutAngularSizeAvailable: boolean = true
  wutObservationTime: string = ''
  wutHint: string = ''
  wutHasResult: boolean = false
}
