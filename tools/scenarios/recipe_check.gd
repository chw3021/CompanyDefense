# 신화 조합 확인용 (화면 없이, 저장하지 않음): 조합표 출력과 각성 가능 여부
extends Node

var dev


func run(p_dev) -> void:
	dev = p_dev
	var battle := Battle.new()
	battle.set_process(false)
	add_child(battle)
	battle.setup(4, 72.0)
	for id in GameData.MYTHICS:
		var m: Dictionary = GameData.MYTHICS[id]
		var names: Array = [m.base] + m.recipe
		dev.say("%s = %s  (물리 %d, 마법 %d)" % [m.name, " + ".join(names.map(func(n): return GameData.towers[n].towerName)),
				GameData.towers[id].towerPhysicalAttack, GameData.towers[id].towerMagicAttack])
	var cto: Tower = battle._place("tower_dv5_1", battle.desk_cells[0])
	battle._place("tower_hr5_1", battle.desk_cells[1])
	dev.say("CTO + 인사 이사 -> can_awaken=%s" % battle.can_awaken(cto))
	battle._place("tower_sl5_2", battle.desk_cells[2])
	dev.say("+ VIP 매니저 -> can_awaken=%s" % battle.can_awaken(cto))
	battle.awaken(cto)
	dev.say("after: %s" % str(battle.towers.map(func(t): return "%s(%d)" % [t.name, t.grade])))
	dev.finish()
