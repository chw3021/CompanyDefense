# 프로필 사진 확인용: 연동된 것처럼 꾸며(파일은 쓰지 않음) 메인 화면 왼쪽 위 프로필을 찍는다.
extends Node

var dev


func run(p_dev) -> void:
	dev = p_dev
	Save.reset()
	Save.create_user("테스터")
	await UI.go("res://scenes/main.tscn")
	await dev.wait(0.5)
	await dev.shot("av_00_unlinked")
	Account.uid = "test"
	Account._refresh_token = "test"
	Account.display_name = "chw3021"
	Account.avatar = null
	Account.profile_changed.emit()
	await dev.wait(0.3)
	await dev.shot("av_01_initial")
	Account.avatar = load("res://assets/tower/hr/hr6_2.png")
	Account.profile_changed.emit()
	await dev.wait(0.3)
	await dev.shot("av_02_photo")
	Account.uid = ""
	Account._refresh_token = ""
	dev.finish()
