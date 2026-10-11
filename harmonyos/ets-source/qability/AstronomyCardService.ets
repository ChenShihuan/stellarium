import { common } from '@kit.AbilityKit'
import { formBindingData, formProvider } from '@kit.FormKit'
import preferences from '@ohos.data.preferences'
import { buildAstronomyCard, normalizeAstronomyCard, CardTonightData } from '../form/AstronomyCardData'

export interface CardPublishResult {
  snapshot: Record<string, string>
  updatedForms: number
  failedForms: number
}

export async function readAstronomyCard(context: common.UIAbilityContext): Promise<Record<string, string>> {
  const store = await preferences.getPreferences(context, 'sky_instrument_card')
  const raw = await store.get('almanacSnapshot', '')
  return normalizeAstronomyCard(typeof raw === 'string' ? raw : '', Date.now())
}

export async function publishAstronomyCard(context: common.UIAbilityContext, tonight: CardTonightData): Promise<CardPublishResult> {
  const snapshot = buildAstronomyCard(tonight, Date.now())
  const store = await preferences.getPreferences(context, 'sky_instrument_card')
  await store.put('almanacSnapshot', JSON.stringify(snapshot))
  await store.flush()
  const result: CardPublishResult = { snapshot: snapshot, updatedForms: 0, failedForms: 0 }
  try {
    const forms = await formProvider.getPublishedRunningFormInfos()
    const reloadKeys: Array<string> = []
    for (const form of forms) {
      if (form.bundleName !== 'com.joinother.skyinstrument') continue
      try {
        await formProvider.updateForm(form.formId, formBindingData.createFormBindingData(snapshot))
        result.updatedForms++
        const reloadKey = form.moduleName + '|' + form.abilityName + '|' + form.formName
        if (!reloadKeys.includes(reloadKey)) reloadKeys.push(reloadKey)
      } catch (_) {
        result.failedForms++
      }
    }
    for (const reloadKey of reloadKeys) {
      const parts = reloadKey.split('|')
      if (parts.length !== 3) continue
      try {
        await formProvider.reloadForms(context, parts[0], parts[1], parts[2])
      } catch (_) {
      }
    }
  } catch (_) {
    result.failedForms++
  }
  return result
}
