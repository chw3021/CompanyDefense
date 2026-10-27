# 직원 탭: 18명의 직원 카드와 레벨 업, 신화 카드와 해금 현황
extends VBoxContainer

var main
var _grid: GridContainer
var _filter := ""
var _filter_buttons := {}


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	add_child(UI.label("직원", 44, UI.TEXT))
	var filters := UI.hbox(10)
	for pair in [["", "전체"], ["hr", "인사"], ["dv", "개발"], ["sl", "영업"]]:
		var b := UI.button(pair[1], UI.CARD, _set_filter.bind(pair[0]), 26)
		b.custom_minimum_size = Vector2(110, 64)
		_filter_buttons[pair[0]] = b
		filters.add_child(b)
	add_child(filters)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	add_child(UI.scroll(_grid))
	_set_filter("")


func _set_filter(team: String) -> void:
	_filter = team
	for key in _filter_buttons:
		UI.recolor(_filter_buttons[key], UI.PRIMARY if key == team else UI.CARD)
	for child in _grid.get_children():
		child.queue_free()
	for id in GameData.tower_ids + GameData.MYTHICS.keys():
		if team == "" or GameData.towers[id].team == team:
			_grid.add_child(_card(id))


func _card(id: String) -> Control:
	var t: Dictionary = GameData.towers[id]
	var grade := int(t.towerGrade)
	var locked := GameData.MYTHICS.has(id) and not GameData.mythic_unlocked(Save.user, id)
	var parts := UI.card_button(UI.CARD, _open.bind(id))
	var b: Button = parts[0]
	var v: VBoxContainer = parts[1]
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var frame := UI.panel(Color(GameData.TEAM_COLORS[t.team], 0.22), 14, 6)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait := UI.icon(GameData.asset(t.towerImagePath), 150)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	frame.add_child(portrait)
	if locked:
		portrait.modulate = Color(0.18, 0.18, 0.22)
		var p := GameData.mythic_progress(Save.user, id)
		var lock := UI.label("잠김\n%d/%d명" % [p[0], p[1]], 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(lock)
	v.add_child(frame)
	var name_label := UI.label(t.towerName, 24, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.clip_text = true
	v.add_child(name_label)
	var info := UI.hbox(6)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		info.add_child(UI.label("해금 필요", 22, UI.DANGER))
	else:
		info.add_child(UI.label("Lv.%d" % Save.user.towers[GameData.level_source(id)], 22, UI.GOLD))
	info.add_child(UI.label(GameData.GRADE_NAMES[grade - 1], 22, GameData.grade_color(grade)))
	v.add_child(info)
	return b


static func stats_text(id: String, level: int) -> String:
	var t: Dictionary = GameData.towers[id]
	var bonus := GameData.stat_bonus(Save.user, t.team)
	var level_mult := 1.0 + float(t.towerAttackMult) * (level - 1)
	return "물리 공격력 %.1f / 마법 공격력 %.1f\n공격 속도 %.2f / 사거리 %d칸" % [
		float(t.towerPhysicalAttack) * level_mult * bonus.physical,
		float(t.towerMagicAttack) * level_mult * bonus.magic,
		float(t.towerAttackSpeed) * bonus.speed,
		int(t.towerAttackRange)]


func _open(id: String) -> void:
	var t: Dictionary = GameData.towers[id]
	var skill: Dictionary = GameData.skill_for_tower(t)
	var grade := int(t.towerGrade)
	var v := UI.vbox(14)

	var top := UI.hbox(20)
	var frame := UI.panel(Color(GameData.TEAM_COLORS[t.team], 0.25), 18, 8)
	var portrait := UI.icon(GameData.asset(t.towerImagePath), 200)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	frame.add_child(portrait)
	# 초상화를 누르면 크게 본다
	frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	frame.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_zoom(portrait.texture))
	top.add_child(frame)
	var info := UI.vbox(8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_child(UI.label("%s팀  |  %d등급 %s" % [GameData.team_name(t.team), grade, GameData.GRADE_NAMES[grade - 1]], 26,
			GameData.grade_color(grade)))
	var level_label := UI.label("", 30)
	info.add_child(level_label)
	var stats := UI.label("", 22, UI.MUTED)
	info.add_child(stats)
	top.add_child(info)
	v.add_child(top)

	var skill_box := UI.panel(UI.CARD, 16, 16)
	var sv := UI.vbox(8)
	skill_box.add_child(sv)
	var skill_head := UI.hbox(12)
	if skill.has("skillImagePath"):
		skill_head.add_child(UI.icon(GameData.asset(skill.skillImagePath), 56))
	skill_head.add_child(UI.label("스킬: " + skill.skillName, 30, Color("9fc3ff")))
	sv.add_child(skill_head)
	# 신화 스킬은 GameData.MYTHICS 에 정의되어 설명 키가 description 이다
	var description: String = skill.get("skillDescription", skill.get("description", ""))
	sv.add_child(UI.wrap_label("%s\n(쿨타임 %d초)" % [description, int(skill.cooldown)], 24, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(skill_box)

	if GameData.MYTHICS.has(id):
		_fill_mythic(id, v, level_label, stats)
		UI.modal(t.towerName, v, [["닫기", UI.CARD_HI]], main)
		return

	var level_up := UI.button("", UI.SUCCESS)
	level_up.custom_minimum_size.y = 90
	v.add_child(level_up)
	var refresh := func():
		var level: int = Save.user.towers[id]
		var maxed := level >= GameData.MAX_TOWER_LEVEL
		level_label.text = "레벨 %d%s" % [level, " (최대)" if maxed else ""]
		stats.text = stats_text(id, level)
		level_up.disabled = maxed
		level_up.text = "최대 레벨" if maxed else "레벨 업  (%d 골드)" % GameData.tower_upgrade_cost(t, level)
	level_up.pressed.connect(func():
		var level: int = Save.user.towers[id]
		if level >= GameData.MAX_TOWER_LEVEL:
			return
		if not Save.spend_gold(GameData.tower_upgrade_cost(t, level)):
			UI.toast("골드가 부족합니다", UI.DANGER)
			return
		Save.user.towers[id] = level + 1
		Save.save()
		refresh.call()
		_set_filter(_filter))
	refresh.call()
	UI.modal(t.towerName, v, [["닫기", UI.CARD_HI]], main)


## 신화 상세: 레벨은 바탕 직원을 따르고 레벨 업 대신 조합식과 해금 조건을 보여 준다
func _fill_mythic(id: String, v: VBoxContainer, level_label: Label, stats: Label) -> void:
	var m: Dictionary = GameData.MYTHICS[id]
	var source := GameData.level_source(id)
	var level: int = Save.user.towers[source]
	level_label.text = "레벨 %d" % level
	stats.text = stats_text(id, level) + "\n(%s의 레벨을 따릅니다)" % GameData.towers[source].towerName
	var box := UI.panel(UI.CARD, 16, 16)
	var bv := UI.vbox(8)
	box.add_child(bv)
	var names: Array = ([m.base] + m.recipe).map(func(n): return GameData.towers[n].towerName)
	bv.add_child(UI.label("조합식", 28, GameData.grade_color(GameData.MYTHIC_GRADE)))
	bv.add_child(UI.wrap_label(" + ".join(names), 24, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	bv.add_child(UI.wrap_label("전투에서 %s을(를) 누르고 '신화 각성'을 누르면 각성합니다." % names[0], 22, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	if GameData.mythic_unlocked(Save.user, id):
		bv.add_child(UI.label("해금 완료", 26, UI.SUCCESS))
	else:
		bv.add_child(UI.label("잠김", 26, UI.DANGER))
		bv.add_child(UI.wrap_label(GameData.mythic_lock_text(Save.user, id) + "\n해금 전에는 전투에서 각성할 수 없습니다.", 22, UI.DANGER, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(box)


func _zoom(texture: Texture2D) -> void:
	var big := UI.icon_texture(texture, 0)
	big.custom_minimum_size = Vector2(540, 720)
	big.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	UI.modal("", big, [["닫기", UI.CARD_HI]], main)
