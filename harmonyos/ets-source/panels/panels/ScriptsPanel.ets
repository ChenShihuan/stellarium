import { I18n } from '../../pages/I18n'
import { RecordingEntry } from '../../pages/MainWindowModels'
import { ToolsStore } from '../../state/ToolsStore'
import { UI_RADIUS_CONTROL } from '../../common/ui/UiTokens'
import { GuideLibrary } from '../guide/GuideLibrary'

// 脚本面板（原宿主 panelContent() 的 `scripts` 分支，分支体原样下沉）。
//
// 判定条件 `activePanel === 'scripts'` 留在宿主。脚本列表 / 回放 / 录制 / 屏幕
// MP4 / 帧序列导出的全部状态由宿主 @State 以 @Prop 传入（宿主仍是写方），
// 所有动作回注宿主；录制开关读 ToolsStore（@ObjectLink，实时刷新）。
// scriptZh / scriptDesc / scriptMetaLine / scriptSourceLine 因设置页也在用，
// 仍留宿主，以函数成员回注。
// 成员名避开 CustomComponent 属性方法（分隔线颜色用 lineColor，不用 borderColor）。

@Component
export struct ScriptsPanel {
  @ObjectLink tools: ToolsStore
  @Prop guideSessionActive: boolean
  @Prop scriptImporting: boolean
  @Prop scriptList: string[]
  @Prop scriptLaunching: boolean
  @Prop scriptLaunchingName: string
  @Prop recordCount: number
  @Prop recordMsg: string
  @Prop recordName: string
  @Prop recordings: RecordingEntry[]
  @Prop screenVideoRecording: boolean
  @Prop screenCaptureFinalizing: boolean
  @Prop screenVideoStatus: string
  @Prop screenVideoBytes: number
  @Prop screenVideoPath: string
  @Prop videoFps: string
  @Prop videoDuration: string
  @Prop videoRecording: boolean
  @Prop videoFrameCount: number
  @Prop videoMaxFrames: number
  @Prop videoFailedFrames: number
  @Prop videoDir: string
  @Prop videoArchivePath: string
  @Prop textColor: string
  @Prop subColor: string
  @Prop accentColor: string
  @Prop panelColor: string
  @Prop lineColor: string
  scriptZh: (filename: string) => string = (filename: string) => filename
  scriptDesc: (filename: string) => string = () => ''
  scriptMetaLine: (filename: string) => string = () => ''
  scriptSourceLine: (filename: string) => string = () => ''
  onStartGuide: (id: string) => void = () => {}
  onStopPlayback: () => void = () => {}
  onImportScript: () => void = () => {}
  onPlayScript: (name: string) => void = () => {}
  onToggleRecording: () => void = () => {}
  onSaveRecording: () => void = () => {}
  onSetRecordName: (value: string) => void = () => {}
  onPlayRecording: (file: string) => void = () => {}
  onLoadRecording: (file: string, name: string) => void = () => {}
  onShareRecording: (rec: RecordingEntry, idx: number) => void = () => {}
  onDeleteRecording: (file: string) => void = () => {}
  onToggleScreenVideo: () => void = () => {}
  onSaveScreenVideoToGallery: (result: SaveButtonOnClickResult) => void = () => {}
  onShareScreenVideo: () => void = () => {}
  onSaveScreenVideoAs: () => void = () => {}
  onSetVideoFps: (value: string) => void = () => {}
  onSetVideoDuration: (value: string) => void = () => {}
  onToggleVideoRecording: () => void = () => {}
  onShareVideoArchive: () => void = () => {}
  onExportVideoArchive: () => void = () => {}

  build() {
    Scroll() {
      Column({ space: 10 }) {
        GuideLibrary({
          textColor: this.textColor, subColor: this.subColor, cardBg: this.panelColor,
          sessionActive: this.guideSessionActive,
          onStartGuide: (id: string) => { this.onStartGuide(id) }
        })
        // ===== 脚本播放列表 =====
        Text(I18n.t('i0123')).fontSize(15).fontColor(this.textColor).width('100%').margin({ top: 4 })
        Row({ space: 8 }) {
          Button(I18n.t('i0252')).fontSize(11).fontColor('#FFFFFF').backgroundColor('#C0392B')
            .borderRadius(UI_RADIUS_CONTROL).height(30).padding({ left: 10, right: 10 })
            .onClick(() => { this.onStopPlayback() })
          Button(I18n.t('btn_import_script')).fontSize(11).fontColor(this.textColor).backgroundColor(this.panelColor)
            .borderRadius(UI_RADIUS_CONTROL).height(30).padding({ left: 10, right: 10 })
            .enabled(!this.scriptImporting)
            .onClick(() => { this.onImportScript() })
          if (this.scriptImporting) {
            LoadingProgress().width(16).height(16).color(this.accentColor)
          }
        }.width('100%').padding({ left: 6, right: 6 })
        if (this.scriptList.length === 0) {
          Text(I18n.t('msg_no_scripts')).fontSize(11).fontColor('#99FFFFFF').width('100%').padding({ left: 6 })
        }
        if (this.scriptLaunching) {
          Row({ space: 6 }) {
            LoadingProgress().width(16).height(16).color(this.accentColor)
            Text(I18n.format('script_starting_named', [this.scriptZh(this.scriptLaunchingName)])).fontSize(10).fontColor(this.subColor)
          }.width('100%').padding({ left: 6, right: 6, bottom: 2 })
        }
        Column({ space: 2 }) {
            ForEach(this.scriptList, (s: string) => {
              Column({ space: 0 }) {
                // 第一行：中文名 + 播放图标
                Row() {
                  Text(this.scriptZh(s)).fontSize(11).fontColor(this.textColor)
                    .fontWeight(FontWeight.Medium).layoutWeight(1)
                  Text('▶').fontSize(9).fontColor('#7FD0FF')
                }
                .height(28).width('100%').padding({ left: 10, right: 10 })
                // 第二行：简短描述
                if (this.scriptDesc(s)) {
                  Text(this.scriptDesc(s))
                    .fontSize(8).fontColor('#77FFFFFF').width('100%')
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .padding({ left: 10, right: 10, bottom: 3 })
                }
                if (this.scriptMetaLine(s).length > 0) {
                  Text(this.scriptMetaLine(s))
                    .fontSize(8).fontColor('#66FFFFFF').width('100%').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .padding({ left: 10, right: 10, bottom: 3 })
                }
                if (this.scriptSourceLine(s).length > 0) {
                  Text(this.scriptSourceLine(s)).fontSize(8).fontColor('#55FFFFFF').width('100%').maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis }).padding({ left: 10, right: 10, bottom: 3 })
                }
            }
            .width('100%')
            .backgroundColor(this.panelColor)
            .borderRadius(UI_RADIUS_CONTROL)
            .opacity(this.scriptLaunching && this.scriptLaunchingName !== s ? 0.55 : 1)
            .hitTestBehavior(HitTestMode.Default)
            .onClick(() => { this.onPlayScript(s) })
          }, (s: string, index: number) => s)
        }
          .id('scripts-list-scroll')
          .width('100%')
          .hitTestBehavior(HitTestMode.Default)

        Row().width('100%').height(0.5).backgroundColor(this.lineColor).margin({ top: 6, bottom: 6 })

        // ===== 录制操作 =====
        Text(I18n.t('c_script_record')).fontSize(15).fontColor(this.textColor).width('100%').margin({ top: 4 })
        Text(I18n.t('m_script_record_desc'))
          .fontSize(11).fontColor('#99FFFFFF').width('100%').padding({ left: 4, right: 4 })

        Row({ space: 10 }) {
          Button(this.tools.recording ? I18n.t('btn_stop_recording') : I18n.t('btn_start_recording'))
            .fontSize(13).fontColor('#FFFFFF').backgroundColor(this.tools.recording ? '#C0392B' : '#2E7D32')
            .borderRadius(UI_RADIUS_CONTROL).height(36).padding({ left: 16, right: 16 })
            .onClick(() => { this.onToggleRecording() })
          if (this.tools.recording) {
            Text(I18n.t('c_recording')).fontSize(12).fontColor('#FF6B6B')
          }
        }.width('100%').padding({ left: 6, right: 6 })

        Text(I18n.format('script_recorded_commands', [this.recordCount.toString()]) + (this.recordMsg.length > 0 ? ' · ' + this.recordMsg : ''))
          .fontSize(11).fontColor('#99FFFFFF').width('100%').padding({ left: 6, right: 6 })

        Row({ space: 8 }) {
          TextInput({ placeholder: I18n.t('c_record_name_hint'), text: this.recordName })
            .fontSize(12).fontColor(this.textColor)
            .backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL).layoutWeight(1).height(36)
            .onChange((v: string) => { this.onSetRecordName(v) })
          Button(I18n.t('btn_save_record'))
            .fontSize(12).fontColor('#FFFFFF').backgroundColor(this.recordCount > 0 ? '#5B93BF' : '#555555')
            .borderRadius(UI_RADIUS_CONTROL).height(36).padding({ left: 12, right: 12 })
            .enabled(this.recordCount > 0)
            .onClick(() => { this.onSaveRecording() })
        }.width('100%').padding({ left: 6, right: 6 })

        Row().width('100%').height(0.5).backgroundColor(this.lineColor).margin({ top: 6, bottom: 6 })

        Text(I18n.t('c_saved_recordings')).fontSize(13).fontColor(this.textColor).width('100%').padding({ left: 6 })
        if (this.recordings.length === 0) {
          Text(I18n.t('m_no_recordings')).fontSize(11).fontColor('#99FFFFFF').width('100%').padding({ left: 6 })
        }
        ForEach(this.recordings, (rec: RecordingEntry, idx: number) => {
          Column({ space: 4 }) {
            Row({ space: 8 }) {
              Column() {
                Text(rec.name).fontSize(13).fontColor(this.textColor).width('100%')
                Text((rec.created.length > 0 ? rec.created + ' · ' : '') + rec.count + ' 条命令')
                  .fontSize(10).fontColor('#99FFFFFF').width('100%')
              }.layoutWeight(1)
              Button(I18n.t('btn_playback'))
                .fontSize(11).fontColor('#FFFFFF').backgroundColor('#5B93BF')
                .borderRadius(UI_RADIUS_CONTROL).height(30).padding({ left: 12, right: 12 })
                .onClick(() => { this.onPlayRecording(rec.file) })
              Button('加载')
                .fontSize(11).fontColor('#FFFFFF').backgroundColor('#7D3C98')
                .borderRadius(UI_RADIUS_CONTROL).height(30).padding({ left: 12, right: 12 })
                .onClick(() => { this.onLoadRecording(rec.file, rec.name) })
              if ((rec.path ?? '').length > 0) {
                Button('分享')
                  .id('recording-share-' + idx.toString())
                  .fontSize(11).fontColor('#FFFFFF').backgroundColor('rgba(68,136,178,0.72)')
                  .borderRadius(UI_RADIUS_CONTROL).height(30).padding({ left: 10, right: 10 })
                  .onClick(() => {
                    this.onShareRecording(rec, idx)
                  })
              }
              Button(I18n.t('btn_delete'))
                .fontSize(11).fontColor('#FFFFFF').backgroundColor('#C0392B')
                .borderRadius(UI_RADIUS_CONTROL).height(30).padding({ left: 12, right: 12 })
                .onClick(() => { this.onDeleteRecording(rec.file) })
            }.width('100%')
          }.width('100%').padding({ left: 8, right: 8, top: 6, bottom: 6 })
            .backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL)
        }, (item: RecordingEntry, idx: number) => item.file)

        // ===== 直接屏幕录制 MP4 =====
        Row().width('100%').height(0.5).backgroundColor(this.lineColor).margin({ top: 6, bottom: 6 })
        Text('屏幕视频（MP4）').fontSize(13).fontColor(this.textColor).width('100%').padding({ left: 6 })
        Text('录制屏幕中的星图与交互界面；系统会在开始前显示录屏授权确认。默认不录麦克风。')
          .fontSize(11).fontColor('#99FFFFFF').width('100%').padding({ left: 6, right: 6 }).maxLines(3)
        Row({ space: 8 }) {
          Button(this.screenVideoRecording ? '停止并生成 MP4' : '开始录制 MP4')
            .fontSize(12).fontColor('#FFFFFF')
            .backgroundColor(this.screenVideoRecording ? '#C0392B' : '#2E7D32')
            .borderRadius(UI_RADIUS_CONTROL).height(36).padding({ left: 14, right: 14 })
            .onClick(() => {
              this.onToggleScreenVideo()
            })
          if (this.screenCaptureFinalizing) {
            LoadingProgress().width(18).height(18).color(this.accentColor)
          }
          Text(this.screenVideoStatus).fontSize(10)
            .fontColor(this.screenVideoRecording ? '#FF9A9A' : this.subColor)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        }.width('100%').padding({ left: 6, right: 6 })
        if (this.screenVideoBytes > 0 && this.screenVideoPath.length > 0) {
          Row({ space: 8 }) {
            SaveButton({ icon: SaveIconStyle.LINES, text: SaveDescription.SAVE_TO_GALLERY,
              buttonType: ButtonType.Capsule })
              .height(34)
              .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {
                this.onSaveScreenVideoToGallery(result)
              })
            Button('分享')
              .id('screen-video-share')
              .fontSize(11).fontColor('#FFFFFF').backgroundColor('rgba(68,136,178,0.72)')
              .borderRadius(UI_RADIUS_CONTROL).height(34).padding({ left: 12, right: 12 })
              .onClick(() => {
                this.onShareScreenVideo()
              })
            Button('另存为')
              .fontSize(11).fontColor(this.textColor).backgroundColor(this.panelColor)
              .borderRadius(UI_RADIUS_CONTROL).height(34).padding({ left: 12, right: 12 })
              .onClick(() => { this.onSaveScreenVideoAs() })
          }.width('100%').padding({ left: 6, right: 6 })
        }

        // ===== 视频录制（帧序列方案，纯星图高质量导出）=====
        Row().width('100%').height(0.5).backgroundColor(this.lineColor).margin({ top: 6, bottom: 6 })
        Text(I18n.t('c_video_frames')).fontSize(13).fontColor(this.textColor).width('100%').padding({ left: 6 })
        Text(I18n.t('m_video_frames_desc'))
          .fontSize(11).fontColor('#99FFFFFF').width('100%').padding({ left: 4, right: 4 })

        Row({ space: 8 }) {
          Column({ space: 2 }) {
            Text(I18n.t('c_fps')).fontSize(10).fontColor('#99FFFFFF')
            TextInput({ placeholder: '1', text: this.videoFps })
              .fontSize(12).fontColor(this.textColor)
              .backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL).width(72).height(34)
              .onChange((v: string) => { this.onSetVideoFps(v) })
          }.width(72)
          Column({ space: 2 }) {
            Text(I18n.t('c_duration_sec')).fontSize(10).fontColor('#99FFFFFF')
            TextInput({ placeholder: '5', text: this.videoDuration })
              .fontSize(12).fontColor(this.textColor)
              .backgroundColor(this.panelColor).borderRadius(UI_RADIUS_CONTROL).width(72).height(34)
              .onChange((v: string) => { this.onSetVideoDuration(v) })
          }.width(72)
          Button(this.videoRecording ? '停止录制' : '开始录制')
            .fontSize(13).fontColor('#FFFFFF').backgroundColor(this.videoRecording ? '#C0392B' : '#2E7D32')
            .borderRadius(UI_RADIUS_CONTROL).height(36).layoutWeight(1).padding({ left: 16, right: 16 })
            .onClick(() => { this.onToggleVideoRecording() })
        }.width('100%').padding({ left: 6, right: 6 })

        if (this.videoRecording || this.videoFrameCount > 0) {
          Row({ space: 10 }) {
            if (this.videoRecording) {
              Text(I18n.t('c_recording')).fontSize(12).fontColor('#FF6B6B')
            }
            Text(I18n.t('c_captured') + ' ' + this.videoFrameCount + ' / ' + this.videoMaxFrames + ' ' + I18n.t('c_frames'))
              .fontSize(11).fontColor('#99FFFFFF')
            if (this.videoFailedFrames > 0) {
              Text('失败 ' + this.videoFailedFrames).fontSize(10).fontColor('#FFB38A')
            }
          }.width('100%').padding({ left: 6, right: 6 })
        }
        if (this.videoDir.length > 0) {
          Text('存放目录：' + this.videoDir)
            .fontSize(10).fontColor('#99FFFFFF').width('100%').padding({ left: 6, right: 6 })
        }
        if (this.videoArchivePath.length > 0) {
          Row({ space: 8 }) {
            Button('分享帧包')
              .id('video-frames-share')
              .fontSize(11).fontColor('#FFFFFF').backgroundColor('rgba(68,136,178,0.72)')
              .borderRadius(UI_RADIUS_CONTROL).height(34).padding({ left: 12, right: 12 })
              .onClick(() => {
                this.onShareVideoArchive()
              })
            Button('导出 ZIP')
              .fontSize(11).fontColor(this.textColor).backgroundColor(this.panelColor)
              .borderRadius(UI_RADIUS_CONTROL).height(34).padding({ left: 12, right: 12 })
              .onClick(() => { this.onExportVideoArchive() })
          }.width('100%').padding({ left: 6, right: 6, bottom: 8 })
        }
      }.width('100%').padding({ left: 8, right: 8, top: 8, bottom: 16 })
    }.width('100%').layoutWeight(1).scrollBar(BarState.Auto).scrollBarWidth(4).scrollBarColor('#33FFFFFF')
  }
}
