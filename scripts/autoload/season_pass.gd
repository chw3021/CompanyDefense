# 시즌 패스 정의와 진행도 계산. 저장은 Save.pass_data() 가 맡는다.
class_name SeasonPass

const SEASON_ID := 1
const SEASON_NAME := "입사 1기"
const XP_PER_LEVEL := 100
const MAX_LEVEL := 20
const PREMIUM_CORP_COST := 15
const XP_PLAY := 30
const XP_WIN := 50


static func level_from_xp(xp: int) -> int:
	return clampi(int(xp) / XP_PER_LEVEL, 0, MAX_LEVEL)


static func xp_into_level(xp: int) -> int:
	if level_from_xp(xp) >= MAX_LEVEL:
		return XP_PER_LEVEL
	return int(xp) % XP_PER_LEVEL


static func xp_to_next(xp: int) -> int:
	if level_from_xp(xp) >= MAX_LEVEL:
		return 0
	return XP_PER_LEVEL - xp_into_level(xp)


## 레벨 보상. gold / time / corp 키만 사용 (0 이면 없음)
static func reward(level: int, premium: bool) -> Dictionary:
	if level < 1 or level > MAX_LEVEL:
		return {}
	if premium:
		return {
			"gold": 250 * level,
			"time": 1 if level % 3 == 0 else 0,
			"corp": 1 if level % 5 == 0 else (2 if level == MAX_LEVEL else 0),
		}
	return {
		"gold": 120 * level,
		"time": 1 if level % 4 == 0 else 0,
		"corp": 1 if level == 10 or level == MAX_LEVEL else 0,
	}


static func reward_text(r: Dictionary) -> String:
	var parts: Array[String] = []
	if int(r.get("gold", 0)) > 0:
		parts.append("골드 %d" % int(r.gold))
	if int(r.get("time", 0)) > 0:
		parts.append("시간 %d" % int(r.time))
	if int(r.get("corp", 0)) > 0:
		parts.append("법인카드 %d" % int(r.corp))
	return " / ".join(PackedStringArray(parts)) if not parts.is_empty() else "없음"


static func claimable_count(user: Dictionary) -> int:
	if user.is_empty():
		return 0
	var p: Dictionary = user.get("pass", {})
	if int(p.get("season", 0)) != SEASON_ID:
		return 0
	var lv := level_from_xp(int(p.get("xp", 0)))
	var n := 0
	var free_claimed: Array = p.get("claimed_free", [])
	var prem_claimed: Array = p.get("claimed_prem", [])
	var premium := bool(p.get("premium", false))
	for i in range(1, lv + 1):
		if not free_claimed.has(i) and not free_claimed.has(float(i)):
			n += 1
		if premium and not prem_claimed.has(i) and not prem_claimed.has(float(i)):
			n += 1
	return n
