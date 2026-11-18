# 상점 탭: 상품 그리드(이미지) + 일반/프리미엄 패스 트리
extends VBoxContainer

const SeasonPass = preload("res://scripts/autoload/season_pass.gd")

const ACCENTS := {
	"gold": Color("ffc940"),
	"purple": Color("9b6cff"),
	"blue": Color("4c8dff"),
	"danger": Color("e5534b"),
	"success": Color("2fbf71"),
}

var main
var _mode := "shop"  # shop | pass
var _body: VBoxContainer
var _shop_tab: Button
var _pass_tab: Button
var _hint: Label


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	add_child(UI.label("상점", 44, UI.TEXT))
	_hint = UI.label("", 22, UI.MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hint)
	var tabs := UI.hbox(10)
	_shop_tab = UI.button("상품", UI.PRIMARY, func(): _switch("shop"), 26)
	_pass_tab = UI.button("시즌 패스", UI.CARD_HI, func(): _switch("pass"), 26)
	for b in [_shop_tab, _pass_tab]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 68
		tabs.add_child(b)
	add_child(tabs)
	_body = UI.vbox(12)
	add_child(UI.scroll(_body))
	_switch("shop")


func _switch(mode: String) -> void:
	_mode = mode
	UI.recolor(_shop_tab, UI.PRIMARY if mode == "shop" else UI.CARD_HI)
	UI.recolor(_pass_tab, UI.PRIMARY if mode == "pass" else UI.CARD_HI)
	_rebuild()


func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	if _mode == "shop":
		_hint.text = "법인카드로 교환합니다. 현금 결제는 스토어 연동 후 붙일 예정입니다."
		_fill_shop()
	else:
		var p := Save.pass_data()
		var lv := SeasonPass.level_from_xp(int(p.xp))
		_hint.text = "%s / Lv.%d / 받을 보상 %d개" % [
			SeasonPass.SEASON_NAME, lv, SeasonPass.claimable_count(Save.user)]
		_fill_pass()
	if main:
		main.refresh_top_bar()


func _accent(item: Dictionary) -> Color:
	return ACCENTS.get(str(item.get("accent", "blue")), UI.PRIMARY)


func _fill_shop() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item: Dictionary in Save.SHOP_ITEMS:
		grid.add_child(_shop_card(item))
	_body.add_child(grid)


func _shop_card(item: Dictionary) -> Control:
	var locked := false
	var status := ""
	if item.get("unlock_pass", false) and Save.pass_data().premium:
		locked = true
		status = "보유 중"
	if item.get("no_ads", false) and Save.ads_removed():
		locked = true
		status = "보유 중"
	var accent := _accent(item)
	var bg := Color(UI.CARD.r, UI.CARD.g, UI.CARD.b, 1.0).lerp(accent, 0.12)
	if locked:
		bg = Color(UI.CARD, 0.55)
	var card := UI.panel(bg, 16, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 280)
	card.clip_contents = true
	var root := UI.vbox(0)
	card.add_child(root)

	var stripe := ColorRect.new()
	stripe.custom_minimum_size = Vector2(0, 8)
	stripe.color = accent if not locked else UI.LINE
	root.add_child(stripe)

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pad)
	var v := UI.vbox(8)
	pad.add_child(v)

	var frame := UI.panel(Color(0, 0, 0, 0.28), 18, 10)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var icon_path := str(item.get("icon", "res://assets/icons/coin.svg"))
	frame.add_child(UI.icon(icon_path, 72))
	v.add_child(frame)

	var title := UI.label(item.name, 24, UI.TEXT if not locked else UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	var desc := UI.label(item.desc, 18, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)

	if int(item.get("cost_corp", 0)) > 0 and not item.get("ad", false):
		var cost := UI.hbox(6)
		cost.alignment = BoxContainer.ALIGNMENT_CENTER
		cost.add_child(UI.icon("res://assets/icons/corp_card.svg", 26))
		cost.add_child(UI.label(str(int(item.cost_corp)), 24, UI.PURPLE))
		v.add_child(cost)
	elif item.get("ad", false):
		v.add_child(UI.label("오늘 %d회 남음" % Save.corp_ad_left(), 20, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	var label: String = status if locked else ("광고 보기" if bool(item.get("ad", false)) else ("패스 구매" if item.get("unlock_pass", false) else "구매"))
	var btn_color := UI.PURPLE if item.get("unlock_pass", false) else (UI.SUCCESS if not locked else UI.CARD_HI)
	var b := UI.button(label, btn_color, func(): _buy(item), 22)
	b.disabled = locked
	b.custom_minimum_size.y = 56
	v.add_child(b)
	return card


func _buy(item: Dictionary) -> void:
	if item.get("ad", false):
		_buy_corp_ad()
		return
	if item.get("unlock_pass", false):
		_offer_premium_purchase()
		return
	var msg := Save.buy_shop_item(str(item.id))
	if msg.begins_with("법인카드가") or msg.begins_with("이미") or msg.begins_with("상품") or msg.begins_with("저장"):
		UI.toast(msg, UI.WARN)
		return
	UI.toast(msg, UI.SUCCESS)
	_rebuild()


func _buy_corp_ad() -> void:
	if Save.corp_ad_left() <= 0:
		UI.toast("오늘은 법인카드 광고 한도에 도달했습니다.", UI.MUTED)
		return
	if not await Ads.show_rewarded("corp_card"):
		return
	var n := Save.grant_corp_from_ad()
	if n <= 0:
		UI.toast("오늘은 더 이상 충전할 수 없습니다.", UI.WARN)
		return
	UI.toast("법인카드 +%d!" % n, UI.PURPLE)
	_rebuild()


func _fill_pass() -> void:
	var p := Save.pass_data()
	var lv := SeasonPass.level_from_xp(int(p.xp))

	_body.add_child(_pass_status_banner(p, lv))
	_body.add_child(_pass_track_cards(p))

	var legend := UI.hbox(8)
	var free_l := UI.label("일반 패스", 22, UI.PRIMARY, HORIZONTAL_ALIGNMENT_CENTER)
	free_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend.add_child(free_l)
	var mid := UI.label("노드", 22, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	mid.custom_minimum_size.x = 64
	legend.add_child(mid)
	var prem_l := UI.label("프리미엄 패스", 22, UI.PURPLE, HORIZONTAL_ALIGNMENT_CENTER)
	prem_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend.add_child(prem_l)
	_body.add_child(legend)

	for level in range(1, SeasonPass.MAX_LEVEL + 1):
		_body.add_child(_pass_tree_node(level, lv, p))
		if level < SeasonPass.MAX_LEVEL:
			_body.add_child(_pass_connector(level < lv))


func _pass_status_banner(p: Dictionary, lv: int) -> Control:
	var head := UI.panel(UI.CARD.lerp(UI.PURPLE, 0.08), 16, 16)
	var hv := UI.vbox(10)
	head.add_child(hv)
	var title_row := UI.hbox(10)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_child(UI.icon("res://assets/icons/pass_free.svg", 40))
	title_row.add_child(UI.label(SeasonPass.SEASON_NAME, 30, UI.GOLD))
	title_row.add_child(UI.icon("res://assets/icons/pass_premium.svg", 40))
	hv.add_child(title_row)
	hv.add_child(UI.label("레벨 %d / %d" % [lv, SeasonPass.MAX_LEVEL], 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 18)
	bar.max_value = SeasonPass.XP_PER_LEVEL
	bar.value = SeasonPass.xp_into_level(int(p.xp)) if lv < SeasonPass.MAX_LEVEL else SeasonPass.XP_PER_LEVEL
	bar.add_theme_stylebox_override("background", UI.box(Color(0, 0, 0, 0.4), 8, 0))
	bar.add_theme_stylebox_override("fill", UI.box(UI.PURPLE, 8, 0))
	hv.add_child(bar)
	var xp_line := "MAX" if lv >= SeasonPass.MAX_LEVEL else "%d / %d XP" % [SeasonPass.xp_into_level(int(p.xp)), SeasonPass.XP_PER_LEVEL]
	hv.add_child(UI.label(xp_line, 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	hv.add_child(UI.label("한 판 +%d XP / 승리 시 +%d XP" % [SeasonPass.XP_PLAY, SeasonPass.XP_WIN], 20, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	return head


func _pass_track_cards(p: Dictionary) -> Control:
	var row := UI.hbox(10)
	# 일반 패스 (항상 활성)
	var free_card := UI.panel(UI.CARD.lerp(UI.PRIMARY, 0.15), 14, 12)
	free_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fv := UI.vbox(8)
	free_card.add_child(fv)
	fv.add_child(UI.icon("res://assets/icons/pass_free.svg", 56))
	fv.get_child(0).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fv.add_child(UI.label("일반 패스", 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	fv.add_child(UI.label("무료로 진행", 20, UI.SUCCESS, HORIZONTAL_ALIGNMENT_CENTER))
	fv.add_child(UI.label("레벨 보상 수령 가능", 18, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(free_card)

	# 프리미엄 패스 (결제 해금)
	var prem_bg := UI.CARD.lerp(UI.PURPLE, 0.2) if p.premium else UI.CARD.lerp(UI.PURPLE, 0.08)
	var prem_card := UI.panel(prem_bg, 14, 12)
	prem_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pv := UI.vbox(8)
	prem_card.add_child(pv)
	if p.premium:
		pv.add_child(UI.icon("res://assets/icons/pass_premium.svg", 56))
	else:
		pv.add_child(UI.icon("res://assets/icons/lock.svg", 56))
	pv.get_child(0).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pv.add_child(UI.label("프리미엄 패스", 26, UI.PURPLE, HORIZONTAL_ALIGNMENT_CENTER))
	if p.premium:
		pv.add_child(UI.label("구매 완료", 20, UI.SUCCESS, HORIZONTAL_ALIGNMENT_CENTER))
		pv.add_child(UI.label("유료 트랙 보상 해금됨", 18, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		pv.add_child(UI.label("잠김 - 결제 후 해금", 20, UI.WARN, HORIZONTAL_ALIGNMENT_CENTER))
		var buy := UI.button("패스 구매", UI.PURPLE, _offer_premium_purchase, 22)
		buy.custom_minimum_size.y = 56
		pv.add_child(buy)
		var price := UI.hbox(6)
		price.alignment = BoxContainer.ALIGNMENT_CENTER
		price.add_child(UI.icon("res://assets/icons/corp_card.svg", 24))
		price.add_child(UI.label(str(SeasonPass.PREMIUM_CORP_COST), 22, UI.PURPLE))
		pv.add_child(price)
	row.add_child(prem_card)
	return row


func _offer_premium_purchase() -> void:
	if Save.pass_data().premium:
		UI.toast("이미 프리미엄 패스를 보유 중입니다.", UI.MUTED)
		return
	var body := UI.vbox(12)
	body.add_child(UI.icon("res://assets/icons/pass_premium.svg", 96))
	body.get_child(0).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(UI.label("프리미엄 출근 패스", 30, UI.PURPLE, HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(UI.wrap_label("일반 패스와 별도로 프리미엄 트랙 보상을 받습니다.\n구매 즉시 골드 1,000 + 시간 2도 지급됩니다.\n(스토어 결제 연동 전: 법인카드로 결제)", 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var price := UI.hbox(8)
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	price.add_child(UI.icon("res://assets/icons/corp_card.svg", 32))
	price.add_child(UI.label("가격 %d" % SeasonPass.PREMIUM_CORP_COST, 28, UI.PURPLE))
	body.add_child(price)
	UI.modal("프리미엄 패스 구매", body, [
		["취소", UI.CARD_HI],
		["구매하기", UI.PURPLE, func():
			if Save.unlock_pass_premium():
				UI.toast("프리미엄 패스를 구매했습니다!", UI.SUCCESS)
				_rebuild()
				if main:
					main.refresh_top_bar()
			else:
				UI.toast("법인카드가 부족합니다.", UI.WARN)],
	], main if main else self)


func _pass_connector(reached: bool) -> Control:
	var wrap := CenterContainer.new()
	wrap.custom_minimum_size = Vector2(0, 18)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(6, 18)
	line.color = UI.PRIMARY if reached else UI.LINE
	wrap.add_child(line)
	return wrap


func _pass_tree_node(level: int, reached_lv: int, p: Dictionary) -> Control:
	var unlocked := level <= reached_lv
	var row := UI.hbox(8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var free_r := SeasonPass.reward(level, false)
	var prem_r := SeasonPass.reward(level, true)
	row.add_child(_pass_reward_cell(free_r, level, false, unlocked, p))

	var node := UI.label(str(level), 26, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	node.custom_minimum_size = Vector2(56, 56)
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var node_color := UI.SUCCESS if unlocked and Save.is_pass_claimed(level, false) and (not p.premium or Save.is_pass_claimed(level, true)) else (UI.PRIMARY if unlocked else UI.LINE)
	node.add_theme_stylebox_override("normal", UI.box(node_color, 28, 0))
	row.add_child(node)

	row.add_child(_pass_reward_cell(prem_r, level, true, unlocked, p))
	return row


func _pass_reward_cell(reward: Dictionary, level: int, premium: bool, unlocked: bool, p: Dictionary) -> Control:
	var locked_prem: bool = premium and not bool(p.premium)
	var claimed: bool = Save.is_pass_claimed(level, premium)
	var can: bool = unlocked and not claimed and not locked_prem and Save.can_claim_pass(level, premium)
	var bg := UI.CARD.lerp(UI.PURPLE, 0.12) if premium and not locked_prem else UI.CARD
	if locked_prem or not unlocked:
		bg = Color(UI.CARD, 0.45)
	var panel := UI.panel(bg, 10, 10)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(6)
	panel.add_child(v)
	if premium:
		if locked_prem:
			v.add_child(UI.icon("res://assets/icons/lock.svg", 36))
		else:
			v.add_child(UI.icon("res://assets/icons/pass_premium.svg", 28))
		v.get_child(0).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		v.add_child(UI.icon("res://assets/icons/pass_free.svg", 28))
		v.get_child(0).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var desc := UI.label(SeasonPass.reward_text(reward), 18, UI.TEXT if unlocked and not locked_prem else UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
	var b_text := "완료" if claimed else ("잠금" if locked_prem else ("잠김" if not unlocked else "받기"))
	var b := UI.button(b_text, UI.SUCCESS if can else UI.CARD_HI, func():
		if locked_prem:
			_offer_premium_purchase()
			return
		if Save.claim_pass_reward(level, premium):
			UI.toast("%d레벨 보상을 받았습니다!" % level, UI.GOLD)
			_rebuild()
		else:
			UI.toast("받을 수 없습니다.", UI.WARN), 18)
	b.disabled = not can and not locked_prem
	b.custom_minimum_size.y = 44
	v.add_child(b)
	return panel
