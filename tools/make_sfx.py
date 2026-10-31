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


def soft(freq, d, vol=0.3, attack=0.015, decay=8.0):
    """Miękki ton: sinus + delikatna druga harmoniczna, łagodne narastanie i wybrzmienie."""
    x = t(d)
    f = np.broadcast_to(freq, x.shape)
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = np.sin(ph) + 0.15 * np.sin(2 * ph)
    e = np.exp(-x * decay)
    a = max(1, int(SR * attack))
    e[:a] *= np.linspace(0, 1, a)
    e[-200:] *= np.linspace(1, 0, 200)
    return y * e * vol


def mix(*parts):
    """Miesza dźwięki: parts = (dźwięk, przesunięcie w sekundach)."""
    n = max(int(SR * off) + len(y) for y, off in parts)
    out = np.zeros(n)
    for y, off in parts:
        i0 = int(SR * off)
        out[i0:i0 + len(y)] += y
    return out


def lowpass(y, k=12):
    return np.convolve(y, np.ones(k) / k, mode="same")


# Chwytak: cichy, miękki "szum" serwa (przefiltrowany szum + niski ton).
d = 0.22
x = t(d)
servo = lowpass(rng.normal(0, 1, len(x)), 40) * 0.5
servo *= np.sin(np.pi * x / d) ** 2
save("pick", servo * 0.35 + soft(np.linspace(180, 260, len(x)), d, 0.10, 0.04, 4))
# Odstawienie: miękkie, niskie "puk" kartonu.
d = 0.18
save("drop", lowpass(soft(np.linspace(130, 70, int(SR * d)), d, 0.45, 0.003, 22), 6))
# Gotowa paleta: ciepły dzwonek (dwa nakładające się tony).
d = 0.6
save("complete", mix((soft(659.25, d, 0.22, 0.01, 5), 0), (soft(987.77, d - 0.09, 0.18, 0.01, 5), 0.09)))
# Wykonane zlecenie: spokojne arpeggio z wybrzmieniem.
notes = [(523.25, 0.0), (659.25, 0.12), (783.99, 0.24), (1046.5, 0.36)]
save("win", mix(*[(soft(f, 1.2 - st, 0.18, 0.01, 3.5), st) for f, st in notes]))
# Kliknięcie: ciche, krótkie "tik".
save("click", soft(1200, 0.05, 0.12, 0.002, 60))
# Ruch niedozwolony: miękkie, niskie "bum" zamiast brzęczenia.
save("error", soft(np.linspace(220, 160, int(SR * 0.2)), 0.2, 0.3, 0.005, 14))
# Podpowiedź i nagroda: delikatne dzwoneczki.
save("hint", mix((soft(880, 0.35, 0.18, 0.01, 7), 0), (soft(1174.66, 0.27, 0.14, 0.01, 7), 0.08)))
save("reward", mix(*[(soft(f, 0.7 - k * 0.07, 0.14, 0.008, 6), k * 0.07) for k, f in enumerate([784, 988, 1175, 1568])]))
print("Zapisano dźwięki w", os.path.abspath(OUT))
