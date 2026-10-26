# 공격/스킬 연출 확인용: 팀별 기본 공격을 찍고, 스킬을 하나씩 강제로 써서 각각 찍는다.
# godot --path . --resolution 720x1280 -- --dev-script=res://tools/scenarios/skills.gd --dev-out=<dir>
extends Node

var dev
var battle: Battle


func run(p_dev) -> void:
	dev = p_dev
	Save.reset()
	Save.create_user("테스터")
	Save.user.max_cleared = 3
	await UI.go("res://scenes/stage.tscn", func(s): s.stage_id = 4)
	await dev.wait(2.6)
	battle = get_tree().current_scene.battle
	battle.start_wave()
	await dev.wait(2.4)  # 웨이브 배너가 지나갈 때까지
	_clear_enemies()
	# 기본 공격: 팀별 3등급 직원 셋이 위아래 통로의 적을 친다
	_place("tower_dv3", Vector2i(3, 1))
	_place("tower_hr3", Vector2i(5, 1))
	_place("tower_sl3", Vector2i(7, 1))
	_place("tower_sl5_1", Vector2i(4, 1))
	_spawn_row()
	for i in 4:
		await dev.wait(0.22)
		await dev.shot("atk_%d" % i)
	for t: Tower in battle.towers.duplicate():
		battle._remove(t)
	# 스킬: 가운데 책상에 한 명씩 앉혀 강제로 발동
	var ids := []
	for team in ["dv", "hr", "sl"]:
		for s in ["1", "2", "3", "4", "5_1", "5_2"]:
			ids.append("tower_%s%s" % [team, s])
	for id in ids:
		_clear_enemies()
		_view()._fx.clear()
		battle.effects.clear()
		battle.projectiles.clear()
		_spawn_row()
		var caster := _place(id, Vector2i(5, 1))
		var helpers := [_place("tower_sl1", Vector2i(3, 1)), _place("tower_dv1", Vector2i(7, 1))]
		caster.target = battle.enemies[3]
		caster.skill._elapsed = 999.0
		caster.skill.use(caster)
		await dev.wait(0.3)
		await dev.shot("skill_" + id.trim_prefix("tower_"))
		battle._remove(caster)
		for h in helpers:
			battle._remove(h)
		await dev.wait(0.6)
	dev.finish()


func _place(id: String, c: Vector2i) -> Tower:
	var t: Tower = battle._place(id, c)
	t.spawn_anim = 0.0
	return t


func _clear_enemies() -> void:
	for e: Enemy in battle.enemies.duplicate():
		battle.enemies.erase(e)
	battle._pending.clear()


## 맨 위 통로와 그 아래 통로에 적을 늘어놓고 움직이지 않게 묶어 둔다
func _spawn_row() -> void:
	for row in [0, 2]:
		for col in range(2, 9):
			var e := Enemy.new("printer", 100000.0, battle)
			e.pos = battle.cell_center(Vector2i(col, row))
			e.hold = 9999.0
			battle.enemies.append(e)


func _view(node: Node = get_tree().current_scene) -> BattleView:
	if node is BattleView:
		return node
	for child in node.get_children():
		var found := _view(child)
		if found:
			return found
	return null
