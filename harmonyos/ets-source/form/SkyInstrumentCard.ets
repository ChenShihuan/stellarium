let skyInstrumentCardStorage = new LocalStorage()

@Entry(skyInstrumentCardStorage)
@Component
struct SkyInstrumentCard {
  @LocalStorageProp('title') cardTitle: string = '星象仪'
  @LocalStorageProp('subtitle') cardSubtitle: string = '二十四节气'
  @LocalStorageProp('summary') cardSummary: string = '打开应用查看本地天象与节气时间'
  @LocalStorageProp('updatedAt') cardUpdatedAt: string = '打开应用刷新年历'

  build() {
    Button() {
      Column({ space: 6 }) {
        Text(this.cardTitle)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F2F6FF')
        Text(this.cardSubtitle)
          .fontSize(14)
          .fontColor('#A9C9E8')
        Text(this.cardSummary)
          .fontSize(12)
          .fontColor('#C5D4E4')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.cardUpdatedAt)
          .fontSize(10)
          .fontColor('#7890A8')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 16 })
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#101C2D')
    }
    .width('100%')
    .height('100%')
    .borderRadius(24)
    .backgroundColor('#101C2D')
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        bundleName: 'com.joinother.skyinstrument',
        moduleName: 'entry',
        abilityName: 'QAbility',
        params: { panel: 'astro', tab: '8' }
      })
    })
  }
}
