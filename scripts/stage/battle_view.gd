# 전투 화면 그리기와 맵 터치 입력 (직원 선택, 끌어다 놓아 승진).
# 바닥/책상은 이 노드가 한 번만 그리고, 움직이는 것은 자식 레이어가 매 프레임 그린다.
class_name BattleView
extends Node2D

const FRAME := 128
const EFFECT_FPS := 20.0
const EFFECT_MAX_FRAMES := 25

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
var _textures := {}       # path -> Texture2D
var _frame_counts := {}   # sheet path -> 프레임 수
var _boxes := {}          # 스타일박스 캐시
var _path_cells := {}     # Vector2i -> true

# 연출 (게임 시간 기준으로 움직이고, 일시정지하면 멈춘다)
var _fx: Array = []       # 파티클/고리/글자 {kind, pos, vel, age, life, size, color, rot, spin, text}
var _dmg := {}            # Enemy -> [모인 피해, 마법 비율 합, 타이머] 데미지 숫자를 0.25초씩 모아서 띄운다
var _shake := 0.0
var _red_flash := 0.0

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
	for row in battle.map.size():
		for col in battle.map[row].size():
			var v := float(battle.map[row][col])
			if v >= 1.0 and v != StageDefs.BOSS_ROOM:
				_path_cells[Vector2i(col, row)] = true
	_dyn = Node2D.new()
	add_child(_dyn)
	_dyn.draw.connect(_draw_dynamic)
	battle.enemy_spawned.connect(_on_enemy_spawned)
	battle.enemy_damaged.connect(_on_enemy_damaged)
	battle.enemy_died.connect(_on_enemy_died)
	battle.enemy_escaped.connect(_on_enemy_escaped)
	battle.enemy_ability.connect(_on_enemy_ability)
	battle.enemy_split.connect(_on_enemy_split)
	battle.tower_placed.connect(_on_tower_placed)
	battle.tower_attacked.connect(_on_tower_attacked)
	battle.skill_cast.connect(_on_skill_cast)
	battle.projectile_hit.connect(_on_projectile_hit)
	queue_redraw()


func _process(delta: float) -> void:
	var dt := 0.0 if battle.paused else delta * battle.speed
	_update_fx(dt)
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
	# 서서히 사라지는 연출이 프레임마다 새 박스를 만들지 않도록 색을 단계로 끊는다
	color = Color(snappedf(color.r, 0.025), snappedf(color.g, 0.025), snappedf(color.b, 0.025), snappedf(color.a, 0.05))
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
	ci.draw_string_outline(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, 0.75 * color.a))
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
	# 보스방: 붉은 카펫을 깐 회의실
	if battle.has_boss_room:
		var room := Rect2(battle.boss_cells[0].x * c, battle.boss_cells[0].y * c, 0, 0)
		for cell: Vector2i in battle.boss_cells:
			room = room.merge(Rect2(cell.x * c, cell.y * c, c, c))
		room = room.grow(-c * 0.06)
		_rounded(room, Color("5a2430"), 14)
		_rounded(room.grow(-c * 0.12), Color("7a3040"), 10)
		_outline(room, Color(UI.DANGER, 0.7), 14, 3)
		_text(room.get_center() + Vector2(0, c * 0.62), "보스방", int(c * 0.26), Color(1, 0.8, 0.8, 0.8))


# ------------------------------------------------------------------ 동적 레이어

func _draw_dynamic() -> void:
	ci = _dyn
	_draw_flow()
	if battle.selected:
		_draw_range(battle.selected)
	for t: Tower in battle.towers:
		_draw_tower(t)
	# 끌고 있거나 선택한 직원과 합칠 수 있는 직원을 금색으로 표시
	if _dragging and _press_tower:
		_draw_merge_targets(_press_tower)
	elif battle.selected:
		_draw_merge_targets(battle.selected)
	for e: Enemy in battle.enemies:
		_draw_enemy(e)
	for p in battle.projectiles:
		_draw_projectile(p)
	for fx in battle.effects:
		_draw_effect(fx)
	_draw_fx()
	if _red_flash > 0:
		ci.draw_rect(Rect2(0, 0, map_size, map_size), Color(UI.DANGER, 0.28 * _red_flash))
	if _dragging and _press_tower:
		_draw_drag()


## 통로 위를 흐르는 작은 화살표로 적의 진행 방향을 보여 준다
func _draw_flow() -> void:
	var path := battle.path
	var spacing := battle.cell * 0.9
	var offset := fmod(Time.get_ticks_msec() / 1000.0 * battle.cell * 0.8, spacing)
	var s := battle.cell * 0.12
	# 고리 맵은 마지막 경유지에서 처음으로 돌아가는 구간까지 그린다
	var segments := path.size() if battle.loop else path.size() - 1
	for i in segments:
		var a: Vector2 = path[i]
		var b: Vector2 = path[(i + 1) % path.size()]
		var length := a.distance_to(b)
		var dir := (b - a) / length
		var side := Vector2(-dir.y, dir.x)
		var d := offset
		while d < length:
			var p := a + dir * d
			ci.draw_colored_polygon(PackedVector2Array([p + dir * s, p - dir * s * 0.6 + side * s, p - dir * s * 0.6 - side * s]), FLOW)
			d += spacing
	_draw_marker(path[0], UI.SUCCESS, "입구")
	if not battle.loop:
		_draw_marker(path[path.size() - 1], UI.DANGER, "출구")


func _draw_marker(at: Vector2, color: Color, text: String) -> void:
	var c := battle.cell
	ci.draw_circle(at, c * 0.42, Color(color, 0.25))
	ci.draw_arc(at, c * 0.42, 0, TAU, 32, color, 3, true)
	_text(at, text, int(c * 0.28))


func _draw_merge_targets(src: Tower) -> void:
	var c := battle.cell
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
	for t: Tower in battle.towers:
		if src.can_merge_with(t):
			var r := Rect2(t.cell.x * c, t.cell.y * c, c, c).grow(-1)
			_outline(r, Color(UI.GOLD, 0.6 + 0.4 * pulse), 12, 5)


func _draw_range(t: Tower) -> void:
	var color: Color = GameData.TEAM_COLORS[t.team]
	ci.draw_circle(t.center(), t.range_px, Color(color, 0.12))
	ci.draw_arc(t.center(), t.range_px, 0, TAU, 64, Color(color, 0.8), 3, true)


func _draw_tower(t: Tower) -> void:
	var c := battle.cell
	var base := Vector2(t.cell.x * c, t.cell.y * c)
	var center_x := base.x + c / 2
	var portrait := tex(GameData.asset(t.data.towerImagePath))
	var team_color: Color = GameData.TEAM_COLORS[t.team]
	var grade_color := GameData.grade_color(t.grade)
	# 책상 윗면을 팀 색으로 칠하고, 2등급부터는 등급 색 테두리 (멀리서도 팀/등급이 보이게)
	var m := c * 0.1
	var top := Rect2(base.x + m, base.y + m, c - m * 2, c - m * 2 - c * 0.08)
	_rounded(top, Color(team_color, 0.55), 10)
	if t.grade >= 2:
		_outline(top.grow(1), grade_color, 10, 3 + t.grade / 2)
	var alpha := 0.35 if (_dragging and _press_tower == t) else 1.0
	var shade := 0.55 if t.stun_left > 0 else 1.0  # 통화 중이면 어둡게
	# 공격하는 동안 대상 쪽으로 살짝 몸을 내민다
	var progress := t.attack_progress()
	var lunge := Vector2.ZERO
	if progress >= 0 and t.target != null and not t.target.dead:
		lunge = (t.target.pos - t.center()).normalized() * c * 0.07 * sin(progress * PI)
	# 전신 대신 얼굴 토큰: 직원이 많아져도 누가 누군지 얼굴로 알아보게
	var radius := c * 0.36 * (1.0 + 0.25 * t.spawn_anim)
	var at := Vector2(center_x, base.y + c * 0.45) + lunge
	ci.draw_circle(at + Vector2(0, c * 0.04), radius + 3, Color(0, 0, 0, 0.35 * alpha))
	ci.draw_circle(at, radius + 2, Color(team_color.darkened(0.45), alpha))
	_draw_face(t.id, portrait, at, radius - 1, Color(shade, shade, shade, alpha))
	ci.draw_arc(at, radius, 0, TAU, 32, Color(team_color, alpha), 4, true)
	if t.buff_glow > 0:
		ci.draw_arc(at, radius + 5, 0, TAU, 32, Color(UI.GOLD, 0.7), 3, true)
	if t.stun_left > 0:
		_rounded(Rect2(center_x - c * 0.36, base.y + c * 0.04, c * 0.72, c * 0.24), Color(0, 0, 0, 0.65), 8)
		_text(Vector2(center_x, base.y + c * 0.16), "통화 중", 17, UI.WARN)
	# 공격 모션은 오른쪽 위에 팀마다 다른 모양으로
	if progress >= 0:
		_draw_attack_motion(t, Vector2(base.x + c * 0.8, base.y + c * 0.12), progress)
	# 등급 배지: 왼쪽 아래 등급 색 동그라미에 숫자
	var badge := Vector2(base.x + c * 0.2, base.y + c * 0.78)
	ci.draw_circle(badge, c * 0.15, Color(0.08, 0.06, 0.12, 0.85))
	ci.draw_circle(badge, c * 0.12, grade_color)
	_text(badge, str(t.grade), int(c * 0.22))
	if battle.selected == t:
		_outline(Rect2(base, Vector2(c, c)).grow(-2), UI.TEXT, 12, 3)


## 직원 그림(350x512)에서 얼굴이 있는 곳: [가운데 x, 머리 꼭대기 y]. 여기서 190px 정사각형을 잘라 쓴다
const FACE_CROPS := {
	"dv1": [161, 24], "dv2": [218, 24], "dv3": [171, 28], "dv4": [173, 26], "dv5_1": [171, 26], "dv5_2": [176, 190],
	"hr1": [180, 22], "hr2": [170, 14], "hr3": [170, 28], "hr4": [168, 20], "hr5_1": [171, 30], "hr5_2": [175, 18],
	"sl1": [173, 22], "sl2": [173, 16], "sl3": [169, 22], "sl4": [176, 14], "sl5_1": [173, 14], "sl5_2": [212, 12],
}
const FACE_SIZE := 190.0
var _circle := PackedVector2Array()  # 반지름 1 짜리 원 꼭짓점 (얼굴 토큰용)


## 직원 얼굴을 at 을 중심으로 반지름 radius 인 원 안에 그린다
func _draw_face(tower_id: String, portrait: Texture2D, at: Vector2, radius: float, modulate: Color) -> void:
	if _circle.is_empty():
		for i in 28:
			_circle.append(Vector2.from_angle(i * TAU / 28))
	var crop: Array = FACE_CROPS.get(tower_id.trim_prefix("tower_"), [175, 20])
	var size := portrait.get_size()
	var origin := Vector2(crop[0] - FACE_SIZE / 2, crop[1] - 8)
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for p in _circle:
		points.append(at + p * radius)
		uvs.append((origin + (p * 0.5 + Vector2(0.5, 0.5)) * FACE_SIZE) / size)
	ci.draw_polygon(points, PackedColorArray([modulate]), uvs, portrait)


## 개발팀: 코드 기호가 튀어나옴, 인사팀: 도장을 쾅, 영업팀: 서류가방 휘두르기
func _draw_attack_motion(t: Tower, at: Vector2, progress: float) -> void:
	var c := battle.cell
	var k := sin(progress * PI)  # 0 → 1 → 0
	var color: Color = GameData.TEAM_COLORS[t.team].lightened(0.35)
	var grow := 1.0 + 0.1 * (t.grade - 1)
	match t.team:
		"dv":
			_text(at + Vector2(0, -c * 0.12 * k), "</>", int(18 * grow * (0.7 + 0.3 * k)), Color(color, k))
		"hr":
			var drop := c * 0.14 * (1.0 - k)
			var disc := at + Vector2(0, -drop)
			_rounded(Rect2(disc + Vector2(-c * 0.05, -c * 0.2), Vector2(c * 0.1, c * 0.14)), Color(0.45, 0.3, 0.2, k), 4)
			_ellipse(disc, c * 0.11 * grow, 0.45, Color(0.85, 0.15, 0.15, k))
			if progress > 0.4:
				_ellipse(at + Vector2(0, c * 0.04), c * 0.14 * grow * k, 0.4, Color(0.9, 0.2, 0.2, 0.35 * k))
		_:
			var a := lerpf(-PI * 0.9, -PI * 0.1, progress)
			var hand := at + Vector2(-c * 0.15, c * 0.1)
			var tip := hand + Vector2(cos(a), sin(a)) * c * 0.28
			ci.draw_arc(hand, c * 0.28, -PI * 0.9, a, 12, Color(color, 0.5 * k), 4, true)
			_rounded(Rect2(tip - Vector2(c * 0.09, c * 0.07) * grow, Vector2(c * 0.18, c * 0.14) * grow), Color(0.55, 0.32, 0.18, k), 3)


func _draw_enemy(e: Enemy) -> void:
	var s := e.size
	var p := e.pos + Vector2(0, e.bob_offset())
	_ellipse(e.pos + Vector2(0, s * 0.42), s * 0.45, 0.3, Color(0, 0, 0, 0.3))
	var mod := Color.WHITE
	if e.slow_left > 0:
		mod = mod.lerp(Color(0.5, 0.7, 1.0), 0.6)
	if e.stun_left > 0:
		mod = mod.darkened(0.4)
	if e.hit_flash > 0:
		mod = mod.lerp(Color(2, 2, 2), 0.5)
	# 보스방 보스가 버티는 동안 공격할 수 없는 적은 흐리게
	if battle.boss_blocking and not e.anchored:
		mod = Color(mod.darkened(0.3), 0.45)
	# 전화기는 벨이 울리기 직전에 부르르 떤다
	if e.type.has("ring") and e.ability_timer < 0.8 and e.stun_left <= 0:
		p.x += sin(Time.get_ticks_msec() / 18.0) * s * 0.05
	var h := s * _enemy_tex.get_height() / _enemy_tex.get_width()
	# 맞으면 납작하게 눌렸다가 돌아온다
	var squash := e.hit_flash / 0.12
	var sw := s * (1.0 + 0.12 * squash)
	var sh := h * (1.0 - 0.12 * squash)
	_draw_enemy_body(e.type_id, Rect2(p.x - sw / 2, p.y + h / 2 - sh, sw, sh), mod, e)
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
	if e.hp_trail > e.hp_ratio():
		_rounded(Rect2(bar.position, Vector2(bar.size.x * e.hp_trail, bar.size.y)), Color(1, 1, 1, 0.75), 3)
	if e.hp_ratio() > 0:
		var fill := UI.WARN if e.is_boss() else (UI.SUCCESS if e.hp_ratio() > 0.5 else UI.DANGER)
		_rounded(Rect2(bar.position, Vector2(bar.size.x * e.hp_ratio(), bar.size.y)), fill, 3)
	# 보호막은 체력바 바로 위에 하늘색 띠로
	if e.shield > 0:
		var sbar := Rect2(bar.position - Vector2(0, 6), Vector2(bar.size.x * e.shield_ratio(), 4))
		_rounded(sbar.grow(1), Color(0, 0, 0, 0.6), 3)
		_rounded(sbar, SHIELD, 2)


const SHIELD := Color("7fdcff")
## 그림이 있는 적 (프린터 계열). 나머지는 도형으로 그린다
const SPRITE_ENEMIES := ["printer", "fax", "copier", "server", "boss"]


## r 은 몸통이 들어갈 칸 (아래쪽이 바닥). e 가 null 이면 잔상처럼 몸통만 그린다
func _draw_enemy_body(type_id: String, r: Rect2, mod: Color, e: Enemy = null) -> void:
	if type_id in SPRITE_ENEMIES:
		ci.draw_texture_rect(_enemy_tex, r, false, StageDefs.ENEMIES[type_id].tint * mod)
		return
	var w := r.size.x
	var hh := r.size.y
	var cx := r.get_center().x
	var foot := r.end.y
	var now := Time.get_ticks_msec()
	match type_id:
		"parcel", "parcel_mini":
			var box := Rect2(r.position.x + w * 0.08, foot - hh * 0.78, w * 0.84, hh * 0.78)
			_rounded(box, Color("b07a45") * mod, 5)
			_rounded(Rect2(box.position, Vector2(box.size.x, box.size.y * 0.24)), Color("c9915a") * mod, 5)
			ci.draw_rect(Rect2(cx - w * 0.07, box.position.y, w * 0.14, box.size.y), Color("e8d3a8") * mod)
			ci.draw_rect(Rect2(box.position.x + box.size.x * 0.62, box.end.y - box.size.y * 0.36, box.size.x * 0.26, box.size.y * 0.2), Color(1, 1, 1, 0.9) * mod)
			_outline(box, Color(0.3, 0.18, 0.08, 0.8) * mod, 5, 2)
		"water":
			# 위: 물통, 아래: 본체와 꼭지 두 개
			var bottle := Rect2(cx - w * 0.26, r.position.y + hh * 0.02, w * 0.52, hh * 0.42)
			_rounded(bottle, Color(0.65, 0.85, 1, 0.75) * mod, 10)
			var level := 0.35 + 0.1 * sin(now / 300.0)
			_rounded(Rect2(bottle.position.x, bottle.position.y + bottle.size.y * level, bottle.size.x, bottle.size.y * (1.0 - level)), Color(0.3, 0.6, 1, 0.85) * mod, 10)
			ci.draw_rect(Rect2(cx - w * 0.1, bottle.end.y, w * 0.2, hh * 0.05), Color(0.55, 0.75, 0.95) * mod)
			var body := Rect2(cx - w * 0.38, foot - hh * 0.52, w * 0.76, hh * 0.52)
			_rounded(body, Color(0.93, 0.95, 0.98) * mod, 6)
			_rounded(Rect2(body.position.x + w * 0.12, body.position.y + hh * 0.08, w * 0.12, hh * 0.1), Color(0.3, 0.55, 1) * mod, 3)
			_rounded(Rect2(body.end.x - w * 0.24, body.position.y + hh * 0.08, w * 0.12, hh * 0.1), Color(1, 0.35, 0.3) * mod, 3)
			_rounded(Rect2(body.position.x + w * 0.1, body.end.y - hh * 0.16, body.size.x - w * 0.2, hh * 0.08), Color(0.35, 0.38, 0.45) * mod, 3)
			_outline(body, Color(0.4, 0.45, 0.55, 0.8) * mod, 6, 2)
			if e != null and e.ability_flash > 0:
				ci.draw_circle(r.get_center(), w * 0.65, Color(UI.SUCCESS, 0.25 * e.ability_flash / 0.6))
		"vacuum":
			var center := Vector2(cx, foot - hh * 0.3)
			_ellipse(center + Vector2(0, hh * 0.08), w * 0.5, 0.42, Color(0.18, 0.19, 0.23) * mod)
			_ellipse(center, w * 0.5, 0.42, Color(0.38, 0.4, 0.47) * mod)
			_ellipse(center + Vector2(0, -hh * 0.02), w * 0.36, 0.42, Color(0.55, 0.58, 0.66) * mod)
			var blink := 1.0 if (now / 250) % 2 == 0 else 0.35
			ci.draw_circle(center + Vector2(0, -hh * 0.05), w * 0.06, Color(0.3, 1, 0.9, blink) * mod)
			# 앞쪽 솔이 빙글빙글 돈다
			var brush := center + Vector2(-w * 0.38, hh * 0.1)
			for i in 3:
				var a := now / 60.0 + i * TAU / 3
				ci.draw_line(brush, brush + Vector2(cos(a), sin(a) * 0.45) * w * 0.2, Color(0.9, 0.9, 0.95) * mod, 2, true)
		"laptop":
			var screen := Rect2(cx - w * 0.36, r.position.y + hh * 0.08, w * 0.72, hh * 0.56)
			_rounded(screen, Color(0.2, 0.22, 0.27) * mod, 5)
			var inner := screen.grow(-w * 0.05)
			_rounded(inner, Color(0.25, 0.55, 0.9) * mod, 3)
			for i in 3:  # 화면 속 엑셀 줄
				var y := inner.position.y + inner.size.y * (0.25 + i * 0.25)
				ci.draw_line(Vector2(inner.position.x + 4, y), Vector2(inner.end.x - 4 - i * 6, y), Color(1, 1, 1, 0.55) * mod, 2)
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(screen.position.x, screen.end.y), Vector2(screen.end.x, screen.end.y),
				Vector2(cx + w * 0.48, foot - hh * 0.06), Vector2(cx - w * 0.48, foot - hh * 0.06)]), Color(0.75, 0.78, 0.83) * mod)
			ci.draw_rect(Rect2(cx - w * 0.48, foot - hh * 0.08, w * 0.96, hh * 0.08), Color(0.55, 0.58, 0.64) * mod)
			if e != null and e.shield > 0:
				var a := e.shield_ratio()
				var radius := w * 0.68 * (0.92 + 0.08 * sin(now / 200.0))
				ci.draw_circle(r.get_center(), radius, Color(SHIELD, 0.16 * a))
				ci.draw_arc(r.get_center(), radius, 0, TAU, 32, Color(SHIELD, 0.7 * a), 2.5, true)
		"phone":
			var ringing := e != null and e.ability_flash > 0
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(cx - w * 0.3, foot - hh * 0.62), Vector2(cx + w * 0.3, foot - hh * 0.62),
				Vector2(cx + w * 0.44, foot), Vector2(cx - w * 0.44, foot)]), Color(0.82, 0.3, 0.26) * mod)
			for row in 3:
				for col in 3:
					var k := Vector2(cx + (col - 1) * w * 0.15, foot - hh * (0.42 - row * 0.12))
					ci.draw_rect(Rect2(k - Vector2(w, hh) * 0.045, Vector2(w, hh) * 0.09), Color(1, 0.92, 0.85) * mod)
			# 수화기: 울리면 들썩인다
			var lift := hh * 0.12 * absf(sin(now / 40.0)) if ringing else 0.0
			var hs := Rect2(cx - w * 0.46, foot - hh * 0.82 - lift, w * 0.92, hh * 0.18)
			var handset := Color(0.62, 0.2, 0.18) * mod
			_rounded(hs, handset, 8)
			_rounded(Rect2(hs.position.x, hs.position.y - hh * 0.04, w * 0.24, hh * 0.24), handset, 8)
			_rounded(Rect2(hs.end.x - w * 0.24, hs.position.y - hh * 0.04, w * 0.24, hh * 0.24), handset, 8)
			if ringing:
				var t := 1.0 - e.ability_flash / 0.6
				for side in [-1.0, 1.0]:
					var from := -PI / 4 if side > 0 else PI * 0.75
					for i in 2:
						ci.draw_arc(r.get_center() + Vector2(side * w * 0.3, -hh * 0.2), w * (0.35 + i * 0.18 + t * 0.2),
								from, from + PI / 2, 8, Color(UI.WARN, 1.0 - t), 3, true)


func _draw_projectile(p: Dictionary) -> void:
	var s: float = p.size
	var r := Rect2(p.pos - Vector2(s, s) / 2, Vector2(s, s))
	# 날아온 방향으로 꼬리를 그린다
	var dir: Vector2 = p.dir
	var side := Vector2(-dir.y, dir.x) * s * 0.22
	var tail: Vector2 = p.pos - dir * s * 1.6
	var trail_color := Color(0.7, 0.85, 1, 0.5)
	if p.sheet == null:
		trail_color = {"dv": Color(0.4, 0.85, 1, 0.45), "hr": Color(1, 0.5, 0.5, 0.45)}.get(p.team, Color(1, 0.95, 0.7, 0.55))
	ci.draw_colored_polygon(PackedVector2Array([p.pos + side, p.pos - side, tail]),
			trail_color)
	if p.sheet == null:
		var grow: float = 1.0 + 0.15 * (p.grade - 1)
		match p.team:
			"dv":  # 빛나는 코드 조각과 뒤에 흩날리는 픽셀
				for i in 3:
					var q: Vector2 = p.pos - dir * s * (0.5 + i * 0.45) + side * sin(p.age * 30.0 + i) * 0.8
					var qs := s * 0.22 * (1.0 - i * 0.25)
					ci.draw_rect(Rect2(q - Vector2(qs, qs) / 2, Vector2(qs, qs)), Color(0.45, 1, 0.85, 0.8 - i * 0.22))
				ci.draw_circle(p.pos, s * 0.42 * grow, Color(0.3, 0.75, 1, 0.35))
				ci.draw_circle(p.pos, s * 0.22 * grow, Color(0.85, 0.97, 1))
			"hr":  # 빙글빙글 도는 결재 도장
				ci.draw_circle(p.pos, s * 0.36 * grow, Color(0.85, 0.15, 0.15))
				ci.draw_arc(p.pos, s * 0.25 * grow, p.age * 14.0, p.age * 14.0 + PI * 1.5, 10, Color(1, 0.85, 0.85), 2.5, true)
			_:
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


# ------------------------------------------------------------------ 연출 (파티클, 데미지 숫자, 화면 흔들림)

const MAX_FX := 400
const DMG_PHYSICAL := Color("ffcf7a")
const DMG_MAGIC := Color("8fc8ff")


func _add_fx(kind: String, pos: Vector2, life: float, size: float, color: Color, vel := Vector2.ZERO, rot := 0.0, spin := 0.0, text := "") -> Dictionary:
	if _fx.size() >= MAX_FX:
		_fx.pop_front()
	var fx := {"kind": kind, "pos": pos, "vel": vel, "age": 0.0, "life": life, "size": size,
			"color": color, "rot": rot, "spin": spin, "text": text}
	_fx.append(fx)
	return fx


func _burst(kind: String, at: Vector2, count: int, speed: float, life: float, size: float, color: Color) -> void:
	for i in count:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * speed * randf_range(0.4, 1.0)
		_add_fx(kind, at, life * randf_range(0.7, 1.0), size * randf_range(0.7, 1.2), color, v, randf() * TAU, randf_range(-12, 12))


func _shake_screen(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _on_enemy_spawned(e: Enemy) -> void:
	if e.is_boss():
		_shake_screen(0.8)
		_red_flash = 0.6
		_add_fx("ring", e.pos, 0.8, battle.cell * 1.6, UI.DANGER)


func _on_enemy_damaged(e: Enemy, amount: float, magic_share: float) -> void:
	var entry: Array = _dmg.get(e, [0.0, 0.0, 0.0])
	entry[0] += amount
	entry[1] += amount * magic_share
	_dmg[e] = entry


func _on_enemy_died(e: Enemy) -> void:
	_flush_damage(e)
	var c := battle.cell
	# 사무기기가 터지며 종이가 흩날린다
	_burst("paper", e.pos, 10 if e.is_boss() else 6, c * 3.2, 0.9, c * 0.19, Color(0.96, 0.98, 1.0))
	_burst("spark", e.pos, 8, c * 2.4, 0.35, c * 0.09, e.type.tint.lerp(UI.GOLD, 0.5))
	_add_fx("ring", e.pos, 0.35, e.size * 0.9, Color(1, 1, 1, 0.9))
	_add_fx("ghost", e.pos, 0.22, e.size, Color.WHITE, Vector2.ZERO, 0.0, 0.0, e.type_id)
	if e.is_boss():
		_shake_screen(1.0)
		_burst("spark", e.pos, 24, c * 4.5, 0.7, c * 0.14, UI.GOLD)


func _on_enemy_escaped(e: Enemy) -> void:
	_dmg.erase(e)
	_shake_screen(1.0 if e.is_boss() else 0.55)
	_red_flash = 1.0
	_add_fx("ring", e.pos, 0.5, battle.cell * 1.2, UI.DANGER)


func _on_enemy_ability(e: Enemy) -> void:
	var c := battle.cell
	var radius: float = e.type.radius * c
	if e.type.has("heal"):
		_add_fx("ring", e.pos, 0.6, radius, UI.SUCCESS)
		for other: Enemy in battle.enemies:
			if other.pos.distance_to(e.pos) <= radius:
				_add_fx("text", other.pos + Vector2(0, -other.size * 0.5), 0.6, 24, UI.SUCCESS, Vector2(0, -c * 0.8), 0, 0, "+")
	elif e.type.has("ring"):
		_add_fx("ring", e.pos, 0.5, radius, UI.WARN)
		_add_fx("text", e.pos + Vector2(0, -e.size * 0.8), 0.8, 22, UI.WARN, Vector2(0, -c * 0.5), 0, 0, "따르릉!")
		for t: Tower in battle.towers:
			if t.stun_left > 0 and t.center().distance_to(e.pos) <= radius:
				_add_fx("ring", t.center(), 0.35, c * 0.7, UI.WARN)


func _on_enemy_split(parent: Enemy, _children: Array) -> void:
	# 상자가 터지며 골판지 조각이 흩어진다
	_burst("paper", parent.pos, 6, battle.cell * 2.6, 0.7, battle.cell * 0.16, Color("c9915a"))


func _on_tower_placed(t: Tower, promoted: bool) -> void:
	var c := battle.cell
	var at := t.center() + Vector2(0, c * 0.3)
	if promoted:
		var color := GameData.grade_color(t.grade)
		for i in 12:
			_add_fx("ray", t.center(), 0.55, c * randf_range(0.9, 1.4), color, Vector2.ZERO, i * TAU / 12 + randf() * 0.2)
		_add_fx("ring", t.center(), 0.6, c * 1.3, color)
		_add_fx("ring", t.center(), 0.4, c * 0.8, Color.WHITE)
		_burst("spark", t.center(), 16, c * 3.0, 0.6, c * 0.1, color.lightened(0.3))
		_shake_screen(0.3)
	else:
		# 책상에 착지하며 먼지가 인다
		_add_fx("ring", at, 0.35, c * 0.55, Color(1, 1, 1, 0.6))
		for i in 6:
			var dir := Vector2(randf_range(-1, 1), randf_range(-0.35, -0.05)).normalized()
			_add_fx("spark", at, 0.4, c * 0.08, Color(0.85, 0.78, 0.65, 0.8), dir * c * 1.6)


## 근접(영업팀): 금빛 휘두르기와 흩날리는 명함. 등급이 높을수록 크고 화려하게
func _on_tower_attacked(t: Tower, target: Enemy, melee: bool) -> void:
	if not melee:
		return
	var c := battle.cell
	var grow := 1.0 + 0.12 * (t.grade - 1)
	var dir := (target.pos - t.center()).angle()
	_add_fx("slash", target.pos, 0.2, c * 0.42 * grow, Color(1, 0.85, 0.4), Vector2.ZERO, dir)
	for i in 1 + t.grade / 2:
		var a := dir + randf_range(-1.0, 1.0)
		_add_fx("card", target.pos, 0.5, c * 0.16, Color.WHITE, Vector2(cos(a), sin(a) - 0.6) * c * 2.2, randf() * TAU, randf_range(-10, 10))
	if t.grade >= 4:
		_add_fx("ring", target.pos, 0.25, c * 0.5, Color(1, 0.85, 0.4, 0.8))


## 원거리 기본 공격이 맞았을 때 (개발팀: 픽셀이 튐, 인사팀: 도장 자국)
func _on_projectile_hit(p: Dictionary) -> void:
	if p.sheet != null:
		return
	var c := battle.cell
	var at: Vector2 = p.target.pos
	match p.team:
		"dv":
			for i in 2 + p.grade:
				var a := randf() * TAU
				_add_fx("pixel", at, 0.35, c * 0.08, [Color(0.45, 1, 0.85), Color(0.4, 0.75, 1)].pick_random(),
						Vector2(cos(a), sin(a)) * c * randf_range(1.2, 2.4), randf() * TAU, randf_range(-8, 8))
			if p.grade >= 4:
				_add_fx("ring", at, 0.25, c * 0.45, Color(0.4, 0.85, 1, 0.8))
		"hr":
			_add_fx("stamp", at + Vector2(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1)) * c, 0.45, c * (0.2 + 0.03 * p.grade),
					Color(0.9, 0.15, 0.15), Vector2.ZERO, randf_range(-0.4, 0.4), 0, "인")


# ------------------------------------------------------------------ 스킬 연출 (스킬마다 다르게)

func _enemies_near(at: Vector2, radius: float) -> Array:
	return battle.enemies.filter(func(e: Enemy): return not e.dead and e.pos.distance_to(at) <= radius)


func _on_skill_cast(t: Tower) -> void:
	var c := battle.cell
	var color: Color = GameData.TEAM_COLORS[t.team]
	var sk: Skill = t.skill
	var at := t.center()
	var target: Enemy = t.target if t.target != null and not t.target.dead else null
	_add_fx("ring", at, 0.4, c * 0.8, color.lightened(0.2))
	if t.grade >= 3:
		_add_fx("text", at + Vector2(0, -c * 0.55), 0.9, 22, color.lightened(0.45), Vector2(0, -c * 0.6), 0, 0, sk.name)
	match sk.id:
		"dv1":  # 디버깅: 엔터 쾅
			_add_fx("text", at + Vector2(0, c * 0.05), 0.6, 20, Color(0.6, 0.9, 1), Vector2(0, -c * 0.6), 0, 0, "Enter!")
		"dv2":  # 코드 실행: 초록 터미널 광선이 대상마다 뻗는다
			for e: Enemy in _enemies_near(at, sk.range_px):
				_add_fx("ray", at, 0.35, at.distance_to(e.pos), Color(0.4, 1, 0.5), Vector2.ZERO, (e.pos - at).angle())
			_add_fx("text", at + Vector2(0, c * 0.05), 0.6, 18, Color(0.4, 1, 0.5), Vector2(0, -c * 0.6), 0, 0, "> run")
		"dv3":  # 서버 안정화: 바닥에 파란 장판
			_add_fx("zone", at, maxf(0.6, sk.duration), sk.range_px, Color(0.3, 0.7, 1))
		"dv4":  # 알고리즘 창조: 선두 적을 레이저로 추적
			var leader: Enemy = null
			for e: Enemy in battle.enemies:
				if not e.dead and (leader == null or e.progress > leader.progress):
					leader = e
			if leader:
				var fx := _add_fx("beam", at, maxf(0.6, sk.duration), c * 0.1, Color(0.75, 0.4, 1))
				fx.to = leader
				_add_fx("cross", leader.pos, 0.6, c * 0.5, Color(0.75, 0.4, 1))
		"dv5_1":  # 코드 해석: 맵 전체에 0과 1이 쏟아진다
			_add_fx("flash", Vector2.ZERO, 0.4, 0, Color(0.3, 0.6, 1, 0.25))
			for i in 28:
				_add_fx("glyph", Vector2(randf() * map_size, randf_range(-0.3, 0.6) * map_size), 0.9, 22,
						Color(0.4, 0.9, 1), Vector2(0, c * randf_range(5, 8)), 0, 0, ["0", "1"].pick_random())
		"dv5_2":  # 해킹 방어: 모든 적을 조준
			_add_fx("flash", Vector2.ZERO, 0.4, 0, Color(1, 0.3, 0.3, 0.18))
			for e: Enemy in _enemies_near(at, INF):
				_add_fx("cross", e.pos, 0.7, c * 0.45, Color(1, 0.35, 0.35))
		"hr1":  # 커피 수혈: 직원들 머리 위로 김이 모락모락
			for ally: Tower in battle.towers:
				if ally.center().distance_to(at) <= sk.range_px:
					for i in 4:
						_add_fx("spark", ally.center() + Vector2(randf_range(-0.2, 0.2) * c, -c * 0.3), 0.9, c * 0.07,
								Color(0.95, 0.9, 0.85, 0.8), Vector2(randf_range(-0.2, 0.2), -1.0) * c * 1.5)
			_add_fx("text", at + Vector2(0, c * 0.05), 0.8, 20, Color(0.85, 0.6, 0.35), Vector2(0, -c * 0.5), 0, 0, "커피!")
		"hr2":  # 사무 지원: 적 방어력이 깎이는 보라 화살표
			for e: Enemy in _enemies_near(at, sk.range_px):
				_add_fx("arrow", e.pos + Vector2(0, -e.size * 0.5), 0.7, c * 0.2, Color(0.75, 0.45, 1), Vector2(0, c * 0.8))
		"hr3":  # 가십: 대상에게 말풍선
			if target:
				_add_fx("bubble", Vector2(target.pos.x, maxf(c * 0.35, target.pos.y - target.size * 0.9)), 1.0, 16, Color.WHITE, Vector2.ZERO, 0, 0, "소곤소곤")
		"hr4":  # 휴식 시간: 적 머리 위로 Zzz
			_add_fx("zone", at, 0.6, sk.range_px, Color(0.6, 0.6, 1))
			for e: Enemy in _enemies_near(at, sk.range_px):
				_add_fx("text", e.pos + Vector2(0, -e.size * 0.6), maxf(0.8, sk.duration), 20, Color(0.75, 0.85, 1), Vector2(c * 0.2, -c * 0.4), 0, 0, "Zzz")
		"hr5_1":  # 성과 압박: 가장 강한 직원에게 금빛 기운
			var strongest: Tower = null
			for ally: Tower in battle.towers:
				if strongest == null or ally.physical + ally.magic > strongest.physical + strongest.magic:
					strongest = ally
			if strongest:
				for i in 10:
					_add_fx("ray", strongest.center(), 0.6, c * 1.2, UI.GOLD, Vector2.ZERO, i * TAU / 10)
				_add_fx("text", strongest.center() + Vector2(0, c * 0.1), 0.9, 24, UI.GOLD, Vector2(0, -c * 0.4), 0, 0, "성과!!")
		"hr5_2":  # 복지 캠페인: 모든 직원에게서 하트가 피어난다
			_add_fx("flash", Vector2.ZERO, 0.5, 0, Color(1, 0.5, 0.7, 0.15))
			for ally: Tower in battle.towers:
				_add_fx("heart", ally.center() + Vector2(0, -c * 0.3), 1.0, c * 0.16, Color(1, 0.45, 0.6), Vector2(randf_range(-0.3, 0.3), -1.0) * c)
		"sl1":  # 콜드 콜: 강한 한 방
			if target:
				_add_fx("slash", target.pos, 0.3, c * 0.7, Color(1, 0.6, 0.2), Vector2.ZERO, (target.pos - at).angle())
				_add_fx("ring", target.pos, 0.35, c * 0.8, Color(1, 0.6, 0.2))
				_add_fx("text", target.pos + Vector2(0, -c * 0.4), 0.6, 28, Color(1, 0.6, 0.2), Vector2(0, -c), 0, 0, "쾅!")
				_shake_screen(0.3)
		"sl2":  # 가격 협상: 적마다 할인 가격표
			var label := "-%d%%" % roundi(sk.mult * 100)
			for e: Enemy in _enemies_near(at, sk.range_px):
				_add_fx("tag", e.pos + Vector2(0, -e.size * 0.7), 0.9, 15, Color(0.55, 0.8, 1), Vector2(0, -c * 0.4), randf_range(-0.3, 0.3), 0, label)
		"sl3":  # 판매 할당량: 동전 분수
			for i in 10:
				_add_fx("coin", at + Vector2(0, -c * 0.2), 0.9, c * 0.13, UI.GOLD, Vector2(randf_range(-1, 1), randf_range(-2.6, -1.6)) * c * 1.5, 0, randf_range(4, 10))
		"sl4":  # 프레젠테이션: 큰 충격파
			_add_fx("ring", at, 0.5, sk.range_px, Color(1, 0.8, 0.35))
			_add_fx("ring", at, 0.7, sk.range_px * 1.15, Color(1, 1, 1, 0.6))
			for i in 12:
				_add_fx("ray", at, 0.45, sk.range_px, Color(1, 0.85, 0.5), Vector2.ZERO, i * TAU / 12)
			_shake_screen(0.35)
		"sl5_1":  # 대형 계약: 대상에 계약 도장
			if target:
				_add_fx("stamp", target.pos, 0.9, c * 0.42, Color(0.9, 0.1, 0.1), Vector2.ZERO, -0.25, 0, "계약")
				_shake_screen(0.3)
		"sl5_2":  # VIP 접대: 금빛 꽃가루와 하트
			_add_fx("ring", at, 0.6, sk.range_px, UI.GOLD)
			for i in 14:
				var a := randf() * TAU
				_add_fx("card", at, 0.9, c * 0.12, [UI.GOLD, Color(1, 0.5, 0.7), Color(0.5, 0.85, 1)].pick_random(),
						Vector2(cos(a), sin(a) - 0.8) * c * 3.0, randf() * TAU, randf_range(-12, 12))
			for e: Enemy in _enemies_near(at, sk.range_px):
				_add_fx("heart", e.pos + Vector2(0, -e.size * 0.5), 0.8, c * 0.12, Color(1, 0.5, 0.7), Vector2(0, -c * 0.8))


func _flush_damage(e: Enemy) -> void:
	var entry = _dmg.get(e)
	_dmg.erase(e)
	if entry == null or entry[0] < 1.0:
		return
	var amount: float = entry[0]
	var color := DMG_MAGIC if entry[1] > amount * 0.5 else DMG_PHYSICAL
	# 최대 체력 대비 큰 한 방일수록 글자가 크다
	var size := int(lerpf(18, 32, clampf(amount / e.max_hp * 2.5, 0.0, 1.0)))
	var at := e.pos + Vector2(randf_range(-0.2, 0.2) * battle.cell, -e.size * 0.6)
	_add_fx("text", at, 0.65, size, color, Vector2(randf_range(-0.3, 0.3), -1.3) * battle.cell, 0, 0, str(roundi(amount)))


func _update_fx(dt: float) -> void:
	if dt <= 0:
		return
	for e in _dmg.keys():
		var entry: Array = _dmg[e]
		entry[2] += dt
		if entry[2] >= 0.25:
			_flush_damage(e)
	for e: Enemy in battle.enemies:
		e.hp_trail = move_toward(e.hp_trail, e.hp_ratio(), dt * 0.9) if e.hit_flash <= 0 else e.hp_trail
	for fx in _fx:
		fx.age += dt
		fx.pos += fx.vel * dt
		fx.rot += fx.spin * dt
		match fx.kind:
			"paper", "card":
				fx.vel = fx.vel * pow(0.12, dt) + Vector2(0, battle.cell * 4.0 * dt)
				fx.spin *= pow(0.4, dt)
			"coin":
				fx.vel += Vector2(0, battle.cell * 9.0 * dt)
			"spark", "text", "pixel", "arrow", "heart", "tag", "bubble":
				fx.vel *= pow(0.08, dt)
	_fx = _fx.filter(func(fx): return fx.age < fx.life)
	_shake = maxf(0.0, _shake - dt * 2.5)
	_red_flash = maxf(0.0, _red_flash - dt * 2.0)
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * _shake * battle.cell * 0.12


func _draw_fx() -> void:
	for fx in _fx:
		var t: float = fx.age / fx.life
		var color: Color = fx.color
		var s: float = fx.size
		match fx.kind:
			"spark":
				ci.draw_circle(fx.pos, s * (1.0 - t), Color(color, color.a * (1.0 - t * 0.5)))
			"paper":
				ci.draw_set_transform(fx.pos, fx.rot, Vector2(1, absf(cos(fx.rot * 1.7)) * 0.7 + 0.3))
				ci.draw_rect(Rect2(-s / 2, -s * 0.65, s, s * 1.3), Color(color, 1.0 - t * t))
				ci.draw_rect(Rect2(-s / 2, -s * 0.65, s, s * 1.3), Color(0.25, 0.3, 0.4, 0.85 * (1.0 - t * t)), false, 2.0)
				ci.draw_set_transform(Vector2.ZERO)
			"ring":
				var r := lerpf(s * 0.25, s, 1.0 - pow(1.0 - t, 3))
				ci.draw_arc(fx.pos, r, 0, TAU, 40, Color(color, color.a * (1.0 - t)), lerpf(8, 2, t), true)
			"ray":
				var dir := Vector2(cos(fx.rot), sin(fx.rot))
				var from: Vector2 = fx.pos + dir * s * 0.3 * t
				var to: Vector2 = fx.pos + dir * s * (0.35 + 0.65 * (1.0 - pow(1.0 - t, 2)))
				ci.draw_line(from, to, Color(color, 1.0 - t), lerpf(7, 1, t), true)
			"slash":
				var a: float = fx.rot
				var span := PI * 0.8
				var start := a - span / 2 + span * 0.3 * t
				ci.draw_arc(fx.pos, s, start, start + span * (0.4 + 0.6 * minf(1.0, t * 3)), 16,
						Color(color, 1.0 - t), lerpf(9, 3, t), true)
			"ghost":
				var gs := s * (1.0 + 0.6 * t)
				var gh := gs * _enemy_tex.get_height() / _enemy_tex.get_width()
				_draw_enemy_body(fx.text, Rect2(fx.pos - Vector2(gs, gh) / 2, Vector2(gs, gh)), Color(1.5, 1.5, 1.5, 0.8 * (1.0 - t)))
			"text", "glyph":
				var pop := 1.0 + 0.35 * maxf(0.0, 1.0 - t * 6)  # 나타날 때 살짝 커졌다가 줄어든다
				var c := Color(color, 1.0 - maxf(0.0, t - 0.55) / 0.45)
				_text(fx.pos, fx.text, int(s * pop), c)
			"pixel":
				ci.draw_set_transform(fx.pos, fx.rot)
				ci.draw_rect(Rect2(-s / 2, -s / 2, s, s), Color(color, 1.0 - t))
				ci.draw_set_transform(Vector2.ZERO)
			"card":  # 명함/꽃가루: 가로로 긴 종이에 색 띠
				ci.draw_set_transform(fx.pos, fx.rot, Vector2(1, absf(cos(fx.rot * 1.3)) * 0.7 + 0.3))
				ci.draw_rect(Rect2(-s * 0.7, -s * 0.42, s * 1.4, s * 0.84), Color(color, 1.0 - t * t))
				ci.draw_rect(Rect2(-s * 0.7, -s * 0.42, s * 0.3, s * 0.84), Color(UI.GOLD.darkened(0.2), 1.0 - t * t))
				ci.draw_set_transform(Vector2.ZERO)
			"coin":
				var squash := absf(cos(fx.age * fx.spin))
				ci.draw_set_transform(fx.pos, 0, Vector2(maxf(0.15, squash), 1))
				ci.draw_circle(Vector2.ZERO, s, Color(color.darkened(0.25), 1.0 - t * t))
				ci.draw_circle(Vector2.ZERO, s * 0.72, Color(color, 1.0 - t * t))
				ci.draw_set_transform(Vector2.ZERO)
			"stamp":  # 크게 찍혔다가 자리를 잡는 빨간 도장
				var k := 1.0 + 0.8 * maxf(0.0, 1.0 - t * 6)
				var a := 1.0 - maxf(0.0, t - 0.5) / 0.5
				ci.draw_set_transform(fx.pos, fx.rot)
				ci.draw_arc(Vector2.ZERO, s * k, 0, TAU, 28, Color(color, a), maxf(2.0, s * 0.14), true)
				ci.draw_set_transform(Vector2.ZERO)
				_text(fx.pos, fx.text, int(s * k * (0.9 if fx.text.length() == 1 else 0.6)), Color(color, a))
			"zone":  # 바닥 장판: 숨 쉬듯 밝아졌다 어두워진다
				var a := minf(1.0, minf(fx.age * 5.0, (fx.life - fx.age) * 3.0))
				var pulse := 0.75 + 0.25 * sin(fx.age * 9.0)
				ci.draw_circle(fx.pos, s, Color(color, 0.16 * a * pulse))
				ci.draw_arc(fx.pos, s, 0, TAU, 48, Color(color, 0.6 * a), 3, true)
				ci.draw_arc(fx.pos, s * fmod(fx.age * 0.8, 1.0), 0, TAU, 48, Color(color, 0.4 * a), 2, true)
			"beam":
				var to = fx.get("to")
				if to != null and not to.dead:
					fx.end = to.pos
				var end: Vector2 = fx.get("end", fx.pos)
				var a := minf(1.0, (fx.life - fx.age) * 3.0)
				var wobble := s * (0.8 + 0.4 * sin(fx.age * 40.0))
				ci.draw_line(fx.pos, end, Color(color, 0.35 * a), wobble * 2.2, true)
				ci.draw_line(fx.pos, end, Color(1, 1, 1, 0.9 * a), wobble * 0.6, true)
				ci.draw_circle(end, wobble * 1.4, Color(color, 0.6 * a))
			"cross":  # 조준선: 돌면서 좁혀진다
				var r := s * (1.4 - 0.6 * minf(1.0, t * 3))
				var a := 1.0 - t * t
				ci.draw_arc(fx.pos, r, 0, TAU, 28, Color(color, a), 2.5, true)
				for i in 4:
					var d := Vector2.from_angle(fx.age * 4.0 + i * PI / 2)
					ci.draw_line(fx.pos + d * r * 0.55, fx.pos + d * r * 1.25, Color(color, a), 2.5, true)
			"flash":
				ci.draw_rect(Rect2(0, 0, map_size, map_size), Color(color, color.a * (1.0 - t)))
			"arrow":
				var a := 1.0 - t
				ci.draw_colored_polygon(PackedVector2Array([fx.pos + Vector2(-s, -s * 0.2), fx.pos + Vector2(s, -s * 0.2), fx.pos + Vector2(0, s)]), Color(color, a))
				ci.draw_rect(Rect2(fx.pos + Vector2(-s * 0.35, -s), Vector2(s * 0.7, s * 0.85)), Color(color, a))
			"heart":
				var a := 1.0 - t * t
				var hs := s * (1.0 + 0.3 * maxf(0.0, 1.0 - t * 5))
				ci.draw_circle(fx.pos + Vector2(-hs * 0.5, 0), hs * 0.55, Color(color, a))
				ci.draw_circle(fx.pos + Vector2(hs * 0.5, 0), hs * 0.55, Color(color, a))
				ci.draw_colored_polygon(PackedVector2Array([fx.pos + Vector2(-hs * 1.02, hs * 0.15), fx.pos + Vector2(hs * 1.02, hs * 0.15), fx.pos + Vector2(0, hs * 1.2)]), Color(color, a))
			"bubble", "tag":  # 말풍선 / 가격표
				var a := 1.0 - maxf(0.0, t - 0.6) / 0.4
				var w := _font.get_string_size(fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(s)).x + s
				var box := Rect2(fx.pos - Vector2(w / 2, s * 0.8), Vector2(w, s * 1.6))
				ci.draw_set_transform(fx.pos, fx.rot)
				box.position -= fx.pos
				if fx.kind == "bubble":
					ci.draw_colored_polygon(PackedVector2Array([Vector2(-s * 0.3, s * 0.7), Vector2(s * 0.3, s * 0.7), Vector2(-s * 0.4, s * 1.4)]), Color(1, 1, 1, a))
				ci.draw_style_box(_box(Color(1, 1, 1, a) if fx.kind == "bubble" else Color(color, a), 8), box)
				ci.draw_set_transform(Vector2.ZERO)
				var ink := Color(0.25, 0.25, 0.35, a) if fx.kind == "bubble" else Color(0.1, 0.2, 0.35, a)
				var tw := _font.get_string_size(fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(s)).x
				ci.draw_string(_font, fx.pos + Vector2(-tw / 2, s * 0.35), fx.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(s), ink)


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
