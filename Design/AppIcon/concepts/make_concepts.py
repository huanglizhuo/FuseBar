"""FuseBar icon concepts — flat SVG previews on the macOS 1024 icon grid.

These are design previews, not the shipping asset: the real icon is an Icon Composer
document whose Liquid Glass lighting is rendered by the system. Each concept therefore
keeps a plain background + white/graphite foreground layers that map 1:1 onto layers.
"""
import math
from pathlib import Path

OUT = Path(__file__).resolve().parent
TILE = dict(x=100, y=100, s=824, r=185.4)  # macOS icon grid squircle (approx.)


def pt(cx, cy, r, a):
    t = math.radians(a)
    return cx + r * math.cos(t), cy + r * math.sin(t)


def arc(cx, cy, r, a0, a1):
    x0, y0 = pt(cx, cy, r, a0); x1, y1 = pt(cx, cy, r, a1)
    large = 1 if a1 - a0 > 180 else 0
    return f"M{x0:.2f} {y0:.2f} A{r} {r} 0 {large} 1 {x1:.2f} {y1:.2f}"


def spiral(cx, cy, r0, r1, a0, a1, steps=48):
    pts = []
    for i in range(steps + 1):
        p = i / steps
        e = p * p * (3 - 2 * p)
        pts.append(pt(cx, cy, r0 + (r1 - r0) * e, a0 + (a1 - a0) * p))
    return "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in pts)


def wifi(cx, cy, scale, color, width):
    # three arcs + dot, same construction as the film's glyph (16-unit box)
    s = scale
    parts = [f'<path d="{arc(cx, cy + 4.6 * s, r * s, 225, 315)}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round"/>'
             for r in (3.3, 6.3, 9.3)]
    parts.append(f'<circle cx="{cx}" cy="{cy + 4.6 * s}" r="{1.35 * s}" fill="{color}"/>')
    return "".join(parts)


def tile(bg_defs, bg_fill, fg, name):
    x, y, s, r = TILE.values()
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>{bg_defs}
<clipPath id="sq"><rect x="{x}" y="{y}" width="{s}" height="{s}" rx="{r}"/></clipPath>
<linearGradient id="rim" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".55"/><stop offset=".5" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#fff" stop-opacity=".18"/></linearGradient>
</defs>
<g clip-path="url(#sq)">
<rect x="{x}" y="{y}" width="{s}" height="{s}" fill="{bg_fill}"/>
{fg}
</g>
<rect x="{x + 1}" y="{y + 1}" width="{s - 2}" height="{s - 2}" rx="{r - 1}" fill="none" stroke="url(#rim)" stroke-width="2"/>
</svg>'''


# ---------------- A · The Orb ---------------------------------------------------------
# Exactly the menu-bar orb (OrbGeometry: r 7.5, lw 1.4, start 145°, sweep 250°, dots 125/102/79/56°).
def concept_a():
    k = 34.0; cx, cy = 512, 492
    R, LW = 7.5 * k, 1.4 * k * 1.35
    dots = "".join(
        f'<circle cx="{pt(cx, cy, R, a)[0]:.2f}" cy="{pt(cx, cy, R, a)[1]:.2f}" r="{1.3 * k * 0.5:.2f}" fill="#fff" opacity="{1 if i < 2 else .38}"/>'
        for i, a in enumerate([125, 102, 79, 56]))
    fg = (f'<path d="{arc(cx, cy, R, 145, 395)}" fill="none" stroke="#fff" stroke-opacity=".28" stroke-width="{LW}" stroke-linecap="round"/>'
          f'<path d="{arc(cx, cy, R, 145, 145 + 250 * .78)}" fill="none" stroke="url(#fgA)" stroke-width="{LW}" stroke-linecap="round"/>'
          + dots + wifi(cx, cy + 26, 17, "url(#fgA)", 32))
    defs = ('<linearGradient id="bgA" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4C8DFF"/><stop offset="1" stop-color="#1532B5"/></linearGradient>'
            '<linearGradient id="fgA" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#E4ECFF"/></linearGradient>')
    return tile(defs, "url(#bgA)", fg, "A")


# ---------------- B · Four into One ---------------------------------------------------
def concept_b():
    cx, cy = 512, 512
    colors = ["#34C759", "#0A84FF", "#FF9F0A", "#BF5AF2"]  # battery, wifi, sound, bluetooth
    streams = "".join(
        f'<path d="{spiral(cx, cy, 322, 176, 196 + i * 90, 286 + i * 90)}" fill="none" stroke="{c}" stroke-width="46" stroke-linecap="round"/>'
        for i, c in enumerate(colors))
    ring = f'<path d="{arc(cx, cy, 140, 145, 395)}" fill="none" stroke="#fff" stroke-width="52" stroke-linecap="round"/>'
    core = f'<circle cx="{cx}" cy="{cy + 128 * .98}" r="0" fill="#fff"/>'
    dots = "".join(f'<circle cx="{pt(cx, cy, 140, a)[0]:.2f}" cy="{pt(cx, cy, 140, a)[1]:.2f}" r="15" fill="#fff" opacity="{1 if i < 2 else .4}"/>'
                   for i, a in enumerate([125, 102, 79, 56]))
    fg = streams + ring + dots + core
    defs = '<radialGradient id="bgB" cx=".5" cy=".38" r=".75"><stop offset="0" stop-color="#3A3A40"/><stop offset="1" stop-color="#121214"/></radialGradient>'
    return tile(defs, "url(#bgB)", fg, "B")


# ---------------- C · Calm ------------------------------------------------------------
def concept_c():
    cx, cy = 512, 500
    ring = f'<path d="{arc(cx, cy, 250, 145, 395)}" fill="none" stroke="#1D1D1F" stroke-width="92" stroke-linecap="round"/>'
    core = f'<circle cx="{cx}" cy="{cy}" r="78" fill="url(#coreC)"/>'
    dots = "".join(f'<circle cx="{pt(cx, cy, 250, a)[0]:.2f}" cy="{pt(cx, cy, 250, a)[1]:.2f}" r="24" fill="#1D1D1F" opacity="{1 if i < 2 else .25}"/>'
                   for i, a in enumerate([125, 102, 79, 56]))
    fg = ring + core + dots
    defs = ('<linearGradient id="bgC" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#E6E7EE"/></linearGradient>'
            '<radialGradient id="coreC" cx=".38" cy=".32" r=".8"><stop offset="0" stop-color="#FFB340"/><stop offset="1" stop-color="#FF6A00"/></radialGradient>')
    return tile(defs, "url(#bgC)", fg, "C")


if __name__ == "__main__":
    for name, fn in [("A-orb", concept_a), ("B-four-into-one", concept_b), ("C-calm", concept_c)]:
        (OUT / f"{name}.svg").write_text(fn())
    print("wrote concepts")
