# 1성 모두 승진 버튼 확인용: 1성을 잔뜩 깔고 버튼 전후를 찍는다.
extends Node

var dev


func run(p_dev) -> void:
	dev = p_dev
	Save.reset()
	Save.create_user("테스터")
	Save.user.max_cleared = 3
	await UI.go("res://scenes/stage.tscn", func(s): s.stage_id = 4)
	await dev.wait(2.6)
	var battle: Battle = get_tree().current_scene.battle
	battle.coins = 4000
	for i in 30:
		battle.hire()
	await dev.wait(0.4)
	dev.say("pairs before=%d towers=%d" % [battle.merge_pairs(1).size(), battle.towers.size()])
	await dev.shot("am_00_before")
	dev.press("1성 모두 승진")
	await dev.wait(0.3)
	await dev.shot("am_01_after")
	dev.say("pairs after=%d towers=%d" % [battle.merge_pairs(1).size(), battle.towers.size()])
	dev.finish()
