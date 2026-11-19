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
	go.icon = load("res://assets/icons/time.svg")
	go.expand_icon = true
	go.custom_minimum_size.y = 110
	add_child(go)
	var ad_row := UI.hbox(10)
	var time_ad := UI.button("광고로 시간 +%d" % Save.TIME_AD_AMOUNT, UI.PRIMARY, _watch_time_ad, 26)
	time_ad.icon = load("res://assets/icons/time.svg")
	time_ad.expand_icon = true
	time_ad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_ad.custom_minimum_size.y = 72
	ad_row.add_child(time_ad)
	var corp_ad := UI.button("광고로 법인카드", UI.PURPLE, _watch_corp_ad, 26)
	corp_ad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corp_ad.custom_minimum_size.y = 72
	ad_row.add_child(corp_ad)
	add_child(ad_row)
	_result = UI.label("시간은 30분마다 1씩 충전됩니다. 상단 시간/법인카드를 탭해도 됩니다.", 24, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
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
		_cards[id].level.text = "Lv.MAX" if GameData.hobby_maxed(id, lv) else "Lv.%d" % lv
		_cards[id].effect.text = GameData.hobby_effect_text(id, lv)


func _watch_time_ad() -> void:
	if Save.time_ad_left() <= 0:
		_result.text = "오늘은 시간 광고 한도에 도달했습니다"
		_result.add_theme_color_override("font_color", UI.MUTED)
		return
	if not await Ads.show_rewarded("time"):
		return
	var n := Save.grant_time_from_ad()
	if n <= 0:
		_result.text = "오늘은 더 이상 충전할 수 없습니다"
		_result.add_theme_color_override("font_color", UI.WARN)
		return
	_result.text = "시간 +%d! (오늘 남은 광고 %d회)" % [n, Save.time_ad_left()]
	_result.add_theme_color_override("font_color", UI.SUCCESS)
	if main:
		main.refresh_top_bar()


func _watch_corp_ad() -> void:
	if Save.corp_ad_left() <= 0:
		_result.text = "오늘은 법인카드 광고 한도에 도달했습니다"
		_result.add_theme_color_override("font_color", UI.MUTED)
		return
	if not await Ads.show_rewarded("corp_card"):
		return
	var n := Save.grant_corp_from_ad()
	if n <= 0:
		_result.text = "오늘은 더 이상 충전할 수 없습니다"
		_result.add_theme_color_override("font_color", UI.WARN)
		return
	_result.text = "법인카드 +%d! (오늘 남은 광고 %d회)" % [n, Save.corp_ad_left()]
	_result.add_theme_color_override("font_color", UI.PURPLE)
	if main:
		main.refresh_top_bar()


func _do_hobby() -> void:
	if not Save.spend_time():
		_result.text = "시간이 부족합니다. 광고로 충전할 수 있습니다."
		_result.add_theme_color_override("font_color", UI.DANGER)
		return
	# 최대 레벨에 닿은 취미는 더 오르지 않게 뽑기에서 뺀다
	var id: String = GameData.hobby_ids.filter(func(h): return not GameData.hobby_maxed(h, Save.user.hobbies[h])).pick_random()
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
	v.add_child(UI.label("레벨 MAX" if GameData.hobby_maxed(id, lv) else "레벨 %d" % lv, 32, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.wrap_label(h.hobbyDescription, 26))
	v.add_child(UI.label("현재 효과: " + GameData.hobby_effect_text(id, lv), 28, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	UI.modal(h.hobbyName, v, [["닫기", UI.CARD_HI]], main)
