"""Składa materiały do Google Play z surowych zrzutów (tools/store_capture.gd) i ikony (tools/store_icon.gd).
Wynik w build/store/:
  pl/screen_1..6.png, en/screen_1..6.png  - zrzuty 1080x1920 z podpisami
  feature_pl.png, feature_en.png           - grafika promocyjna 1024x500
Uruchomienie (z folderu projektu): python3 tools/store_compose.py
Wymaga: Python 3 + Pillow."""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..")
STORE = os.path.join(ROOT, "build", "store")
FONT = os.path.join(ROOT, "assets", "fonts", "Exo2-Variable.ttf")

CAPTIONS = {
    "pl": [
        ("Steruj robotem", "Sortuj paczki – jeden produkt na paletę"),
        ("Coraz większe wyzwania", "Folia, chwytaki, limit ruchów – 150 zleceń"),
        ("Zaprogramuj robota", "Ułóż program i naciśnij START"),
        ("Pojedynki", "Ścigaj się z rywalami, wyzywaj znajomych"),
        ("Rozbuduj swoją halę", "Ozdoby za gwiazdki i pakiety wyglądu"),
        ("Gwiazdki i awanse", "Od Praktykanta do Głównego automatyka"),
    ],
    "en": [
        ("Control the robot", "Sort the boxes – one product per pallet"),
        ("Growing challenges", "Stretch wrap, grippers, move limits – 150 orders"),
        ("Program the robot", "Write a program and press START"),
        ("Duels", "Race rivals and challenge your friends"),
        ("Build your factory", "Decorations for stars and style packs"),
        ("Stars and ranks", "From Trainee to Chief Automation Engineer"),
    ],
}
FEATURE = {
    "pl": ("Fabryka Sort", "Steruj robotem. Programuj. Rywalizuj."),
    "en": ("Factory Sort", "Control the robot. Program it. Compete."),
}
BG_TOP, BG_BOTTOM = (32, 46, 61), (12, 17, 23)
ACCENT = (255, 182, 39)


def font(size, weight):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def gradient(w, h):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3)))
    return img


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], radius, fill=255)
    out = Image.new("RGBA", img.size)
    out.paste(img, (0, 0), mask)
    return out


def centered(d, y, text, f, fill, width):
    w = d.textlength(text, font=f)
    d.text(((width - w) / 2, y), text, font=f, fill=fill)


def screen(raw_path, title, sub, out_path):
    W, H = 1080, 1920
    canvas = gradient(W, H).convert("RGBA")
    shot = Image.open(raw_path).convert("RGB")
    sw = int(W * 0.84)
    sh = int(shot.size[1] * sw / shot.size[0])
    shot = rounded(shot.resize((sw, sh), Image.LANCZOS), 36)
    x, y = (W - sw) // 2, H - sh - 40
    shadow = Image.new("RGBA", (sw + 80, sh + 80), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([40, 50, sw + 40, sh + 40], 40, fill=(0, 0, 0, 150))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)), (x - 40, y - 40))
    canvas.alpha_composite(shot, (x, y))
    d = ImageDraw.Draw(canvas)
    centered(d, 60, title, font(88, 800), ACCENT, W)
    centered(d, 180, sub, font(44, 600), (230, 236, 242), W)
    canvas.convert("RGB").save(out_path)


def feature(lang, out_path):
    W, H = 1024, 500
    canvas = gradient(W, H).convert("RGBA")
    # Prawa strona: fragment rozgrywki.
    raw = Image.open(os.path.join(STORE, "raw_1.png")).convert("RGB")
    crop = raw.crop((0, 200, 1080, 1220)).resize((400, 378), Image.LANCZOS)
    canvas.alpha_composite(rounded(crop, 28), (W - 400 - 36, (H - 378) // 2))
    icon = Image.open(os.path.join(STORE, "icon_512.png")).convert("RGB").resize((150, 150), Image.LANCZOS)
    canvas.alpha_composite(rounded(icon, 32), (44, 60))
    d = ImageDraw.Draw(canvas)
    title, sub = FEATURE[lang]
    d.text((44, 236), title, font=font(70, 800), fill=ACCENT)
    d.text((48, 334), sub, font=font(27, 600), fill=(230, 236, 242))
    canvas.convert("RGB").save(out_path)


if __name__ == "__main__":
    for lang, caps in CAPTIONS.items():
        os.makedirs(os.path.join(STORE, lang), exist_ok=True)
        for i, (t, s) in enumerate(caps, 1):
            screen(os.path.join(STORE, "raw_%d.png" % i), t, s, os.path.join(STORE, lang, "screen_%d.png" % i))
        feature(lang, os.path.join(STORE, "feature_%s.png" % lang))
    print("Zapisano materiały w", os.path.abspath(STORE))
