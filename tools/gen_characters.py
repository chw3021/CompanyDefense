"""직원 전투 스프라이트(SVG) 생성기.

직원마다 머리 모양, 얼굴, 옷, 소품을 조합해 전투 맵에 서는 SD 캐릭터를 만든다.
  assets/tower/<팀>/<id>_sprite.svg  (256x256 → 128px 텍스처)
직원 카드/직원 탭의 초상화는 별도 일러스트(assets/tower/<팀>/<id>.png)를 쓴다.

실행: python tools/gen_characters.py
"""
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = "#2b2233"  # 외곽선


# ------------------------------------------------------------------ SVG 도우미

def n(v):
    s = f"{v:.1f}"
    return s[:-2] if s.endswith(".0") else s


def shade(hex_color, k):
    """k < 1 이면 어둡게, k > 1 이면 밝게"""
    h = hex_color.lstrip("#")
    rgb = [int(h[i:i + 2], 16) for i in (0, 2, 4)]
    if k <= 1:
        rgb = [c * k for c in rgb]
    else:
        rgb = [c + (255 - c) * (k - 1) for c in rgb]
    return "#" + "".join(f"{int(max(0, min(255, round(c)))):02x}" for c in rgb)


def stroke_attr(sw, color=OUT):
    if not sw:
        return ""
    return f' stroke="{color}" stroke-width="{n(sw)}" stroke-linejoin="round" stroke-linecap="round"'


def path(d, fill, sw=0, stroke=OUT, extra=""):
    return f'<path d="{d}" fill="{fill}"{stroke_attr(sw, stroke)}{extra}/>'


def circle(x, y, r, fill, sw=0, extra=""):
    return f'<circle cx="{n(x)}" cy="{n(y)}" r="{n(r)}" fill="{fill}"{stroke_attr(sw)}{extra}/>'


def ellipse(x, y, rx, ry, fill, sw=0, extra=""):
    return f'<ellipse cx="{n(x)}" cy="{n(y)}" rx="{n(rx)}" ry="{n(ry)}" fill="{fill}"{stroke_attr(sw)}{extra}/>'


def rect(x, y, w, h, fill, sw=0, r=0, extra=""):
    return f'<rect x="{n(x)}" y="{n(y)}" width="{n(w)}" height="{n(h)}" rx="{n(r)}" fill="{fill}"{stroke_attr(sw)}{extra}/>'


def line(points, color, width, extra=""):
    d = "M" + " L".join(f"{n(x)},{n(y)}" for x, y in points)
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{n(width)}" stroke-linecap="round" stroke-linejoin="round"{extra}/>'


def poly(points):
    return "M" + " L".join(f"{n(x)},{n(y)}" for x, y in points) + "Z"


def smooth(points, closed=True):
    """Catmull-Rom 곡선으로 점들을 부드럽게 잇는다"""
    count = len(points)
    d = f"M{n(points[0][0])},{n(points[0][1])}"
    last = count if closed else count - 1
    for i in range(last):
        p0 = points[(i - 1) % count] if (closed or i > 0) else points[i]
        p1 = points[i]
        p2 = points[(i + 1) % count]
        p3 = points[(i + 2) % count] if (closed or i + 2 < count) else p2
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f" C{n(c1[0])},{n(c1[1])} {n(c2[0])},{n(c2[1])} {n(p2[0])},{n(p2[1])}"
    return d + ("Z" if closed else "")


def limb(points, width, color, sw):
    """팔다리: 굵은 선을 외곽선 색으로 한 번, 옷 색으로 한 번 그린다"""
    return line(points, OUT, width + sw * 2) + line(points, color, width)


def arc_points(rx, ry, cy, a0, a1, count, radii=None):
    pts = []
    for i in range(count):
        a = math.radians(a0 + (a1 - a0) * i / (count - 1))
        r = radii[i % len(radii)] if radii else 1.0
        pts.append((math.cos(a) * rx * r, cy - math.sin(a) * ry * r))
    return pts


def mirror(points):
    return [(-x, y) for x, y in reversed(points)]


def group(content, tx=0, ty=0, s=1.0):
    return f'<g transform="translate({n(tx)},{n(ty)}) scale({n(s)})">{"".join(content)}</g>'


# ------------------------------------------------------------------ 머리카락 (머리 중심 기준 좌표, 얼굴 반지름 약 60)

def hair_layers(style, color, sw, long_len):
    """(뒷머리, 앞머리) SVG 조각 목록"""
    back, front = [], []
    dark = shade(color, 0.8)
    L = long_len

    def side_part_bangs():
        return [(58, 8), (54, -12), (36, -24), (12, -28), (-10, -40), (-24, -24), (-44, -16), (-58, -2), (-62, 10)]

    outer = arc_points(64, 70, -4, 192, -12, 9)
    if style == "side_part":
        front.append(path(smooth(outer + side_part_bangs()), color, sw))
    elif style == "messy":
        outer = arc_points(62, 66, -4, 196, -16, 13, [1.0, 1.15])
        bangs = [(60, 10), (52, -8), (44, -22), (34, -6), (22, -26), (10, -8), (-2, -28),
                 (-14, -10), (-26, -26), (-36, -8), (-46, -22), (-54, -6), (-62, 10)]
        front.append(path(smooth(outer + bangs), color, sw))
    elif style == "spiky":
        outer = arc_points(60, 64, -4, 200, -20, 15, [1.0, 1.34])
        bangs = [(60, 12), (50, -14), (40, 4), (28, -22), (16, 0), (4, -26), (-8, 2),
                 (-20, -22), (-32, 2), (-44, -16), (-54, 4), (-62, 12)]
        front.append(path(poly(outer + bangs), color, sw))
    elif style == "bob_straight":
        back.append(path(smooth([(-64, -30), (-72, 10), (-72, 58), (-50, 66), (50, 66), (72, 58), (72, 10), (64, -30), (0, -76)]), dark, sw))
        pts = [(-72, 58), (-74, 12)] + arc_points(68, 72, -4, 190, -10, 9) + [(74, 12), (72, 58), (60, 60), (56, 20), (54, -6), (30, -10), (0, -9), (-30, -10), (-54, -6), (-56, 20), (-60, 60)]
        front.append(path(smooth(pts), color, sw))
    elif style in ("long_straight", "long_wavy", "bun", "long_center"):
        wave = 7 if style != "long_straight" else 0
        side = []
        steps = 6
        for i in range(steps + 1):
            y = 10 + (L - 10) * i / steps
            side.append((-74 - (wave if i % 2 else 0), y))
        bottom = [(-50, L + 8), (-18, L + 2), (18, L + 2), (50, L + 8)] if wave else [(-50, L + 6), (50, L + 6)]
        back.append(path(smooth([(-62, -32)] + side + bottom + mirror(side) + [(62, -32), (0, -78)]), dark, sw))
        if style == "bun":
            back.append(circle(0, -80, 22, color, sw))
            back.append(path("M-12,-84 Q0,-94 12,-84", "none", sw * 0.7, dark))
        if style == "long_center":
            bangs = [(66, 64), (58, 66), (56, 20), (46, -18), (24, -40), (2, -50), (0, -38), (-2, -50), (-24, -40), (-46, -18), (-56, 20), (-58, 66)]
        else:
            bangs = [(68, 64), (58, 66), (56, 20), (50, -14), (28, -34), (8, -46), (-6, -30), (-28, -18), (-48, -6), (-56, 20), (-58, 62)]
        front.append(path(smooth([(-66, 62), (-72, 10)] + arc_points(66, 72, -4, 190, -10, 9) + [(72, 10)] + bangs), color, sw))
    elif style == "ponytail":
        back.append(path(smooth([(30, -62), (62, -60), (86, -32), (92, 10), (88, 60), (78, 104), (64, 126), (58, 92), (66, 50), (64, 10), (50, -30)]), dark, sw))
        back.append(circle(58, -56, 8, shade(color, 0.6), sw))
        pts = [(-66, 34), (-70, 8)] + outer + [(62, 30), (56, 32), (54, -10), (36, -26), (12, -30), (-12, -40), (-26, -24), (-44, -16), (-56, 0), (-58, 34)]
        front.append(path(smooth(pts), color, sw))
    elif style == "twin_tails":
        left = [(-44, -50), (-80, -54), (-104, -20), (-110, 30), (-102, 84), (-88, 108), (-90, 66), (-84, 16), (-66, -22)]
        back.append(path(smooth(left), dark, sw))
        back.append(path(smooth(mirror(left)), dark, sw))
        bangs = [(60, 14), (54, -8), (42, -20), (30, -6), (18, -26), (4, -10), (-8, -30), (-20, -10), (-32, -24), (-44, -8), (-54, -12), (-62, 14)]
        front.append(path(smooth(outer + bangs), color, sw))
    elif style == "slicked":
        bangs = [(60, 8), (56, -14), (42, -32), (16, -38), (-16, -38), (-42, -32), (-56, -14), (-60, 8)]
        front.append(path(smooth(arc_points(64, 72, -4, 190, -10, 9) + bangs), color, sw))
        for dx in (-26, 0, 26):
            front.append(path(f"M{dx * 0.6},-40 Q{dx},-56 {dx * 1.4},-68", "none", sw * 0.7, dark))
    elif style == "crop":
        front.append(ellipse(-57, -4, 9, 18, "#9aa0aa", sw))
        front.append(ellipse(57, -4, 9, 18, "#9aa0aa", sw))
        bangs = [(56, -10), (44, -36), (20, -44), (-20, -44), (-44, -36), (-56, -10)]
        front.append(path(smooth([(-58, -10), (-62, -48), (-40, -72), (40, -72), (62, -48), (58, -10)] + bangs), color, sw))
    elif style == "bob_messy":
        back.append(path(smooth([(-62, -30), (-76, 10), (-80, 44), (-66, 56), (-56, 42), (56, 42), (66, 56), (80, 44), (76, 10), (62, -30), (0, -80)]), dark, sw))
        bangs = [(70, 40), (58, 44), (56, 10), (46, -14), (34, -2), (22, -24), (8, -6), (-6, -28), (-18, -8), (-32, -24), (-44, -6), (-56, 10), (-58, 44)]
        front.append(path(smooth([(-70, 40), (-72, 8)] + arc_points(66, 72, -4, 190, -10, 9) + [(72, 8)] + bangs), color, sw))
        front.append(path("M-6,-72 Q-16,-92 -30,-90", "none", sw, color))
        front.append(path("M10,-72 Q14,-94 30,-96", "none", sw, color))
    # 머리 윤기 (밝은 띠)
    if style not in ("spiky", "crop"):
        front.append(path("M-34,-52 Q-10,-66 18,-62", "none", sw * 1.6, shade(color, 1.35), ' opacity="0.7"'))
    return back, front


# ------------------------------------------------------------------ 얼굴

FACE = "M-56,-5 C-56,-50 -30,-62 0,-62 C30,-62 56,-50 56,-5 C56,30 35,60 0,62 C-35,60 -56,30 -56,-5Z"


def eyes(spec, sw):
    s = []
    style = spec.get("eyes", "normal")
    iris = spec.get("iris", "#3b2a24")
    for side in (-1, 1):
        x, y = 21 * side, 10
        if style == "normal" or style == "big":
            big = style == "big"
            rx, ry = (9, 12) if big else (7.5, 10)
            s.append(ellipse(x, y, rx, ry, iris))
            s.append(ellipse(x, y + 2, rx * 0.55, ry * 0.6, shade(iris, 0.45)))
            s.append(circle(x - 2.5, y - 4, rx * 0.36, "#ffffff"))
            if big:
                s.append(circle(x + 3, y + 4, 1.8, "#ffffff"))
            s.append(path(f"M{n(x - rx - 2)},{n(y - ry * 0.4)} Q{n(x)},{n(y - ry - 4)} {n(x + rx + 2)},{n(y - ry * 0.4)}", "none", sw * 1.1))
        elif style == "tired":
            s.append(ellipse(x, y + 2, 8, 8, iris))
            s.append(circle(x, y + 3, 3.5, shade(iris, 0.4)))
            s.append(circle(x - 2, y, 2, "#ffffff"))
            s.append(path(f"M{n(x - 11)},{n(y - 7)} L{n(x + 11)},{n(y - 7)} L{n(x + 11)},{n(y - 1)} Q{n(x)},{n(y - 4)} {n(x - 11)},{n(y - 1)}Z", spec["skin"]))
            s.append(path(f"M{n(x - 11)},{n(y - 1)} Q{n(x)},{n(y - 4)} {n(x + 11)},{n(y - 1)}", "none", sw * 1.1))
            s.append(path(f"M{n(x - 8)},{n(y + 13)} Q{n(x)},{n(y + 17)} {n(x + 8)},{n(y + 13)}", "none", sw * 0.6, "#8a6a7a"))
        elif style == "sharp":
            s.append(path(f"M{n(x - 10 * side)},{n(y + 1)} Q{n(x)},{n(y - 7)} {n(x + 10 * side)},{n(y - 3)} Q{n(x)},{n(y + 7)} {n(x - 10 * side)},{n(y + 1)}Z", iris))
            s.append(circle(x, y, 2, "#ffffff"))
            s.append(path(f"M{n(x - 12 * side)},{n(y + 1)} Q{n(x)},{n(y - 9)} {n(x + 12 * side)},{n(y - 5)}", "none", sw * 1.3))
        elif style == "glow":
            s.append(ellipse(x, y + 14, 13, 6, "#3a2a40", extra=' opacity="0.35"'))
            s.append(circle(x, y, 15, "#ff2a3a", extra=' opacity="0.35"'))
            s.append(circle(x, y, 9, "#ff3b4a"))
            s.append(circle(x, y, 4, "#fff2f2"))
        elif style == "happy":
            s.append(path(f"M{n(x - 8)},{n(y + 3)} Q{n(x)},{n(y - 8)} {n(x + 8)},{n(y + 3)}", "none", sw * 1.3))
    # 눈썹
    brow = spec.get("brow", "normal")
    bc = shade(spec["hair"], 0.7)
    for side in (-1, 1):
        x = 21 * side
        if brow == "angry":
            pts = [(x + 11 * side, -16), (x - 9 * side, -7)]
        elif brow == "worried":
            pts = [(x + 10 * side, -9), (x - 8 * side, -16)]
        else:
            pts = [(x - 9, -12), (x, -15), (x + 9, -12)]
        s.append(line(pts, bc, sw * 1.3))
    return s


def mouth(spec, sw):
    m = spec.get("mouth", "smile")
    if m == "smile":
        return [path("M-9,33 Q0,41 9,33", "none", sw * 1.1)]
    if m == "grin":
        return [path("M-15,29 Q0,31 15,29 Q12,49 0,50 Q-12,49 -15,29Z", "#8c2f3a", sw),
                path("M-8,44 Q0,38 8,44 Q4,49 0,49 Q-4,49 -8,44Z", "#e96a6a"),
                path("M-12,30 L12,30 L10,34 L-10,34Z", "#ffffff")]
    if m == "open":
        return [path("M-9,31 Q0,30 9,31 Q7,43 0,44 Q-7,43 -9,31Z", "#8c2f3a", sw),
                path("M-5,40 Q0,36 5,40 Q2,43 0,43 Q-2,43 -5,40Z", "#e96a6a")]
    if m == "neutral":
        return [line([(-6, 36), (6, 36)], OUT, sw * 1.1)]
    if m == "frown":
        return [path("M-8,38 Q0,32 8,38", "none", sw * 1.1)]
    if m == "smirk":
        return [path("M-8,35 Q3,39 11,31", "none", sw * 1.1)]
    if m == "wobbly":
        return [path("M-8,36 Q-4,32 0,36 Q4,40 8,36", "none", sw * 1.1)]
    if m == "lips":
        return [path("M-9,33 Q0,30 9,33 Q0,42 -9,33Z", "#d8394f", sw * 0.6)]
    return []


def glasses(kind, sw):
    if not kind:
        return []
    s = []
    if kind in ("round", "square", "pale"):
        color = "#f2efe6" if kind == "pale" else OUT
        lens = ' fill="#ffffff" fill-opacity="0.25"' if kind != "pale" else ' fill="#fff8dc" fill-opacity="0.75"'
        for side in (-1, 1):
            x = 21 * side
            if kind == "round":
                s.append(f'<circle cx="{n(x)}" cy="10" r="15"{lens} stroke="{color}" stroke-width="{n(sw * 1.3)}"/>')
            else:
                s.append(f'<rect x="{n(x - 17)}" y="-2" width="34" height="24" rx="6"{lens} stroke="{color}" stroke-width="{n(sw * 1.3)}"/>')
        s.append(line([(-6, 8), (6, 8)], color, sw * 1.3))
        s.append(line([(-36, 6), (-52, 2)], color, sw * 1.1))
        s.append(line([(36, 6), (52, 2)], color, sw * 1.1))
        if kind == "pale":
            s.append(path("M-38,-2 L-4,-2 M4,-2 L38,-2", "none", sw * 0.8))
    elif kind == "sun":
        for side in (-1, 1):
            x = 21 * side
            s.append(path(f"M{n(x - 17)},0 L{n(x + 17)},0 Q{n(x + 16)},20 {n(x)},20 Q{n(x - 16)},20 {n(x - 17)},0Z", "#1e1b2a", sw))
            s.append(line([(x - 9, 5), (x - 3, 5)], "#ffffff", sw * 0.8, ' opacity="0.6"'))
        s.append(line([(-4, 3), (4, 3)], OUT, sw * 1.3))
    elif kind == "visor":
        s.append(path("M-54,2 Q0,-8 54,2 L52,20 Q0,12 -52,20Z", "#38e8ff", sw, extra=' fill-opacity="0.75"'))
        s.append(line([(-40, 8), (-10, 4)], "#ffffff", sw, ' opacity="0.8"'))
    return s


def head_back(spec, sw, long_len):
    back, _ = hair_layers(spec["hair_style"], spec["hair"], sw, long_len)
    return back


def head_front(spec, sw, long_len):
    s = []
    skin = spec["skin"]
    s.append(circle(-55, 10, 10, skin, sw))
    s.append(circle(55, 10, 10, skin, sw))
    s.append(path(FACE, skin, sw))
    if spec.get("beard"):
        b = spec["hair"]
        s.append(path("M-50,14 Q-48,52 0,64 Q48,52 50,14 Q44,30 30,36 Q14,30 0,30 Q-14,30 -30,36 Q-44,30 -50,14Z", b, sw))
        s.append(path("M-14,33 Q0,41 14,33", "none", sw, skin))
    if spec.get("blush"):
        s.append(ellipse(-32, 27, 9, 5, "#ff7f8a", extra=' opacity="0.5"'))
        s.append(ellipse(32, 27, 9, 5, "#ff7f8a", extra=' opacity="0.5"'))
    s.append(path("M1,19 Q-2,25 3,25", "none", sw * 0.8, shade(skin, 0.7)))
    s += eyes(spec, sw)
    s += mouth(spec, sw)
    _, front = hair_layers(spec["hair_style"], spec["hair"], sw, long_len)
    s += front
    s += glasses(spec.get("glasses"), sw)
    if spec.get("sweat"):
        s.append(path("M48,-18 Q42,-6 48,-2 Q54,-6 48,-18Z", "#9fdcff", sw * 0.7))
    if spec.get("ribbon"):
        for side in (-1, 1):
            x = 52 * side
            s.append(path(poly([(x, -52), (x - 16, -64), (x - 16, -40)]), "#22202a", sw * 0.6))
            s.append(path(poly([(x, -52), (x + 16, -64), (x + 16, -40)]), "#22202a", sw * 0.6))
    return s


# ------------------------------------------------------------------ 몸 (rig: SD 기준점)

SPRITE = dict(W=256, H=256, cx=128, head=(128, 92, 1.12), long=92, neck_top=150, neck_bot=176,
              neck_w=24, sy=170, sh=42, waist_y=204, wh=36, hem_y=218, hh=40, hip_y=212, hip_dx=14,
              ankle_y=238, leg_w=24, shoe=(16, 8), k=0.4, arm_w=19, hand_r=8.5, skirt_y=232,
              long_skirt_y=238, sw=6.0, ground=246, prop=0.55)


def torso_path(R, hem=None):
    cx, sy, sh = R["cx"], R["sy"], R["sh"]
    wy, wh, hh = R["waist_y"], R["wh"], R["hh"]
    hem = hem or R["hem_y"]
    r = sh * 0.35
    return (f"M{n(cx - sh + r)},{n(sy)} L{n(cx + sh - r)},{n(sy)} Q{n(cx + sh)},{n(sy)} {n(cx + sh)},{n(sy + r)} "
            f"L{n(cx + wh)},{n(wy)} L{n(cx + hh)},{n(hem)} L{n(cx - hh)},{n(hem)} L{n(cx - wh)},{n(wy)} "
            f"L{n(cx - sh)},{n(sy + r)} Q{n(cx - sh)},{n(sy)} {n(cx - sh + r)},{n(sy)}Z")


def arm_points(R, side, pose):
    """side: -1 화면 왼쪽, 1 오른쪽. 반환: (어깨, 팔꿈치, 손목)"""
    k, cx, sy, sh = R["k"], R["cx"], R["sy"], R["sh"]
    S = (cx + side * (sh - 9 * k - 2), sy + 10 * k + 2)
    o = side  # 바깥쪽 방향
    if pose == "down":
        return S, (S[0] + o * 8 * k, S[1] + 60 * k), (S[0] + o * 10 * k, S[1] + 112 * k)
    if pose == "front":
        return S, (S[0] + o * 10 * k, S[1] + 58 * k), (cx + o * 26 * k, S[1] + 96 * k)
    if pose == "raise":
        return S, (S[0] + o * 14 * k, S[1] + 62 * k), (S[0] - o * 12 * k, S[1] + 30 * k)
    if pose == "hip":
        return S, (S[0] + o * 30 * k, S[1] + 52 * k), (S[0] + o * 2 * k, S[1] + 100 * k)
    if pose in ("pocket", "behind"):
        return S, (S[0] + o * 6 * k, S[1] + 58 * k), (S[0] - o * 4 * k, S[1] + 100 * k)
    raise ValueError(pose)


def arm(R, spec, side, pose, sleeve, rolled=False, cuff=None):
    sw, w, skin = R["sw"], R["arm_w"], spec["skin"]
    S, E, W = arm_points(R, side, pose)
    s = []
    if rolled:
        s.append(limb([E, W], w * 0.82, skin, sw))
        s.append(limb([S, E], w, sleeve, sw))
        cuff_from = (E[0] + (S[0] - E[0]) * 0.22, E[1] + (S[1] - E[1]) * 0.22)
        butt = ' stroke-linecap="butt"'
        s.append(line([cuff_from, E], OUT, w + sw * 2, butt).replace(' stroke-linecap="round"', ""))
        s.append(line([cuff_from, E], shade(sleeve, 0.9), w, butt).replace(' stroke-linecap="round"', ""))
    else:
        s.append(limb([S, E, W], w, sleeve, sw))
        if cuff:
            t = 0.82
            C = (E[0] + (W[0] - E[0]) * t, E[1] + (W[1] - E[1]) * t)
            s.append(line([C, W], cuff, w * 0.9))
    hand = None
    if pose not in ("pocket", "behind"):
        hand = (W[0], W[1] + R["hand_r"] * 0.4)
        s.append(circle(hand[0], hand[1], R["hand_r"], skin, sw))
    return s, hand


def legs(R, spec):
    """하의와 신발"""
    sw, cx, k = R["sw"], R["cx"], R["k"]
    bottom = spec["bottom"]
    s = []
    lx, rx = cx - R["hip_dx"], cx + R["hip_dx"]
    ay = R["ankle_y"]
    kind = bottom[0]
    shoe_color = spec.get("shoes", "#26222c")
    if kind in ("pants", "jeans"):
        color = bottom[1]
        for x, d in ((lx, -1), (rx, 1)):
            s.append(limb([(x, R["hip_y"]), (x + d * 2 * k, ay)], R["leg_w"], color, sw))
        s.append(rect(cx - R["hh"] + 4 * k, R["hip_y"] - 14 * k, (R["hh"] - 4 * k) * 2, 30 * k + 6, color))
        s.append(line([(cx, R["hip_y"] + 4 * k), (cx, R["hip_y"] + 40 * k)], shade(color, 0.7), sw))
        if kind == "jeans":
            for x, d in ((lx, -1), (rx, 1)):
                s.append(rect(x + d * 2 * k - R["leg_w"] / 2 - 1, ay - 16 * k - 4, R["leg_w"] + 2, 14 * k + 4, shade(color, 1.25), sw, 3))
    else:
        color, bottom_y = bottom[1], (R["skirt_y"] if kind == "skirt" else R["long_skirt_y"])
        tights = spec.get("tights", spec["skin"])
        for x in (lx + 4 * k, rx - 4 * k):
            s.append(limb([(x, bottom_y - 10), (x, ay)], R["leg_w"] * 0.6, tights, sw))
        top = R["waist_y"]
        flare = 6 * k if kind == "skirt" else 22 * k
        pts = [(cx - R["wh"], top), (cx + R["wh"], top), (cx + R["hh"] + flare, bottom_y), (cx - R["hh"] - flare, bottom_y)]
        s.append(path(poly(pts), color, sw))
        if kind == "plaid":
            stripe = shade(color, 1.45)
            for i in range(1, 6):
                t = i / 6
                xa = pts[0][0] + (pts[1][0] - pts[0][0]) * t
                xb = pts[3][0] + (pts[2][0] - pts[3][0]) * t
                s.append(line([(xa, top + 2), (xb, bottom_y - 2)], stripe, sw * 0.9, ' opacity="0.8"'))
            for i in range(1, 5):
                t = i / 5
                y = top + (bottom_y - top) * t
                half = R["wh"] + (R["hh"] + flare - R["wh"]) * t
                s.append(line([(cx - half + 2, y), (cx + half - 2, y)], stripe, sw * 0.9, ' opacity="0.8"'))
    # 신발
    rx_, ry_ = R["shoe"]
    shoe_kind = spec.get("shoe_kind", "dress")
    for x, d in ((lx, -1), (rx, 1)):
        if kind not in ("pants", "jeans"):
            x += -d * 4 * k
        sx, sy = x + d * 4 * k, ay + ry_ * 0.5
        if shoe_kind == "heel":
            s.append(path(f"M{n(sx - rx_ * 0.7)},{n(sy + ry_ * 0.6)} Q{n(sx - rx_ * 0.6)},{n(sy - ry_)} {n(sx)},{n(sy - ry_)} Q{n(sx + rx_ * 0.9)},{n(sy - ry_ * 0.4)} {n(sx + rx_ * 0.8)},{n(sy + ry_ * 0.6)}Z", shoe_color, sw))
        else:
            s.append(ellipse(sx, sy, rx_, ry_, shoe_color, sw))
            if shoe_kind == "sneaker":
                s.append(line([(sx - rx_ * 0.8, sy + ry_ * 0.35), (sx + rx_ * 0.8, sy + ry_ * 0.35)], "#ffffff", sw * 1.2))
    return s


def outfit(R, spec):
    """목, 상의, 상의 장식"""
    sw, cx, sy, sh, k = R["sw"], R["cx"], R["sy"], R["sh"], R["k"]
    top = spec["top"]
    kind = top[0]
    T = R["hem_y"] - sy
    skin = spec["skin"]
    s = []
    hem = R["waist_y"] + (R["hem_y"] - R["waist_y"]) * 0.5 if kind == "blazer_f" else None
    if kind == "hoodie":
        s.append(ellipse(cx, sy + 2, sh * 0.62, T * 0.12, shade(top[1], 0.8), sw))
    # 목
    s.append(rect(cx - R["neck_w"] / 2, R["neck_top"], R["neck_w"], R["neck_bot"] - R["neck_top"], skin, sw))
    s.append(rect(cx - R["neck_w"] / 2 + sw / 2, R["neck_top"], R["neck_w"] - sw, (R["neck_bot"] - R["neck_top"]) * 0.45, shade(skin, 0.85)))
    color = top[1]
    s.append(path(torso_path(R, hem), color, sw))
    v_depth = T * 0.62
    if kind in ("suit", "blazer_f"):
        shirt, tie = top[2], top[3] if len(top) > 3 else None
        s.append(path(poly([(cx - sh * 0.3, sy - 1), (cx + sh * 0.3, sy - 1), (cx, sy + v_depth)]), shirt, sw))
        s.append(path(poly([(cx - sh * 0.3, sy - 1), (cx - sh * 0.02, sy + T * 0.14), (cx - sh * 0.2, sy + T * 0.2)]), shirt, sw * 0.8))
        s.append(path(poly([(cx + sh * 0.3, sy - 1), (cx + sh * 0.02, sy + T * 0.14), (cx + sh * 0.2, sy + T * 0.2)]), shirt, sw * 0.8))
        if tie:
            s.append(path(poly([(cx - sh * 0.07, sy + T * 0.1), (cx + sh * 0.07, sy + T * 0.1), (cx + sh * 0.05, sy + T * 0.18), (cx - sh * 0.05, sy + T * 0.18)]), shade(tie, 0.85), sw * 0.8))
            s.append(path(poly([(cx - sh * 0.05, sy + T * 0.18), (cx + sh * 0.05, sy + T * 0.18), (cx + sh * 0.1, sy + T * 0.52), (cx, sy + T * 0.6), (cx - sh * 0.1, sy + T * 0.52)]), tie, sw * 0.8))
            if "stripe" in top[4:]:
                for t in (0.28, 0.38, 0.48):
                    s.append(line([(cx - sh * 0.07, sy + T * t), (cx + sh * 0.08, sy + T * (t - 0.05))], shade(tie, 1.5), sw * 0.8))
        if spec.get("necklace"):
            s.append(path(f"M{n(cx - sh * 0.16)},{n(sy + 2)} Q{n(cx)},{n(sy + T * 0.3)} {n(cx + sh * 0.16)},{n(sy + 2)}", "none", sw * 0.6, "#e8c25a"))
            s.append(circle(cx, sy + T * 0.25, 3 * k + 1.5, "#e8c25a"))
        lapel = shade(color, 0.86)
        s.append(path(poly([(cx - sh * 0.3, sy), (cx - sh * 0.48, sy + T * 0.3), (cx - sh * 0.36, sy + T * 0.34), (cx, sy + v_depth)]), lapel, sw))
        s.append(path(poly([(cx + sh * 0.3, sy), (cx + sh * 0.48, sy + T * 0.3), (cx + sh * 0.36, sy + T * 0.34), (cx, sy + v_depth)]), lapel, sw))
        s.append(line([(cx, sy + v_depth), (cx, hem or R["hem_y"])], OUT, sw))
        s.append(circle(cx + sh * 0.08, sy + v_depth + T * 0.1, sh * 0.05 + 1, shade(color, 0.6), sw * 0.6))
        if kind == "suit":
            s.append(line([(cx + sh * 0.5, sy + T * 0.32), (cx + sh * 0.72, sy + T * 0.3)], OUT, sw * 0.8))
            if spec.get("pocket_square"):
                s.append(path(poly([(cx + sh * 0.52, sy + T * 0.31), (cx + sh * 0.7, sy + T * 0.29), (cx + sh * 0.64, sy + T * 0.22)]), "#ffffff", sw * 0.6))
            s.append(line([(cx - sh * 0.75, sy + T * 0.82), (cx - sh * 0.45, sy + T * 0.82)], OUT, sw * 0.8))
            s.append(line([(cx + sh * 0.45, sy + T * 0.82), (cx + sh * 0.75, sy + T * 0.82)], OUT, sw * 0.8))
    elif kind == "hoodie":
        inner = top[2] if len(top) > 2 else None
        if inner:
            s.append(rect(cx - sh * 0.24, sy + 2, sh * 0.48, T - 2, inner, sw))
            s.append(line([(cx - sh * 0.24, sy + 2), (cx - sh * 0.3, R["hem_y"])], OUT, sw))
            s.append(line([(cx + sh * 0.24, sy + 2), (cx + sh * 0.3, R["hem_y"])], OUT, sw))
        else:
            s.append(line([(cx, sy + T * 0.08), (cx, R["hem_y"])], shade(color, 1.6), sw * 0.9))
            s.append(path(f"M{n(cx - sh * 0.5)},{n(sy + T * 0.95)} L{n(cx - sh * 0.38)},{n(sy + T * 0.62)} L{n(cx + sh * 0.38)},{n(sy + T * 0.62)} L{n(cx + sh * 0.5)},{n(sy + T * 0.95)}", "none", sw * 0.8, shade(color, 1.5)))
        for side in (-1, 1):
            s.append(line([(cx + side * sh * 0.16, sy + T * 0.04), (cx + side * sh * 0.18, sy + T * 0.36)], "#f2f2f2", sw * 0.9))
        s.append(rect(cx - R["hh"] - 1, R["hem_y"] - T * 0.07, R["hh"] * 2 + 2, T * 0.07, shade(color, 0.8), sw, 2))
    elif kind == "turtleneck":
        nh = (R["neck_bot"] - R["neck_top"]) * 0.55
        s.append(rect(cx - R["neck_w"] / 2 - 3 * k, R["neck_bot"] - nh, R["neck_w"] + 6 * k, nh + 4, color, sw, 4))
        s.append(line([(cx - R["neck_w"] / 2, R["neck_bot"] - nh * 0.45), (cx + R["neck_w"] / 2, R["neck_bot"] - nh * 0.45)], shade(color, 1.6), sw * 0.6))
    elif kind in ("shirt", "cardigan"):
        tie = top[2] if kind == "shirt" and len(top) > 2 else None
        collar = "#ffffff" if kind == "cardigan" else shade(color, 0.92)
        if kind == "cardigan":
            s.append(path(poly([(cx - sh * 0.24, sy), (cx + sh * 0.24, sy), (cx, sy + T * 0.4)]), "#ffffff", sw))
            s.append(line([(cx - sh * 0.02, sy + T * 0.4), (cx - sh * 0.06, R["hem_y"])], OUT, sw))
            s.append(line([(cx - sh * 0.24, sy), (cx - sh * 0.02, sy + T * 0.4)], shade(color, 0.7), sw * 1.2))
            s.append(line([(cx + sh * 0.24, sy), (cx + sh * 0.02, sy + T * 0.4)], shade(color, 0.7), sw * 1.2))
            for t in (0.5, 0.66, 0.82):
                s.append(circle(cx + sh * 0.04, sy + T * t, sh * 0.05 + 1, "#7a4e34", sw * 0.5))
        else:
            s.append(line([(cx, sy + T * 0.12), (cx, R["hem_y"])], shade(color, 0.75), sw * 0.8))
            if not tie:
                for t in (0.3, 0.5, 0.7):
                    s.append(circle(cx, sy + T * t, sh * 0.03 + 0.8, shade(color, 0.7)))
            if "nopocket" not in top[3:]:
                s.append(rect(cx + sh * 0.2, sy + T * 0.26, sh * 0.28, T * 0.17, "none", sw * 0.7, 2))
        s.append(path(poly([(cx - sh * 0.32, sy - 2), (cx, sy + T * 0.08), (cx - sh * 0.24, sy + T * 0.17)]), collar, sw * 0.8))
        s.append(path(poly([(cx + sh * 0.32, sy - 2), (cx, sy + T * 0.08), (cx + sh * 0.24, sy + T * 0.17)]), collar, sw * 0.8))
        if tie:
            s.append(path(poly([(cx - sh * 0.07, sy + T * 0.06), (cx + sh * 0.07, sy + T * 0.06), (cx + sh * 0.05, sy + T * 0.15), (cx - sh * 0.05, sy + T * 0.15)]), shade(tie, 0.85), sw * 0.8))
            s.append(path(poly([(cx - sh * 0.05, sy + T * 0.15), (cx + sh * 0.05, sy + T * 0.15), (cx + sh * 0.1, sy + T * 0.7), (cx, sy + T * 0.8), (cx - sh * 0.1, sy + T * 0.7)]), tie, sw * 0.8))
        if spec.get("belt"):
            s.append(rect(cx - R["hh"], R["hem_y"] - T * 0.07, R["hh"] * 2, T * 0.07, "#24212b", sw * 0.6))
            s.append(rect(cx - sh * 0.08, R["hem_y"] - T * 0.075, sh * 0.16, T * 0.08, spec["belt"], sw * 0.5, 1))
    return s


# ------------------------------------------------------------------ 소품

def prop_svg(name, R, hands, spec):
    sw, s_, k = R["sw"], R["prop"], R["k"]
    out = []
    cx = R["cx"]
    left, right = hands.get(-1), hands.get(1)
    if name == "keyboard":
        y = (left or right)[1] + 2
        w, h = 120 * s_, 22 * s_
        out.append(rect(cx - w / 2, y - h / 2, w, h, "#2d2b36", sw, 5 * s_))
        for row in range(2):
            for col in range(9):
                out.append(rect(cx - w / 2 + 8 * s_ + col * 12 * s_, y - h / 2 + 4 * s_ + row * 8 * s_, 8 * s_, 5 * s_, "#5a5866"))
    elif name == "laptop":
        y = (left or right)[1]
        w, h = 110 * s_, 72 * s_
        out.append(rect(cx - w / 2, y - h + 8 * s_, w, h, "#23212b", sw, 6 * s_))
        out.append(circle(cx, y - h / 2 + 8 * s_, 9 * s_, "#cfd6e4"))
        out.append(rect(cx - w / 2 - 6 * s_, y + 4 * s_, w + 12 * s_, 9 * s_, "#4a4756", sw, 3 * s_))
    elif name == "coffee":
        x, y = right
        out.append(path(poly([(x - 12 * s_, y - 30 * s_), (x + 12 * s_, y - 30 * s_), (x + 9 * s_, y + 8 * s_), (x - 9 * s_, y + 8 * s_)]), "#f4efe6", sw))
        out.append(rect(x - 11.5 * s_, y - 18 * s_, 23 * s_, 14 * s_, "#a0683f", sw * 0.6))
        out.append(circle(x, y - 11 * s_, 4 * s_, "#2f8a5c"))
        out.append(rect(x - 14 * s_, y - 36 * s_, 28 * s_, 7 * s_, "#3a3440", sw * 0.8, 3 * s_))
        out.append(circle(x - 6 * s_, y + 4 * s_, R["hand_r"], spec["skin"], sw))
    elif name == "papers":
        x, y = right
        for i, c in enumerate(("#dfe6f2", "#eef2f8", "#ffffff")):
            out.append(f'<g transform="rotate({-18 + i * 4} {n(x)} {n(y)})">' + rect(x - 34 * s_, y - 42 * s_ + i * 2, 54 * s_, 40 * s_, c, sw * 0.8, 2) + "</g>")
        for t in range(3):
            out.append(line([(x - 26 * s_, y - 30 * s_ + t * 8 * s_), (x + 8 * s_, y - 38 * s_ + t * 8 * s_)], "#9aa6bb", sw * 0.8))
        out.append(circle(x, y, R["hand_r"], spec["skin"], sw))
    elif name == "briefcase":
        x, y = left
        out.append(path(f"M{n(x - 10 * s_)},{n(y + 6 * s_)} L{n(x - 10 * s_)},{n(y - 2 * s_)} L{n(x + 10 * s_)},{n(y - 2 * s_)} L{n(x + 10 * s_)},{n(y + 6 * s_)}", "none", sw * 1.2))
        out.append(rect(x - 34 * s_, y + 6 * s_, 68 * s_, 48 * s_, "#231f27", sw, 5 * s_))
        out.append(line([(x - 34 * s_, y + 22 * s_), (x + 34 * s_, y + 22 * s_)], "#4b4552", sw))
        out.append(circle(x, y, R["hand_r"], spec["skin"], sw))
    elif name == "pen_note":
        x, y = right
        out.append(line([(x - 6 * s_, y + 4 * s_), (x - 46 * s_, y - 18 * s_)], OUT, 7 * s_ + sw))
        out.append(line([(x - 6 * s_, y + 4 * s_), (x - 46 * s_, y - 18 * s_)], "#2b2b33", 5 * s_))
        out.append(line([(x - 40 * s_, y - 15 * s_), (x - 52 * s_, y - 22 * s_)], "#e2b94a", 4 * s_))
        out.append(circle(x, y, R["hand_r"], spec["skin"], sw))
        lx, ly = left
        out.append(f'<g transform="rotate(14 {n(lx)} {n(ly)})">' + rect(lx - 8 * s_, ly - 40 * s_, 44 * s_, 54 * s_, "#6b3f2a", sw, 4 * s_) +
                   rect(lx - 2 * s_, ly - 34 * s_, 34 * s_, 42 * s_, "#f6efe2", 0, 2) + "</g>")
        out.append(circle(lx, ly, R["hand_r"], spec["skin"], sw))
    elif name == "golf":
        x, y = left
        gy = R["ground"] - 6 * s_
        out.append(line([(x, y), (x - 30 * s_, gy)], OUT, 6 * s_ + sw * 2))
        out.append(line([(x, y), (x - 30 * s_, gy)], "#c9ced8", 6 * s_))
        out.append(path(f"M{n(x - 30 * s_)},{n(gy)} L{n(x - 52 * s_)},{n(gy + 4 * s_)} Q{n(x - 60 * s_)},{n(gy - 6 * s_)} {n(x - 46 * s_)},{n(gy - 8 * s_)} L{n(x - 30 * s_)},{n(gy - 6 * s_)}Z", "#3a3742", sw))
        out.append(circle(x, y, R["hand_r"], spec["skin"], sw))
    elif name == "money_bag":
        x, y = left
        out.append(path(f"M{n(x - 8 * s_)},{n(y + 4 * s_)} Q{n(x - 40 * s_)},{n(y + 30 * s_)} {n(x - 30 * s_)},{n(y + 56 * s_)} L{n(x + 30 * s_)},{n(y + 56 * s_)} Q{n(x + 40 * s_)},{n(y + 30 * s_)} {n(x + 8 * s_)},{n(y + 4 * s_)}Z", "#e9b93c", sw))
        out.append(f'<text x="{n(x)}" y="{n(y + 46 * s_)}" font-size="{n(30 * s_)}" font-weight="bold" text-anchor="middle" fill="#8a5a12">$</text>')
        out.append(circle(x, y, R["hand_r"], spec["skin"], sw))
    elif name == "card":
        x, y = right
        out.append(f'<g transform="rotate(-12 {n(x)} {n(y)})">' + rect(x - 30 * s_, y - 30 * s_, 48 * s_, 30 * s_, "#ffffff", sw * 0.8, 3) +
                   rect(x - 24 * s_, y - 24 * s_, 12 * s_, 12 * s_, "#b4365a") +
                   line([(x - 8 * s_, y - 20 * s_), (x + 10 * s_, y - 20 * s_)], "#8a8a99", sw * 0.8) +
                   line([(x - 8 * s_, y - 12 * s_), (x + 4 * s_, y - 12 * s_)], "#8a8a99", sw * 0.8) + "</g>")
        out.append(circle(x, y, R["hand_r"], spec["skin"], sw))
    return out


def body_strap(R, spec, kind):
    sw, cx, sy, sh, k = R["sw"], R["cx"], R["sy"], R["sh"], R["k"]
    T = R["hem_y"] - sy
    if kind == "shoulder_bag":
        return [line([(cx - sh * 0.7, sy + 2), (cx + sh * 0.9, sy + T * 0.9)], OUT, 8 * k + sw * 2),
                line([(cx - sh * 0.7, sy + 2), (cx + sh * 0.9, sy + T * 0.9)], "#26222c", 8 * k)]
    if kind == "backpack":
        return [line([(cx + sh * 0.55, sy), (cx + sh * 0.62, sy + T * 0.7)], OUT, 10 * k + sw * 2),
                line([(cx + sh * 0.55, sy), (cx + sh * 0.62, sy + T * 0.7)], "#2a2730", 10 * k)]
    if kind == "lanyard":
        return [path(f"M{n(cx - sh * 0.2)},{n(sy)} L{n(cx - sh * 0.3)},{n(sy + T * 0.5)} L{n(cx - sh * 0.08)},{n(sy + T * 0.5)}", "none", sw * 0.9, "#2f3a5a"),
                rect(cx - sh * 0.44, sy + T * 0.48, sh * 0.34, T * 0.2, "#5fb4e8", sw * 0.7, 2),
                rect(cx - sh * 0.4, sy + T * 0.56, sh * 0.26, T * 0.04, "#ffffff")]
    return []


def bag_side(R, spec, kind):
    """몸 옆에 매달린 가방 (팔보다 먼저 그린다)"""
    sw, cx, sh, k = R["sw"], R["cx"], R["sh"], R["k"]
    if kind == "shoulder_bag":
        x, y = cx + sh * 0.9, R["hem_y"] - 6 * k
        return [rect(x - 22 * k, y - 18 * k, 48 * k, 40 * k, "#26222c", sw, 6 * k),
                rect(x - 8 * k, y - 6 * k, 22 * k, 14 * k, "#d8d8de", sw * 0.6, 2)]
    if kind == "backpack":
        x = cx + R["sh"] + 2 * k
        return [rect(x - 12 * k, R["sy"] + 30 * k, 30 * k, 74 * k, "#2a2730", sw, 8 * k)]
    if kind == "messenger":
        x, y = cx + sh * 1.0, R["hem_y"] - 20 * k
        return [line([(cx - sh * 0.6, R["sy"]), (x, y)], OUT, 8 * k + sw * 2), line([(cx - sh * 0.6, R["sy"]), (x, y)], "#2a2730", 8 * k),
                rect(x - 16 * k, y - 10 * k, 46 * k, 52 * k, "#2f2c36", sw, 8 * k)]
    return []


def background(R, spec):
    sw, k = R["sw"], R["k"]
    s = []
    if spec.get("monitors"):
        spots = [(6, 120), (6, 178), (186, 120), (186, 178)]
        w, h = 64, 54
        for x, y in spots:
            s.append(rect(x, y, w, h, "#37474f", sw, 6 * k + 2))
            s.append(rect(x + w * 0.1, y + h * 0.12, w * 0.8, h * 0.7, "#0f2a30", 0, 3))
            s.append(circle(x + w * 0.36, y + h * 0.44, h * 0.09, "#9ef5ff"))
            s.append(circle(x + w * 0.64, y + h * 0.44, h * 0.09, "#9ef5ff"))
            s.append(circle(x + w * 0.5, y + h * 0.44, h * 0.3, "#5fe8ff", extra=' opacity="0.18"'))
    return s


def floating(R, spec):
    sw, k = R["sw"], R["k"]
    s = []
    if spec.get("drone"):
        x, y, z = 34, 28, 0.7
        for d in (-1, 1):
            s.append(line([(x, y), (x + d * 34 * z, y - 12 * z)], OUT, 5 * z + 2))
            s.append(ellipse(x + d * 34 * z, y - 16 * z, 20 * z, 5 * z, "#2a2730", sw * 0.7))
        s.append(ellipse(x, y, 22 * z, 15 * z, "#2a2730", sw))
        s.append(circle(x, y + 2 * z, 12 * z, "#3cff8a", extra=' opacity="0.35"'))
        s.append(circle(x, y + 2 * z, 6 * z, "#3cff8a"))
    if spec.get("hologram"):
        x, y, z = 210, 150, 0.65
        cube = f"M{n(x)},{n(y - 26 * z)} L{n(x + 24 * z)},{n(y - 13 * z)} L{n(x + 24 * z)},{n(y + 13 * z)} L{n(x)},{n(y + 26 * z)} L{n(x - 24 * z)},{n(y + 13 * z)} L{n(x - 24 * z)},{n(y - 13 * z)}Z"
        s.append(circle(x, y, 40 * z, "#38e8ff", extra=' opacity="0.15"'))
        s.append(path(cube, "#38e8ff", 2.5 * z + 1, "#bff8ff", ' fill-opacity="0.35"'))
        s.append(path(f"M{n(x - 24 * z)},{n(y - 13 * z)} L{n(x)},{n(y)} L{n(x + 24 * z)},{n(y - 13 * z)} M{n(x)},{n(y)} L{n(x)},{n(y + 26 * z)}", "none", 2.5 * z + 1, "#bff8ff"))
    if spec.get("sparkle"):
        pts = [(30, 110), (226, 70)]
        z = 0.7
        for x, y in pts:
            s.append(path(f"M{n(x)},{n(y - 14 * z)} Q{n(x + 2 * z)},{n(y - 2 * z)} {n(x + 14 * z)},{n(y)} Q{n(x + 2 * z)},{n(y + 2 * z)} {n(x)},{n(y + 14 * z)} Q{n(x - 2 * z)},{n(y + 2 * z)} {n(x - 14 * z)},{n(y)} Q{n(x - 2 * z)},{n(y - 2 * z)} {n(x)},{n(y - 14 * z)}Z", "#ffe27a"))
    return s


def character(spec, R):
    sw = R["sw"]
    hx, hy, hs = R["head"]
    head_sw = sw / hs
    s = [ellipse(R["cx"], R["ground"], R["sh"] * 1.25, R["shoe"][1] * 1.1, "#000000", extra=' opacity="0.18"')]
    s += background(R, spec)
    s.append(group(head_back(spec, head_sw, R["long"]), hx, hy, hs))
    bag = spec.get("bag")
    if bag == "backpack":
        s += bag_side(R, spec, bag)
    s += legs(R, spec)
    s += outfit(R, spec)
    s += body_strap(R, spec, bag if bag in ("shoulder_bag", "backpack") else spec.get("strap"))
    if bag in ("shoulder_bag", "messenger"):
        s += bag_side(R, spec, bag)
    top = spec["top"]
    sleeve = top[1]
    rolled = top[0] == "shirt" and spec.get("rolled", True)
    cuff = top[2] if top[0] in ("suit", "blazer_f") else None
    hands = {}
    poses = spec.get("arms", ("down", "down"))
    for side, pose in zip((-1, 1), poses):
        part, hand = arm(R, spec, side, pose, sleeve, rolled, cuff)
        s += part
        hands[side] = hand
    if spec.get("watch") and hands.get(1):
        x, y = hands[1]
        s.append(rect(x - R["arm_w"] * 0.5, y - R["hand_r"] * 2.2, R["arm_w"], R["hand_r"] * 0.9, "#22202a", sw * 0.6, 2))
    for p in spec.get("props", []):
        s += prop_svg(p, R, hands, spec)
    s.append(group(head_front(spec, head_sw, R["long"]), hx, hy, hs))
    s += floating(R, spec)
    W, H = R["W"], R["H"]
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="128" height="128">' + "".join(s) + "</svg>\n"


# ------------------------------------------------------------------ 직원 목록 (예전 그림의 머리, 옷, 소품을 따른다)

LIGHT = "#f7d9c4"
WARM = "#f1c7a6"
TAN = "#e2b08c"

CHARACTERS = {
    # 개발팀
    "dv1": dict(skin=WARM, hair="#1f1d24", hair_style="side_part", glasses="square", iris="#3a2a22", mouth="smile",
                top=("suit", "#6f6f78", "#f4f6fa", "#2f7fb0", "stripe"), bottom=("pants", "#4a4f63"), pocket_square=True,
                arms=("front", "front"), props=["keyboard"]),
    "dv2": dict(skin=LIGHT, hair="#d9bf94", hair_style="ponytail", glasses="round", iris="#6a4a2a", mouth="neutral", blush=True,
                top=("turtleneck", "#1e1c24"), bottom=("pants", "#a9abb3"), shoes="#33303a",
                arms=("front", "front"), props=["laptop"]),
    "dv3": dict(skin=WARM, hair="#16151b", hair_style="messy", eyes="tired", iris="#2fb3c4", mouth="frown",
                top=("hoodie", "#77787f", "#f4f4f4"), bottom=("pants", "#8a5a3c"), shoes="#1f1d24", shoe_kind="sneaker",
                watch=True),
    "dv4": dict(skin=LIGHT, hair="#5a3626", hair_style="long_wavy", eyes="happy", mouth="smile", blush=True,
                top=("hoodie", "#1f1d24"), bottom=("jeans", "#4a76a8"), shoes="#d8423f", shoe_kind="sneaker",
                arms=("pocket", "raise"), bag="backpack", drone=True),
    "dv5_1": dict(skin=WARM, hair="#141318", hair_style="spiky", eyes="glow", mouth="neutral",
                  top=("suit", "#5d616c", "#f2f4f8"), bottom=("pants", "#5a5f6c"), belt="#bfc5cf"),
    "dv5_2": dict(skin=LIGHT, hair="#18171d", hair_style="bob_straight", glasses="pale", iris="#3a2a22", mouth="neutral",
                  top=("suit", "#7d8394", "#f4f6fa", "#e8c03a"), bottom=("pants", "#39456a"), monitors=True),
    # 인사팀
    "hr1": dict(skin=LIGHT, hair="#b8936e", hair_style="bob_messy", eyes="big", iris="#8a4a22", mouth="wobbly", blush=True, sweat=True,
                brow="worried", top=("suit", "#6a5a52", "#f4f6fa", "#2c4f7c"), bottom=("pants", "#6f6a72"),
                arms=("down", "raise"), props=["coffee"]),
    "hr2": dict(skin=WARM, hair="#1b1a20", hair_style="side_part", glasses="round", iris="#7a4a20", mouth="smirk",
                top=("shirt", "#f4f6fa", "#6b6e78"), bottom=("pants", "#1f1d24"), strap="lanyard",
                arms=("pocket", "pocket")),
    "hr3": dict(skin=LIGHT, hair="#4a3329", hair_style="long_straight", glasses="round", iris="#e0602a", mouth="smile",
                top=("blazer_f", "#2a3a5c", "#f4f6fa"), bottom=("skirt", "#26242c"), tights="#8f8f9c", shoe_kind="heel",
                arms=("behind", "behind")),
    "hr4": dict(skin=WARM, hair="#4a3427", hair_style="messy", glasses="square", iris="#3a2a22", mouth="smile",
                top=("shirt", "#eef1f6", None, "pocket"), bottom=("pants", "#545a6a"), belt="#d9b23a",
                arms=("pocket", "pocket")),
    "hr5_1": dict(skin=WARM, hair="#6c6c72", hair_style="slicked", eyes="sharp", iris="#4a2a3a", brow="angry", mouth="frown",
                  top=("suit", "#1d1c22", "#f4f6fa", "#2f72b8"), bottom=("pants", "#1d1c22"),
                  arms=("down", "raise"), props=["papers"]),
    "hr5_2": dict(skin=LIGHT, hair="#6a4430", hair_style="bun", glasses="round", iris="#6a3a22", mouth="smile", blush=True,
                  top=("cardigan", "#e2cc9e"), bottom=("plaid", "#5a3a3a"), tights="#a7a9b4", shoes="#4a3022",
                  arms=("behind", "behind")),
    # 영업팀
    "sl1": dict(skin=LIGHT, hair="#f07a2a", hair_style="twin_tails", ribbon=True, eyes="big", iris="#7a4a20", mouth="open",
                blush=True, top=("suit", "#55555f", "#f4f6fa"), bottom=("pants", "#3e4252"), shoes="#3a3440",
                bag="shoulder_bag", shoe_kind="sneaker"),
    "sl2": dict(skin=LIGHT, hair="#6a4634", hair_style="long_wavy", eyes="sharp", iris="#3a2420", mouth="lips", necklace=True,
                top=("blazer_f", "#5a5d66", "#f4f6fa"), bottom=("skirt", "#5a5d66"), shoe_kind="heel",
                arms=("front", "raise"), props=["pen_note"]),
    "sl3": dict(skin=WARM, hair="#16151b", hair_style="side_part", glasses="square", iris="#2f9a4a", mouth="smile", blush=True,
                top=("suit", "#3a3a46", "#f4f6fa", "#2a8a9a"), bottom=("pants", "#2f3448"), pocket_square=True,
                arms=("down", "hip"), props=["briefcase"]),
    "sl4": dict(skin=WARM, hair="#5a3a28", hair_style="long_center", glasses="round", iris="#3a2a22", mouth="smile", beard=True,
                top=("shirt", "#f4f6fa", "#1e1c24"), bottom=("pants", "#1e1c24"), bag="messenger", watch=True,
                arms=("down", "down"), props=["golf"]),
    "sl5_1": dict(skin=WARM, hair="#18171d", hair_style="crop", iris="#2f8ad8", brow="angry", mouth="grin", blush=True,
                  top=("suit", "#3d4258", "#f4f6fa", "#b33a3a"), bottom=("pants", "#3d4258"),
                  arms=("behind", "behind")),
    "sl5_2": dict(skin=LIGHT, hair="#3a2a26", hair_style="long_straight", eyes="sharp", iris="#2a1e22", mouth="lips",
                  top=("blazer_f", "#1d1c22", "#e8e2f2"), bottom=("skirt", "#1d1c22"), tights="#5a4a48", shoe_kind="heel",
                  arms=("down", "hip")),
    # 특수 (보스 유물로만 뽑는다)
    "dv7": dict(skin=LIGHT, hair="#e6ecf5", hair_style="messy", glasses="visor", mouth="smile",
                top=("suit", "#f2f4f8", "#2a3550", "#38c8e8"), bottom=("pants", "#2a3550"), shoes="#e6ecf5", shoe_kind="sneaker",
                arms=("down", "raise"), hologram=True, sparkle=True),
    "hr7": dict(skin=LIGHT, hair="#5a1f3a", hair_style="bob_straight", glasses="sun", mouth="lips",
                top=("blazer_f", "#8a2346", "#f4f6fa"), bottom=("skirt", "#5a1830"), tights="#3a2a30", shoe_kind="heel",
                arms=("hip", "raise"), props=["card"], sparkle=True),
    "sl7": dict(skin=TAN, hair="#f0c64a", hair_style="slicked", glasses="sun", mouth="grin",
                top=("suit", "#f4f1e8", "#1e1c24", "#e8b52a"), bottom=("pants", "#f4f1e8"), shoes="#8a5a2a", pocket_square=True,
                arms=("down", "hip"), props=["money_bag"], sparkle=True, watch=True),
    # 신화 (특수 직원 + 다른 팀 전설 2명으로 각성)
    "dv6_3": dict(skin=WARM, hair="#cfd4de", hair_style="slicked", eyes="glow", mouth="smirk", beard=True,
                  top=("suit", "#1f2a44", "#e8f4ff", "#38e8ff"), bottom=("pants", "#1f2a44"), shoes="#141a2a",
                  arms=("down", "raise"), hologram=True, monitors=True, sparkle=True),
    "hr6_3": dict(skin=LIGHT, hair="#2a1420", hair_style="long_straight", glasses="sun", mouth="lips", necklace=True,
                  top=("blazer_f", "#5a1430", "#f4e6ee"), bottom=("skirt", "#2a0e1c"), tights="#2a1e24", shoe_kind="heel",
                  arms=("hip", "raise"), props=["card"], sparkle=True),
    "sl6_3": dict(skin=TAN, hair="#ececf2", hair_style="side_part", glasses="square", iris="#3a2a22", mouth="grin", beard=True,
                  top=("suit", "#1a1a22", "#f4f4f4", "#e8b52a", "stripe"), bottom=("pants", "#1a1a22"), shoes="#6a3a1a",
                  pocket_square=True, arms=("down", "hip"), props=["money_bag"], sparkle=True, watch=True),
    # 신화 (전설 + 다른 팀 전설 2명으로 각성)
    "dv6_1": dict(skin=LIGHT, hair="#141318", hair_style="ponytail", glasses="round", iris="#3a2a22", mouth="smirk",
                  top=("suit", "#1f2a3a", "#16151b"), bottom=("pants", "#16151b"), shoes="#f2f2f4", shoe_kind="sneaker",
                  arms=("pocket", "raise"), hologram=True, sparkle=True),
    "dv6_2": dict(skin=LIGHT, hair="#dfe3ea", hair_style="bob_messy", eyes="sharp", iris="#2fb3c4", mouth="smirk",
                  top=("hoodie", "#f2f3f6", "#1e1c24"), bottom=("pants", "#1e1c24"), shoes="#f2f2f4", shoe_kind="sneaker",
                  arms=("hip", "raise"), hologram=True, sparkle=True),
    "hr6_1": dict(skin=WARM, hair="#2a2830", hair_style="side_part", mouth="smile",
                  top=("suit", "#6a1e2a", "#f4f6fa", "#d9b23a"), bottom=("pants", "#6a1e2a"), shoes="#6a3a1a", pocket_square=True,
                  arms=("pocket", "raise"), props=["card"], sparkle=True),
    "hr6_2": dict(skin=LIGHT, hair="#d9b46a", hair_style="long_wavy", eyes="happy", mouth="smile", blush=True,
                  top=("blazer_f", "#e8dccb", "#f2b8c6"), bottom=("long", "#d98f9c"), shoes="#d9c2a6", shoe_kind="heel",
                  arms=("front", "front"), sparkle=True),
    "sl6_1": dict(skin=WARM, hair="#c9ccd4", hair_style="slicked", eyes="sharp", iris="#3a2a22", mouth="smirk", beard=True,
                  top=("suit", "#1a1a20", "#f4f6fa", "#d9a92a"), bottom=("pants", "#1a1a20"), pocket_square=True,
                  arms=("front", "raise"), props=["pen_note"], sparkle=True, watch=True),
    "sl6_2": dict(skin=LIGHT, hair="#4a2e22", hair_style="ponytail", eyes="happy", mouth="smile",
                  top=("blazer_f", "#f4f2ee", "#f4f6fa", "#2a3a6a"), bottom=("pants", "#f4f2ee"), shoes="#f4f4f4", shoe_kind="heel",
                  arms=("down", "raise"), props=["card"], sparkle=True),
}


def main():
    for cid, spec in CHARACTERS.items():
        team = cid[:2]
        folder = os.path.join(ROOT, "assets", "tower", team)
        os.makedirs(folder, exist_ok=True)
        target = os.path.join(folder, f"{cid}_sprite.svg")
        with open(target, "w", encoding="utf-8", newline="\n") as fp:
            fp.write(character(spec, SPRITE))
    print(f"{len(CHARACTERS)} characters written")


if __name__ == "__main__":
    main()
