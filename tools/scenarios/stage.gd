# 자동 플레이: 새 계정으로 스테이지를 끝까지 진행하며 스크린샷을 남긴다.
# 인자: --dev-stage=1 (기본 1), --dev-speed=4 (시뮬레이션 배속)
extends Node

var dev


func run(p_dev) -> void:
	dev = p_dev
	var stage_id := 1
	var sim_speed := 4.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dev-stage="):
			stage_id = int(arg.trim_prefix("--dev-stage="))
		elif arg.begins_with("--dev-speed="):
			sim_speed = float(arg.trim_prefix("--dev-speed="))
	Save.reset()
	Save.create_user("테스터")
	await UI.go("res://scenes/stage.tscn", func(s): s.stage_id = stage_id)
	await dev.wait(0.6)
	await dev.shot("s%d_01_start" % stage_id)
	var screen = get_tree().current_scene
	var battle: Battle = screen.battle
	await dev.wait(2.0)

	for i in 3:
		battle.hire()
	await dev.wait(0.3)
	await dev.shot("s%d_02_hired" % stage_id)
	# 실제 터치 경로로 직원을 눌러 선택되는지 확인한다
	var first: Tower = battle.towers[0]
	await dev.tap(screen.view.get_global_transform_with_canvas() * battle.cell_center(first.cell))
	await dev.wait(0.3)
	dev.say("tap select: %s" % ("OK" if battle.selected == first else "FAILED"))
	await dev.shot("s%d_03_selected" % stage_id)
	battle.select(null)

	battle.speed = sim_speed
	var shot_battle := false
	var frames_left := 60 * 60 * 6
	while not battle.finished and frames_left > 0:
		frames_left -= 1
		_auto_play(battle)
		if not shot_battle and battle.wave_index >= 2 and battle.enemies.size() >= 5:
			shot_battle = true
			battle.speed = 1.0
			await dev.wait(0.4)
			await dev.shot("s%d_04_battle" % stage_id)
			battle.speed = sim_speed
		await get_tree().process_frame
	dev.say("stage %d finished won=%s wave=%d/%d life=%d score=%d kills=%d towers=%d" % [
			stage_id, battle.won, battle.wave_index, battle.wave_count(), battle.life, battle.score,
			battle.kills, battle.towers.size()])
	await dev.wait(1.2)
	await dev.shot("s%d_05_result" % stage_id)
	dev.finish()


## 단순한 자동 플레이: 합칠 수 있으면 합치고, 돈이 남으면 고용/업그레이드, 웨이브가 끝나면 다음 웨이브
func _auto_play(battle: Battle) -> void:
	for a: Tower in battle.towers:
		for b: Tower in battle.towers:
			if a.can_merge_with(b):
				battle.merge(a, b)
				return
	if battle.coins >= Battle.SPAWN_COST and battle.towers.size() < battle.desk_cells.size():
		battle.hire()
	elif battle.coins >= 400:
		var team: String = GameData.TEAMS.pick_random()
		battle.upgrade_team(team)
	if battle.can_start_wave():
		battle.start_wave()
