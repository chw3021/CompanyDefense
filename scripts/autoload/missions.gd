# 일일 미션과 업적: 정의, 진행도 계산, 보상 받기.
# 진행도는 전투가 끝날 때 Battle.session 을 Save.record_session 으로 한 번에 반영한다.
# 저장 위치: user.stats (누적 기록), user.achievements (업적별로 받은 단계 수), user.daily (오늘 미션)
class_name Missions

## 업적. stat 은 user.stats 의 키이거나 user 의 키 (games_played 등). tiers = [[목표, 골드], ...]
const ACHIEVEMENTS := [
	{"id": "kills", "name": "사무기기 처리반", "desc": "적 %d마리 처치", "stat": "kills",
			"tiers": [[100, 300], [1000, 1000], [5000, 3000], [20000, 8000]]},
	{"id": "bosses", "name": "보스 사냥꾼", "desc": "보스 %d마리 처치", "stat": "boss_kills",
			"tiers": [[1, 300], [10, 1000], [50, 3000], [200, 8000]]},
	{"id": "merges", "name": "인사 발령", "desc": "승진 %d회", "stat": "merges",
			"tiers": [[10, 300], [100, 1000], [500, 3000]]},
	{"id": "hires", "name": "채용 박람회", "desc": "직원 %d명 고용", "stat": "hires",
			"tiers": [[50, 300], [500, 1000], [2000, 3000]]},
	{"id": "skills", "name": "능력자", "desc": "스킬 %d회 사용", "stat": "skills",
			"tiers": [[100, 300], [1000, 1000], [5000, 3000]]},
	{"id": "grade", "name": "전설의 탄생", "desc": "%d등급 직원 만들기", "stat": "max_grade",
			"tiers": [[3, 300], [4, 1000], [5, 3000]]},
	{"id": "games", "name": "성실한 사원", "desc": "%d판 플레이", "stat": "games_played",
			"tiers": [[5, 300], [30, 1000], [100, 3000]]},
	{"id": "wins", "name": "승리의 기쁨", "desc": "%d번 승리", "stat": "games_won",
			"tiers": [[3, 300], [20, 1000], [100, 3000]]},
	{"id": "stages", "name": "승승장구", "desc": "스테이지 %d 클리어", "stat": "max_cleared",
			"tiers": [[1, 200], [2, 500], [3, 1000]]},
	{"id": "rounds", "name": "야근의 신", "desc": "무한 야근 %d라운드 버티기", "stat": "round_best",
			"tiers": [[10, 500], [20, 1500], [30, 3000], [50, 6000], [80, 10000]]},
]

## 일일 미션 후보. 매일 날짜로 섞어 DAILY_COUNT 개를 뽑는다. best 는 한 판 최고값으로 센다
const DAILY_POOL := [
	{"id": "kill", "desc": "적 %d마리 처치", "stat": "kills", "goal": 150, "gold": 300},
	{"id": "boss", "desc": "보스 %d마리 처치", "stat": "boss_kills", "goal": 2, "gold": 400},
	{"id": "play", "desc": "%d판 플레이", "stat": "games", "goal": 3, "gold": 300},
	{"id": "win", "desc": "스테이지 %d번 승리", "stat": "wins", "goal": 1, "gold": 300},
	{"id": "merge", "desc": "승진 %d회", "stat": "merges", "goal": 15, "gold": 300},
	{"id": "skill", "desc": "스킬 %d회 사용", "stat": "skills", "goal": 50, "gold": 300},
	{"id": "hire", "desc": "직원 %d명 고용", "stat": "hires", "goal": 40, "gold": 250},
	{"id": "round", "desc": "무한 야근 한 판에 %d라운드", "stat": "round", "goal": 15, "gold": 500, "best": true},
]
const DAILY_COUNT := 3
const DAILY_BONUS_GOLD := 500   # 오늘 미션을 모두 끝내면
const DAILY_BONUS_TIME := 1

## 전투 한 판에서 세는 값 (Battle.session 의 키)
const SESSION_KEYS := ["kills", "boss_kills", "merges", "hires", "skills", "max_grade", "games", "wins", "round"]


static func today() -> String:
	return Time.get_date_string_from_system()


static func seconds_until_reset() -> int:
	var t := Time.get_time_dict_from_system()
	return 86400 - (int(t.hour) * 3600 + int(t.minute) * 60 + int(t.second))


## 오늘의 미션 상태. 날짜가 바뀌었으면 새로 뽑는다
static func daily(user: Dictionary) -> Dictionary:
	var d: Dictionary = user.get("daily", {})
	if d.get("date", "") != today():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(today() + str(user.get("name", "")))
		var pool := range(DAILY_POOL.size())
		var picks := []
		for i in DAILY_COUNT:
			picks.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
		d = {"date": today(), "bonus_claimed": false,
				"missions": picks.map(func(i): return {"id": DAILY_POOL[i].id, "progress": 0, "claimed": false})}
		user["daily"] = d
	return d


static func daily_def(id: String) -> Dictionary:
	for m in DAILY_POOL:
		if m.id == id:
			return m
	return {}


static func daily_done(m: Dictionary) -> bool:
	return int(m.progress) >= int(daily_def(m.id).goal)


static func daily_all_done(user: Dictionary) -> bool:
	return daily(user).missions.all(func(m): return daily_done(m))


static func stat_value(user: Dictionary, stat: String) -> int:
	if user.has(stat):
		return int(user[stat])
	return int(user.get("stats", {}).get(stat, 0))


## 업적에서 지금까지 받은 단계 수
static func claimed_tiers(user: Dictionary, a: Dictionary) -> int:
	return int(user.get("achievements", {}).get(a.id, 0))


## 다음에 받을 단계 [목표, 골드]. 다 받았으면 빈 배열
static func next_tier(user: Dictionary, a: Dictionary) -> Array:
	var i := claimed_tiers(user, a)
	return a.tiers[i] if i < a.tiers.size() else []


static func achievement_ready(user: Dictionary, a: Dictionary) -> bool:
	var tier := next_tier(user, a)
	return not tier.is_empty() and stat_value(user, a.stat) >= int(tier[0])


## 지금 받을 수 있는 보상 개수 (메인 화면 배지)
static func claimable_count(user: Dictionary) -> int:
	if user.is_empty():
		return 0
	var n := 0
	var d := daily(user)
	for m in d.missions:
		if daily_done(m) and not m.claimed:
			n += 1
	if daily_all_done(user) and not d.bonus_claimed:
		n += 1
	for a in ACHIEVEMENTS:
		if achievement_ready(user, a):
			n += 1
	return n


## 전투 한 판의 기록을 누적 기록과 오늘 미션에 반영 (저장은 부르는 쪽이)
static func apply_session(user: Dictionary, session: Dictionary) -> void:
	var stats: Dictionary = user.get("stats", {})
	for key in ["kills", "boss_kills", "merges", "hires", "skills"]:
		stats[key] = int(stats.get(key, 0)) + int(session.get(key, 0))
	stats["max_grade"] = maxi(int(stats.get("max_grade", 0)), int(session.get("max_grade", 0)))
	user["stats"] = stats
	for m in daily(user).missions:
		var def := daily_def(m.id)
		var value := int(session.get(def.stat, 0))
		if def.get("best", false):
			m.progress = maxi(int(m.progress), value)
		else:
			m.progress = int(m.progress) + value
		m.progress = mini(int(m.progress), int(def.goal))
