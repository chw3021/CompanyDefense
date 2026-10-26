# 가독성 확인용: 직원과 적이 많은 한창때 화면을 찍는다. --dev-stage=4 처럼 스테이지 지정
extends Node

var dev


func run(p_dev) -> void:
	dev = p_dev
	Save.reset()
	Save.create_user("테스터")
	Save.user.max_cleared = 3
	var stage_id := 4
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dev-stage="):
			stage_id = int(arg.trim_prefix("--dev-stage="))
	await UI.go("res://scenes/stage.tscn", func(s): s.stage_id = stage_id)
	await dev.wait(2.6)
	var battle: Battle = get_tree().current_scene.battle
	battle.coins = 4000
	for i in 30:
		battle.hire()
	for n in 6:  # 몇 번 승진시켜 등급을 섞는다
		for a: Tower in battle.towers:
			var merged := false
			for b: Tower in battle.towers:
				if a.can_merge_with(b):
					battle.merge(a, b)
					merged = true
					break
			if merged:
				break
	battle.select(null)
	battle.start_wave()
	battle.speed = 2.0
	await dev.wait(5.0)
	# 합칠 짝이 있는 직원을 골라 선택해 둔다 (합치기 표시 확인)
	for a: Tower in battle.towers:
		for b: Tower in battle.towers:
			if a.can_merge_with(b) and battle.selected == null:
				battle.select(a)
	await dev.wait(0.5)
	await dev.shot("busy_%d" % stage_id)
	dev.finish()
