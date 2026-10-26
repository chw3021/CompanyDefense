# 무한 야근(고리 맵 서바이벌) 확인용: 직원을 깔고 시작해서 시간이 흐른 모습과, 적을 일부러 쌓아 끝나는 화면을 찍는다.
extends Node

var dev


func run(p_dev) -> void:
	dev = p_dev
	Save.reset()
	Save.create_user("테스터")
	Save.user.max_cleared = 3
	await UI.go("res://scenes/main.tscn")
	await dev.wait(0.5)
	await dev.shot("surv_00_stage_list")
	await UI.go("res://scenes/stage.tscn", func(s): s.stage_id = 4)
	await dev.wait(0.6)
	await dev.shot("surv_01_intro")
	await dev.wait(2.2)
	var battle: Battle = get_tree().current_scene.battle
	battle.coins = 1500
	for i in 12:
		battle.hire()
	battle.start_wave()
	battle.speed = 3.0
	await dev.wait(9.0)
	await dev.shot("surv_02_round")
	dev.say("round=%d alive=%d left=%.1f" % [battle.display_wave(), battle.alive_count(), battle.round_left])
	# 직원을 모두 내보내 적을 쌓는다
	for t: Tower in battle.towers.duplicate():
		battle._remove(t)
	battle.speed = 8.0
	while not battle.finished:
		await dev.wait(0.5)
		if battle.alive_count() >= 80 and battle.alive_count() < 84:
			await dev.shot("surv_03_crowded")
	dev.say("ended round=%d wave_index=%d best=%d" % [battle.display_wave(), battle.wave_index, Save.user.get("round_best", 0)])
	await dev.wait(1.2)
	await dev.shot("surv_04_game_over")
	dev.finish()
