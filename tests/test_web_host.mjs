import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import http from 'node:http';
import fs from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {once} from 'node:events';
import WebSocket, {WebSocketServer} from '../server/node_modules/ws/wrapper.mjs';

assert.ok(fs.existsSync('builds/web/index.html.gz'), 'Build the Web package before the hosting check');
const port = 18321;
const upstreamPort = 18322;
const upstream = http.createServer();
const websocketServer = new WebSocketServer({server:upstream});
let observedOrigin = '';
websocketServer.on('connection',(socket,request) => {
  observedOrigin = request.headers.origin;
  socket.on('message',data => socket.send(data));
});
await new Promise(resolve => upstream.listen(upstreamPort,'127.0.0.1',resolve));
const host = spawn(process.execPath, ['tools/serve_web.mjs'], {env: {...process.env, WEB_PORT: String(port), WEB_HOST:'127.0.0.1', UPSTREAM_PORT:String(upstreamPort)}, stdio: ['ignore', 'pipe', 'inherit']});
const request = (url, headers = {}, method = 'GET') => new Promise((resolve, reject) => {
  const connection = http.request({host: '127.0.0.1', port, path: url, headers, method}, response => {
    const chunks = [];
    response.on('data', chunk => chunks.push(chunk));
    response.on('end', () => resolve({status: response.statusCode, headers: response.headers, body: Buffer.concat(chunks)}));
  });
  connection.on('error', reject);
  connection.end();
});
try {
  await Promise.race([once(host.stdout, 'data'), once(host, 'exit').then(() => {throw Error('Local host exited before listening');})]);
  const plain = await request('/');
  assert.equal(plain.status, 200);
  assert.deepEqual(plain.body, fs.readFileSync('builds/web/index.html'));
  const compressed = await request('/', {'Accept-Encoding': 'gzip'});
  assert.equal(compressed.headers['content-encoding'], 'gzip');
  assert.deepEqual(gunzipSync(compressed.body), plain.body);
  const declined = await request('/', {'Accept-Encoding': 'gzip;q=0'});
  assert.equal(declined.headers['content-encoding'], undefined, 'Respect explicit gzip refusal');
  const head = await request('/index.wasm', {}, 'HEAD');
  assert.equal(head.status, 200);
  assert.equal(head.headers['content-type'], 'application/wasm');
  assert.equal(Number(head.headers['content-length']), fs.statSync('builds/web/index.wasm').size);
  assert.equal(head.body.length, 0);
  for (const path of ['/%2e%2e%2fproject.godot', '/%00', '/%zz', '/does-not-exist']) {
    const result = await request(path);
    assert.ok([400, 404].includes(result.status), `Reject unsafe or missing path ${path}`);
  }
  assert.equal((await request('/', {}, 'POST')).status, 405);
  const relay = new WebSocket(`ws://127.0.0.1:${port}/play`,{origin:'https://world.example'});
  await once(relay,'open');
  const reply = once(relay,'message');
  relay.send('actual websocket round trip');
  assert.equal((await reply)[0].toString(),'actual websocket round trip');
  assert.equal(observedOrigin,'https://world.example');
  relay.close();
  await once(relay,'close');
  assert.equal((await request('/other',{'Connection':'Upgrade','Upgrade':'websocket'})).status,404);
  console.log('PASS: real Web host raw/gzip/HEAD/WASM MIME, URI/method refusal, WebSocket relay and preserved Origin');
} finally {
  host.kill('SIGTERM');
  await once(host, 'exit');
  websocketServer.close();
  await new Promise(resolve => upstream.close(resolve));
}
