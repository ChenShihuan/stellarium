import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');

const service = read('harmonyos/ets-source/qability/CollaborationSessionService.ets');
const ability = read('harmonyos/ets-source/qability/QAbility.ets');
const catalog = read('src/StelOhosCommandCatalog.hpp');
const module = read('harmonyos/module.json5');
const sync = read('scripts/sync-ohos-build-sources.sh');

for (const name of [
  'createCollaborationSession',
  'getCollaborationState',
  'exportCollaborationSession',
  'previewCollaborationSession',
  'importCollaborationSession',
  'applyCollaborationSession'
]) {
  assert.match(ability, new RegExp(`request.commandName === '${name}'`), `${name} missing from QAbility`);
  assert.match(catalog, new RegExp(name), `${name} missing from native catalog`);
}

assert.match(service, /schemaVersion/);
assert.match(service, /expiresAt/);
assert.match(service, /locationIncluded/);
assert.match(service, /redactedFields/);
for (const field of ['viewJ2000', 'fovDeg', 'jd', 'selected', 'flags']) {
  assert.match(service, new RegExp(`\\['${field}'\\]`), `${field} is not explicitly whitelisted`);
}
assert.doesNotMatch(service, /nativeState\[['"](SN|UDID|password|telescopeHost|telescopePort)['"]\]/);
assert.match(service, /stellarium\.collaboration\.session/);
assert.match(module, /"continuable": false/);
assert.match(ability, /OnContinueResult\.REJECT/);
assert.match(sync, /CollaborationSessionService\.ets/);
// The application currently supports an explicit online build.  The
// collaboration payload itself must remain local and redacted; the module
// permission is not evidence that a session was uploaded.
assert.match(module, /ohos\.permission\.INTERNET/);
assert.doesNotMatch(service, /https?:\/\//);
console.log('HarmonyOS collaboration contract passed.');
