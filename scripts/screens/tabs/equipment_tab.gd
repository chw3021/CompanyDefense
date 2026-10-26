# 사무용품 탭: 골드로 구매/강화하는 영구 보너스
extends VBoxContainer

var main
var _cards := {}   # eqId -> {level, effect}


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	add_child(UI.label("사무용품", 44, UI.TEXT))
	add_child(UI.label("사무용품은 모든 스테이지에 적용됩니다", 24, UI.MUTED))
	var list := UI.vbox(12)
	for id in GameData.equipment_ids:
		list.add_child(_card(id))
	add_child(UI.scroll(list))
	_refresh()


static func level_text(level: int) -> String:
	return "미보유" if level <= 0 else "Lv.%d" % level


func _card(id: String) -> Control:
	var eq: Dictionary = GameData.equipment[id]
	var parts := UI.card_button(UI.CARD, _open.bind(id))
	var v: VBoxContainer = parts[1]
	var row := UI.hbox(16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := UI.panel(Color(0, 0, 0, 0.25), 16, 8)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(UI.icon(GameData.asset(eq.eqImagePath), 80))
	row.add_child(frame)
	var text := UI.vbox(4)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UI.hbox(10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(UI.label(eq.eqName, 30))
	var level := UI.label("", 24, UI.GOLD)
	head.add_child(level)
	text.add_child(head)
	var effect := UI.label("", 22, UI.MUTED)
	text.add_child(effect)
	row.add_child(text)
	v.add_child(row)
	_cards[id] = {"level": level, "effect": effect}
	return parts[0]


func _refresh() -> void:
	for id in _cards:
		var lv: int = Save.user.equipment[id]
		_cards[id].level.text = level_text(lv)
		_cards[id].level.add_theme_color_override("font_color", UI.GOLD if lv > 0 else UI.MUTED)
		var eq: Dictionary = GameData.equipment[id]
		_cards[id].effect.text = GameData.equipment_effect_text(eq, maxi(lv, 1)) + ("" if lv > 0 else " (구매 시)")


func _open(id: String) -> void:
	var eq: Dictionary = GameData.equipment[id]
	var v := UI.vbox(14)
	v.add_child(UI.icon(GameData.asset(eq.eqImagePath), 150))
	v.add_child(UI.wrap_label(eq.eqDescription, 26))
	var level_label := UI.label("", 32, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(level_label)
	var effect := UI.label("", 26, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(effect)
	var buy := UI.button("", UI.SUCCESS)
	buy.custom_minimum_size.y = 90
	v.add_child(buy)
	var refresh := func():
		var lv: int = Save.user.equipment[id]
		var maxed := lv >= GameData.MAX_EQUIPMENT_LEVEL
		level_label.text = "미보유" if lv <= 0 else "레벨 %d%s" % [lv, " (최대)" if maxed else ""]
		var text := "효과 없음" if lv <= 0 else "현재 효과: " + GameData.equipment_effect_text(eq, lv)
		if not maxed:
			text += "\n다음 레벨: " + GameData.equipment_effect_text(eq, lv + 1)
		effect.text = text
		buy.disabled = maxed
		buy.text = "최대 레벨" if maxed else "%s  (%d 골드)" % ["구매" if lv <= 0 else "강화", GameData.equipment_cost(eq, lv)]
	buy.pressed.connect(func():
		var lv: int = Save.user.equipment[id]
		if lv >= GameData.MAX_EQUIPMENT_LEVEL:
			return
		if not Save.spend_gold(GameData.equipment_cost(eq, lv)):
			UI.toast("골드가 부족합니다", UI.DANGER)
			return
		Save.user.equipment[id] = lv + 1
		Save.save()
		refresh.call()
		_refresh())
	refresh.call()
	UI.modal(eq.eqName, v, [["닫기", UI.CARD_HI]], main)
