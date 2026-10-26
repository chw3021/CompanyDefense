# 원본 리소스 중 화면에 비해 지나치게 큰 이미지를 줄인다 (APK 용량, GPU 메모리 절약).
# 실행: godot --headless --path . --script res://tools/shrink_assets.gd
# 스프라이트 시트(128px 프레임)는 프레임 계산이 깨지므로 건드리지 않는다.
extends SceneTree

const RULES := [
	# [폴더, 파일 이름 정규식, 긴 변 최대 크기]
	["res://assets/tower", "^(hr|dv|sl)\\d(_\\d)?\\.png$", 512],
	["res://assets/menu", "\\.png$", 256],
	["res://assets/icons", "^(?!loading)[\\w-]+\\.png$", 256],  # loading.png 은 스프라이트 시트
	["res://assets/hobby", "\\.png$", 256],
	["res://assets/constructure", "\\.png$", 256],
	["res://assets/menu", "\\.jpg$", 1440],
	["res://assets/enemy", "\\.png$", 160],
]


func _init() -> void:
	var total := 0
	for rule in RULES:
		total += _shrink_dir(rule[0], rule[1], rule[2])
	print("shrunk %d files" % total)
	quit()


func _shrink_dir(dir_path: String, pattern: String, max_side: int) -> int:
	var regex := RegEx.create_from_string(pattern)
	var count := 0
	for file in DirAccess.get_files_at(dir_path):
		if regex.search(file) != null:
			if _shrink(dir_path.path_join(file), max_side):
				count += 1
	for sub in DirAccess.get_directories_at(dir_path):
		count += _shrink_dir(dir_path.path_join(sub), pattern, max_side)
	return count


func _shrink(path: String, max_side: int) -> bool:
	var abs_path := ProjectSettings.globalize_path(path)
	var image := Image.load_from_file(abs_path)
	if image == null:
		push_error("load failed: " + path)
		return false
	var w := image.get_width()
	var h := image.get_height()
	if maxi(w, h) <= max_side:
		return false
	var scale := float(max_side) / maxi(w, h)
	image.resize(roundi(w * scale), roundi(h * scale), Image.INTERPOLATE_LANCZOS)
	var err := image.save_jpg(abs_path, 0.88) if path.ends_with(".jpg") else image.save_png(abs_path)
	print("%s %dx%d -> %dx%d" % [path, w, h, image.get_width(), image.get_height()])
	return err == OK
