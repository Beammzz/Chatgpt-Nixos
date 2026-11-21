// Exercise the bundled native libraries, not a substitute system Node runtime.
const assert = require('node:assert/strict');
const path = require('node:path');
const modules = path.join(process.env.CHATGPT_RESOURCES || '/usr/lib/chatgpt/resources', 'cua_node/lib/node_modules');
const sharp = require(path.join(modules, 'sharp'));
const { ClassicLevel } = require(path.join(modules, 'classic-level'));

async function main() {
  const image = await sharp({
    create: { width: 2, height: 3, channels: 3, background: '#336699' },
  }).png().toBuffer();
  const metadata = await sharp(image).metadata();
  assert.equal(metadata.width, 2);
  assert.equal(metadata.height, 3);
  console.log(`Sharp/libvips ${sharp.versions.vips}: PNG encode/decode passed`);

  const database = new ClassicLevel(path.join(process.env.CODEX_HOME, 'level-smoke'));
  await database.open();
  try {
    await database.put('smoke', 'ok');
    assert.equal(await database.get('smoke'), 'ok');
    console.log('Classic Level: native database write/read passed');
  } finally {
    await database.close();
  }

  // Host privilege policy remains usable by unsandboxed native children.
  const { execFileSync } = require('node:child_process');
  const status = execFileSync('/bin/sh', ['-c', 'awk "/^NoNewPrivs:|^Seccomp:/" /proc/self/status'], { encoding: 'utf8' });
  assert.match(status, /NoNewPrivs:\s+0/);
  console.log(`Native child status:\n${status.trim()}`);
  // Sudo policy is host configuration; opt in to this benign root-id check.
  if (process.env.CHATGPT_TEST_SUDO === '1') {
    const identity = execFileSync('sudo', ['-n', 'id'], { encoding: 'utf8' });
    assert.match(identity, /uid=0\(root\)/);
    console.log(`Native child sudo -n id: ${identity.trim()}`);
  }
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
