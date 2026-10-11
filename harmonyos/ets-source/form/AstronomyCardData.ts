export interface CardMoonData {
  phaseName?: string
  illumination?: number
  age?: number
  rise?: string
  set?: string
}

export interface CardPlanetData {
  name?: string
  visible?: boolean
}

export interface CardShowerData {
  name?: string
  zhr?: number
}

export interface CardTonightData {
  date?: string
  moon?: CardMoonData
  sun?: CardSunData
  planets?: CardPlanetData[]
  meteorShowers?: CardShowerData[]
  satellites?: CardSatelliteData
}

export interface CardSunData {
  rise?: string
  set?: string
  astroTwilightEnd?: string
  astroTwilightStart?: string
  darkWindowHours?: number
}

export interface CardSatelliteData {
  count?: number
  enabled?: boolean
}

export function cardClock(value: string | undefined): string {
  const match = (value ?? '').match(/T(\d{2}:\d{2})/)
  return match === null ? '—' : match[1]
}

export function defaultAstronomyCard(): Record<string, string> {
  return {
    schemaVersion: '3', title: '星象仪', subtitle: '本地观测摘要', summary: '卡片已就绪 · 使用最近星历',
    moonSummary: '最近星历', moonPhase: '今夜月相', moonIllumination: '-1', moonAge: '0',
    planetSummary: '今晚行星', planetNames: '本地星体目录已就绪', meteorSummary: '流星雨活动',
    meteorRate: '—', satelliteSummary: '卫星目录已就绪', observationSummary: '暗夜观测',
    darkStart: '—', darkEnd: '—', moonRise: '—', moonSet: '—', sunRise: '—', sunSet: '—',
    updatedAt: '最近一次本地计算', calculatedAt: '0', dataDate: '', dataStatus: '本地快照'
  }
}

export function buildAstronomyCard(tonight: CardTonightData, now: number): Record<string, string> {
  const data = defaultAstronomyCard()
  const moon = tonight.moon
  const sun = tonight.sun
  const planets = tonight.planets ?? []
  const visible = planets.filter((planet: CardPlanetData) => planet.visible === true)
  const showers = (tonight.meteorShowers ?? []).slice().sort((first: CardShowerData, second: CardShowerData) =>
    (second.zhr ?? 0) - (first.zhr ?? 0))
  const illumination = moon?.illumination
  data.moonPhase = moon?.phaseName ?? '月相待计算'
  data.moonIllumination = illumination !== undefined && Number.isFinite(illumination)
    ? String(Math.max(0, Math.min(100, illumination))) : '-1'
  data.moonAge = String(moon?.age ?? 0)
  data.moonSummary = illumination !== undefined && Number.isFinite(illumination)
    ? String(Math.round(Math.max(0, Math.min(100, illumination)))) + '% 照明' : '待计算'
  data.planetSummary = planets.length > 0 ? String(visible.length) + ' 颗在地平线上' : '待计算'
  data.planetNames = visible.map((planet: CardPlanetData) => planet.name ?? '').filter((name: string) => name.length > 0).join(' · ') || '当前无行星在地平线上'
  data.meteorSummary = showers.length > 0 ? showers[0].name ?? '活动流星雨' : '无活动数据'
  data.meteorRate = showers.length > 0 && showers[0].zhr !== undefined ? 'ZHR ' + String(showers[0].zhr) : '—'
  data.satelliteSummary = tonight.satellites?.enabled === true ? String(tonight.satellites.count ?? 0) + ' 颗本地卫星' : '目录未启用'
  const darkHours = sun?.darkWindowHours
  data.observationSummary = darkHours !== undefined && Number.isFinite(darkHours) && darkHours > 0
    ? (Math.round(darkHours * 10) / 10).toFixed(1) + ' 小时暗夜' : '无完整天文暗夜'
  data.darkStart = cardClock(sun?.astroTwilightEnd)
  data.darkEnd = cardClock(sun?.astroTwilightStart)
  data.sunRise = cardClock(sun?.rise)
  data.sunSet = cardClock(sun?.set)
  data.moonRise = cardClock(moon?.rise)
  data.moonSet = cardClock(moon?.set)
  data.dataDate = (tonight.date ?? '').slice(0, 10)
  data.subtitle = '观星手札 · ' + data.dataDate
  data.summary = data.darkStart + ' – ' + data.darkEnd + '  天文暗夜'
  data.calculatedAt = String(now)
  data.dataStatus = '本地星历'
  const updated = new Date(now)
  data.updatedAt = String(updated.getHours()).padStart(2, '0') + ':' + String(updated.getMinutes()).padStart(2, '0') + ' 更新'
  return data
}

export function normalizeAstronomyCard(raw: string, now: number): Record<string, string> {
  const fallback = defaultAstronomyCard()
  try {
    const parsed = JSON.parse(raw) as Record<string, string>
    if (parsed === null || parsed.schemaVersion !== '3') return fallback
    for (const key of Object.keys(fallback)) {
      if (typeof parsed[key] === 'string') fallback[key] = parsed[key].slice(0, 200)
    }
    const calculatedAt = Number(fallback.calculatedAt)
    if (!Number.isFinite(calculatedAt) || calculatedAt <= 0 || now - calculatedAt > 6 * 60 * 60 * 1000 || calculatedAt > now + 60000) {
      fallback.dataStatus = '旧快照'
      fallback.updatedAt = '最近数据 · 待更新'
    }
    return fallback
  } catch (_) {
    return fallback
  }
}

export function moonSilhouette(size: number, illumination: number, age: number): string {
  const fraction = Math.max(0, Math.min(100, illumination)) / 100
  const radius = size * 0.39
  const center = size / 2
  const terminator = Math.max(0.02, Math.abs(2 * fraction - 1)) * radius
  const waxing = age <= 14.765
  const outerSweep = waxing ? 1 : 0
  const innerSweep = waxing ? 0 : 1
  const outerArc = 'A ' + radius + ' ' + radius + ' 0 0 ' + outerSweep + ' ' + center + ' ' + (center + radius)
  const innerArc = 'A ' + terminator + ' ' + radius + ' 0 0 ' + innerSweep + ' ' + center + ' ' + (center - radius)
  return 'M ' + center + ' ' + (center - radius) + ' ' + outerArc + ' ' + innerArc + ' Z'
}
