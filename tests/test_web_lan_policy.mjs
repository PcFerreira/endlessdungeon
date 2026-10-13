import assert from 'node:assert/strict';
import {requiredFeatures,isPrivateLanHost,launchArguments} from '../tools/web_lan_policy.mjs';

const secure = 'Secure Context - Check web server configuration (use HTTPS)';
const missing = ['WebGL 2.0',secure,'Fetch'];
for (const host of ['localhost','127.0.0.1','[::1]','10.0.0.1','172.16.0.1','172.31.255.255','192.168.100.95']) {
  assert.equal(isPrivateLanHost(host),true);
  assert.deepEqual(requiredFeatures(missing,{protocol:'http:',hostname:host,threads:false}),['WebGL 2.0','Fetch']);
  assert.deepEqual(requiredFeatures(missing,{protocol:'https:',hostname:host,threads:false}),missing);
  assert.deepEqual(requiredFeatures(missing,{protocol:'http:',hostname:host,threads:true}),missing);
}
for (const host of ['8.8.8.8','172.15.255.255','172.32.0.1','192.169.0.1','010.0.0.1','192.168.0.256','world.example','localhost.example']) {
  assert.equal(isPrivateLanHost(host),false);
  assert.deepEqual(requiredFeatures(missing,{protocol:'http:',hostname:host,threads:false}),missing);
}
assert.deepEqual(missing,['WebGL 2.0',secure,'Fetch']);
const args = ['--example'];
assert.deepEqual(launchArguments(args,{protocol:'http:',hostname:'192.168.100.95',threads:false,secureContext:false}),['--example','--audio-driver','Dummy']);
for (const context of [
  {protocol:'http:',hostname:'127.0.0.1',threads:false,secureContext:true},
  {protocol:'https:',hostname:'world.example',threads:false,secureContext:true},
  {protocol:'http:',hostname:'8.8.8.8',threads:false,secureContext:false},
  {protocol:'http:',hostname:'192.168.100.95',threads:true,secureContext:false},
]) assert.deepEqual(launchArguments(args,context),args);
assert.deepEqual(args,['--example']);
console.log('PASS: private HTTP single-thread app preflight, public/HTTPS/thread and other feature checks preserved');
