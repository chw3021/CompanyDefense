# 보스방 확인용: 무한 야근 5라운드부터 시작해 보스가 보스방에 서고, 일반 적이 흐려지는지 찍는다.
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
	battle.coins = 3000
	for i in 25:
		battle.hire()
	battle.wave_index = 4  # 5라운드 (중간 보스)
	battle.start_wave()
	battle.speed = 2.0
	var shot := false
	for i in 120:
		await dev.wait(0.25)
		if battle.boss_blocking and not shot:
			await dev.wait(1.0)
			await dev.shot("boss_00_blocking")
			shot = true
			dev.say("blocking: alive=%d" % battle.alive_count())
		if shot and not battle.boss_blocking:
			await dev.wait(0.4)
			await dev.shot("boss_01_after")
			dev.say("boss down at round %d alive=%d" % [battle.display_wave(), battle.alive_count()])
			break
	dev.finish()
