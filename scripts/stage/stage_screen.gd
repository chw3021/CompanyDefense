# 스테이지 화면: 위쪽 HUD, 가운데 맵, 아래쪽 조작 패널.
extends Control

const MAP_CELL := 72.0

var stage_id := 1
var battle: Battle
var view: BattleView

var _life_label: Label
var _coin_label: Label
var _wave_label: Label
var _speed_button: Button
var _fx_button: Button
var _mute_button: Button
var _wave_button: Button
var _hire_button: Button
var _hire_cost_label: Label
var _hire_title_label: Label
var _relic_button: Button
var _relic_label: Label
var _merge_button: Button  # 1성 모두 승진
var _target_button: Button
var _slot_button: Button
var _sell_armed: Tower  # 퇴사 버튼을 한 번 눌러 확인을 기다리는 직원
var _sell_token := 0
var _map_area: Control
var _float_layer: Control
var _info_slot: Control
var _hint: VBoxContainer
var _card: PanelContainer
var _upgrades: HBoxContainer
var _upgrade_labels := {}
var _upgrade_costs := {}
var _card_widgets := {}
var _pause_modal: Control
var _setup_bar: PanelContainer  # 일시정지/정비 중 맵을 가리지 않는 하단 바
var _setup_label: Label
var _last_life := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	battle = Battle.new()
	battle.setup(stage_id, MAP_CELL)
	add_child(battle)
	_build()
	battle.hud_changed.connect(_refresh_hud)
	battle.message.connect(_show_message)
	battle.floating.connect(_show_floating)
	battle.tower_selected.connect(_on_tower_selected)
	battle.game_over.connect(_on_game_over)
	battle.wave_started.connect(func(i: int):
		Audio.wave()
		_show_wave_banner(i))
	battle.rest_started.connect(func(_reason: String): _refresh_setup_bar())
	battle.rest_ended.connect(_refresh_setup_bar)
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
	root.clip_contents = true
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
	hud.clip_contents = true
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10 + int(_safe_top()))
	margin.add_theme_constant_override("margin_bottom", 8)
	hud.add_child(margin)
	var row := UI.hbox(6)
	margin.add_child(row)

	# 고리 맵은 목숨 대신 필드에 있는 적 수 (n/100)
	row.add_child(UI.icon("res://assets/enemy/printer.png", 34) if battle.loop else UI.icon("res://assets/icons/heart.svg", 28))
	_life_label = UI.label("", 30)
	_life_label.custom_minimum_size.x = 90 if battle.loop else 42
	row.add_child(_life_label)
	row.add_child(UI.icon("res://assets/icons/coin.svg", 34))
	_coin_label = UI.label("", 30, UI.GOLD)
	_coin_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coin_label.clip_text = true
	row.add_child(_coin_label)
	_wave_label = UI.label("", 24)
	_wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wave_label.clip_text = true
	_wave_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_wave_label)

	var pause := UI.button("II", UI.CARD_HI, _toggle_pause, 22)
	pause.custom_minimum_size = Vector2(48, 48)
	UI.recolor_compact(pause, UI.CARD_HI, 6)
	row.add_child(pause)
	_speed_button = UI.button("", UI.CARD_HI, _toggle_speed, 20)
	_speed_button.custom_minimum_size = Vector2(48, 48)
	UI.recolor_compact(_speed_button, UI.CARD_HI, 6)
	row.add_child(_speed_button)
	_fx_button = UI.button("", UI.CARD_HI, _toggle_fx, 16)
	_fx_button.custom_minimum_size = Vector2(48, 48)
	_fx_button.clip_text = true
	UI.recolor_compact(_fx_button, UI.CARD_HI, 6)
	row.add_child(_fx_button)
	_mute_button = UI.button("", UI.CARD_HI, _toggle_mute, 16)
	_mute_button.custom_minimum_size = Vector2(48, 48)
	_mute_button.clip_text = true
	UI.recolor_compact(_mute_button, UI.CARD_HI, 6)
	row.add_child(_mute_button)
	return hud


func _build_panel() -> Control:
	var panel := UI.panel(UI.PANEL, 0, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var col := UI.vbox(10)
	margin.add_child(col)

	# 가운데: 직원 정보 카드 또는 안내 문구
	_info_slot = Control.new()
	_info_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_slot.clip_contents = true
	col.add_child(_info_slot)
	_hint = UI.vbox(14)
	_hint.alignment = BoxContainer.ALIGNMENT_CENTER
	_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint.add_child(UI.label("직원을 누르면 정보를 볼 수 있어요\n같은 직원끼리 끌어다 놓으면 승진!\n전설 이상은 빈 책상으로 이동 (쿨 2웨이브)", 24, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var tools := UI.hbox(8)
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	_merge_button = UI.button("", UI.SUCCESS, _on_merge_pressed, 18)
	var merge_cfg := UI.button("설정", UI.CARD_HI, _open_merge_settings, 18)
	var book := UI.button("신화", Color("7a3fb0"), _open_recipes, 18)
	var help := UI.button("도움", UI.CARD_HI, _open_help, 18)
	var tool_colors := [UI.SUCCESS, UI.CARD_HI, Color("7a3fb0"), UI.CARD_HI]
	var tool_btns := [_merge_button, merge_cfg, book, help]
	for i in tool_btns.size():
		var b: Button = tool_btns[i]
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		UI.recolor_compact(b, tool_colors[i], 8)
		tools.add_child(b)
	# 자동 승진 문구가 길어서 왼쪽 칸을 더 넓게
	_merge_button.size_flags_stretch_ratio = 1.7
	_hint.add_child(tools)
	var pref_row := UI.hbox(6)
	pref_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_button = UI.button("", UI.CARD_HI, func():
		Save.cycle_desk_pref_slot()
		_refresh_hud(), 16)
	var save_pref := UI.button("저장", UI.PRIMARY, func(): battle.save_desk_prefs_from_towers(), 16)
	var clear_pref := UI.button("삭제", UI.CARD_HI, func(): battle.clear_desk_prefs(), 16)
	_target_button = UI.button("", UI.PRIMARY, func():
		battle.target_mode = Save.cycle_target_mode()
		_refresh_hud(), 16)
	var pref_colors := [UI.CARD_HI, UI.PRIMARY, UI.CARD_HI, UI.PRIMARY]
	var pref_btns := [_slot_button, save_pref, clear_pref, _target_button]
	for i in pref_btns.size():
		var b: Button = pref_btns[i]
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		UI.recolor_compact(b, pref_colors[i], 8)
		pref_row.add_child(b)
	_hint.add_child(pref_row)
	_info_slot.add_child(_hint)
	_card = _build_tower_card()
	_card.visible = false
	col.add_child(_card)

	# 팀 업그레이드
	_upgrades = UI.hbox(10)
	for team in GameData.TEAMS:
		_upgrades.add_child(_build_upgrade_card(team))
	col.add_child(_upgrades)

	# 직원 고용 / 웨이브 시작 (좁은 화면에서 잘리지 않게 최소 폭을 낮춘다)
	var actions := UI.hbox(8)
	_hire_button = UI.button("", UI.SUCCESS, battle.hire)
	_hire_button.custom_minimum_size = Vector2(0, 96)
	_hire_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hire_button.clip_text = true
	UI.recolor_compact(_hire_button, UI.SUCCESS, 10)
	var hire_content := UI.hbox(8)
	hire_content.alignment = BoxContainer.ALIGNMENT_CENTER
	hire_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hire_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	hire_content.add_child(UI.icon("res://assets/icons/work.svg", 36))
	var hire_text := UI.vbox(0)
	hire_text.alignment = BoxContainer.ALIGNMENT_CENTER
	hire_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hire_title_label = UI.label("고용", 22)
	_hire_title_label.clip_text = true
	_hire_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hire_text.add_child(_hire_title_label)
	_hire_cost_label = UI.label(str(Battle.SPAWN_COST), 20, UI.GOLD)
	_hire_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hire_text.add_child(_hire_cost_label)
	hire_content.add_child(hire_text)
	_hire_button.add_child(hire_content)
	actions.add_child(_hire_button)
	# 팀 필터는 별도 큰 버튼 대신 좁은 토글 (폭 넘침 방지)
	var hire_team_btn := UI.button("팀", UI.CARD_HI, func():
		Save.cycle_hire_team()
		_refresh_hud(), 18)
	hire_team_btn.custom_minimum_size = Vector2(52, 96)
	UI.recolor_compact(hire_team_btn, UI.CARD_HI, 8)
	actions.add_child(hire_team_btn)

	# 유물 뽑기: 보스를 잡아 유물이 있을 때만 보인다
	_relic_button = UI.button("", UI.PURPLE, battle.summon_special)
	_relic_button.custom_minimum_size = Vector2(72, 96)
	UI.recolor_compact(_relic_button, UI.PURPLE, 8)
	var relic_content := UI.vbox(0)
	relic_content.alignment = BoxContainer.ALIGNMENT_CENTER
	relic_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	relic_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	relic_content.add_child(UI.icon("res://assets/icons/relic.svg", 36))
	_relic_label = UI.label("", 18, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_relic_label.clip_text = true
	relic_content.add_child(_relic_label)
	_relic_button.add_child(relic_content)
	actions.add_child(_relic_button)

	_wave_button = UI.button("야근 시작", UI.DANGER, _on_wave_pressed, 24)
	_wave_button.icon = UI.play_icon()
	_wave_button.custom_minimum_size = Vector2(0, 96)
	_wave_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wave_button.clip_text = true
	_wave_button.expand_icon = true
	_wave_button.add_theme_constant_override("icon_max_width", 28)
	UI.recolor_compact(_wave_button, UI.DANGER, 10)
	actions.add_child(_wave_button)
	col.add_child(actions)

	_setup_bar = UI.panel(UI.CARD, 14, 14)
	_setup_bar.visible = false
	var setup_col := UI.vbox(8)
	_setup_bar.add_child(setup_col)
	_setup_label = UI.label("", 26, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	setup_col.add_child(_setup_label)
	setup_col.add_child(UI.wrap_label("고용 · 승진 · 전설 이동 · 팀 업그레이드로 정비하세요", 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var setup_row := UI.hbox(8)
	setup_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_col.add_child(setup_row)
	var resume := UI.button("계속 / 정비 완료", UI.PRIMARY, _resume_setup, 22)
	resume.custom_minimum_size = Vector2(0, 64)
	resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume.clip_text = true
	setup_row.add_child(resume)
	var give_up := UI.button("포기", UI.DANGER, _confirm_give_up, 22)
	give_up.custom_minimum_size = Vector2(0, 64)
	give_up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	give_up.clip_text = true
	setup_row.add_child(give_up)
	col.add_child(_setup_bar)
	return panel


func _on_wave_pressed() -> void:
	if battle.resting:
		battle.end_rest()
	elif battle.paused:
		_resume_setup()
	else:
		battle.start_wave()


func _on_merge_pressed() -> void:
	if battle.merge_auto_pairs_count() == 0:
		_open_merge_settings()
	else:
		battle.merge_auto()
		_refresh_hud()


func _open_merge_settings() -> void:
	var v := UI.vbox(14)
	var grade_btn := UI.button("", UI.PRIMARY)
	grade_btn.custom_minimum_size.y = 72
	var grade_refresh := func(): grade_btn.text = "승진 범위: 1~%d성" % Save.merge_auto_grade()
	grade_btn.pressed.connect(func():
		Save.cycle_merge_auto_grade()
		grade_refresh.call()
		_refresh_hud())
	grade_refresh.call()
	v.add_child(grade_btn)
	var team_btn := UI.button("", UI.PRIMARY)
	team_btn.custom_minimum_size.y = 72
	var team_refresh := func(): team_btn.text = "팀 필터: %s" % Save.merge_auto_team_label()
	team_btn.pressed.connect(func():
		Save.cycle_merge_auto_team()
		team_refresh.call()
		_refresh_hud())
	team_refresh.call()
	v.add_child(team_btn)
	v.add_child(UI.wrap_label("자동 승진 버튼을 누르면 선택한 범위·팀의 짝을 연쇄로 합칩니다.\n(모바일: 도움말에서도 바꿀 수 있습니다)", 22, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	UI.modal("자동 승진 설정", v, [["닫기", UI.CARD_HI]], self)


func _build_upgrade_card(team: String) -> Button:
	var b := UI.button("", UI.CARD, func(): battle.upgrade_team(team))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 110)
	b.clip_text = true
	UI.recolor_compact(b, UI.CARD, 8)
	var v := UI.vbox(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_child(UI.icon("res://assets/icons/%sup.svg" % team, 36))
	var name_label := UI.label("", 20, GameData.TEAM_COLORS[team].lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
	name_label.clip_text = true
	v.add_child(name_label)
	var cost := UI.coin_row("", 18)
	v.add_child(cost)
	b.add_child(v)
	_upgrade_labels[team] = name_label
	_upgrade_costs[team] = cost.get_node("Amount")
	return b


func _build_tower_card() -> PanelContainer:
	# 9:16 보다 넓은 화면은 아래 패널 높이가 고정이라, 전설(신화 조합 줄 포함) 카드가 업그레이드 줄 자리에 들어가도록 촘촘하게 둔다
	var card := UI.panel(UI.CARD, 20, 12)
	var v := UI.vbox(10)
	card.add_child(v)
	var top := UI.hbox(18)
	v.add_child(top)
	var portrait_bg := UI.panel(Color("0f1319"), 16, 6)
	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	var sell := UI.button("", Color("a0604a"), _on_sell_pressed, 28)
	var trade := UI.button("", Color("3b6ea5"), func():
		if battle.selected:
			battle.trade(battle.selected), 28)
	for b in [sell, trade]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 68
		b.add_theme_constant_override("icon_max_width", 40)
		row.add_child(b)
	sell.icon = load("res://assets/icons/walk_out.svg")
	trade.icon = load("res://assets/icons/negociation.svg")
	sell.expand_icon = false
	var help := UI.button("?", UI.CARD_HI, _open_help, 28)
	help.custom_minimum_size = Vector2(68, 68)
	row.add_child(help)
	v.add_child(row)
	# 전설이면 신화 조합 재료와 각성 버튼
	var mythic := UI.hbox(12)
	var recipe := UI.label("", 22, UI.MUTED)
	recipe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mythic.add_child(recipe)
	var awaken := UI.button("신화 각성", Color("7a3fb0"), func():
		if battle.selected:
			battle.awaken(battle.selected), 24)
	awaken.custom_minimum_size = Vector2(0, 56)
	awaken.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	awaken.clip_text = true
	mythic.add_child(awaken)
	v.add_child(mythic)
	_card_widgets = {"portrait": portrait, "name": name_label, "grade": grade_label, "stats": stats,
			"skill": skill, "sell": sell, "trade": trade, "mythic": mythic, "recipe": recipe, "awaken": awaken}
	return card


## 신화 조합 상태 (선택한 전설 기준): 재료 이름 옆에 보유/없음
func _fill_recipe(t: Tower) -> void:
	var mythic := battle.mythic_for(t)
	_card_widgets.mythic.visible = mythic != ""
	if mythic == "":
		return
	var parts := battle.recipe_towers(t)
	var names := []
	var recipe: Array = GameData.MYTHICS[mythic].recipe
	for i in recipe.size():
		names.append("%s %s" % [GameData.towers[recipe[i]].towerName, "(보유)" if parts[i] != null else "(없음)"])
	var unlocked := battle.mythic_unlocked(t)
	var lock := ""
	if not unlocked:
		# 카드 높이를 두 줄로 맞추려고 해금 조건을 짧게 붙인다 (자세한 문구는 신화 조합표)
		var p := GameData.mythic_progress(Save.user, mythic)
		lock = " (잠김: %s팀 Lv.%d 이상 %d/%d명)" % [GameData.team_name(GameData.towers[mythic].team), GameData.MYTHIC_UNLOCK_LEVEL, p[0], p[1]]
	_card_widgets.recipe.text = "→ %s%s\n재료: %s" % [GameData.MYTHICS[mythic].name, lock, " + ".join(names)]
	var ok := battle.can_awaken(t)
	_card_widgets.recipe.add_theme_color_override("font_color", UI.GOLD if ok else (UI.MUTED if unlocked else UI.DANGER))
	_card_widgets.awaken.disabled = not ok
	_card_widgets.awaken.text = "신화 각성" if unlocked else "잠김"


## 신화 조합표: 신화마다 재료와 지금 필드에 있는지
func _open_recipes() -> void:
	var list := UI.vbox(12)
	var on_field := func(id: String) -> bool:
		return battle.towers.any(func(t: Tower): return t.id == id)
	for id in GameData.MYTHICS:
		var m: Dictionary = GameData.MYTHICS[id]
		var card := UI.panel(UI.CARD, 16, 16)
		var v := UI.vbox(6)
		card.add_child(v)
		var unlocked := GameData.mythic_unlocked(Save.user, id)
		var head := UI.hbox(10)
		head.add_child(UI.label(m.name, 30, GameData.grade_color(GameData.MYTHIC_GRADE)))
		head.add_child(UI.label("%s팀 신화" % GameData.team_name(GameData.towers[id].team), 22, UI.MUTED))
		if not unlocked:
			head.add_child(UI.label("잠김", 22, UI.DANGER))
		v.add_child(head)
		if not unlocked:
			v.add_child(UI.wrap_label(GameData.mythic_lock_text(Save.user, id), 20, UI.DANGER, HORIZONTAL_ALIGNMENT_LEFT))
		var parts := HFlowContainer.new()
		parts.add_theme_constant_override("h_separation", 8)
		parts.add_theme_constant_override("v_separation", 6)
		for need in [m.base] + m.recipe:
			var t: Dictionary = GameData.towers[need]
			var have: bool = on_field.call(need)
			var chip := UI.label("%s (%s)" % [t.towerName, GameData.grade_label(t)], 20,
					UI.SUCCESS if have else UI.MUTED)
			chip.add_theme_stylebox_override("normal", UI.box(Color(UI.SUCCESS, 0.15) if have else Color(0, 0, 0, 0.25), 10, 6))
			parts.add_child(chip)
		v.add_child(parts)
		v.add_child(UI.wrap_label("%s: %s" % [m.skill.skillName, m.skill.description], 21, Color("c9d4ff"), HORIZONTAL_ALIGNMENT_LEFT))
		list.add_child(card)
	var scroll := UI.scroll(list)
	scroll.custom_minimum_size = UI.modal_scroll_size(560, 640)
	var v := UI.vbox(10)
	v.add_child(UI.wrap_label("세 팀의 전설 3명(또는 특수 직원 + 전설 2명)을 모으면 신화로 각성! 첫 번째 직원을 누르고 '신화 각성'.\n재료로 쓴 직원은 사라집니다. 초록색은 지금 필드에 있는 직원.\n신화는 직원 관리에서 그 팀 직원을 모두 레벨 %d 이상으로 올려야 해금됩니다." % GameData.MYTHIC_UNLOCK_LEVEL, 22, UI.MUTED))
	v.add_child(scroll)
	UI.modal("신화 조합표", v, [["닫기", UI.CARD_HI]], self)


## 도움말: 팀 레벨업, 협상, 적 방어력
func _open_help() -> void:
	var v := UI.vbox(12)
	var section := func(title: String) -> void:
		v.add_child(UI.label(title, 30, UI.GOLD))
	var line := func(text: String, color: Color) -> void:
		v.add_child(UI.wrap_label(text, 22, color, HORIZONTAL_ALIGNMENT_LEFT))

	section.call("팀 레벨업 (인사 / 개발 / 영업)")
	line.call("아래 팀 버튼을 누르면 그 팀 직원 모두의 물리·마법 공격력이 레벨당 10%씩 오릅니다.\n비용은 50 × 현재 레벨 코인이고, 이번 스테이지에서만 유지됩니다.", UI.MUTED)
	var roles := {"hr": "공격 속도 증가, 적 방어력 감소, 기절 등 지원", "dv": "마법 피해 스킬", "sl": "물리 피해 스킬과 코인 획득"}
	for team in GameData.TEAMS:
		var lv: int = battle.team_level[team]
		line.call("%s팀 Lv.%d: 공격력 +%d%% → 다음 레벨 +%d%% (%d코인)\n  %s" % [GameData.team_name(team), lv, (lv - 1) * 10, lv * 10, battle.upgrade_cost(team), roles[team]],
				GameData.TEAM_COLORS[team].lightened(0.3))

	section.call("협상")
	var chances := []
	for i in Battle.TRADE_CHANCES.size():
		chances.append("%d성 %d%%" % [i + 1, roundi(Battle.TRADE_CHANCES[i] * 100)])
	line.call("직원을 누르고 '협상'을 누르면 50 × 등급 코인을 내고 같은 등급의 다른 직원으로 바꿉니다.\n실패하면 그 직원은 퇴사하고 코인은 돌려받지 못합니다. 신화와 특수 직원은 협상할 수 없습니다.", UI.MUTED)
	line.call("성공 확률: " + " · ".join(chances), UI.TEXT)

	section.call("전설 이동 · 정비")
	line.call("전설(5성) 이상 직원은 빈 책상으로 끌어 이동할 수 있습니다. 이동 후 %d웨이브(라운드) 동안 다시 옮길 수 없습니다." % Battle.MOVE_COOLDOWN, UI.MUTED)
	line.call("일시정지와 정비 시간에는 전투만 멈추고 고용·승진·이동이 가능합니다.\n무한 야근은 %d라운드마다, 그리고 보스 라운드 직전에 정비가 열립니다." % Battle.REST_EVERY, UI.MUTED)
	line.call("선호 자리 슬롯 1~3: 지금 배치를 저장해 두고 고용 시 그 빈자리를 먼저 씁니다.", UI.MUTED)
	line.call("야근은 %d라운드마다 랜덤 이벤트(수당 2배, 전력 질주, 고용 불가, 업무 폭주)가 납니다." % Battle.EVENT_EVERY, UI.MUTED)

	section.call("고용 · 공격 우선순위")
	line.call("고용 옆 '팀'으로 인사/개발/영업만 고용할 수 있습니다 (비용 %d). 공격 우선순위는 힌트 줄 버튼으로 바꿉니다." % Battle.HIRE_TEAM_COST, UI.MUTED)
	line.call("현재 고용: %s / 우선순위: %s / 시드: %d" % [Save.hire_team_label(), Save.target_mode_label(), battle.run_seed], UI.TEXT)

	section.call("자동 승진")
	line.call("현재 범위 1~%d성 / 팀: %s. '승진설정'에서 바꿀 수 있습니다." % [Save.merge_auto_grade(), Save.merge_auto_team_label()], UI.TEXT)

	section.call("적 방어력")
	line.call("받는 피해 = 피해 × (1 - 방어 ÷ (방어 + 100)). 괄호 안은 줄어드는 피해입니다.\n맵에서 체력바 옆 '물'(주황)·'마'(파랑) 표시는 그 피해가 잘 들어가는 적입니다.", UI.MUTED)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	for head in ["적", "물리", "마법", "약점"]:
		var hl := UI.label(head, 18, UI.MUTED)
		hl.clip_text = true
		grid.add_child(hl)
	for id in StageDefs.ENEMIES:
		var e: Dictionary = StageDefs.ENEMIES[id]
		var gap: float = e.pdef - e.mdef
		var weak := "-"
		var weak_color := UI.MUTED
		if absf(gap) >= BattleView.WEAK_GAP:
			weak = "마법" if gap > 0 else "물리"
			weak_color = BattleView.DMG_MAGIC if gap > 0 else BattleView.DMG_PHYSICAL
		var name_l := UI.label(e.name, 18, UI.DANGER if e.boss else UI.TEXT)
		name_l.clip_text = true
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_l)
		grid.add_child(UI.label("%d(-%d%%)" % [e.pdef, roundi(100.0 * e.pdef / (e.pdef + 100.0))], 17, BattleView.DMG_PHYSICAL))
		grid.add_child(UI.label("%d(-%d%%)" % [e.mdef, roundi(100.0 * e.mdef / (e.mdef + 100.0))], 17, BattleView.DMG_MAGIC))
		grid.add_child(UI.label(weak, 18, weak_color))
	v.add_child(grid)

	var scroll := UI.scroll(v)
	scroll.custom_minimum_size = UI.modal_scroll_size(560, 640)
	UI.modal("도움말", scroll, [["닫기", UI.CARD_HI]], self)


# ------------------------------------------------------------------ 갱신

func _refresh_hud() -> void:
	if battle.loop:
		var n := battle.alive_count()
		_life_label.text = "%d/%d" % [n, battle.max_enemies]
		var ratio := float(n) / battle.max_enemies
		_life_label.add_theme_color_override("font_color", UI.DANGER if ratio >= 0.8 else (UI.WARN if ratio >= 0.5 else UI.TEXT))
	else:
		_life_label.text = str(battle.life)
		if battle.life < _last_life:
			_pulse(_life_label, UI.DANGER)
		_last_life = battle.life
	_coin_label.text = str(battle.coins)
	if battle.loop:
		_wave_label.text = "라운드 %d · %d초" % [battle.display_wave(), ceili(maxf(0.0, battle.round_left))] if battle.wave_running else "라운드 %d" % maxi(1, battle.display_wave())
	elif battle.endless:
		_wave_label.text = "웨이브 %d" % battle.display_wave()
	else:
		_wave_label.text = "웨이브 %d/%d" % [battle.display_wave(), battle.wave_count()]
	_speed_button.text = "x%d" % int(battle.speed)
	_fx_button.text = Save.effect_quality_short()
	_mute_button.text = "음X" if Save.sfx_muted() else "음"
	# 이벤트 문구는 HUD 폭을 넘기기 쉬워서 짧은 표시만 붙인다
	if battle.loop and battle.event_id != "":
		_wave_label.text = "%s · 이벤트" % _wave_label.text
	var can_start := battle.can_start_wave()
	if battle.resting:
		_wave_button.disabled = false
		_wave_button.text = "정비 완료"
	elif battle.paused:
		_wave_button.disabled = false
		_wave_button.text = "계속하기"
	else:
		_wave_button.disabled = not can_start
		var start_text := "야근 시작" if battle.loop else "웨이브 시작"
		_wave_button.text = start_text if can_start else ("진행 중" if battle.wave_running else "종료")
	var cost := battle.hire_cost()
	_hire_button.modulate.a = 0.45 if battle.hire_blocked else (1.0 if battle.coins >= cost else 0.6)
	if _hire_title_label:
		var team_name := Save.hire_team_label()
		_hire_title_label.text = team_name if team_name != "전체" else "고용"
	if _hire_cost_label:
		_hire_cost_label.text = "막힘" if battle.hire_blocked else str(cost)
	_relic_button.visible = battle.relics > 0
	_relic_label.text = "x%d" % battle.relics
	var pairs := battle.merge_auto_pairs_count()
	var team_tag := Save.merge_auto_team()
	var scope := "1~%d" % Save.merge_auto_grade()
	if team_tag in GameData.TEAMS:
		scope = "%s%s" % [GameData.team_name(team_tag).left(1), scope]
	_merge_button.text = "승진 %s(%d)" % [scope, pairs]
	_merge_button.disabled = false
	if _slot_button:
		_slot_button.text = "슬롯%d" % (Save.desk_pref_slot() + 1)
	if _target_button:
		_target_button.text = Save.target_mode_short()
	_refresh_setup_bar()
	for team in GameData.TEAMS:
		_upgrade_labels[team].text = "%s Lv.%d" % [GameData.team_name(team), battle.team_level[team]]
		_upgrade_costs[team].text = str(battle.upgrade_cost(team))


func _process(_delta: float) -> void:
	# 공격 속도 버프 등으로 바뀌는 능력치를 카드에 계속 반영
	if _card.visible and battle.selected:
		_fill_stats(battle.selected)
		_fit_upgrades()


func _on_tower_selected(t: Tower) -> void:
	_sell_armed = null
	_card.visible = t != null
	_hint.visible = t == null
	if t == null:
		_upgrades.visible = true
		return
	_card_widgets.portrait.texture = load(GameData.asset(t.data.towerImagePath))
	_card_widgets.name.text = t.name
	_card_widgets.grade.text = "%s팀  |  %s" % [GameData.team_name(t.team), GameData.grade_label(t.data)]
	_card_widgets.grade.add_theme_color_override("font_color", GameData.tower_color(t.data))
	_card_widgets.sell.text = "퇴사  +%d" % Battle.sell_price(t)
	_card_widgets.trade.text = "협상  -%d (%d%%)" % [Battle.trade_cost(t), roundi(Battle.trade_chance(t) * 100)]
	_card_widgets.trade.disabled = not Battle.can_trade(t)
	_fill_stats(t)
	_fit_upgrades()


## 카드와 팀 업그레이드 줄이 함께 들어갈 높이가 있을 때만 업그레이드 줄을 보여 준다 (낮은 화면에서는 그 자리에 카드).
## 카드가 처음 배치되기 전에는 줄바꿈 높이를 크게 잡으므로 _process 에서 다시 맞춘다
func _fit_upgrades() -> void:
	var col := _card.get_parent() as VBoxContainer
	var sep := col.get_theme_constant("separation")
	# 넘쳐서 col 이 늘어난 상태여도 흔들리지 않게 화면 높이 기준으로 남는 높이를 잰다
	var room: float = size.y - col.global_position.y - col.get_parent().get_theme_constant("margin_bottom")
	var need: float = _card.get_combined_minimum_size().y + _upgrades.size.y + _hire_button.get_parent().size.y + sep * 3
	_upgrades.visible = need <= room


## 퇴사는 되돌릴 수 없어서 두 번 눌러야 한다 (화면이 낮으면 바로 아래 직원 고용 버튼과 붙어 있어 잘못 누르기 쉽다)
func _on_sell_pressed() -> void:
	var t := battle.selected
	if t == null:
		return
	if _sell_armed == t:
		_sell_armed = null
		battle.sell(t)
		return
	_sell_armed = t
	_sell_token += 1
	var token := _sell_token
	_card_widgets.sell.text = "한 번 더 누르면 퇴사"
	get_tree().create_timer(2.0).timeout.connect(func():
		if token == _sell_token and _sell_armed == t:
			_sell_armed = null
			_card_widgets.sell.text = "퇴사  +%d" % Battle.sell_price(t))


func _fill_stats(t: Tower) -> void:
	_fill_recipe(t)
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
	var title := "WAVE %d / %d" % [index + 1, battle.wave_count()]
	if battle.endless:
		title = ("ROUND %d" if battle.loop else "WAVE %d") % (index + 1)
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
	var guide := "직원을 고용하고 웨이브 시작을 누르세요"
	if battle.loop:
		guide = "적이 끝없이 몰려옵니다. %d마리가 쌓이면 끝!\n직원을 고용하고 야근 시작을 누르세요" % battle.max_enemies
	v.add_child(UI.label(guide, 24, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
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


func _toggle_fx() -> void:
	Save.cycle_effect_quality()
	view.apply_effect_settings()
	_refresh_hud()


func _toggle_mute() -> void:
	Save.toggle_sfx_muted()
	_refresh_hud()


func _toggle_pause() -> void:
	if battle.finished:
		return
	# 정비 중 II: 정비 종료. 일시정지 중 II: 재개
	if battle.resting:
		battle.end_rest()
		return
	if battle.paused:
		_resume_setup()
		return
	battle.paused = true
	_refresh_setup_bar()
	_refresh_hud()
	# 맵을 가리지 않도록 전체 모달 대신 안내만. 포기는 하단 바에서
	battle.message.emit("일시정지 — 배치를 수정할 수 있습니다", UI.WARN)


func _resume_setup() -> void:
	if battle.resting:
		battle.end_rest()
		return
	battle.paused = false
	if is_instance_valid(_pause_modal):
		UI.close_modal(_pause_modal)
		_pause_modal = null
	_refresh_setup_bar()
	_refresh_hud()


func _confirm_give_up() -> void:
	var text := UI.label("스테이지를 포기하면 보상을 받을 수 없습니다.", 28, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_pause_modal = UI.modal("포기하기", text, [
		["취소", UI.CARD_HI],
		["포기하기", UI.DANGER, func():
			battle.flush_session()
			UI.go("res://scenes/main.tscn")],
	], self, false)


func _refresh_setup_bar() -> void:
	if _setup_bar == null:
		return
	var frozen := battle.setup_frozen() and not battle.finished
	_setup_bar.visible = frozen
	if not frozen:
		return
	if battle.resting:
		_setup_label.text = battle.rest_reason if battle.rest_reason != "" else "정비 시간"
	else:
		_setup_label.text = "일시정지 · 배치 수정 가능"


# ------------------------------------------------------------------ 종료

func _on_game_over(won: bool, summary: Dictionary) -> void:
	if won:
		Audio.win()
	else:
		Audio.lose()
	await get_tree().create_timer(0.6).timeout
	var v := UI.vbox(10)
	var text := "모든 웨이브를 막아냈습니다!" if won else "회사가 무너졌습니다..."
	if battle.loop:
		text = "적이 %d마리나 쌓였습니다...\n%d라운드를 버텼습니다!" % [battle.max_enemies, summary.wave]
	elif battle.endless:
		text = "웨이브 %d까지 버텼습니다!" % summary.wave
	var headline := UI.label(text, 30, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(headline)
	if battle.endless:
		var record := "최고 기록 경신!" if summary.new_record else "최고 기록: %d라운드" % Save.user.get("round_best", 0)
		v.add_child(UI.label(record, 28, UI.GOLD if summary.new_record else UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var stats := UI.panel(UI.CARD, 16, 18)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 8)
	var rows := [
		["처치", str(summary.kills)],
		["획득 골드", str(summary.gold)],
		["점수", str(summary.score)],
		["승진", str(summary.get("merges", 0))],
		["고용", str(summary.get("hires", 0))],
		["피해", str(summary.get("damage", 0))],
		["시드", str(summary.get("seed", 0))],
	]
	if int(summary.get("mythics", 0)) > 0:
		rows.insert(6, ["신화", str(summary.mythics)])
	for pair in rows:
		grid.add_child(UI.label(pair[0], 26, UI.MUTED))
		var value := UI.label(pair[1], 28, UI.GOLD if pair[0] == "획득 골드" else UI.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(value)
	stats.add_child(grid)
	v.add_child(stats)
	if summary.first_clear:
		var bonus := "첫 클리어 보상이 메일함에 도착했습니다!"
		if stage_id < StageDefs.COUNT:
			bonus += "\n다음 스테이지가 열렸습니다!"
		v.add_child(UI.label(bonus, 24, UI.SUCCESS, HORIZONTAL_ALIGNMENT_CENTER))
	if Missions.claimable_count(Save.user) > 0:
		v.add_child(UI.label("받을 수 있는 미션 보상이 있어요! (메인 화면 > 미션)", 24, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var title := "야근 종료" if battle.endless else ("승리!" if won else "패배")
	var buttons := [
		["다시 하기", UI.CARD_HI, func(): UI.go("res://scenes/stage.tscn", func(s): s.stage_id = stage_id)],
		["메인 화면", UI.PRIMARY, func(): UI.go("res://scenes/main.tscn")],
	]
	if battle.endless and int(summary.get("seed", 0)) != 0:
		buttons.insert(0, ["같은 시드", UI.SUCCESS, func():
			Save.set_pending_run_seed(int(summary.seed))
			UI.go("res://scenes/stage.tscn", func(s): s.stage_id = stage_id)])
		buttons.insert(1, ["시드 복사", UI.CARD_HI, func():
			DisplayServer.clipboard_set(str(summary.seed))
			UI.toast("시드를 복사했습니다.", UI.GOLD)])
	UI.modal(title, v, buttons, self, false)
