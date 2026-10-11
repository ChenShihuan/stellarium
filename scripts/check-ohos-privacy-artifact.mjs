import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const hap = resolve(process.argv[2] ?? join(root, 'build/libstellarium-harmonyos/entry/build/default/outputs/default/entry-default-signed.hap'));
const disassembler = process.env.ARK_DISASM ?? '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/ark_disasm';
const auditDirectory = mkdtempSync(join(tmpdir(), 'stellarium-privacy-artifact-'));
const hash = buffer => createHash('sha256').update(buffer).digest('hex');
const extract = name => execFileSync('unzip', ['-p', hap, name], { maxBuffer: 256 * 1024 * 1024 });

function allocatedSections(buffer) {
  assert.equal(buffer.subarray(0, 6).toString('hex'), '7f454c460201', 'expected 64-bit little-endian ELF');
  assert.equal(buffer.readUInt16LE(18), 183, 'expected arm64');
  const tableOffset = Number(buffer.readBigUInt64LE(40));
  const entrySize = buffer.readUInt16LE(58);
  const count = buffer.readUInt16LE(60);
  assert.ok(entrySize >= 64 && count > 0 && tableOffset + count * entrySize <= buffer.length);
  const namesIndex = buffer.readUInt16LE(62);
  assert.ok(namesIndex < count);
  const namesOffset = Number(buffer.readBigUInt64LE(tableOffset + entrySize * namesIndex + 24));
  const result = {};
  for (let index = 0; index < count; index++) {
    const entry = tableOffset + index * entrySize;
    if (!(buffer.readBigUInt64LE(entry + 8) & 2n) || buffer.readUInt32LE(entry + 4) === 8) continue;
    const nameStart = namesOffset + buffer.readUInt32LE(entry);
    const nameEnd = buffer.indexOf(0, nameStart);
    assert.ok(nameStart < buffer.length && nameEnd >= nameStart);
    const name = buffer.toString('utf8', nameStart, nameEnd);
    const offset = Number(buffer.readBigUInt64LE(entry + 24));
    const size = Number(buffer.readBigUInt64LE(entry + 32));
    assert.ok(offset + size <= buffer.length);
    result[name] = { size, sha256: hash(buffer.subarray(offset, offset + size)) };
  }
  assert.ok(result['.text'] && result['.rodata']);
  return result;
}

const manifest = JSON.parse(readFileSync(join(root, 'build/qt-platform-patch/manifest.json'), 'utf8'));
const reference = readFileSync(join(root, 'build/qt-platform-patch/compiled/plugins/platforms/libqohos.so'));
assert.equal(hash(reference), manifest.librarySha256);
const packedPlatform = extract('libs/arm64-v8a/libqohos.so');
const sections = allocatedSections(packedPlatform);
assert.deepEqual(sections, allocatedSections(reference), 'packaged Qt runtime differs from the audited build, excluding non-runtime debug sections');

const module = JSON.parse(extract('module.json').toString('utf8'));
const buildMode = module.app.debug === true ? 'debug' : 'release';
const expectedMode = process.env.EXPECT_OHOS_BUILD_MODE;
if (expectedMode !== undefined) {
  assert.ok(['debug', 'release'].includes(expectedMode), 'expected build mode must be debug or release');
  assert.equal(buildMode, expectedMode, 'compiled build mode differs from expectation; signing configuration does not select build mode');
}
const permissions = (module.module.requestPermissions ?? []).map(permission => permission.name);
assert.ok(!permissions.includes('ohos.permission.ACCESS_UDID'));
assert.ok(!permissions.includes('ohos.permission.INTERNET'));
const abc = extract('ets/modules.abc');
const abcPath = join(auditDirectory, 'modules.abc');
const assemblyPath = join(auditDirectory, 'modules.pa');
writeFileSync(abcPath, abc, { mode: 0o600 });
execFileSync(disassembler, [abcPath, assemblyPath], { timeout: 120000, maxBuffer: 1024 * 1024 });
const assembly = readFileSync(assemblyPath, 'utf8');

function method(className, methodName) {
  const expression = new RegExp(`^\\.function[^\\n]*\\.${className}\\.[^\\n]*#${methodName}\\([^\\n]*\\{\\n[\\s\\S]*?^\\}`, 'm');
  const found = assembly.match(expression);
  assert.ok(found, `missing compiled ${className}.${methodName}`);
  return found[0];
}

const stage = method('QAbilityStage', 'initQtAppContextImpl');
assert.equal((stage.match(/"hasCurrentPrivacyConsent"/g) ?? []).length, 3);
assert.ok(stage.lastIndexOf('"hasCurrentPrivacyConsent"') < stage.indexOf('"setupQtApplication"'));
assert.match(stage, /Privacy consent changed during resource finalization/);
assert.match(stage, /\bthrow\b/);
const child = method('QChildProcess', 'onStart');
assert.ok(child.indexOf('"hasCurrentPrivacyConsent"') >= 0);
assert.ok(child.indexOf('"hasCurrentPrivacyConsent"') < child.indexOf('"runQtChildProcess"'));
assert.match(child, /blocked Qt child process before current consent/);
assert.match(child, /\breturnundefined\b/);
assert.ok(child.indexOf('returnundefined') < child.indexOf('"runQtChildProcess"'));

const mapPath = join(dirname(hap), `symbol/${buildMode}/entry-sourceMaps.map`);
const report = {
  scope: 'Artifact identity and compiled guard presence; not exhaustive control-flow proof or a system privacy scan',
  hap, buildMode, versionCode: module.app.versionCode, hapSha256: hash(readFileSync(hap)), bytecodeSha256: hash(abc),
  qtRevision: manifest.revision, packedPlatformSha256: hash(packedPlatform),
  matchingRuntimeSections: Object.keys(sections).length,
  mainInitializationConsentChecks: 3, childInitializationGuard: true,
  permissions, sourceMap: existsSync(mapPath) ? { path: mapPath, sha256: hash(readFileSync(mapPath)) } : null,
  auditDirectory
};
writeFileSync(join(auditDirectory, 'report.json'), JSON.stringify(report, null, 2) + '\n', { mode: 0o600 });
console.log(JSON.stringify(report, null, 2));
