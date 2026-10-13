import { WebSocketServer } from '../../server/node_modules/ws/wrapper.mjs';

const server = new WebSocketServer({ host: '127.0.0.1', port: Number(process.env.BURST_PORT || 18089) });
server.on('listening', () => console.log('READY online packet burst'));
server.on('connection', socket => {
  socket.on('message', () => {
    const padding = 'x'.repeat(32768);
    for (let tick = 0; tick < 512; tick++) socket.send(JSON.stringify({ tick, padding }));
  });
});
process.on('SIGTERM', () => { for (const socket of server.clients) socket.terminate(); server.close(); });
