#!/usr/bin/env python3
"""Synthesises every game sound from scratch (stdlib only), so all audio is
original and licence-free. Re-run to tweak; output is deterministic.

    python3 tools/make_sounds.py app/Resources/Sounds
"""
import math, os, random, struct, sys, wave

SR = 44100
rng = random.Random(3)


def env(t, attack, decay):
    """Fast attack, exponential decay."""
    a = min(1.0, t / attack) if attack > 0 else 1.0
    return a * math.exp(-t / decay)


def mallet(freq, dur, decay=0.12, bright=0.25, vol=0.6):
    """Marimba-like note: fundamental + soft 4th harmonic + tiny click."""
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        e = env(t, 0.002, decay)
        s = math.sin(2 * math.pi * freq * t) + bright * math.sin(2 * math.pi * freq * 4 * t) * math.exp(-t / (decay / 4))
        out.append(vol * e * s)
    return out


def noise_burst(dur, decay, vol=0.3, lowpass=0.2):
    out, prev = [], 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        prev += lowpass * (rng.uniform(-1, 1) - prev)       # one-pole low-pass
        out.append(vol * env(t, 0.001, decay) * prev * 3)
    return out


def sweep(f0, f1, dur, vol=0.35, decay=0.2):
    out, phase = [], 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        f = f0 + (f1 - f0) * (t / dur)
        phase += 2 * math.pi * f / SR
        out.append(vol * env(t, 0.004, decay) * (math.sin(phase) + 0.3 * math.sin(2 * phase)))
    return out


def mix(*parts):
    """parts: (offset_seconds, samples)"""
    n = max(int(o * SR) + len(s) for o, s in parts)
    out = [0.0] * n
    for o, s in parts:
        k = int(o * SR)
        for i, v in enumerate(s):
            out[k + i] += v
    return out


def write(path, samples, gain=1.0):
    peak = max(1e-9, max(abs(x) for x in samples))
    norm = min(1.0, 0.89 / peak) * gain
    tail = int(SR * 0.004)                                 # tiny fade-out, no click at the end
    for i in range(tail):
        samples[-1 - i] *= i / tail
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x * norm)) * 32767)) for x in samples))


C5, E5, G5, A5, C6, E6 = 523.25, 659.25, 783.99, 880.0, 1046.5, 1318.5

SOUNDS = {
    # soft UI tap (cells, buttons, tiles)
    "tap": (lambda: mix((0, noise_burst(0.03, 0.006, 0.25, 0.5)), (0, mallet(1400, 0.05, 0.015, 0.0, 0.25)))),
    # letter key: wooden "tok"
    "key": (lambda: mix((0, mallet(620, 0.12, 0.035, 0.35, 0.7)), (0, noise_burst(0.02, 0.004, 0.15, 0.6)))),
    # take a letter back: lower tok
    "undo": (lambda: mallet(420, 0.12, 0.03, 0.3, 0.6)),
    # wrong word: two low falling notes, gentle
    "wrong": (lambda: mix((0, sweep(300, 240, 0.16, 0.5, 0.08)), (0.13, sweep(240, 180, 0.22, 0.5, 0.1)))),
    # word solved: rising three-note mallet
    "correct": (lambda: mix((0, mallet(C5, 0.3, 0.12)), (0.07, mallet(E5, 0.3, 0.12)), (0.14, mallet(G5, 0.5, 0.2)))),
    # level complete: longer arpeggio with a ringing top note
    "complete": (lambda: mix((0, mallet(C5, 0.4, 0.15)), (0.09, mallet(E5, 0.4, 0.15)), (0.18, mallet(G5, 0.4, 0.15)),
                             (0.27, mallet(C6, 1.0, 0.45, 0.3)), (0.27, mallet(E6, 1.0, 0.4, 0.1, 0.25)))),
    # one star landing
    "star": (lambda: mix((0, mallet(A5 * 2, 0.35, 0.12, 0.1, 0.5)), (0.03, mallet(E6, 0.35, 0.1, 0.0, 0.3)))),
    # hint: quick sparkle
    "hint": (lambda: mix((0, mallet(1318, 0.2, 0.06, 0.1, 0.4)), (0.05, mallet(1568, 0.2, 0.06, 0.1, 0.4)),
                         (0.10, mallet(2093, 0.3, 0.09, 0.1, 0.4)))),
    # remove-a-letter hint: soft whoosh
    "erase": (lambda: mix((0, noise_burst(0.25, 0.08, 0.5, 0.08)), (0, sweep(900, 500, 0.2, 0.15, 0.08)))),
    # coins spent / earned
    "coin": (lambda: mix((0, mallet(988, 0.12, 0.05, 0.2, 0.5)), (0.07, mallet(E6, 0.4, 0.15, 0.2, 0.5)))),
    # open a clue / navigate forward
    "open": (lambda: sweep(500, 800, 0.12, 0.3, 0.06)),
}


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "app/Resources/Sounds"
    os.makedirs(out, exist_ok=True)
    for name, make in SOUNDS.items():
        p = os.path.join(out, name + ".wav")
        write(p, make())
        print("%-9s %5.0f ms  %s" % (name, os.path.getsize(p) / 2 / SR * 1000, p))


if __name__ == "__main__":
    main()
