import type common from '@ohos.app.ability.common';
import { privacyManager } from '@kit.AppGalleryKit';
import hilog from '@ohos.hilog';
import { LOG_DOMAIN, LOG_TAG } from '../common/QtAppConstants';
import { BusinessError } from '@kit.BasicServicesKit';

export interface PrivacyConsentResult {
  accepted: boolean;
  dialogShown: boolean;
  errorCode?: number;
}

export function hasCurrentPrivacyConsent(): boolean {
  try {
    const management = privacyManager.getAppPrivacyMgmtInfo();
    return allHostedAgreementsAccepted(management, privacyManager.getAppPrivacyResult());
  } catch (_) {
    return false;
  }
}

function allHostedAgreementsAccepted(management: privacyManager.AppPrivacyMgmtInfo,
  results: privacyManager.AppPrivacyResult[]): boolean {
  if (management.type !== privacyManager.AppPrivacyMgmtType.FULL_MODE ||
    !management.privacyInfo.some((link) => link.type === privacyManager.AppPrivacyLinkType.PRIVACY_STATEMENT_LINK)) return false;
  return management.privacyInfo.every((link) => {
    let resultType: privacyManager.AppPrivacyType;
    if (link.type === privacyManager.AppPrivacyLinkType.PRIVACY_STATEMENT_LINK) {
      resultType = privacyManager.AppPrivacyType.PRIVACY_AGREEMENT;
    } else if (link.type === privacyManager.AppPrivacyLinkType.USER_AGREEMENT_LINK) {
      resultType = privacyManager.AppPrivacyType.USER_AGREEMENT;
    } else {
      return false;
    }
    const matching = results.filter((result) => result.type === resultType &&
      result.id === link.id && result.versionCode === link.versionCode);
    return matching.length > 0 && matching.every((result) =>
      result.result === privacyManager.AppPrivacyResultType.FULL_MODE_AGREED);
  });
}

let pendingConsentRequest: Promise<PrivacyConsentResult> | undefined = undefined;

export function requestPrivacyConsent(
  context: common.UIAbilityContext,
): Promise<PrivacyConsentResult> {
  if (pendingConsentRequest !== undefined) {
    hilog.info(LOG_DOMAIN, LOG_TAG, '[privacy-probe] phase=dialog-request-joined');
    return pendingConsentRequest;
  }
  pendingConsentRequest = performPrivacyConsentRequest(context).finally(() => {
    pendingConsentRequest = undefined;
  });
  return pendingConsentRequest;
}

async function performPrivacyConsentRequest(
  context: common.UIAbilityContext,
): Promise<PrivacyConsentResult> {
  try {
    hilog.info(LOG_DOMAIN, LOG_TAG, '[privacy-probe] phase=management-query-start');
    const management = privacyManager.getAppPrivacyMgmtInfo();
    hilog.info(LOG_DOMAIN, LOG_TAG,
      `[privacy-probe] phase=management-query-finish; type=${management.type}; linkCount=${management.privacyInfo.length}`);
    if (management.type !== privacyManager.AppPrivacyMgmtType.FULL_MODE || management.privacyInfo.length === 0) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'Privacy Manager has no AppGallery configuration; Qt startup remains blocked');
      return { accepted: false, dialogShown: false, errorCode: 1006700003 };
    }

    const privacyStatement = management.privacyInfo.find((item) =>
      item.type === privacyManager.AppPrivacyLinkType.PRIVACY_STATEMENT_LINK,
    );
    if (privacyStatement === undefined) {
      return { accepted: false, dialogShown: false, errorCode: 1006700003 };
    }
    hilog.info(LOG_DOMAIN, LOG_TAG,
      `[privacy-probe] phase=result-query-start; statementConfigured=${privacyStatement !== undefined}`);
    const privacyResults = privacyManager.getAppPrivacyResult();
    hilog.info(LOG_DOMAIN, LOG_TAG,
      `[privacy-probe] phase=result-query-finish; resultCount=${privacyResults.length}`);
    const accepted = allHostedAgreementsAccepted(management, privacyResults);
    if (accepted) {
      hilog.info(LOG_DOMAIN, LOG_TAG, 'Privacy Manager reports the current privacy statement is already accepted');
      return { accepted: true, dialogShown: false };
    }

    hilog.info(LOG_DOMAIN, LOG_TAG, '[privacy-probe] phase=dialog-request-start');
    const consent = await privacyManager.requestAppPrivacyConsent(context);
    hilog.info(LOG_DOMAIN, LOG_TAG,
      `[privacy-probe] phase=dialog-request-finish; resultCount=${consent.results.length}`);
    const acceptedAfterRequest = allHostedAgreementsAccepted(management, consent.results) && hasCurrentPrivacyConsent();
    return { accepted: acceptedAfterRequest, dialogShown: true };
  } catch (err) {
    hilog.error(LOG_DOMAIN, LOG_TAG, `Privacy Manager request failed; Qt startup remains blocked: ${JSON.stringify(err)}`);
    const code = (err as BusinessError)?.code;
    return { accepted: false, dialogShown: false, errorCode: typeof code === 'number' && Number.isFinite(code) ? code : -1 };
  }
}
