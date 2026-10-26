# 공통 UI: 색상 팔레트, 테마, 자주 쓰는 위젯 생성 헬퍼, 토스트, 모달 창, 화면 전환.
extends Node

const BG := Color("12161d")
const PANEL := Color("1c222c")
const CARD := Color("29313e")
const CARD_HI := Color("364052")
const LINE := Color("3f4a5c")
const TEXT := Color("f2f4f8")
const MUTED := Color("9aa4b2")
const GOLD := Color("ffc940")
const PRIMARY := Color("4c8dff")
const SUCCESS := Color("2fbf71")
const DANGER := Color("e5534b")
const WARN := Color("f0883e")
const PURPLE := Color("9b6cff")

const RADIUS := 18

var theme: Theme
var _toast_layer: CanvasLayer
var _fade: ColorRect


func _ready() -> void:
	theme = _build_theme()
	get_tree().root.theme = theme
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 100
	add_child(_toast_layer)
	_fade = ColorRect.new()
	_fade.color = Color(BG, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast_layer.add_child(_fade)


# ------------------------------------------------------------------ 테마

static func box(color: Color, radius := RADIUS, margin := 16, shadow := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = true
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 4)
	return sb


## 아래쪽이 조금 두꺼운 입체 버튼 모양
static func button_box(color: Color, pressed := false) -> StyleBoxFlat:
	var sb := box(color, 16, 14)
	sb.border_color = color.darkened(0.35)
	sb.border_width_bottom = 2 if pressed else 6
	sb.content_margin_top = 14 + (4 if pressed else 0)
	return sb


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 30

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))

	for state in ["normal", "hover", "focus"]:
		t.set_stylebox(state, "Button", button_box(PRIMARY))
	t.set_stylebox("pressed", "Button", button_box(PRIMARY.darkened(0.15), true))
	t.set_stylebox("disabled", "Button", button_box(Color("4a505c")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(TEXT, 0.55))
	t.set_constant("h_separation", "Button", 12)
	t.set_constant("icon_max_width", "Button", 56)

	t.set_stylebox("panel", "PanelContainer", box(CARD))
	t.set_stylebox("panel", "Panel", box(CARD))

	var line_edit := box(Color("0f1319"), 14, 18)
	line_edit.border_color = LINE
	line_edit.set_border_width_all(2)
	t.set_stylebox("normal", "LineEdit", line_edit)
	var line_focus := line_edit.duplicate() as StyleBoxFlat
	line_focus.border_color = PRIMARY
	t.set_stylebox("focus", "LineEdit", line_focus)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_font_size("font_size", "LineEdit", 34)

	var scroll_grabber := box(Color(1, 1, 1, 0.25), 6, 0)
	t.set_stylebox("grabber", "VScrollBar", scroll_grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", scroll_grabber)
	t.set_stylebox("grabber_pressed", "VScrollBar", scroll_grabber)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())

	var slider := box(Color("0f1319"), 8, 4)
	t.set_stylebox("slider", "HSlider", slider)
	var fill := box(PRIMARY, 8, 4)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)

	var progress_bg := box(Color("0f1319"), 10, 0)
	t.set_stylebox("background", "ProgressBar", progress_bg)
	t.set_stylebox("fill", "ProgressBar", box(SUCCESS, 10, 0))
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_font_size("font_size", "ProgressBar", 20)
	return t


# ------------------------------------------------------------------ 위젯

func label(text: String, size := 30, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## 테두리 글자 (맵 위에 띄우는 글자처럼 배경이 복잡한 곳에 쓴다)
func outlined(text: String, size := 30, color := TEXT, outline := 8) -> Label:
	var l := label(text, size, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", outline)
	return l


func button(text: String, color := PRIMARY, on_pressed: Callable = Callable(), size := 30) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	recolor(b, color)
	if on_pressed.is_valid():
		b.pressed.connect(on_pressed)
	b.pressed.connect(_click_feedback.bind(b))
	return b


func recolor(b: Button, color: Color) -> void:
	for state in ["normal", "hover"]:
		b.add_theme_stylebox_override(state, button_box(color))
	b.add_theme_stylebox_override("pressed", button_box(color.darkened(0.15), true))


var _play_icon: ImageTexture

## 흰색 재생 삼각형 (폰트에 ▶ 글자가 없어서 직접 만든다)
func play_icon() -> Texture2D:
	if _play_icon == null:
		var size := 48
		var tri := PackedVector2Array([Vector2(10, 5), Vector2(10, 43), Vector2(43, 24)])
		var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				# 픽셀마다 4x4 표본으로 가장자리를 부드럽게
				var hits := 0
				for sy in 4:
					for sx in 4:
						if Geometry2D.is_point_in_polygon(Vector2(x + (sx + 0.5) / 4.0, y + (sy + 0.5) / 4.0), tri):
							hits += 1
				image.set_pixel(x, y, Color(1, 1, 1, hits / 16.0))
		_play_icon = ImageTexture.create_from_image(image)
	return _play_icon


func icon(path: String, size: float) -> TextureRect:
	return icon_texture(load(path), size)


func icon_texture(texture: Texture2D, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## 코인 아이콘 + 숫자
func coin_row(amount_text: String, size := 28, color := GOLD) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon("res://assets/icons/coin.png", size))
	var l := label(amount_text, size, color)
	l.name = "Amount"
	h.add_child(l)
	return h


func panel(color := CARD, radius := RADIUS, margin := 16, shadow := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, radius, margin, shadow))
	return p


func vbox(separation := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


func hbox(separation := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


func spacer(min_size := 0.0, vertical := true) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, min_size) if vertical else Vector2(min_size, 0)
	if vertical:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## 카드 모양 버튼. 안쪽 내용은 돌려받은 VBox 에 넣는다 (버튼 크기는 내용에 맞춰진다)
func card_button(color := CARD, on_pressed: Callable = Callable()) -> Array:
	var b := button("", color, on_pressed)
	for state in ["normal", "hover"]:
		b.add_theme_stylebox_override(state, box(color, RADIUS, 14))
	var pressed := box(color.darkened(0.15), RADIUS, 14)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", box(color.darkened(0.3), RADIUS, 14))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	var v := vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(v)
	b.add_child(margin)
	# Button 은 자식 크기를 모르므로, 내용이 만들어진 뒤와 바뀔 때마다 최소 높이를 맞춘다
	var fit := func(): b.custom_minimum_size.y = margin.get_combined_minimum_size().y
	margin.minimum_size_changed.connect(fit)
	fit.call_deferred()
	return [b, v]


## 세로 스크롤 영역 (가로 스크롤 없음)
func scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s


## 둥근 알약 모양 표시 (아이콘 + 글자)
func pill(icon_path: String, text: String, color := TEXT) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _pill_box())
	var h := hbox(8)
	h.add_child(icon(icon_path, 36))
	var l := label(text, 28, color)
	h.add_child(l)
	p.add_child(h)
	p.set_meta("text", l)
	return p


func _pill_box() -> StyleBoxFlat:
	var sb := box(Color(0, 0, 0, 0.35), 40, 8)
	sb.content_margin_left = 12
	sb.content_margin_right = 18
	return sb


func wrap_label(text: String, size := 26, color := MUTED, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := label(text, size, color, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 100
	return l


## 사진 배경을 화면에 꽉 차게 깔고 어둡게 덮는다
func backdrop(parent: Control, image_path: String, dim := 0.55) -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	var tex := TextureRect.new()
	tex.texture = load(image_path)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(tex)
	var shade := ColorRect.new()
	shade.color = Color(BG, dim)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(shade)


func _click_feedback(b: Control) -> void:
	b.pivot_offset = b.size / 2
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(0.95, 0.95), 0.05)
	tw.tween_property(b, "scale", Vector2.ONE, 0.08)


# ------------------------------------------------------------------ 토스트 / 모달

func toast(text: String, color := TEXT) -> void:
	var p := panel(Color(0.05, 0.06, 0.08, 0.92), 30, 18)
	var l := label(text, 28, color, HORIZONTAL_ALIGNMENT_CENTER)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_layer.add_child(p)
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	p.position = Vector2((vp.x - p.size.x) / 2, vp.y * 0.16)
	p.modulate.a = 0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.3)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


## 화면을 어둡게 덮는 모달 창. content 를 카드 안에 넣어 보여 주고, 닫는 함수를 돌려준다.
## buttons: [[텍스트, 색, 콜백], ...] — 콜백 뒤에 창이 닫힌다.
func modal(title: String, content: Control, buttons: Array = [], parent: Node = null, dismiss_on_backdrop := true) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var card := panel(PANEL, 26, 28, true)
	card.custom_minimum_size = Vector2(600, 0)
	center.add_child(card)
	var v := vbox(22)
	card.add_child(v)
	if title != "":
		v.add_child(label(title, 40, TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(content)
	if not buttons.is_empty():
		var row := hbox(14)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for spec in buttons:
			var b := button(spec[0], spec[1])
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size.y = 84
			var cb: Callable = spec[2] if spec.size() > 2 else Callable()
			b.pressed.connect(func():
				close_modal(root)
				if cb.is_valid():
					cb.call())
			row.add_child(b)
		v.add_child(row)

	if dismiss_on_backdrop:
		dim.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed:
				close_modal(root))

	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.add_child(root)
	(parent if parent != null else get_tree().current_scene).add_child(layer)

	# 크기가 정해진 뒤에 가운데를 기준으로 커지도록
	card.resized.connect(func(): card.pivot_offset = card.size / 2)
	card.scale = Vector2(0.9, 0.9)
	root.modulate.a = 0
	var tw := root.create_tween().set_parallel()
	tw.tween_property(root, "modulate:a", 1.0, 0.15)
	tw.tween_property(card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return root


func close_modal(root: Control) -> void:
	if not is_instance_valid(root):
		return
	var layer := root.get_parent()
	var tw := root.create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.12)
	tw.tween_callback(layer.queue_free)


# ------------------------------------------------------------------ 화면 전환

func go(scene_path: String, setup: Callable = Callable()) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.15)
	await tw.finished
	var scene: Node = load(scene_path).instantiate()
	if setup.is_valid():
		setup.call(scene)
	var tree := get_tree()
	var old := tree.current_scene
	tree.root.add_child(scene)
	tree.current_scene = scene
	if old:
		old.queue_free()
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.2)
	await tw2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
