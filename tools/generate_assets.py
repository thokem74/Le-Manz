#!/usr/bin/env python3
"""Reproducible, hand-designed pixel assets and synthesized arcade effects.

No original game files are required. Run from any directory with Python 3.
"""
from pathlib import Path
import math
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

RATE = 22050


def write_wave(name, duration, sample):
    values = []
    for i in range(int(RATE * duration)):
        t = i / RATE
        # Effects have soft edges; the engine is exactly periodic at the loop boundary.
        envelope = 1.0 if name == "engine" else min(1.0, t / 0.008, (duration - t) / 0.018)
        values.append(int(max(-1, min(1, sample(t) * envelope)) * 32767))
    with wave.open(str(AUDIO / f"{name}.wav"), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(struct.pack(f"<{len(values)}h", *values))


def square(t, frequency):
    return 1.0 if math.sin(t * frequency * math.tau) >= 0 else -1.0


write_wave("engine", 1.0, lambda t: 0.13 * square(t, 90) + 0.065 * square(t, 180) + 0.04 * math.sin(t * 45 * math.tau))
noise = random.Random(1982)
write_wave("crash", 0.55, lambda t: (noise.uniform(-1, 1) * 0.45 + square(t, 40 + 80 * (1 - t / 0.55)) * 0.15) * (1 - t / 0.55))
write_wave("tick", 0.09, lambda t: square(t, 660) * 0.18)
write_wave("bonus", 0.32, lambda t: square(t, [523, 659, 784, 1046][min(3, int(t / 0.08))]) * 0.20)
write_wave("extra_time", 0.64, lambda t: square(t, [523, 659, 784, 1046, 784, 1046, 1318, 1568][min(7, int(t / 0.08))]) * 0.20)
write_wave("finish", 0.8, lambda t: square(t, [784, 659, 523, 392][min(3, int(t / 0.2))]) * 0.19)
# Godot's WAV importer records the seamless engine loop in source control.
engine_import = AUDIO / "engine.wav.import"
if not engine_import.exists():
    engine_import.write_text('''[remap]
importer="wav"
type="AudioStreamWAV"
path="res://.godot/imported/engine.wav-generated.sample"

[deps]
source_file="res://assets/audio/engine.wav"
dest_files=["res://.godot/imported/engine.wav-generated.sample"]

[params]
force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode=1
edit/loop_begin=0
edit/loop_end=-1
compress/mode=0
''')
print("Generated pixel art, bitmap font and six arcade effects.")
