import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const page = readFileSync(new URL('../harmonyos/ets-source/pages/MainWindowNativeNode.ets', import.meta.url), 'utf8');
const widthMethod = page.slice(page.indexOf('private compactDockWidthPercent()'), page.indexOf('private compactDockLabelFontSize()'));
const dockBuilder = page.slice(page.indexOf('bottomDock()'), page.indexOf('// 手机、平板和桌面窗口共享同一套空闲透明度'));
const button = page.slice(page.indexOf('dockButton(item: ShellAction)'), page.indexOf('@Builder\n  floatingPanel()'));

test('phone Dock width is stable when a panel opens', () => {
  assert.doesNotMatch(widthMethod, /this\.panelVisible \?/);
  assert.match(widthMethod, /targetWidth = Math\.min\(420, Math\.max\(288, width - 48\)\)/);
  assert.match(widthMethod, /return this\.clamp\(targetWidth \* 100 \/ width, 82, 92\)/);
  assert.match(dockBuilder, /compactDockWidthPercent\(\) \+ '%'/);
});

test('Dock buttons keep feedback without a large press shrink', () => {
  assert.match(button, /\.scale\(\{ x: 0\.97, y: 0\.97 \}\)/);
  assert.doesNotMatch(button, /\.scale\(\{ x: 0\.92, y: 0\.92 \}\)/);
});
