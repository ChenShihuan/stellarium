import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const source = read('harmonyos/ets-source/pages/MainWindowNativeNode.ets');
const native = read('src/StelMainView.cpp');
const catalog = read('src/StelOhosCommandCatalog.hpp');
const i18n = read('harmonyos/ets-source/pages/I18n.ets');
const guide = read('docs/harmonyos/PC-TOUCHPAD-AND-KEYBOARD-GUIDE.md');

for (const token of [
  'event.axisPinch',
  'AxisType.PINCH_AXIS',
  "callNativeFire('zoomBy'",
  "'|1|'",
  "callNativeFire('endPinch'",
  'event.scrollStep !== undefined',
  "callNativeFire('zoomStep'",
  "callNativeFire('panBy'"
]) {
  assert.ok(source.includes(token), `${token} missing from touchpad input path`);
}

for (const token of ['zoomBy', 'endPinch', 'zoomStep']) {
  assert.match(native, new RegExp(`commandName == "${token}"`), `${token} missing from native bridge`);
  assert.match(catalog, new RegExp(`\\b${token}\\b`), `${token} missing from command catalog`);
}

for (const token of [
  'settings_view_input_guide_title',
  'settings_view_input_guide_touchpad',
  'settings_view_input_guide_mouse',
  'settings_view_input_guide_keyboard'
]) {
  assert.match(i18n, new RegExp(`['"]${token}['"]`), `${token} missing from localized guide`);
}

for (const token of ['双指滑动', '双指捏合', 'zoomBy', 'endPinch', '不能伪造']) {
  assert.match(guide, new RegExp(token), `${token} missing from touchpad guide`);
}

console.log('HarmonyOS touchpad and keyboard contract passed.');
