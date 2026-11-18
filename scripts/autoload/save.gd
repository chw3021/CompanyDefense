# 플레이어 데이터 저장/로드 (오프라인, user://save.json) 와 진행 규칙 (시간 충전, 메일, 스테이지 결과).
extends Node

signal changed

const PassDefs = preload("res://scripts/autoload/season_pass.gd")
const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.cfg"
const MAX_TIME := 5
const TIME_REFILL_SEC := 30 * 60
const NICKNAME_MAX := 10
const DEFAULT_NAME := "신입사원"
const RICH_GOLD := 99999999  # tools/build.ps1 -Me 로 만든 내 전용 APK (기능 태그 rich_start) 와 슈퍼계정 (Account.SUPER_UIDS) 에만 적용
const TIME_AD_AMOUNT := 2
const TIME_AD_DAILY_MAX := 5
const CORP_AD_AMOUNT := 1
const CORP_AD_DAILY_MAX := 5
const START_COIN_AD_BONUS := 120
const REST_COIN_BONUS := 150
const REST_CORP_COST := 1
const REROLL_CORP_COST := 1
const START_CORP_CARDS := 3

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
	apply_rich_start()
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
		"corp_card": START_CORP_CARDS,
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
	apply_rich_start()
	save()


## 내 전용 빌드(-Me) 이거나 슈퍼계정으로 연동된 경우
func is_rich() -> bool:
	if OS.has_feature("rich_start"):
		return true
	# Save 가 Account 보다 먼저 로드되므로 아직 없을 수 있다 (그때는 Account._ready 가 다시 적용한다)
	var account := get_node_or_null("/root/Account")
	return account != null and account.is_super()


## 켤 때마다 골드를 RICH_GOLD 까지 채우고, 시간을 가득 채우고, 모든 스테이지와 직원 최대 레벨(신화 해금 포함)을 연다
func apply_rich_start() -> void:
	if not is_rich():
		return
	user.gold = maxi(user.gold, RICH_GOLD)
	user.time = MAX_TIME
	user.corp_card = maxi(int(user.get("corp_card", 0)), 99)
	user.max_cleared = maxi(user.max_cleared, StageDefs.COUNT - 1)
	for id in user.towers:
		user.towers[id] = GameData.MAX_TOWER_LEVEL


## 클라우드에서 받은 데이터로 바꾼다
func replace_user(data: Dictionary) -> void:
	user = data
	_normalize()
	apply_rich_start()
	refresh_time()
	save()


func reset() -> void:
	user = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	changed.emit()


## 데이터에 새 직원/취미/장비가 추가되었으면 채우고, 사라진 직원은 지운다
func _normalize() -> void:
	for key in ["towers", "hobbies", "equipment", "best_scores", "desk_prefs"]:
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
	for key in ["gold", "time", "corp_card", "last_refill", "max_cleared", "round_best", "high_score", "games_played", "games_won"]:
		user[key] = int(user.get(key, 0))
	# 기존 세이브에 법인카드 시드 지급 (한 번만)
	if int(user.get("corp_card_seeded", 0)) < 1:
		user.corp_card = maxi(int(user.corp_card), START_CORP_CARDS)
		user["corp_card_seeded"] = 1
	if String(user.get("name", "")).strip_edges() == "":
		user["name"] = DEFAULT_NAME
	user["ads_removed"] = bool(user.get("ads_removed", false))
	_normalize_pass()


# ------------------------------------------------------------------ 재화

func gold() -> int:
	return user.get("gold", 0)


func add_gold(amount: int) -> void:
	if user.is_empty() or amount == 0:
		return
	user.gold = maxi(0, int(user.gold) + amount)
	save()


func spend_gold(amount: int) -> bool:
	if user.is_empty() or user.gold < amount:
		return false
	user.gold -= amount
	save()
	return true


func corp_card() -> int:
	return int(user.get("corp_card", 0))


func add_corp_card(amount: int) -> void:
	if user.is_empty() or amount == 0:
		return
	user.corp_card = maxi(0, corp_card() + amount)
	save()


func spend_corp_card(amount: int) -> bool:
	if user.is_empty() or corp_card() < amount:
		return false
	user.corp_card -= amount
	save()
	return true


func add_time(amount: int) -> void:
	if user.is_empty() or amount <= 0:
		return
	user.time = int(user.time) + amount
	save()


func spend_time() -> bool:
	if user.is_empty():
		return false
	if is_rich():  # 내 전용 빌드와 슈퍼계정은 시간이 줄지 않는다
		return true
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


# ------------------------------------------------------------------ 광고 일일 한도 / 시작 코인

func _ads_daily() -> Dictionary:
	var a: Dictionary = user.get("ads_daily", {})
	if str(a.get("date", "")) != Missions.today():
		a = {"date": Missions.today(), "time": 0, "corp": 0}
		user["ads_daily"] = a
	return a


func time_ad_left() -> int:
	if user.is_empty():
		return 0
	return maxi(0, TIME_AD_DAILY_MAX - int(_ads_daily().get("time", 0)))


func corp_ad_left() -> int:
	if user.is_empty():
		return 0
	return maxi(0, CORP_AD_DAILY_MAX - int(_ads_daily().get("corp", 0)))


## 광고 시청 성공 후 호출. 성공하면 충전된 시간 수, 실패(한도)면 0
func grant_time_from_ad() -> int:
	if user.is_empty() or time_ad_left() <= 0:
		return 0
	_ads_daily()["time"] = int(_ads_daily().get("time", 0)) + 1
	add_time(TIME_AD_AMOUNT)
	return TIME_AD_AMOUNT


## 광고 시청 성공 후 호출. 성공하면 지급된 법인카드 수
func grant_corp_from_ad() -> int:
	if user.is_empty() or corp_ad_left() <= 0:
		return 0
	_ads_daily()["corp"] = int(_ads_daily().get("corp", 0)) + 1
	add_corp_card(CORP_AD_AMOUNT)
	return CORP_AD_AMOUNT


func set_pending_start_coin_bonus(amount: int) -> void:
	settings.set_value("game", "pending_start_coin", amount)
	settings.save(SETTINGS_PATH)


func take_pending_start_coin_bonus() -> int:
	var n := int(settings.get_value("game", "pending_start_coin", 0))
	settings.set_value("game", "pending_start_coin", 0)
	settings.save(SETTINGS_PATH)
	return n


func ads_removed() -> bool:
	return bool(user.get("ads_removed", false))


# ------------------------------------------------------------------ 상점 / 시즌 패스

## 상점 상품. cost_corp > 0 이면 법인카드, ad 면 광고, flag 는 일회성 해금
## accent: gold / purple / blue / danger / success (카드 장식색)
const SHOP_ITEMS := [
	{"id": "gold_s", "name": "월급 보너스 (소)", "desc": "골드 1,000", "cost_corp": 3, "gold": 1000,
			"icon": "res://assets/icons/gold_pack.svg", "accent": "gold"},
	{"id": "gold_m", "name": "월급 보너스 (중)", "desc": "골드 3,500", "cost_corp": 8, "gold": 3500,
			"icon": "res://assets/icons/gold_pack.svg", "accent": "gold"},
	{"id": "gold_l", "name": "성과급 뭉치", "desc": "골드 8,000", "cost_corp": 15, "gold": 8000,
			"icon": "res://assets/icons/coin.svg", "accent": "gold"},
	{"id": "time_pack", "name": "반차 신청", "desc": "시간 +3", "cost_corp": 2, "time": 3,
			"icon": "res://assets/icons/waste.svg", "accent": "blue"},
	{"id": "corp_ad", "name": "법인카드 충전", "desc": "광고로 법인카드 +1 (일일 한도)", "ad": true,
			"icon": "res://assets/icons/corp_card.svg", "accent": "purple"},
	{"id": "pass_prem", "name": "프리미엄 출근 패스", "desc": "유료 패스 트랙 해금 + 즉시 보너스", "cost_corp": 15, "unlock_pass": true,
			"icon": "res://assets/icons/pass_premium.svg", "accent": "purple"},
	{"id": "no_banner", "name": "배너 광고 제거", "desc": "로비 배너 제거 (보상형은 유지)", "cost_corp": 25, "no_ads": true,
			"icon": "res://assets/icons/cancel.png", "accent": "danger"},
]


func _normalize_pass() -> void:
	if user.is_empty():
		return
	var p: Dictionary = user.get("pass", {})
	if int(p.get("season", 0)) != PassDefs.SEASON_ID:
		p = {
			"season": PassDefs.SEASON_ID,
			"xp": 0,
			"premium": false,
			"claimed_free": [],
			"claimed_prem": [],
		}
	p["season"] = PassDefs.SEASON_ID
	p["xp"] = int(p.get("xp", 0))
	p["premium"] = bool(p.get("premium", false))
	for key in ["claimed_free", "claimed_prem"]:
		var raw: Array = p.get(key, [])
		var cleaned: Array = []
		for v in raw:
			var n := int(v)
			if n >= 1 and n <= PassDefs.MAX_LEVEL and not cleaned.has(n):
				cleaned.append(n)
		p[key] = cleaned
	user["pass"] = p


func pass_data() -> Dictionary:
	_normalize_pass()
	return user["pass"]


func add_pass_xp(amount: int, do_save := true) -> void:
	if user.is_empty() or amount <= 0:
		return
	var p := pass_data()
	var cap := PassDefs.MAX_LEVEL * PassDefs.XP_PER_LEVEL
	p.xp = mini(cap, int(p.xp) + amount)
	user["pass"] = p
	if do_save:
		save()


func unlock_pass_premium() -> bool:
	var p := pass_data()
	if p.premium:
		return false
	if not spend_corp_card(PassDefs.PREMIUM_CORP_COST):
		return false
	p.premium = true
	user["pass"] = p
	# 구매 즉시 보너스 (스토어 연동 전: 법인카드 결제 대용)
	user.gold += 1000
	user.time += 2
	save()
	return true


func _claim_has(list: Array, level: int) -> bool:
	return list.has(level) or list.has(float(level))


func is_pass_claimed(level: int, premium: bool) -> bool:
	var p := pass_data()
	return _claim_has(p["claimed_prem" if premium else "claimed_free"], level)


func can_claim_pass(level: int, premium: bool) -> bool:
	var p := pass_data()
	if level < 1 or level > PassDefs.level_from_xp(int(p.xp)):
		return false
	if premium and not p.premium:
		return false
	var key := "claimed_prem" if premium else "claimed_free"
	return not _claim_has(p[key], level)


func claim_pass_reward(level: int, premium: bool) -> bool:
	if not can_claim_pass(level, premium):
		return false
	var p := pass_data()
	var key := "claimed_prem" if premium else "claimed_free"
	var claimed: Array = p[key]
	claimed.append(level)
	p[key] = claimed
	user["pass"] = p
	var r := PassDefs.reward(level, premium)
	if int(r.get("gold", 0)) > 0:
		user.gold += int(r.gold)
	if int(r.get("time", 0)) > 0:
		user.time += int(r.time)
	if int(r.get("corp", 0)) > 0:
		user.corp_card = corp_card() + int(r.corp)
	save()
	return true


## 상점 구매. 성공 메시지 또는 실패 사유
func buy_shop_item(item_id: String) -> String:
	if user.is_empty():
		return "저장 데이터가 없습니다."
	var item := {}
	for it in SHOP_ITEMS:
		if it.id == item_id:
			item = it
			break
	if item.is_empty():
		return "상품을 찾을 수 없습니다."
	if item.get("unlock_pass", false):
		if pass_data().premium:
			return "이미 프리미엄 패스를 보유 중입니다."
		if not unlock_pass_premium():
			return "법인카드가 부족합니다."
		return "프리미엄 출근 패스를 해금했습니다!"
	if item.get("no_ads", false):
		if ads_removed():
			return "이미 배너 광고 제거를 구매했습니다."
		if not spend_corp_card(int(item.cost_corp)):
			return "법인카드가 부족합니다."
		user["ads_removed"] = true
		save()
		return "배너 광고 제거가 적용되었습니다."
	if item.get("ad", false):
		return "AD"  # UI 가 광고 플로우 처리
	var cost := int(item.get("cost_corp", 0))
	if cost > 0 and not spend_corp_card(cost):
		return "법인카드가 부족합니다."
	if int(item.get("gold", 0)) > 0:
		user.gold += int(item.gold)
	if int(item.get("time", 0)) > 0:
		user.time += int(item.time)
	save()
	return "구매가 완료되었습니다."


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


## 광고로 메일 보상의 절반을 한 번 더 (이미 받은 메일만)
func claim_mail_ad_bonus(mail: Dictionary) -> bool:
	if not mail.claimed or mail.get("ad_bonus", false):
		return false
	if not mail_has_reward(mail):
		return false
	mail["ad_bonus"] = true
	user.gold += int(mail.gold) / 2
	user.time += int(mail.time) / 2
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
	add_pass_xp(PassDefs.XP_PLAY + (PassDefs.XP_WIN if won else 0), false)
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


## 일일 미션 광고 추가 보상 (골드 절반, 미션당 1회)
func claim_daily_ad_bonus(m: Dictionary) -> bool:
	if not m.claimed or m.get("ad_bonus", false):
		return false
	m["ad_bonus"] = true
	user.gold += int(Missions.daily_def(m.id).gold) / 2
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


func claim_daily_bonus_ad() -> bool:
	var d := Missions.daily(user)
	if not d.bonus_claimed or d.get("bonus_ad", false):
		return false
	d["bonus_ad"] = true
	user.gold += Missions.DAILY_BONUS_GOLD / 2
	user.time += maxi(1, Missions.DAILY_BONUS_TIME / 2) if Missions.DAILY_BONUS_TIME > 0 else 0
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


## 업적 광고 추가 보상. key = "업적id:단계"
func claim_achievement_ad_bonus(a: Dictionary, tier_index: int, gold_amount: int) -> bool:
	var key := "%s:%d" % [a.id, tier_index]
	var boosted: Dictionary = user.get("achievement_ad", {})
	if boosted.get(key, false):
		return false
	boosted[key] = true
	user["achievement_ad"] = boosted
	user.gold += gold_amount / 2
	save()
	return true

func achievement_ad_done(a: Dictionary, tier_index: int) -> bool:
	return bool(user.get("achievement_ad", {}).get("%s:%d" % [a.id, tier_index], false))


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


## 이펙트 품질: on(켜기) / min(최소화) / off(끄기)
const FX_ON := "on"
const FX_MIN := "min"
const FX_OFF := "off"
const FX_ORDER := [FX_ON, FX_MIN, FX_OFF]


func effect_quality() -> String:
	var q: String = str(settings.get_value("game", "effect_quality", FX_ON))
	return q if q in FX_ORDER else FX_ON


func set_effect_quality(quality: String) -> void:
	settings.set_value("game", "effect_quality", quality if quality in FX_ORDER else FX_ON)
	settings.save(SETTINGS_PATH)


func cycle_effect_quality() -> String:
	var next: String = FX_ORDER[(FX_ORDER.find(effect_quality()) + 1) % FX_ORDER.size()]
	set_effect_quality(next)
	return next


func effect_quality_label(quality := "") -> String:
	match quality if not quality.is_empty() else effect_quality():
		FX_MIN:
			return "최소화"
		FX_OFF:
			return "끄기"
		_:
			return "켜기"


## 저사양: 이펙트 끄기 + 투사체 히트 연출 생략 + 데미지 숫자 합치기 강화
func apply_low_perf_preset() -> void:
	set_effect_quality(FX_OFF)
	set_lite_projectiles(true)
	set_dmg_batch_sec(0.55)


func lite_projectiles() -> bool:
	return bool(settings.get_value("game", "lite_projectiles", false))


func set_lite_projectiles(on: bool) -> void:
	settings.set_value("game", "lite_projectiles", on)
	settings.save(SETTINGS_PATH)


## 데미지 숫자를 모아서 띄우는 간격 (초). 길수록 글자가 덜 뜬다
func dmg_batch_sec() -> float:
	return float(settings.get_value("game", "dmg_batch_sec", 0.25))


func set_dmg_batch_sec(sec: float) -> void:
	settings.set_value("game", "dmg_batch_sec", clampf(sec, 0.15, 1.0))
	settings.save(SETTINGS_PATH)


func volume_master() -> float:
	return float(settings.get_value("audio", "master", 1.0))


func volume_bgm() -> float:
	return float(settings.get_value("audio", "bgm", 0.8))


func volume_sfx() -> float:
	return float(settings.get_value("audio", "sfx", 1.0))


func set_volume_master(v: float) -> void:
	settings.set_value("audio", "master", clampf(v, 0.0, 1.0))
	settings.save(SETTINGS_PATH)
	Audio.apply_volumes()


func set_volume_bgm(v: float) -> void:
	settings.set_value("audio", "bgm", clampf(v, 0.0, 1.0))
	settings.save(SETTINGS_PATH)
	Audio.apply_volumes()


func set_volume_sfx(v: float) -> void:
	settings.set_value("audio", "sfx", clampf(v, 0.0, 1.0))
	settings.save(SETTINGS_PATH)
	Audio.apply_volumes()


## 자동 승진: 1~max 성까지 합침 (기본 1)
func merge_auto_grade() -> int:
	return clampi(int(settings.get_value("game", "merge_auto_grade", 1)), 1, GameData.MAX_GRADE - 1)


func set_merge_auto_grade(grade: int) -> void:
	settings.set_value("game", "merge_auto_grade", clampi(grade, 1, GameData.MAX_GRADE - 1))
	settings.save(SETTINGS_PATH)


## 자동 승진 팀 필터 ("" = 전체)
func merge_auto_team() -> String:
	var team: String = str(settings.get_value("game", "merge_auto_team", ""))
	return team if team in GameData.TEAMS else ""


func set_merge_auto_team(team: String) -> void:
	settings.set_value("game", "merge_auto_team", team if team in GameData.TEAMS else "")
	settings.save(SETTINGS_PATH)


func cycle_merge_auto_grade() -> int:
	var next := merge_auto_grade() % (GameData.MAX_GRADE - 1) + 1
	set_merge_auto_grade(next)
	return next


func cycle_merge_auto_team() -> String:
	var order: Array = [""] + GameData.TEAMS.duplicate()
	var i := order.find(merge_auto_team())
	var next: String = order[(maxi(i, 0) + 1) % order.size()]
	set_merge_auto_team(next)
	return next


func merge_auto_team_label(team: Variant = null) -> String:
	var t: String = merge_auto_team() if team == null else str(team)
	return GameData.team_name(t) if t in GameData.TEAMS else "전체"


## 스테이지별 선호 책상. 슬롯 0~2. 옛 형식(배열)은 슬롯 0으로 읽는다
const DESK_SLOTS := 3


func desk_pref_slot() -> int:
	return clampi(int(settings.get_value("game", "desk_pref_slot", 0)), 0, DESK_SLOTS - 1)


func set_desk_pref_slot(slot: int) -> void:
	settings.set_value("game", "desk_pref_slot", clampi(slot, 0, DESK_SLOTS - 1))
	settings.save(SETTINGS_PATH)


func cycle_desk_pref_slot() -> int:
	var next := (desk_pref_slot() + 1) % DESK_SLOTS
	set_desk_pref_slot(next)
	return next


func desk_prefs(stage_id: int, slot := -1) -> Array:
	var s := desk_pref_slot() if slot < 0 else slot
	var raw = user.get("desk_prefs", {}).get(str(stage_id), null)
	if typeof(raw) == TYPE_ARRAY:
		return raw if s == 0 else []
	if typeof(raw) == TYPE_DICTIONARY:
		var cells = raw.get(str(s), [])
		return cells if typeof(cells) == TYPE_ARRAY else []
	return []


func set_desk_prefs(stage_id: int, cells: Array, slot := -1) -> void:
	if not user.has("desk_prefs") or typeof(user.desk_prefs) != TYPE_DICTIONARY:
		user.desk_prefs = {}
	var key := str(stage_id)
	var bag = user.desk_prefs.get(key, {})
	if typeof(bag) == TYPE_ARRAY:
		bag = {"0": bag}
	elif typeof(bag) != TYPE_DICTIONARY:
		bag = {}
	var encoded: Array = []
	for c in cells:
		if c is Vector2i:
			encoded.append("%d,%d" % [c.x, c.y])
		elif typeof(c) == TYPE_STRING:
			encoded.append(c)
	var s := desk_pref_slot() if slot < 0 else slot
	bag[str(s)] = encoded
	user.desk_prefs[key] = bag
	save()


func clear_desk_prefs(stage_id: int, slot := -1) -> void:
	var key := str(stage_id)
	if not user.get("desk_prefs", {}).has(key):
		return
	var s := desk_pref_slot() if slot < 0 else slot
	var bag = user.desk_prefs[key]
	if typeof(bag) == TYPE_ARRAY:
		if s == 0:
			user.desk_prefs.erase(key)
	elif typeof(bag) == TYPE_DICTIONARY:
		bag.erase(str(s))
		if bag.is_empty():
			user.desk_prefs.erase(key)
		else:
			user.desk_prefs[key] = bag
	save()


func parse_desk_cell(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))


func sfx_muted() -> bool:
	return bool(settings.get_value("audio", "muted", false))


func set_sfx_muted(on: bool) -> void:
	settings.set_value("audio", "muted", on)
	settings.save(SETTINGS_PATH)
	Audio.apply_volumes()


func toggle_sfx_muted() -> bool:
	set_sfx_muted(not sfx_muted())
	return sfx_muted()


## 고용 팀 필터 ("" = 랜덤 전체). 지정 시 비용 할증
func hire_team() -> String:
	var team: String = str(settings.get_value("game", "hire_team", ""))
	return team if team in GameData.TEAMS else ""


func set_hire_team(team: String) -> void:
	settings.set_value("game", "hire_team", team if team in GameData.TEAMS else "")
	settings.save(SETTINGS_PATH)


func cycle_hire_team() -> String:
	var order: Array = [""] + GameData.TEAMS.duplicate()
	var i := order.find(hire_team())
	var next: String = order[(maxi(i, 0) + 1) % order.size()]
	set_hire_team(next)
	return next


func hire_team_label(team: Variant = null) -> String:
	var t: String = hire_team() if team == null else str(team)
	return GameData.team_name(t) if t in GameData.TEAMS else "전체"


## 공격 우선순위 오버라이드: auto / nearest / furthest / strongest / weakest / boss
const TARGET_MODES := ["auto", "nearest", "furthest", "strongest", "weakest", "boss"]
const TARGET_LABELS := {
	"auto": "기본", "nearest": "가까운 적", "furthest": "앞선 적",
	"strongest": "체력 높은 적", "weakest": "체력 낮은 적", "boss": "보스 우선",
}
## 인게임 좁은 버튼용 짧은 표시
const TARGET_LABELS_SHORT := {
	"auto": "기본", "nearest": "근접", "furthest": "선두",
	"strongest": "강적", "weakest": "약적", "boss": "보스",
}


func target_mode() -> String:
	var m: String = str(settings.get_value("game", "target_mode", "auto"))
	return m if m in TARGET_MODES else "auto"


func set_target_mode(mode: String) -> void:
	settings.set_value("game", "target_mode", mode if mode in TARGET_MODES else "auto")
	settings.save(SETTINGS_PATH)


func cycle_target_mode() -> String:
	var i := TARGET_MODES.find(target_mode())
	var next: String = TARGET_MODES[(maxi(i, 0) + 1) % TARGET_MODES.size()]
	set_target_mode(next)
	return next


func target_mode_label(mode: Variant = null) -> String:
	var m: String = target_mode() if mode == null else str(mode)
	return TARGET_LABELS.get(m, "기본")


func target_mode_short(mode: Variant = null) -> String:
	var m: String = target_mode() if mode == null else str(mode)
	return TARGET_LABELS_SHORT.get(m, "기본")


## 인게임 HUD 이펙트 버튼용 (좁은 칸)
func effect_quality_short(quality := "") -> String:
	match quality if not quality.is_empty() else effect_quality():
		FX_MIN:
			return "최소"
		FX_OFF:
			return "끔"
		_:
			return "이펙"


func last_run_seed() -> int:
	return int(settings.get_value("game", "last_run_seed", 0))


func set_last_run_seed(seed: int) -> void:
	settings.set_value("game", "last_run_seed", seed)
	settings.save(SETTINGS_PATH)


func pending_run_seed() -> int:
	return int(settings.get_value("game", "pending_run_seed", 0))


func set_pending_run_seed(seed: int) -> void:
	settings.set_value("game", "pending_run_seed", seed)
	settings.save(SETTINGS_PATH)


func clear_pending_run_seed() -> void:
	settings.set_value("game", "pending_run_seed", 0)
	settings.save(SETTINGS_PATH)


## 세이브 JSON 문자열 (민감정보 없이 진행 데이터만)
func export_user_json() -> String:
	return JSON.stringify(user, "\t")


func import_user_json(text: String) -> String:
	var parsed = JSON.parse_string(text.strip_edges())
	if typeof(parsed) != TYPE_DICTIONARY:
		return "형식이 올바르지 않습니다."
	if String(parsed.get("name", "")).strip_edges() == "":
		return "닉네임이 없는 데이터입니다."
	replace_user(parsed)
	return ""

