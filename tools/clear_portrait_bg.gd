# 직원 초상화의 흰 배경을 투명하게 만든다.
# 가장자리에서부터 이어진 흰색만 지우므로 그림 안쪽의 흰 셔츠 등은 남는다.
# 실행: godot --headless --path . --script res://tools/clear_portrait_bg.gd
extends SceneTree

const WHITE_MIN := 0.9      # 이보다 밝고
const MAX_CHROMA := 0.08    # 색이 거의 없으면 배경으로 본다


func _init() -> void:
	var regex := RegEx.create_from_string("^(hr|dv|sl)\\d(_\\d)?\\.png$")
	for team in ["hr", "dv", "sl"]:
		var dir: String = "res://assets/tower/" + team
		for file in DirAccess.get_files_at(dir):
			if regex.search(file):
				_clear(ProjectSettings.globalize_path(dir.path_join(file)))
	quit()


func _is_bg(c: Color) -> bool:
	return c.a > 0.5 and minf(c.r, minf(c.g, c.b)) >= WHITE_MIN \
			and maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)) <= MAX_CHROMA


func _clear(path: String) -> void:
	var image := Image.load_from_file(path)
	image.convert(Image.FORMAT_RGBA8)
	var w := image.get_width()
	var h := image.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack: Array[Vector2i] = []
	for x in w:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in h:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	var cleared := 0
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var i := p.y * w + p.x
		if seen[i]:
			continue
		seen[i] = 1
		var c := image.get_pixelv(p)
		if c.a < 0.05 or _is_bg(c):
			image.set_pixelv(p, Color(c.r, c.g, c.b, 0))
			cleared += 1
			stack.append(p + Vector2i.LEFT)
			stack.append(p + Vector2i.RIGHT)
			stack.append(p + Vector2i.UP)
			stack.append(p + Vector2i.DOWN)
	# 경계의 밝은 픽셀은 반투명하게 해서 흰 테두리가 남지 않게 한다
	var edge := image.duplicate()
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var c := image.get_pixel(x, y)
			if c.a == 0:
				continue
			var near_clear := image.get_pixel(x - 1, y).a == 0 or image.get_pixel(x + 1, y).a == 0 \
					or image.get_pixel(x, y - 1).a == 0 or image.get_pixel(x, y + 1).a == 0
			if near_clear:
				var brightness := minf(c.r, minf(c.g, c.b))
				if brightness > 0.75:
					edge.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * clampf((1.0 - brightness) * 4.0, 0.0, 1.0)))
	edge.save_png(path)
	print("%s cleared %d%%" % [path.get_file(), roundi(100.0 * cleared / (w * h))])
