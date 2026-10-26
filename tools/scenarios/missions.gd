# 미션/업적 확인용: 기록을 조금 쌓은 계정으로 메인 화면의 미션 창(일일, 업적)을 찍는다.
extends Node

var dev


func run(p_dev) -> void:
	dev = p_dev
	Save.reset()
	Save.create_user("테스터")
	Save.user.max_cleared = 2
	Save.user.games_played = 6
	Save.user.games_won = 3
	Save.user.round_best = 12
	Save.record_session({"kills": 180, "boss_kills": 1, "merges": 12, "hires": 30, "skills": 120, "max_grade": 4, "games": 2, "wins": 1, "round": 9})
	await UI.go("res://scenes/main.tscn")
	await dev.wait(0.6)
	await dev.shot("mis_00_main")
	var main := get_tree().current_scene
	main.open_missions()
	await dev.wait(0.5)
	await dev.shot("mis_01_daily")
	dev.press("업적")
	await dev.wait(0.4)
	await dev.shot("mis_02_achievements")
	dev.say("claimable=%d" % Missions.claimable_count(Save.user))
	dev.finish()
