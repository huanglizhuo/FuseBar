"""Original FuseBar vector artwork. No system symbols or baked lighting effects."""
import math
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent

def point(cx, cy, radius, angle):
    a = math.radians(angle)
    return cx + radius * math.cos(a), cy + radius * math.sin(a)

def xy(p):
    return f'{p[0]:.3f},{p[1]:.3f}'

def ribbon(cx, cy, radius, width, start, end):
    outer, inner = radius + width / 2, radius - width / 2
    large = int(end - start > 180)
    return (f'M {xy(point(cx,cy,outer,start))} '
            f'A {outer},{outer} 0 {large} 1 {xy(point(cx,cy,outer,end))} '
            f'A {width/2},{width/2} 0 0 1 {xy(point(cx,cy,inner,end))} '
            f'A {inner},{inner} 0 {large} 0 {xy(point(cx,cy,inner,start))} '
            f'A {width/2},{width/2} 0 0 1 {xy(point(cx,cy,outer,start))} Z')

def svg(name, content):
    (ROOT / name).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n{content}\n</svg>\n')

svg('01-orbit.svg', f'<path fill="#FFFFFF" d="{ribbon(512,500,278,80,130,410)}"/>')
svg('02-converging-signals.svg', '\n'.join(f'<path fill="#FFFFFF" d="{ribbon(512,586,r,w,218,322)}"/>' for r,w in [(190,53),(108,49)]))
svg('03-merged-core.svg', '<circle fill="#FFFFFF" cx="512" cy="584" r="30"/>')

assets = ROOT.parent.parent / 'Sources/FuseBar/AppIcon.icon/Assets'
assets.mkdir(parents=True, exist_ok=True)
for source in ROOT.glob('*.svg'):
    shutil.copy2(source, assets / source.name)
