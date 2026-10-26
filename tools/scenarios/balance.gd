# 밸런스 시뮬레이터: 화면 없이 전투만 빠르게 돌려 승률과 웨이브별 누수를 잰다.
# godot --headless --path . -- --dev-script=res://tools/scenarios/balance.gd --dev-out=<dir> [--dev-runs=40] [--dev-stages=1,2,3]
# 결과는 콘솔과 <dir>/balance.json 에 남는다. 저장 데이터를 덮어쓰니 PC 에서만 돌릴 것.
extends Node

const STEP := 0.05          # 시뮬레이션 한 틱 (게임 시간 초)
const MAX_TIME := 7200.0    # 한 판 최대 게임 시간
const ENDLESS_SLOTS := 80    # 무한 모드에서 웨이브별 누수를 셀 칸 수

## 계정 성장 단계 가정. towers 는 등급(1~5)별 레벨, hobbies/equipment 는 모든 항목에 같은 레벨
## after1/after2 는 앞 스테이지를 깬 뒤 번 골드(약 2,700 / 5,000)로 현실적으로 올릴 수 있는 정도
const PROFILES := {
	"new": {"towers": [1, 1, 1, 1, 1], "hobbies": 1, "equipment": 0},
	"after1": {"towers": [5, 2, 1, 1, 1], "hobbies": 2, "equipment": 1},
	"after2": {"towers": [8, 4, 2, 1, 1], "hobbies": 3, "equipment": 2},
	"mid": {"towers": [5, 5, 5, 5, 5], "hobbies": 5, "equipment": 3},
	"veteran": {"towers": [15, 12, 10, 8, 6], "hobbies": 10, "equipment": 7},
	"max": {"towers": [30, 30, 30, 30, 30], "hobbies": 10, "equipment": 10},  # 모든 강화를 끝까지
}

var dev
var hp_scale := 0.0  # --dev-hp-scale=1.3 으로 스테이지의 hp_scale 을 덮어쓴다 (0 이면 그대로)


func run(p_dev) -> void:
	dev = p_dev
	var runs := 40
	var stages := [1, 2, 3]
	var profiles := PROFILES.keys()
	var bots := ["casual", "smart"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dev-runs="):
			runs = int(arg.trim_prefix("--dev-runs="))
		elif arg.begins_with("--dev-stages="):
			stages = Array(arg.trim_prefix("--dev-stages=").split(",")).map(func(s): return int(s))
		elif arg.begins_with("--dev-profiles="):
			profiles = Array(arg.trim_prefix("--dev-profiles=").split(","))
		elif arg.begins_with("--dev-power="):
			StageDefs.endless_hp_power = float(arg.trim_prefix("--dev-power="))
		elif arg.begins_with("--dev-k="):
			StageDefs.endless_hp_k = float(arg.trim_prefix("--dev-k="))
		elif arg.begins_with("--dev-late="):
			StageDefs.late_growth = float(arg.trim_prefix("--dev-late="))
		elif arg.begins_with("--dev-hp-scale="):
			hp_scale = float(arg.trim_prefix("--dev-hp-scale="))
		elif arg.begins_with("--dev-bots="):
			bots = Array(arg.trim_prefix("--dev-bots=").split(","))
	Save.reset()
	var report := []
	for stage_id in stages:
		for profile in profiles:
			for bot in bots:
				var agg := _aggregate(stage_id, profile, bot, runs)
				report.append(agg)
				dev.say(_line(agg))
	var f := FileAccess.open(dev.out_dir.path_join("balance.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	Save.reset()
	dev.finish()


func _line(a: Dictionary) -> String:
	if a.endless:
		return "stage=%d profile=%-6s bot=%-6s avg_wave=%.1f p10/50/90=%s time=%ds maxgrade=%s" % [
			a.stage, a.profile, a.bot, a.avg_wave, str(a.wave_p10_50_90), roundi(a.avg_time), str(a.max_grade_hist)]
	return "stage=%d profile=%-4s bot=%-6s win=%3d%% life=%.1f wave=%.1f/%d time=%ds leaks/wave=%s maxgrade=%s" % [
		a.stage, a.profile, a.bot, roundi(a.win_rate * 100), a.avg_life, a.avg_wave, a.waves,
		roundi(a.avg_time), str(a.leaks_per_wave), str(a.max_grade_hist)]


func _aggregate(stage_id: int, profile: String, bot: String, runs: int) -> Dictionary:
	var wins := 0
	var life_sum := 0.0
	var wave_sum := 0.0
	var time_sum := 0.0
	var endless := StageDefs.is_endless(stage_id)
	var waves: int = ENDLESS_SLOTS if endless else StageDefs.STAGES[stage_id].waves.size()
	var reached := []
	var leaks := []
	leaks.resize(waves)
	leaks.fill(0.0)
	var grade_hist := {}
	for i in runs:
		var r := _play(stage_id, profile, bot)
		if r.won:
			wins += 1
		life_sum += r.life
		wave_sum += r.wave
		reached.append(r.wave)
		time_sum += r.time
		for w in waves:
			leaks[w] += r.leaks[w]
		grade_hist[r.max_grade] = grade_hist.get(r.max_grade, 0) + 1
	return {
		"stage": stage_id, "profile": profile, "bot": bot, "runs": runs, "waves": waves,
		"win_rate": float(wins) / runs, "avg_life": life_sum / runs, "avg_wave": wave_sum / runs,
		"avg_time": time_sum / runs,
		"leaks_per_wave": leaks.map(func(v): return snappedf(v / runs, 0.1)),
		"max_grade_hist": grade_hist,
		"endless": endless, "wave_p10_50_90": _percentiles(reached),
	}


func _percentiles(values: Array) -> Array:
	var sorted := values.duplicate()
	sorted.sort()
	return [0.1, 0.5, 0.9].map(func(q): return sorted[mini(sorted.size() - 1, int(q * sorted.size()))])


func _make_user(profile: String) -> Dictionary:
	var p: Dictionary = PROFILES[profile]
	var user := {"towers": {}, "hobbies": {}, "equipment": {}, "gold": 0, "time": 5,
			"max_cleared": 99, "best_scores": {}, "high_score": 0, "games_played": 0, "games_won": 0, "mails": []}
	for id in GameData.tower_ids:
		user.towers[id] = p.towers[int(GameData.towers[id].towerGrade) - 1]
	for id in GameData.hobby_ids:
		user.hobbies[id] = p.hobbies
	for id in GameData.equipment_ids:
		user.equipment[id] = p.equipment
	return user


func _play(stage_id: int, profile: String, bot: String) -> Dictionary:
	Save.user = _make_user(profile)
	var battle := Battle.new()
	battle.set_process(false)
	add_child(battle)
	battle.setup(stage_id, 72.0)
	battle.speed = 1.0
	if hp_scale > 0:
		battle.def = battle.def.duplicate()
		battle.def.hp_scale = hp_scale
	var leaks := []
	leaks.resize(battle.wave_count() if battle.wave_count() > 0 else ENDLESS_SLOTS)
	leaks.fill(0)
	var last_life := battle.life
	while not battle.finished and battle.game_time() < MAX_TIME:
		_act(battle, bot)
		battle._process(STEP)
		if battle.life < last_life:
			leaks[mini(battle.wave_index, leaks.size() - 1)] += last_life - battle.life
			last_life = battle.life
	var max_grade := 0
	for t: Tower in battle.towers:
		max_grade = maxi(max_grade, t.grade)
	var result := {"won": battle.won, "life": battle.life, "wave": battle.wave_index,
			"time": battle.game_time(), "leaks": leaks, "max_grade": max_grade}
	battle.queue_free()
	return result


## casual: 고용과 승진만 한다 (처음 해보는 사람)
## smart: 승진 > 고용 > 직원이 많은 팀부터 팀 업그레이드
## only_dv, only_hr_sl 등: casual 이지만 고용과 승진 결과를 그 팀들로만 고정 (팀 성능 비교용)
## noskill: casual 이지만 스킬을 쓰지 않는다 (스킬 기여도 측정용)
func _act(battle: Battle, bot: String) -> void:
	var teams: Array = Array(bot.trim_prefix("only_").split("_")) if bot.begins_with("only_") else []
	for a: Tower in battle.towers:
		for b: Tower in battle.towers:
			if a.can_merge_with(b):
				if teams.is_empty():
					battle.merge(a, b)
				else:
					_merge_team(battle, a, b, teams)
				return
	var free := battle.towers.size() < battle.desk_cells.size()
	if battle.coins >= Battle.SPAWN_COST and free:
		if teams.is_empty():
			battle.hire()
		else:
			battle.coins -= Battle.SPAWN_COST
			_place(battle, _of_team(1, teams), battle._free_desks().pick_random())
	if bot == "noskill":
		for t: Tower in battle.towers:
			if t.skill.base_cooldown != INF:
				t.skill.base_cooldown = INF
				t.recalculate()
	if bot == "smart":
		for t: Tower in battle.towers:
			if battle.can_awaken(t):
				battle.awaken(t)
				return
	if bot == "smart":
		var counts := {"hr": 0, "dv": 0, "sl": 0}
		for t: Tower in battle.towers:
			counts[t.team] += 1 << (t.grade - 1)
		var best: String = counts.keys().reduce(func(x, y): return x if counts[x] >= counts[y] else y)
		if battle.coins >= battle.upgrade_cost(best):
			battle.upgrade_team(best)
	if battle.can_start_wave():
		battle.start_wave()


func _of_team(grade: int, teams: Array) -> String:
	return GameData.towers_of_grade(grade).filter(func(id): return GameData.towers[id].team in teams).pick_random()


func _place(battle: Battle, tower_id: String, c: Vector2i) -> Tower:
	return battle._place(tower_id, c)


func _merge_team(battle: Battle, a: Tower, b: Tower, teams: Array) -> void:
	var c := b.cell
	battle._remove(a)
	battle._remove(b)
	_place(battle, _of_team(b.grade + 1, teams), c)
