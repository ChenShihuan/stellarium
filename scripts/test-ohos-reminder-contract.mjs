import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

const service = read('harmonyos/ets-source/qability/AstronomyReminderService.ets');
const ability = read('harmonyos/ets-source/qability/QAbility.ets');
const manifest = read('harmonyos/module.json5');
const catalog = read('src/StelOhosCommandCatalog.hpp');
const sync = read('scripts/sync-ohos-build-sources.sh');

for (const name of [
  'getAstronomyReminderStatus',
  'getAstronomyReminders',
  'scheduleAstronomyReminder',
  'scheduleNextSolarTermReminder',
  'cancelAstronomyReminder',
  'clearAstronomyReminders'
]) {
  assert.match(ability, new RegExp(`request.commandName === '${name}'`), `${name} missing from QAbility`);
  assert.match(catalog, new RegExp(name), `${name} missing from native catalog`);
}

assert.match(service, /reminderAgentManager/);
assert.match(service, /getAllValidReminders/);
assert.match(service, /publishReminder/);
assert.match(manifest, /ohos\.permission\.PUBLISH_AGENT_REMINDER/);
assert.match(sync, /AstronomyReminderService\.ets/);
assert.match(ability, /nestedResult/);
assert.match(ability, /Array\.isArray\(rawTerms\)/);
assert.match(ability, /Number\(String\(rawCurrentJD/);
assert.match(ability, /directNextDate/);
assert.match(read('src/StelMainView.cpp'), /nextSolarTermDate/);
console.log('HarmonyOS reminder contract passed.');
