// LX200 望远镜编辑器 / 控制命令行为控制器（STATE-REVIEW §10.2 D9，PLAN §15 D 轨道 D9）。
//
// 原宿主 MainWindowNativeNode 的 12 个望远镜编辑器/控制方法逐字下沉：
//   validateTelescopeEditorStatus / selectTelescopeProfile / beginNewTelescopeProfile /
//   selectTelescopeProtocol / saveTelescopeProfile / deleteTelescopeProfile / testTelescopeConnection /
//   applyLx200Result（私有助手）/ lx200GotoSelected / lx200SyncSelected / lx200Abort /
//   readTelescopePosition。
//
// **不 import NAPI/UI**（§15.7 规则 1）：桥经 CommandPort；状态整体写回 TelescopeStore
//（面板经 @ObjectLink 消费）。live-position 定时器簇早已在 TelescopeStore 自持（§14 B3-4），
// 本控制器只调用其 start/stop/schedule，不自持定时器。实测 12 法均不调 flashHint / refreshState，
// 故不注入 BehaviorHostHooks。
import { I18n } from '../pages/I18n'
import { StellariumBridgeResponse } from '../pages/StellariumTypes'
import {
  TelescopeControlResponse, TelescopeProfilesResponse, TelescopeProfile, TELESCOPE_SIMULATOR_MODEL
} from '../pages/MainWindowModels'
import { telescopeUpdateTime, telescopeErrorText } from '../common/derive/actions'
import { CommandPort } from '../bridge/CommandPort'
import { TelescopeStore } from '../state/TelescopeStore'

export class TelescopeController {
  private port: CommandPort
  private telescopeStore: TelescopeStore

  constructor(port: CommandPort, telescopeStore: TelescopeStore) {
    this.port = port
    this.telescopeStore = telescopeStore
  }

  // 原宿主 validateTelescopeEditorStatus()：模拟器直接给本地状态；其余协议向桥查询端点。
  validateTelescopeEditorStatus(): void {
    if (this.telescopeStore.lx200Protocol === 'simulated') {
      this.telescopeStore.lx200Transport = I18n.t('m_telescope_transport_simulated')
      this.telescopeStore.lx200Scope = I18n.t('m_telescope_scope_offline')
      this.telescopeStore.lx200ConnectionState = 'available'
      return
    }
    this.port.requestInteractive('getTelescopeControl', this.telescopeStore.lx200Host.trim() + '|' + this.telescopeStore.lx200Port.trim(), (result: TelescopeControlResponse) => {
      this.telescopeStore.applyTelescopeEndpointStatus(result)
    })
  }

  // 原宿主 selectTelescopeProfile()：选择档位并回读配置。
  selectTelescopeProfile(slot: number): void {
    if (slot === this.telescopeStore.lx200SelectedSlot && !this.telescopeStore.lx200EditingNew) return
    this.port.requestInteractive('selectTelescopeProfile', slot.toString(), (result: TelescopeProfilesResponse) => {
      if (result.ok === true) {
        this.telescopeStore.applyTelescopeProfiles(result)
        this.validateTelescopeEditorStatus()
      } else {
        this.telescopeStore.lx200Status = result.error ?? I18n.t('m_telescope_load_failed')
      }
    })
  }

  // 原宿主 beginNewTelescopeProfile()：寻找空档位并初始化「新建」编辑器草稿。
  beginNewTelescopeProfile(): void {
    this.telescopeStore.stopTelescopeLivePosition(false)
    const used = new Set<number>(this.telescopeStore.lx200Profiles.map((profile: TelescopeProfile) => profile.slot))
    let slot = 1
    while (slot <= 9 && used.has(slot)) slot += 1
    if (slot > 9) {
      this.telescopeStore.lx200Status = I18n.t('m_telescope_slots_full')
      return
    }
    this.telescopeStore.lx200SelectedSlot = slot
    this.telescopeStore.lx200Name = I18n.format('m_telescope_simulator_name', [slot.toString()]) as string
    this.telescopeStore.lx200Protocol = 'simulated'
    this.telescopeStore.lx200DeviceModel = TELESCOPE_SIMULATOR_MODEL
    this.telescopeStore.lx200Host = ''
    this.telescopeStore.lx200Port = ''
    this.telescopeStore.lx200Equinox = 'J2000'
    this.telescopeStore.lx200CommandDelayMs = 0
    this.telescopeStore.lx200Circles = '1, 2, 4'
    this.telescopeStore.lx200EditingNew = true
    this.telescopeStore.lx200ConnectionState = 'available'
    this.telescopeStore.lx200Position = ''
    this.telescopeStore.lx200PositionUpdatedAt = ''
    this.telescopeStore.lx200PositionUpdateState = 'idle'
    this.validateTelescopeEditorStatus()
  }

  // 原宿主 selectTelescopeProtocol()：切换协议并重置端点草稿。
  selectTelescopeProtocol(protocol: string): void {
    if (protocol === this.telescopeStore.lx200Protocol) return
    this.telescopeStore.stopTelescopeLivePosition(false)
    this.telescopeStore.lx200Protocol = protocol
    this.telescopeStore.lx200Position = ''
    this.telescopeStore.lx200PositionUpdatedAt = ''
    this.telescopeStore.lx200PositionUpdateState = 'idle'
    if (protocol === 'simulated') {
      this.telescopeStore.lx200DeviceModel = TELESCOPE_SIMULATOR_MODEL
      this.telescopeStore.lx200Host = ''
      this.telescopeStore.lx200Port = ''
      this.telescopeStore.lx200ConnectionState = 'available'
      this.telescopeStore.lx200Status = I18n.t('m_telescope_simulator_ready')
    } else {
      this.telescopeStore.lx200DeviceModel = 'Meade LX200 (compatible)'
      this.telescopeStore.lx200Host = '127.0.0.1'
      this.telescopeStore.lx200Port = '4030'
      this.telescopeStore.lx200ConnectionState = 'not_tested'
      this.telescopeStore.lx200Status = I18n.t('m_telescope_not_tested')
    }
    this.validateTelescopeEditorStatus()
  }

  // 原宿主 saveTelescopeProfile()：校验并保存档位。
  saveTelescopeProfile(): void {
    const port = Number(this.telescopeStore.lx200Port.trim())
    const invalidEndpoint = this.telescopeStore.lx200Protocol === 'lx200_tcp' &&
      (this.telescopeStore.lx200Host.trim().length === 0 || !Number.isInteger(port) || port < 1 || port > 65535)
    if (this.telescopeStore.lx200Name.trim().length === 0 || invalidEndpoint) {
      this.telescopeStore.lx200Status = I18n.t('m_telescope_invalid_profile')
      return
    }
    const profile: TelescopeProfile = {
      slot: this.telescopeStore.lx200SelectedSlot,
      name: this.telescopeStore.lx200Name.trim(),
      protocol: this.telescopeStore.lx200Protocol,
      deviceModel: this.telescopeStore.lx200DeviceModel,
      host: this.telescopeStore.lx200Host.trim(),
      port: this.telescopeStore.lx200Protocol === 'simulated' ? 0 : port,
      equinox: this.telescopeStore.lx200Equinox,
      commandDelayMs: this.telescopeStore.lx200CommandDelayMs,
      circles: this.telescopeStore.telescopeCircleValues()
    }
    this.telescopeStore.lx200Busy = true
    this.port.requestInteractive('saveTelescopeProfile', JSON.stringify(profile), (result: TelescopeProfilesResponse) => {
      this.telescopeStore.lx200Busy = false
      if (result.ok !== true) {
        this.telescopeStore.lx200Status = result.error ?? I18n.t('m_telescope_save_failed')
        return
      }
      this.telescopeStore.applyTelescopeProfiles(result)
      this.telescopeStore.lx200Status = I18n.t('m_telescope_saved')
      this.validateTelescopeEditorStatus()
    }, () => { this.telescopeStore.lx200Busy = false })
  }

  // 原宿主 deleteTelescopeProfile()：删除当前档位（新建草稿则改为回读）。
  deleteTelescopeProfile(): void {
    if (this.telescopeStore.lx200EditingNew) {
      this.telescopeStore.loadTelescopeControlStatus()
      return
    }
    this.port.requestInteractive('deleteTelescopeProfile', this.telescopeStore.lx200SelectedSlot.toString(), (result: TelescopeProfilesResponse) => {
      if (result.ok === true) {
        this.telescopeStore.applyTelescopeProfiles(result)
        this.telescopeStore.lx200Status = I18n.t('m_telescope_deleted')
        this.validateTelescopeEditorStatus()
      } else {
        this.telescopeStore.lx200Status = result.error ?? I18n.t('m_telescope_delete_failed')
      }
    })
  }

  // 原宿主 testTelescopeConnection()：测试连接并安排 live-position 轮询。
  testTelescopeConnection(): void {
    if (this.telescopeStore.lx200EditingNew) {
      this.telescopeStore.lx200Status = I18n.t('m_telescope_save_before_test')
      return
    }
    this.telescopeStore.stopTelescopeLivePosition(false)
    this.telescopeStore.lx200Busy = true
    this.telescopeStore.lx200Status = I18n.t('m_telescope_connecting')
    this.port.requestInteractive('testTelescopeConnection', this.telescopeStore.lx200Payload(), (result: TelescopeControlResponse) => {
      this.telescopeStore.lx200Busy = false
      this.telescopeStore.applyTelescopeEndpointStatus(result)
      this.telescopeStore.lx200ConnectionState = result.ok === true ? 'available' : 'unavailable'
      this.telescopeStore.lx200Status = result.ok === true
        ? (result.simulated === true ? I18n.t('m_telescope_simulator_ready') : I18n.t('m_telescope_available'))
        : telescopeErrorText(result, I18n.t('m_telescope_test_failed'))
      this.telescopeStore.scheduleTelescopeLivePosition()
    }, (result: StellariumBridgeResponse) => {
      const response = result as TelescopeControlResponse
      this.telescopeStore.lx200Busy = false
      if (response.state === 'available' || response.state === 'unavailable') this.telescopeStore.lx200ConnectionState = response.state
      this.telescopeStore.lx200Status = telescopeErrorText(response, I18n.t('m_telescope_test_failed'))
      this.telescopeStore.scheduleTelescopeLivePosition()
    })
  }

  // 原宿主 applyLx200Result()：Goto/Sync 回包统一处理（私有助手）。
  private applyLx200Result(result: StellariumBridgeResponse): void {
    const response = result as TelescopeControlResponse
    this.telescopeStore.lx200Busy = false
    if (result.ok === true) {
      this.telescopeStore.lx200ConnectionState = 'available'
      const target = result.target && result.target.length > 0 ? result.target : I18n.t('m_telescope_target_default')
      const mode = result.mode === 'sync' ? I18n.t('m_telescope_mode_sync') : I18n.t('m_telescope_mode_goto')
      const coord = result.ra && result.dec ? ' · ' + result.ra + ' / ' + result.dec : ''
      this.telescopeStore.lx200Status = I18n.format('m_telescope_command_sent', [mode as string, target as string, coord])
      if (result.mode === 'goto') this.telescopeStore.setTelescopeLivePosition(true)
    } else {
      if (response.state === 'available' || response.state === 'unavailable') this.telescopeStore.lx200ConnectionState = response.state
      this.telescopeStore.lx200Status = telescopeErrorText(response, I18n.t('m_telescope_disconnected'))
    }
    this.telescopeStore.scheduleTelescopeLivePosition()
  }

  // 原宿主 lx200GotoSelected/lx200SyncSelected/lx200Abort()：指向/同步/中止当前选中天体。
  lx200GotoSelected(): void {
    if (this.telescopeStore.lx200EditingNew) {
      this.telescopeStore.lx200Status = I18n.t('m_telescope_save_before_control')
      return
    }
    this.telescopeStore.stopTelescopeLivePosition(false)
    this.telescopeStore.lx200Busy = true
    this.telescopeStore.lx200Status = I18n.t('m_telescope_sending_goto')
    this.port.requestInteractive('telescopeLx200GotoSelected', this.telescopeStore.lx200Payload(),
      (result: StellariumBridgeResponse) => this.applyLx200Result(result),
      (result: StellariumBridgeResponse) => this.applyLx200Result(result))
  }

  lx200SyncSelected(): void {
    if (this.telescopeStore.lx200EditingNew) {
      this.telescopeStore.lx200Status = I18n.t('m_telescope_save_before_control')
      return
    }
    this.telescopeStore.stopTelescopeLivePosition(false)
    this.telescopeStore.lx200Busy = true
    this.telescopeStore.lx200Status = I18n.t('m_telescope_sending_sync')
    this.port.requestInteractive('telescopeLx200SyncSelected', this.telescopeStore.lx200Payload(),
      (result: StellariumBridgeResponse) => this.applyLx200Result(result),
      (result: StellariumBridgeResponse) => this.applyLx200Result(result))
  }

  lx200Abort(): void {
    if (this.telescopeStore.lx200EditingNew) {
      this.telescopeStore.lx200Status = I18n.t('m_telescope_save_before_control')
      return
    }
    this.telescopeStore.stopTelescopeLivePosition(false)
    this.telescopeStore.lx200Busy = true
    this.port.requestInteractive('telescopeLx200Abort', this.telescopeStore.lx200Payload(), (result: StellariumBridgeResponse) => {
      const response = result as TelescopeControlResponse
      this.telescopeStore.lx200Busy = false
      if (response.state === 'available' || response.state === 'unavailable') this.telescopeStore.lx200ConnectionState = response.state
      this.telescopeStore.lx200Status = result.ok === true ? I18n.t('m_telescope_stop_sent') :
        telescopeErrorText(response, I18n.t('m_telescope_stop_failed'))
      this.telescopeStore.scheduleTelescopeLivePosition()
    }, (result: StellariumBridgeResponse) => {
      const response = result as TelescopeControlResponse
      this.telescopeStore.lx200Busy = false
      if (response.state === 'available' || response.state === 'unavailable') this.telescopeStore.lx200ConnectionState = response.state
      this.telescopeStore.lx200Status = telescopeErrorText(response, I18n.t('m_telescope_stop_failed'))
      this.telescopeStore.scheduleTelescopeLivePosition()
    })
  }

  // 原宿主 readTelescopePosition()：读取望远镜指向（center=true 时居中屏幕）。
  readTelescopePosition(center: boolean = false): void {
    if (this.telescopeStore.lx200EditingNew) {
      this.telescopeStore.lx200Status = I18n.t('m_telescope_save_before_control')
      return
    }
    this.telescopeStore.stopTelescopeLivePosition(false)
    this.telescopeStore.lx200Busy = true
    this.telescopeStore.lx200Status = center ? I18n.t('m_telescope_centering') : I18n.t('m_telescope_reading_position')
    const command = center ? 'centerScreenOnTelescope' : 'getTelescopePosition'
    this.port.requestInteractive(command, this.telescopeStore.lx200Payload(), (result: TelescopeControlResponse) => {
      this.telescopeStore.lx200Busy = false
      if (result.ok === true) {
        this.telescopeStore.lx200ConnectionState = 'available'
        this.telescopeStore.lx200Position = (result.ra ?? '--:--:--') + ' / ' + (result.dec ?? '--°--:--')
        this.telescopeStore.lx200PositionUpdatedAt = telescopeUpdateTime()
        this.telescopeStore.lx200PositionUpdateState = 'fresh'
        this.telescopeStore.lx200Status = center ? I18n.t('m_telescope_centered') : I18n.t('m_telescope_position_updated')
      } else {
        if (result.state === 'available' || result.state === 'unavailable') this.telescopeStore.lx200ConnectionState = result.state
        this.telescopeStore.lx200Status = telescopeErrorText(result, I18n.t('m_telescope_position_failed'))
      }
      this.telescopeStore.scheduleTelescopeLivePosition()
    }, (result: StellariumBridgeResponse) => {
      const response = result as TelescopeControlResponse
      this.telescopeStore.lx200Busy = false
      if (response.state === 'available' || response.state === 'unavailable') this.telescopeStore.lx200ConnectionState = response.state
      this.telescopeStore.lx200PositionUpdateState = 'error'
      this.telescopeStore.lx200Status = telescopeErrorText(response, I18n.t('m_telescope_position_failed'))
      this.telescopeStore.scheduleTelescopeLivePosition()
    })
  }
}
