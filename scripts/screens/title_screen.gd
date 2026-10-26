# 타이틀 화면. 처음이면 닉네임을 받아 계정을 만들고, 아니면 바로 출근한다.
extends Control

var _starting := false


func _ready() -> void:
	UI.backdrop(self, "res://assets/menu/menu_background.jpg", 0.25)
	# 아래쪽을 어둡게 해서 버튼과 글자가 잘 보이게
	var grad := TextureRect.new()
	var g := GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(UI.BG, 0.0))
	g.gradient.set_color(1, Color(UI.BG, 0.95))
	g.fill_from = Vector2(0, 0.35)
	g.fill_to = Vector2(0, 1)
	grad.texture = g
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(grad)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	margin.add_theme_constant_override("margin_top", 200)
	margin.add_theme_constant_override("margin_bottom", 140)
	add_child(margin)
	var v := UI.vbox(10)
	margin.add_child(v)

	var title := UI.outlined("컴퍼니 디펜스", 100, UI.TEXT, 18)
	v.add_child(title)
	v.add_child(UI.outlined("몰려오는 사무기기로부터 회사를 지켜라!", 32, Color("ffe7a3"), 10))
	v.add_child(UI.spacer())
	if Save.has_user():
		v.add_child(UI.outlined("%s 님, 오늘도 화이팅!" % Save.user.name, 34, UI.GOLD, 10))
	var start := UI.button("출근하기" if Save.has_user() else "입사하기", UI.PRIMARY, _on_start, 44)
	start.custom_minimum_size = Vector2(0, 120)
	v.add_child(start)

	# 제목이 살짝 떠다니는 연출
	title.pivot_offset = Vector2(300, 60)
	var tw := title.create_tween().set_loops()
	tw.tween_property(title, "position:y", -8.0, 1.6).as_relative().set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "position:y", 8.0, 1.6).as_relative().set_trans(Tween.TRANS_SINE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


func _on_start() -> void:
	if _starting:
		return
	if Save.has_user():
		_starting = true
		UI.go("res://scenes/main.tscn")
		return
	ask_nickname("닉네임을 입력하세요", "", func(nick: String):
		_starting = true
		Save.create_user(nick)
		UI.go("res://scenes/main.tscn"))


## 닉네임 입력 창. 빈 값이면 기본 이름, 최대 10자
static func ask_nickname(title: String, initial: String, on_done: Callable, parent: Node = null) -> void:
	var v := UI.vbox(14)
	var edit := LineEdit.new()
	edit.text = initial
	edit.placeholder_text = Save.DEFAULT_NAME
	edit.max_length = Save.NICKNAME_MAX
	edit.custom_minimum_size = Vector2(520, 90)
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(edit)
	v.add_child(UI.label("최대 %d자" % Save.NICKNAME_MAX, 22, UI.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var submit := func():
		var nick := edit.text.strip_edges().left(Save.NICKNAME_MAX)
		on_done.call(nick if nick != "" else Save.DEFAULT_NAME)
	var modal := UI.modal(title, v, [["확인", UI.PRIMARY, submit]], parent)
	edit.text_submitted.connect(func(_t):
		UI.close_modal(modal)
		submit.call())
	edit.grab_focus.call_deferred()
