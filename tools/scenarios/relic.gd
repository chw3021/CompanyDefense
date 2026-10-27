# 보스 유물 확인용: 보스를 잡으면 유물이 생기고, 유물 버튼으로 특수 직원을 뽑고, 퇴사는 두 번 눌러야 되는지 찍는다.
extends Node

var dev


func run(p_dev) -> void:
	dev = p_dev
	Save.reset()
	Save.create_user("테스터")
	await UI.go("res://scenes/stage.tscn", func(s): s.stage_id = 1)
	await dev.wait(2.6)
	var screen = get_tree().current_scene
	var battle: Battle = screen.battle
	battle.coins = 3000
	for i in 12:
		battle.hire()
	battle.merge_all(1)
	battle.select(null)
	await dev.wait(0.5)
	await dev.shot("relic_00_field")

	var boss := Enemy.new("boss", 10.0, battle)
	battle.enemies.append(boss)
	boss.kill()
	await dev.wait(0.3)
	dev.say("relic after boss: %s" % ("OK" if battle.relics == 1 else "FAILED (%d)" % battle.relics))
	await dev.shot("relic_01_button")

	dev.say("relic button visible: %s" % ("OK" if screen._relic_button.is_visible_in_tree() else "FAILED"))
	screen._relic_button.emit_signal("pressed")
	await dev.wait(0.6)
	var special: Tower = battle.selected
	var ok := special != null and GameData.is_special(special.data) and battle.relics == 0
	dev.say("summon special: %s" % ("OK " + special.name if ok else "FAILED"))
	await dev.shot("relic_02_special")

	var count := battle.towers.size()
	dev.press("퇴사")
	await dev.wait(0.2)
	dev.say("sell first tap keeps tower: %s" % ("OK" if battle.towers.size() == count else "FAILED"))
	await dev.shot("relic_03_sell_armed")
	dev.press("한 번 더")
	await dev.wait(0.2)
	dev.say("sell second tap removes: %s" % ("OK" if battle.towers.size() == count - 1 else "FAILED"))
	dev.finish()
