#!/usr/bin/env node

const net = require('node:net');

const port = Number.parseInt(process.env.PORT ?? '3000', 10);
const socket = net.createConnection({ host: '127.0.0.1', port });

socket.once('connect', () => {
  socket.destroy();
  console.error(
    `Backend startup cancelled: port ${port} is already in use. ` +
      'SenderWho may already be running. Stop the existing process before starting another.',
  );
  process.exit(1);
});

socket.once('error', (error) => {
  if (error.code === 'ECONNREFUSED') process.exit(0);
  console.error(`Could not check port ${port}: ${error.message}`);
  process.exit(1);
});

socket.setTimeout(1500, () => {
  socket.destroy();
  console.error(`Timed out while checking whether port ${port} is available.`);
  process.exit(1);
});
