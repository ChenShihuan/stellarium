import { AstronomyCardSurface } from './AstronomyCardSurface'

@Entry
@ComponentV2
struct SkyInstrumentCompactCard {
  @Provider() moonPhase: string = '今夜月相'
  @Provider() moonIllumination: string = '-1'
  @Provider() moonAge: string = '0'
  @Provider() moonSummary: string = '最近星历'
  @Provider() planetSummary: string = '今晚行星'
  @Provider() planetNames: string = '本地星体目录已就绪'
  @Provider() meteorSummary: string = '流星雨活动'
  @Provider() meteorRate: string = '—'
  @Provider() satelliteSummary: string = '卫星目录已就绪'
  @Provider() observationSummary: string = '暗夜观测'
  @Provider() darkStart: string = '—'
  @Provider() darkEnd: string = '—'
  @Provider() sunRise: string = '—'
  @Provider() sunSet: string = '—'
  @Provider() moonRise: string = '—'
  @Provider() moonSet: string = '—'
  @Provider() dataDate: string = ''
  @Provider() dataStatus: string = '本地快照'
  @Provider() updatedAt: string = '最近一次本地计算'

  build() {
    Column() { AstronomyCardSurface({ kind: 'compact' }) }
  }
}
