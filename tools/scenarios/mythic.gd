# 신화 확인용: 조합표, 전설 카드의 재료 표시, 각성 연출, 신화 스킬 6종을 찍는다.
extends Node

var dev
var battle: Battle


func run(p_dev) -> void:
	dev = p_dev
	Save.reset()
	Save.create_user("테스터")
	Save.user.max_cleared = 3
	await UI.go("res://scenes/stage.tscn", func(s): s.stage_id = 3)
	await dev.wait(2.6)
	var screen := get_tree().current_scene
	battle = screen.battle
	# 재료를 깔아 둔다 (CTO + 인사 이사 + VIP 매니저), VIP 매니저는 처음엔 빼고 찍는다
	var cto := _place("tower_dv5_1", Vector2i(2, 1))
	_place("tower_hr5_1", Vector2i(3, 1))
	for c in [Vector2i(2, 3), Vector2i(3, 3), Vector2i(2, 5)]:
		_place(["tower_sl1", "tower_hr2", "tower_dv3"].pick_random(), c)
	screen._open_recipes()
	await dev.wait(0.5)
	await dev.shot("my_00_book")
	for m in get_tree().root.find_children("*", "Control", true, false):
		pass
	dev.press("닫기")
	await dev.wait(0.3)
	battle.select(cto)
	await dev.wait(0.3)
	await dev.shot("my_01_missing")
	_place("tower_sl5_2", Vector2i(3, 5))
	await dev.wait(0.3)
	await dev.shot("my_02_ready")
	battle.awaken(cto)
	await dev.wait(0.35)
	await dev.shot("my_03_born")
	await dev.wait(2.0)
	await dev.shot("my_04_card")
	battle.select(null)
	# 신화 스킬 6종
	battle.start_wave()
	await dev.wait(2.4)
	for id in GameData.MYTHICS:
		for t: Tower in battle.towers.duplicate():
			battle._remove(t)
		for e: Enemy in battle.enemies.duplicate():
			battle.enemies.erase(e)
		battle._pending.clear()
		for i in 8:
			var e := Enemy.new("printer", 100000.0, battle)
			e.pos = battle.path[0].lerp(battle.path[1], i / 8.0)
			e.hold = 9999.0
			battle.enemies.append(e)
		var m := _place(id, Vector2i(2, 3))
		_place("tower_sl1", Vector2i(2, 5))
		_place("tower_dv1", Vector2i(3, 3))
		m.target = battle.enemies[0]
		m.skill._elapsed = 999.0
		m.skill.use(m)
		await dev.wait(0.35)
		await dev.shot("my_skill_" + id.trim_prefix("tower_"))
		await dev.wait(0.5)
	dev.finish()


func _place(id: String, c: Vector2i) -> Tower:
	var t: Tower = battle._place(id, c)
	t.spawn_anim = 0.0
	return t
