# 스테이지 정의: 맵, 웨이브, 적 종류.
# 맵 값 규칙: 0 = 책상(직원 배치 칸), 1.0 = 통로, 1.1 / 1.2 / 1.3 ... = 경유지 순서.
# 1.1 이 입구이고 0.1 씩 증가하는 값을 끝까지 따라간다 (마지막 경유지가 출구).
# 모든 맵은 위쪽 줄부터 적는다 (map[row][col], row 0 = 화면 맨 위).
class_name StageDefs

const COUNT := 4
const BASE_START_COINS := 300

## 적 종류. hp_mult 는 웨이브 기본 체력에 곱해지고 speed 는 초당 칸 수
const ENEMIES := {
	"printer": {"name": "프린터", "hp_mult": 1.0, "speed": 2.0, "pdef": 5, "mdef": 5, "scale": 1.0, "tint": Color(1, 1, 1), "reward": 8, "boss": false},
	"fax": {"name": "팩스", "hp_mult": 0.6, "speed": 3.5, "pdef": 0, "mdef": 10, "scale": 0.8, "tint": Color(0.55, 0.85, 1), "reward": 6, "boss": false},
	"copier": {"name": "복합기", "hp_mult": 2.5, "speed": 1.3, "pdef": 40, "mdef": 5, "scale": 1.25, "tint": Color(0.75, 0.6, 0.95), "reward": 15, "boss": false},
	"server": {"name": "서버", "hp_mult": 1.6, "speed": 1.8, "pdef": 5, "mdef": 45, "scale": 1.1, "tint": Color(0.55, 1, 0.55), "reward": 12, "boss": false},
	"boss": {"name": "부장님 프린터", "hp_mult": 12.0, "speed": 1.0, "pdef": 20, "mdef": 20, "scale": 1.6, "tint": Color(1, 0.45, 0.45), "reward": 100, "boss": true},
}

const STAGES := {
	1: {
		"name": "입사 첫 주",
		"difficulty": "쉬움",
		"start_coins": 300,
		"hp_scale": 1.6,  # 이 스테이지 모든 적 체력 배율 (밸런스 조정용)
		"tint": Color(1, 1, 1),
		"map": [
			[1.1, 0, 0, 2.2, 0, 0, 1.5, 1.0, 1.0, 1.4],
			[1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0, 1.0],
			[1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0, 1.0],
			[1.2, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.3],
			[0, 0, 0, 1.0, 0, 0, 1.0, 0, 0, 0],
			[0, 0, 0, 1.0, 0, 0, 1.0, 0, 0, 0],
			[1.9, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.8],
			[1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0, 1.0],
			[1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0, 1.0],
			[2.0, 1.0, 1.0, 2.1, 0, 0, 1.6, 1.0, 1.0, 1.7],
		],
		# [생성 간격(초), [[적, 기본 체력, 마리 수], ...]]
		"waves": [
			[1.0, [["printer", 30, 8]]],
			[0.9, [["printer", 40, 10]]],
			[0.8, [["printer", 50, 8], ["fax", 50, 6]]],
			[0.8, [["printer", 65, 10], ["copier", 65, 3]]],
			[0.7, [["fax", 80, 8], ["server", 80, 6], ["copier", 80, 3]]],
			[1.5, [["printer", 90, 6], ["boss", 90, 1]]],
		],
	},
	2: {
		"name": "분기 마감",
		"difficulty": "보통",
		"start_coins": 500,
		"hp_scale": 1.5,  # 이 스테이지 모든 적 체력 배율 (밸런스 조정용)
		"tint": Color(1, 0.9, 0.75),
		"map": [
			[1.1, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.2, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 1.0, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 1.0, 0],
			[0, 1.4, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.3, 0],
			[0, 1.0, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 1.0, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 1.5, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.6, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 1.0, 0],
			[0, 0, 0, 0, 0, 0, 0, 0, 1.0, 0],
			[1.8, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.7, 0],
		],
		"waves": [
			[1.0, [["printer", 45, 10]]],
			[0.7, [["fax", 55, 12]]],
			[0.9, [["printer", 65, 8], ["copier", 65, 4]]],
			[0.8, [["server", 75, 10]]],
			[0.7, [["fax", 85, 10], ["copier", 85, 5]]],
			[0.8, [["server", 95, 8], ["copier", 95, 6]]],
			[0.6, [["printer", 110, 12], ["fax", 110, 8]]],
			[1.0, [["copier", 125, 6], ["server", 125, 6], ["boss", 125, 1]]],
		],
	},
	3: {
		"name": "연말 감사",
		"difficulty": "어려움",
		"start_coins": 800,
		"hp_scale": 1.4,  # 이 스테이지 모든 적 체력 배율 (밸런스 조정용)
		"tint": Color(0.72, 0.75, 0.95),
		"map": [
			[0, 1.1, 0, 0, 0, 0, 0, 0, 0, 0],
			[0, 1.0, 0, 0, 1.4, 1.0, 1.0, 1.5, 0, 0],
			[0, 1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0],
			[0, 1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0],
			[0, 1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0],
			[0, 1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0],
			[0, 1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0],
			[0, 1.0, 0, 0, 1.0, 0, 0, 1.0, 0, 0],
			[0, 1.2, 1.0, 1.0, 1.3, 0, 0, 1.0, 0, 0],
			[0, 0, 0, 0, 0, 0, 0, 1.6, 0, 0],
		],
		"waves": [
			[1.0, [["printer", 55, 10]]],
			[0.7, [["fax", 65, 14]]],
			[0.8, [["printer", 80, 10], ["copier", 80, 2], ["server", 80, 2]]],
			[0.8, [["printer", 90, 8], ["copier", 90, 3], ["server", 90, 3]]],
			[0.8, [["fax", 105, 10], ["boss", 105, 1]]],
			[0.8, [["server", 120, 8], ["copier", 120, 4]]],
			[0.45, [["fax", 135, 20]]],
			[0.9, [["copier", 150, 10]]],
			[0.6, [["printer", 170, 10], ["server", 170, 8], ["fax", 170, 8]]],
			[1.2, [["copier", 190, 6], ["server", 190, 6], ["boss", 200, 2]]],
		],
	},
	# 무한 모드: 웨이브가 끝없이 이어지고 갈수록 어려워진다 (endless_wave 가 만든다)
	4: {
		"name": "무한 야근",
		"difficulty": "무한",
		"start_coins": 600,
		"hp_scale": 1.0,  # 이 스테이지 모든 적 체력 배율 (밸런스 조정용)
		"tint": Color(0.8, 0.68, 0.95),
		"endless": true,
		# 바깥을 한 바퀴 돈 뒤 가운데로 감겨 들어가는 나선
		"map": [
			[1.1, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.2],
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 1.0],
			[1.5, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.6, 0, 1.0],
			[1.0, 0, 0, 0, 0, 0, 0, 1.0, 0, 1.0],
			[1.0, 0, 1.9, 1.0, 1.0, 2.0, 0, 1.0, 0, 1.0],
			[1.0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 1.0],
			[1.0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 1.0],
			[1.0, 0, 1.8, 1.0, 1.0, 1.0, 1.0, 1.7, 0, 1.0],
			[1.0, 0, 0, 0, 0, 0, 0, 0, 0, 1.0],
			[1.4, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.3],
		],
		"waves": [],
	},
}

## 무한 모드 난이도: 웨이브마다 체력 x endless_hp_growth, 마리 수와 생성 속도도 늘어난다
const ENDLESS_BASE_HP := 40.0
static var endless_hp_growth := 1.22  # 시뮬레이터가 --dev-growth 로 바꿔 볼 수 있게 var
const ENDLESS_MAX_COUNT := 36


static func is_endless(stage_id: int) -> bool:
	return STAGES[stage_id].get("endless", false)


## 무한 모드의 index 번째 웨이브 (0부터). 형식은 STAGES 의 waves 와 같다
## 10의 배수 = 보스 웨이브, 5의 배수 = 중간 보스, 나머지는 4가지 테마를 돌아가며
static func endless_wave(index: int) -> Array:
	var w := index + 1
	var hp := ENDLESS_BASE_HP * pow(endless_hp_growth, index)
	var count := mini(8 + int(index * 0.7), ENDLESS_MAX_COUNT)
	var interval := maxf(0.35, 1.0 - index * 0.02)
	if w % 10 == 0:
		return [maxf(interval, 0.8), [["printer", hp, count / 2], ["boss", hp, w / 10]]]
	if w % 5 == 0:
		return [interval, [["copier", hp, count / 4], ["server", hp, count / 4], ["boss", hp * 0.5, 1]]]
	match w % 4:
		1:  # 프린터 물량
			return [interval, [["printer", hp, count]]]
		2:  # 빠른 팩스 떼
			return [interval * 0.6, [["fax", hp, roundi(count * 1.4)]]]
		3:  # 단단한 기계 (물리/마법 방어가 높다)
			return [interval, [["printer", hp, count / 3], ["copier", hp, maxi(1, count / 3)], ["server", hp, maxi(1, count / 3)]]]
	return [interval * 0.8, [["printer", hp, count / 4], ["fax", hp, count / 4], ["copier", hp, count / 4], ["server", hp, count / 4]]]


static func description(stage_id: int) -> String:
	var s: Dictionary = STAGES[stage_id]
	if is_endless(stage_id):
		return "%s / 웨이브 무한" % s.difficulty
	return "%s / 웨이브 %d" % [s.difficulty, s.waves.size()]


## 경유지 칸 목록 (Vector2i(열, 행)), 입구부터 출구까지
static func waypoints(map: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var i := 0
	while true:
		var value := 1.1 + i * 0.1
		var found := false
		for row in map.size():
			for col in map[row].size():
				if absf(float(map[row][col]) - value) < 0.001:
					result.append(Vector2i(col, row))
					found = true
					break
			if found:
				break
		if not found:
			break
		i += 1
	return result
