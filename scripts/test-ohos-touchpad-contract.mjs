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
  'typeof event.scrollStep',
  'axisPanActive',
  'finishAxisPan',
  "callNativeFire('startPanInertia'",
  "callNativeFire('zoomStep'",
  "callNativeFire('panBy'",
  'getModifierKeyState',
  "callInteractive('sendKey'",
  'keyboardToken'
]) {
  assert.ok(source.includes(token), `${token} missing from touchpad input path`);
}

for (const token of ['zoomBy', 'endPinch', 'zoomStep', 'startPanInertia']) {
  assert.match(native, new RegExp(`commandName == "${token}"`), `${token} missing from native bridge`);
  assert.match(catalog, new RegExp(`\\b${token}\\b`), `${token} missing from command catalog`);
}

for (const token of ['getKeyboardShortcuts', 'setKeyboardShortcut', 'resetKeyboardShortcuts']) {
  assert.match(native, new RegExp(`commandName == "${token}"`), `${token} missing from native bridge`);
  assert.match(catalog, new RegExp(`\\b${token}\\b`), `${token} missing from command catalog`);
}

for (const token of ['getDefaultShortcut', 'getDefaultAltShortcut']) {
  assert.match(read('src/core/StelActionMgr.hpp'), new RegExp(token), `${token} missing from action manager`);
}

for (const token of [
  'settings_view_input_guide_title',
  'settings_view_input_guide_touchpad',
  'settings_view_input_guide_mouse',
  'settings_view_input_guide_keyboard'
]) {
  assert.match(i18n, new RegExp(`['"]${token}['"]`), `${token} missing from localized guide`);
}

for (const token of [
  'settings_shortcuts_title',
  'settings_shortcuts_search',
  'settings_shortcuts_primary',
  'settings_shortcuts_alternate',
  'settings_shortcuts_save'
]) {
  assert.match(i18n, new RegExp(`['"]${token}['"]`), `${token} missing from shortcut editor`);
}

for (const token of ['双指滑动', '双指捏合', '惯性', '快捷键编辑器', 'zoomBy', 'endPinch', '不能伪造']) {
  assert.match(guide, new RegExp(token), `${token} missing from touchpad guide`);
}

console.log('HarmonyOS touchpad and keyboard contract passed.');
