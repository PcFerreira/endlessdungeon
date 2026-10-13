import http from 'node:http';
import { isIP } from 'node:net';
import path from 'node:path';
import { hostname, networkInterfaces } from 'node:os';
import { readFileSync } from 'node:fs';
import { randomBytes, randomUUID, scrypt, timingSafeEqual, createHash } from 'node:crypto';
import { promisify } from 'node:util';
import { WebSocketServer, WebSocket } from 'ws';
import { openDatabase, tokenHash } from './database.mjs';
import { startWorker } from './worker.mjs';

const root = path.resolve(import.meta.dirname, '..');
const hashPassword = promisify(scrypt);
const manifestPath = process.env.NETWORK_MANIFEST_PATH || path.join(root, 'config/network_manifest.json');
const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
if (manifest.protocol !== 1 || ![4, 5, 6, 7].includes(manifest.generator_version) || typeof manifest.content_revision !== 'string' || !manifest.content_revision.length) throw Error('Invalid network manifest');
for (const [filename, expected] of Object.entries(manifest.inputs || {})) {
  if (path.isAbsolute(filename) || filename.split('/').includes('..')) throw Error('Invalid manifest input');
  const actual = createHash('sha256').update(readFileSync(path.join(root, filename))).digest('hex');
  if (actual !== expected) throw Error(`Network manifest is stale: ${filename}`);
}
const store = openDatabase(process.env.ENDLESS_DB || path.join(root, 'server/data/world.sqlite'), manifest, process.env.WORLD_SEED, process.argv.includes('--upgrade-content'));
const { db, world } = store;
const maxPlayers = integerEnv('MAX_PLAYERS', 32, 1, 128);
const maxConnections = maxPlayers + 16;
const radius = integerEnv('INTEREST_RADIUS', 80, 10, 200);
const host = process.env.ENDLESS_HOST || '0.0.0.0';
const publicMode = process.env.PUBLIC_WORLD === '1';
const configuredOrigins = (process.env.ALLOWED_ORIGINS || '').split(',').map(value => value.trim()).filter(Boolean).map(value => new URL(value).origin);
if (publicMode && !configuredOrigins.length) throw Error('Public binding requires ALLOWED_ORIGINS');
const localHosts = ['127.0.0.1', 'localhost', hostname(), ...Object.values(networkInterfaces()).flat().filter(address => address.family === 'IPv4').map(address => address.address)];
const allowedOrigins = new Set(configuredOrigins.length ? configuredOrigins : localHosts.map(value => new URL(`http://${value}:8000`).origin));
const allowNativeOrigin = !publicMode && !configuredOrigins.length;
const publicWorld = { id: world.id, seed: world.seed, generator_version: world.generator_version, content_revision: world.content_revision };
let shuttingDown = false, worker, server, heartbeat, authJobs = 0, saveAt = 0, latestTick = 0;
const clients = new Set(), online = new Map(), records = new Map(), locks = new Map(), addressBuckets = new Map();
const dummySalt = randomBytes(16).toString('hex');
const dummyHash = await hashPassword('Dummy-password-never-valid', dummySalt, 64);
const authorityFailure = error => {
  if (shuttingDown) return;
  console.error(JSON.stringify({ event: 'authority_failure', message: error.message }));
  shutdown(1);
};
worker = await startWorker(root, world, state => {
  latestTick = state.tick;
  for (const record of state.players) records.set(record.id, record);
  for (const client of clients) {
    if (!client.id || !records.has(client.id) || client.ws.readyState !== WebSocket.OPEN) continue;
    const own = records.get(client.id);
    const players = state.players.filter(player => player.id === client.id || distance(own.position, player.position) <= radius).map(publicPlayer);
    send(client, { type: 'state', tick: state.tick, players });
    const center = chunkAt(own.position);
    if (client.chunkCenter !== center.join(',')) {
      client.chunkCenter = center.join(',');
      queueChunks(client, around(center)).catch(cause => chunkFailure(client, cause));
    }
  }
  if (Date.now() - saveAt >= 1000) {
    saveAt = Date.now();
    try { store.save([...records.values()]); } catch (error) { authorityFailure(error); }
  }
}, authorityFailure);

server = http.createServer((request, response) => {
  if (request.url !== '/healthz' || request.method !== 'GET') { response.writeHead(404); response.end(); return; }
  response.writeHead(shuttingDown ? 503 : 200, { 'content-type': 'application/json', 'cache-control': 'no-store' });
  response.end(JSON.stringify({ ready: !shuttingDown, protocol: 1, players: online.size, tick: latestTick }));
});
const sockets = new WebSocketServer({ noServer: true, maxPayload: 4096, perMessageDeflate: false });
server.on('upgrade', (request, socket, head) => {
  if (shuttingDown || !['/play', '/ws'].includes(request.url) || clients.size >= maxConnections || (!allowedOrigins.has(request.headers.origin) && !(allowNativeOrigin && !request.headers.origin))) {
    socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n'); return;
  }
  let address = request.socket.remoteAddress || 'unknown';
  const forwarded = request.headers['x-forwarded-for'];
  if (process.env.TRUST_PROXY === '1' && typeof forwarded === 'string' && isIP(forwarded.trim())) address = forwarded.trim();
  if ([...clients].filter(client => client.address === address).length >= 12 || !consume(address, 'connect', 20, 0.5)) {
    socket.end('HTTP/1.1 429 Too Many Requests\r\nConnection: close\r\n\r\n'); return;
  }
  sockets.handleUpgrade(request, socket, head, ws => sockets.emit('connection', ws, address));
});
sockets.on('connection', (ws, address) => {
  const client = { ws, address, id: null, seq: -1, inputAt: 0, inputs: 0, inputWindow: Date.now(), busy: false, alive: true, messages: 0, messageWindow: Date.now(), sentChunks: new Set(), sentRegions: new Set(), chunkQueue: Promise.resolve(), chunkCenter: null };
  clients.add(client);
  const authTimeout = setTimeout(() => { if (!client.id) { error(client, 'authentication_timeout', 'Sign in before joining the world.'); ws.close(1008); } }, 15000);
  ws.on('pong', () => { client.alive = true; });
  ws.on('error', () => {});
  ws.on('close', () => {
    clearTimeout(authTimeout); clients.delete(client);
    if (client.id && online.get(client.id) === client) {
      online.delete(client.id);
      serialize(client.id, async () => {
        const result = await worker.request({ type: 'leave', id: client.id });
        if (result.player?.id) store.save([result.player]);
        records.delete(client.id);
      }).catch(authorityFailure);
    }
  });
  ws.on('message', (bytes, binary) => {
    if (Date.now() - client.messageWindow >= 1000) { client.messageWindow = Date.now(); client.messages = 0; }
    if (++client.messages > 90) { error(client, 'rate_limit', 'Too many messages.'); ws.close(1008); return; }
    if (binary) { error(client, 'invalid_message', 'Use JSON text messages.'); return; }
    let message;
    try { message = JSON.parse(bytes.toString()); } catch { error(client, 'invalid_message', 'Malformed JSON.'); return; }
    if (!message || Array.isArray(message) || typeof message !== 'object') { error(client, 'invalid_message', 'Expected a JSON object.'); return; }
    if (message.type === 'input') { input(client, message); return; }
    if (message.type === 'hub_travel') { travel(client, message).catch(authorityFailure); return; }
    if (message.type === 'chunks') {
      if (!client.id) { error(client, 'authentication_required', 'Sign in first.'); return; }
      const center = chunkAt(records.get(client.id).position);
      if (!Array.isArray(message.coordinates) || !message.coordinates.length || message.coordinates.length > 25 || message.coordinates.some(c => !Array.isArray(c) || c.length !== 2 || !c.every(Number.isSafeInteger) || c.some(value => Math.abs(value) > 62502)) || Object.keys(message).some(key => !['type', 'coordinates'].includes(key))) { error(client, 'invalid_chunks', 'Request at most 25 valid map chunk coordinates.'); return; }
      if (!consume(address, 'chunks', 6, 2)) { error(client, 'rate_limit', 'Map requests are too frequent.'); return; }
      const nearby = message.coordinates.filter(c => Math.abs(c[0] - center[0]) <= 2 && Math.abs(c[1] - center[1]) <= 2);
      if (nearby.length) queueChunks(client, nearby, true).catch(cause => chunkFailure(client, cause));
      return;
    }
    if (message.type === 'bye') { ws.close(1000); return; }
    if (!['register', 'login', 'resume'].includes(message.type)) { error(client, 'unsupported_command', 'This world accepts authentication and movement input only.'); return; }
    if (client.id || client.busy) { error(client, 'already_authenticated', 'Authentication is already active.'); return; }
    if (message.content_revision !== manifest.content_revision || (message.protocol !== undefined && message.protocol !== 1)) { error(client, 'content_mismatch', 'Client and world content editions differ.'); return; }
    if (!consume(address, 'auth', 8, 0.1) || authJobs >= 4) { error(client, 'rate_limit', 'Please wait before signing in again.'); return; }
    client.busy = true; authJobs += 1;
    authenticate(client, message).catch(cause => {
      error(client, cause.code || 'server_error', cause.code ? cause.message : 'The world could not complete sign in.');
      if (!cause.code) console.error(JSON.stringify({ event: 'authentication_failure', message: 'Internal authentication or storage error' }));
    }).finally(() => { client.busy = false; authJobs -= 1; });
  });
});
heartbeat = setInterval(() => {
  for (const client of clients) {
    if (!client.alive) { client.ws.terminate(); continue; }
    client.alive = false; client.ws.ping();
  }
  const now = Date.now();
  for (const [key, bucket] of addressBuckets) if (now - bucket.at > 600000) addressBuckets.delete(key);
}, 15000);
await new Promise((resolve, reject) => { server.once('error', reject); server.listen(integerEnv('ENDLESS_PORT', 8080, 0, 65535), host, resolve); });
console.log(JSON.stringify({ event: 'listening', port: server.address().port, host: server.address().address, world_id: world.id, generator_version: world.generator_version }));
process.on('SIGTERM', () => shutdown(0));
process.on('SIGINT', () => shutdown(0));

function integerEnv(key, fallback, min, max) {
  const value = Number(process.env[key] ?? fallback);
  if (!Number.isInteger(value) || value < min || value > max) throw Error(`Invalid ${key}`);
  return value;
}
function failure(code, message) { return Object.assign(Error(message), { code }); }
function distance(a, b) { return Math.hypot(a[0] - b[0], a[1] - b[1]); }
function chunkAt(position) { return position.map(value => Math.floor(value / 16)); }
function around([x, z]) {
  const coordinates = [];
  for (let dx = -2; dx <= 2; dx++) for (let dz = -2; dz <= 2; dz++) coordinates.push([x + dx, z + dz]);
  return coordinates;
}
function chunkFailure(client, cause) {
  if (client.id && online.get(client.id) === client && client.ws.readyState === WebSocket.OPEN) authorityFailure(cause);
}
function queueChunks(client, coordinates, repeat = false) {
  client.chunkQueue = client.chunkQueue.then(async () => {
    for (const coordinate of coordinates) {
      if (!client.id || client.ws.readyState !== WebSocket.OPEN) return;
      const key = coordinate.join(',');
      if (!repeat && client.sentChunks.has(key)) continue;
      const center = chunkAt(records.get(client.id).position);
      if (Math.abs(coordinate[0] - center[0]) > 2 || Math.abs(coordinate[1] - center[1]) > 2) continue;
      let cached = store.mapChunk(coordinate);
      if (!cached) {
        const result = await worker.request({ type: 'chunks', id: client.id, coordinates: [coordinate] });
        store.saveChunks(result); cached = store.mapChunk(coordinate);
      }
      const regionKey = cached.region.coordinate.join(',');
      const regions = client.sentRegions.has(regionKey) ? [] : [cached.region.data];
      const payload = JSON.stringify({ type: 'chunks', revision: manifest.content_revision, chunks: [cached.chunk], regions, radius: 2 });
      if (Buffer.byteLength(payload) > 1024 * 1024) throw Error('Map chunk exceeds the 1 MiB wire limit');
      if (client.ws.readyState !== WebSocket.OPEN) return;
      await new Promise((resolve, reject) => client.ws.send(payload, cause => cause ? reject(cause) : resolve()));
      client.sentChunks.add(key); client.sentRegions.add(regionKey);
    }
    if (client.sentChunks.size > 400) client.sentChunks = new Set([...client.sentChunks].slice(-100));
    if (client.sentRegions.size > 100) client.sentRegions = new Set([...client.sentRegions].slice(-25));
  });
  return client.chunkQueue;
}
function publicPlayer(player) {
  const { id, username, class_id, profile, position, heading } = player;
  return { id, username, class_id, profile, position, heading };
}
function send(client, value) {
  if (client.ws.readyState !== WebSocket.OPEN) return;
  if (client.ws.bufferedAmount > 2 * 1024 * 1024) { client.ws.close(1008, 'Slow connection'); return; }
  client.ws.send(JSON.stringify(value));
}
function error(client, code, message) { send(client, { type: 'error', code, message }); }
function consume(address, category, capacity, refill) {
  const key = `${category}:${address}`, now = Date.now();
  if (!addressBuckets.has(key) && addressBuckets.size >= 10000) return false;
  const bucket = addressBuckets.get(key) || { tokens: capacity, at: now };
  bucket.tokens = Math.min(capacity, bucket.tokens + (now - bucket.at) / 1000 * refill); bucket.at = now;
  addressBuckets.set(key, bucket);
  if (bucket.tokens < 1) return false;
  bucket.tokens -= 1; return true;
}
function serialize(id, action) {
  const prior = locks.get(id) || Promise.resolve();
  const current = prior.catch(() => {}).then(action);
  locks.set(id, current);
  current.finally(() => { if (locks.get(id) === current) locks.delete(id); }).catch(() => {});
  return current;
}
async function travel(client, message) {
  if (!client.id) { error(client, 'authentication_required', 'Sign in first.'); return; }
  if (!['world', 'hub'].includes(message.destination) || Object.keys(message).some(key => !['type', 'destination'].includes(key))) { error(client, 'invalid_hub_travel', 'Choose the Worldgate destination.'); return; }
  if (!consume(client.id, 'hub_travel', 4, 1)) { error(client, 'hub_travel_refused', 'Wait a moment before using the Worldgate again.'); return; }
  await serialize(client.id, async () => {
    if (online.get(client.id) !== client || client.ws.readyState !== WebSocket.OPEN) return;
    const result = await worker.request({ type: 'hub_travel', id: client.id, destination: message.destination });
    if (result.refused) { error(client, 'hub_travel_refused', result.refused); return; }
    records.set(client.id, result.player);
    store.save([result.player]);
    client.sentChunks.clear();
    client.sentRegions.clear();
    client.chunkCenter = '';
    send(client, { type: 'hub_travel', destination: message.destination, player: publicPlayer(result.player) });
  });
}

function input(client, message) {
  if (!client.id) { error(client, 'authentication_required', 'Sign in first.'); return; }
  const d = message.direction;
  if (Object.keys(message).some(key => !['type', 'seq', 'direction'].includes(key)) || !Number.isSafeInteger(message.seq) || message.seq < 0 || !Array.isArray(d) || d.length !== 2 || !d.every(Number.isFinite) || Math.hypot(...d) > 1.00001) { error(client, 'invalid_input', 'Supply a sequence and a direction with length at most one.'); return; }
  if (message.seq <= client.seq) { error(client, 'stale_input', 'Input sequences must increase.'); return; }
  const now = Date.now();
  if (now - client.inputWindow >= 1000) { client.inputWindow = now; client.inputs = 0; }
  if (++client.inputs > 40) { error(client, 'rate_limit', 'Movement input exceeds 40 updates per second.'); return; }
  client.seq = message.seq;
  worker.send({ type: 'input', id: client.id, direction: d });
}
async function authenticate(client, message) {
  let account, token;
  if (message.type === 'resume') {
    if (typeof message.token !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(message.token)) throw failure('invalid_credentials', 'Credentials are invalid or expired.');
    account = db.prepare('SELECT accounts.* FROM sessions JOIN accounts ON sessions.account_id = accounts.id WHERE sessions.token_hash = ? AND sessions.expires_at > ?').get(tokenHash(message.token), Date.now());
    if (!account) throw failure('invalid_credentials', 'Credentials are invalid or expired.');
    token = message.token;
  } else {
    if (typeof message.username !== 'string' || !/^[A-Za-z0-9_]{3,24}$/.test(message.username) || typeof message.password !== 'string' || message.password.length < 12 || message.password.length > 128) throw failure('invalid_credentials', 'Use a 3-24 character username and a 12-128 character password.');
    const usernameKey = message.username.toLowerCase();
    account = db.prepare('SELECT * FROM accounts WHERE username_key = ?').get(usernameKey);
    if (message.type === 'register') {
      if (account) throw failure('username_unavailable', 'Choose another username.');
      if (!['mage', 'sword', 'spellsword'].includes(message.class_id)) throw failure('invalid_class', 'Choose a supported class.');
      const salt = randomBytes(16).toString('hex');
      const hash = (await hashPassword(message.password, salt, 64)).toString('hex');
      account = { id: randomUUID(), username: message.username, username_key: usernameKey, password_salt: salt, password_hash: hash, class_id: message.class_id, created_at: Date.now() };
    } else {
      const hash = await hashPassword(message.password, account?.password_salt || dummySalt, 64);
      const expected = account ? Buffer.from(account.password_hash, 'hex') : dummyHash;
      if (!timingSafeEqual(hash, expected) || !account) throw failure('invalid_credentials', 'Credentials are invalid or expired.');
    }
    token = randomBytes(32).toString('base64url');
  }
  await serialize(account.id, async () => {
    if (client.ws.readyState !== WebSocket.OPEN) return;
    if (online.size >= maxPlayers && !online.has(account.id)) throw failure('world_full', 'The world is full.');
    const previous = online.get(account.id);
    let record = records.get(account.id);
    if (previous) {
      const snapshot = await worker.request({ type: 'snapshot' });
      record = snapshot.players.find(player => player.id === account.id) || record;
    }
    if (!record) {
      const stored = db.prepare('SELECT record FROM players WHERE account_id = ? AND world_id = ?').get(account.id, world.id);
      record = stored ? JSON.parse(stored.record) : {};
    }
    const result = await worker.request({ type: 'join', id: account.id, username: account.username, class_id: account.class_id, record });
    record = result.player;
    try {
      store.transaction(() => {
        if (message.type === 'register') db.prepare('INSERT INTO accounts VALUES (?, ?, ?, ?, ?, ?, ?)').run(account.id, account.username, account.username_key, account.password_salt, account.password_hash, account.class_id, account.created_at);
        db.prepare('INSERT INTO players VALUES (?, ?, ?, ?) ON CONFLICT(account_id) DO UPDATE SET record = excluded.record, updated_at = excluded.updated_at').run(account.id, world.id, JSON.stringify(record), Date.now());
        if (message.type !== 'resume') {
          db.prepare('DELETE FROM sessions WHERE account_id = ?').run(account.id);
          db.prepare('INSERT INTO sessions VALUES (?, ?, ?)').run(tokenHash(token), account.id, Date.now() + 7 * 86400000);
        }
      });
    } catch (cause) {
      await worker.request({ type: 'leave', id: account.id });
      records.delete(account.id);
      if (cause.code?.startsWith('ERR_SQLITE_CONSTRAINT') || cause.errcode === 2067) throw failure('username_unavailable', 'Choose another username.');
      throw cause;
    }
    if (previous) { error(previous, 'session_replaced', 'This account signed in from another connection.'); previous.id = null; previous.ws.close(1008); }
    records.set(account.id, record); online.set(account.id, client); client.id = account.id;
    const players = [...records.values()].filter(player => distance(record.position, player.position) <= radius).map(publicPlayer);
    send(client, { type: 'welcome', protocol: 1, token, player: record, world: publicWorld, players });
    client.chunkCenter = chunkAt(record.position).join(',');
    queueChunks(client, around(chunkAt(record.position))).catch(cause => chunkFailure(client, cause));
    if (client.ws.readyState !== WebSocket.OPEN) {
      online.delete(account.id);
      const removed = await worker.request({ type: 'leave', id: account.id });
      if (removed.player?.id) store.save([removed.player]);
      records.delete(account.id);
    }
  });
}
async function shutdown(code) {
  if (shuttingDown) return;
  shuttingDown = true; clearInterval(heartbeat);
  const deadline = setTimeout(() => process.exit(1), 5000); deadline.unref();
  try {
    if (worker) {
      const snapshot = await worker.request({ type: 'snapshot' });
      store.save(snapshot.players);
    }
  } catch { code = 1; }
  for (const client of clients) client.ws.terminate();
  worker?.stop(); server?.close(); db.close(); process.exit(code);
}
