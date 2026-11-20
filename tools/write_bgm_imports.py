# UTF-8 without BOM. Godot wav .import stubs for CI/--import.
import hashlib
import os

BASE = os.path.join(os.path.dirname(__file__), "..", "assets", "bgm")
LOOP = {"lobby", "shop", "stage_easy", "office"}  # stage_hard* 는 플레이리스트라 자체 루프 끔


def main() -> None:
	for name in ["lobby", "shop", "stage_easy", "stage_hard", "stage_hard_2", "clear", "defeated", "office"]:
		src = f"res://assets/bgm/{name}.wav"
		h = hashlib.md5(src.encode()).hexdigest()
		uid = "uid://c" + h[:15]
		dest = f"res://.godot/imported/{name}.wav-{h}.sample"
		loop = 1 if name in LOOP else 0
		text = (
			"[remap]\n\n"
			'importer="wav"\n'
			'type="AudioStreamWAV"\n'
			f'uid="{uid}"\n'
			f'path="{dest}"\n\n'
			"[deps]\n\n"
			f'source_file="{src}"\n'
			f'dest_files=["{dest}"]\n\n'
			"[params]\n\n"
			"force/8_bit=false\n"
			"force/mono=false\n"
			"force/max_rate=false\n"
			"force/max_rate_hz=44100\n"
			"edit/trim=false\n"
			"edit/normalize=false\n"
			f"edit/loop_mode={loop}\n"
			"edit/loop_begin=0\n"
			"edit/loop_end=-1\n"
			"compress/mode=2\n"
		)
		path = os.path.join(BASE, name + ".wav.import")
		with open(path, "w", encoding="utf-8", newline="\n") as f:
			f.write(text)
		print("wrote", path)


if __name__ == "__main__":
	main()
