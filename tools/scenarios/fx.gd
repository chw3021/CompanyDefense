# 연출 확인용: 전투 중 이벤트(공격, 처치, 승진, 탈출) 직후를 연속으로 찍는다.
extends Node

var dev


func run(p_dev) -> void:
	dev = p_dev
	Save.reset()
	Save.create_user("테스터")
	await UI.go("res://scenes/stage.tscn", func(s): s.stage_id = 1)
	await dev.wait(2.6)
	var battle: Battle = get_tree().current_scene.battle
	battle.coins = 2000
	for i in 10:
		battle.hire()
	await dev.wait(0.5)
	# 승진 연출
	for a: Tower in battle.towers:
		for b: Tower in battle.towers:
			if a.can_merge_with(b):
				battle.merge(a, b)
				await dev.wait(0.12)
				await dev.shot("fx_01_promote")
				break
		if battle.selected:
			break
	battle.select(null)
	battle.start_wave()
	await dev.wait(0.1)
	await dev.shot("fx_02_wave_banner")
	await dev.wait(4.0)
	for i in 6:
		await dev.shot("fx_03_battle_%d" % i)
		await dev.wait(0.18)
	# 탈출 연출: 남은 적 하나를 출구 바로 앞으로 보낸다
	var e: Enemy = null
	for x: Enemy in battle.enemies:
		e = x
	if e:
		e.pos = battle.path[battle.path.size() - 1]
		e._path_index = battle.path.size() - 1
		await dev.wait(0.1)
		await dev.shot("fx_04_leak")
	dev.finish()
