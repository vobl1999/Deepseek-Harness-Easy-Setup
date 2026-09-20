// Boots the real "dsh web" from an installed copy and waits for HTTP 200.
// usage: node boot-check.js <install root> [port]
const { spawn } = require('child_process');
const http = require('http');
const path = require('path');

const root = path.resolve(process.argv[2] || '.');
const port = Number(process.argv[3] || 3999);
const nodeExe = path.join(root, 'node.exe');
const binJs = path.join(root, 'node_modules', '@deepseek-ai', 'dsh', 'lib', 'bin.js');

// scrub the harness' own environment so the check reflects a plain user machine
const env = Object.assign({}, process.env);
for (const key of Object.keys(env)) {
  if (key.indexOf('DSH_') === 0) delete env[key];
}

const child = spawn(nodeExe, [binJs, 'web', '--port', String(port), '--no-open'], {
  cwd: root,
  env: env,
  stdio: ['ignore', 'pipe', 'pipe'],
  windowsHide: true,
});

let output = '';
const collect = function (chunk) {
  output = (output + chunk).slice(-20000);
};
child.stdout.on('data', collect);
child.stderr.on('data', collect);

const deadline = Date.now() + 90000;

(async function () {
  while (Date.now() < deadline) {
    await new Promise(function (r) { setTimeout(r, 1000); });
    if (child.exitCode !== null) break;
    try {
      const status = await new Promise(function (resolve, reject) {
        http.get('http://127.0.0.1:' + port + '/', function (res) {
          let body = '';
          res.on('data', function (c) { body += c; });
          res.on('end', function () { resolve({ code: res.statusCode, bytes: body.length }); });
        }).on('error', reject);
      });
      if (status.code === 200 && status.bytes > 100) {
        console.log('boot ok: ' + JSON.stringify(status));
        child.kill();
        setTimeout(function () { process.exit(0); }, 500);
        return;
      }
    } catch (error) {
      // not listening yet
    }
  }
  console.log('boot failed, child exit code: ' + child.exitCode);
  console.log(output);
  child.kill();
  process.exit(1);
})();
