# 개발용 자동 실행기. 명령줄 인자로 시나리오를 받아 화면을 조작하고 스크린샷을 남긴 뒤 종료한다.
# 예) godot --path . -- --dev-script=res://tools/scenarios/stage.gd --dev-out=C:/tmp/shots
# 인자가 없으면 아무것도 하지 않는다 (배포 빌드에도 영향 없음).
extends Node

var out_dir := ""
var _scenario: Node


func _ready() -> void:
	var script_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dev-script="):
			script_path = arg.trim_prefix("--dev-script=")
		elif arg.begins_with("--dev-out="):
			out_dir = arg.trim_prefix("--dev-out=")
	if script_path == "":
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_scenario = load(script_path).new()
	add_child(_scenario)
	_scenario.call_deferred("run", self)


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	image.save_png(path)
	print("[dev] shot ", path)


func say(msg: String) -> void:
	print("[dev] ", msg)


## 화면에 보이는 버튼 중 글자가 text 로 시작하는 것을 눌러 준다
func press(text: String) -> bool:
	var b := find_button(get_tree().root, text)
	if b == null:
		say("button not found: " + text)
		return false
	b.emit_signal("pressed")
	return true


## 화면 좌표 at 을 실제로 누른 것처럼 입력 이벤트를 보낸다 (손가락 터치와 같은 경로를 탄다)
func tap(at: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		get_viewport().push_input(e, true)  # 좌표가 이미 뷰포트(720x1280) 기준
		await get_tree().process_frame


func find_button(node: Node, text: String) -> BaseButton:
	for child in node.get_children():
		if child is Button and child.is_visible_in_tree() and (child as Button).text.begins_with(text):
			return child
		var found := find_button(child, text)
		if found:
			return found
	return null


func finish() -> void:
	say("done")
	get_tree().quit()
