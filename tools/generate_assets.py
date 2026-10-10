#!/usr/bin/env python3
"""Reproducible, hand-designed pixel assets and synthesized arcade effects.

No original game files are required. Run from any directory with Python 3.
"""
from pathlib import Path
import math
import re
import random
import struct
import wave
import zlib

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/art"
FONT = ROOT / "assets/font"
AUDIO = ROOT / "assets/audio"
for folder in (ART, FONT, AUDIO):
    folder.mkdir(parents=True, exist_ok=True)

# Five-by-seven glyphs, drawn on a six-by-eight cell. Lowercase uses capitals.
GLYPHS = {
    "A": "01110 10001 10001 11111 10001 10001 10001",
    "B": "11110 10001 10001 11110 10001 10001 11110",
    "C": "01111 10000 10000 10000 10000 10000 01111",
    "D": "11110 10001 10001 10001 10001 10001 11110",
    "E": "11111 10000 10000 11110 10000 10000 11111",
    "F": "11111 10000 10000 11110 10000 10000 10000",
    "G": "01111 10000 10000 10111 10001 10001 01111",
    "H": "10001 10001 10001 11111 10001 10001 10001",
    "I": "11111 00100 00100 00100 00100 00100 11111",
    "J": "00111 00010 00010 00010 10010 10010 01100",
    "K": "10001 10010 10100 11000 10100 10010 10001",
    "L": "10000 10000 10000 10000 10000 10000 11111",
    "M": "10001 11011 10101 10101 10001 10001 10001",
    "N": "10001 11001 10101 10011 10001 10001 10001",
    "O": "01110 10001 10001 10001 10001 10001 01110",
    "P": "11110 10001 10001 11110 10000 10000 10000",
    "Q": "01110 10001 10001 10001 10101 10010 01101",
    "R": "11110 10001 10001 11110 10100 10010 10001",
    "S": "01111 10000 10000 01110 00001 00001 11110",
    "T": "11111 00100 00100 00100 00100 00100 00100",
    "U": "10001 10001 10001 10001 10001 10001 01110",
    "V": "10001 10001 10001 10001 10001 01010 00100",
    "W": "10001 10001 10001 10101 10101 11011 10001",
    "X": "10001 10001 01010 00100 01010 10001 10001",
    "Y": "10001 10001 01010 00100 00100 00100 00100",
    "Z": "11111 00001 00010 00100 01000 10000 11111",
    "0": "01110 10001 10011 10101 11001 10001 01110",
    "1": "00100 01100 00100 00100 00100 00100 01110",
    "2": "01110 10001 00001 00010 00100 01000 11111",
    "3": "11110 00001 00001 01110 00001 00001 11110",
    "4": "00010 00110 01010 10010 11111 00010 00010",
    "5": "11111 10000 10000 11110 00001 00001 11110",
    "6": "01110 10000 10000 11110 10001 10001 01110",
    "7": "11111 00001 00010 00100 01000 01000 01000",
    "8": "01110 10001 10001 01110 10001 10001 01110",
    "9": "01110 10001 10001 01111 00001 00001 01110",
    ":": "00000 00100 00100 00000 00100 00100 00000",
    ".": "00000 00000 00000 00000 00000 00100 00100",
    ",": "00000 00000 00000 00000 00100 00100 01000",
    "-": "00000 00000 00000 11111 00000 00000 00000",
    "+": "00000 00100 00100 11111 00100 00100 00000",
    "/": "00001 00001 00010 00100 01000 10000 10000",
    "<": "00010 00100 01000 10000 01000 00100 00010",
    ">": "01000 00100 00010 00001 00010 00100 01000",
    "!": "00100 00100 00100 00100 00100 00000 00100",
    "?": "01110 10001 00001 00010 00100 00000 00100",
    "=": "00000 00000 11111 00000 11111 00000 00000",
    "(": "00010 00100 01000 01000 01000 00100 00010",
    ")": "01000 00100 00010 00010 00010 00100 01000",
    "%": "11001 11010 00100 00100 01000 10110 00110",
    "'": "00100 00100 01000 00000 00000 00000 00000",
}
atlas = bytearray(96 * 48 * 4)
characters = []
for index, code in enumerate(range(32, 127)):
    x, y = (index % 16) * 6, (index // 16) * 8
    pattern = GLYPHS.get(chr(code).upper(), "00000 " * 7).split()
    for yy, row in enumerate(pattern):
        for xx, value in enumerate(row):
            if value == "1":
                pixel_offset = ((y + yy) * 96 + x + xx) * 4
                atlas[pixel_offset:pixel_offset + 4] = bytes((255, 255, 255, 255))
    characters.append(f"char id={code} x={x} y={y} width=5 height=7 xoffset=0 yoffset=0 xadvance=6 page=0 chnl=15")
def png_chunk(kind, payload):
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))


scanlines = b"".join(b"\0" + atlas[row * 384:(row + 1) * 384] for row in range(48))
(FONT / "retro.png").write_bytes(
    b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", struct.pack(">IIBBBBB", 96, 48, 8, 6, 0, 0, 0))
    + png_chunk(b"IDAT", zlib.compress(scanlines)) + png_chunk(b"IEND", b"")
)
(FONT / "retro.fnt").write_text(
    'info face="Le Manz Pixel" size=8 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1\n'
    'common lineHeight=8 base=7 scaleW=96 scaleH=48 pages=1 packed=0\n'
    'page id=0 file="retro.png"\nchars count=95\n' + "\n".join(characters) + "\n"
)


def rect(x, y, w, h, colour):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{colour}"/>'


def svg(name, w, h, content):
    (ART / name).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{content}</svg>\n')


# Native 32 x 34 artwork: integer rectangles retain crisp edges at every scale.
car = "".join([
    rect(0, 6, 6, 8, "#161622"), rect(26, 6, 6, 8, "#161622"),
    rect(0, 23, 6, 8, "#161622"), rect(26, 23, 6, 8, "#161622"),
    rect(10, 0, 12, 3, "#ffffff"), rect(6, 3, 20, 30, "#eeeecc"),
    rect(4, 5, 24, 6, "#ffffff"), rect(12, 3, 8, 9, "#c3c3c3"),
    rect(9, 12, 14, 9, "#222034"), rect(11, 12, 10, 3, "#6ecbd4"),
    rect(8, 23, 16, 6, "#ffffff"), rect(14, 23, 4, 6, "#c3c3c3"),
    rect(4, 30, 24, 4, "#eeeecc"), rect(6, 31, 4, 3, "#b13e53"),
    rect(22, 31, 4, 3, "#b13e53"), rect(6, 5, 4, 3, "#d9d56e"),
    rect(22, 5, 4, 3, "#d9d56e"),
])
svg("traffic.svg", 32, 34, car)
explosions = ""
for frame in (1, 2):
    offset = frame * 32
    explosions += rect(offset + 7, 4, 18, 27, "#b13e53")
    for x, y, w, h in [(3, 11, 26, 12), (10, 3, 10, 28), (0, 16, 32, 5), (14, 0, 5, 34)]:
        explosions += rect(offset + x, y, w, h, "#ef7d57" if frame == 1 else "#d9d56e")
    explosions += rect(offset + 12, 11, 8, 12, "#eeeecc")
svg("player.svg", 96, 34, car + explosions)
svg("pixel.svg", 1, 8, rect(0, 0, 1, 8, "#ffffff"))
svg("kerb.svg", 4, 8, rect(0, 0, 4, 8, "#ffffff"))
svg("dash.svg", 1, 8, rect(0, 1, 1, 6, "#ffffff"))
svg("tree.svg", 12, 8, rect(5, 4, 2, 4, "#663931") + rect(2, 1, 8, 5, "#346524") + rect(0, 2, 12, 3, "#6abe30"))
svg("lights.svg", 32, 34, rect(6, 31, 4, 3, "#ff3455") + rect(22, 31, 4, 3, "#ff3455"))
svg("indicator.svg", 2, 3, rect(0, 0, 2, 3, "#ffdf64"))
checks = "".join(rect(x * 8, y * 8, 8, 8, "#eeeecc" if (x + y) % 2 == 0 else "#222034") for y in range(2) for x in range(28))
svg("finish.svg", 224, 16, checks)
logo = ""
for i, letter in enumerate("LE MANZ"):
    for y, row in enumerate(GLYPHS.get(letter, "00000 " * 7).split()):
        for x, value in enumerate(row):
            if value == "1":
                logo += rect(i * 24 + x * 4 + 2, y * 4 + 2, 4, 4, "#b13e53")
                logo += rect(i * 24 + x * 4, y * 4, 4, 4, "#d9d56e")
svg("logo.svg", 166, 30, logo)
# App icon follows the in-game car rather than retaining the Godot logo.
svg("app_icon.svg", 192, 192, rect(0, 0, 192, 192, "#222034") + rect(40, 0, 112, 192, "#6c6c6c") + '<g transform="translate(48,45) scale(3)">' + car + "</g>" + rect(94, 0, 4, 28, "#eeeecc") + rect(94, 160, 4, 32, "#eeeecc"))

# Eight 16 x 24 roadside props share one inspectable sprite atlas.
props = [
    rect(6, 15, 4, 9, "#663931") + rect(3, 1, 10, 14, "#346524") + rect(0, 5, 16, 9, "#6abe30") + rect(3, 4, 4, 4, "#99c653"),
    rect(2, 13, 12, 8, "#346524") + rect(0, 15, 16, 5, "#6abe30") + rect(4, 13, 4, 2, "#99c653"),
    rect(6, 7, 4, 17, "#eeeecc") + rect(6, 12, 4, 6, "#222034") + rect(7, 8, 2, 3, "#d9d56e"),
    rect(7, 9, 2, 15, "#c3c3c3") + rect(0, 1, 16, 12, "#222034") + rect(1, 2, 14, 10, "#8e80ce") + rect(4, 5, 8, 2, "#eeeecc") + rect(8, 3, 2, 6, "#eeeecc"),
    rect(5, 0, 3, 24, "#c3c3c3") + rect(9, 2, 2, 20, "#383848") + rect(4, 0, 8, 2, "#eeeecc") + rect(4, 22, 8, 2, "#eeeecc") + rect(5, 6, 3, 2, "#d9d56e"),
    rect(6, 15, 4, 9, "#663931") + rect(3, 1, 10, 14, "#537e83") + rect(0, 5, 16, 9, "#6ecbd4") + rect(3, 1, 10, 3, "#ffffff") + rect(0, 5, 16, 3, "#eeeecc"),
    rect(2, 13, 12, 8, "#537e83") + rect(0, 15, 16, 5, "#6ecbd4") + rect(2, 13, 12, 3, "#ffffff"),
    rect(6, 7, 4, 17, "#eeeecc") + rect(6, 12, 4, 6, "#537e83") + rect(7, 8, 2, 3, "#b13e53"),
]
svg("scenery.svg", 128, 24, "".join(f'<g transform="translate({index * 16},0)">{art}</g>' for index, art in enumerate(props)))
svg("ice_mark.svg", 8, 8, rect(0, 1, 3, 1, "#8ab8c9") + rect(2, 2, 1, 3, "#8ab8c9") + rect(3, 4, 4, 1, "#8ab8c9"))
svg("spark.svg", 2, 2, rect(0, 0, 2, 2, "#ffffff"))
svg("reflector.svg", 2, 3, rect(0, 0, 2, 3, "#d9d56e"))
svg("repair.svg", 24, 10, "".join(f'<g transform="translate({i * 8},0)">' + rect(3, 4, 2, 6, "#6ecbd4") + rect(1, 0, 2, 4, "#6ecbd4") + rect(5, 0, 2, 4, "#6ecbd4") + rect(2, 3, 4, 2, "#eeeecc") + rect(0, 8 - i * 2, 1, 1, "#d9d56e") + '</g>' for i in range(3)))

RATE = 22050


def write_wave(name, duration, sample):
    values = []
    for i in range(int(RATE * duration)):
        t = i / RATE
        # Effects have soft edges; the engine is exactly periodic at the loop boundary.
        envelope = 1.0 if name in ("engine", "ice_slip", "repair") else min(1.0, t / 0.008, (duration - t) / 0.018)
        values.append(int(max(-1, min(1, sample(t) * envelope)) * 32767))
    with wave.open(str(AUDIO / f"{name}.wav"), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(struct.pack(f"<{len(values)}h", *values))


def square(t, frequency):
    return 1.0 if math.sin(t * frequency * math.tau) >= 0 else -1.0


def reward_note(t, frequency, duration, strength=1.0):
    """A bell body with quiet pulse harmonics and a click-free note envelope."""
    if t < 0 or t >= duration:
        return 0.0
    attack = min(1.0, t / 0.003)
    release = min(1.0, (duration - t) / 0.025)
    decay = math.exp(-5.0 * t / duration)
    phase = t * frequency * math.tau
    # A finite odd-harmonic series adds SID-like colour without harsh square edges.
    pulse = (math.sin(phase * 3) / 3 + math.sin(phase * 5) / 5) * 0.14
    bell = math.sin(phase) + 0.22 * math.sin(phase * 2)
    return strength * attack * release * decay * (bell + pulse)


def passing_reward(t):
    # The second note overlaps the first note's decay rather than cutting it off.
    return 0.30 * (reward_note(t, 523.251, 0.12) + reward_note(t - 0.055, 783.991, 0.145))


def bonus_reward(t):
    ascent = sum(reward_note(t - index * 0.065, frequency, 0.16, 0.22)
                 for index, frequency in enumerate((523.251, 659.255, 783.991, 1046.502)))
    chord_time = t - 0.24
    chord = sum(reward_note(chord_time, frequency, 0.48, strength)
                for frequency, strength in ((523.251, 0.10), (659.255, 0.08), (783.991, 0.08), (1046.502, 0.12)))
    bass = reward_note(chord_time, 130.813, 0.32, 0.10)
    # A quiet octave shimmer decorates the chord's tail without dominating it.
    shimmer = reward_note(chord_time - 0.045, 2093.005, 0.435, 0.035)
    return ascent + chord + bass + shimmer


# Integer harmonics of 60 Hz yield a periodic, zero-crossing one-second loop.
write_wave("engine", 1.0, lambda t: (0.22 * math.sin(t * 120 * math.tau) + 0.16 * math.sin(t * 240 * math.tau) + 0.10 * math.sin(t * 480 * math.tau) + 0.065 * math.sin(t * 720 * math.tau)) * (0.9 + 0.1 * math.cos(t * 60 * math.tau)))
write_wave("passing", 0.20, passing_reward)
write_wave("ice_slip", 1.0, lambda t: 0.07 * math.sin(t * 1080 * math.tau) * math.sin(t * 13 * math.tau) + 0.035 * math.sin(t * 1620 * math.tau))
write_wave("repair", 1.0, lambda t: 0.10 * math.sin(t * 360 * math.tau) * (0.5 - 0.5 * math.cos(t * 8 * math.tau)))
noise = random.Random(1982)
write_wave("crash", 0.55, lambda t: (noise.uniform(-1, 1) * 0.45 + square(t, 40 + 80 * (1 - t / 0.55)) * 0.15) * (1 - t / 0.55))
write_wave("tick", 0.09, lambda t: square(t, 660) * 0.18)
write_wave("bonus", 0.72, bonus_reward)
write_wave("extra_time", 0.64, lambda t: square(t, [523, 659, 784, 1046, 784, 1046, 1318, 1568][min(7, int(t / 0.08))]) * 0.20)
write_wave("finish", 0.8, lambda t: square(t, [784, 659, 523, 392][min(3, int(t / 0.2))]) * 0.19)
# WAV import mode 2 means Forward; mode 1 means Disabled, not LOOP_FORWARD.
# Preserve importer identities while making regeneration restore loop settings.
for name in ("engine", "ice_slip", "repair"):
    import_file = AUDIO / f"{name}.wav.import"
    if import_file.exists():
        import_text = import_file.read_text()
        import_text = re.sub(r"edit/loop_mode=\d+", "edit/loop_mode=2", import_text)
    else:
        import_text = f'''[remap]
importer="wav"
type="AudioStreamWAV"
path="res://.godot/imported/{name}.wav-generated.sample"
[deps]
source_file="res://assets/audio/{name}.wav"
dest_files=["res://.godot/imported/{name}.wav-generated.sample"]
[params]
edit/trim=false
edit/normalize=false
edit/loop_mode=2
edit/loop_begin=0
edit/loop_end=-1
compress/mode=0
'''
    import_file.write_text(import_text)
print("Generated retro scenery, sprites and nine driving effects.")
