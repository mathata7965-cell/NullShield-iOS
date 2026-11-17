import fs from "fs";
import path from "path";
import zlib from "zlib";
import { fileURLToPath } from "url";

function clamp(v) {
  return v <= 0 ? 0 : v >= 255 ? 255 : Math.round(v);
}

function smoothstep(e0, e1, x) {
  const t = Math.max(0, Math.min(1, (x - e0) / (e1 - e0)));
  return t * t * (3 - 2 * t);
}

function sdHexagon(px, py, r) {
  // Upright pointy-top hexagon (swap axes from flat-top SDF)
  const kx = -0.866025404;
  const ky = 0.5;
  const kz = 0.577350269;
  let ax = Math.abs(py);
  let ay = Math.abs(px);
  const dotK = 2 * Math.min(kx * ax + ky * ay, 0);
  ax -= dotK * kx;
  ay -= dotK * ky;
  ax -= Math.max(-kz * r, Math.min(kz * r, ax));
  ay -= r;
  const d = Math.hypot(ax, ay);
  return ay < 0 ? -d : d;
}

function sdRoundedHex(px, py, r, c) {
  return sdHexagon(px, py, r - c) - c;
}

function sdSegment(px, py, ax, ay, bx, by) {
  const pax = px - ax;
  const pay = py - ay;
  const bax = bx - ax;
  const bay = by - ay;
  const denom = bax * bax + bay * bay;
  const h = denom > 0 ? Math.max(0, Math.min(1, (pax * bax + pay * bay) / denom)) : 0;
  return Math.hypot(pax - bax * h, pay - bay * h);
}

function sdCapsule(px, py, ax, ay, bx, by, rad) {
  return sdSegment(px, py, ax, ay, bx, by) - rad;
}

function generateIcon(outPath, size = 1024) {
  const rowBytes = 1 + size * 3;
  const raw = Buffer.alloc(size * rowBytes);
  const inv = 1 / size;

  for (let y = 0; y < size; y++) {
    let off = y * rowBytes;
    raw[off++] = 0;
    const v = (y + 0.5) * inv;
    const ny = v * 2 - 1;
    for (let x = 0; x < size; x++) {
      const u = (x + 0.5) * inv;
      const nx = u * 2 - 1;
      const dc = Math.hypot(nx, ny);

      let r = 6 + 7 * (1 - v);
      let g = 10 + 16 * (1 - v * 0.6);
      let b = 18 + 25 * (1 - dc * 0.55);

      const coreGlow = Math.exp(-dc * dc * 3.0);
      r += coreGlow * 3;
      g += coreGlow * 48;
      b += coreGlow * 44;

      const atl = Math.exp(-((u - 0.25) ** 2 + (v - 0.20) ** 2) * 4.5);
      const abr = Math.exp(-((u - 0.78) ** 2 + (v - 0.80) ** 2) * 4.2);
      r += abr * 4;
      g += atl * 36 + abr * 22;
      b += atl * 30 + abr * 52;

      for (const rr of [0.60, 0.78, 0.96]) {
        const ra = Math.exp(-Math.abs(dc - rr) * 260) * 0.13;
        r += ra * 25;
        g += ra * 210;
        b += ra * 195;
      }

      const dHex = sdRoundedHex(nx, ny, 0.69, 0.10);
      const shHex = (1 - smoothstep(-0.02, 0.11, dHex)) * 0.58;
      r *= 1 - shHex * 0.55;
      g *= 1 - shHex * 0.55;
      b *= 1 - shHex * 0.55;

      const hexAlpha = 1 - smoothstep(-0.004, 0.004, dHex);
      if (hexAlpha > 0) {
        const ld = Math.max(0, 1 - (u * 0.7 + v * 0.9) * 0.75);
        let hr = 13 + 17 * ld;
        let hg = 22 + 27 * ld;
        let hb = 34 + 36 * ld;
        const ig = Math.exp(-dc * dc * 4.8);
        hr += ig * 3;
        hg += ig * 38;
        hb += ig * 34;
        const dInHex = sdRoundedHex(nx, ny, 0.595, 0.085);
        const rec = Math.exp(-Math.abs(dInHex) * 165) * 0.34;
        hg += rec * 110;
        hb += rec * 105;
        r = r * (1 - hexAlpha) + hr * hexAlpha;
        g = g * (1 - hexAlpha) + hg * hexAlpha;
        b = b * (1 - hexAlpha) + hb * hexAlpha;
      }

      const rimBand = Math.exp(-Math.abs(dHex) * 120);
      if (rimBand > 0.005) {
        const gt = Math.max(0, Math.min(1, (u + v) * 0.5));
        const spec = 0.64 + 0.54 * Math.max(0, 1 - (u * 0.8 + v * 0.8));
        const rs = Math.min(1, rimBand * spec * 0.94);
        r = r * (1 - rs) + 12 * gt * rs;
        g = g * (1 - rs) + (250 * (1 - gt) + 210 * gt) * rs;
        b = b * (1 - rs) + (165 * (1 - gt) + 255 * gt) * rs;
      }

      // Precision Null glyph (Ø)
      const ringR = 0.295;
      const ringT = 0.068;
      const dRing = Math.abs(dc - ringR) - ringT;
      const dSlash = sdCapsule(nx, ny, 0.31, -0.31, -0.31, 0.31, 0.048);
      const dSlashGap = sdCapsule(nx, ny, 0.34, -0.34, -0.34, 0.34, 0.095);
      const dRingCut = Math.max(dRing, -dSlashGap);

      const dBloom = Math.min(dRing, dSlash);
      if (dBloom < 0.24) {
        const bl = Math.exp(-Math.max(0, dBloom) * 15) * 0.35;
        g += bl * 245;
        b += bl * 185;
      }

      const dSh = Math.min(
        Math.abs(Math.hypot(nx - 0.014, ny - 0.022) - ringR) - ringT,
        sdCapsule(nx - 0.014, ny - 0.022, 0.31, -0.31, -0.31, 0.31, 0.048)
      );
      const gSh = (1 - smoothstep(-0.02, 0.05, dSh)) * 0.48;
      r *= 1 - gSh;
      g *= 1 - gSh;
      b *= 1 - gSh;

      const ringAlpha = 1 - smoothstep(-0.004, 0.004, dRingCut);
      if (ringAlpha > 0) {
        const tc = Math.max(0, Math.min(1, (nx + ny + 0.75) / 1.5));
        const hi = Math.max(0, 1 - Math.abs(dRing) / ringT) * 0.24;
        const gr = 6 * (1 - tc) + 16 * tc + hi * 75;
        const gg = 250 * (1 - tc) + 216 * tc + hi * 25;
        const gb = 165 * (1 - tc) + 255 * tc + hi * 30;
        r = r * (1 - ringAlpha) + gr * ringAlpha;
        g = g * (1 - ringAlpha) + gg * ringAlpha;
        b = b * (1 - ringAlpha) + gb * ringAlpha;
      }

      const slashAlpha = 1 - smoothstep(-0.004, 0.004, dSlash);
      if (slashAlpha > 0) {
        const ridge = Math.max(0, 1 - (dSlash + 0.048) / 0.048);
        r = r * (1 - slashAlpha) + (230 + ridge * 25) * slashAlpha;
        g = g * (1 - slashAlpha) + 255 * slashAlpha;
        b = b * (1 - slashAlpha) + (248 + ridge * 7) * slashAlpha;
      }

      raw[off++] = clamp(r);
      raw[off++] = clamp(g);
      raw[off++] = clamp(b);
    }
  }

  function crc32(buf) {
    let c = 0xffffffff;
    for (let i = 0; i < buf.length; i++) {
      c ^= buf[i];
      for (let k = 0; k < 8; k++) {
        c = (c >>> 1) ^ (c & 1 ? 0xedb88320 : 0);
      }
    }
    return (c ^ 0xffffffff) >>> 0;
  }

  function chunk(tag, data) {
    const t = Buffer.from(tag, "ascii");
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length, 0);
    const crcBuf = Buffer.concat([t, data]);
    const crcOut = Buffer.alloc(4);
    crcOut.writeUInt32BE(crc32(crcBuf), 0);
    return Buffer.concat([len, t, data, crcOut]);
  }

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8;
  ihdr[9] = 2;
  const idat = zlib.deflateSync(raw, { level: 6 });
  const png = Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr),
    chunk("IDAT", idat),
    chunk("IEND", Buffer.alloc(0)),
  ]);

  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, png);
  console.log(`Generated AppIcon: ${outPath} (${png.length} bytes)`);
}

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.dirname(__dirname);
const target = path.join(rootDir, "Null", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png");
generateIcon(target, 1024);
