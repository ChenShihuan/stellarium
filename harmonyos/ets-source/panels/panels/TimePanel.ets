import { TimeStore } from '../../state/TimeStore'
import { TimeWheelStore } from '../../state/TimeWheelStore'
import { EquationOfTimeStore } from '../../state/EquationOfTimeStore'
import { JulianDateStore } from '../../state/JulianDateStore'
import { NightModeStore } from '../../state/NightModeStore'
import { AtmosphereStore } from '../../state/AtmosphereStore'
import { NightModeToggleRow } from '../../common/ui/NightModeToggleRow'
import { QuickChipRow } from '../../common/ui/QuickChipRow'
import { TimeWheelScrubber } from '../time/TimeWheelScrubber'
import { TimeSpeedChips } from '../time/TimeSpeedChips'
import { SiderealTimeRow } from '../time/SiderealTimeRow'
import { EquationOfTimeBlock } from '../time/EquationOfTimeBlock'
import { JulianDateControls } from '../time/JulianDateControls'
import { ObservationAidBlock } from '../time/ObservationAidBlock'
import { ManualTimeBlock } from '../time/ManualTimeBlock'

// 观测时间面板，对应 `activePanel === 'time'`：时间转轴 + 速率档位 + 快捷跳转 + 恒星时 +
// 均时差 + 儒略日 + 夜视模式 + 大气折射 + 手动指定时间。
//
// 六个 store（timeWheel / time / equationOfTime / julian / nightMode / atmosphere）走 @ObjectLink；
// 其余数值/颜色走 @Prop；时间轮控制器与手动时间的读写属宿主私有状态，经回调注入。

@Component
export struct TimePanel {
  @ObjectLink timeWheelStore: TimeWheelStore
  @ObjectLink timeStore: TimeStore
  @ObjectLink equationOfTimeStore: EquationOfTimeStore
  @ObjectLink julianStore: JulianDateStore
  @ObjectLink nightModeStore: NightModeStore
  @ObjectLink atmosphereStore: AtmosphereStore
  @Prop manualYear: number
  @Prop manualMonth: number
  @Prop manualDay: number
  @Prop manualHour: number
  @Prop manualMinute: number
  @Prop textColor: string
  @Prop subColor: string
  @Prop accentColor: string
  @Prop panelColor: string
  @Prop inputColor: string
  @Prop borderTint: string
  onSelectUnit: (unit: string) => void = () => {}
  onWheelTouch: (event: TouchEvent) => void = () => {}
  onChip: (id: string) => void = () => {}
  onEquationToggle: (setting: string, enabled: boolean) => void = () => {}
  onAdjustJulian: (scale: string, direction: number) => void = () => {}
  onApplyJulian: (scale: string) => void = () => {}
  onNightMode: (enabled: boolean) => void = () => {}
  onAtmosphere: (pressure: number, temperature: number, extinction: number) => void = () => {}
  onPickDate: (year: number, monthIndex: number, day: number) => void = () => {}
  onPickTime: (hour: number, minute: number) => void = () => {}
  onApplyManual: () => void = () => {}
  onResetManual: () => void = () => {}

  build() {
    Column() {
      // Sky Guide 风格时间拖动滑块（-365天 ~ +365天）：置于面板最前，手机端打开即可直接拖动
      TimeWheelScrubber({
        store: this.timeWheelStore,
        onSelectUnit: (unit: string) => { this.onSelectUnit(unit) },
        onWheelTouch: (event: TouchEvent) => { this.onWheelTouch(event) }
      })
      TimeSpeedChips({ store: this.timeStore, onChip: (id: string) => { this.onChip(id) } })
      QuickChipRow({ items: [
        { id: '-12h', label: '-12h' }, { id: '+12h', label: '+12h' },
        { id: 'sunRise', label: '日出' }, { id: 'sunTransit', label: '中天' },
        { id: 'sunSet', label: '日落' }, { id: 'astronomicalSet', label: '天文昏' }
      ], onChip: (id: string) => { this.onChip(id) } })
      SiderealTimeRow({
        store: this.timeStore,
        subColor: this.subColor
      })
      EquationOfTimeBlock({
        store: this.equationOfTimeStore,
        textColor: this.textColor,
        subColor: this.subColor,
        accentColor: this.accentColor,
        panelColor: this.panelColor,
        onToggle: (setting: string, enabled: boolean) => { this.onEquationToggle(setting, enabled) }
      })
      JulianDateControls({
        store: this.julianStore,
        textColor: this.textColor,
        subColor: this.subColor,
        inputColor: this.inputColor,
        onAdjust: (scale: string, direction: number) => { this.onAdjustJulian(scale, direction) },
        onApply: (scale: string) => { this.onApplyJulian(scale) }
      })
      // 夜视模式与主界面按钮共用同一 nightModeStore
      NightModeToggleRow({
        store: this.nightModeStore,
        textColor: this.textColor,
        subColor: this.subColor,
        onToggle: (enabled: boolean) => { this.onNightMode(enabled) }
      })
      ObservationAidBlock({
        refractionOn: this.atmosphereStore.refractionOn,
        atmoPressure: this.atmosphereStore.atmoPressure,
        atmoTemperature: this.atmosphereStore.atmoTemperature,
        atmoExtinction: this.atmosphereStore.atmoExtinction,
        textColor: this.textColor,
        subColor: this.subColor,
        borderColorValue: this.borderTint,
        onAtmosphere: (pressure: number, temperature: number, extinction: number) => { this.onAtmosphere(pressure, temperature, extinction) }
      })
      ManualTimeBlock({
        manualYear: this.manualYear,
        manualMonth: this.manualMonth,
        manualDay: this.manualDay,
        manualHour: this.manualHour,
        manualMinute: this.manualMinute,
        textColor: this.textColor,
        subColor: this.subColor,
        inputColor: this.inputColor,
        panelColor: this.panelColor,
        borderColorValue: this.borderTint,
        onPickDate: (year: number, monthIndex: number, day: number) => { this.onPickDate(year, monthIndex, day) },
        onPickTime: (hour: number, minute: number) => { this.onPickTime(hour, minute) },
        onApply: () => { this.onApplyManual() },
        onReset: () => { this.onResetManual() }
      })
    }.width('100%')
  }
}
