import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const script = read('scripts/set-ohos-network-mode.sh');
const cmake = read('CMakeLists.txt');
const inventory = read('docs/harmonyos/NETWORK-INVENTORY.md');
const localization = read('data/ohos/network-localization.json');

assert.match(script, /offline\|online\)/);
assert.match(script, /STELLARIUM_OHOS_OFFLINE/);
assert.match(script, /OFFLINE_APPGALLERY_BUILD/);
assert.match(script, /ohos\.permission\.INTERNET/);
assert.match(script, /sync-ohos-build-sources\.sh/);
assert.match(cmake, /STELLARIUM_OHOS_OFFLINE/);
assert.match(inventory, /Map Kit/);
assert.match(inventory, /用户主动/);
assert.match(localization, /onlineBuildMeans/);
assert.match(localization, /platform.map-kit/);
assert.match(localization, /query.plate-solver.astrometry/);
console.log('HarmonyOS network mode contract passed.');
