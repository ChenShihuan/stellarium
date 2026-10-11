import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const page = readFileSync(new URL('../harmonyos/ets-source/pages/MainWindowNativeNode.ets', import.meta.url), 'utf8');
const i18n = readFileSync(new URL('../harmonyos/ets-source/pages/I18n.ets', import.meta.url), 'utf8');
const sourceLogic = page.slice(page.indexOf('private setSatelliteSourceEnabled'), page.indexOf('private deleteSatelliteSource'));
const sourcePanel = page.slice(page.indexOf("Text(I18n.t('sat_sources_title'))"), page.indexOf("Text(I18n.t('c_total_count'))"));

test('satellite sources preserve the original enabled-source behavior', () => {
  assert.match(sourceLogic, /addNew: sourceIndex === index \? enabled : source\.addNew/);
  assert.match(sourcePanel, /Toggle\(\{ type: ToggleType\.Switch, isOn: source\.addNew \}\)/);
  assert.match(sourcePanel, /enabled\(this\.satUpdateSettings\.autoAddEnabled\)/);
});

test('long URLs stay compact and remain inspectable', () => {
  assert.match(sourcePanel, /this\.satelliteSourcePreview\(source\.url\)/);
  assert.match(sourcePanel, /this\.expandedSatelliteSourceIndex === sourceIndex/);
  assert.match(sourcePanel, /\.height\(176\)\.scrollBar\(BarState\.Auto\)/);
  assert.match(page, /private satelliteSourcePreview\(url: string\)/);
});

test('source management labels are localized', () => {
  for (const key of ['sat_source_enabled', 'sat_source_disabled', 'sat_source_local_file', 'sat_source_edit', 'sat_source_save', 'sat_source_restore', 'sat_source_restore_title', 'sat_source_restore_message', 'sat_source_cancel', 'sat_source_enabled_hint', 'sat_next_update', 'sat_updates_disabled', 'sat_updating', 'sat_update_error']) {
    assert.match(i18n, new RegExp(`'${key}':`));
    assert.match(i18n, new RegExp(`'${key}': \\{[^\\n]*'zh_CN':`));
  }
});

test('source management exposes original edit and restore actions', () => {
  assert.match(page, /private editSatelliteSource\(index: number\)/);
  assert.match(page, /private restoreSatelliteSources\(\)/);
  assert.match(page, /restoreSatelliteSources/);
  assert.match(page, /satelliteUpdateStatusText/);
});
