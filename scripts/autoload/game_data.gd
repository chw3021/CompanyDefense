# 게임 정적 데이터 (타워, 스킬, 취미, 장비). res://assets/data/gamedata.json 에서 읽는다.
# 취미/장비가 타워 능력치에 주는 보너스 계산도 여기서 한다.
extends Node

const TEAMS := ["hr", "dv", "sl"]
const TEAM_NAMES := {"hr": "인사", "dv": "개발", "sl": "영업"}
const TEAM_COLORS := {"hr": Color("ff7eb6"), "dv": Color("4c8dff"), "sl": Color("ffb648")}
const GRADE_COLORS := [Color("b8c0cc"), Color("4cd17a"), Color("4c9dff"), Color("b07cff"), Color("ffa53d"), Color("ff5c8a")]
const GRADE_NAMES := ["일반", "고급", "희귀", "영웅", "전설", "신화"]
const MAX_GRADE := 5      # 승진(같은 직원 합치기)으로 오를 수 있는 최고 등급
const MYTHIC_GRADE := 6   # 신화: 전설 + 조합 재료로만 각성

## 신화 직원. 전설(base)과 다른 두 팀의 전설 한 명씩, 전설 셋을 모으면 base 가 신화로 각성한다.
## 만들기가 아주 어려운 만큼 능력치는 전설의 MYTHIC_STAT_MULT 배, 스킬은 맵 전체급.
## 그림은 image 가 있으면 그것을, 없으면 base 의 것을 쓴다. 능력치와 레벨은 level_source(base) 전설을 따른다
## 신화는 그 팀 직원이 모두 MYTHIC_UNLOCK_LEVEL 이상이어야 해금된다 (해금 전에는 각성 불가)
const MYTHICS := {
	"tower_dv6_1": {"base": "tower_dv5_1", "name": "천재 개발자", "recipe": ["tower_hr5_1", "tower_sl5_2"], "image": "tower/dv/dv6_1",
			"skill": {"skillName": "전체 리팩토링", "mult": 5.0, "cooldown": 12.0, "duration": 0.8, "range": 0.0,
			"description": "맵 위의 모든 적에게 마법 공격력의 500% 피해를 주고 0.8초 동안 기절시킵니다. (보스는 기절하지 않음)"}},
	"tower_dv6_2": {"base": "tower_dv5_2", "name": "화이트 해커", "recipe": ["tower_hr5_2", "tower_sl5_1"], "image": "tower/dv/dv6_2",
			"skill": {"skillName": "방화벽 구축", "mult": 0.25, "cooldown": 15.0, "duration": 6.0, "range": 0.0,
			"description": "맵 위의 모든 적에게 6초 동안 0.1초마다 마법 공격력의 25% 피해를 주고 30% 느리게 만듭니다."}},
	"tower_hr6_1": {"base": "tower_hr5_1", "name": "인사 부사장", "recipe": ["tower_dv5_2", "tower_sl5_1"], "image": "tower/hr/hr6_1",
			"skill": {"skillName": "성과급 지급", "mult": 1.0, "cooldown": 15.0, "duration": 6.0, "range": 0.0,
			"description": "가장 강한 아군 3명의 공격력과 공격 속도를 6초 동안 100% 올리고 스킬을 바로 쓸 수 있게 합니다."}},
	"tower_hr6_2": {"base": "tower_hr5_2", "name": "복지의 여신", "recipe": ["tower_dv5_1", "tower_sl5_2"], "image": "tower/hr/hr6_2",
			"skill": {"skillName": "전사 워크숍", "mult": 0.5, "cooldown": 18.0, "duration": 6.0, "range": 0.0,
			"description": "모든 아군의 공격력과 공격 속도를 6초 동안 50% 올리고, 모든 적을 0.6초 동안 기절시킵니다. (보스는 기절하지 않음)"}},
	"tower_sl6_1": {"base": "tower_sl5_1", "name": "대표이사", "recipe": ["tower_dv5_1", "tower_hr5_2"], "image": "tower/sl/sl6_1",
			"skill": {"skillName": "인수합병", "mult": 0.4, "cooldown": 12.0, "duration": 1.0, "range": 0.0,
			"description": "맵 위에서 체력이 40% 이하인 일반 적을 모두 즉시 처치하고 한 마리당 코인 2개를 얻습니다. (보스는 물리 공격력의 800% 피해)"}},
	"tower_sl6_2": {"base": "tower_sl5_2", "name": "글로벌 영업왕", "recipe": ["tower_dv5_2", "tower_hr5_1"], "image": "tower/sl/sl6_2",
			"skill": {"skillName": "해외 수주", "mult": 4.0, "cooldown": 10.0, "duration": 3.0, "range": 4.0,
			"description": "사거리 4칸 안의 적에게 물리 공격력의 400% 피해를 주고 3초 동안 60% 느리게 만들며 코인 30개를 얻습니다."}},
	# 특수 직원(유물)이 base 인 신화
	"tower_dv6_3": {"base": "tower_dv7", "name": "AI 연구소장", "recipe": ["tower_hr5_1", "tower_sl5_1"], "image": "tower/dv/dv6_3",
			"skill": {"skillName": "특이점", "mult": 7.0, "cooldown": 10.0, "duration": 2.0, "range": 0.0,
			"description": "체력이 가장 많은 적 5명에게 마법 공격력의 700% 피해를 주고 2초 동안 기절시킵니다. (보스는 기절하지 않음)"}},
	"tower_hr6_3": {"base": "tower_hr7", "name": "헤드헌팅 대표", "recipe": ["tower_dv5_2", "tower_sl5_2"], "image": "tower/hr/hr6_3",
			"skill": {"skillName": "인재 쟁탈전", "mult": 0.6, "cooldown": 14.0, "duration": 6.0, "range": 0.0,
			"description": "모든 적의 방어력을 6초 동안 50 낮추고, 모든 아군의 공격 속도를 6초 동안 60% 올립니다."}},
	"tower_sl6_3": {"base": "tower_sl7", "name": "벤처 캐피털리스트", "recipe": ["tower_dv5_1", "tower_hr5_1"], "image": "tower/sl/sl6_3",
			"skill": {"skillName": "유니콘 투자", "mult": 3.0, "cooldown": 12.0, "duration": 1.0, "range": 0.0,
			"description": "맵 위의 모든 적에게 물리 공격력의 300% 피해를 주고, 맞힌 적 한 마리당 코인 2개를 얻습니다. (최대 40개)"}},
}
const MYTHIC_STAT_MULT := 4.0
const MYTHIC_UNLOCK_LEVEL := 5

## 특수 직원. 보스를 잡으면 떨어지는 유물로만 뽑을 수 있다 (고용, 승진, 협상, 직원 탭 대상이 아님).
## 능력치는 base 전설의 SPECIAL_STAT_MULT 배, 레벨은 base 의 레벨을 따른다. 그림은 image(.svg / _sprite.svg)
const SPECIALS := {
	"tower_dv7": {"base": "tower_dv5_1", "name": "AI 연구원", "image": "tower/dv/dv7",
			"skill": {"skillName": "딥러닝", "mult": 4.0, "cooldown": 6.0, "duration": 1.0, "range": 0.0,
			"description": "체력이 가장 많은 적 3명에게 마법 공격력의 400% 피해를 줍니다."}},
	"tower_hr7": {"base": "tower_hr5_1", "name": "헤드헌터", "image": "tower/hr/hr7",
			"skill": {"skillName": "스카우트 제의", "mult": 0.4, "cooldown": 10.0, "duration": 4.0, "range": 3.0,
			"description": "사거리 3칸 안의 적 방어력을 4초 동안 30 낮추고 1초 동안 기절시키며, 같은 범위 직원의 공격 속도를 40% 올립니다. (보스는 기절하지 않음)"}},
	"tower_sl7": {"base": "tower_sl5_1", "name": "엔젤 투자자", "image": "tower/sl/sl7",
			"skill": {"skillName": "투자 유치", "mult": 3.0, "cooldown": 9.0, "duration": 1.0, "range": 2.5,
			"description": "사거리 2.5칸 안의 적에게 물리 공격력의 300% 피해를 주고, 맞힌 적 한 마리당 코인 3개를 얻습니다."}},
}
const SPECIAL_STAT_MULT := 1.6
const SPECIAL_COLOR := Color("3ee6c8")
const MAX_TOWER_LEVEL := 30
const MAX_EQUIPMENT_LEVEL := 100
## 스킬 쿨타임은 최대 50% 까지만 줄어든다
const MIN_COOLDOWN_MULT := 0.5

var towers := {}      # towerId(tower_dv1) -> Dictionary
var tower_ids: Array[String] = []
var skills := {}      # skillId(dv1) -> Dictionary
var hobbies := {}     # hobbyId -> Dictionary
var hobby_ids: Array[String] = []
var equipment := {}   # eqId -> Dictionary
var equipment_ids: Array[String] = []
var mythic_of := {}   # 전설 towerId -> 신화 towerId


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
	_add_mythics()
	_add_specials()


## 신화 직원을 전설 데이터에서 만들어 towers / skills 에 넣는다 (tower_ids 에는 넣지 않는다: 고용, 직원 탭 대상이 아님)
func _add_mythics() -> void:
	for id in MYTHICS:
		var m: Dictionary = MYTHICS[id]
		var source := level_source(m.base)
		var t: Dictionary = towers[source].duplicate()
		t.towerId = id
		t.towerName = m.name
		t.towerGrade = MYTHIC_GRADE
		if m.has("image"):
			t.towerImagePath = m.image + ".png"
			t.towerPortraitPath = t.towerImagePath
			t.towerSpritePath = m.image + "_sprite.svg"
		t.towerPhysicalAttack = float(t.towerPhysicalAttack) * MYTHIC_STAT_MULT
		t.towerMagicAttack = float(t.towerMagicAttack) * MYTHIC_STAT_MULT
		t.towerAttackSpeed = float(t.towerAttackSpeed) * 1.2
		t.towerAttackRange = float(t.towerAttackRange) + (0.5 if t.team == "sl" else 1.0)  # 영업팀은 근접 그대로 (4칸부터 원거리)
		t.mythicBase = m.base
		towers[id] = t
		var skill: Dictionary = m.skill.duplicate()
		var key: String = id.trim_prefix("tower_")
		skill.skillId = key
		skill.summoneeImagePath = skills[source.trim_prefix("tower_")].get("summoneeImagePath", "")
		skills[key] = skill
		mythic_of[m.base] = id


## 레벨(과 신화 능력치)을 따라가는 직원 탭의 전설. 신화와 특수 직원은 base 를 거슬러 올라간다
static func level_source(id: String) -> String:
	while MYTHICS.has(id) or SPECIALS.has(id):
		id = MYTHICS[id].base if MYTHICS.has(id) else SPECIALS[id].base
	return id


## 신화가 속한 팀에서 MYTHIC_UNLOCK_LEVEL 이상인 직원 수와 팀 전체 직원 수 [ready, total]
func mythic_progress(user: Dictionary, mythic_id: String) -> Array:
	var team: String = towers[mythic_id].team
	var members := tower_ids.filter(func(id): return towers[id].team == team)
	var levels: Dictionary = user.get("towers", {})
	var ready := members.filter(func(id): return int(levels.get(id, 1)) >= MYTHIC_UNLOCK_LEVEL).size()
	return [ready, members.size()]


func mythic_unlocked(user: Dictionary, mythic_id: String) -> bool:
	var p := mythic_progress(user, mythic_id)
	return p[0] >= p[1]


## 잠긴 신화의 해금 안내 문구
func mythic_lock_text(user: Dictionary, mythic_id: String) -> String:
	var p := mythic_progress(user, mythic_id)
	return "%s팀 직원 %d명을 모두 레벨 %d 이상으로 올리면 해금됩니다. (현재 %d/%d명)" % [
			team_name(towers[mythic_id].team), p[1], MYTHIC_UNLOCK_LEVEL, p[0], p[1]]


## 특수 직원을 전설 데이터에서 만들어 towers / skills 에 넣는다 (tower_ids 에는 넣지 않는다)
func _add_specials() -> void:
	for id in SPECIALS:
		var s: Dictionary = SPECIALS[id]
		var t: Dictionary = towers[s.base].duplicate()
		t.towerId = id
		t.towerName = s.name
		t.towerImagePath = s.image + ".png"
		t.towerPortraitPath = t.towerImagePath
		t.towerSpritePath = s.image + "_sprite.svg"
		t.towerPhysicalAttack = float(t.towerPhysicalAttack) * SPECIAL_STAT_MULT
		t.towerMagicAttack = float(t.towerMagicAttack) * SPECIAL_STAT_MULT
		t.special = true
		towers[id] = t
		var skill: Dictionary = s.skill.duplicate()
		var key: String = id.trim_prefix("tower_")
		skill.skillId = key
		skill.summoneeImagePath = skills[String(s.base).trim_prefix("tower_")].get("summoneeImagePath", "")
		skills[key] = skill


static func is_special(tower: Dictionary) -> bool:
	return tower.get("special", false)


## 카드에 보여 줄 등급 이름과 색 (특수 직원은 등급 대신 "특수")
static func grade_label(tower: Dictionary) -> String:
	return "특수" if is_special(tower) else GRADE_NAMES[clampi(int(tower.towerGrade) - 1, 0, GRADE_NAMES.size() - 1)]


static func tower_color(tower: Dictionary) -> Color:
	return SPECIAL_COLOR if is_special(tower) else grade_color(int(tower.towerGrade))


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
		"attack": return "%s 공격력 +%.1f%%" % [target, value]
		"speed": return "%s 공격 속도 +%.1f%%" % [target, value]
		"cooldown": return "%s 스킬 쿨타임 -%.1f%%" % [target, value]
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


## 최대 레벨(100)까지 총비용은 baseCost 의 약 277배 (최대 레벨 10 시절 55배의 약 5배)
static func equipment_cost(eq: Dictionary, level: int) -> int:
	return roundi(int(eq["baseCost"]) * (1.0 + level / 28.0))
