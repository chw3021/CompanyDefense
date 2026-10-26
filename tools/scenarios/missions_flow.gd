# 미션 흐름 확인용 (화면 없이): 전투 한 판의 기록이 누적 기록/일일 미션에 반영되고, 보상 받기가 되는지
extends Node

var dev


func run(p_dev) -> void:
	dev = p_dev
	Save.reset()
	Save.create_user("테스터")
	var battle := Battle.new()
	battle.set_process(false)
	add_child(battle)
	battle.setup(1, 72.0)
	battle.coins = 2000
	for i in 8:
		battle.hire()
	battle.start_wave()
	for i in 1200:
		battle._process(0.05)
		if battle.wave_index >= 2:
			break
	dev.say("session before end: %s" % battle.session)
	battle._end(true)
	dev.say("stats: %s" % Save.user.stats)
	dev.say("games=%d wins=%d" % [Save.user.games_played, Save.user.games_won])
	for m in Missions.daily(Save.user).missions:
		dev.say("daily %s progress=%d" % [m.id, m.progress])
	var gold := Save.gold()
	var claimed := 0
	for a in Missions.ACHIEVEMENTS:
		if Save.claim_achievement(a):
			claimed += 1
	dev.say("claimed achievements=%d gold %d -> %d, claimable now=%d" % [claimed, gold, Save.gold(), Missions.claimable_count(Save.user)])
	# 날짜가 바뀌면 새 미션
	Save.user.daily.date = "2000-01-01"
	dev.say("new day missions: %s" % str(Missions.daily(Save.user).missions.map(func(m): return m.id)))
	Save.reset()
	dev.finish()
