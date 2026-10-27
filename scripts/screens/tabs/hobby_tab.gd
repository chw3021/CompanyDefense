# 취미 탭: 시간 1 을 써서 무작위 취미 레벨을 올린다
extends VBoxContainer

var main
var _cards := {}   # hobbyId -> {button, level, effect}
var _result: Label


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	add_child(UI.label("취미", 44, UI.TEXT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for id in GameData.hobby_ids:
		grid.add_child(_card(id))
	add_child(UI.scroll(grid))

	var go := UI.button("취미 활동 하기!  (시간 1)", UI.SUCCESS, _do_hobby, 34)
	go.icon = load("res://assets/icons/waste.svg")
	go.expand_icon = true
	go.custom_minimum_size.y = 110
	add_child(go)
	_result = UI.label("시간은 30분마다 1씩 충전됩니다", 26, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_result)
	_refresh()


func _card(id: String) -> Control:
	var h: Dictionary = GameData.hobbies[id]
	var parts := UI.card_button(UI.CARD, _open.bind(id))
	var b: Button = parts[0]
	var v: VBoxContainer = parts[1]
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UI.hbox(14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UI.icon(GameData.asset(h.hobbyImagePath), 84))
	var text := UI.vbox(2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(h.hobbyName, 30))
	var level := UI.label("", 24, UI.GOLD)
	text.add_child(level)
	var effect := UI.label("", 22, UI.MUTED)
	text.add_child(effect)
	row.add_child(text)
	v.add_child(row)
	_cards[id] = {"button": b, "level": level, "effect": effect}
	return b


func _refresh() -> void:
	for id in _cards:
		var lv: int = Save.user.hobbies[id]
		_cards[id].level.text = "Lv.%d" % lv
		_cards[id].effect.text = GameData.hobby_effect_text(id, lv)


func _do_hobby() -> void:
	if not Save.spend_time():
		_result.text = "시간이 부족합니다"
		_result.add_theme_color_override("font_color", UI.DANGER)
		return
	var id: String = GameData.hobby_ids.pick_random()
	Save.user.hobbies[id] += 1
	Save.save()
	_refresh()
	var h: Dictionary = GameData.hobbies[id]
	_result.text = "%s 레벨 업! (%s)" % [h.hobbyName, GameData.hobby_effect_text(id, Save.user.hobbies[id])]
	_result.add_theme_color_override("font_color", UI.SUCCESS)
	# 오른 카드를 반짝여 알려 준다
	var card: Button = _cards[id].button
	var tw := card.create_tween()
	for i in 2:
		tw.tween_property(card, "modulate", Color(1.6, 1.6, 1.2), 0.12)
		tw.tween_property(card, "modulate", Color.WHITE, 0.12)


func _open(id: String) -> void:
	var h: Dictionary = GameData.hobbies[id]
	var lv: int = Save.user.hobbies[id]
	var v := UI.vbox(14)
	var img := UI.icon(GameData.asset(h.hobbyImagePath), 180)
	v.add_child(img)
	v.add_child(UI.label("레벨 %d" % lv, 32, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.wrap_label(h.hobbyDescription, 26))
	v.add_child(UI.label("현재 효과: " + GameData.hobby_effect_text(id, lv), 28, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	UI.modal(h.hobbyName, v, [["닫기", UI.CARD_HI]], main)
