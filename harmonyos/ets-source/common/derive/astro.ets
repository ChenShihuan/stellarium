// Astronomy display/derivation helpers.
// Migrated verbatim from pages/MainWindowNativeNode.ets (plan §14.2, track A1-2).
// These are pure, stateless file-level functions: no host-field access, no IO,
// no store/UI imports. They only depend on their arguments, the shared
// HeliocentricPosition type, and the static HELIOCENTRIC_PLANET_ORBITS table.

import { TabItem, HeliocentricPosition } from '../../pages/StellariumTypes'
import { HELIOCENTRIC_PLANET_ORBITS } from '../../pages/MainWindowModels'
import { I18n } from '../../pages/I18n'

// Julian day from a calendar date/time. Pure Gregorian/Julian conversion;
// no timezone handling (callers pass the values they want).
export function dateToJD(year: number, month: number, day: number, hour: number, minute: number): number {
  if (month <= 2) {
    year -= 1
    month += 12
  }
  const A = Math.floor(year / 100)
  const B = 2 - A + Math.floor(A / 4)
  const jdDay = Math.floor(365.25 * (year + 4716)) + Math.floor(30.6001 * (month + 1)) + day + B - 1524.5
  return jdDay + hour / 24.0 + minute / 1440.0
}

/** 儒略日 -> 'YYYY-MM-DD HH:mm:ss' 本地显示文本（入参需已含 UTC 偏移）。 */
export function jdToLocalTimeText(jd: number): string {
  // 用 UTC 取值避免设备时区二次偏移（jd 已带观测地偏移）
  const d = new Date((jd - 2440587.5) * 86400000)
  const p2 = (n: number): string => n < 10 ? '0' + n : n.toString()
  return d.getUTCFullYear() + '-' + p2(d.getUTCMonth() + 1) + '-' + p2(d.getUTCDate()) + ' ' +
    p2(d.getUTCHours()) + ':' + p2(d.getUTCMinutes()) + ':' + p2(d.getUTCSeconds())
}

export function astroGroupForTab(tab: number): number {
  if (tab === 0 || tab === 1 || tab === 6) return 1
  if (tab === 3 || tab === 7 || tab === 8) return 2
  return 0
}

export function graphModeLabel(mode: number): string {
  if (mode === 0) return '高度曲线'
  if (mode === 1) return '方位角曲线'
  if (mode === 2) return '全年高度'
  if (mode === 3) return '月度可观测性'
  if (mode === 4) return '月距曲线'
  return '双变量时间曲线'
}

export function hourOffsetLabel(t: number): string {
  const h: number = Math.floor(t)
  const mi: number = Math.round((t - h) * 60)
  if (h === 0 && mi === 0) return '此刻'
  let s: string = ''
  if (h > 0) s += h.toString() + ' 小时'
  if (mi > 0) s += mi.toString() + ' 分'
  return s + '后'
}

export function hecPointAngle(position: HeliocentricPosition): number {
  return position.displayLongitude ?? position.longitude
}

export function hecPlanetOrbitRadius(englishName: string): number {
  for (const orbit of HELIOCENTRIC_PLANET_ORBITS) {
    if (orbit.englishName === englishName) return orbit.visualRadius
  }
  return 0
}

export function messierNumberOf(raw: string): string {
  const compact = raw.trim().replace(/\s+/g, '')
  if (!/^M\d+$/i.test(compact)) { return '' }
  const number = Number(compact.substring(1))
  return number >= 1 && number <= 110 ? number.toString() : ''
}

export function minorPlanetNumberOf(raw: string): string {
  const match = raw.trim().match(/^\(?(\d{1,7})\)?(?:\s|$)/)
  return match !== null ? match[1] : ''
}

// 精确到角秒：地球自转约 15″/秒，300ms 刷新时用户能直接看到坐标连续变化。
export function fmtDegMin(deg: number): string {
  const sign = deg < 0 ? '-' : ''
  let totalSeconds = Math.round(Math.abs(deg) * 3600)
  const d = Math.floor(totalSeconds / 3600)
  totalSeconds -= d * 3600
  const m = Math.floor(totalSeconds / 60)
  const s = totalSeconds - m * 60
  return sign + d.toString() + '°' + (m < 10 ? '0' + m : m.toString()) + '\'' + (s < 10 ? '0' + s : s.toString()) + '″'
}

export function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value))
}

export function distance(x0: number, y0: number, x1: number, y1: number): number {
  const dx = x1 - x0
  const dy = y1 - y0
  return Math.sqrt(dx * dx + dy * dy)
}

export function astroTabItemsForGroup(group: number): Array<TabItem> {
  if (group === 1) {
    return [
      { label: I18n.t('a0000'), id: 0 },
      { label: I18n.t('a0001'), id: 1 },
      { label: I18n.t('a0006'), id: 6 }
    ]
  }
  if (group === 2) {
    return [
      { label: I18n.t('a0003'), id: 3 },
      { label: I18n.t('a0007'), id: 7 },
      { label: I18n.t('a0008'), id: 8 }
    ]
  }
  return [
    { label: I18n.t('a0005'), id: 5 },
    { label: I18n.t('a0002'), id: 2 },
    { label: I18n.t('a0004'), id: 4 },
    { label: I18n.t('a0009'), id: 9 }
  ]
}

export function astroGroupItems(): Array<TabItem> {
  return [
    { label: I18n.t('astro_group_observation'), id: 0 },
    { label: I18n.t('astro_group_position'), id: 1 },
    { label: I18n.t('astro_group_events'), id: 2 }
  ]
}

export function rtsCalendarDurationLabel(days: number): string {
  if (days === 31) return '1 个月'
  if (days === 62) return '2 个月'
  if (days === 92) return '3 个月'
  if (days === 183) return '6 个月'
  if (days === 365) return '12 个月'
  return days.toString() + ' 天'
}

export function graphStartOptionLabel(offsetDays: number): string {
  if (offsetDays === 0) return '当前'
  return '+' + offsetDays.toString() + ' 天'
}

export function planetMetricLabel(metric: string): string {
  if (metric === 'magnitude') return '星等'
  if (metric === 'phase') return '照亮比例'
  if (metric === 'distance') return '距离'
  if (metric === 'elongation') return '距日角'
  if (metric === 'angularSize') return '视直径'
  if (metric === 'phaseAngle') return '相角'
  if (metric === 'heliocentricDistance') return '日心距'
  if (metric === 'transitAltitude') return '过中天高度'
  if (metric === 'rightAscension') return '赤经'
  return '赤纬'
}

export function planetMetricUnit(metric: string): string {
  if (metric === 'phase') return ' %'
  if (metric === 'distance' || metric === 'heliocentricDistance') return ' AU'
  if (metric === 'angularSize') return '″'
  if (metric === 'rightAscension') return ' h'
  if (metric === 'magnitude') return ' 等'
  return '°'
}

export function planetPairBodyName(body: string): string {
  if (body === 'Sun') return '太阳'
  if (body === 'Earth') return '地球'
  if (body === 'Moon') return '月亮'
  if (body === 'Mercury') return '水星'
  if (body === 'Venus') return '金星'
  if (body === 'Mars') return '火星'
  if (body === 'Jupiter') return '木星'
  if (body === 'Saturn') return '土星'
  if (body === 'Uranus') return '天王星'
  if (body === 'Neptune') return '海王星'
  return '冥王星'
}

export function planetPairLinearLabel(value: number | undefined): string {
  const distance: number = value ?? 0
  if (distance < 0.1) return (distance * 149597871).toFixed(0) + ' km'
  return distance.toFixed(3) + ' AU'
}

export function hecPointSize(position: HeliocentricPosition): number {
  if (position.isComet) return 9
  if (position.isSelectedMinor) return 10
  if (position.englishName === 'Mercury') return 9
  if (position.englishName === 'Venus' || position.englishName === 'Earth') return 11
  if (position.englishName === 'Mars') return 10
  if (position.englishName === 'Jupiter') return 17
  if (position.englishName === 'Saturn') return 15
  if (position.englishName === 'Uranus' || position.englishName === 'Neptune') return 13
  return 11
}

export function hecDistanceLabel(position: HeliocentricPosition): string {
  return position.distanceAU < 10 ? position.distanceAU.toFixed(3) : position.distanceAU.toFixed(2)
}

export function lunarElongationBarHeight(separation: number | undefined): number {
  return Math.max(1, Math.min(96, (separation ?? 0) / 180 * 96))
}

export function planetTimeSeriesBarHeight(value: number | undefined, min: number, max: number): number {
  return Math.max(1, Math.min(96, ((value ?? min) - min) / (max - min) * 96))
}

export function planetPairBarHeight(value: number | undefined, min: number, max: number): number {
  return Math.max(1, Math.min(96, ((value ?? min) - min) / (max - min) * 96))
}
