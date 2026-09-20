// Turns the whale svg into whale-<size>.png plus a multi-size whale.ico.
// sharp comes from the dsh package itself, so this needs no extra install.
// usage: node build-icon.js <deps dir containing sharp> <svg file> <output dir>
const fs = require('fs');
const path = require('path');

const depsDir = process.argv[2];
const svgPath = process.argv[3];
const outDir = process.argv[4];
if (!depsDir || !svgPath || !outDir) {
  console.error('usage: node build-icon.js <deps dir with sharp> <svg> <out dir>');
  process.exit(2);
}

const sharp = require(path.join(depsDir, 'sharp'));
const SIZES = [256, 64, 48, 32, 16];

(async () => {
  const pngDir = path.join(outDir, 'icon-png');
  fs.mkdirSync(pngDir, { recursive: true });

  const svg = fs.readFileSync(svgPath);
  const big = await sharp(svg, { density: 512 }).png().toBuffer();

  const blobs = [];
  for (const size of SIZES) {
    const png = await sharp(big).resize(size, size).png().toBuffer();
    fs.writeFileSync(path.join(pngDir, 'whale-' + size + '.png'), png);
    blobs.push(png);
  }

  // ICO container: 6 byte header, 16 bytes per entry, then the PNG payloads.
  // Windows has taken PNG-compressed icon entries since Vista.
  const header = Buffer.alloc(6);
  header.writeUInt16LE(0, 0);
  header.writeUInt16LE(1, 2);
  header.writeUInt16LE(SIZES.length, 4);

  const entries = [];
  let offset = 6 + 16 * SIZES.length;
  SIZES.forEach((size, index) => {
    const entry = Buffer.alloc(16);
    entry[0] = size === 256 ? 0 : size;
    entry[1] = size === 256 ? 0 : size;
    entry[2] = 0;
    entry[3] = 0;
    entry.writeUInt16LE(1, 4);
    entry.writeUInt16LE(32, 6);
    entry.writeUInt32LE(blobs[index].length, 8);
    entry.writeUInt32LE(offset, 12);
    offset += blobs[index].length;
    entries.push(entry);
  });

  fs.writeFileSync(path.join(outDir, 'whale.ico'), Buffer.concat([header].concat(entries).concat(blobs)));
  fs.rmSync(pngDir, { recursive: true, force: true });
  console.log('icon written: ' + path.join(outDir, 'whale.ico'));
})().catch((error) => {
  console.error('icon build failed: ' + error.message);
  process.exit(1);
});
