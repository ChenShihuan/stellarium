import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const source = fs.readFileSync(path.join(root, 'harmonyos/ets-source/pages/MainWindowNativeNode.ets'), 'utf8');

for (const token of [
  '@State private gyroscopePending: boolean = false',
  '@State private gyroscopePendingTarget: boolean = false',
  'private requestGyroscopeToggle(enabled: boolean): void',
  'private gyroscopeVisualEnabled(): boolean',
  'private gyroIndicatorColor(): string',
  "this.flashHint(enabled ? I18n.t('m_gyro_listening') : I18n.t('m_gyro_off'))",
  "this.requestGyroscopeToggle(!this.gyroscopeVisualEnabled())",
  'if (icon === \'gyro\')',
  'this.gyroscopePending = false'
]) {
  assert.ok(source.includes(token), `${token} missing from gyro quick-control path`);
}

assert.ok(
  source.indexOf('this.requestGyroscopeToggle(!this.gyroscopeVisualEnabled())') <
    source.indexOf('private handleCompactTopQuickTouch'),
  'compact quick control must route through the guarded toggle helper'
);
assert.ok(source.includes("hilog.info(0x0000, 'StellariumArkUI', '[gyro-ui] duplicate tap ignored')"));

console.log('HarmonyOS gyro quick-control feedback contract passed.');
