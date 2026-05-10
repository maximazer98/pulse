from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os, math, random

SIZE = 1024
os.makedirs("assets/launcher_icon", exist_ok=True)

NEON_BLUE  = (0, 200, 255)
NEON_PINK  = (255, 45, 135)
WHITE      = (255, 255, 255)
BG         = (10, 10, 26)

def add_layer(base: Image.Image, layer: Image.Image) -> Image.Image:
    return Image.alpha_composite(base, layer)

def glow_rect(draw, x1, y1, x2, y2, color, spread=28):
    for g in range(spread, 0, -3):
        a = int((1 - g / (spread + 2)) * 80)
        draw.rectangle([x1-g, y1-g, x2+g, y2+g], fill=(*color, a))

def glow_circle(draw, cx, cy, r, color, spread=50, max_alpha=100):
    for g in range(spread, 0, -4):
        a = int((1 - g / (spread + 2)) * max_alpha)
        draw.ellipse([cx-r-g, cy-r-g, cx+r+g, cy+r+g], fill=(*color, a))

def make_icon(transparent_bg: bool) -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    # ── Background ──────────────────────────────────────────────
    if not transparent_bg:
        bg = Image.new("RGBA", (SIZE, SIZE), (*BG, 255))

        # Stars
        rng = random.Random(42)
        sd = ImageDraw.Draw(bg)
        for _ in range(180):
            x = rng.randint(0, SIZE)
            y = rng.randint(0, SIZE)
            r = rng.choice([1, 1, 1, 2])
            a = rng.randint(60, 200)
            sd.ellipse([x-r, y-r, x+r, y+r], fill=(255, 255, 255, a))

        # Radial background glow (center deep purple)
        for radius in range(480, 0, -20):
            t = 1 - radius / 480
            a = int(t * 38)
            sd.ellipse([SIZE//2-radius, SIZE//2-radius,
                        SIZE//2+radius, SIZE//2+radius],
                       fill=(28, 10, 70, a))

        img = add_layer(img, bg)

    cx = SIZE // 2

    # ── Three bars at different Y positions ─────────────────────
    bars = [
        # (y_center, gap_half, color, alpha_mult)
        (SIZE//2 - 220, 115,  NEON_PINK,  0.45),  # top bar, pink, faded
        (SIZE//2 + 10,  108,  NEON_BLUE,  1.0),   # middle bar, blue, hero
        (SIZE//2 + 230, 130,  NEON_BLUE,  0.35),  # bottom bar, faded
    ]

    for (bar_y, gap_half, color, am) in bars:
        bar_h  = 68
        bar_l  = cx - gap_half
        bar_r  = cx + gap_half

        # Glow
        glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        gd   = ImageDraw.Draw(glow)
        glow_rect(gd, 0, bar_y-bar_h//2, bar_l, bar_y+bar_h//2, color, spread=30)
        glow_rect(gd, bar_r, bar_y-bar_h//2, SIZE, bar_y+bar_h//2, color, spread=30)
        glow = glow.filter(ImageFilter.GaussianBlur(8))
        # Apply alpha multiplier
        r2, g2, b2, a2 = glow.split()
        a2 = a2.point(lambda x: int(x * am))
        glow = Image.merge("RGBA", (r2, g2, b2, a2))
        img = add_layer(img, glow)

        # Solid bars
        solid = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        sd2   = ImageDraw.Draw(solid)
        bar_alpha = int(255 * am)
        sd2.rectangle([0, bar_y-bar_h//2, bar_l, bar_y+bar_h//2],
                      fill=(*color, bar_alpha))
        sd2.rectangle([bar_r, bar_y-bar_h//2, SIZE, bar_y+bar_h//2],
                      fill=(*color, bar_alpha))
        # Bright top edge
        edge_a = int(255 * am)
        sd2.rectangle([0, bar_y-bar_h//2, bar_l, bar_y-bar_h//2+5],
                      fill=(min(color[0]+80,255), min(color[1]+40,255), 255, edge_a))
        sd2.rectangle([bar_r, bar_y-bar_h//2, SIZE, bar_y-bar_h//2+5],
                      fill=(min(color[0]+80,255), min(color[1]+40,255), 255, edge_a))
        img = add_layer(img, solid)

    # ── Ball (centered in middle bar gap) ───────────────────────
    hero_y   = SIZE//2 + 10
    ball_r   = 62

    # Ball glow (blue only — white glow was overblowing bars)
    for glow_color, spread, alpha in [
        (NEON_BLUE, 55, 80),
        (WHITE,     22, 35),
    ]:
        gl = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        gd = ImageDraw.Draw(gl)
        glow_circle(gd, cx, hero_y, ball_r, glow_color, spread=spread, max_alpha=alpha)
        gl = gl.filter(ImageFilter.GaussianBlur(7))
        img = add_layer(img, gl)

    ball_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    bd = ImageDraw.Draw(ball_layer)
    bd.ellipse([cx-ball_r, hero_y-ball_r, cx+ball_r, hero_y+ball_r],
               fill=(255, 255, 255, 255))
    # Highlight
    bd.ellipse([cx-30, hero_y-30-14, cx+6, hero_y+6-14],
               fill=(255, 255, 255, 170))
    img = add_layer(img, ball_layer)

    # Trail (below ball, neon blue fading)
    trail = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    td = ImageDraw.Draw(trail)
    for i in range(1, 6):
        tr = max(5, int(ball_r * (1 - i * 0.16)))
        a  = max(18, 145 - i * 28)
        ty = hero_y + ball_r + 10 + i * (ball_r // 2 + 6)
        td.ellipse([cx-tr, ty-tr, cx+tr, ty+tr], fill=(*NEON_BLUE, a))
    img = add_layer(img, trail)

    # ── PULSE text ───────────────────────────────────────────────
    if not transparent_bg:
        font_path = "C:/Windows/Fonts/arialbd.ttf"
        try:
            font = ImageFont.truetype(font_path, size=130)
            tl = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
            td2 = ImageDraw.Draw(tl)
            text = "PULSE"
            bbox = td2.textbbox((0, 0), text, font=font)
            tw = bbox[2] - bbox[0]
            tx = (SIZE - tw) // 2 - bbox[0]
            ty_text = SIZE - 190

            # Text glow
            for spread in [16, 10, 5]:
                a = 60 if spread == 16 else (90 if spread == 10 else 130)
                td2.text((tx - spread//3, ty_text - spread//3),
                         text, font=font, fill=(*NEON_BLUE, a))
            # Text solid
            td2.text((tx, ty_text), text, font=font, fill=(255, 255, 255, 255))
            tl_blur = tl.filter(ImageFilter.GaussianBlur(3))
            img = add_layer(img, tl_blur)
            tl2 = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
            td3 = ImageDraw.Draw(tl2)
            td3.text((tx, ty_text), text, font=font, fill=(255, 255, 255, 255))
            img = add_layer(img, tl2)
        except Exception:
            pass  # skip text if font missing

    return img

full = make_icon(transparent_bg=False)
full.save("assets/launcher_icon/icon.png")
print("Saved: assets/launcher_icon/icon.png")

fg = make_icon(transparent_bg=True)
fg.save("assets/launcher_icon/icon_foreground.png")
print("Saved: assets/launcher_icon/icon_foreground.png")
