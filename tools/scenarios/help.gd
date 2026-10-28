# 도움말/약점 표시 확인용: 스킬 이펙트 위로 체력바·등급 별·약점 표시가 보이는지, 도움말 창과 직원 카드의 ? 버튼을 찍는다.
# godot --path . --resolution 720x1280 -- --dev-script=res://tools/scenarios/help.gd --dev-out=<dir>
extends Node

var dev
var battle: Battle


func run(p_dev) -> void:
	dev = p_dev
	Save.reset()
	Save.create_user("테스터")
	Save.user.max_cleared = 3
	await UI.go("res://scenes/stage.tscn", func(s): s.stage_id = 1)
	await dev.wait(2.6)
	var screen := get_tree().current_scene
	battle = screen.battle
	battle.start_wave()
	await dev.wait(2.4)
	for e: Enemy in battle.enemies.duplicate():
		battle.enemies.erase(e)
	battle._pending.clear()
	# 맨 위 통로 (0행) 에 복합기/서버/프린터를 번갈아 세워 둔다
	var types := ["copier", "server", "printer"]
	for col in range(3, 10):
		var e := Enemy.new(types[col % 3], 100000.0, battle)
		e.pos = battle.cell_center(Vector2i(col, 3))
		e.hold = 9999.0
		battle.enemies.append(e)
	for id_cell in [["tower_sl5_2", Vector2i(4, 2)], ["tower_dv3", Vector2i(5, 2)], ["tower_hr2", Vector2i(4, 4)]]:
		var t: Tower = battle._place(id_cell[0], id_cell[1])
		t.spawn_anim = 0.0
	var caster: Tower = battle.towers[0]
	caster.target = battle.enemies[1]
	caster.skill._elapsed = 999.0
	caster.skill.use(caster)
	await dev.wait(0.3)
	await dev.shot("help_00_skill_overlay")
	battle.paused = true
	dev.press("도움말")
	await dev.wait(0.4)
	await dev.shot("help_01_modal")
	dev.press("닫기")
	await dev.wait(0.3)
	battle.select(caster)
	await dev.wait(0.3)
	await dev.shot("help_02_card")
	await UI.go("res://scenes/main.tscn")
	await dev.wait(0.5)
	get_tree().current_scene._open_settings()
	await dev.wait(0.4)
	await dev.shot("help_03_settings")
	dev.finish()
