import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const source = readFileSync(new URL('../harmonyos/ets-source/pages/MainWindowNativeNode.ets', import.meta.url), 'utf8');
// 选择按钮已从参数化 @Builder settingsChoiceButton 改为共享组件 SettingsChoiceButton（@Prop active 实时刷新），
// 时间设置三项由 TimeSettingsSection 承载，宿主只保留分组判定与分发。
const buttonSource = readFileSync(new URL('../harmonyos/ets-source/common/ui/SettingsChoiceButton.ets', import.meta.url), 'utf8');
const sectionSource = readFileSync(new URL('../harmonyos/ets-source/panels/settings/TimeSettingsSection.ets', import.meta.url), 'utf8');
function method(name) {
  const start = source.indexOf(name);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n  }', start));
}

test('all four settings groups read current state rather than a captured selection boolean', () => {
  const selected = method('private settingsChoiceSelected(');
  assert.ok(selected.includes('this.informationMode === value'));
  for (const state of ['configDateFormat', 'configTimeFormat', 'startupTimeMode']) {
    assert.ok(selected.includes(`this.timeSettingsStore.${state} === value`), state);
  }
  const dispatch = method('private selectSettingsChoice(');
  for (const group of ['information', 'date', 'time', 'startup']) {
    assert.ok(dispatch.includes(`group === '${group}'`), group);
  }
  assert.ok(source.includes('active: this.informationMode === mode'));
  assert.ok(sectionSource.includes('active: this.store.configDateFormat === option.id'));
  assert.ok(sectionSource.includes('active: this.store.configTimeFormat === option.id'));
  assert.ok(sectionSource.includes('active: this.store.startupTimeMode === option.id'));
  for (const group of ['date', 'time', 'startup']) {
    assert.ok(sectionSource.includes(`this.onSelectFormat('${group}', option.id)`), group);
  }
});

test('choice buttons have an explicit normal type and shared control radius', () => {
  assert.match(buttonSource, /Button\(\{ type: ButtonType.Normal \}\)/);
  assert.match(buttonSource, /borderRadius\(UI_RADIUS_CONTROL\)/);
  assert.doesNotMatch(buttonSource, /UI_RADIUS_PILL|maxLines|minFontSize/);
  assert.match(buttonSource, /minHeight: 40, maxWidth: '100%'/);
});

test('selection animation follows the background, but does not animate button layout', () => {
  assert.ok(buttonSource.indexOf('.backgroundColor(') < buttonSource.indexOf('.animation('));
  assert.ok(buttonSource.indexOf('.animation(') < buttonSource.indexOf('.padding('));
  assert.match(buttonSource, /duration: UI_OPTION_ANIMATION_MS, curve: Curve.EaseOut/);
  assert.match(buttonSource, /clickEffect\(\{ level: ClickEffectLevel.LIGHT \}\)/);
  assert.match(source, /canPick: !this\.informationSettingPending/);
  assert.match(source, /pending: this\.timeSettingsPending/);
  assert.match(sectionSource, /canPick: !this\.pending/);
});

test('CLI and touch share time response animations and semantic settings routes', () => {
  const apply = method('private applyTimeSettings(');
  assert.match(apply, /getUIContext\(\)\.animateTo/);
  assert.match(apply, /this\.timeSettingsStore\.startupTimeMode = result\.startupTimeMode/);
  assert.match(apply, /this\.deltaTStore\.deltaTAlgorithm = result\.deltaTAlgorithm/);
  const route = method('private openPanelFromCli(');
  assert.match(route, /settingsInformation/);
  assert.match(route, /settingsTime/);
  assert.match(route, /this\.selectConfigTab\(panel === 'settingsInformation' \? 1 : \(panel === 'settingsTime' \? 3 : -1\)\)/);
});
