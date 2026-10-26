# 전투 화면 그리기와 맵 터치 입력 (직원 선택, 끌어다 놓아 승진).
# 바닥/책상은 이 노드가 한 번만 그리고, 움직이는 것은 자식 레이어가 매 프레임 그린다.
class_name BattleView
extends Node2D

const FRAME := 128
const EFFECT_FPS := 20.0
const EFFECT_MAX_FRAMES := 25
const HIT_FRAMES := 60

const FLOOR := Color("2a3140")
const DESK_TOP := Color("b48d63")
const DESK_SIDE := Color("7b5b3d")
const LANE := Color("e9dfca")
const LANE_EDGE := Color(0, 0, 0, 0.35)
const FLOW := Color(0.45, 0.38, 0.3, 0.35)

var battle: Battle
var map_size: float
var ci: CanvasItem   # 지금 그리고 있는 레이어

var _dyn: Node2D
var _font: Font
var _bg: Texture2D
var _enemy_tex: Texture2D
var _bolt_tex: Texture2D
var _hit_tex := {}        # team -> 공격 모션 시트
var _textures := {}       # path -> Texture2D
var _frame_counts := {}   # sheet path -> 프레임 수
var _boxes := {}          # 스타일박스 캐시
var _path_cells := {}     # Vector2i -> true

var _press_tower: Tower
var _dragging := false
var _drag_pos := Vector2.ZERO
var _press_pos := Vector2.ZERO
var _hover_target: Tower


func setup(p_battle: Battle) -> void:
	battle = p_battle
	map_size = battle.cell * 10
	_font = load("res://fonts/Jua-Regular.ttf")
	_bg = load("res://assets/background/stage1.png")
	_enemy_tex = load("res://assets/enemy/printer.png")
	_bolt_tex = load("res://assets/tower/projectile.png")
	for team in GameData.TEAMS:
		_hit_tex[team] = load("res://assets/tower/%s/hit.png" % team)
	for row in battle.map.size():
		for col in battle.map[row].size():
			if float(battle.map[row][col]) >= 1.0:
				_path_cells[Vector2i(col, row)] = true
	_dyn = Node2D.new()
	add_child(_dyn)
	_dyn.draw.connect(_draw_dynamic)
	queue_redraw()


func _process(_delta: float) -> void:
	_dyn.queue_redraw()


func tex(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]


func _frame_count(sheet: String) -> int:
	if not _frame_counts.has(sheet):
		var t := tex(sheet)
		_frame_counts[sheet] = maxi(1, int(t.get_width() / FRAME) * int(t.get_height() / FRAME))
	return _frame_counts[sheet]


func _frame_rect(index: int, sheet_tex: Texture2D) -> Rect2:
	if sheet_tex.get_width() < FRAME:
		return Rect2(Vector2.ZERO, sheet_tex.get_size())
	var cols := int(sheet_tex.get_width() / FRAME)
	return Rect2((index % cols) * FRAME, (index / cols) * FRAME, FRAME, FRAME)


# ------------------------------------------------------------------ 도형 도우미

func _box(color: Color, radius: int, border := 0) -> StyleBoxFlat:
	var key := "%s|%d|%d" % [color.to_html(), radius, border]
	if not _boxes.has(key):
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(radius)
		sb.anti_aliasing = true
		if border > 0:
			sb.draw_center = false
			sb.border_color = color
			sb.set_border_width_all(border)
		else:
			sb.bg_color = color
		_boxes[key] = sb
	return _boxes[key]


func _rounded(r: Rect2, color: Color, radius := 10) -> void:
	ci.draw_style_box(_box(color, radius), r)


func _outline(r: Rect2, color: Color, radius := 10, width := 3) -> void:
	ci.draw_style_box(_box(color, radius, width), r)


func _ellipse(center: Vector2, radius: float, squash: float, color: Color) -> void:
	ci.draw_set_transform(center, 0, Vector2(1, squash))
	ci.draw_circle(Vector2.ZERO, radius, color)
	ci.draw_set_transform(Vector2.ZERO)


func _text(at: Vector2, text: String, size: int, color := Color.WHITE) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := at + Vector2(-w / 2, size * 0.35)
	ci.draw_string_outline(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, 0.75))
	ci.draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


# ------------------------------------------------------------------ 정적 레이어 (바닥, 통로, 책상)

func _draw() -> void:
	ci = self
	# 어두운 사무실 바닥 위에 회의실 사진을 아주 옅게 깐다 (스테이지마다 색조가 다르다)
	var tint: Color = battle.def.tint
	draw_rect(Rect2(0, 0, map_size, map_size), FLOOR * tint)
	var src_h := float(_bg.get_height())
	var src := Rect2((_bg.get_width() - src_h) / 2.0, 0, src_h, src_h)
	draw_texture_rect_region(_bg, Rect2(0, 0, map_size, map_size), src, Color(tint, 0.16))
	var c := battle.cell
	for cell: Vector2i in _path_cells:
		draw_rect(Rect2(cell.x * c, cell.y * c, c, c), LANE)
	# 통로 테두리: 통로가 아닌 쪽에만 선을 긋는다
	for cell: Vector2i in _path_cells:
		var x := cell.x * c
		var y := cell.y * c
		if not _path_cells.has(cell + Vector2i.UP):
			draw_line(Vector2(x, y), Vector2(x + c, y), LANE_EDGE, 3)
		if not _path_cells.has(cell + Vector2i.DOWN):
			draw_line(Vector2(x, y + c), Vector2(x + c, y + c), LANE_EDGE, 3)
		if not _path_cells.has(cell + Vector2i.LEFT):
			draw_line(Vector2(x, y), Vector2(x, y + c), LANE_EDGE, 3)
		if not _path_cells.has(cell + Vector2i.RIGHT):
			draw_line(Vector2(x + c, y), Vector2(x + c, y + c), LANE_EDGE, 3)
	# 책상: 그림자, 옆면, 윗면 순서로 그려 살짝 떠 보이게
	var m := c * 0.1
	for cell: Vector2i in battle.desk_cells:
		var r := Rect2(cell.x * c + m, cell.y * c + m, c - m * 2, c - m * 2)
		_rounded(Rect2(r.position + Vector2(0, c * 0.06), r.size), Color(0, 0, 0, 0.25))
		_rounded(r, DESK_SIDE)
		_rounded(Rect2(r.position, r.size - Vector2(0, c * 0.08)), DESK_TOP)


# ------------------------------------------------------------------ 동적 레이어

func _draw_dynamic() -> void:
	ci = _dyn
	_draw_flow()
	if _dragging and _press_tower:
		_draw_merge_targets()
	if battle.selected:
		_draw_range(battle.selected)
	for t: Tower in battle.towers:
		_draw_tower(t)
	for e: Enemy in battle.enemies:
		_draw_enemy(e)
	for p in battle.projectiles:
		_draw_projectile(p)
	for fx in battle.effects:
		_draw_effect(fx)
	if _dragging and _press_tower:
		_draw_drag()


## 통로 위를 흐르는 작은 화살표로 적의 진행 방향을 보여 준다
func _draw_flow() -> void:
	var path := battle.path
	var spacing := battle.cell * 0.9
	var offset := fmod(Time.get_ticks_msec() / 1000.0 * battle.cell * 0.8, spacing)
	var s := battle.cell * 0.12
	for i in path.size() - 1:
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var length := a.distance_to(b)
		var dir := (b - a) / length
		var side := Vector2(-dir.y, dir.x)
		var d := offset
		while d < length:
			var p := a + dir * d
			ci.draw_colored_polygon(PackedVector2Array([p + dir * s, p - dir * s * 0.6 + side * s, p - dir * s * 0.6 - side * s]), FLOW)
			d += spacing
	_draw_marker(path[0], UI.SUCCESS, "입구")
	_draw_marker(path[path.size() - 1], UI.DANGER, "출구")


func _draw_marker(at: Vector2, color: Color, text: String) -> void:
	var c := battle.cell
	ci.draw_circle(at, c * 0.42, Color(color, 0.25))
	ci.draw_arc(at, c * 0.42, 0, TAU, 32, color, 3, true)
	_text(at, text, int(c * 0.28))


func _draw_merge_targets() -> void:
	var c := battle.cell
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
	for t: Tower in battle.towers:
		if _press_tower.can_merge_with(t):
			var r := Rect2(t.cell.x * c, t.cell.y * c, c, c).grow(-2)
			_rounded(r, Color(UI.GOLD, 0.15 + 0.15 * pulse), 12)
			_outline(r, Color(UI.GOLD, 0.6 + 0.4 * pulse), 12, 4)


func _draw_range(t: Tower) -> void:
	var color: Color = GameData.TEAM_COLORS[t.team]
	ci.draw_circle(t.center(), t.range_px, Color(color, 0.12))
	ci.draw_arc(t.center(), t.range_px, 0, TAU, 64, Color(color, 0.8), 3, true)


func _draw_tower(t: Tower) -> void:
	var c := battle.cell
	var base := Vector2(t.cell.x * c, t.cell.y * c)
	var center_x := base.x + c / 2
	var foot := base.y + c * 0.86
	var portrait := tex(GameData.asset(t.data.towerImagePath))
	var h := c * 0.98 * (1.0 + 0.25 * t.spawn_anim)
	var w := h * portrait.get_width() / portrait.get_height()
	# 발밑에 팀 색 받침
	_ellipse(Vector2(center_x, foot), c * 0.36, 0.35, Color(GameData.TEAM_COLORS[t.team], 0.6))
	if t.buff_glow > 0:
		ci.draw_arc(Vector2(center_x, foot - c * 0.4), c * 0.46, 0, TAU, 32, Color(UI.GOLD, 0.55), 3, true)
	var alpha := 0.35 if (_dragging and _press_tower == t) else 1.0
	ci.draw_texture_rect(portrait, Rect2(center_x - w / 2, foot - h, w, h), false, Color(1, 1, 1, alpha))
	# 공격 모션은 오른쪽 위에 겹쳐 그린다
	var progress := t.attack_progress()
	if progress >= 0:
		var sheet: Texture2D = _hit_tex[t.team]
		var s := c * 0.5
		ci.draw_texture_rect_region(sheet, Rect2(base.x + c - s * 0.85, base.y - s * 0.1, s, s),
				_frame_rect(int(progress * HIT_FRAMES), sheet))
	# 등급 배지 (칸 수 = 등급)
	var badge := Rect2(base.x + c * 0.2, base.y + c * 0.85, c * 0.6, c * 0.1)
	_rounded(badge, Color(0, 0, 0, 0.6), 4)
	var pip_w := badge.size.x / GameData.MAX_GRADE
	var grade_color := GameData.grade_color(t.grade)
	for i in t.grade:
		_rounded(Rect2(badge.position.x + i * pip_w + 1, badge.position.y + 1, pip_w - 2, badge.size.y - 2), grade_color, 3)
	if battle.selected == t:
		_outline(Rect2(base, Vector2(c, c)).grow(-2), UI.TEXT, 12, 3)


func _draw_enemy(e: Enemy) -> void:
	var s := e.size
	var p := e.pos + Vector2(0, e.bob_offset())
	_ellipse(e.pos + Vector2(0, s * 0.42), s * 0.45, 0.3, Color(0, 0, 0, 0.3))
	var tint: Color = e.type.tint
	if e.slow_left > 0:
		tint = tint.lerp(Color(0.5, 0.7, 1.0), 0.6)
	if e.stun_left > 0:
		tint = tint.darkened(0.4)
	if e.hit_flash > 0:
		tint = tint.lerp(Color(2, 2, 2), 0.5)
	var h := s * _enemy_tex.get_height() / _enemy_tex.get_width()
	ci.draw_texture_rect(_enemy_tex, Rect2(p.x - s / 2, p.y - h / 2, s, h), false, tint)
	if e.stun_left > 0:
		var t := Time.get_ticks_msec() / 200.0
		for i in 3:
			var a := t + i * TAU / 3
			ci.draw_circle(p + Vector2(cos(a) * s * 0.35, -s * 0.55 + sin(a) * s * 0.1), s * 0.07, UI.GOLD)
	if e.is_boss():
		ci.draw_arc(p, s * 0.62, 0, TAU, 40, Color(UI.DANGER, 0.7), 3, true)
	# 체력바
	var bar_w := maxf(s * 0.9, battle.cell * 0.5)
	var bar := Rect2(p.x - bar_w / 2, p.y - h / 2 - 12, bar_w, 7)
	_rounded(bar.grow(1), Color(0, 0, 0, 0.7), 4)
	if e.hp_ratio() > 0:
		var fill := UI.WARN if e.is_boss() else (UI.SUCCESS if e.hp_ratio() > 0.5 else UI.DANGER)
		_rounded(Rect2(bar.position, Vector2(bar.size.x * e.hp_ratio(), bar.size.y)), fill, 3)


func _draw_projectile(p: Dictionary) -> void:
	var s: float = p.size
	var r := Rect2(p.pos - Vector2(s, s) / 2, Vector2(s, s))
	if p.sheet == null:
		ci.draw_texture_rect(_bolt_tex, r, false)
	else:
		var sheet := tex(p.sheet)
		ci.draw_texture_rect_region(sheet, r, _frame_rect(_frame_count(p.sheet) / 2, sheet))


func _draw_effect(fx: Dictionary) -> void:
	var sheet := tex(fx.sheet)
	var count := mini(EFFECT_MAX_FRAMES, _frame_count(fx.sheet))
	var index := int(fx.age * EFFECT_FPS) % count
	var s: float = fx.size
	var alpha := clampf((fx.life - fx.age) / 0.2, 0.0, 1.0)  # 끝날 때 살짝 사라지게
	ci.draw_texture_rect_region(sheet, Rect2(fx.pos - Vector2(s, s) / 2, Vector2(s, s)), _frame_rect(index, sheet), Color(1, 1, 1, alpha))


func _draw_drag() -> void:
	var portrait := tex(GameData.asset(_press_tower.data.towerImagePath))
	var h := battle.cell * 1.1
	var w := h * portrait.get_width() / portrait.get_height()
	var ring := UI.GOLD if _hover_target != null else Color(1, 1, 1, 0.6)
	ci.draw_circle(_drag_pos, battle.cell * 0.55, Color(ring, 0.18))
	ci.draw_arc(_drag_pos, battle.cell * 0.55, 0, TAU, 40, ring, 3, true)
	ci.draw_texture_rect(portrait, Rect2(_drag_pos.x - w / 2, _drag_pos.y - h * 0.75, w, h), false, Color(1, 1, 1, 0.9))


# ------------------------------------------------------------------ 입력

## 맵 영역(Control)의 gui_input 에 연결된다. 화면 Control 이 터치를 먼저 가져가므로
## _unhandled_input 으로는 받을 수 없다. 이 노드는 맵 영역의 (0, 0) 에 있어서 좌표가 같다.
func handle_input(event: InputEvent) -> void:
	if battle.finished or battle.paused:
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	var local: Vector2 = event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not Rect2(0, 0, map_size, map_size).has_point(local):
				return
			_press_pos = local
			_press_tower = battle.tower_at_cell(battle.cell_at(local))
			_dragging = false
			_hover_target = null
			if _press_tower == null:
				battle.select(null)
			get_viewport().set_input_as_handled()
		elif _press_tower != null:
			if _dragging:
				var other := battle.tower_at_cell(battle.cell_at(local))
				if _press_tower.can_merge_with(other):
					battle.merge(_press_tower, other)
			else:
				battle.select(null if battle.selected == _press_tower else _press_tower)
			_press_tower = null
			_dragging = false
			_hover_target = null
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _press_tower != null:
		_drag_pos = local
		if not _dragging and local.distance_to(_press_pos) > battle.cell * 0.25:
			_dragging = true
			battle.select(_press_tower)
		if _dragging:
			var other := battle.tower_at_cell(battle.cell_at(local))
			_hover_target = other if _press_tower.can_merge_with(other) else null
		get_viewport().set_input_as_handled()


## 자동 테스트용: 직원을 끌어다 다른 직원 위에 놓은 것과 같다
func simulate_drag(from: Tower, to: Tower) -> void:
	if from.can_merge_with(to):
		battle.merge(from, to)
