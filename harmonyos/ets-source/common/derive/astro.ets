// Astronomy display/derivation helpers.
// Migrated verbatim from pages/MainWindowNativeNode.ets (plan §14.2, track A1-2).
// These are pure, stateless file-level functions: no host-field access, no IO,
// no store/UI imports. They only depend on their arguments, the shared
// HeliocentricPosition type, and the static HELIOCENTRIC_PLANET_ORBITS table.

import { HeliocentricPosition } from '../../pages/StellariumTypes'
import { HELIOCENTRIC_PLANET_ORBITS } from '../../pages/MainWindowModels'

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
