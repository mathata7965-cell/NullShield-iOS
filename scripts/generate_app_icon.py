#!/usr/bin/env python3
"""
Generate a 1024x1024 Obsidian-Emerald Null (Ø) Shield AppIcon.png
using pure Python standard library (zero external dependencies).
"""
import math
import os
import struct
import zlib


def clamp(v: float) -> int:
    if v <= 0.0:
        return 0
    if v >= 255.0:
        return 255
    return int(v + 0.5)


def smoothstep(edge0: float, edge1: float, x: float) -> float:
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def sd_hexagon(px: float, py: float, r: float) -> float:
    kx = -0.866025404
    ky = 0.5
    kz = 0.577350269
    ax = abs(py)
    ay = abs(px)
    dot_k = 2.0 * min(kx * ax + ky * ay, 0.0)
    ax -= dot_k * kx
    ay -= dot_k * ky
    ax -= max(-kz * r, min(kz * r, ax))
    ay -= r
    d = math.hypot(ax, ay)
    return -d if ay < 0.0 else d


def sd_rounded_hexagon(px: float, py: float, r: float, corner: float) -> float:
    return sd_hexagon(px, py, r - corner) - corner


def sd_segment(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> float:
    pax = px - ax
    pay = py - ay
    bax = bx - ax
    bay = by - ay
    denom = bax * bax + bay * bay
    h = max(0.0, min(1.0, (pax * bax + pay * bay) / denom)) if denom > 0.0 else 0.0
    return math.hypot(pax - bax * h, pay - bay * h)


def sd_capsule(px: float, py: float, ax: float, ay: float, bx: float, by: float, radius: float) -> float:
    return sd_segment(px, py, ax, ay, bx, by) - radius


def generate_icon(out_path: str, size: int = 1024) -> None:
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    raw = bytearray()
    inv_size = 1.0 / size

    for y in range(size):
        raw.append(0)
        v = (y + 0.5) * inv_size
        ny = v * 2.0 - 1.0
        for x in range(size):
            u = (x + 0.5) * inv_size
            nx = u * 2.0 - 1.0
            dist_center = math.hypot(nx, ny)

            r = 6.0 + 7.0 * (1.0 - v)
            g = 10.0 + 16.0 * (1.0 - v * 0.6)
            b = 18.0 + 25.0 * (1.0 - dist_center * 0.55)

            core_glow = math.exp(-dist_center * dist_center * 3.0)
            r += core_glow * 3.0
            g += core_glow * 48.0
            b += core_glow * 44.0

            aura_tl = math.exp(-((u - 0.25) ** 2 + (v - 0.20) ** 2) * 4.5)
            aura_br = math.exp(-((u - 0.78) ** 2 + (v - 0.80) ** 2) * 4.2)
            r += aura_br * 4.0
            g += aura_tl * 36.0 + aura_br * 22.0
            b += aura_tl * 30.0 + aura_br * 52.0

            for ring_r in (0.60, 0.78, 0.96):
                ring_d = abs(dist_center - ring_r)
                ring_a = math.exp(-ring_d * 260.0) * 0.13
                r += ring_a * 25.0
                g += ring_a * 210.0
                b += ring_a * 195.0

            d_hex = sd_rounded_hexagon(nx, ny, 0.69, 0.10)
            shadow_hex = (1.0 - smoothstep(-0.02, 0.11, d_hex)) * 0.58
            r *= 1.0 - shadow_hex * 0.55
            g *= 1.0 - shadow_hex * 0.55
            b *= 1.0 - shadow_hex * 0.55

            hex_alpha = 1.0 - smoothstep(-0.004, 0.004, d_hex)
            if hex_alpha > 0.0:
                light_dir = max(0.0, 1.0 - (u * 0.7 + v * 0.9) * 0.75)
                hr = 13.0 + 17.0 * light_dir
                hg = 22.0 + 27.0 * light_dir
                hb = 34.0 + 36.0 * light_dir

                inner_glow = math.exp(-dist_center * dist_center * 4.8)
                hr += inner_glow * 3.0
                hg += inner_glow * 38.0
                hb += inner_glow * 34.0

                d_inner_hex = sd_rounded_hexagon(nx, ny, 0.595, 0.085)
                recess = math.exp(-abs(d_inner_hex) * 165.0) * 0.34
                hg += recess * 110.0
                hb += recess * 105.0

                r = r * (1.0 - hex_alpha) + hr * hex_alpha
                g = g * (1.0 - hex_alpha) + hg * hex_alpha
                b = b * (1.0 - hex_alpha) + hb * hex_alpha

            rim_band = math.exp(-abs(d_hex) * 120.0)
            if rim_band > 0.005:
                grad_t = max(0.0, min(1.0, (u + v) * 0.5))
                spec = 0.64 + 0.54 * max(0.0, 1.0 - (u * 0.8 + v * 0.8))
                rim_strength = min(1.0, rim_band * spec * 0.94)
                r = r * (1.0 - rim_strength) + 12.0 * grad_t * rim_strength
                g = g * (1.0 - rim_strength) + (250.0 * (1.0 - grad_t) + 210.0 * grad_t) * rim_strength
                b = b * (1.0 - rim_strength) + (165.0 * (1.0 - grad_t) + 255.0 * grad_t) * rim_strength

            ring_radius = 0.295
            ring_half_thick = 0.068
            d_ring = abs(dist_center - ring_radius) - ring_half_thick
            d_slash = sd_capsule(nx, ny, 0.31, -0.31, -0.31, 0.31, 0.048)
            d_slash_gap = sd_capsule(nx, ny, 0.34, -0.34, -0.34, 0.34, 0.095)
            d_ring_cut = max(d_ring, -d_slash_gap)

            d_glyph_bloom = min(d_ring, d_slash)
            if d_glyph_bloom < 0.24:
                bloom = math.exp(-max(0.0, d_glyph_bloom) * 15.0) * 0.35
                g += bloom * 245.0
                b += bloom * 185.0

            d_ring_shadow = abs(math.hypot(nx - 0.014, ny - 0.022) - ring_radius) - ring_half_thick
            d_slash_shadow = sd_capsule(nx - 0.014, ny - 0.022, 0.31, -0.31, -0.31, 0.31, 0.048)
            d_shadow = min(d_ring_shadow, d_slash_shadow)
            glyph_shadow = (1.0 - smoothstep(-0.02, 0.05, d_shadow)) * 0.48
            r *= 1.0 - glyph_shadow
            g *= 1.0 - glyph_shadow
            b *= 1.0 - glyph_shadow

            ring_alpha = 1.0 - smoothstep(-0.004, 0.004, d_ring_cut)
            if ring_alpha > 0.0:
                t_col = max(0.0, min(1.0, (nx + ny + 0.75) / 1.5))
                highlight = max(0.0, 1.0 - abs(d_ring) / ring_half_thick) * 0.24
                gr = 6.0 * (1.0 - t_col) + 16.0 * t_col + highlight * 75.0
                gg = 250.0 * (1.0 - t_col) + 216.0 * t_col + highlight * 25.0
                gb = 165.0 * (1.0 - t_col) + 255.0 * t_col + highlight * 30.0
                r = r * (1.0 - ring_alpha) + gr * ring_alpha
                g = g * (1.0 - ring_alpha) + gg * ring_alpha
                b = b * (1.0 - ring_alpha) + gb * ring_alpha

            slash_alpha = 1.0 - smoothstep(-0.004, 0.004, d_slash)
            if slash_alpha > 0.0:
                ridge = max(0.0, 1.0 - (d_slash + 0.048) / 0.048)
                r = r * (1.0 - slash_alpha) + (230.0 + ridge * 25.0) * slash_alpha
                g = g * (1.0 - slash_alpha) + 255.0 * slash_alpha
                b = b * (1.0 - slash_alpha) + (248.0 + ridge * 7.0) * slash_alpha

            raw.extend((clamp(r), clamp(g), clamp(b)))

    def png_chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    idat = zlib.compress(bytes(raw), level=6)
    png_bytes = b"".join(
        [
            b"\x89PNG\r\n\x1a\n",
            png_chunk(b"IHDR", ihdr),
            png_chunk(b"IDAT", idat),
            png_chunk(b"IEND", b""),
        ]
    )

    with open(out_path, "wb") as f:
        f.write(png_bytes)


if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    root_dir = os.path.dirname(script_dir)
    target = os.path.join(
        root_dir,
        "Null",
        "Assets.xcassets",
        "AppIcon.appiconset",
        "AppIcon.png",
    )
    generate_icon(target, size=1024)
    print(f"Generated AppIcon: {target} ({os.path.getsize(target)} bytes)")
