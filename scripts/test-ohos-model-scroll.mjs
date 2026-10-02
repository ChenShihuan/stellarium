import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import test from 'node:test';

const source = readFileSync(new URL('../harmonyos/ets-source/pages/MainWindowNativeNode.ets', import.meta.url), 'utf8');
// 全屏三维模型叠层已下沉为 ObjectInspectorModelOverlay 组件（Phase 5d）：组件把舞台手势转交宿主注入的
// onStageTouch -> handleObjectInspectorModelTouch；旋转/双指缩放的算法与内部触摸状态仍在宿主。
const modelOverlay = readFileSync(new URL('../harmonyos/ets-source/panels/overlay/ObjectInspectorModelOverlay.ets', import.meta.url), 'utf8');
// 三维模型的舞台与触摸回调已下沉为 TabletInspectorModelBlock 组件（本轮搬迁），
// 组件只负责把手势事件转交给宿主注入的 onModelTouch 回调；旋转/缩放算法仍留在宿主。
const mediaComponents = readFileSync(new URL('../harmonyos/ets-source/panels/object/TabletInspectorMedia.ets', import.meta.url), 'utf8');
// 详情卡外壳（页头 + 页签 + Scroll）已在本轮下沉为 UnifiedObjectDetailCard 组件，
// 卡片内的 Scroll/scroller 与滚动位置上报告搬到该组件文件。
const detailCard = readFileSync(new URL('../harmonyos/ets-source/panels/object/UnifiedObjectDetailCard.ets', import.meta.url), 'utf8');
const stageStart = mediaComponents.indexOf(".id('object-model-inline-stage')");
const stage = mediaComponents.slice(stageStart, mediaComponents.indexOf('Text(this.modelNotice)', stageStart));

test('only the bounded model captures touch; the outer card isolates the sky', () => {
  assert.match(stage, /HitTestMode.BLOCK_HIERARCHY/);
  assert.match(stage, /onTouch.*this\.onModelTouch\(event\)/);
  assert.doesNotMatch(stage, /PanDirection|onGestureJudgeBegin|parallelGesture/);
  assert.match(mediaComponents.slice(stageStart - 230, stageStart), /width\(this\.inlineModelSize\)\.height\(this\.inlineModelSize\)/);
  assert.match(source, /onModelTouch: \(event: TouchEvent\) => \{ this\.handleObjectInspectorModelTouch\(event\) \}/);
  assert.equal((source.match(/height\(this.detailCardHeight\(\)\)\s*\.zIndex\(\d+\)\s*\.hitTestBehavior\(HitTestMode.BLOCK_HIERARCHY\)/g) ?? []).length, 3);
  assert.match(source, /scroller: this\.objectDetailScroller/);
  assert.match(detailCard, /Scroll\(this\.scroller\)/);
  assert.match(detailCard, /stellariumObjectDetailScrollY.*currentOffset\(\)\?\.yOffset/);
});

test('compact and wide cards reserve at least 40vp per side', () => {
  const start = source.indexOf('  private objectInspectorInlineModelSize(');
  const method = source.slice(start, source.indexOf('\n  }', start) + 4);
  const Controller = new Function(stripTypeScriptTypes('class Controller {\n' + method + '\n}') + ';return Controller;')();
  for (const width of [280, 286, 318, 340, 380, 480]) {
    const controller = new Controller();
    controller.bottomCardWidth = () => width;
    const size = controller.objectInspectorInlineModelSize();
    assert.ok(size <= 200);
    assert.ok((width - 32 - size) / 2 >= 40);
  }
});

test('inline and full screen retain unrestricted rotation and pinch with cleanup', () => {
  assert.match(modelOverlay, /onStageTouch\(event\)/);
  assert.match(modelOverlay, /HitTestMode.BLOCK_HIERARCHY/);
  assert.match(modelOverlay, /object-model-close/);
  assert.match(source, /onStageTouch: \(event: TouchEvent\) => \{ this\.handleObjectInspectorModelTouch\(event\) \}/);
  const handler = source.slice(source.indexOf('private handleObjectInspectorModelTouch'), source.indexOf('private objectInspectorInlineModelSize'));
  assert.match(handler, /rotateObjectInspectorModel\(deltaX, deltaY\)/);
  assert.match(handler, /objectInspectorModelScale \* scaleFactor/);
  assert.match(handler, /TouchType.Up.*TouchType.Cancel/);
  assert.match(handler, /objectInspectorModelInteracting = false/);
  assert.match(handler, /requestObjectInspectorModelRender\(true\)/);
});

function touchHarness() {
  const start = source.indexOf('  private handleObjectInspectorModelTouch(');
  const method = source.slice(start, source.indexOf('\n  }', start) + 4);
  const TouchType = { Down: 0, Move: 1, Up: 2, Cancel: 3 };
  const Controller = new Function('TouchType', stripTypeScriptTypes('class Controller {\n' + method + '\n}') + ';return Controller;')(TouchType);
  const controller = new Controller();
  const moves = [];
  const renders = [];
  // 缩放与交互标志随状态搬迁进了 ObjectMediaStore，触摸计数等内部状态仍在宿主。
  controller.objectMediaStore = { objectInspectorModelScale: 1, objectInspectorModelInteracting: false };
  controller.objectInspectorModelTouchCount = 0;
  controller.objectInspectorModelLastPinchDistance = 0;
  Object.assign(controller, {
    touchScreenX: point => point.x, touchScreenY: point => point.y,
    rotateObjectInspectorModel: (...values) => moves.push(values),
    requestObjectInspectorModelRender: quality => renders.push(quality) });
  const touch = (type, points) => controller.handleObjectInspectorModelTouch({ type: TouchType[type],
    touches: points.map(([x, y]) => ({ x, y })), changedTouches: [], stopPropagation() {} });
  return { controller, moves, renders, touch };
}

test('touch handler preserves horizontal, vertical and diagonal movement', () => {
  const { moves, renders, controller, touch } = touchHarness();
  touch('Down', [[0, 0]]);
  touch('Move', [[20, 0]]);
  touch('Move', [[20, 30]]);
  touch('Move', [[10, 15]]);
  touch('Up', []);
  assert.deepEqual(moves, [[20, 0], [0, 30], [-10, -15]]);
  assert.deepEqual(renders, [true]);
  assert.equal(controller.objectMediaStore.objectInspectorModelInteracting, false);
});

test('two-finger pinch changes scale without orbit and cancellation resets interaction', () => {
  const { moves, controller, touch } = touchHarness();
  touch('Down', [[0, 0], [100, 0]]);
  touch('Move', [[0, 0], [110, 0]]);
  assert.ok(controller.objectMediaStore.objectInspectorModelScale > 1);
  touch('Move', [[0, 0], [90, 0]]);
  assert.ok(controller.objectMediaStore.objectInspectorModelScale < 1);
  assert.deepEqual(moves, []);
  touch('Cancel', []);
  assert.equal(controller.objectMediaStore.objectInspectorModelInteracting, false);
  assert.equal(controller.objectInspectorModelTouchCount, 0);
  assert.equal(controller.objectInspectorModelLastPinchDistance, 0);
});
