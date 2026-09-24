import { spawn } from 'node:child_process';
import { networkInterfaces } from 'node:os';
import { once } from 'node:events';

// The existing port-80 service routes Host: go-kit.local to this private port.
process.env.PORT = '5184';
const { server } = await import('../server.mjs');
if (!server.listening) await once(server, 'listening');

let advertiser;
let publishedAddress;
let stopping = false;
let refreshing = false;
function lanAddress() {
  const interfaces = networkInterfaces();
  const names = Object.keys(interfaces).filter(name => /^en\d+$/.test(name)).sort();
  for (const name of names) {
    const entry = interfaces[name].find(a => a.family === 'IPv4' && !a.internal && !a.address.startsWith('169.254.'));
    if (entry) return entry.address;
  }
}
async function stopAdvertiser() {
  const child = advertiser;
  advertiser = undefined;
  publishedAddress = undefined;
  if (!child || child.exitCode !== null || child.signalCode !== null) return;
  const exited = new Promise(resolve => child.once('exit', resolve));
  child.kill('SIGTERM');
  const timer = setTimeout(() => child.kill('SIGKILL'), 2000);
  await exited;
  clearTimeout(timer);
}
async function refresh() {
  if (refreshing || stopping) return;
  refreshing = true;
  try {
    const address = lanAddress();
    if (address === publishedAddress && advertiser) return;
    await stopAdvertiser();
    if (!address || stopping) return;
    const child = spawn('/usr/bin/dns-sd', ['-P', 'Go Kit', '_http._tcp', 'local', '80', 'go-kit.local', address, 'path=/'], { stdio: 'inherit' });
    advertiser = child;
    publishedAddress = address;
    child.on('error', error => {
      console.error('[go-kit] Bonjour:', error.message);
      if (advertiser === child) { advertiser = undefined; publishedAddress = undefined; }
    });
    child.on('exit', code => {
      if (advertiser === child) {
        advertiser = undefined;
        publishedAddress = undefined;
        if (!stopping) console.error('[go-kit] Bonjour exited:', code, '; retrying in 15 seconds');
      }
    });
    console.log(`[go-kit] Advertising http://go-kit.local/ at ${address}:80`);
  } finally { refreshing = false; }
}
const timer = setInterval(() => refresh().catch(console.error), 15000);
await refresh();
async function shutdown() {
  if (stopping) return;
  stopping = true;
  clearInterval(timer);
  await stopAdvertiser();
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 3000).unref();
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
