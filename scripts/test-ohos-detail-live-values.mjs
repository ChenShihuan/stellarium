import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const source = readFileSync(new URL('../harmonyos/ets-source/pages/MainWindowNativeNode.ets', import.meta.url), 'utf8');
const getterBody = source.match(/private selectedDisplayValue\(key: string\): string \{([\s\S]*?)\n  \}/)[1];
const getter = new Function('key', getterBody);
const fields = [...getterBody.matchAll(/case '(selected\w+)':/g)].map(match => match[1]);

// 选中天体的取值统一改由 ObjectDetailStore 承载（本轮状态搬迁），
// 因此下面的假宿主改为注入 objectDetailStore，断言“取值读的是当前状态”这一不变式。

test('every selected-object value resolves current state rather than a builder snapshot', () => {
  const state = { zhNameOf: value => value, objectDetailStore: {} };
  for (const field of fields) {
    state.objectDetailStore[field] = 'first';
    assert.equal(getter.call(state, field), 'first', field);
    state.objectDetailStore[field] = 'second';
    assert.equal(getter.call(state, field), 'second', field);
  }
});

test('hidden or unavailable coordinates do not retain their last value', () => {
  const state = { objectDetailStore: { selectedCoordApparentAltAz: '', selectedCoordAlt: 'fallback' } };
  assert.equal(getter.call(state, 'selectedCoordApparentAltAz'), 'fallback');
  state.objectDetailStore.selectedCoordAlt = '';
  assert.equal(getter.call(state, 'selectedCoordApparentAltAz'), '');
});

test('structured row resolves replaced fields and handles fields that disappear', () => {
  const body = source.match(/private detailFieldValue\(key: string\): string \{([\s\S]*?)\n  \}/)[1];
  const value = new Function('key', body.replace('item: ObjectDetailField', 'item'));
  const state = { objectDetailStore: { selectedDetailFields: [{ key: 'range', value: '1200 km' }] } };
  assert.equal(value.call(state, 'range'), '1200 km');
  state.objectDetailStore.selectedDetailFields = [{ key: 'range', value: '1100 km' }];
  assert.equal(value.call(state, 'range'), '1100 km');
  state.objectDetailStore.selectedDetailFields = [];
  assert.equal(value.call(state, 'range'), '--');
});

test('live detail polling does not wait for optional satellite pass predictions', () => {
  const poll = source.match(/private startDetailAutoRefresh\(\): void \{([\s\S]*?)\n  \}/)[1];
  assert.doesNotMatch(poll, /selectedSatellitePassesLoaded|getSatellitePasses/);
  assert.match(poll, /this\.skyDragging/);
  assert.match(poll, /this\.refreshSelectedObject\(\)/);
});

test('live merging preserves row order and static records while removing expired values', () => {
  const body = source.match(/private updateSelectedLiveDetails\(fields: Array<ObjectDetailField>\): void \{([\s\S]*?)\n  \}/)[1];
  const merge = new Function('fields', body.replaceAll(': ObjectDetailField', ''));
  const state = { objectDetailStore: { selectedDetailFields: [
    { key: 'range', value: '1000', live: true }, { key: 'tleEpoch', value: 'epoch' },
    { key: 'visibility', value: 'visible', live: true }
  ] } };
  merge.call(state, [{ key: 'range', value: '900', live: true }, { key: 'height', value: '800', live: true }]);
  assert.deepEqual(state.objectDetailStore.selectedDetailFields.map(field => field.key), ['range', 'tleEpoch', 'height']);
  assert.equal(state.objectDetailStore.selectedDetailFields[0].value, '900');
  assert.equal(state.objectDetailStore.selectedDetailFields[1].value, 'epoch');
  merge.call(state, []);
  assert.deepEqual(state.objectDetailStore.selectedDetailFields, [{ key: 'tleEpoch', value: 'epoch' }]);
});

// objectDataRow / tabletInspectorRow 已改为组件（ObjectDataRow / StructuredDetailRow：由父方解析好数值后以 @Prop 传入），
// 贴片族（objectDataTile / objectMetric / objectScheduleTile / objectDetailTab / objectCompactMetric）同样已改为
// DetailTiles.ets 里的组件，因此这条“只传稳定 key、不传字符串快照”的守卫只覆盖仍然是“传 key”的宿主 builder。
test('coordinate and summary builders receive stable keys, not string snapshots', () => {
  const calls = source.split('\n').filter(line => /this\.(selectedCoordinateRow|expandedSummaryMetric|expandedSummaryLine)\(/.test(line));
  assert.ok(calls.length > 5, `call sites found: ${calls.length}`);
  for (const line of calls) assert.doesNotMatch(line, /, this\.selected\w+|, this\.zhNameOf/, line);
});

test('tile components receive resolved values while the host keeps the lookups', () => {
  for (const tile of ['ObjectDataTile', 'ObjectMetric', 'ObjectScheduleTile']) {
    assert.ok(source.includes(`${tile}({ label: `), tile);
  }
  assert.ok(source.includes("value: this.selectedDisplayValue('selectedRise')"));
  assert.ok(source.includes('ObjectDetailTab({ label:'), 'the tab bar comes from the component');
  assert.ok(source.includes('active: this.bottomCardIndex ==='), 'the active tab is derived from live state');
  assert.ok(source.includes("ObjectCompactMetric({ label: I18n.t('i0007')"), 'compact metrics resolve their value in the host');
});
