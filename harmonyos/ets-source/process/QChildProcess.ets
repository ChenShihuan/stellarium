import ChildProcess from '@ohos.app.ability.ChildProcess';
import QtUtils from '../qability/QtUtils';
import hilog from '@ohos.hilog';
import qpa from 'libqohos.so';
import {LOG_DOMAIN, LOG_TAG} from '../common/QtAppConstants';
import { hasCurrentPrivacyConsent } from '../qability/PrivacyConsent';

export default class QChildProcess extends ChildProcess {
  onStart() {
    if (!hasCurrentPrivacyConsent()) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, '[privacy-gate] blocked Qt child process before current consent');
      return;
    }
    hilog.info(LOG_DOMAIN, LOG_TAG, 'QChildProcess::onStart()');
    qpa.runQtChildProcess({
      modulesFactories: QtUtils.getModulesFactoriesMapForQt(),
    });
  }
}
