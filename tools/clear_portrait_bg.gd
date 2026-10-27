# 직원 초상화의 흰 배경을 투명하게 만든다. 흰 배경이 그대로 있는 원본에 한 번만 실행한다.
# 1) 가장자리에서부터 이어진 흰색을 지운다.
# 2) 팔과 몸 사이처럼 그림 안에 갇힌 순백 영역도 지운다.
#    흰 셔츠나 가운은 음영이 있어 평균 밝기가 낮으므로(약 0.91~0.95) 남는다.
# 3) 지운 영역에 맞닿은 테두리는 바로 안쪽 그림 색과 흰색이 섞인 것으로 보고,
#    그 비율만큼 투명하게 하고 색은 안쪽 색으로 바꿔 흰 테두리가 남지 않게 한다.
# 실행: godot --headless --path . --script res://tools/clear_portrait_bg.gd
# 일부만: godot --headless --path . --script res://tools/clear_portrait_bg.gd -- dv6_1.png hr6_1.png
extends SceneTree

const WHITE_MIN := 0.9         # 이보다 밝고
const MAX_CHROMA := 0.08       # 색이 거의 없으면 배경 후보로 본다
const HOLE_MIN_PIXELS := 40    # 갇힌 영역이 이보다 작으면 하이라이트로 보고 남긴다
const HOLE_MEAN_MIN := 0.975   # 갇힌 영역의 평균 밝기가 이 이상이면 배경으로 본다
const NEAR_BG := 8             # 배경에서 이 거리 안에 있는 작은 흰 틈은 크기와 상관없이 지운다
const EDGE_BAND := 3           # 테두리 처리 폭 (픽셀)
const INNER_SEARCH := 3        # 테두리 픽셀의 안쪽 색을 찾는 반경 (픽셀)
# 원래 순백인 그림 부분 (600x800 기준). 이 안의 갇힌 흰 영역은 지우지 않는다.
const KEEP_WHITE := {
	"dv5_2.png": [Rect2i(260, 344, 88, 28)],  # 빛나는 안경 렌즈
}


func _init() -> void:
	var regex := RegEx.create_from_string("^(hr|dv|sl)\\d(_\\d)?\\.png$")
	# 이미 배경을 지운 파일을 다시 돌리면 테두리가 또 깎이므로, 파일 이름을 주면 그것만 처리한다
	var only := OS.get_cmdline_user_args()
	for team in ["hr", "dv", "sl"]:
		var dir: String = "res://assets/tower/" + team
		for file in DirAccess.get_files_at(dir):
			if regex.search(file) and (only.is_empty() or file in only):
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
	var small_regions: Array[Array] = []
	var keep: Array = KEEP_WHITE.get(path.get_file(), [])
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
		var white: bool = sum / region.size() >= HOLE_MEAN_MIN \
				and not keep.any(func(r: Rect2i): return r.has_point(Vector2i(start % w, start / w)))
		if touches_edge or (white and region.size() >= HOLE_MIN_PIXELS):
			for i in region:
				bg[i] = 1
		elif white:
			small_regions.append(region)

	# 머리카락 가닥 사이 같은 작은 순백 틈은 배경 가까이에 있을 때만 지운다 (눈의 하이라이트는 남긴다)
	var near := _grow(bg, NEAR_BG, w)
	for region in small_regions:
		for i in region:
			if near[i]:
				for j in region:
					bg[j] = 1
				break

	# 배경에서 EDGE_BAND 픽셀 안쪽까지를 테두리로 본다
	var band := _grow(bg, EDGE_BAND, w)

	var src := data.duplicate()
	var cleared := 0
	for i in n:
		if bg[i]:
			data[i * 4 + 3] = 0
			cleared += 1
		elif band[i]:
			# 테두리가 아닌 가장 가까운 픽셀을 안쪽 색으로 본다 (같은 거리면 더 진한 쪽)
			var x := i % w
			var y := i / w
			var inner := -1
			var best := 0
			for dy in range(-INNER_SEARCH, INNER_SEARCH + 1):
				for dx in range(-INNER_SEARCH, INNER_SEARCH + 1):
					var px := x + dx
					var py := y + dy
					if px < 0 or py < 0 or px >= w or py >= h:
						continue
					var j := py * w + px
					var d := dx * dx + dy * dy
					if not band[j] and (inner < 0 or d < best or (d == best and low[j] < low[inner])):
						inner = j
						best = d
			# 안쪽 색을 못 찾은 가는 선은 검은색과 섞였다고 본다
			var inner_low := low[inner] if inner >= 0 else 0.0
			var a := clampf((1.0 - low[i]) / maxf(1.0 - inner_low, 0.05), 0.0, 1.0)
			if a < 1.0:
				for c in 3:
					if inner >= 0:
						data[i * 4 + c] = src[inner * 4 + c]
					else:
						var v := src[i * 4 + c] / 255.0
						data[i * 4 + c] = roundi(clampf((v - (1.0 - a)) / maxf(a, 0.01), 0.0, 1.0) * 255.0)
				data[i * 4 + 3] = roundi(src[i * 4 + 3] * a)
	Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data).save_png(path)
	print("%s cleared %d%%" % [path.get_file(), roundi(100.0 * cleared / n)])


## mask 를 상하좌우로 steps 픽셀만큼 넓힌다
func _grow(mask: PackedByteArray, steps: int, w: int) -> PackedByteArray:
	var n := mask.size()
	var out := mask.duplicate()
	for step in steps:
		var grown := out.duplicate()
		for i in n:
			if out[i]:
				continue
			var x := i % w
			if (x > 0 and out[i - 1]) or (x < w - 1 and out[i + 1]) \
					or (i >= w and out[i - w]) or (i + w < n and out[i + w]):
				grown[i] = 1
		out = grown
	return out
