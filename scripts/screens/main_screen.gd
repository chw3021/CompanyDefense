# 메인 화면: 위쪽 정보 막대, 탭 내용, 아래쪽 탭 메뉴. 메일함과 메뉴 창도 여기서 연다.
extends Control

const TABS := [
	["스테이지", "res://assets/menu/stage.svg", "res://scripts/screens/tabs/stage_tab.gd"],
	["직원", "res://assets/menu/human.svg", "res://scripts/screens/tabs/employee_tab.gd"],
	["취미", "res://assets/menu/hobbies.svg", "res://scripts/screens/tabs/hobby_tab.gd"],
	["사무용품", "res://assets/menu/auto.svg", "res://scripts/screens/tabs/equipment_tab.gd"],
]

## 이 화면을 열 때 보여 줄 탭 (UI.go 의 setup 에서 바꿀 수 있다)
var start_tab := 0

var _gold_pill: PanelContainer
var _time_pill: PanelContainer
var _mail_button: Button
var _mail_badge: Label
var _mission_badge: Label
var _content: Control
var _nav_buttons: Array[Button] = []
var _current_tab := -1
var _exit_modal: Control


func _ready() -> void:
	if not Save.has_user():
		Save.create_user(Save.DEFAULT_NAME)
	UI.backdrop(self, "res://assets/menu/menu_background.jpg", 0.82)
	var root := UI.vbox(0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(_build_top_bar())
	_content = MarginContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		_content.add_theme_constant_override("margin_" + side, 20)
	_content.add_theme_constant_override("margin_top", 10)
	root.add_child(_content)
	root.add_child(_build_nav())
	Save.changed.connect(refresh_top_bar)
	refresh_top_bar()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(func():
		Save.refresh_time()
		refresh_top_bar())
	add_child(timer)
	show_tab(start_tab)
	# 웹에서 구글 로그인 페이지를 다녀온 결과 (화면보다 먼저 끝났거나, 나중에 끝나거나)
	Account.login_done.connect(_on_redirect_login)
	var pending = Account.take_pending()
	if pending != null:
		_after_login(pending)


func _on_redirect_login(_error: String) -> void:
	var pending = Account.take_pending()
	if pending != null:
		_after_login(pending)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(_exit_modal):
			UI.close_modal(_exit_modal)
			return
		_exit_modal = UI.modal("게임 종료", UI.label("게임을 종료할까요?", 30, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER), [
			["취소", UI.CARD_HI],
			["종료", UI.DANGER, func(): get_tree().quit()],
		], self)


# ------------------------------------------------------------------ 위쪽 막대

func _safe_top() -> float:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	return 0.0 if screen.y <= 0 else safe.position.y * get_viewport_rect().size.y / screen.y


func _build_top_bar() -> Control:
	var bar := UI.panel(Color(UI.PANEL, 0.92), 0, 0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14 + int(_safe_top()))
	margin.add_theme_constant_override("margin_bottom", 14)
	bar.add_child(margin)
	var row := UI.hbox(10)
	margin.add_child(row)
	_gold_pill = UI.pill("res://assets/icons/coin.svg", "", UI.GOLD)
	row.add_child(_gold_pill)
	_time_pill = UI.pill("res://assets/icons/waste.svg", "")
	row.add_child(_time_pill)
	row.add_child(UI.spacer(0, false))

	var mission_button := UI.button("미션", UI.CARD_HI, open_missions, 26)
	mission_button.custom_minimum_size = Vector2(100, 68)
	_mission_badge = _badge(mission_button)
	row.add_child(mission_button)

	_mail_button = UI.button("메일", UI.CARD_HI, open_mailbox, 26)
	_mail_button.custom_minimum_size = Vector2(100, 68)
	_mail_badge = _badge(_mail_button)
	row.add_child(_mail_button)

	var menu := UI.button("", UI.CARD_HI, open_menu)
	menu.icon = load("res://assets/menu/menu.svg")
	menu.expand_icon = true
	menu.custom_minimum_size = Vector2(68, 68)
	row.add_child(menu)
	return bar


## 버튼 오른쪽 위의 빨간 숫자 배지
func _badge(b: Button) -> Label:
	var badge := UI.label("", 20, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	badge.add_theme_stylebox_override("normal", UI.box(UI.DANGER, 14, 2))
	badge.custom_minimum_size = Vector2(30, 28)
	badge.position = Vector2(76, -8)
	b.add_child(badge)
	return badge


func refresh_top_bar() -> void:
	if not Save.has_user():
		return
	_gold_pill.get_meta("text").text = str(Save.gold())
	var t: int = Save.user.time
	var text := str(t) if t > Save.MAX_TIME else "%d/%d" % [t, Save.MAX_TIME]
	var left := Save.seconds_until_next_time()
	if left > 0:
		text += "  %d:%02d" % [left / 60, left % 60]
	_time_pill.get_meta("text").text = text
	var unclaimed := Save.unclaimed_mail_count()
	_mail_badge.visible = unclaimed > 0
	_mail_badge.text = str(unclaimed)
	var ready := Missions.claimable_count(Save.user)
	_mission_badge.visible = ready > 0
	_mission_badge.text = str(ready)


# ------------------------------------------------------------------ 탭

func _build_nav() -> Control:
	var bar := UI.panel(Color(UI.PANEL, 0.96), 0, 0)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 22)
	bar.add_child(margin)
	var row := UI.hbox(8)
	margin.add_child(row)
	for i in TABS.size():
		var b := Button.new()
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 120
		b.icon = load(TABS[i][1])
		b.expand_icon = true
		b.text = TABS[i][0]
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_constant_override("icon_max_width", 60)
		var idle := UI.box(Color(0, 0, 0, 0), 18, 10)
		var active := UI.box(Color(UI.PRIMARY, 0.22), 18, 10)
		for state in ["normal", "hover", "focus", "disabled"]:
			b.add_theme_stylebox_override(state, idle)
		for state in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, active)
		b.add_theme_color_override("font_color", UI.MUTED)
		b.add_theme_color_override("font_pressed_color", UI.TEXT)
		b.add_theme_color_override("font_hover_pressed_color", UI.TEXT)
		b.pressed.connect(show_tab.bind(i))
		_nav_buttons.append(b)
		row.add_child(b)
	return bar


func show_tab(index: int) -> void:
	for i in _nav_buttons.size():
		_nav_buttons[i].set_pressed_no_signal(i == index)
	if index == _current_tab:
		return
	_current_tab = index
	for child in _content.get_children():
		child.queue_free()
	var tab: Control = load(TABS[index][2]).new()
	tab.set("main", self)
	_content.add_child(tab)
	tab.modulate.a = 0
	tab.create_tween().tween_property(tab, "modulate:a", 1.0, 0.15)


# ------------------------------------------------------------------ 메일함

func open_mailbox() -> void:
	var list := UI.vbox(12)
	var scroll := UI.scroll(list)
	scroll.custom_minimum_size = Vector2(620, 640)
	_fill_mails(list)
	var actions := UI.hbox(10)
	var claim_all := UI.button("모두 받기", UI.SUCCESS, func():
		for mail in Save.user.mails.duplicate():
			if Save.mail_has_reward(mail) and not mail.claimed:
				Save.claim_mail(mail)
		_fill_mails(list), 26)
	var delete := UI.button("받은 메일 삭제", UI.CARD_HI, func():
		Save.delete_claimed_mails()
		_fill_mails(list), 26)
	for b in [claim_all, delete]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 76
		actions.add_child(b)
	var v := UI.vbox(16)
	v.add_child(scroll)
	v.add_child(actions)
	UI.modal("메일함", v, [["닫기", UI.CARD_HI]], self)


func _fill_mails(list: VBoxContainer) -> void:
	for child in list.get_children():
		child.queue_free()
	if Save.user.mails.is_empty():
		list.add_child(UI.label("받은 메일이 없습니다.", 28, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		return
	for mail: Dictionary in Save.user.mails:
		var claimable: bool = Save.mail_has_reward(mail) and not mail.claimed
		var card := UI.panel(UI.CARD if claimable else Color(UI.CARD, 0.5), 16, 18)
		var v := UI.vbox(8)
		card.add_child(v)
		var head := UI.hbox(10)
		var title := UI.label(mail.title, 28, UI.GOLD if claimable else UI.MUTED)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.add_child(title)
		if Save.mail_has_reward(mail):
			var b := UI.button("받기" if claimable else "받음", UI.SUCCESS, func():
				Save.claim_mail(mail)
				UI.toast("보상을 받았습니다!", UI.GOLD)
				_fill_mails(list), 24)
			b.disabled = not claimable
			b.custom_minimum_size = Vector2(110, 64)
			head.add_child(b)
		v.add_child(head)
		v.add_child(UI.wrap_label(mail.content, 24, UI.TEXT if claimable else UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
		if Save.mail_has_reward(mail):
			var rewards := UI.hbox(18)
			if int(mail.gold) > 0:
				rewards.add_child(UI.coin_row(str(int(mail.gold)), 24))
			if int(mail.time) > 0:
				var t := UI.hbox(6)
				t.add_child(UI.icon("res://assets/icons/waste.svg", 24))
				t.add_child(UI.label("시간 %d" % int(mail.time), 24, Color("7fd3ff")))
				rewards.add_child(t)
			v.add_child(rewards)
		list.add_child(card)


# ------------------------------------------------------------------ 미션 / 업적

func open_missions() -> void:
	var list := UI.vbox(12)
	var scroll := UI.scroll(list)
	scroll.custom_minimum_size = Vector2(620, 700)
	var tabs := UI.hbox(10)
	var daily_tab := UI.button("일일 미션", UI.PRIMARY, Callable(), 26)
	var achieve_tab := UI.button("업적", UI.CARD_HI, Callable(), 26)
	var switch_tab := func(daily: bool):
		UI.recolor(daily_tab, UI.PRIMARY if daily else UI.CARD_HI)
		UI.recolor(achieve_tab, UI.CARD_HI if daily else UI.PRIMARY)
		if daily:
			_fill_daily(list)
		else:
			_fill_achievements(list)
		scroll.scroll_vertical = 0
	daily_tab.pressed.connect(switch_tab.bind(true))
	achieve_tab.pressed.connect(switch_tab.bind(false))
	for b in [daily_tab, achieve_tab]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 72
		tabs.add_child(b)
	var v := UI.vbox(14)
	v.add_child(tabs)
	v.add_child(scroll)
	switch_tab.call(true)
	UI.modal("미션", v, [["닫기", UI.CARD_HI]], self)


func _fill_daily(list: VBoxContainer) -> void:
	for child in list.get_children():
		child.queue_free()
	var left := Missions.seconds_until_reset()
	list.add_child(UI.label("매일 자정에 새 미션 (%d시간 %d분 남음)" % [left / 3600, left % 3600 / 60], 24, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var d := Missions.daily(Save.user)
	for m: Dictionary in d.missions:
		var def := Missions.daily_def(m.id)
		var state := "claimed" if m.claimed else ("ready" if Missions.daily_done(m) else "progress")
		list.add_child(_mission_card(def.desc % def.goal, "", int(m.progress), int(def.goal), int(def.gold), 0, state, func():
			if Save.claim_daily(m):
				UI.toast("보상을 받았습니다!", UI.GOLD)
			_fill_daily(list)))
	var done: int = d.missions.filter(func(m): return Missions.daily_done(m)).size()
	var bonus_state := "claimed" if d.bonus_claimed else ("ready" if Missions.daily_all_done(Save.user) else "progress")
	list.add_child(_mission_card("오늘의 미션 모두 완료", "보너스", done, d.missions.size(), Missions.DAILY_BONUS_GOLD,
			Missions.DAILY_BONUS_TIME, bonus_state, func():
				if Save.claim_daily_bonus():
					UI.toast("보너스를 받았습니다!", UI.GOLD)
				_fill_daily(list)))


func _fill_achievements(list: VBoxContainer) -> void:
	for child in list.get_children():
		child.queue_free()
	# 받을 수 있는 것을 위로
	var order := Missions.ACHIEVEMENTS.duplicate()
	order.sort_custom(func(a, b): return Missions.achievement_ready(Save.user, a) and not Missions.achievement_ready(Save.user, b))
	for a: Dictionary in order:
		var tier := Missions.next_tier(Save.user, a)
		var claimed := Missions.claimed_tiers(Save.user, a)
		var stage := "%s  (%d/%d단계)" % [a.name, claimed, a.tiers.size()]
		var value := Missions.stat_value(Save.user, a.stat)
		if tier.is_empty():
			var last: Array = a.tiers[a.tiers.size() - 1]
			list.add_child(_mission_card(a.desc % last[0], stage, int(last[0]), int(last[0]), 0, 0, "claimed", Callable()))
			continue
		var state := "ready" if Missions.achievement_ready(Save.user, a) else "progress"
		list.add_child(_mission_card(a.desc % tier[0], stage, value, int(tier[0]), int(tier[1]), 0, state, func():
			if Save.claim_achievement(a):
				UI.toast("업적 달성! %s" % a.name, UI.GOLD)
			_fill_achievements(list)))


## 미션 한 줄: 제목, 진행 막대, 보상, 받기 버튼. state = progress / ready / claimed
func _mission_card(title: String, sub: String, value: int, goal: int, gold: int, time: int, state: String, on_claim: Callable) -> Control:
	var ready := state == "ready"
	var card := UI.panel(UI.CARD if state != "claimed" else Color(UI.CARD, 0.5), 16, 16)
	var row := UI.hbox(14)
	card.add_child(row)
	var v := UI.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	if sub != "":
		v.add_child(UI.label(sub, 22, UI.GOLD if ready else UI.MUTED))
	var title_label := UI.label(title, 27, UI.TEXT if state != "claimed" else UI.MUTED)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title_label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.max_value = maxi(1, goal)
	bar.value = mini(value, goal)
	bar.add_theme_stylebox_override("background", UI.box(Color(0, 0, 0, 0.4), 7, 0))
	bar.add_theme_stylebox_override("fill", UI.box(UI.SUCCESS if value >= goal else UI.PRIMARY, 7, 0))
	v.add_child(bar)
	var info := UI.hbox(16)
	info.add_child(UI.label("%d / %d" % [mini(value, goal), goal], 22, UI.MUTED))
	if gold > 0:
		info.add_child(UI.coin_row(str(gold), 22))
	if time > 0:
		var t := UI.hbox(6)
		t.add_child(UI.icon("res://assets/icons/waste.svg", 22))
		t.add_child(UI.label("시간 %d" % time, 22, Color("7fd3ff")))
		info.add_child(t)
	v.add_child(info)
	var b := UI.button({"ready": "받기", "claimed": "완료"}.get(state, "진행 중"), UI.SUCCESS if ready else UI.CARD_HI, on_claim, 24)
	b.disabled = not ready
	b.custom_minimum_size = Vector2(120, 72)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	return card


# ------------------------------------------------------------------ 메뉴

func open_menu() -> void:
	var v := UI.vbox(12)
	var name_label := UI.label("사원: " + Save.user.name, 32, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(name_label)
	v.add_child(UI.spacer(6))
	# 람다는 지역 변수를 값으로 잡으므로, 버튼보다 나중에 만들어지는 메뉴 창은 딕셔너리에 담아 넘긴다
	var ctx := {}
	var items := [
		["내 정보", UI.PRIMARY, func():
			UI.close_modal(ctx.modal)
			_open_profile()],
		["내 기록", UI.PRIMARY, _open_records],
		["닉네임 변경", UI.PRIMARY, func():
			UI.close_modal(ctx.modal)
			_change_nickname()],
		["설정", UI.PRIMARY, _open_settings],
		["데이터 초기화", UI.DANGER, func():
			UI.close_modal(ctx.modal)
			_confirm_reset()],
	]
	for item in items:
		var b := UI.button(item[0], item[1], item[2])
		b.custom_minimum_size.y = 86
		v.add_child(b)
	ctx.modal = UI.modal("메뉴", v, [["닫기", UI.CARD_HI]], self)


func _open_records() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 12)
	grid.add_child(UI.label("스테이지", 26, UI.GOLD))
	grid.add_child(UI.label("최고 점수", 26, UI.GOLD, HORIZONTAL_ALIGNMENT_RIGHT))
	for id in range(1, StageDefs.COUNT + 1):
		var cleared: bool = id <= Save.user.max_cleared
		grid.add_child(UI.label("%d. %s%s" % [id, StageDefs.STAGES[id].name, "  (클리어)" if cleared else ""], 26,
				UI.SUCCESS if cleared else UI.TEXT))
		var best = Save.user.best_scores.get(str(id))
		var score := UI.label(str(best) if best != null else "-", 26, UI.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(score)
	var played: int = Save.user.games_played
	var won: int = Save.user.games_won
	var rate := 0 if played == 0 else roundi(100.0 * won / played)
	var v := UI.vbox(18)
	var box := UI.panel(UI.CARD, 16, 20)
	box.add_child(grid)
	v.add_child(box)
	v.add_child(UI.label("플레이 %d회 / 승리 %d회 (%d%%)\n최고 점수 %d" % [played, won, rate, Save.user.high_score], 28,
			UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	UI.modal("내 기록", v, [["닫기", UI.CARD_HI]], self)


## 내 정보: 계정 요약과 구글 계정 연동 (클라우드 저장)
func _open_profile() -> void:
	var u: Dictionary = Save.user
	var level_sum := 0
	for id in u.towers:
		level_sum += int(u.towers[id])
	var v := UI.vbox(16)
	var info := UI.panel(UI.CARD, 16, 20)
	info.add_child(UI.label("닉네임: %s\n스테이지 클리어: %d / %d\n무한 야근 최고 라운드: %d\n플레이 %d회 / 승리 %d회\n보유 골드: %d\n직원 레벨 합계: %d" % [
			u.name, u.max_cleared, StageDefs.COUNT, u.round_best, u.games_played, u.games_won, u.gold, level_sum], 26))
	v.add_child(info)
	var box := UI.panel(UI.CARD, 16, 20)
	var bv := UI.vbox(12)
	box.add_child(bv)
	bv.add_child(UI.label("계정 연동", 30, UI.GOLD))
	var status := UI.wrap_label("", 24, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	bv.add_child(status)
	v.add_child(box)
	# 람다는 지역 변수를 값으로 잡으므로, 나중에 만들어지는 창은 딕셔너리에 담아 넘긴다
	var ctx := {}
	var specs := []
	if Account.is_linked():
		status.text = "구글 계정: %s\n진행 상황이 자동으로 클라우드에 저장됩니다." % Account.email
		specs = [
			["지금 클라우드에 저장", UI.PRIMARY, func():
				UI.toast("클라우드에 저장했습니다." if await Account.upload() else "클라우드 저장에 실패했습니다.", UI.GOLD)],
			["클라우드에서 불러오기", UI.PRIMARY, func():
				UI.close_modal(ctx.modal)
				_load_cloud()],
			["연동 해제", UI.DANGER, func():
				UI.modal("연동 해제", UI.wrap_label("연동을 해제해도 이 기기와 클라우드의 데이터는 지워지지 않습니다.\n해제할까요?", 26, UI.TEXT), [
					["취소", UI.CARD_HI],
					["해제", UI.DANGER, func():
						Account.unlink()
						UI.close_modal(ctx.modal)
						_open_profile()
						UI.toast("계정 연동을 해제했습니다.")],
				], self)],
		]
	else:
		status.text = "구글 계정을 연동하면 진행 상황이 클라우드에 저장되어 다른 기기에서도 이어서 할 수 있습니다."
		specs = [["구글 계정 연동", UI.SUCCESS, func():
			UI.close_modal(ctx.modal)
			_start_login()]]
	for spec in specs:
		var b := UI.button(spec[0], spec[1], spec[2], 26)
		b.custom_minimum_size.y = 76
		bv.add_child(b)
	ctx.modal = UI.modal("내 정보", v, [["닫기", UI.CARD_HI]], self)


func _start_login() -> void:
	if Account.use_redirect_login():
		if Account.web_client_id == "":
			UI.toast("계정 연동이 아직 준비되지 않았습니다.", UI.DANGER)
			return
		Save.save()
		Account.start_redirect_login()
		return
	var v := UI.vbox(14)
	var guide := UI.wrap_label("로그인 코드를 받는 중입니다...", 26, UI.TEXT)
	v.add_child(guide)
	var code := UI.label("", 56, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(code)
	var row := UI.hbox(10)
	v.add_child(row)
	var ctx := {"url": "https://www.google.com/device"}
	for spec in [["브라우저 열기", func(): OS.shell_open(ctx.url)], ["코드 복사", func():
			DisplayServer.clipboard_set(code.text)
			UI.toast("코드를 복사했습니다.")]]:
		var b := UI.button(spec[0], UI.PRIMARY, spec[1], 26)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 76
		row.add_child(b)
	row.visible = false
	var modal := UI.modal("구글 계정 연동", v, [["취소", UI.CARD_HI, Account.cancel_device_login]], self, false)
	var on_code := func(user_code: String, verification_url: String):
		ctx.url = verification_url
		code.text = user_code
		guide.text = "브라우저에서 %s 에 접속해 아래 코드를 입력하고 구글 계정으로 로그인해 주세요." % verification_url
		row.visible = true
	Account.device_code_ready.connect(on_code)
	var error: String = await Account.start_device_login()
	Account.device_code_ready.disconnect(on_code)
	UI.close_modal(modal)
	_after_login(error)


## 로그인 직후: 클라우드에 데이터가 있으면 어느 쪽을 쓸지 묻고, 없으면 이 기기 데이터를 올린다
func _after_login(error: String) -> void:
	if error != "":
		UI.toast(error, UI.DANGER)
		return
	if Account.is_super():
		Save.apply_rich_start()
		Save.save()
	var cloud = await Account.download()
	if cloud == null:
		UI.toast("계정은 연동되었지만 클라우드 데이터를 확인하지 못했습니다.", UI.WARN)
	elif cloud.is_empty():
		await Account.upload()
		UI.toast("구글 계정이 연동되었습니다. 이 기기 데이터를 클라우드에 저장했습니다.", UI.SUCCESS)
	else:
		_ask_cloud_or_local(cloud, "구글 계정이 연동되었습니다.\n")


func _load_cloud() -> void:
	var cloud = await Account.download()
	if cloud == null:
		UI.toast("클라우드 데이터를 불러오지 못했습니다.", UI.DANGER)
	elif cloud.is_empty():
		UI.toast("클라우드에 저장된 데이터가 없습니다.", UI.WARN)
	else:
		_ask_cloud_or_local(cloud, "")


func _ask_cloud_or_local(cloud: Dictionary, head: String) -> void:
	var summary := func(u: Dictionary) -> String:
		return "%s / 스테이지 %d 클리어 / 골드 %d" % [u.get("name", ""), int(u.get("max_cleared", 0)), int(u.get("gold", 0))]
	var text := "%s클라우드에 저장된 데이터가 있습니다.\n\n클라우드: %s\n이 기기: %s\n\n어느 데이터를 사용할까요?" % [
			head, summary.call(cloud.user), summary.call(Save.user)]
	UI.modal("데이터 선택", UI.wrap_label(text, 26, UI.TEXT), [
		["이 기기 데이터", UI.PRIMARY, func():
			UI.toast("이 기기 데이터를 클라우드에 저장했습니다." if await Account.upload() else "클라우드 저장에 실패했습니다.", UI.GOLD)],
		["클라우드 데이터", UI.SUCCESS, func():
			Save.replace_user(cloud.user)
			UI.go("res://scenes/main.tscn")
			UI.toast("클라우드 데이터를 불러왔습니다.", UI.SUCCESS)],
	], self, false)


func _change_nickname() -> void:
	const Title = preload("res://scripts/screens/title_screen.gd")
	Title.ask_nickname("새 닉네임", Save.user.name, func(nick: String):
		Save.set_user_name(nick)
		UI.toast("닉네임이 '%s'(으)로 변경되었습니다." % nick, UI.GOLD), self)


func _open_settings() -> void:
	var v := UI.vbox(18)
	var speed_button := UI.button("", UI.PRIMARY)
	speed_button.custom_minimum_size.y = 86
	var refresh := func(): speed_button.text = "게임 속도: x%d" % int(Save.game_speed())
	speed_button.pressed.connect(func():
		Save.set_game_speed(1.0 if Save.game_speed() >= 2.0 else 2.0)
		refresh.call())
	refresh.call()
	v.add_child(speed_button)
	# 스킬 이펙트 진하기: 낮출수록 이펙트 뒤의 직원과 적이 잘 보인다
	var fx_label := UI.label("", 26)
	var fx_slider := HSlider.new()
	fx_slider.min_value = 0.0
	fx_slider.max_value = 1.0
	fx_slider.step = 0.05
	fx_slider.value = Save.effect_alpha()
	fx_slider.custom_minimum_size.y = 48
	var fx_refresh := func(value: float): fx_label.text = "스킬 이펙트 진하기: %d%%" % roundi(value * 100)
	fx_slider.value_changed.connect(func(value: float):
		Save.set_effect_alpha(value)
		fx_refresh.call(value))
	fx_refresh.call(fx_slider.value)
	v.add_child(fx_label)
	v.add_child(fx_slider)
	v.add_child(UI.wrap_label("낮출수록 스킬 이펙트가 투명해져 직원과 적이 잘 보입니다.", 22, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(UI.wrap_label("컴퍼니 디펜스 v2.0\n데이터는 이 기기에 저장되며, 내 정보에서 구글 계정을 연동하면 클라우드에도 저장됩니다.\n\n사무실 이미지: pikisuperstar / Freepik\n글꼴: Jua (SIL OFL)", 24))
	UI.modal("설정", v, [["닫기", UI.CARD_HI]], self)


func _confirm_reset() -> void:
	var linked_note := "\n구글 계정 연동은 해제되며, 클라우드 데이터는 지워지지 않습니다." if Account.is_linked() else ""
	var text := UI.wrap_label("모든 진행 상황(골드, 레벨, 기록)이 삭제됩니다.%s\n정말 초기화할까요?" % linked_note, 28, UI.TEXT)
	UI.modal("데이터 초기화", text, [
		["취소", UI.CARD_HI],
		["초기화", UI.DANGER, func():
			# 새로 만든 데이터가 클라우드 데이터를 덮어쓰지 않도록 연동부터 푼다
			Account.unlink()
			Save.reset()
			UI.go("res://scenes/title.tscn")],
	], self)
