# 직원 초상화의 흰 배경을 투명하게 만든다. 흰 배경이 그대로 있는 원본에 한 번만 실행한다.
# 1) 가장자리에서부터 이어진 흰색을 지운다.
# 2) 팔과 몸 사이처럼 그림 안에 갇힌 순백 영역도 지운다.
#    흰 셔츠나 가운은 음영이 있어 평균 밝기가 낮으므로(약 0.91~0.95) 남는다.
# 3) 지운 영역에 맞닿은 테두리는 흰색을 빼서(color to alpha) 흰 테두리가 남지 않게 한다.
# 실행: godot --headless --path . --script res://tools/clear_portrait_bg.gd
extends SceneTree

const WHITE_MIN := 0.9         # 이보다 밝고
const MAX_CHROMA := 0.08       # 색이 거의 없으면 배경 후보로 본다
const HOLE_MIN_PIXELS := 40    # 갇힌 영역이 이보다 작으면 하이라이트로 보고 남긴다
const HOLE_MEAN_MIN := 0.975   # 갇힌 영역의 평균 밝기가 이 이상이면 배경으로 본다
const EDGE_BAND := 2           # 테두리 처리 폭 (픽셀)
const OPAQUE_BELOW := 0.6      # 테두리 픽셀이 이보다 어두우면 완전히 불투명


func _init() -> void:
	var regex := RegEx.create_from_string("^(hr|dv|sl)\\d(_\\d)?\\.png$")
	for team in ["hr", "dv", "sl"]:
		var dir: String = "res://assets/tower/" + team
		for file in DirAccess.get_files_at(dir):
			if regex.search(file):
				_clear(ProjectSettings.globalize_path(dir.path_join(file)))
	quit()


func _clear(path: String) -> void:
	var image := Image.load_from_file(path)
	image.convert(Image.FORMAT_RGBA8)
	var w := image.get_width()
	var h := image.get_height()
	var data := image.get_data()
	var n := w * h
	# 픽셀마다 가장 어두운 채널 밝기와 배경 후보 여부
	var low := PackedFloat32Array()
	low.resize(n)
	var candidate := PackedByteArray()
	candidate.resize(n)
	for i in n:
		var r := data[i * 4] / 255.0
		var g := data[i * 4 + 1] / 255.0
		var b := data[i * 4 + 2] / 255.0
		var mn := minf(r, minf(g, b))
		low[i] = mn
		if data[i * 4 + 3] < 13 or (mn >= WHITE_MIN and maxf(r, maxf(g, b)) - mn <= MAX_CHROMA):
			candidate[i] = 1

	# 배경 후보를 연결 영역으로 묶어 가장자리에 닿거나 순백으로 갇힌 영역만 배경으로 정한다
	var bg := PackedByteArray()
	bg.resize(n)
	var seen := PackedByteArray()
	seen.resize(n)
	for start in n:
		if not candidate[start] or seen[start]:
			continue
		var region: Array[int] = [start]
		seen[start] = 1
		var touches_edge := false
		var sum := 0.0
		var k := 0
		while k < region.size():
			var i: int = region[k]
			k += 1
			sum += low[i]
			var x := i % w
			var y := i / w
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				touches_edge = true
			for j in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
				if j >= 0 and j < n and candidate[j] and not seen[j]:
					seen[j] = 1
					region.append(j)
		if touches_edge or (region.size() >= HOLE_MIN_PIXELS and sum / region.size() >= HOLE_MEAN_MIN):
			for i in region:
				bg[i] = 1

	# 배경에서 EDGE_BAND 픽셀 안쪽까지를 테두리로 본다
	var band := bg.duplicate()
	for step in EDGE_BAND:
		var grown := band.duplicate()
		for i in n:
			if band[i]:
				continue
			var x := i % w
			if (x > 0 and band[i - 1]) or (x < w - 1 and band[i + 1]) \
					or (i >= w and band[i - w]) or (i + w < n and band[i + w]):
				grown[i] = 1
		band = grown

	var cleared := 0
	for i in n:
		if bg[i]:
			data[i * 4 + 3] = 0
			cleared += 1
		elif band[i]:
			# 흰색과 섞인 색에서 흰색을 빼고 그만큼 투명하게 한다
			var a := clampf((1.0 - low[i]) / (1.0 - OPAQUE_BELOW), 0.0, 1.0)
			if a < 1.0:
				for c in 3:
					var v := data[i * 4 + c] / 255.0
					data[i * 4 + c] = roundi(clampf((v - (1.0 - a)) / maxf(a, 0.01), 0.0, 1.0) * 255.0)
				data[i * 4 + 3] = roundi(data[i * 4 + 3] * a)
	Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data).save_png(path)
	print("%s cleared %d%%" % [path.get_file(), roundi(100.0 * cleared / n)])
