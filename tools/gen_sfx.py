"""간단한 효과음 WAV 생성기 (표준 라이브러리만 사용).

실행: python tools/gen_sfx.py
출력: assets/sfx/*.wav
"""
from __future__ import annotations

import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sfx")
RATE = 22050


def _clamp(x: float) -> int:
	return max(-32767, min(32767, int(x * 32767)))


def write_wav(path: str, samples: list[float]) -> None:
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with wave.open(path, "w") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(RATE)
		frames = b"".join(struct.pack("<h", _clamp(s)) for s in samples)
		w.writeframes(frames)


def env(i: int, n: int, attack: float = 0.01, release: float = 0.2) -> float:
	t = i / max(1, n - 1)
	a = min(1.0, t / max(0.001, attack))
	r = min(1.0, (1.0 - t) / max(0.001, release))
	return a * r


def tone(seconds: float, freq: float, vol: float = 0.4, attack=0.01, release=0.25, wave="sine") -> list[float]:
	n = int(RATE * seconds)
	out = []
	for i in range(n):
		t = i / RATE
		phase = 2 * math.pi * freq * t
		if wave == "square":
			s = 1.0 if math.sin(phase) >= 0 else -1.0
		elif wave == "saw":
			s = 2.0 * ((freq * t) % 1.0) - 1.0
		elif wave == "noise":
			s = random.uniform(-1.0, 1.0)
		else:
			s = math.sin(phase)
		out.append(s * vol * env(i, n, attack, release))
	return out


def sweep(seconds: float, f0: float, f1: float, vol: float = 0.35, wave="sine") -> list[float]:
	n = int(RATE * seconds)
	out = []
	phase = 0.0
	for i in range(n):
		t = i / max(1, n - 1)
		freq = f0 + (f1 - f0) * t
		phase += 2 * math.pi * freq / RATE
		if wave == "square":
			s = 1.0 if math.sin(phase) >= 0 else -1.0
		else:
			s = math.sin(phase)
		out.append(s * vol * env(i, n, 0.01, 0.35))
	return out


def mix(*tracks: list[float]) -> list[float]:
	n = max(len(t) for t in tracks)
	out = [0.0] * n
	for tr in tracks:
		for i, v in enumerate(tr):
			out[i] += v
	peak = max((abs(x) for x in out), default=1.0)
	if peak > 1.0:
		out = [x / peak for x in out]
	return out


def gen_click() -> list[float]:
	# 짧은 UI 딸깍
	return mix(
		tone(0.045, 880, 0.35, 0.002, 0.5, "sine"),
		tone(0.03, 1320, 0.18, 0.002, 0.6, "sine"),
	)


def gen_hit() -> list[float]:
	# 근접 타격: 저음 + 노이즈 퍽
	body = sweep(0.09, 220, 90, 0.45, "sine")
	thud = tone(0.07, 70, 0.35, 0.001, 0.7, "sine")
	noise = tone(0.05, 1, 0.28, 0.001, 0.55, "noise")
	return mix(body, thud, noise)


def gen_projectile() -> list[float]:
	# 투사체 발사: 위로 올라가는 짧은 삐융
	return mix(
		sweep(0.1, 420, 980, 0.28, "sine"),
		tone(0.06, 640, 0.12, 0.005, 0.5, "square"),
	)


def gen_impact() -> list[float]:
	# 피격/명중: 짧은 탁 + 노이즈
	return mix(
		sweep(0.07, 380, 120, 0.4, "sine"),
		tone(0.05, 1, 0.32, 0.001, 0.6, "noise"),
		tone(0.04, 180, 0.2, 0.001, 0.55, "square"),
	)


def gen_promote() -> list[float]:
	return mix(
		sweep(0.18, 400, 900, 0.3, "sine"),
		tone(0.12, 600, 0.2, 0.01, 0.4, "sine"),
		tone(0.1, 900, 0.12, 0.02, 0.5, "sine"),
	)


def gen_wave() -> list[float]:
	return mix(
		tone(0.08, 520, 0.25, 0.005, 0.4, "square"),
		tone(0.1, 780, 0.18, 0.02, 0.45, "sine"),
	)


def gen_boss() -> list[float]:
	return mix(
		sweep(0.28, 140, 60, 0.45, "sine"),
		tone(0.2, 90, 0.35, 0.01, 0.5, "sine"),
		tone(0.15, 1, 0.25, 0.001, 0.5, "noise"),
	)


def gen_win() -> list[float]:
	return mix(
		tone(0.12, 523, 0.28, 0.01, 0.35, "sine"),
		tone(0.14, 659, 0.24, 0.04, 0.35, "sine"),
		tone(0.2, 784, 0.3, 0.08, 0.4, "sine"),
	)


def gen_lose() -> list[float]:
	return mix(
		sweep(0.35, 300, 80, 0.35, "sine"),
		tone(0.25, 110, 0.25, 0.02, 0.55, "sine"),
	)


def main() -> None:
	random.seed(7)
	sounds = {
		"click": gen_click,
		"hit": gen_hit,
		"projectile": gen_projectile,
		"impact": gen_impact,
		"promote": gen_promote,
		"wave": gen_wave,
		"boss": gen_boss,
		"win": gen_win,
		"lose": gen_lose,
	}
	for name, fn in sounds.items():
		path = os.path.join(OUT, f"{name}.wav")
		write_wav(path, fn())
		print("wrote", path)


if __name__ == "__main__":
	main()
