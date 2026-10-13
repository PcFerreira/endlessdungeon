import net from 'node:net';
import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import path from 'node:path';

export async function startWorker(root, world, onState, onFailure) {
  const pending = new Map();
  let counter = 0, socket, child;
  const listener = net.createServer();
  await new Promise((resolve, reject) => { listener.once('error', reject); listener.listen(0, '127.0.0.1', resolve); });
  const connected = new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(Error('Godot authority did not connect')), 30000);
    listener.once('connection', connection => { socket = connection; clearTimeout(timeout); listener.close(); resolve(); });
  });
  const localBinary = path.join(root, '.tools/Godot.app/Contents/MacOS/Godot');
  const binary = process.env.GODOT_BINARY || (existsSync(localBinary) ? localBinary : 'godot');
  child = spawn(binary, ['--headless', '--path', root, '--script', 'server/world_worker.gd'], {
    cwd: root, env: { ...process.env, WORLD_WORKER_PORT: String(listener.address().port) }, stdio: ['ignore', 'pipe', 'pipe']
  });
  let diagnostics = '';
  for (const stream of [child.stdout, child.stderr]) stream.on('data', data => {
    diagnostics = (diagnostics + data.toString()).slice(-16000);
  });
  child.once('error', error => onFailure(error));
  child.once('exit', code => onFailure(Error(`Godot authority exited (${code}): ${diagnostics}`)));
  try { await connected; } catch (error) { child.kill(); listener.close(); throw Error(`${error.message}\n${diagnostics}`); }
  let buffer = '';
  socket.setNoDelay(true);
  socket.on('data', data => {
    buffer += data.toString();
    if (buffer.length > 4 * 1024 * 1024) return socket.destroy(Error('Worker frame overflow'));
    while (buffer.includes('\n')) {
      const newline = buffer.indexOf('\n');
      const line = buffer.slice(0, newline); buffer = buffer.slice(newline + 1);
      let message;
      try { message = JSON.parse(line); } catch { return socket.destroy(Error('Malformed worker frame')); }
      if (message.type === 'state') onState(message);
      else if (pending.has(message.request)) {
        const { resolve, reject, timer } = pending.get(message.request);
        pending.delete(message.request); clearTimeout(timer);
        if (message.error) reject(Error(message.error)); else resolve(message);
      }
    }
  });
  socket.on('error', onFailure);
  socket.on('close', () => {
    for (const { reject, timer } of pending.values()) { clearTimeout(timer); reject(Error('Authority disconnected')); }
    pending.clear();
    onFailure(Error('Authority disconnected'));
  });
  const send = value => socket.write(JSON.stringify(value) + '\n');
  const request = value => new Promise((resolve, reject) => {
    const id = ++counter;
    const timer = setTimeout(() => { pending.delete(id); reject(Error('Authority request timeout')); }, 10000);
    pending.set(id, { resolve, reject, timer }); send({ ...value, request: id });
  });
  const ready = await request({ type: 'init', seed: world.seed, generator_version: world.generator_version });
  if (world.engine_version) {
    const expected = world.engine_version.split('.');
    const actual = ready.engine;
    if ([actual.major, actual.minor, actual.patch, actual.status, actual.build].map(String).join('.') !== expected.slice(0, 5).join('.') || !String(actual.hash).startsWith(expected[5])) {
      socket.destroy(); child.kill(); throw Error('Godot authority version disagrees with the network manifest');
    }
  }
  return { send, request, stop: () => { socket.destroy(); child.kill('SIGTERM'); } };
}
