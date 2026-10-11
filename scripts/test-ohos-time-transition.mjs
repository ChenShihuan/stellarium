import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const page = readFileSync(new URL('../harmonyos/ets-source/pages/MainWindowNativeNode.ets', import.meta.url), 'utf8');
const duration = page.slice(page.indexOf('private timeTransitionDurationMs'), page.indexOf('// ===== 时间速率档位系统 ====='));
const astro = page.slice(page.indexOf('private animateTimeToJD'), page.indexOf('/** 将原生返回的速率映射回时间档位'));
const wheel = page.slice(page.indexOf('private startTimeWheelTransition'), page.indexOf('private stopTimeWheelInertia'));
const advance = page.slice(page.indexOf('private advanceTimeWheel'), page.indexOf('private timeWheelVelocityMultiplier'));

test('long astronomy jumps use distance-aware eased timing', () => {
  assert.match(duration, /Math\.log10/);
  assert.match(duration, /Math\.pow\(normalized, 1\.45\)/);
  assert.match(duration, /this\.clamp\(900.*7000\)/);
  assert.match(astro, /const distanceDays = distanceSeconds \/ 86400\.0/);
  assert.match(astro, /this\.timeTransitionDurationMs\(distanceDays\)/);
  assert.match(astro, /distanceDays >= 30 \? 32 : 48/);
  assert.match(astro, /const useNativeRate = distanceDays >= 3\.0/);
  assert.match(astro, /this\.astroTimeTransitionUsesNativeRate = true/);
  assert.match(astro, /this\.setTimeRate\(travelRate\)/);
  assert.match(astro, /if \(useNativeRate\)/);
});

test('time-wheel month and year changes interpolate from start to target', () => {
  assert.match(wheel, /timeWheelTransitionStartMs/);
  assert.match(wheel, /timeWheelTransitionDurationMs/);
  assert.match(wheel, /const eased = progress \* progress \* \(3 - 2 \* progress\)/);
  assert.doesNotMatch(wheel, /Math\.ceil\(Math\.abs\(deltaMs\).*\/ 3\.0/);
  assert.match(wheel, /const sendNative = now - this\.timeWheelLastNativePushMs >= 48/);
  assert.match(advance, /this\.timeWheelUnit === 'day'/);
});
