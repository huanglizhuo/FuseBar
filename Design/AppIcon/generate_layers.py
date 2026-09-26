"""Original FuseBar vector artwork (v2 “The Orb”). No system symbols or baked lighting effects.

The icon is the menu-bar orb itself, scaled up as a brand form:
  01 · open ring with the orb's 110° bottom gap (OrbGeometry.ringStartAngle 145°, sweep 250°):
       a faint full track plus a solid value arc, the same two-part ring the status item draws
  02 · the four status dots that sit in that gap (OrbGeometry.dotAngles); two lit, two dimmed
  03 · the network signal at the centre, the orb's default centre icon
The value arc is a fixed brand proportion, not a live battery reading.
Coordinates are the concept artwork (Design/AppIcon/concepts/A-orb.svg, 824 px body)
scaled to Icon Composer's full 1024 canvas.
"""
import math
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent
K = 1024 / 824                          # concept body → Icon Composer canvas

def S(x, y):                            # concept coordinates → canvas
    return 512 + (x - 512) * K, 512 + (y - 512) * K

CX, CY = S(512, 492)
R, W = 255 * K, 64.26 * K               # ring radius and solid width
VALUE_END = 145 + 250 * 0.78            # fixed brand proportion of the ring
DOT_R = 22.1 * K
WIFI_C = S(512, 596.2)
WIFI_W, WIFI_DOT = 32 * K, 22.95 * K

def point(cx, cy, radius, angle):
    a = math.radians(angle)
    return cx + radius * math.cos(a), cy + radius * math.sin(a)

def xy(p):
    return f'{p[0]:.3f},{p[1]:.3f}'

def ribbon(cx, cy, radius, width, start, end):
    outer, inner = radius + width / 2, radius - width / 2
    large = int(end - start > 180)
    return (f'M {xy(point(cx,cy,outer,start))} '
            f'A {outer:.3f},{outer:.3f} 0 {large} 1 {xy(point(cx,cy,outer,end))} '
            f'A {width/2:.3f},{width/2:.3f} 0 0 1 {xy(point(cx,cy,inner,end))} '
            f'A {inner:.3f},{inner:.3f} 0 {large} 0 {xy(point(cx,cy,inner,start))} '
            f'A {width/2:.3f},{width/2:.3f} 0 0 1 {xy(point(cx,cy,outer,start))} Z')

def circle(cx, cy, r):
    # A circle as a filled path (two arcs), so every layer is paths only.
    return f'M {cx - r:.3f},{cy:.3f} A {r:.3f},{r:.3f} 0 1 0 {cx + r:.3f},{cy:.3f} A {r:.3f},{r:.3f} 0 1 0 {cx - r:.3f},{cy:.3f} Z'

def svg(name, content):
    (ROOT / name).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n{content}\n</svg>\n')

for old in ROOT.glob('0*.svg'):
    old.unlink()

svg('01-orbit.svg', '\n'.join([
    f'<path fill="#FFFFFF" fill-opacity="0.28" d="{ribbon(CX, CY, R, W, VALUE_END, 395)}"/>',
    f'<path fill="#FFFFFF" d="{ribbon(CX, CY, R, W, 145, VALUE_END)}"/>',
]))
svg('02-status-dots.svg', '\n'.join(
    f'<path fill="#FFFFFF" fill-opacity="{1 if i < 2 else 0.38}" d="{circle(*point(CX, CY, R, a), DOT_R)}"/>'
    for i, a in enumerate((125, 102, 79, 56))))
svg('03-signal.svg', '\n'.join(
    [f'<path fill="#FFFFFF" d="{ribbon(*WIFI_C, r * K, WIFI_W, 225, 315)}"/>' for r in (56.1, 107.1, 158.1)]
    + [f'<path fill="#FFFFFF" d="{circle(*WIFI_C, WIFI_DOT)}"/>']))

assets = ROOT.parent.parent / 'Sources/FuseBar/AppIcon.icon/Assets'
if assets.parent.exists():
    assets.mkdir(parents=True, exist_ok=True)
    for old in assets.glob('0*.svg'):
        old.unlink()
    for source in sorted(ROOT.glob('0*.svg')):
        shutil.copy2(source, assets / source.name)
