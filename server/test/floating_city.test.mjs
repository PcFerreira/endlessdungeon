import assert from 'node:assert/strict';
import { test } from 'node:test';
import { spawn, execFile } from 'node:child_process';
import { once } from 'node:events';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { promisify } from 'node:util';
import WebSocket from 'ws';

const root = path.resolve(import.meta.dirname, '../..');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));

async function connect(port) {
  const socket = new WebSocket(`ws://127.0.0.1:${port}/play`), messages = [];
  socket.on('message', bytes => messages.push(JSON.parse(bytes)));
  await once(socket, 'open');
  return {
    socket, send: message => socket.send(JSON.stringify(message)),
    async next(type, predicate = () => true) {
      const deadline = Date.now() + 20000;
      while (Date.now() < deadline) {
        const index = messages.findIndex(message => message.type === type && predicate(message));
        if (index >= 0) return messages.splice(index, 1)[0];
        await pause(10);
      }
      throw Error(`Missing ${type}; socket=${socket.readyState}; pending=${messages.map(m => m.type + ':' + (m.code || '')).join(',')}`);
    }
  };
}

test('fresh public accounts share Lanternwake and travel only through authoritative gates', { timeout: 120000 }, async () => {
  const directory = await mkdtemp(path.join(tmpdir(), 'endless-floating-hub-'));
  const manifest = path.join(directory, 'manifest.json');
  const engine = process.env.GODOT_BINARY || path.join(root, '.tools/Godot.app/Contents/MacOS/Godot');
  const version = (await promisify(execFile)(engine, ['--version'])).stdout.trim();
  await writeFile(manifest, JSON.stringify({ protocol: 1, generator_version: 4, engine_version: version, content_revision: 'floating-hub-fixture' }));
  const clients = [];
  let gateway;
  const launch = async () => {
    gateway = spawn(process.execPath, ['server/index.mjs'], { cwd: root, env: { ...process.env, NETWORK_MANIFEST_PATH: manifest, ENDLESS_HOST: '127.0.0.1', PUBLIC_WORLD: '0', ALLOWED_ORIGINS: '', ENDLESS_PORT: '0', ENDLESS_DB: path.join(directory, 'world.sqlite'), WORLD_SEED: '12345' } });
    let output = '';
    gateway.stdout.on('data', bytes => { output += bytes; });
    gateway.stderr.on('data', bytes => { output += bytes; });
    const deadline = Date.now() + 30000;
    while (Date.now() < deadline) {
      const match = output.match(/"event":"listening","port":(\d+)/);
      if (match) return Number(match[1]);
      if (gateway.exitCode !== null) throw Error(output);
      await pause(20);
    }
    throw Error(output);
  };
  const stop = async () => {
    if (gateway && gateway.exitCode === null) { gateway.kill('SIGTERM'); await once(gateway, 'exit'); }
  };
  const client = async port => { const value = await connect(port); clients.push(value); return value; };
  try {
    let port = await launch();
    const unauthenticated = await client(port);
    unauthenticated.send({ type: 'hub_travel', destination: 'world' });
    assert.equal((await unauthenticated.next('error')).code, 'authentication_required');
    const first = await client(port), second = await client(port);
    const register = (value, username) => value.send({ type: 'register', username, password: 'Floating-city-only-123', class_id: 'mage', content_revision: 'floating-hub-fixture' });
    register(first, 'LanternOne');
    const one = await first.next('welcome');
    assert.deepEqual(one.player.position, [32, -4058]);
    const map = await first.next('chunks', packet => packet.regions.some(region => region.city?.floating_city));
    const hub = map.regions.find(region => region.city?.floating_city).city;
    assert.equal(hub.name, 'Lanternwake');
    assert.equal(hub.theme, 'halloween');
    register(second, 'LanternTwo');
    const two = await second.next('welcome');
    assert.deepEqual(two.player.position, one.player.position);
    assert.equal((await first.next('state', message => message.players.length === 2)).players.length, 2);
    first.send({ type: 'hub_travel', destination: 'world' });
    assert.equal((await first.next('error')).code, 'hub_travel_refused');
    first.send({ type: 'hub_travel', destination: 'world', position: [0, 0] });
    assert.equal((await first.next('error')).code, 'invalid_hub_travel');
    assert.equal(first.socket.readyState, WebSocket.OPEN);
    let sequence = 0;
    const deadline = Date.now() + 10000;
    let point = one.player.position;
    while (Date.now() < deadline && Math.abs(point[1] + 4041) > 1) {
      first.send({ type: 'input', seq: ++sequence, direction: [0, 1] });
      const state = await first.next('state', message => message.players.some(player => player.id === one.player.id));
      point = state.players.find(player => player.id === one.player.id).position;
      await pause(50);
    }
    assert.ok(Math.abs(point[1] + 4041) <= 1, 'Real movement must reach the departure dock');
    first.send({ type: 'input', seq: ++sequence, direction: [0, 0] });
    first.send({ type: 'hub_travel', destination: 'world' });
    const departed = await first.next('hub_travel');
    assert.deepEqual(departed.player.position, [64, 67]);
    await second.next('state', message => message.players.length === 1);
    first.send({ type: 'hub_travel', destination: 'hub' });
    const returned = await first.next('hub_travel');
    assert.deepEqual(returned.player.position, one.player.position);
    await second.next('state', message => message.players.length === 2);
    for (const value of clients) value.socket.close();
    await pause(150);
    await stop();
    port = await launch();
    const resumed = await client(port);
    resumed.send({ type: 'resume', token: one.token, content_revision: 'floating-hub-fixture' });
    assert.deepEqual((await resumed.next('welcome')).player.position, one.player.position);
    resumed.socket.close();
  } finally {
    for (const value of clients) value.socket.terminate();
    await stop();
    await rm(directory, { recursive: true, force: true });
  }
});
