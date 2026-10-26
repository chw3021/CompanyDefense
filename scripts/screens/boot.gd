# 시작 장면. 저장 데이터를 확인하고 타이틀(메인)로 넘어간다.
extends Control


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	await get_tree().process_frame
	if Dev.out_dir != "":
		return  # 자동 실행 시나리오가 화면 전환을 직접 한다
	UI.go("res://scenes/title.tscn" if ResourceLoader.exists("res://scenes/title.tscn") else "res://scenes/main.tscn")
