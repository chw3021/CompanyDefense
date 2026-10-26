# 스테이지 화면: 위쪽 HUD, 가운데 맵, 아래쪽 조작 패널.
extends Control

const MAP_CELL := 72.0
const CARD_MIN_HEIGHT := 230.0

var stage_id := 1
var battle: Battle
var view: BattleView

var _life_label: Label
var _coin_label: Label
var _wave_label: Label
var _speed_button: Button
var _wave_button: Button
var _hire_button: Button
var _map_area: Control
var _float_layer: Control
var _info_slot: Control
var _hint: Label
var _card: PanelContainer
var _upgrades: HBoxContainer
var _upgrade_labels := {}
var _upgrade_costs := {}
var _card_widgets := {}
var _pause_modal: Control
var _last_life := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	battle = Battle.new()
	battle.setup(stage_id, MAP_CELL)
	add_child(battle)
	_build()
	battle.hud_changed.connect(_refresh_hud)
	battle.message.connect(_show_message)
	battle.floating.connect(_show_floating)
	battle.tower_selected.connect(_on_tower_selected)
	battle.game_over.connect(_on_game_over)
	battle.wave_started.connect(_show_wave_banner)
	_last_life = battle.life
	_refresh_hud()
	_show_banner()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_toggle_pause()


# ------------------------------------------------------------------ 레이아웃

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := UI.vbox(0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(_build_hud())

	_map_area = Control.new()
	_map_area.custom_minimum_size = Vector2(MAP_CELL * 10, MAP_CELL * 10)
	_map_area.clip_contents = true
	root.add_child(_map_area)
	view = BattleView.new()
	_map_area.add_child(view)
	view.setup(battle)
	_map_area.gui_input.connect(view.handle_input)
	_float_layer = Control.new()
	_float_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_area.add_child(_float_layer)

	root.add_child(_build_panel())


func _safe_top() -> float:
	# 노치/상태바 영역만큼 HUD 를 내린다
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.y <= 0:
		return 0.0
	return safe.position.y * get_viewport_rect().size.y / screen.y


func _build_hud() -> Control:
	var hud := UI.panel(UI.PANEL, 0, 0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12 + int(_safe_top()))
	margin.add_theme_constant_override("margin_bottom", 12)
	hud.add_child(margin)
	var row := UI.hbox(10)
	margin.add_child(row)

	row.add_child(UI.icon("res://assets/icons/heart.png", 40))
	_life_label = UI.label("", 34)
	_life_label.custom_minimum_size.x = 50
	row.add_child(_life_label)
	row.add_child(UI.icon("res://assets/icons/coin.png", 40))
	_coin_label = UI.label("", 34, UI.GOLD)
	_coin_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_coin_label)
	_wave_label = UI.label("", 30)
	row.add_child(_wave_label)
	row.add_child(UI.spacer(8, false))

	var pause := UI.button("II", UI.CARD_HI, _toggle_pause, 28)
	pause.custom_minimum_size = Vector2(72, 64)
	row.add_child(pause)
	_speed_button = UI.button("", UI.CARD_HI, _toggle_speed, 28)
	_speed_button.custom_minimum_size = Vector2(72, 64)
	row.add_child(_speed_button)
	return hud


func _build_panel() -> Control:
	var panel := UI.panel(UI.PANEL, 0, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	var col := UI.vbox(12)
	margin.add_child(col)

	# 가운데: 직원 정보 카드 또는 안내 문구
	_info_slot = Control.new()
	_info_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_slot.clip_contents = true
	col.add_child(_info_slot)
	_hint = UI.label("직원을 누르면 정보를 볼 수 있어요\n같은 직원끼리 끌어다 놓으면 승진!", 26, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_info_slot.add_child(_hint)
	_card = _build_tower_card()
	_card.visible = false
	col.add_child(_card)

	# 팀 업그레이드
	_upgrades = UI.hbox(10)
	for team in GameData.TEAMS:
		_upgrades.add_child(_build_upgrade_card(team))
	col.add_child(_upgrades)

	# 직원 고용 / 웨이브 시작
	var actions := UI.hbox(12)
	_hire_button = UI.button("", UI.SUCCESS, battle.hire)
	_hire_button.custom_minimum_size.y = 112
	_hire_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hire_content := UI.hbox(14)
	hire_content.alignment = BoxContainer.ALIGNMENT_CENTER
	hire_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hire_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	hire_content.add_child(UI.icon("res://assets/icons/work.png", 64))
	var hire_text := UI.vbox(0)
	hire_text.alignment = BoxContainer.ALIGNMENT_CENTER
	hire_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hire_text.add_child(UI.label("직원 고용", 34))
	hire_text.add_child(UI.coin_row(str(Battle.SPAWN_COST), 26))
	hire_content.add_child(hire_text)
	_hire_button.add_child(hire_content)
	actions.add_child(_hire_button)

	_wave_button = UI.button("웨이브 시작", UI.DANGER, battle.start_wave, 34)
	_wave_button.icon = UI.play_icon()
	_wave_button.custom_minimum_size.y = 112
	_wave_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_wave_button)
	col.add_child(actions)
	return panel


func _build_upgrade_card(team: String) -> Button:
	var b := UI.button("", UI.CARD, func(): battle.upgrade_team(team))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 132
	var v := UI.vbox(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_child(UI.icon("res://assets/icons/%sup.png" % team, 54))
	var name_label := UI.label("", 26, GameData.TEAM_COLORS[team].lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(name_label)
	var cost := UI.coin_row("", 22)
	v.add_child(cost)
	b.add_child(v)
	_upgrade_labels[team] = name_label
	_upgrade_costs[team] = cost.get_node("Amount")
	return b


func _build_tower_card() -> PanelContainer:
	var card := UI.panel(UI.CARD, 20, 18)
	var v := UI.vbox(14)
	card.add_child(v)
	var top := UI.hbox(18)
	v.add_child(top)
	var portrait_bg := UI.panel(Color("0f1319"), 16, 6)
	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(96, 120)
	portrait_bg.add_child(portrait)
	top.add_child(portrait_bg)
	var text := UI.vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_label := UI.label("", 34)
	var grade_label := UI.label("", 22)
	var stats := UI.label("", 24, UI.MUTED)
	var skill := UI.label("", 24, Color("c9d4ff"))
	skill.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for l in [name_label, grade_label, stats, skill]:
		text.add_child(l)
	top.add_child(text)

	var row := UI.hbox(12)
	var sell := UI.button("", Color("a0604a"), func():
		if battle.selected:
			battle.sell(battle.selected), 28)
	var trade := UI.button("", Color("3b6ea5"), func():
		if battle.selected:
			battle.trade(battle.selected), 28)
	for b in [sell, trade]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 76
		row.add_child(b)
	sell.icon = load("res://assets/icons/walk_out.png")
	trade.icon = load("res://assets/icons/negociation.png")
	sell.expand_icon = false
	v.add_child(row)
	_card_widgets = {"portrait": portrait, "name": name_label, "grade": grade_label, "stats": stats,
			"skill": skill, "sell": sell, "trade": trade}
	return card


# ------------------------------------------------------------------ 갱신

func _refresh_hud() -> void:
	_life_label.text = str(battle.life)
	if battle.life < _last_life:
		_pulse(_life_label, UI.DANGER)
	_last_life = battle.life
	_coin_label.text = str(battle.coins)
	if battle.endless:
		_wave_label.text = "웨이브 %d" % battle.display_wave()
	else:
		_wave_label.text = "웨이브 %d/%d" % [battle.display_wave(), battle.wave_count()]
	_speed_button.text = "x%d" % int(battle.speed)
	var can_start := battle.can_start_wave()
	_wave_button.disabled = not can_start
	_wave_button.text = "웨이브 시작" if can_start else ("진행 중" if battle.wave_running else "종료")
	_hire_button.modulate.a = 1.0 if battle.coins >= Battle.SPAWN_COST else 0.6
	for team in GameData.TEAMS:
		_upgrade_labels[team].text = "%s Lv.%d" % [GameData.team_name(team), battle.team_level[team]]
		_upgrade_costs[team].text = str(battle.upgrade_cost(team))


func _process(_delta: float) -> void:
	# 공격 속도 버프 등으로 바뀌는 능력치를 카드에 계속 반영
	if _card.visible and battle.selected:
		_fill_stats(battle.selected)


func _on_tower_selected(t: Tower) -> void:
	_card.visible = t != null
	_hint.visible = t == null
	if t == null:
		_upgrades.visible = true
		return
	_card_widgets.portrait.texture = load(GameData.asset(t.data.towerImagePath))
	_card_widgets.name.text = t.name
	_card_widgets.grade.text = "%s팀  |  %s" % [GameData.team_name(t.team), GameData.GRADE_NAMES[t.grade - 1]]
	_card_widgets.grade.add_theme_color_override("font_color", GameData.grade_color(t.grade))
	_card_widgets.sell.text = "퇴사  +%d" % Battle.sell_price(t)
	_card_widgets.trade.text = "협상  -%d (30%%)" % Battle.trade_cost(t)
	_fill_stats(t)
	# 화면이 낮으면 팀 업그레이드 줄 자리에 카드를 보여 준다
	_upgrades.visible = _info_slot.size.y + _card.size.y >= CARD_MIN_HEIGHT * 2


func _fill_stats(t: Tower) -> void:
	_card_widgets.stats.text = "물리 %d  /  마법 %d  /  공속 %.1f" % [roundi(t.physical), roundi(t.magic), t.attack_speed]
	var ready := t.skill.ready_ratio()
	_card_widgets.skill.text = "스킬: %s%s" % [t.skill.name, "" if ready >= 1.0 else "  (%d%%)" % roundi(ready * 100)]


func _show_floating(text: String, at: Vector2, color: Color) -> void:
	var l := UI.outlined(text, 30, color, 8)
	_float_layer.add_child(l)
	l.reset_size()
	l.position = at - l.size / 2
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - MAP_CELL * 0.7, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _show_message(text: String, color: Color) -> void:
	var l := UI.outlined(text, 40, color, 10)
	_float_layer.add_child(l)
	l.reset_size()
	l.position = Vector2((MAP_CELL * 10 - l.size.x) / 2, MAP_CELL * 5 - l.size.y / 2)
	l.pivot_offset = l.size / 2
	l.scale = Vector2(0.6, 0.6)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.1)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


## 목숨이 줄면 숫자가 빨갛게 튀어 오른다
func _pulse(label: Label, color: Color) -> void:
	label.pivot_offset = label.size / 2
	label.add_theme_color_override("font_color", color)
	var tw := label.create_tween()
	tw.tween_property(label, "scale", Vector2(1.5, 1.5), 0.08)
	tw.tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): label.remove_theme_color_override("font_color"))


## 웨이브 시작: 띠가 옆에서 밀려 들어왔다가 빠진다. 보스 웨이브는 빨간 띠
func _show_wave_banner(index: int) -> void:
	var boss := battle.wave_has_boss(index)
	var band := UI.panel(Color(UI.DANGER, 0.88) if boss else Color(0.05, 0.06, 0.08, 0.82), 0, 14)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.custom_minimum_size.x = MAP_CELL * 10
	var v := UI.vbox(0)
	band.add_child(v)
	var last := not battle.endless and index + 1 == battle.wave_count()
	var title := "WAVE %d" % (index + 1) if battle.endless else "WAVE %d / %d" % [index + 1, battle.wave_count()]
	v.add_child(UI.label(title, 44, UI.GOLD if not boss else UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	if boss or last:
		v.add_child(UI.label("보스 등장!" if boss else "마지막 웨이브!", 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	_float_layer.add_child(band)
	band.reset_size()
	var y := MAP_CELL * 2.2 - band.size.y / 2
	band.position = Vector2(-MAP_CELL * 10, y)
	var tw := band.create_tween()
	tw.tween_property(band, "position:x", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(band, "position:x", MAP_CELL * 10, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(band.queue_free)


func _show_banner() -> void:
	var box := UI.panel(Color(0.05, 0.06, 0.08, 0.85), 24, 26)
	var v := UI.vbox(6)
	box.add_child(v)
	v.add_child(UI.label("STAGE %d" % stage_id, 26, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(battle.def.name, 52, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("직원을 고용하고 웨이브 시작을 누르세요", 24, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.add_child(box)
	box.reset_size()
	box.position = Vector2((MAP_CELL * 10 - box.size.x) / 2, MAP_CELL * 5 - box.size.y / 2)
	var tw := box.create_tween()
	box.modulate.a = 0
	tw.tween_property(box, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.8)
	tw.tween_property(box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(box.queue_free)


# ------------------------------------------------------------------ 일시정지 / 속도

func _toggle_speed() -> void:
	battle.set_speed(1.0 if battle.speed >= 2.0 else 2.0)
	_refresh_hud()


func _toggle_pause() -> void:
	if battle.finished:
		return
	if is_instance_valid(_pause_modal):
		UI.close_modal(_pause_modal)
		_pause_modal = null
		battle.paused = false
		return
	battle.paused = true
	var text := UI.label("스테이지를 포기하면 보상을 받을 수 없습니다.", 28, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_pause_modal = UI.modal("일시정지", text, [
		["계속하기", UI.PRIMARY, func(): battle.paused = false],
		["포기하기", UI.DANGER, func(): UI.go("res://scenes/main.tscn")],
	], self, false)


# ------------------------------------------------------------------ 종료

func _on_game_over(won: bool, summary: Dictionary) -> void:
	await get_tree().create_timer(0.6).timeout
	var v := UI.vbox(10)
	var text := "모든 웨이브를 막아냈습니다!" if won else "회사가 무너졌습니다..."
	if battle.endless:
		text = "웨이브 %d까지 버텼습니다!" % summary.wave
	var headline := UI.label(text, 30, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(headline)
	if battle.endless:
		var record := "최고 기록 경신!" if summary.new_record else "최고 기록: 웨이브 %d" % Save.user.endless_best
		v.add_child(UI.label(record, 28, UI.GOLD if summary.new_record else UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var stats := UI.panel(UI.CARD, 16, 18)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 8)
	for pair in [["처치", str(summary.kills)], ["획득 골드", str(summary.gold)], ["점수", str(summary.score)]]:
		grid.add_child(UI.label(pair[0], 28, UI.MUTED))
		var value := UI.label(pair[1], 30, UI.GOLD if pair[0] == "획득 골드" else UI.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(value)
	stats.add_child(grid)
	v.add_child(stats)
	if summary.first_clear:
		var bonus := "첫 클리어 보상이 메일함에 도착했습니다!"
		if stage_id < StageDefs.COUNT:
			bonus += "\n다음 스테이지가 열렸습니다!"
		v.add_child(UI.label(bonus, 24, UI.SUCCESS, HORIZONTAL_ALIGNMENT_CENTER))
	var title := "야근 종료" if battle.endless else ("승리!" if won else "패배")
	UI.modal(title, v, [
		["다시 하기", UI.CARD_HI, func(): UI.go("res://scenes/stage.tscn", func(s): s.stage_id = stage_id)],
		["메인 화면", UI.PRIMARY, func(): UI.go("res://scenes/main.tscn")],
	], self, false)
