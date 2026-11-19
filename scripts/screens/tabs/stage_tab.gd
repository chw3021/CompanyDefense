# 스테이지 선택 탭
class_name StageTab
extends VBoxContainer

const DIFFICULTY_COLORS := {"쉬움": Color("2fbf71"), "보통": Color("f0b43e"), "어려움": Color("e5534b"), "무한": Color("9b6bff")}
const RANK_SHOW_MAX := 50

var main


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	var header := UI.hbox(12)
	header.add_child(UI.label("스테이지 선택", 44, UI.TEXT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var rank_btn := UI.button("무한 랭킹", UI.GOLD, func(): open_endless_ranking(main if main else self), 24)
	rank_btn.custom_minimum_size = Vector2(150, 56)
	header.add_child(rank_btn)
	add_child(header)
	var list := UI.vbox(16)
	add_child(UI.scroll(list))
	for id in range(1, StageDefs.COUNT + 1):
		list.add_child(_stage_card(id))


func _stage_card(id: int) -> Control:
	var s: Dictionary = StageDefs.STAGES[id]
	var unlocked := Save.is_stage_unlocked(id)
	var cleared: bool = id <= Save.user.max_cleared
	var parts := UI.card_button(UI.CARD, func(): _open_stage(id))
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
	var name_l := UI.label(s.name, 36, UI.TEXT if unlocked else UI.MUTED)
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(name_l)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 6)
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


func _open_stage(id: int) -> void:
	if not Save.is_stage_unlocked(id):
		return
	var body := UI.vbox(12)
	body.add_child(UI.label("입장 전에 시작 코인을 받을 수 있습니다.\n(전투가 시작된 뒤에는 광고가 나오지 않습니다)", 24, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(UI.label("광고 보상: 시작 코인 +%d" % Save.START_COIN_AD_BONUS, 28, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var buttons := [
		["취소", UI.CARD_HI],
		["바로 시작", UI.PRIMARY, func():
			Save.set_pending_start_coin_bonus(0)
			UI.go("res://scenes/stage.tscn", func(scene): scene.stage_id = id)],
		["광고 후 시작", UI.SUCCESS, func():
			_start_with_coin_ad(id)],
	]
	if StageDefs.is_endless(id):
		buttons.insert(1, ["랭킹 보기", UI.GOLD, func(): open_endless_ranking(main if main else self)])
	UI.modal(StageDefs.STAGES[id].name, body, buttons, main)


## 무한 야근 클라우드 랭킹 모달 (로비·게임오버에서 공통 사용)
static func open_endless_ranking(parent: Node) -> void:
	var list := UI.vbox(10)
	var status := UI.label("랭킹을 불러오는 중입니다...", 26, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	list.add_child(status)
	var my_best: int = int(Save.user.get("round_best", 0)) if Save.has_user() else 0
	var my_score: int = int(Save.user.best_scores.get("4", 0)) if Save.has_user() else 0
	var mine := UI.panel(UI.CARD, 16, 16)
	mine.add_child(UI.label("내 최고 기록\n%d라운드 / 점수 %d" % [my_best, my_score], 26, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	list.add_child(mine)
	UI.modal("무한 야근 랭킹", UI.bind_modal_scroll(UI.scroll(list), 560, 640), [["닫기", UI.CARD_HI]], parent)
	await Account.queue_submit_endless_rank()
	var ranks = await Account.fetch_endless_ranks()
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	if is_instance_valid(status):
		status.queue_free()
	if ranks == null:
		list.add_child(UI.wrap_label(
				"클라우드 랭킹을 불러오지 못했습니다.\n인터넷 연결을 확인해 주세요.",
				24, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		return
	if ranks.is_empty():
		list.add_child(UI.label("아직 등록된 기록이 없습니다.\n무한 야근을 플레이해 보세요!", 26, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		return
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	grid.add_child(UI.label("순위", 24, UI.GOLD))
	grid.add_child(UI.label("닉네임", 24, UI.GOLD))
	grid.add_child(UI.label("라운드", 24, UI.GOLD, HORIZONTAL_ALIGNMENT_RIGHT))
	var shown := mini(ranks.size(), RANK_SHOW_MAX)
	for i in shown:
		var row: Dictionary = ranks[i]
		var color: Color = UI.SUCCESS if row.get("me", false) else UI.TEXT
		grid.add_child(UI.label(str(i + 1), 24, color))
		var nick := UI.label(str(row.get("name", Save.DEFAULT_NAME)), 24, color)
		nick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nick.clip_text = true
		nick.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		grid.add_child(nick)
		var rounds_l := UI.label(str(int(row.get("rounds", 0))), 24, color, HORIZONTAL_ALIGNMENT_RIGHT)
		rounds_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(rounds_l)
	var box := UI.panel(UI.CARD, 16, 16)
	box.add_child(grid)
	list.add_child(box)
	if ranks.size() > RANK_SHOW_MAX:
		list.add_child(UI.label("상위 %d명까지 표시합니다." % RANK_SHOW_MAX, 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))


func _start_with_coin_ad(id: int) -> void:
	if not await Ads.show_rewarded("start_coin"):
		return
	Save.set_pending_start_coin_bonus(Save.START_COIN_AD_BONUS)
	UI.toast("시작 코인 +%d 적용!" % Save.START_COIN_AD_BONUS, UI.GOLD)
	UI.go("res://scenes/stage.tscn", func(scene): scene.stage_id = id)


func _chip(text: String, color: Color) -> Label:
	var l := UI.label(text, 22, UI.TEXT)
	var sb := UI.box(Color(color, 0.85), 14, 0)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	l.add_theme_stylebox_override("normal", sb)
	return l
