#!/usr/bin/env python3
"""Synthesizes all of Catch the Jewels' original sound effects and music loop.

Everything is generated from simple waveforms, so the audio is original and
royalty-free. Writes 16-bit mono WAV files; generate_assets.sh converts them to
CAF (effects, low latency) and AAC/M4A (music, small size).

Usage: synthesize_audio.py <output-directory>
"""

import math
import random
import struct
import sys
import wave
from pathlib import Path

RATE = 44100


def note(freq_name: str) -> float:
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3,
             "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    name, octave = freq_name[:-1], int(freq_name[-1])
    semitones = names[name] + (octave - 4) * 12
    return 440.0 * (2 ** (semitones / 12))


def envelope(i: int, length: int, attack: float, release: float) -> float:
    t = i / RATE
    total = length / RATE
    if t < attack:
        return t / attack
    remaining = total - t
    if remaining < release:
        return max(0.0, remaining / release)
    return 1.0


def bell(freq: float, duration: float, volume: float = 0.5, decay: float = 6.0) -> list[float]:
    """Bright, glassy tone: fundamental plus inharmonic partials with exponential decay."""
    n = int(duration * RATE)
    partials = [(1.0, 1.0), (2.0, 0.45), (3.01, 0.22), (4.2, 0.12), (5.4, 0.06)]
    out = []
    for i in range(n):
        t = i / RATE
        sample = sum(a * math.sin(2 * math.pi * freq * m * t) for m, a in partials)
        out.append(volume * sample * math.exp(-decay * t) * envelope(i, n, 0.004, 0.02) / 1.85)
    return out


def pluck(freq: float, duration: float, volume: float = 0.35) -> list[float]:
    """Soft harp-like pluck for the music loop."""
    n = int(duration * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        sample = (math.sin(2 * math.pi * freq * t)
                  + 0.35 * math.sin(2 * math.pi * freq * 2 * t)
                  + 0.12 * math.sin(2 * math.pi * freq * 3 * t))
        out.append(volume * sample * math.exp(-3.2 * t) * envelope(i, n, 0.006, 0.05) / 1.47)
    return out


def pad(freq: float, duration: float, volume: float = 0.08) -> list[float]:
    n = int(duration * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        sample = (math.sin(2 * math.pi * freq * t) + 0.5 * math.sin(2 * math.pi * freq * 1.5 * t + 0.3)
                  + 0.25 * math.sin(2 * math.pi * freq * 2.003 * t))
        out.append(volume * sample * envelope(i, n, 0.6, 0.8) / 1.75)
    return out


def noise_burst(duration: float, volume: float, decay: float, seed: int) -> list[float]:
    rng = random.Random(seed)
    n = int(duration * RATE)
    out = []
    last = 0.0
    for i in range(n):
        t = i / RATE
        # One-pole low-pass for a darker rumble.
        last = last * 0.82 + rng.uniform(-1, 1) * 0.18
        out.append(volume * last * 3 * math.exp(-decay * t))
    return out


def sweep(start: float, end: float, duration: float, volume: float) -> list[float]:
    n = int(duration * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        f = start + (end - start) * (i / n)
        phase += 2 * math.pi * f / RATE
        out.append(volume * math.sin(phase) * envelope(i, n, 0.005, 0.08))
    return out


def mix(length_seconds: float, *layers: tuple[float, list[float]]) -> list[float]:
    out = [0.0] * int(length_seconds * RATE)
    for offset, samples in layers:
        start = int(offset * RATE)
        for i, s in enumerate(samples):
            if start + i < len(out):
                out[start + i] += s
    return out


def write(path: Path, samples: list[float]) -> None:
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = min(1.0, 0.89 / peak)
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * gain)) * 32767)) for s in samples))
    print(f"wrote {path.name} ({len(samples) / RATE:.2f}s)")


def main() -> None:
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)

    # Each jewel has its own pitch so value can be heard as well as seen.
    jewels = {"ruby": "C6", "sapphire": "E6", "emerald": "G6", "amethyst": "B6"}
    for name, pitch in jewels.items():
        f = note(pitch)
        write(out / f"sfx_{name}.wav", mix(0.45, (0, bell(f, 0.45, 0.55)), (0.03, bell(f * 1.5, 0.3, 0.18))))

    write(out / "sfx_gold.wav", mix(0.8, *[(i * 0.06, bell(note(p), 0.5, 0.45)) for i, p in enumerate(["C6", "E6", "G6", "C7"])]))
    write(out / "sfx_bomb.wav", mix(0.7, (0, noise_burst(0.7, 0.9, 6.5, 7)), (0, sweep(160, 45, 0.45, 0.7))))
    write(out / "sfx_heart.wav", mix(0.6, (0, bell(note("A5"), 0.4, 0.45)), (0.1, bell(note("E6"), 0.5, 0.45))))
    write(out / "sfx_countdown.wav", bell(note("A5"), 0.25, 0.45, decay=12))
    write(out / "sfx_start.wav", mix(0.5, (0, bell(note("E6"), 0.3, 0.4)), (0.05, bell(note("A6"), 0.45, 0.5))))
    write(out / "sfx_gameOver.wav", mix(1.3, *[(i * 0.18, bell(note(p), 0.7, 0.45, decay=4)) for i, p in enumerate(["G5", "E5", "C5", "G4"])]))
    write(out / "sfx_newBest.wav", mix(1.4, *[(i * 0.11, bell(note(p), 0.8, 0.45, decay=4)) for i, p in enumerate(["C5", "E5", "G5", "C6", "E6", "G6"])]))
    write(out / "sfx_achievement.wav", mix(1.0, (0, bell(note("G5"), 0.6, 0.4)), (0.12, bell(note("D6"), 0.6, 0.4)), (0.24, bell(note("G6"), 0.8, 0.5))))
    write(out / "sfx_tap.wav", bell(note("E6"), 0.08, 0.3, decay=40))

    # Music: 16-bar royal arpeggio loop at 96 BPM (exactly 40 seconds, loops seamlessly).
    bpm = 96
    beat = 60 / bpm
    bars = 16
    length = bars * 4 * beat
    progression = [
        ("A3", ["A4", "C5", "E5", "C5"]), ("F3", ["F4", "A4", "C5", "A4"]),
        ("C3", ["G4", "C5", "E5", "C5"]), ("G3", ["G4", "B4", "D5", "B4"]),
    ]
    layers = []
    for bar in range(bars):
        root, arpeggio = progression[bar % 4]
        start = bar * 4 * beat
        layers.append((start, pad(note(root), 4 * beat, 0.07)))
        for step in range(8):
            pitch = arpeggio[step % 4]
            if bar % 8 >= 4 and step % 4 == 2:
                pitch = pitch[:-1] + str(int(pitch[-1]) + 1)
            layers.append((start + step * beat / 2, pluck(note(pitch), beat * 1.6, 0.16)))
    music = mix(length + 2 * beat, *layers)
    # Fold the tail back onto the start so the loop point is seamless.
    loop_samples = int(length * RATE)
    for i in range(len(music) - loop_samples):
        music[i] += music[loop_samples + i]
    write(out / "music_royal_loop.wav", music[:loop_samples])


if __name__ == "__main__":
    main()
