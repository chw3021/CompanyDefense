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
	assert(GameData.level_source("tower_dv6_3") == "tower_dv5_1")
	Save.user = {"towers": {}}
	for id in GameData.tower_ids:
		Save.user.towers[id] = GameData.MYTHIC_UNLOCK_LEVEL
	var cto: Tower = battle._place("tower_dv5_1", battle.desk_cells[0])
	battle._place("tower_hr5_1", battle.desk_cells[1])
	dev.say("CTO + 인사 이사 -> can_awaken=%s" % battle.can_awaken(cto))
	assert(not battle.can_awaken(cto))
	battle._place("tower_sl5_2", battle.desk_cells[2])
	Save.user.towers["tower_dv1"] = GameData.MYTHIC_UNLOCK_LEVEL - 1
	dev.say("+ VIP 매니저, 개발팀 1명 Lv.4 -> can_awaken=%s / %s" % [battle.can_awaken(cto), GameData.mythic_lock_text(Save.user, "tower_dv6_1")])
	assert(not battle.can_awaken(cto))
	Save.user.towers["tower_dv1"] = GameData.MYTHIC_UNLOCK_LEVEL
	dev.say("개발팀 전원 Lv.5 -> can_awaken=%s" % battle.can_awaken(cto))
	assert(battle.can_awaken(cto))
	assert(GameData.equipment_cost(GameData.equipment["coffee"], 0) == 300)
	var total := 0
	for lv in GameData.MAX_EQUIPMENT_LEVEL:
		total += GameData.equipment_cost(GameData.equipment["coffee"], lv)
	dev.say("커피 최대 레벨까지 총비용 %d (이전 %d)" % [total, 300 * 55])
	battle.awaken(cto)
	dev.say("after: %s" % str(battle.towers.map(func(t): return "%s(%d)" % [t.name, t.grade])))
	# 예전 세이브의 사무용품 레벨은 한 번만 10배로 옮겨진다
	Save.user = {"equipment": {"coffee": 3, "badge": 10}}
	Save._normalize()
	Save._normalize()
	dev.say("세이브 이전: coffee=%d badge=%d" % [Save.user.equipment.coffee, Save.user.equipment.badge])
	assert(Save.user.equipment.coffee == 30 and Save.user.equipment.badge == 100)
	dev.finish()
