import { cp, mkdir, readFile, readdir, realpath } from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';

async function filesBelow(directory, prefix = '') {
  const files = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const relative = path.posix.join(prefix, entry.name);
    if (entry.isDirectory()) files.push(...await filesBelow(path.join(directory, entry.name), relative));
    else if (entry.isFile()) files.push(relative);
  }
  return files;
}

export async function assembleRuntime(source, destination) {
  source = await realpath(source);
  const manifest = JSON.parse(await readFile(path.join(source, 'config/network_manifest.json'), 'utf8'));
  const files = new Set(['project.godot', 'assets/icon.svg', 'config/network_manifest.json', 'server/package.json', 'server/package-lock.json', 'server/index.mjs', 'server/database.mjs', 'server/worker.mjs', 'server/world_worker.gd', 'server/GODOT_LICENSE.txt', 'server/GODOT_COPYRIGHT.txt', 'server/GODOT_AUTHORS.md']);
  for (const relative of await filesBelow(path.join(source, 'scripts'))) if (/\.(gd|gdshader|uid)$/.test(relative)) files.add(`scripts/${relative}`);
  for (const relative of await filesBelow(path.join(source, 'config'))) if (relative.endsWith('.json')) files.add(`config/${relative}`);
  for (const relative of await filesBelow(path.join(source, 'assets'))) if (path.basename(relative) === 'catalog.json' || (relative.startsWith('lore/locales/') && relative.endsWith('.json'))) files.add(`assets/${relative}`);
  for (const [relative, expected] of Object.entries(manifest.inputs)) {
    const bytes = await readFile(path.join(source, relative));
    if (createHash('sha256').update(bytes).digest('hex') !== expected) throw Error(`Network manifest is stale: ${relative}`);
    files.add(relative);
  }
  const pending = ['server/world_worker.gd'];
  const visited = new Set();
  while (pending.length) {
    const relative = pending.pop();
    if (visited.has(relative)) continue;
    visited.add(relative); files.add(relative);
    if (!relative.endsWith('.gd')) continue;
    const script = await readFile(path.join(source, relative), 'utf8');
    for (const match of script.matchAll(/preload\s*\(\s*["']res:\/\/([^"']+)["']/g)) pending.push(match[1]);
  }
  for (const relative of files) {
    if (path.isAbsolute(relative) || relative.split('/').includes('..')) throw Error(`Invalid runtime resource path: ${relative}`);
    const original = path.join(source, relative);
    if (!(await realpath(original)).startsWith(source + path.sep)) throw Error(`Runtime resource escapes source: ${relative}`);
    const target = path.join(destination, relative);
    await mkdir(path.dirname(target), { recursive: true });
    await cp(original, target, { dereference: true });
  }
  return [...files].sort();
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  const [source, destination] = process.argv.slice(2);
  if (!source || !destination) throw Error('Usage: node server/assemble_runtime.mjs SOURCE DESTINATION');
  const files = await assembleRuntime(source, destination);
  console.log(JSON.stringify({ event: 'runtime_assembled', files: files.length }));
}
