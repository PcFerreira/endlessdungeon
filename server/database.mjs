import { DatabaseSync } from 'node:sqlite';
import { randomUUID, createHash } from 'node:crypto';
import { mkdirSync } from 'node:fs';
import path from 'node:path';

export const tokenHash = token => createHash('sha256').update(token).digest('hex');

export function openDatabase(filename, manifest, configuredSeed, upgradeContent = false) {
  mkdirSync(path.dirname(filename), { recursive: true });
  const db = new DatabaseSync(filename);
  db.exec(`PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA foreign_keys=ON; PRAGMA busy_timeout=5000;
    CREATE TABLE IF NOT EXISTS worlds (id TEXT PRIMARY KEY, seed TEXT NOT NULL, generator_version INTEGER NOT NULL, content_revision TEXT NOT NULL, protocol INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS accounts (id TEXT PRIMARY KEY, username TEXT NOT NULL, username_key TEXT UNIQUE NOT NULL, password_salt TEXT NOT NULL, password_hash TEXT NOT NULL, class_id TEXT NOT NULL, created_at INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS players (account_id TEXT PRIMARY KEY REFERENCES accounts(id), world_id TEXT NOT NULL REFERENCES worlds(id), record TEXT NOT NULL, updated_at INTEGER NOT NULL);
    CREATE TABLE IF NOT EXISTS sessions (token_hash TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(id), expires_at INTEGER NOT NULL);
    CREATE INDEX IF NOT EXISTS sessions_account ON sessions(account_id);
    CREATE TABLE IF NOT EXISTS map_regions (world_id TEXT NOT NULL REFERENCES worlds(id), revision TEXT NOT NULL, x INTEGER NOT NULL, z INTEGER NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(world_id, revision, x, z));
    CREATE TABLE IF NOT EXISTS map_chunks (world_id TEXT NOT NULL REFERENCES worlds(id), revision TEXT NOT NULL, x INTEGER NOT NULL, z INTEGER NOT NULL, region_x INTEGER NOT NULL, region_z INTEGER NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(world_id, revision, x, z));`);
  let world = db.prepare('SELECT * FROM worlds LIMIT 1').get();
  if (!world) {
    const seed = configuredSeed ?? String(Math.floor(Math.random() * 2147483647));
    if (!/^-?\d{1,10}$/.test(seed) || !Number.isSafeInteger(Number(seed)) || Math.abs(Number(seed)) > 2147483647) throw Error('WORLD_SEED must be a signed 32-bit decimal integer');
    world = { id: randomUUID(), seed, ...manifest };
    db.prepare('INSERT INTO worlds VALUES (?, ?, ?, ?, ?)').run(world.id, seed, manifest.generator_version, manifest.content_revision, manifest.protocol);
  }
  if (world.protocol !== manifest.protocol || world.generator_version !== manifest.generator_version) throw Error('Stored world requires its original protocol and generator edition; migrate explicitly');
  if (world.content_revision !== manifest.content_revision) {
    if (!upgradeContent) throw Error('Stored world content differs. Back up the database and use --upgrade-content to adopt the current verified content');
    db.prepare('UPDATE worlds SET content_revision = ? WHERE id = ?').run(manifest.content_revision, world.id);
    world.content_revision = manifest.content_revision;
  }
  if (configuredSeed !== undefined && configuredSeed !== world.seed) throw Error('WORLD_SEED disagrees with the stored world seed');
  db.prepare('DELETE FROM sessions WHERE expires_at <= ?').run(Date.now());
  world.engine_version = manifest.engine_version;
  const transaction = action => {
    db.exec('BEGIN IMMEDIATE');
    try { const result = action(); db.exec('COMMIT'); return result; }
    catch (error) { db.exec('ROLLBACK'); throw error; }
  };
  const save = records => transaction(() => {
    const update = db.prepare('UPDATE players SET record = ?, updated_at = ? WHERE account_id = ?');
    for (const record of records) update.run(JSON.stringify(record), Date.now(), record.id);
  });
  const mapChunk = ([x, z]) => {
    const row = db.prepare('SELECT payload, region_x, region_z FROM map_chunks WHERE world_id = ? AND revision = ? AND x = ? AND z = ?').get(world.id, world.content_revision, x, z);
    if (!row) return null;
    const region = db.prepare('SELECT payload FROM map_regions WHERE world_id = ? AND revision = ? AND x = ? AND z = ?').get(world.id, world.content_revision, row.region_x, row.region_z);
    if (!region) throw Error('Persisted map chunk has no region');
    return { chunk: JSON.parse(row.payload), region: { coordinate: [row.region_x, row.region_z], data: JSON.parse(region.payload) } };
  };
  const saveChunks = result => transaction(() => {
    for (const region of result.regions) db.prepare('INSERT OR IGNORE INTO map_regions VALUES (?, ?, ?, ?, ?)').run(world.id, world.content_revision, ...region.coordinate, JSON.stringify(region.data));
    for (const chunk of result.chunks) {
      const { region_coordinate, ...payload } = chunk;
      db.prepare('INSERT OR IGNORE INTO map_chunks VALUES (?, ?, ?, ?, ?, ?, ?)').run(world.id, world.content_revision, ...chunk.coordinate, ...region_coordinate, JSON.stringify(payload));
    }
  });
  return { db, world, transaction, save, mapChunk, saveChunks };
}
