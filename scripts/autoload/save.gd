# 플레이어 데이터 저장/로드 (오프라인, user://save.json) 와 진행 규칙 (시간 충전, 메일, 스테이지 결과).
extends Node

signal changed

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.cfg"
const MAX_TIME := 5
const TIME_REFILL_SEC := 30 * 60
const NICKNAME_MAX := 10
const DEFAULT_NAME := "신입사원"
const RICH_GOLD := 99999999  # tools/build.ps1 -Me 로 만든 내 전용 APK 에만 적용 (기능 태그 rich_start)

var user: Dictionary = {}
var settings := ConfigFile.new()


func _ready() -> void:
	settings.load(SETTINGS_PATH)
	_load()


func has_user() -> bool:
	return not user.is_empty()


func _now() -> int:
	return int(Time.get_unix_time_from_system())


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("저장 데이터를 읽지 못했습니다. 새로 시작합니다.")
		return
	user = parsed
	_normalize()
	_apply_rich_start()
	refresh_time()


func save() -> void:
	if user.is_empty():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(user))
	f.close()
	changed.emit()


func create_user(user_name: String) -> void:
	user = {
		"name": user_name,
		"gold": 1000,
		"time": MAX_TIME,
		"last_refill": _now(),
		"towers": {},
		"hobbies": {},
		"equipment": {},
		"mails": [],
		"max_cleared": 0,
		"round_best": 0,  # 무한 야근 최고 라운드
		"best_scores": {},
		"high_score": 0,
		"games_played": 0,
		"games_won": 0,
	}
	_normalize()
	send_mail("입사를 환영합니다!", "컴퍼니 디펜스에 오신 것을 환영합니다.\n입사 축하금을 받아가세요.", 500, 3)
	_apply_rich_start()
	save()


## 내 전용 빌드면 켤 때마다 골드를 RICH_GOLD 까지 채운다
func _apply_rich_start() -> void:
	if OS.has_feature("rich_start") and user.gold < RICH_GOLD:
		user.gold = RICH_GOLD


## 클라우드에서 받은 데이터로 바꾼다
func replace_user(data: Dictionary) -> void:
	user = data
	_normalize()
	refresh_time()
	save()


func reset() -> void:
	user = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	changed.emit()


## 데이터에 새 직원/취미/장비가 추가되었으면 채우고, 사라진 직원은 지운다
func _normalize() -> void:
	for key in ["towers", "hobbies", "equipment", "best_scores"]:
		if not user.has(key) or typeof(user[key]) != TYPE_DICTIONARY:
			user[key] = {}
	if not user.has("mails"):
		user["mails"] = []
	for id in GameData.tower_ids:
		if not user.towers.has(id):
			user.towers[id] = 1
	for id in GameData.hobby_ids:
		if not user.hobbies.has(id):
			user.hobbies[id] = 1
	for id in GameData.equipment_ids:
		if not user.equipment.has(id):
			user.equipment[id] = 0
	for id in user.towers.keys():
		if not GameData.towers.has(id):
			user.towers.erase(id)
	# JSON 은 숫자를 float 로 읽으므로 정수로 되돌린다
	for key in ["towers", "hobbies", "equipment", "best_scores"]:
		for id in user[key]:
			user[key][id] = int(user[key][id])
	# 사무용품 레벨당 효과가 1/10 로 줄어든 버전: 기존 레벨을 10배로 옮겨 효과를 유지한다
	if int(user.get("equipment_version", 1)) < 2:
		for id in user.equipment:
			user.equipment[id] = mini(user.equipment[id] * 10, GameData.MAX_EQUIPMENT_LEVEL)
		user["equipment_version"] = 2
	for key in ["gold", "time", "last_refill", "max_cleared", "round_best", "high_score", "games_played", "games_won"]:
		user[key] = int(user.get(key, 0))
	if String(user.get("name", "")).strip_edges() == "":
		user["name"] = DEFAULT_NAME


# ------------------------------------------------------------------ 재화

func gold() -> int:
	return user.get("gold", 0)


func spend_gold(amount: int) -> bool:
	if user.is_empty() or user.gold < amount:
		return false
	user.gold -= amount
	save()
	return true


func spend_time() -> bool:
	if user.is_empty():
		return false
	refresh_time()
	if user.time < 1:
		return false
	if user.time >= MAX_TIME:
		# 가득 찬 상태에서 쓰면 그때부터 충전 시간을 잰다
		user.last_refill = _now()
	user.time -= 1
	save()
	return true


## 30분마다 시간 1 충전 (최대 MAX_TIME)
func refresh_time() -> void:
	if user.is_empty():
		return
	var now := _now()
	if user.time >= MAX_TIME:
		user.last_refill = now
		return
	var elapsed: int = now - user.last_refill
	if elapsed < 0:
		user.last_refill = now  # 기기 시간이 뒤로 돌아간 경우
		return
	var gained := elapsed / TIME_REFILL_SEC
	if gained > 0:
		user.time = mini(MAX_TIME, user.time + gained)
		user.last_refill = now if user.time >= MAX_TIME else user.last_refill + gained * TIME_REFILL_SEC
		save()


func seconds_until_next_time() -> int:
	if user.is_empty() or user.time >= MAX_TIME:
		return 0
	return maxi(0, TIME_REFILL_SEC - (_now() - user.last_refill))


# ------------------------------------------------------------------ 메일

func send_mail(title: String, content: String, gold_reward: int, time_reward: int) -> void:
	user.mails.push_front({
		"id": "mail_%d_%d" % [_now(), user.mails.size()],
		"title": title,
		"content": content,
		"gold": gold_reward,
		"time": time_reward,
		"claimed": false,
		"sent_at": _now(),
	})
	save()


static func mail_has_reward(mail: Dictionary) -> bool:
	return int(mail.gold) > 0 or int(mail.time) > 0


func unclaimed_mail_count() -> int:
	if user.is_empty():
		return 0
	return user.mails.filter(func(m): return mail_has_reward(m) and not m.claimed).size()


## 메일 보상 받기. 시간은 최대치를 넘어서 받을 수 있다
func claim_mail(mail: Dictionary) -> bool:
	if mail.claimed:
		return false
	mail.claimed = true
	user.gold += int(mail.gold)
	user.time += int(mail.time)
	save()
	return true


func delete_claimed_mails() -> void:
	user.mails = user.mails.filter(func(m): return mail_has_reward(m) and not m.claimed)
	save()


# ------------------------------------------------------------------ 스테이지 결과

## 결과 반영. 이번에 처음 클리어했으면 true
func record_stage_result(stage_id: int, won: bool, score: int, gold_reward: int) -> bool:
	if user.is_empty():
		return false
	user.games_played += 1
	user.gold += gold_reward
	var key := str(stage_id)
	if score > int(user.best_scores.get(key, -1)):
		user.best_scores[key] = score
	user.high_score = maxi(user.high_score, score)
	var first_clear := false
	if won:
		user.games_won += 1
		if user.time < MAX_TIME:
			user.time += 1
		if stage_id > user.max_cleared:
			user.max_cleared = stage_id
			first_clear = true
			send_mail("스테이지 %d 첫 클리어 보상" % stage_id,
					"스테이지 %d을(를) 처음으로 클리어했습니다!\n보너스를 받아가세요." % stage_id,
					300 * stage_id, 2)
	save()
	return first_clear


## 무한 모드에서 버틴 웨이브 수 기록. 최고 기록을 넘었으면 true (저장은 record_stage_result 가 한다)
## 처음 만나는 적이면 기록하고 true (적 소개를 한 번만 보여 주려고)
func mark_enemy_seen(type_id: String) -> bool:
	if user.is_empty():
		return false
	var seen: Array = user.get("seen_enemies", [])
	if seen.has(type_id):
		return false
	seen.append(type_id)
	user["seen_enemies"] = seen
	save()
	return true


func record_endless_round(rounds: int) -> bool:
	if user.is_empty() or rounds <= int(user.get("round_best", 0)):
		return false
	user.round_best = rounds
	return true


# ------------------------------------------------------------------ 미션 / 업적 (정의는 Missions)

## 전투 한 판의 기록을 누적 기록과 오늘 미션에 반영
func record_session(session: Dictionary) -> void:
	if user.is_empty():
		return
	Missions.apply_session(user, session)
	save()


func claim_daily(m: Dictionary) -> bool:
	if m.claimed or not Missions.daily_done(m):
		return false
	m.claimed = true
	user.gold += int(Missions.daily_def(m.id).gold)
	save()
	return true


func claim_daily_bonus() -> bool:
	var d := Missions.daily(user)
	if d.bonus_claimed or not Missions.daily_all_done(user):
		return false
	d.bonus_claimed = true
	user.gold += Missions.DAILY_BONUS_GOLD
	user.time += Missions.DAILY_BONUS_TIME
	save()
	return true


func claim_achievement(a: Dictionary) -> bool:
	if not Missions.achievement_ready(user, a):
		return false
	var tier := Missions.next_tier(user, a)
	var claimed: Dictionary = user.get("achievements", {})
	claimed[a.id] = Missions.claimed_tiers(user, a) + 1
	user["achievements"] = claimed
	user.gold += int(tier[1])
	save()
	return true


func is_stage_unlocked(stage_id: int) -> bool:
	return has_user() and stage_id <= user.max_cleared + 1


func set_user_name(user_name: String) -> void:
	user.name = user_name
	save()


# ------------------------------------------------------------------ 설정

func game_speed() -> float:
	return settings.get_value("game", "speed", 1.0)


func set_game_speed(speed: float) -> void:
	settings.set_value("game", "speed", speed)
	settings.save(SETTINGS_PATH)


## 스킬 이펙트 스프라이트 불투명도 (0 = 안 보임, 1 = 원본)
func effect_alpha() -> float:
	return settings.get_value("game", "effect_alpha", 0.75)


func set_effect_alpha(alpha: float) -> void:
	settings.set_value("game", "effect_alpha", clampf(alpha, 0.0, 1.0))
	settings.save(SETTINGS_PATH)
