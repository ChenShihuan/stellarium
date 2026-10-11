import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const page = readFileSync(new URL('../harmonyos/ets-source/pages/MainWindowNativeNode.ets', import.meta.url), 'utf8');
const i18n = readFileSync(new URL('../harmonyos/ets-source/pages/I18n.ets', import.meta.url), 'utf8');
const cpp = readFileSync(new URL('../src/StelMainView.cpp', import.meta.url), 'utf8');
const catalog = readFileSync(new URL('../src/StelOhosCommandCatalog.hpp', import.meta.url), 'utf8');

test('pointer coordinate changes do not reload the whole panel on success', () => {
  const setter = page.slice(page.indexOf('private setPointerCoordinates'), page.indexOf('private pointerCoordinateSystemLabel'));
  assert.match(setter, /this\.applyPointerCoordinatesSetting|if \(setting === 'enabled'\)/);
  assert.match(setter, /if \(r\.ok !== true\)[\s\S]*?this\.loadPointerCoordinates\(false\)/);
  assert.doesNotMatch(setter, /if \(r\.ok === true\)[\s\S]*?this\.loadPointerCoordinates/);
  assert.match(page, /Stack\(\{ alignContent: Alignment\.Center \}\)/);
  assert.match(page, /pointer_coord_toolbar_hint/);
});

test('layer tabs keep a stable top row and readable desktop type', () => {
  const tabs = page.slice(page.indexOf('viewTabs()'), page.indexOf('private selectViewTab'));
  assert.match(tabs, /fontSize\(this\.panelFontSize\(12\)\)/);
  assert.match(tabs, /\.height\(this\.isLargeDesktopCanvas\(\) \? 46 : 42\)/);
  assert.match(page, /this\.layerPresetBar\(\)[\s\S]*this\.viewTabs\(\)[\s\S]*Scroll\(this\.widePanelScroller\)/);
});

test('survey tab explains the two original layers and reports native state', () => {
  const surveys = page.slice(page.indexOf('viewSurveysTab()'), page.indexOf('private loadSurveyState'));
  assert.match(surveys, /survey_usage/);
  assert.match(surveys, /survey_alignment_hint/);
  assert.match(page, /callInteractive\('getSurveyState'/);
  assert.match(cpp, /commandName == "getSurveyState"/);
  assert.match(catalog, /getSurveyState/);
});

test('pointer toolbar wording explains its independent quick-switch role', () => {
  assert.match(i18n, /'pointer_coord_toolbar_hint':/);
  assert.match(i18n, /'zh_CN': '[^']*快速开关/);
});

test('pointer coordinates receive the latest touch or mouse position', () => {
  assert.match(page, /updateNativePointerPosition\(x, y\)/);
  assert.match(page, /callNativeFire\('setPointerPosition'/);
  assert.match(page, /event\.action === MouseAction\.Move\)[\s\S]*?updateNativePointerPosition/);
  assert.match(page, /event\.action === MouseAction\.Press && event\.button === MouseButton\.Left/);
  assert.match(page, /event\.action === MouseAction\.Release && this\.mouseSkyPressed/);
  assert.doesNotMatch(page, /event\.action === 0 && event\.button === 0/);
  assert.doesNotMatch(page, /event\.action === 2 && this\.mouseSkyPressed/);
  assert.doesNotMatch(page, /event\.action === 1 && this\.mouseSkyPressed/);
  assert.match(cpp, /commandName == "setPointerPosition"/);
  assert.match(cpp, /setOhosMousePos\(x2, y2\)/);
  assert.match(cpp, /state\["screenX"\]/);
  assert.match(catalog, /selectAt,setPointerPosition,selftestActions/);
});
