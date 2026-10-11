import { createServer } from 'node:http';
import { createReadStream, existsSync, statSync } from 'node:fs';
import path from 'node:path';

const root = path.resolve('dist/client');
if (!existsSync(path.join(root, 'index.html')))
  throw new Error('请先运行 npm run build');
const mime = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.jpg': 'image/jpeg',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.woff2': 'font/woff2',
  '.rsc': 'text/x-component',
};
const server = createServer((request, response) => {
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.setHeader('Referrer-Policy', 'no-referrer');
  response.setHeader('X-Robots-Tag', 'noindex, nofollow');
  response.setHeader('Cache-Control', 'no-store');
  if (!['GET', 'HEAD'].includes(request.method ?? '')) {
    response.writeHead(405, { Allow: 'GET, HEAD' });
    response.end();
    return;
  }
  let pathname;
  try {
    pathname = decodeURIComponent(
      new URL(request.url ?? '/', 'http://localhost').pathname,
    );
  } catch {
    response.writeHead(400);
    response.end();
    return;
  }
  if (
    pathname.includes('\0') ||
    pathname.split('/').some((segment) => segment.startsWith('.'))
  ) {
    response.writeHead(404);
    response.end();
    return;
  }
  const normalized = pathname.replace(/\/$/, '') || '/index';
  const target = path.resolve(root, `.${normalized}`);
  if (!target.startsWith(`${root}${path.sep}`)) {
    response.writeHead(404);
    response.end();
    return;
  }
  const file = [target, `${target}.html`].find(
    (candidate) => existsSync(candidate) && statSync(candidate).isFile(),
  );
  const actual = file ?? path.join(root, '404.html');
  response.writeHead(file ? 200 : 404, {
    'Content-Type': mime[path.extname(actual)] ?? 'application/octet-stream',
  });
  if (request.method === 'HEAD') {
    response.end();
    return;
  }
  createReadStream(actual)
    .on('error', () => response.destroy())
    .pipe(response);
});
server.listen(3000, '127.0.0.1', () =>
  console.log('星象仪静态预览：http://127.0.0.1:3000/（仅本机）'),
);