# 스테이지 선택 탭
extends VBoxContainer

const DIFFICULTY_COLORS := {"쉬움": Color("2fbf71"), "보통": Color("f0b43e"), "어려움": Color("e5534b"), "무한": Color("9b6bff")}

var main


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	add_child(UI.label("스테이지 선택", 44, UI.TEXT))
	var list := UI.vbox(16)
	add_child(UI.scroll(list))
	for id in range(1, StageDefs.COUNT + 1):
		list.add_child(_stage_card(id))


func _stage_card(id: int) -> Control:
	var s: Dictionary = StageDefs.STAGES[id]
	var unlocked := Save.is_stage_unlocked(id)
	var cleared: bool = id <= Save.user.max_cleared
	var parts := UI.card_button(UI.CARD, func(): UI.go("res://scenes/stage.tscn", func(scene): scene.stage_id = id))
	var b: Button = parts[0]
	var v: VBoxContainer = parts[1]
	b.disabled = not unlocked
	b.custom_minimum_size.y = 170

	var row := UI.hbox(18)
	v.add_child(row)
	# 스테이지 번호 원
	var badge := UI.label(str(id), 48, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	badge.custom_minimum_size = Vector2(100, 100)
	badge.add_theme_stylebox_override("normal", UI.box(UI.PRIMARY if unlocked else UI.LINE, 50, 0))
	row.add_child(badge)

	var text := UI.vbox(6)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(UI.label(s.name, 40, UI.TEXT if unlocked else UI.MUTED))
	var chips := UI.hbox(10)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_child(_chip(s.difficulty, DIFFICULTY_COLORS[s.difficulty]))
	var endless := StageDefs.is_endless(id)
	chips.add_child(_chip("라운드 무한" if endless else "웨이브 %d" % s.waves.size(), UI.LINE))
	if cleared and not endless:
		chips.add_child(_chip("클리어", UI.SUCCESS))
	text.add_child(chips)
	if not unlocked:
		text.add_child(UI.label("이전 스테이지를 클리어하면 열립니다", 24, UI.MUTED))
	elif endless:
		var best_round: int = Save.user.get("round_best", 0)
		text.add_child(UI.label("최고 기록 라운드 %d" % best_round if best_round > 0 else "적 100마리가 모이기 전에 버텨 보세요!", 24, UI.GOLD))
	else:
		var best = Save.user.best_scores.get(str(id))
		if best != null:
			text.add_child(UI.label("최고 점수 %d" % best, 24, UI.GOLD))
	row.add_child(text)
	if unlocked:
		row.add_child(UI.icon_texture(UI.play_icon(), 40))
	return b


func _chip(text: String, color: Color) -> Label:
	var l := UI.label(text, 22, UI.TEXT)
	var sb := UI.box(Color(color, 0.85), 14, 0)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	l.add_theme_stylebox_override("normal", sb)
	return l
