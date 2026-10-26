# 특수 적 확인용: 새 적을 한 마리씩 경로 위에 늘어놓고 능력(회복, 전화벨, 분열, 보호막)이 보이게 찍는다.
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
	battle.coins = 2000
	for i in 10:
		battle.hire()
	battle.start_wave()
	await dev.wait(0.2)
	for e: Enemy in battle.enemies.duplicate():
		e.kill()
	battle._pending.clear()
	# 경로 앞쪽부터 한 종류씩 (분열은 일부러 맞아서 나뉘게, 보호막은 반쯤 깎인 상태로)
	var kinds := ["parcel", "water", "vacuum", "laptop", "phone", "parcel_mini", "printer"]
	for i in kinds.size():
		var e := Enemy.new(kinds[i], 400.0, battle)
		e.progress = 0.0
		e._path_index = 1 + i % (battle.path.size() - 1)
		e.pos = battle.path[e._path_index - 1].lerp(battle.path[e._path_index], 0.3 + 0.4 * float(i / (battle.path.size() - 1)))
		battle.enemies.append(e)
		Save.mark_enemy_seen(kinds[i])
	for t: Tower in battle.towers:
		t.stun(0.0)
	battle.speed = 0.15
	await dev.wait(2.0)
	await dev.shot("enemies_00_lineup")
	# 능력 강제 발동
	for e: Enemy in battle.enemies:
		if e.type.has("interval"):
			e.ability_timer = 0.0
		if e.type_id == "laptop":
			e.damage(150, 0)
		if e.type_id == "water":
			for o: Enemy in battle.enemies:
				o.hp = o.max_hp * 0.5
	battle.towers[0].stun(3.0)  # 통화 중 표시 확인용
	await dev.wait(0.15)
	await dev.shot("enemies_01_abilities")
	for e: Enemy in battle.enemies.duplicate():
		if e.type_id == "parcel":
			e.kill()
	await dev.wait(0.25)
	await dev.shot("enemies_02_split")
	dev.say("enemies alive: %d" % battle.enemies.size())
	dev.finish()
