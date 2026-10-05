import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { test } from 'node:test';

const source = readFileSync(new URL('../harmonyos/ets-source/pages/MainWindowNativeNode.ets', import.meta.url), 'utf8');
const ability = readFileSync(new URL('../harmonyos/ets-source/qability/QAbility.ets', import.meta.url), 'utf8');
// Phase 4l：astro 分支体已下沉到 panels/astro/AstroPanel.ets，UI 断言改读组件文件。
const panel = readFileSync(new URL('../harmonyos/ets-source/panels/astro/AstroPanel.ets', import.meta.url), 'utf8');
function method(name) {
  const begin = source.indexOf('  private ' + name + '(');
  assert.ok(begin >= 0, name);
  return source.slice(begin, source.indexOf('\n  }', begin) + 4);
}
// Phase A1-2：astroGroupForTab / astroTabItemsForGroup 已迁到 common/derive/astro.ets，
// 宿主不再有它们的 private 方法；从纯函数模块取（通过函数作用域传给 Controller）。
const derive = readFileSync(new URL('../harmonyos/ets-source/common/derive/astro.ets', import.meta.url), 'utf8');
function deriveFn(name) {
  const begin = derive.indexOf('export function ' + name + '(');
  assert.ok(begin >= 0, name);
  return stripTypeScriptTypes(derive.slice(begin + 'export '.length, derive.indexOf('\n}', begin) + 2));
}
function harness() {
  const code = 'class Controller {\n' + ['selectAstroTab', 'selectAstroGroup', 'selectAstroFilter']
    .map(method).join('\n') + '\n}';
  const Controller = new Function('Curve', 'astroGroupForTab', 'astroTabItemsForGroup', stripTypeScriptTypes(code) + '; return Controller;')(
    { EaseIn: 'in', EaseOut: 'out' },
    new Function(deriveFn('astroGroupForTab') + '; return astroGroupForTab;')(),
    new Function('I18n', deriveFn('astroTabItemsForGroup') + '; return astroTabItemsForGroup;')({ t: k => k }));
  const controller = new Controller();
  const callbacks = [];
  const animations = [];
  const loads = [];
  Object.assign(controller, {
    astroStore: { astroTab: 5, astroGroup: 0, astroContentOpacity: 1, astroContentOffsetX: 0 },
    astroRequestedTab: -1, astroTransitionId: 0,
    panelVisible: true, activePanel: 'astro',
    wutStore: { wutPeriod: 'evening', wutMinAltitude: 0, wutMaxMagnitude: 6, wutDirection: 'all' },
    astroPanelScroller: { scrollTo: () => {} },
    publishAstroPanelState: () => {}, saveAppSettings: () => {},
    loadAstroTab: tab => loads.push(tab), loadWutTargets: () => loads.push('wut'),
    getUIContext: () => ({ animateTo: (options, update) => {
      animations.push(options);
      update();
      if (options.onFinish) callbacks.push(options.onFinish);
    } }),
  });
  return { controller, animations, loads, flush: () => { while (callbacks.length) callbacks.shift()(); } };
}

test('every astronomy click site has light press feedback; all 64 selected backgrounds animate', () => {
  assert.equal((panel.match(/\.onClick\(/g) ?? []).length, 102);
  assert.equal((panel.match(/\.clickEffect\(/g) ?? []).length, 102);
  assert.equal((panel.match(/duration: UI_OPTION_ANIMATION_MS, curve: Curve.EaseOut/g) ?? []).length, 64);
  assert.doesNotMatch(panel, /springMotion|geometryTransition/);
});

test('the scroll itself only translates/fades; no animated sizing or conditional scroll recreation', () => {
  assert.match(panel, /Scroll\(this\.scroller\)/);
  assert.match(panel, /id\('astro-content'\)\.opacity\(this\.store\.astroContentOpacity\)\.translate\(\{ x: this\.store\.astroContentOffsetX \}\)/);
  assert.doesNotMatch(panel, /\.height\(this.astroContent|if \(this.astroContentOpacity/);
});

test('tonight loading feedback follows filters so starting a calculation cannot push the controls', () => {
  const tonight = panel.slice(panel.indexOf('} else if (this.store.astroTab === 5)'), panel.indexOf('} else if (this.store.astroTab === 6)'));
  assert.ok(tonight.indexOf('if (this.wutStore.wutLoading)') > tonight.indexOf("this.host.selectAstroFilter('direction',"));
  assert.ok(tonight.indexOf('if (this.wutStore.wutLoading)') < tonight.indexOf('if (this.wutStore.wutHint.length'));
});

test('switching follows displayed tab order rather than numeric IDs and uses detail timing', () => {
  const state = harness();
  state.controller.astroStore.astroTab = 9;
  state.controller.selectAstroTab(0);
  assert.equal(state.controller.astroStore.astroContentOffsetX, -8);
  assert.deepEqual(state.loads, []);
  state.flush();
  assert.deepEqual(state.loads, [0]);
  assert.equal(state.controller.astroStore.astroGroup, 1);
  assert.equal(state.controller.astroStore.astroContentOpacity, 1);
  assert.deepEqual(state.animations.map(item => [item.duration, item.curve]), [[100, 'in'], [170, 'out']]);
  state.controller.selectAstroTab(9);
  assert.equal(state.controller.astroStore.astroContentOffsetX, 8);
  state.flush();
});

test('repeated active tab or group does not reload', () => {
  const state = harness();
  state.controller.selectAstroTab(5);
  state.controller.selectAstroGroup(0);
  state.flush();
  assert.deepEqual(state.loads, []);
  assert.equal(state.animations.length, 0);
});

test('rapid changes only commit and load the last target', () => {
  const state = harness();
  state.controller.selectAstroTab(2);
  state.controller.selectAstroTab(4);
  state.controller.selectAstroTab(0);
  state.flush();
  assert.equal(state.controller.astroStore.astroTab, 0);
  assert.deepEqual(state.loads, [0]);
  assert.equal(state.controller.astroRequestedTab, -1);
});

test('returning to the original tab during fade cancels the earlier destination', () => {
  const state = harness();
  state.controller.selectAstroTab(2);
  state.controller.selectAstroTab(5);
  state.flush();
  assert.equal(state.controller.astroStore.astroTab, 5);
  assert.deepEqual(state.loads, [5]);
  assert.equal(state.controller.astroStore.astroContentOpacity, 1);
});

test('closing during a transition does not load a hidden computation', () => {
  const state = harness();
  state.controller.selectAstroTab(7);
  state.controller.panelVisible = false;
  state.flush();
  assert.deepEqual(state.loads, []);
  assert.equal(state.controller.astroRequestedTab, -1);
  assert.equal(state.controller.astroStore.astroContentOpacity, 1);
});

test('filter commands and touch use one validated state path; repeated values do not recalculate', () => {
  const state = harness();
  for (const [key, value] of [['period', 'morning'], ['altitude', '20'], ['magnitude', '8'], ['direction', 'east']]) {
    state.controller.selectAstroFilter(key, value);
    state.controller.selectAstroFilter(key, value);
    assert.ok(panel.includes("this.host.selectAstroFilter('" + key + "',"));
  }
  state.controller.selectAstroFilter('period', 'nonsense');
  state.controller.selectAstroFilter('altitude', '-90');
  assert.equal(state.loads.length, 4);
  assert.equal(state.controller.wutStore.wutPeriod, 'morning');
  for (const command of ['setAstroTab', 'setAstroGroup', 'setAstroFilter', 'getAstroPanelState']) {
    assert.ok(ability.includes("'" + command + "'"));
  }
});
