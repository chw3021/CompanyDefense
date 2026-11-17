# ScrollContainer 자식으로 붙여 모바일/웹 터치 드래그 스크롤을 보장한다.
# 카드/패널이 터치를 먹어도 _input 단계에서 세로 스크롤을 직접 민다.
extends Node

var _armed := false
var _dragging := false
var _origin := Vector2.ZERO

const DEADZONE := 16.0


func _ready() -> void:
	set_process_input(true)


func _scroll() -> ScrollContainer:
	return get_parent() as ScrollContainer


func _input(event: InputEvent) -> void:
	var s := _scroll()
	if s == null or not s.is_visible_in_tree():
		return
	var rect := s.get_global_rect()
	if event is InputEventScreenTouch:
		if event.pressed:
			_armed = rect.has_point(event.position)
			_dragging = false
			_origin = event.position
		else:
			_armed = false
			_dragging = false
	elif event is InputEventScreenDrag and _armed:
		if not _dragging:
			if event.position.distance_to(_origin) < DEADZONE:
				return
			_dragging = true
		s.scroll_vertical -= int(event.relative.y)
		get_viewport().set_input_as_handled()
