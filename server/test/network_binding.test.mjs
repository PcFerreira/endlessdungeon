import assert from 'node:assert/strict';
import { test } from 'node:test';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { hostname, networkInterfaces, tmpdir } from 'node:os';
import path from 'node:path';
import { spawn, execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { once } from 'node:events';
import WebSocket from 'ws';

const root = path.resolve(import.meta.dirname, '../..');
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

async function upgrade(port, origin, address = '127.0.0.1') {
  const ws = new WebSocket(`ws://${address}:${port}/play`, origin === undefined ? {} : { origin });
  try {
    return await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(Error('WebSocket handshake timed out')), 5000);
      ws.on('error', cause => { clearTimeout(timer); reject(cause); });
      ws.once('open', () => { clearTimeout(timer); resolve(101); });
      ws.once('unexpected-response', (_request, response) => {
        clearTimeout(timer); response.resume(); resolve(response.statusCode);
      });
    });
  } finally {
    ws.terminate();
  }
}

test('all-interface development access and explicit public origins use real handshakes', { timeout: 90000 }, async () => {
  const dir = await mkdtemp(path.join(tmpdir(), 'endless-binding-'));
  const manifestPath = path.join(dir, 'manifest.json');
  const godot = globalThis.process.env.GODOT_BINARY || path.join(root, '.tools/Godot.app/Contents/MacOS/Godot');
  const version = (await promisify(execFile)(godot, ['--version'])).stdout.trim();
  const ruby = 'require ARGV.shift; print JSON.generate(NetworkManifest.new(ARGV[0], engine_version: ARGV[1]).document)';
  const document = (await promisify(execFile)('ruby', ['-e', ruby, path.join(root, 'tools/build_network_manifest.rb'), root, version])).stdout;
  await writeFile(manifestPath, document);
  let child, count = 0;
  const stop = async () => {
    if (child && child.exitCode === null) { child.kill('SIGTERM'); await once(child, 'exit'); }
  };
  const launch = async overrides => {
    const env = { ...globalThis.process.env, ENDLESS_PORT: '0', ENDLESS_DB: path.join(dir, `world-${++count}.sqlite`), NETWORK_MANIFEST_PATH: manifestPath, PUBLIC_WORLD: '0', ALLOWED_ORIGINS: '', GODOT_BINARY: godot };
    delete env.ENDLESS_HOST;
    Object.assign(env, overrides);
    child = spawn(globalThis.process.execPath, ['server/index.mjs'], { cwd: root, env });
    let output = '';
    child.stdout.on('data', data => { output += data; });
    child.stderr.on('data', data => { output += data; });
    const end = Date.now() + 30000;
    while (Date.now() < end) {
      const line = output.split('\n').find(value => value.startsWith('{"event":"listening"'));
      if (line) return JSON.parse(line);
      if (child.exitCode !== null) throw Error(output);
      await sleep(20);
    }
    throw Error(`Gateway startup timed out: ${output}`);
  };
  try {
    let ready = await launch({});
    assert.equal(ready.host, '0.0.0.0');
    const lan = Object.values(networkInterfaces()).flat().find(address => address.family === 'IPv4' && !address.internal);
    assert.ok(lan, 'LAN acceptance needs a current non-loopback IPv4 interface');
    const health = await fetch(`http://${lan.address}:${ready.port}/healthz`, { signal: AbortSignal.timeout(5000) });
    assert.equal(health.status, 200);
    assert.equal((await health.json()).ready, true);
    assert.equal(await upgrade(ready.port, `http://${lan.address}:8000`, lan.address), 101);
    assert.equal(await upgrade(ready.port, 'http://localhost:8000'), 101);
    assert.equal(await upgrade(ready.port, new URL(`http://${hostname()}:8000`).origin), 101);
    assert.equal(await upgrade(ready.port, undefined), 101);
    assert.equal(await upgrade(ready.port, 'https://unrelated.example.invalid'), 403);
    assert.equal(await upgrade(ready.port, 'http://localhost:8001'), 403);
    await stop();

    ready = await launch({ ENDLESS_HOST: '127.0.0.1', PUBLIC_WORLD: '1', ALLOWED_ORIGINS: 'https://play.example.invalid' });
    assert.equal(await upgrade(ready.port, 'https://play.example.invalid'), 101);
    assert.equal(await upgrade(ready.port, undefined), 403);
    assert.equal(await upgrade(ready.port, 'http://localhost:8000'), 403);
    assert.equal(await upgrade(ready.port, 'null'), 403);
    await stop();

    ready = await launch({ ENDLESS_HOST: '127.0.0.1', ALLOWED_ORIGINS: 'http://localhost:8000' });
    assert.equal(await upgrade(ready.port, 'http://localhost:8000'), 101);
    assert.equal(await upgrade(ready.port, undefined), 403);
    assert.equal(await upgrade(ready.port, `http://${lan.address}:8000`), 403);
    await stop();
    await assert.rejects(launch({ ENDLESS_HOST: '127.0.0.1', PUBLIC_WORLD: '1' }), /Public binding requires ALLOWED_ORIGINS/);
  } finally {
    await stop();
    await rm(dir, { recursive: true, force: true });
  }
});
