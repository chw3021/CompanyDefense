# 보상형 광고. 한 판(라이브 전투) 중에는 절대 띄우지 않는다.
# AdMob 연동 전: 짧은 대기 후 테스트 보상으로 성공 처리.
extends Node

## stage 화면이 라이브 전투 중일 때만 true (정비·일시정지 포함). 결과/부활 제안/로비는 false.
var live_battle := false


func set_live_battle(active: bool) -> void:
	live_battle = active


## 전투 중이 아니면 보상 플로우 가능. ads_removed 면 실제 광고 없이 즉시 성공 처리.
func can_show_rewarded() -> bool:
	return not live_battle


func can_show_banner() -> bool:
	return not live_battle and Save.has_user() and not Save.ads_removed()


## 판 종료·미션/메일 추가보상은 로비 광고 공용 쿨과 분리한다. (미션 여러 개면 연속 시청이 막히면 안 됨)
const COOLDOWN_EXEMPT := ["revive", "gold_double", "mission_bonus", "mail_bonus"]


## placement 은 로깅/추후 AdMob 유닛 매핑용. 성공 시 true.
## ponytail: 실기기 AdMob 플러그인으로 교체. 천장 = 테스트 즉시 성공 / 광고 제거 시 즉시 성공.
func show_rewarded(placement: String) -> bool:
	if not can_show_rewarded():
		UI.toast("전투가 끝난 뒤에 광고를 볼 수 있습니다.", UI.WARN)
		return false
	var skip_cool := placement in COOLDOWN_EXEMPT
	if not skip_cool:
		var cool := Save.ad_cooldown_left()
		if cool > 0:
			UI.toast("광고 보상은 %s 후에 다시 받을 수 있습니다." % Save.format_cooldown(cool), UI.WARN)
			return false
	# 모든 광고 제거: 시청 없이 보상만 지급 (공유 쿨은 그대로 적용)
	if Save.ads_removed():
		if not skip_cool:
			Save.mark_reward_ad()
		return true
	UI.toast("광고 시청 중… (%s)" % _label(placement), UI.MUTED)
	await get_tree().create_timer(0.4).timeout
	if not can_show_rewarded():
		UI.toast("전투가 끝난 뒤에 광고를 볼 수 있습니다.", UI.WARN)
		return false
	if not skip_cool:
		var cool2 := Save.ad_cooldown_left()
		if cool2 > 0:
			UI.toast("광고 보상은 %s 후에 다시 받을 수 있습니다." % Save.format_cooldown(cool2), UI.WARN)
			return false
		Save.mark_reward_ad()
	return true


func _label(placement: String) -> String:
	match placement:
		"time":
			return "시간 충전"
		"gold_double":
			return "골드 2배"
		"revive":
			return "부활"
		"mail_bonus":
			return "메일 추가 보상"
		"mission_bonus":
			return "미션 추가 보상"
		"start_coin":
			return "시작 코인"
		"corp_card":
			return "법인카드"
		_:
			return placement
