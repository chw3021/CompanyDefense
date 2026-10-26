# 자동 실행: 타이틀부터 메인 화면의 모든 탭과 창을 열어 스크린샷을 남긴다.
extends Node

var dev


func run(p_dev) -> void:
	dev = p_dev
	Save.reset()
	await UI.go("res://scenes/title.tscn")
	await dev.wait(0.5)
	await dev.shot("m01_title_new")
	dev.press("입사하기")
	await dev.wait(0.4)
	await dev.shot("m02_nickname")
	dev.press("확인")
	await dev.wait(0.8)
	await dev.shot("m03_main_stage")

	var main = get_tree().current_scene
	main.open_mailbox()
	await dev.wait(0.4)
	await dev.shot("m04_mailbox")
	dev.press("모두 받기")
	await dev.wait(0.3)
	await dev.shot("m05_mailbox_claimed")
	dev.press("닫기")
	await dev.wait(0.3)

	main.show_tab(1)
	await dev.wait(0.4)
	await dev.shot("m06_employees")
	var tab = main._content.get_child(main._content.get_child_count() - 1)
	tab._open("tower_hr3")
	await dev.wait(0.4)
	dev.press("레벨 업")
	await dev.wait(0.3)
	await dev.shot("m07_employee_dialog")
	dev.press("닫기")
	await dev.wait(0.3)

	main.show_tab(2)
	await dev.wait(0.4)
	dev.press("취미 활동 하기")
	await dev.wait(0.5)
	await dev.shot("m08_hobby")

	main.show_tab(3)
	await dev.wait(0.4)
	await dev.shot("m09_equipment")
	tab = main._content.get_child(main._content.get_child_count() - 1)
	tab._open("coffee")
	await dev.wait(0.3)
	dev.press("구매")
	await dev.wait(0.3)
	await dev.shot("m10_equipment_dialog")
	dev.press("닫기")
	await dev.wait(0.3)

	main.open_menu()
	await dev.wait(0.4)
	await dev.shot("m11_menu")
	dev.press("내 기록")
	await dev.wait(0.4)
	await dev.shot("m12_records")

	await UI.go("res://scenes/title.tscn")
	await dev.wait(0.5)
	await dev.shot("m13_title_returning")
	dev.finish()
