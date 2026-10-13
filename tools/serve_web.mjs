#!/usr/bin/env node
import http from 'node:http';
import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';
import net from 'node:net';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../builds/web');
const port = Number(process.env.WEB_PORT || 8000);
const host = process.env.WEB_HOST || '0.0.0.0';
const upstreamPort = Number(process.env.UPSTREAM_PORT || 8080);
if (!Number.isSafeInteger(upstreamPort) || upstreamPort < 1 || upstreamPort > 65535) throw Error('UPSTREAM_PORT must be an integer from 1 to65535');
const types = {'.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.json': 'application/json', '.svg': 'image/svg+xml', '.png': 'image/png', '.txt': 'text/plain; charset=utf-8', '.md': 'text/plain; charset=utf-8'};
const server = http.createServer((request, response) => {
  if (!['GET', 'HEAD'].includes(request.method)) {
    response.writeHead(405, {'Allow': 'GET, HEAD'}).end();
    return;
  }
  let pathname;
  try { pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname); }
  catch { response.writeHead(400).end(); return; }
  const file = path.resolve(root, '.' + (pathname.endsWith('/') ? pathname + 'index.html' : pathname));
  if (!file.startsWith(root + path.sep) || pathname.includes('\0') || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
    response.writeHead(404).end();
    return;
  }
  const encodings = (request.headers['accept-encoding'] || '').toLowerCase().split(',').map(entry => entry.trim().split(';'));
  const gzip = encodings.some(([name, ...parameters]) => name === 'gzip' && !parameters.some(value => /^\s*q=0(?:\.0*)?\s*$/.test(value))) && fs.existsSync(file + '.gz');
  const served = gzip ? file + '.gz' : file;
  const headers = {'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Content-Length': fs.statSync(served).size, 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff', 'Vary': 'Accept-Encoding'};
  if (gzip) headers['Content-Encoding'] = 'gzip';
  response.writeHead(200, headers);
  if (request.method === 'HEAD') response.end();
  else fs.createReadStream(served).on('error', () => response.destroy()).pipe(response);
});
server.on('upgrade',(request,socket,head) => {
  if (request.url !== '/play') {
    socket.end('HTTP/1.1 404 Not Found\r\nConnection: close\r\nContent-Length: 0\r\n\r\n');
    return;
  }
  if (request.method !== 'GET' || request.headers.upgrade?.toLowerCase() !== 'websocket' || !request.headers.connection?.toLowerCase().split(',').map(value=>value.trim()).includes('upgrade')) {
    socket.end('HTTP/1.1 400 Bad Request\r\nConnection: close\r\nContent-Length: 0\r\n\r\n');
    return;
  }
  socket.pause();
  const upstream = net.createConnection({host:'127.0.0.1',port:upstreamPort});
  upstream.setTimeout(10000,()=>upstream.destroy());
  upstream.on('connect',()=> {
    upstream.setTimeout(0);
    let headers = 'GET /play HTTP/1.1\r\n';
    for (let index=0;index<request.rawHeaders.length;index+=2) headers += `${request.rawHeaders[index]}: ${request.rawHeaders[index+1]}\r\n`;
    upstream.write(headers+'\r\n');
    if (head.length) upstream.write(head);
    upstream.pipe(socket);
    socket.pipe(upstream);
    socket.resume();
  });
  upstream.on('error',()=>socket.destroy());
  socket.on('error',()=>upstream.destroy());
  upstream.on('close',()=>socket.destroy());
  socket.on('close',()=>upstream.destroy());
});
server.listen(port, host, () => {
  console.log(`Web build at http://127.0.0.1:${port}/; listening on ${host}:${port}`);
  if (host === '0.0.0.0') {
    for (const address of Object.values(os.networkInterfaces()).flat()) {
      if (address.family === 'IPv4' && !address.internal) console.log(`LAN browser: http://${address.address}:${port}/`);
    }
  }
});
