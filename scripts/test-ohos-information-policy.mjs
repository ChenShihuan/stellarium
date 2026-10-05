import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const source = readFileSync(new URL('../harmonyos/ets-source/pages/MainWindowNativeNode.ets', import.meta.url), 'utf8');
const match = source.match(/private applyCustomInformationMask\(\): void \{([\s\S]*?)\n  \}/);
assert.ok(match);
const apply = new Function(match[1].replace('new Map<string, string>', 'new Map').replace('field: ObjectDetailField', 'field'));

// 选中天体的信息字段改由 ObjectDetailStore 承载（本轮状态搬迁），假宿主相应注入 objectDetailStore。
function state(enabled, mode = 'custom') {
  return {
    informationMode: mode,
    informationMaskHas: key => enabled.includes(key),
    objectDetailStore: {
      selectedMagnitude: '3.40', selectedDistance: '2.5 Mly', selectedConstellation: '仙女座',
      selectedCoordEq: '00h42m', selectedCoordGalactic: '121°', selectedName: '仙女座星系',
      selectedDetailFields: [
        { key: 'equatorialOfDate', value: '00h42m' }, { key: 'surfaceBrightness', value: '13.2' },
        { key: 'morphology', value: 'SA(s)b' }
      ]
    }
  };
}

test('custom empty mask clears information values but preserves selection identity', () => {
  const selected = state([]);
  apply.call(selected);
  assert.equal(selected.objectDetailStore.selectedMagnitude, '');
  assert.equal(selected.objectDetailStore.selectedConstellation, '');
  assert.equal(selected.objectDetailStore.selectedCoordEq, '');
  assert.equal(selected.objectDetailStore.selectedName, '仙女座星系');
  assert.deepEqual(selected.objectDetailStore.selectedDetailFields, []);
});

test('custom groups filter both overview values and structured detail rows', () => {
  const selected = state(['magnitude', 'galactic']);
  apply.call(selected);
  assert.equal(selected.objectDetailStore.selectedMagnitude, '3.40');
  assert.equal(selected.objectDetailStore.selectedCoordGalactic, '121°');
  assert.equal(selected.objectDetailStore.selectedDistance, '');
  assert.deepEqual(selected.objectDetailStore.selectedDetailFields.map(field => field.key), ['surfaceBrightness']);
});

test('preset information modes are not filtered by saved custom choices', () => {
  const selected = state([], 'all');
  const original = JSON.stringify(selected);
  apply.call(selected);
  assert.equal(JSON.stringify(selected), original);
});
