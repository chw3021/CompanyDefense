# 폰트에 특정 글자가 있는지 확인한다
extends SceneTree
func _init() -> void:
	var font: FontFile = load("res://fonts/Jua-Regular.ttf")
	for ch in ["▶", "·", "…", "♥", "★", "×", "→", "%", "!", "?"]:
		print("U+%X " % ch.unicode_at(0), font.has_char(ch.unicode_at(0)))
	quit()
