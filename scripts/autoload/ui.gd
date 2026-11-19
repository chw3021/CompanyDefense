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
## margin 을 줄이면 좁은 HUD/툴 버튼에서 글자가 덜 잘린다
static func button_box(color: Color, pressed := false, margin := 14) -> StyleBoxFlat:
	var sb := box(color, 16, margin)
	sb.border_color = color.darkened(0.35)
	sb.border_width_bottom = 2 if pressed else 6
	sb.content_margin_top = margin + (4 if pressed else 0)
	sb.content_margin_bottom = margin
	return sb


## 좁은 인게임 버튼용 (좌우 여백을 줄여 글자 공간을 확보)
func recolor_compact(b: Button, color: Color, margin := 8) -> void:
	for state in ["normal", "hover"]:
		b.add_theme_stylebox_override(state, button_box(color, false, margin))
	b.add_theme_stylebox_override("pressed", button_box(color.darkened(0.15), true, margin))


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
	b.add_theme_stylebox_override("disabled", button_box(Color("4a505c")))
	b.add_theme_color_override("font_disabled_color", Color(TEXT, 0.55))


var _play_icon: ImageTexture
var _hud_icons := {}  # kind -> ImageTexture (웹에서 이모지/폰트 깨짐 방지)


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


## 이펙트 품질 아이콘 (on / min / off) - 버튼 안에서 잘 보이도록 굵고 크게
func fx_icon(quality: String = "") -> Texture2D:
	var q := quality if not quality.is_empty() else Save.effect_quality()
	var kind := "fx2_%s" % q
	if _hud_icons.has(kind):
		return _hud_icons[kind]
	var n := 3 if q == Save.FX_ON else (1 if q == Save.FX_MIN else 0)
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	var center := Vector2(32, 32)
	_stamp_circle(img, center, 7.0, Color(1, 0.95, 0.7, 0.98 if n > 0 else 0.4))
	_stamp_circle(img, center, 3.2, Color(1, 1, 1, 1.0 if n > 0 else 0.5))
	for i in 8:
		if n == 0:
			break
		if n == 1 and i % 2 == 1:
			continue
		var a := i * TAU / 8.0 + 0.2
		var c := Color(1, 0.88, 0.35, 1.0) if n == 3 else Color(0.95, 0.95, 1.0, 0.9)
		_stamp_line(img, center + Vector2(cos(a), sin(a)) * 10.0, center + Vector2(cos(a), sin(a)) * 26.0, 3.6, c)
	# 바깥 고리로 존재감
	if n > 0:
		_stamp_arc(img, center, 22.0, Color(1, 1, 1, 0.35 if n == 1 else 0.55), -PI, PI)
	if n == 0:
		_stamp_line(img, Vector2(14, 14), Vector2(50, 50), 5.0, Color(1, 0.4, 0.4, 1.0))
		_stamp_line(img, Vector2(50, 14), Vector2(14, 50), 5.0, Color(1, 0.4, 0.4, 1.0))
	_hud_icons[kind] = ImageTexture.create_from_image(img)
	return _hud_icons[kind]


## 효과음 켜짐/꺼짐 아이콘
func mute_icon(muted: bool = false) -> Texture2D:
	var kind := "mute2_on" if not muted else "mute2_off"
	if _hud_icons.has(kind):
		return _hud_icons[kind]
	var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	# 스피커 몸통 (더 크게)
	var body := PackedVector2Array([
		Vector2(10, 24), Vector2(24, 24), Vector2(38, 12), Vector2(38, 52), Vector2(24, 40), Vector2(10, 40),
	])
	_stamp_poly(img, body, Color(1, 1, 1, 0.98))
	_stamp_circle(img, Vector2(16, 32), 3.0, Color(0.15, 0.16, 0.2, 0.9))
	if muted:
		_stamp_line(img, Vector2(12, 12), Vector2(54, 52), 5.0, Color(1, 0.4, 0.4, 1.0))
	else:
		_stamp_arc(img, Vector2(40, 32), 10.0, Color(1, 1, 1, 0.85), -0.85, 0.85)
		_stamp_arc(img, Vector2(40, 32), 17.0, Color(1, 1, 1, 0.55), -0.85, 0.85)
		_stamp_arc(img, Vector2(40, 32), 24.0, Color(1, 1, 1, 0.3), -0.85, 0.85)
	_hud_icons[kind] = ImageTexture.create_from_image(img)
	return _hud_icons[kind]


func _stamp_circle(img: Image, at: Vector2, radius: float, color: Color) -> void:
	var r2 := radius * radius
	var x0 := maxi(0, int(at.x - radius - 1))
	var y0 := maxi(0, int(at.y - radius - 1))
	var x1 := mini(img.get_width() - 1, int(at.x + radius + 1))
	var y1 := mini(img.get_height() - 1, int(at.y + radius + 1))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(x + 0.5, y + 0.5).distance_squared_to(at)
			if d <= r2:
				var a := color.a * clampf(1.0 - d / r2, 0.15, 1.0)
				img.set_pixel(x, y, Color(color.r, color.g, color.b, a))


func _stamp_line(img: Image, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var steps := maxi(8, int(a.distance_to(b) * 2.0))
	for i in steps + 1:
		_stamp_circle(img, a.lerp(b, float(i) / steps), width * 0.5, color)


func _stamp_poly(img: Image, poly: PackedVector2Array, color: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				img.set_pixel(x, y, color)


func _stamp_arc(img: Image, at: Vector2, radius: float, color: Color, a0 := -0.7, a1 := 0.7) -> void:
	var steps := 16
	for i in steps:
		var t0 := lerpf(a0, a1, float(i) / steps)
		var t1 := lerpf(a0, a1, float(i + 1) / steps)
		var p0 := at + Vector2(cos(t0), sin(t0)) * radius
		var p1 := at + Vector2(cos(t1), sin(t1)) * radius
		_stamp_line(img, p0, p1, 2.6, color)


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
	h.add_child(icon("res://assets/icons/coin.svg", size))
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


## 카드 모양 버튼. 안쪽 내용은 돌려받은 VBox 에 넣는다 (버튼 크기는 내용에 맞춰진다).
## mouse_filter 는 PASS: 스크롤 목록에서 카드 위를 드래그해도 부모 ScrollContainer 가 스크롤된다.
func card_button(color := CARD, on_pressed: Callable = Callable()) -> Array:
	var b := button("", color, on_pressed)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
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


## 세로 스크롤 영역 (가로 스크롤 없음).
## 모바일/웹에서는 자식 Button/Panel 이 터치를 가로채면 드래그 스크롤이 죽어서,
## STOP 인 컨트롤만 PASS 로 바꿔 ScrollContainer 까지 이벤트가 올라가게 한다 (IGNORE 는 유지).
func scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 짧은 탭은 클릭, 이 이상 움직이면 스크롤로 본다
	s.scroll_deadzone = 24
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	_wire_touch_scroll(content)
	# 웹/모바일에서 자식이 이벤트를 먹어도 드래그 스크롤이 되도록 릴레이를 붙인다
	var relay: Node = load("res://scripts/ui/touch_scroll_relay.gd").new()
	s.add_child(relay)
	return s


## 스크롤 내용 트리에 터치 드래그가 통과되게 연결한다
func _wire_touch_scroll(node: Node) -> void:
	if node is Control:
		var c := node as Control
		if c.mouse_filter == Control.MOUSE_FILTER_STOP:
			c.mouse_filter = Control.MOUSE_FILTER_PASS
	if node is Container and not node.has_meta("_ui_touch_scroll"):
		node.set_meta("_ui_touch_scroll", true)
		node.child_entered_tree.connect(_on_touch_scroll_child)
	for child in node.get_children():
		_wire_touch_scroll(child)


func _on_touch_scroll_child(node: Node) -> void:
	# card_button 이 IGNORE 자식을 붙인 뒤에 적용하려고 한 프레임 미룬다
	call_deferred("_wire_touch_scroll_if_valid", node)


func _wire_touch_scroll_if_valid(node: Node) -> void:
	if is_instance_valid(node):
		_wire_touch_scroll(node)


## 모달 카드 가로폭 (좁은 웹/모바일에서 화면을 넘기지 않는다)
func modal_width(prefer := 600.0) -> float:
	var vp := get_viewport().get_visible_rect().size.x if get_viewport() else prefer
	return minf(prefer, maxf(280.0, vp - 40.0))


## 모달 안 스크롤 영역 크기 (최대 높이도 같게 맞춰야 스크롤이 동작한다)
func modal_scroll_size(prefer_w := 560.0, prefer_h := 640.0) -> Vector2:
	var vp := get_viewport().get_visible_rect().size if get_viewport() else Vector2(prefer_w, prefer_h)
	var w := minf(prefer_w, maxf(240.0, modal_width() - 48.0))
	# 제목/닫기 버튼 자리를 빼고 스크롤 뷰포트 높이를 고정한다
	var h := minf(prefer_h, maxf(220.0, vp.y - 280.0))
	return Vector2(w, h)


## ScrollContainer 높이를 고정해 내용이 길면 스크롤되게 한다
func bind_modal_scroll(scroll: ScrollContainer, prefer_w := 560.0, prefer_h := 640.0) -> ScrollContainer:
	var sz := modal_scroll_size(prefer_w, prefer_h)
	scroll.custom_minimum_size = sz
	scroll.custom_maximum_size = sz
	return scroll


## 큰 숫자는 K/M/B 로 줄여 상단 바 폭을 아낀다.
static func compact_num(n: int) -> String:
	var sign := "-" if n < 0 else ""
	var a := absi(n)
	if a < 1000:
		return sign + str(a)
	if a < 1_000_000:
		return sign + _compact_unit(float(a) / 1000.0, "K")
	if a < 1_000_000_000:
		return sign + _compact_unit(float(a) / 1_000_000.0, "M")
	return sign + _compact_unit(float(a) / 1_000_000_000.0, "B")


static func _compact_unit(v: float, suffix: String) -> String:
	if v >= 100.0:
		return "%d%s" % [int(round(v)), suffix]
	var rounded: float = roundf(v * 10.0) / 10.0
	if is_equal_approx(rounded, roundf(rounded)):
		return "%d%s" % [int(roundf(rounded)), suffix]
	return "%.1f%s" % [rounded, suffix]


## 둥근 알약 모양 표시 (아이콘 + 글자). expand=false 면 내용 폭만 쓰고 줄어들지 않게 최소폭을 둔다.
func pill(icon_path: String, text: String, color := TEXT, expand := true) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _pill_box())
	if expand:
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		p.custom_minimum_size.x = 108
	p.clip_contents = true
	var h := hbox(6)
	h.add_child(icon(icon_path, 32))
	var l := label(text, 26, color)
	if expand:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	else:
		l.clip_text = false
	h.add_child(l)
	p.add_child(h)
	p.set_meta("text", l)
	return p


func _pill_box() -> StyleBoxFlat:
	var sb := box(Color(0, 0, 0, 0.35), 40, 6)
	sb.content_margin_left = 10
	sb.content_margin_right = 12
	return sb


func wrap_label(text: String, size := 26, color := MUTED, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := label(text, size, color, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	# 웹: 버튼 press 제스처 안에서 오디오 unlock (autoload _input 보다 여기가 더 확실하다)
	Audio.ensure_web_unlocked()
	Audio.click()
	b.pivot_offset = b.size / 2
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(0.95, 0.95), 0.05)
	tw.tween_property(b, "scale", Vector2.ONE, 0.08)


# ------------------------------------------------------------------ 토스트 / 모달

func toast(text: String, color := TEXT) -> void:
	var p := panel(Color(0.05, 0.06, 0.08, 0.92), 24, 16)
	p.clip_contents = true
	var l := wrap_label(text, 26, color, HORIZONTAL_ALIGNMENT_CENTER)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_layer.add_child(p)
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	var max_w := minf(vp.x - 40.0, 560.0)
	p.custom_maximum_size = Vector2(max_w, 0)
	p.reset_size()
	await get_tree().process_frame
	p.position = Vector2((vp.x - p.size.x) / 2, vp.y * 0.16)
	p.modulate.a = 0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.3)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


## 화면을 어둡게 덮는 모달 창. content 를 카드 안에 넣어 보여 주고, 닫는 함수를 돌려준다.
## buttons: [[텍스트, 색, 콜백], ...] - 콜백 뒤에 창이 닫힌다.
func modal(title: String, content: Control, buttons: Array = [], parent: Node = null, dismiss_on_backdrop := true) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.clip_contents = true

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var card := panel(PANEL, 22, 22, true)
	card.clip_contents = true
	card.custom_minimum_size = Vector2(modal_width(), 0)
	# 세로도 화면을 넘기지 않게 상한
	var vp_h := get_viewport().get_visible_rect().size.y if get_viewport() else 1280.0
	card.custom_maximum_size = Vector2(modal_width(), maxf(320.0, vp_h - 48.0))
	center.add_child(card)
	var v := vbox(16)
	card.add_child(v)
	if title != "":
		var title_l := label(title, 36, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		title_l.clip_text = true
		v.add_child(title_l)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 스크롤은 높이를 고정해야 내용이 길 때 실제로 스크롤된다
	if content is ScrollContainer:
		var room := maxf(200.0, vp_h - 240.0)
		var want_h := content.custom_minimum_size.y if content.custom_minimum_size.y > 0.0 else room
		var want_w := content.custom_minimum_size.x if content.custom_minimum_size.x > 0.0 else modal_width() - 48.0
		var h := minf(want_h, room)
		var w := minf(want_w, modal_width() - 40.0)
		content.custom_minimum_size = Vector2(w, h)
		content.custom_maximum_size = Vector2(w, h)
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(content)
	if not buttons.is_empty():
		var row := hbox(10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for spec in buttons:
			var b := button(spec[0], spec[1], Callable(), 28)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0, 76)
			b.clip_text = true
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
