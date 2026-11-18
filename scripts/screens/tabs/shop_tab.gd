# 상점 탭: 상품 구매 + 시즌 패스
extends VBoxContainer

const SeasonPass = preload("res://scripts/autoload/season_pass.gd")

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
		_hint.text = "%s  ·  Lv.%d  ·  받을 보상 %d개" % [
			SeasonPass.SEASON_NAME, lv, SeasonPass.claimable_count(Save.user)]
		_fill_pass()
	if main:
		main.refresh_top_bar()


func _fill_shop() -> void:
	for item: Dictionary in Save.SHOP_ITEMS:
		_body.add_child(_shop_card(item))


func _shop_card(item: Dictionary) -> Control:
	var locked := false
	var status := ""
	if item.get("unlock_pass", false) and Save.pass_data().premium:
		locked = true
		status = "보유 중"
	if item.get("no_ads", false) and Save.ads_removed():
		locked = true
		status = "보유 중"
	var card := UI.panel(UI.CARD if not locked else Color(UI.CARD, 0.55), 16, 16)
	var row := UI.hbox(12)
	card.add_child(row)
	var text := UI.vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(item.name, 28, UI.TEXT if not locked else UI.MUTED))
	text.add_child(UI.label(item.desc, 22, UI.MUTED))
	if int(item.get("cost_corp", 0)) > 0 and not item.get("ad", false):
		text.add_child(UI.label("법인카드 %d" % int(item.cost_corp), 24, UI.PURPLE))
	elif item.get("ad", false):
		text.add_child(UI.label("오늘 남은 횟수 %d" % Save.corp_ad_left(), 24, UI.GOLD))
	row.add_child(text)
	var label: String = status if locked else ("광고" if bool(item.get("ad", false)) else "구매")
	var b := UI.button(label, UI.SUCCESS if not locked else UI.CARD_HI, func(): _buy(item), 24)
	b.disabled = locked
	b.custom_minimum_size = Vector2(120, 72)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	return card


func _buy(item: Dictionary) -> void:
	if item.get("ad", false):
		_buy_corp_ad()
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
	var head := UI.panel(UI.CARD, 16, 16)
	var hv := UI.vbox(10)
	head.add_child(hv)
	hv.add_child(UI.label(SeasonPass.SEASON_NAME, 32, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
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
	hv.add_child(UI.label("한 판 +%d XP · 승리 시 +%d XP" % [SeasonPass.XP_PLAY, SeasonPass.XP_WIN], 20, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if p.premium:
		hv.add_child(UI.label("프리미엄 출근 패스 적용 중", 24, UI.SUCCESS, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		var unlock := UI.button("프리미엄 해금 (법인카드 %d)" % SeasonPass.PREMIUM_CORP_COST, UI.PURPLE, _unlock_premium, 24)
		unlock.custom_minimum_size.y = 72
		hv.add_child(unlock)
	_body.add_child(head)

	for level in range(1, SeasonPass.MAX_LEVEL + 1):
		_body.add_child(_pass_level_row(level, lv, p))


func _unlock_premium() -> void:
	if Save.pass_data().premium:
		UI.toast("이미 해금되어 있습니다.", UI.MUTED)
		return
	if Save.corp_card() < SeasonPass.PREMIUM_CORP_COST:
		UI.toast("법인카드가 부족합니다.", UI.WARN)
		return
	if Save.unlock_pass_premium():
		UI.toast("프리미엄 출근 패스를 해금했습니다!", UI.SUCCESS)
		_rebuild()


func _pass_level_row(level: int, reached: int, p: Dictionary) -> Control:
	var unlocked := level <= reached
	var card := UI.panel(UI.CARD if unlocked else Color(UI.CARD, 0.45), 14, 12)
	var row := UI.hbox(10)
	card.add_child(row)
	var badge := UI.label(str(level), 28, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	badge.custom_minimum_size = Vector2(56, 56)
	badge.add_theme_stylebox_override("normal", UI.box(UI.PRIMARY if unlocked else UI.LINE, 28, 0))
	row.add_child(badge)

	var free_r := SeasonPass.reward(level, false)
	var prem_r := SeasonPass.reward(level, true)
	var col := UI.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)

	col.add_child(_pass_claim_line("무료", free_r, level, false, unlocked, p))
	col.add_child(_pass_claim_line("프리미엄", prem_r, level, true, unlocked, p))
	return card


func _pass_claim_line(title: String, reward: Dictionary, level: int, premium: bool, unlocked: bool, p: Dictionary) -> Control:
	var line := UI.hbox(8)
	var locked_prem: bool = premium and not bool(p.premium)
	var claimed: bool = Save.is_pass_claimed(level, premium)
	var name_l := UI.label(title, 22, UI.GOLD if premium else UI.MUTED)
	name_l.custom_minimum_size.x = 90
	line.add_child(name_l)
	var desc := UI.label(SeasonPass.reward_text(reward), 22, UI.TEXT if unlocked else UI.MUTED)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.clip_text = true
	line.add_child(desc)
	var can: bool = unlocked and not claimed and not locked_prem and Save.can_claim_pass(level, premium)
	var b_text := "완료" if claimed else ("잠김" if locked_prem or not unlocked else "받기")
	var b := UI.button(b_text, UI.SUCCESS if can else UI.CARD_HI, func():
		if Save.claim_pass_reward(level, premium):
			UI.toast("%d레벨 %s 보상을 받았습니다!" % [level, title], UI.GOLD)
			_rebuild()
		else:
			UI.toast("받을 수 없습니다.", UI.WARN), 20)
	b.disabled = not can
	b.custom_minimum_size = Vector2(100, 52)
	line.add_child(b)
	return line
