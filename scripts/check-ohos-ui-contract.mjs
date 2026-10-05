// Locks the UI contract that the refactor of pages/ must not break.
//
// The monolith exposes two kinds of stable anchors that automated UI tests and
// the CLI suite depend on: `.id()` node ids (used by uitest / dumpLayout) and
// the `activePanel` / setPanel names that address the 33 panels. Moving code
// between files is allowed; renaming or dropping an anchor is not.
//
// Usage:
//   node scripts/check-ohos-ui-contract.mjs           # verify against the baseline
//   node scripts/check-ohos-ui-contract.mjs --update  # rewrite the baseline
import assert from 'node:assert/strict';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const mirror = root + 'harmonyos/ets-source/pages/MainWindowNativeNode.ets';
const baselinePath = root + 'docs/harmonyos/json/ui-contract-baseline.json';

const source = readFileSync(mirror, 'utf8');
const uniqueSorted = values => [...new Set(values)].sort();

// `.id('literal')` — a literal id used as-is by tests.
const staticIds = uniqueSorted([...source.matchAll(/\.id\('([^']*)'\)/g)].map(match => match[1]));
// `.id('prefix-' + expr)` — a templated id; only the literal prefix is contract.
const dynamicIdPrefixes = uniqueSorted([...source.matchAll(/\.id\('([^']*)'\s*\+/g)].map(match => match[1]));
const totalIdAnchors = [...source.matchAll(/\.id\(/g)].length;
// Panel names: every compare against activePanel plus every setPanel target.
const panels = uniqueSorted([
  ...[...source.matchAll(/activePanel\s*===?\s*'(\w+)'/g)].map(match => match[1]),
  ...[...source.matchAll(/setPanel\('(\w+)'\)/g)].map(match => match[1]),
  ...[...source.matchAll(/panelId:\s*'(\w+)'/g)].map(match => match[1]),
]);

const contract = {
  note: 'Stable UI contract for the pages/ refactor. Regenerate with --update only when an anchor is intentionally added or renamed.',
  source: 'harmonyos/ets-source/pages/MainWindowNativeNode.ets',
  panels,
  staticIds,
  dynamicIdPrefixes,
  totalIdAnchors,
  count: {
    panels: panels.length,
    staticIds: staticIds.length,
    dynamicIdPrefixes: dynamicIdPrefixes.length,
    totalIdAnchors,
  },
};

if (process.argv.includes('--update')) {
  mkdirSync(baselinePath.replace(/[^/]+$/, ''), { recursive: true });
  writeFileSync(baselinePath, JSON.stringify(contract, null, 2) + '\n');
  console.log(`UI contract baseline written: ${contract.count.panels} panels, ` +
    `${contract.count.staticIds} static ids, ${contract.count.dynamicIdPrefixes} dynamic prefixes, ` +
    `${contract.count.totalIdAnchors} id anchors.`);
} else {
  const baseline = JSON.parse(readFileSync(baselinePath, 'utf8'));
  const diff = (label, before, after) => {
    const gone = before.filter(value => !after.includes(value));
    const added = after.filter(value => !before.includes(value));
    assert.ok(gone.length === 0, `${label} removed or renamed: ${gone.join(', ')}`);
    assert.ok(added.length === 0, `${label} added (run --update if intentional): ${added.join(', ')}`);
  };
  diff('panel names', baseline.panels, contract.panels);
  diff('static .id() anchors', baseline.staticIds, contract.staticIds);
  diff('dynamic .id() prefixes', baseline.dynamicIdPrefixes, contract.dynamicIdPrefixes);
  assert.equal(contract.totalIdAnchors, baseline.totalIdAnchors,
    `total .id() anchors changed: ${baseline.totalIdAnchors} -> ${contract.totalIdAnchors}`);
  console.log(`UI contract intact: ${contract.count.panels} panels, ${contract.count.staticIds} static ids, ` +
    `${contract.count.dynamicIdPrefixes} dynamic prefixes, ${contract.count.totalIdAnchors} id anchors.`);
}
