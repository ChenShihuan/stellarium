import assert from 'node:assert/strict';
import { existsSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';

const output = path.resolve('dist/client');
const routes = ['index.html', 'privacy.html', 'credits.html', '404.html'];
for (const route of routes) {
  const filename = path.join(output, route);
  assert(existsSync(filename), `Missing static route: ${route}`);
  const html = readFileSync(filename, 'utf8');
  assert(
    !html.includes('Your site is taking shape'),
    'Scaffold content remains',
  );
  assert(!/<form\b/i.test(html), 'Unexpected form in informational site');
  for (const match of html.matchAll(
    /<(script|img|link)\b[^>]*?\b(src|href)="([^"]+)"/g,
  )) {
    const resource = match[3];
    assert(
      !/^(https?:)?\/\//.test(resource),
      `External automatic resource: ${resource}`,
    );
    if (!resource.startsWith('/')) continue;
    const file = path.resolve(output, `.${resource.split(/[?#]/)[0]}`);
    assert(
      file.startsWith(`${output}${path.sep}`),
      'Resource escaped output root',
    );
    assert(
      existsSync(file) && statSync(file).isFile(),
      `Missing resource: ${resource}`,
    );
  }
  if (route !== '404.html') {
    assert(!/noindex/.test(html), `Published route is not indexable: ${route}`);
  }
  console.log(`PASS ${route}`);
}
const main = readFileSync(path.join(output, 'index.html'), 'utf8');
assert(main.includes('新ICP备2026008516号-1'), 'Missing verified website filing number');
for (const match of main.matchAll(/href="#([^"]+)"/g)) {
  assert(main.includes(`id="${match[1]}"`), `Missing section: ${match[1]}`);
}
console.log(
  'PASS local resources, homepage anchors, no forms, website filing and indexing',
);
