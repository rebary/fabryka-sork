"""Generuje efekty dźwiękowe gry (własne, syntetyczne - brak problemów z licencją).
Uruchomienie z folderu projektu:  python3 tools/make_sfx.py
Wymaga: Python 3 + numpy. Wynik: assets/sfx/*.wav (mono, 22050 Hz, 16 bit)."""
import os, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
rng = np.random.default_rng(1)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, attack=0.005, release=None):
    e = np.ones(n)
    a = max(1, int(SR * attack))
    e[:a] = np.linspace(0, 1, a)
    r = n - a if release is None else max(1, int(SR * release))
    e[-r:] *= np.linspace(1, 0, r) ** 2
    return e


def tone(freq, d, shape="sine", vol=0.5):
    x = t(d)
    phase = 2 * np.pi * np.cumsum(np.broadcast_to(freq, x.shape)) / SR
    if shape == "sine":
        y = np.sin(phase)
    elif shape == "square":
        y = np.sign(np.sin(phase)) * 0.6
    else:  # saw
        y = 2 * ((phase / (2 * np.pi)) % 1) - 1
    return y * vol * env(len(x))


def save(name, y):
    y = np.clip(y, -1, 1)
    data = (y * 32000).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


os.makedirs(OUT, exist_ok=True)
# Serwo chwytaka: krótki, narastający "wizg".
d = 0.16
save("pick", tone(np.linspace(260, 520, int(SR * d)), d, "saw", 0.18) + tone(np.linspace(520, 1040, int(SR * d)), d, "sine", 0.08))
# Odstawienie paczki: głuche stuknięcie kartonu.
d = 0.14
x = t(d)
thud = np.sin(2 * np.pi * np.cumsum(np.linspace(150, 55, len(x))) / SR) * np.exp(-x * 30)
noise = rng.normal(0, 1, len(x)) * np.exp(-x * 60) * 0.25
save("drop", (thud * 0.7 + noise) * env(len(x), 0.001))
# Skompletowana paleta: dwutonowy dzwonek.
save("complete", np.concatenate([tone(880, 0.12, vol=0.35), tone(1318.5, 0.28, vol=0.35)]))
# Wykonane zlecenie: arpeggio.
save("win", np.concatenate([tone(f, d2, vol=0.35) for f, d2 in [(523.25, .1), (659.25, .1), (783.99, .1), (1046.5, .45)]]))
# Kliknięcie przycisku.
save("click", tone(1800, 0.03, "square", 0.15))
# Błąd / ruch niedozwolony: niskie brzęczenie.
save("error", tone(110, 0.18, "square", 0.25) + tone(116, 0.18, "square", 0.2))
# Podpowiedź / nagroda: miękki, wznoszący się dźwięk.
save("hint", np.concatenate([tone(660, 0.08, vol=0.3), tone(990, 0.2, vol=0.3)]))
save("reward", np.concatenate([tone(f, 0.07, vol=0.3) for f in (784, 988, 1175)] + [tone(1568, 0.3, vol=0.3)]))
print("Zapisano dźwięki w", os.path.abspath(OUT))
