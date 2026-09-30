import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit'
import { common, Want } from '@kit.AbilityKit'
import preferences from '@ohos.data.preferences'
import hilog from '@ohos.hilog'

const CARD_STORE = 'sky_instrument_card'
const CARD_SNAPSHOT_KEY = 'almanacSnapshot'
const DOMAIN = 0xD003
const TAG = 'SkyInstrumentForm'

function defaultCardData(): Record<string, string> {
  return {
    'title': '星象仪',
    'subtitle': '二十四节气',
    'summary': '打开应用查看本地天象与节气时间',
    'updatedAt': '打开应用刷新年历'
  }
}

async function readCardData(context: common.FormExtensionContext): Promise<Record<string, string>> {
  const fallback = defaultCardData()
  try {
    const store = await preferences.getPreferences(context, CARD_STORE)
    const raw = await store.get(CARD_SNAPSHOT_KEY, '')
    if (typeof raw !== 'string' || raw.length === 0) return fallback
    const parsed = JSON.parse(raw) as Record<string, string>
    return {
      'title': parsed['title'] ?? fallback['title'],
      'subtitle': parsed['subtitle'] ?? fallback['subtitle'],
      'summary': parsed['summary'] ?? fallback['summary'],
      'updatedAt': parsed['updatedAt'] ?? fallback['updatedAt']
    }
  } catch (error) {
    hilog.warn(DOMAIN, TAG, 'read card snapshot failed: %{public}s', String(error))
    return fallback
  }
}

export default class SkyInstrumentFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = String(want.parameters?.[formInfo.FormParam.IDENTITY_KEY] ?? '')
    if (formId.length > 0) {
      void readCardData(this.context).then((data: Record<string, string>) => {
        return formProvider.updateForm(formId, formBindingData.createFormBindingData(data))
      }).catch((error: Error) => {
        hilog.warn(DOMAIN, TAG, 'initial card update failed: %{public}s', error.message)
      })
    }
    return formBindingData.createFormBindingData(defaultCardData())
  }

  onUpdateForm(formId: string): void {
    void readCardData(this.context).then((data: Record<string, string>) => {
      const bindingData = formBindingData.createFormBindingData(data)
      return formProvider.updateForm(formId, bindingData)
    }).catch((error: Error) => {
      hilog.warn(DOMAIN, TAG, 'update card failed: %{public}s', error.message)
    })
  }

  onRemoveForm(_formId: string): void {
    // No external resource or subscription is created by the card.
  }

  onAcquireFormState(_want: Want): formInfo.FormState {
    return formInfo.FormState.READY
  }
}
