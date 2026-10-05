import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const source = readFileSync(new URL('../harmonyos/ets-source/pages/MainWindowNativeNode.ets', import.meta.url), 'utf8');
const mediaComponents = readFileSync(new URL('../harmonyos/ets-source/panels/object/TabletInspectorMedia.ets', import.meta.url), 'utf8');
// 媒体卡片已下沉为 TabletInspectorMediaCard 组件（本轮搬迁），宿主只保留分支判定并向组件传参。
const card = mediaComponents.slice(mediaComponents.indexOf('export struct TabletInspectorMediaCard {'), mediaComponents.indexOf('export struct TabletInspectorNoticeRow {'));
const preview = source.slice(source.indexOf('  private objectInspectorMediaPreviewOverlay() {'), source.indexOf('  private openObjectInspectorMediaPreview(): void'));
// 天体详情分支已下沉为 ObjectPanel 组件（Phase 4e）：媒体卡片的调用点现在组件内，
// 但视口高度仍由宿主按实时视口状态算好后以 @Prop 传入。
const objectPanel = readFileSync(new URL('../harmonyos/ets-source/panels/panels/ObjectPanel.ets', import.meta.url), 'utf8');

test('detail images preserve their entire frame instead of covering the viewport', () => {
  assert.match(card, /Image\(this\.store\.objectInspectorMediaPixelMap\)[\s\S]*?objectFit\(ImageFit\.Contain\)/);
  assert.doesNotMatch(card, /ImageFit\.Cover/);
});

test('caption follows the image viewport, with no fixed height on the outer column', () => {
  assert.match(card, /Column\(\{ space: 0 \}\) \{\s+Stack\(\{ alignContent: Alignment\.Center \}\)/);
  assert.match(card, /\}\.width\('100%'\)\.height\(this\.imageHeight\)\s+Row\(\{ space: 6 \}\)/);
  assert.match(card, /\}\s+\.width\('100%'\)\.clip\(true\)\.borderRadius/);
});

test('host still feeds the media card the viewport height computed from the live viewport state', () => {
  const call = objectPanel.slice(objectPanel.indexOf('TabletInspectorMediaGroup({'), objectPanel.indexOf('SatellitePassDetails({'));
  assert.match(call, /store: this\.objectMediaStore/);
  assert.match(call, /imageHeight: this\.imageHeight/);
  assert.match(source, /imageHeight: this\.objectInspectorImageHeight\(\)/);
});

test('preview shrinks to the available detail viewport without growing beyond 210vp', () => {
  const body = source.match(/private objectInspectorImageHeight\(\): number \{([\s\S]*?)\n  \}/)[1];
  const height = new Function(body);
  for (const available of [160, 210, 300, 500]) {
    const result = height.call({ objectMediaStore: { objectInspectorMediaViewportHeight: available } });
    assert.ok(result >= 72 && result <= 210);
    assert.ok(result + 88 <= available);
  }
});

test('full-screen image keeps aspect fit and a working close action', () => {
  assert.match(preview, /Image\(this\.objectMediaStore\.objectInspectorMediaPixelMap\)[\s\S]*?objectFit\(ImageFit\.Contain\)/);
  assert.match(preview, /onClick\(\(\) => \{ this\.closeObjectInspectorMediaPreview\(\) \}\)/);
});
