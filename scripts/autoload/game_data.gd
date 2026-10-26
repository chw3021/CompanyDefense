# 게임 정적 데이터 (타워, 스킬, 취미, 장비). res://assets/data/gamedata.json 에서 읽는다.
# 취미/장비가 타워 능력치에 주는 보너스 계산도 여기서 한다.
extends Node

const TEAMS := ["hr", "dv", "sl"]
const TEAM_NAMES := {"hr": "인사", "dv": "개발", "sl": "영업"}
const TEAM_COLORS := {"hr": Color("ff7eb6"), "dv": Color("4c8dff"), "sl": Color("ffb648")}
const GRADE_COLORS := [Color("b8c0cc"), Color("4cd17a"), Color("4c9dff"), Color("b07cff"), Color("ffa53d")]
const GRADE_NAMES := ["일반", "고급", "희귀", "영웅", "전설"]
const MAX_GRADE := 5
const MAX_TOWER_LEVEL := 30
const MAX_EQUIPMENT_LEVEL := 10
## 스킬 쿨타임은 최대 50% 까지만 줄어든다
const MIN_COOLDOWN_MULT := 0.5

var towers := {}      # towerId(tower_dv1) -> Dictionary
var tower_ids: Array[String] = []
var skills := {}      # skillId(dv1) -> Dictionary
var hobbies := {}     # hobbyId -> Dictionary
var hobby_ids: Array[String] = []
var equipment := {}   # eqId -> Dictionary
var equipment_ids: Array[String] = []


func _init() -> void:
	var text := FileAccess.get_file_as_string("res://assets/data/gamedata.json")
	var root: Dictionary = JSON.parse_string(text)
	for key in root["towers"]:
		var t: Dictionary = root["towers"][key]
		towers[t["towerId"]] = t
		tower_ids.append(t["towerId"])
	skills = root["skills"]
	hobbies = root["hobbies"]
	for key in hobbies:
		hobby_ids.append(key)
	equipment = root["equipment"]
	for key in equipment:
		equipment_ids.append(key)


func skill_for_tower(tower: Dictionary) -> Dictionary:
	return skills.get(String(tower["towerId"]).trim_prefix("tower_"), {})


func towers_of_grade(grade: int) -> Array:
	return tower_ids.filter(func(id): return int(towers[id]["towerGrade"]) == grade)


static func team_name(team: String) -> String:
	return TEAM_NAMES.get(team, team)


static func grade_color(grade: int) -> Color:
	return GRADE_COLORS[clampi(grade - 1, 0, GRADE_COLORS.size() - 1)]


static func asset(path: String) -> String:
	return "res://assets/" + path


# ------------------------------------------------------------------ 취미 / 장비 보너스

## 레벨당 효과 수치. stock 은 코인, 나머지는 비율
static func hobby_rate(hobby_id: String) -> float:
	match hobby_id:
		"exercise": return 0.02    # 물리 공격력 +2%
		"reading": return 0.02     # 마법 공격력 +2%
		"game": return 0.01        # 공격 속도 +1%
		"instrument": return 0.01  # 스킬 쿨타임 -1%
		"stock": return 20.0       # 시작 코인 +20
	return 0.0


static func hobby_effect_text(hobby_id: String, level: int) -> String:
	var value := hobby_rate(hobby_id) * level
	match hobby_id:
		"exercise": return "물리 공격력 +%d%%" % roundi(value * 100)
		"reading": return "마법 공격력 +%d%%" % roundi(value * 100)
		"game": return "공격 속도 +%d%%" % roundi(value * 100)
		"instrument": return "스킬 쿨타임 -%d%%" % roundi(minf(value, 1 - MIN_COOLDOWN_MULT) * 100)
		"stock": return "시작 코인 +%d" % int(value)
	return ""


func equipment_effect_text(eq: Dictionary, level: int) -> String:
	var value := float(eq["perLevel"]) * level * 100
	var target := "모든 직원" if eq["team"] == "all" else team_name(eq["team"]) + "팀"
	match eq["stat"]:
		"attack": return "%s 공격력 +%d%%" % [target, roundi(value)]
		"speed": return "%s 공격 속도 +%d%%" % [target, roundi(value)]
		"cooldown": return "%s 스킬 쿨타임 -%d%%" % [target, roundi(value)]
	return ""


## 팀별 능력치 배율 {physical, magic, speed, cooldown}
func stat_bonus(user: Dictionary, team: String) -> Dictionary:
	var bonus := {"physical": 1.0, "magic": 1.0, "speed": 1.0, "cooldown": 1.0}
	if user.is_empty():
		return bonus
	var hobby_levels: Dictionary = user["hobbies"]
	bonus.physical += hobby_rate("exercise") * int(hobby_levels.get("exercise", 0))
	bonus.magic += hobby_rate("reading") * hobby_levels.get("reading", 0)
	bonus.speed += hobby_rate("game") * hobby_levels.get("game", 0)
	var cooldown_reduction: float = hobby_rate("instrument") * hobby_levels.get("instrument", 0)
	var eq_levels: Dictionary = user["equipment"]
	for eq_id in eq_levels:
		var level: int = eq_levels[eq_id]
		if level <= 0 or not equipment.has(eq_id):
			continue
		var eq: Dictionary = equipment[eq_id]
		if eq["team"] != "all" and eq["team"] != team:
			continue
		var value := float(eq["perLevel"]) * level
		match eq["stat"]:
			"attack":
				bonus.physical += value
				bonus.magic += value
			"speed":
				bonus.speed += value
			"cooldown":
				cooldown_reduction += value
	bonus.cooldown = maxf(MIN_COOLDOWN_MULT, 1.0 - cooldown_reduction)
	return bonus


func start_coin_bonus(user: Dictionary) -> int:
	if user.is_empty():
		return 0
	return int(hobby_rate("stock") * user["hobbies"].get("stock", 0))


# ------------------------------------------------------------------ 성장 비용

static func tower_upgrade_cost(tower: Dictionary, current_level: int) -> int:
	return 50 * int(tower["towerGrade"]) * (current_level + 1)


static func equipment_cost(eq: Dictionary, level: int) -> int:
	return int(eq["baseCost"]) * (level + 1)
