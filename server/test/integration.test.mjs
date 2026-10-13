import assert from 'node:assert/strict';
import { test } from 'node:test';
import { spawn, execFile } from 'node:child_process';
import { mkdtemp, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { once } from 'node:events';
import { promisify } from 'node:util';
import { DatabaseSync } from 'node:sqlite';
import WebSocket from 'ws';

const root = path.resolve(import.meta.dirname, '../..');
const revision = 'integration-real-world-v1';
const password = 'Correct-horse-9476';
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

async function client(port) {
  const ws = new WebSocket(`ws://127.0.0.1:${port}/play`);
  const messages = [];
  ws.on('message', data => messages.push(JSON.parse(data)));
  await once(ws, 'open');
  return {
    ws, messages,
    send: value => ws.send(JSON.stringify(value)),
    async next(type, predicate = () => true, timeout = 15000) {
      const end = Date.now() + timeout;
      while (Date.now() < end) {
        const index = messages.findIndex(message => message.type === type && predicate(message));
        if (index >= 0) return messages.splice(index, 1)[0];
        await sleep(10);
      }
      throw Error(`Timed out awaiting ${type}; socket=${ws.readyState}; pending=${JSON.stringify(messages.map(message => ({ type: message.type, code: message.code })))}`);
    }
  };
}

test('real clients share authoritative movement and restart durable accounts', { timeout: 120000 }, async () => {
  const dir = await mkdtemp(path.join(tmpdir(), 'endless-server-'));
  const manifest = path.join(dir, 'manifest.json');
  const godotBinary = globalThis.process.env.GODOT_BINARY || path.join(root, '.tools/Godot.app/Contents/MacOS/Godot');
  const engineVersion = (await promisify(execFile)(godotBinary, ['--version'])).stdout.trim();
  const hub = JSON.parse(await readFile(path.join(root, 'config/floating_city.json'), 'utf8'));
  const hubSpawn = hub.center.map((value, index) => value + hub.spawn[index]);
  await writeFile(manifest, JSON.stringify({ protocol: 1, generator_version: 4, engine_version: engineVersion, content_revision: revision }));
  let process;
  const clients = [];
  const launch = async (args = [], env = {}) => {
    process = spawn(globalThis.process.execPath, ['server/index.mjs', ...args], {
      cwd: root,
      env: { ...globalThis.process.env, ENDLESS_DB: path.join(dir, 'world.sqlite'), ENDLESS_HOST: '127.0.0.1', PUBLIC_WORLD: '0', ALLOWED_ORIGINS: '', ENDLESS_PORT: '0', WORLD_SEED: '481516', NETWORK_MANIFEST_PATH: manifest, ...env }
    });
    let output = '';
    process.stdout.on('data', data => { output += data; });
    process.stderr.on('data', data => { output += data; });
    const end = Date.now() + 30000;
    while (Date.now() < end) {
      const match = output.match(/"event":"listening","port":(\d+)/);
      if (match) return Number(match[1]);
      if (process.exitCode !== null) throw Error(output);
      await sleep(20);
    }
    throw Error(`Server startup timeout: ${output}`);
  };
  const connect = async port => { const c = await client(port); clients.push(c); return c; };
  const stop = async () => { if (process.exitCode === null) { process.kill('SIGTERM'); await once(process, 'exit'); } };
  try {
    let port = await launch();
    const unauth = await connect(port);
    unauth.send({ type: 'input', seq: 1, direction: [1, 0] });
    assert.equal((await unauth.next('error')).code, 'authentication_required');
    const a = await connect(port), b = await connect(port);
    a.send({ type: 'register', username: 'Alice', password, class_id: 'mage', content_revision: revision });
    const first = await a.next('welcome');
    assert.equal(first.world.seed, '481516');
    assert.equal(first.player.profile.name, 'Alice');
    assert.equal(first.player.inventory.items.sanctum_sigil, 1);
    assert.deepEqual(first.player.position, hubSpawn);
    const initialChunk = await a.next('chunks');
    assert.equal(initialChunk.revision, revision);
    assert.equal(initialChunk.radius, 2);
    assert.equal(initialChunk.chunks.length, 1);
    assert.ok(initialChunk.regions.length > 0);
    assert.ok(initialChunk.regions.some(region => region.city?.floating_city));
    assert.equal(initialChunk.chunks[0].cells['@'], 'map');
    assert.equal(initialChunk.chunks[0].cells.v.length, 256);
    const receivedChunks = new Set([initialChunk.chunks[0].coordinate.join(',')]);
    while (receivedChunks.size < 25) {
      const packet = await a.next('chunks');
      for (const chunk of packet.chunks) receivedChunks.add(chunk.coordinate.join(','));
    }
    b.send({ type: 'register', username: 'Bob', password, class_id: 'sword', content_revision: revision });
    const second = await b.next('welcome');
    assert.notEqual(first.player.id, second.player.id);
    const together = await b.next('state', state => state.players.length === 2);
    assert.ok(together.players.some(player => player.id === first.player.id));
    assert.ok(together.players.every(player => !('inventory' in player) && !('token' in player)));
    a.send({ type: 'save', position: [999999, 999999], inventory: { gold_coin: 999999 } });
    assert.equal((await a.next('error')).code, 'unsupported_command');
    a.ws.send('{');
    assert.equal((await a.next('error')).code, 'invalid_message');
    a.send({ type: 'chunks', coordinates: [[999999, 999999]] });
    assert.equal((await a.next('error')).code, 'invalid_chunks');
    a.send({ type: 'input', seq: 1, direction: [0, 0], position: [99, 99] });
    assert.equal((await a.next('error')).code, 'invalid_input');
    a.send({ type: 'input', seq: 1, direction: [null, 0] });
    assert.equal((await a.next('error')).code, 'invalid_input');
    a.send({ type: 'input', seq: 1, direction: [100, 0] });
    assert.equal((await a.next('error')).code, 'invalid_input');
    a.send({ type: 'input', seq: 1, direction: [0, 1] });
    await sleep(300);
    a.send({ type: 'input', seq: 2, direction: [0, 0] });
    const moved = (await a.next('state', state => {
      const own = state.players.find(player => player.id === first.player.id);
      return own && own.position[1] > first.player.position[1] + .1;
    })).players.find(player => player.id === first.player.id);
    assert.ok(Math.hypot(moved.position[0] - first.player.position[0], moved.position[1] - first.player.position[1]) < 2);
    a.send({ type: 'input', seq: 2, direction: [0, -1] });
    assert.equal((await a.next('error')).code, 'stale_input');
    a.ws.close(); await once(a.ws, 'close');
    await sleep(200);
    const resume = await connect(port);
    resume.send({ type: 'resume', token: first.token, content_revision: revision });
    const restored = await resume.next('welcome');
    assert.equal(restored.player.id, first.player.id);
    assert.ok(restored.player.position[1] > first.player.position[1]);
    assert.deepEqual(restored.player.inventory, first.player.inventory);
    const duplicate = await connect(port);
    duplicate.send({ type: 'login', username: 'alice', password, content_revision: revision });
    const replacement = await duplicate.next('welcome');
    assert.equal((await resume.next('error')).code, 'session_replaced');
    await stop();
    port = await launch();
    const restarted = await connect(port);
    restarted.send({ type: 'resume', token: replacement.token, content_revision: revision });
    const durable = await restarted.next('welcome');
    assert.deepEqual(durable.world, first.world);
    assert.deepEqual(durable.player.position, replacement.player.position);
    assert.deepEqual(durable.player.build, first.player.build);
    const persistedChunk = await restarted.next('chunks', message => message.chunks[0].coordinate.join(',') === initialChunk.chunks[0].coordinate.join(','));
    assert.deepEqual(persistedChunk.chunks, initialChunk.chunks);
    assert.deepEqual(persistedChunk.regions, initialChunk.regions);
    const stale = await connect(port);
    stale.send({ type: 'resume', token: first.token, content_revision: revision });
    assert.equal((await stale.next('error')).code, 'invalid_credentials');
    const wrong = await connect(port);
    wrong.send({ type: 'login', username: 'alice', password: 'Definitely-wrong-9476', content_revision: revision });
    assert.equal((await wrong.next('error')).code, 'invalid_credentials');
    const mismatch = await connect(port);
    mismatch.send({ type: 'resume', token: replacement.token, content_revision: 'wrong' });
    assert.equal((await mismatch.next('error')).code, 'content_mismatch');
    const db = await readFile(path.join(dir, 'world.sqlite'));
    assert.ok(!db.includes(Buffer.from(password)));
    assert.ok(!db.includes(Buffer.from(replacement.token)));
    await stop();
    const { stdout } = await promisify(execFile)(godotBinary, ['--headless', '--path', root, '--script', 'server/test/collision_probe.gd'], { env: { ...globalThis.process.env, WORLD_SEED: '481516' } });
    const probe = JSON.parse(stdout.match(/COLLISION_PROBE (.*)/)[1]);
    const database = new DatabaseSync(path.join(dir, 'world.sqlite'));
    assert.ok(database.prepare('SELECT count(*) AS total FROM map_chunks').get().total >= 25);
    assert.ok(database.prepare('SELECT count(*) AS total FROM map_regions').get().total >= 1);
    const record = JSON.parse(database.prepare('SELECT record FROM players WHERE account_id = ?').get(first.player.id).record);
    record.position = probe.position;
    database.prepare('UPDATE players SET record = ? WHERE account_id = ?').run(JSON.stringify(record), first.player.id);
    const farRecord = JSON.parse(database.prepare('SELECT record FROM players WHERE account_id = ?').get(second.player.id).record);
    farRecord.position = [1000, 1000];
    database.prepare('UPDATE players SET record = ? WHERE account_id = ?').run(JSON.stringify(farRecord), second.player.id);
    database.close();
    port = await launch();
    const collision = await connect(port);
    collision.send({ type: 'resume', token: replacement.token, content_revision: revision });
    const wallStart = await collision.next('welcome');
    assert.deepEqual(wallStart.player.position, probe.position);
    for (let seq = 0; seq < 30; seq++) { collision.send({ type: 'input', seq, direction: probe.direction }); await sleep(50); }
    collision.send({ type: 'input', seq: 30, direction: [0, 0] });
    collision.messages.length = 0;
    const againstWall = (await collision.next('state')).players.find(player => player.id === first.player.id);
    assert.ok(Math.hypot(againstWall.position[0] - probe.position[0], againstWall.position[1] - probe.position[1]) < .7, 'Real generated wall must stop server movement');
    const far = await connect(port);
    far.send({ type: 'resume', token: second.token, content_revision: revision });
    const farWelcome = await far.next('welcome');
    assert.equal(farWelcome.players.length, 1, 'Distant players are excluded from public snapshots');
    const huge = await connect(port);
    huge.ws.send('x'.repeat(5000));
    assert.equal((await once(huge.ws, 'close'))[0], 1009);
    await stop();
    const boundaryOutput = await promisify(execFile)(godotBinary, ['--headless', '--path', root, '--script', 'server/test/chunk_crossing_probe.gd'], { env: { ...globalThis.process.env, WORLD_SEED: '481516' } });
    const boundary = JSON.parse(boundaryOutput.stdout.match(/CHUNK_CROSSING_PROBE (.*)/)[1]);
    const boundaryDb = new DatabaseSync(path.join(dir, 'world.sqlite'));
    const boundaryRecord = JSON.parse(boundaryDb.prepare('SELECT record FROM players WHERE account_id = ?').get(first.player.id).record);
    boundaryRecord.position = boundary.position;
    boundaryDb.prepare('UPDATE players SET record = ? WHERE account_id = ?').run(JSON.stringify(boundaryRecord), first.player.id);
    boundaryDb.close();
    port = await launch();
    const lagged = await connect(port);
    lagged.send({ type: 'resume', token: replacement.token, content_revision: revision });
    const beforeBoundary = await lagged.next('welcome');
    const oldCenter = beforeBoundary.player.position.map(value => Math.floor(value / 16));
    lagged.send({ type: 'input', seq: 1, direction: boundary.direction });
    const crossedState = await lagged.next('state', state => Math.floor(state.players.find(player => player.id === first.player.id).position[0] / 16) > oldCenter[0]);
    lagged.send({ type: 'input', seq: 2, direction: [0, 0] });
    lagged.send({ type: 'chunks', coordinates: [[oldCenter[0] - 2, oldCenter[1]]] });
    const crossed = crossedState.players.find(player => player.id === first.player.id);
    const currentCenter = crossed.position.map(value => Math.floor(value / 16));
    const currentEdge = [currentCenter[0] + 2, currentCenter[1]];
    lagged.send({ type: 'chunks', coordinates: [[oldCenter[0] - 2, oldCenter[1]], currentEdge] });
    await lagged.next('chunks', packet => packet.chunks.some(chunk => chunk.coordinate.join(',') === currentEdge.join(',')));
    await sleep(200);
    assert.equal(lagged.ws.readyState, WebSocket.OPEN);
    assert.ok(!lagged.messages.some(message => message.type === 'error'), 'Legitimate lagged boundary requests must not emit a fatal client error');
    assert.ok(lagged.messages.some(message => message.type === 'state'), 'Authoritative movement continues after lagged map requests');
    await stop();
    await writeFile(manifest, JSON.stringify({ protocol: 1, generator_version: 4, content_revision: 'changed-content' }));
    await assert.rejects(launch(), /Stored world content differs/);
    port = await launch(['--upgrade-content']);
    const upgraded = await connect(port);
    upgraded.send({ type: 'resume', token: replacement.token, content_revision: 'changed-content' });
    const upgradeWelcome = await upgraded.next('welcome');
    assert.equal(upgradeWelcome.world.id, first.world.id);
    assert.equal(upgradeWelcome.world.seed, first.world.seed);
    assert.equal(upgradeWelcome.world.content_revision, 'changed-content');
    await stop();
    await writeFile(manifest, JSON.stringify({ protocol: 1, generator_version: 4, content_revision: 'changed-content', inputs: { 'scripts/world.gd': '0'.repeat(64) } }));
    await assert.rejects(launch(), /Network manifest is stale/);
    await writeFile(manifest, JSON.stringify({ protocol: 1, generator_version: 6, engine_version: engineVersion, content_revision: 'edition-six' }));
    await assert.rejects(launch(['--upgrade-content']), /Stored world requires its original protocol and generator edition/);
    port = await launch([], { ENDLESS_DB: path.join(dir, 'edition-six.sqlite') });
    const six = await connect(port);
    six.send({ type: 'register', username: 'EditionSix', password, class_id: 'sword', content_revision: 'edition-six' });
    const sixWelcome = await six.next('welcome');
    assert.equal(sixWelcome.world.generator_version, 6);
    assert.deepEqual(sixWelcome.player.position, hubSpawn);
    const sixMap = await six.next('chunks');
    assert.equal(sixMap.chunks[0].cells.v.length, 256);
  } finally {
    for (const c of clients) c.ws.terminate();
    if (process) await stop();
    await rm(dir, { recursive: true, force: true });
  }
});
