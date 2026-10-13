import assert from 'node:assert/strict';
import { test } from 'node:test';
import { mkdtemp, rm, readFile, realpath, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { execFile, spawn } from 'node:child_process';
import { promisify } from 'node:util';
import { once } from 'node:events';
import WebSocket from 'ws';
import { assembleRuntime } from '../assemble_runtime.mjs';

const root = path.resolve(import.meta.dirname, '../..');
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

test('assembled deployment starts real authority without workspace resource fallback', { timeout: 90000 }, async () => {
  const dir = await realpath(await mkdtemp(path.join(tmpdir(), 'endless-runtime-')));
  let child, ws;
  try {
    const copied = await assembleRuntime(root, dir);
    const manifest = JSON.parse(await readFile(path.join(dir, 'config/network_manifest.json'), 'utf8'));
    for (const relative of Object.keys(manifest.inputs)) assert.ok(copied.includes(relative), `Missing authority input ${relative}`);
    for (const relative of copied) assert.ok((await realpath(path.join(dir, relative))).startsWith(dir + path.sep), `Runtime resource escapes isolated assembly: ${relative}`);
    assert.ok(copied.includes('assets/world_construction/catalog.json'));
    assert.ok(copied.includes('assets/lore/catalog.json'));
    assert.ok(copied.every(relative => !relative.includes('node_modules') && !relative.startsWith('server/data/') && !relative.startsWith('import_assets/')));
    await assert.rejects(stat(path.join(dir, 'server/data')));
    const npm = path.join(path.dirname(globalThis.process.execPath), '../lib/node_modules/npm/bin/npm-cli.js');
    await promisify(execFile)(globalThis.process.execPath, [npm, 'ci', '--omit=dev', '--ignore-scripts'], { cwd: path.join(dir, 'server') });
    assert.ok((await realpath(path.join(dir, 'server/node_modules/ws'))).startsWith(dir));
    child = spawn(globalThis.process.execPath, ['server/index.mjs'], {
      cwd: dir,
      env: { ...globalThis.process.env, ENDLESS_HOST: '127.0.0.1', PUBLIC_WORLD: '0', ALLOWED_ORIGINS: '', ENDLESS_PORT: '0', ENDLESS_DB: path.join(dir, 'database/world.sqlite'), GODOT_BINARY: globalThis.process.env.GODOT_BINARY || path.join(root, '.tools/Godot.app/Contents/MacOS/Godot'), NETWORK_MANIFEST_PATH: path.join(dir, 'config/network_manifest.json') }
    });
    let output = '';
    child.stdout.on('data', data => { output += data; });
    child.stderr.on('data', data => { output += data; });
    let port;
    const deadline = Date.now() + 30000;
    while (Date.now() < deadline) {
      const match = output.match(/"event":"listening","port":(\d+)/);
      if (match) { port = Number(match[1]); break; }
      if (child.exitCode !== null) throw Error(output);
      await sleep(20);
    }
    assert.ok(port, `Assembled gateway startup timed out: ${output}`);
    ws = new WebSocket(`ws://127.0.0.1:${port}/play`);
    const messages = [];
    ws.on('message', bytes => messages.push(JSON.parse(bytes)));
    await once(ws, 'open');
    ws.send(JSON.stringify({ type: 'register', username: 'AssemblyPlayer', password: 'Assembly-test-password-9476', class_id: 'mage', content_revision: manifest.content_revision }));
    const end = Date.now() + 15000;
    while (Date.now() < end && (!messages.some(message => message.type === 'welcome') || !messages.some(message => message.type === 'chunks'))) await sleep(20);
    const welcome = messages.find(message => message.type === 'welcome');
    assert.ok(welcome, `Assembled character initialization failed: ${output}`);
    assert.equal(welcome.player.inventory.items.sanctum_sigil, 1);
    assert.equal(welcome.player.build.class_id, 'mage');
    const hub = JSON.parse(await readFile(path.join(dir, 'config/floating_city.json'), 'utf8'));
    assert.deepEqual(welcome.player.position, hub.center.map((value, index) => value + hub.spawn[index]));
    const chunks = messages.find(message => message.type === 'chunks');
    assert.ok(chunks, `Assembled World chunk generation failed: ${output}`);
    assert.equal(chunks.chunks[0].cells.v.length, 256);
    assert.ok(chunks.regions.length > 0);
    assert.ok(chunks.regions.some(region => region.city?.floating_city));
    assert.equal(chunks.revision, manifest.content_revision);
  } finally {
    ws?.terminate();
    if (child && child.exitCode === null) { child.kill('SIGTERM'); await once(child, 'exit'); }
    await rm(dir, { recursive: true, force: true });
  }
});
