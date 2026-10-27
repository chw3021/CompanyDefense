# 구글 계정 연동과 클라우드 저장 (Firebase Auth REST + Realtime Database REST).
# 웹은 구글 로그인 페이지로 이동했다가 돌아오는 방식(OAuth implicit), 그 외(안드로이드, PC)는
# 기기 코드 방식(google.com/device 에 코드 입력)으로 구글 토큰을 받아 Firebase 로그인한다.
# 연동 정보(refresh token)는 user://account.json 에만 두고 클라우드 저장 데이터에는 넣지 않는다.
extends Node

## 웹 redirect / 기기 코드 로그인이 끝나면 (error 가 "" 이면 성공)
signal login_done(error: String)
signal device_code_ready(user_code: String, url: String)

const API_KEY := "AIzaSyBR1kQXuUPKbRROAN8u-EHDOFcPna0ZM0E"
## OAuth 클라이언트 값은 커밋하지 않는 파일에 둔다 (account_keys.example.gd 참고, 웹 배포는 GitHub Actions 시크릿으로 만든다)
const KEYS_PATH := "res://scripts/autoload/account_keys.gd"
const DB_URL := "https://company-defense-default-rtdb.firebaseio.com"
const ACCOUNT_PATH := "user://account.json"
const SCOPE := "openid email profile"
const UPLOAD_INTERVAL := 20.0

var web_client_id := ""
## "TV 및 입력 제한 기기" 유형 OAuth 클라이언트 (기기 코드 로그인)
var device_client_id := ""
var device_client_secret := ""
var uid := ""
var email := ""
var _refresh_token := ""
var _id_token := ""
var _expires_at := 0
var _dirty := false
var _uploading := false
var _cancel_device := false
## 웹에서 로그인 페이지로 다녀온 직후의 결과. 메인 화면이 뜰 때 take_pending() 으로 가져간다
var _pending: Variant = null


func _ready() -> void:
	if ResourceLoader.exists(KEYS_PATH):
		var keys: GDScript = load(KEYS_PATH)
		web_client_id = keys.WEB_CLIENT_ID
		device_client_id = keys.DEVICE_CLIENT_ID
		device_client_secret = keys.DEVICE_CLIENT_SECRET
	var data = JSON.parse_string(FileAccess.get_file_as_string(ACCOUNT_PATH)) if FileAccess.file_exists(ACCOUNT_PATH) else null
	if data is Dictionary:
		uid = data.get("uid", "")
		email = data.get("email", "")
		_refresh_token = data.get("refresh_token", "")
	Save.changed.connect(func(): _dirty = true)
	var timer := Timer.new()
	timer.wait_time = UPLOAD_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_auto_upload)
	add_child(timer)
	if OS.has_feature("web"):
		_consume_web_redirect()


func is_linked() -> bool:
	return uid != "" and _refresh_token != ""


func use_redirect_login() -> bool:
	return OS.has_feature("web")


func take_pending() -> Variant:
	var p = _pending
	_pending = null
	return p


func unlink() -> void:
	uid = ""
	email = ""
	_refresh_token = ""
	_id_token = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ACCOUNT_PATH))


# ------------------------------------------------------------------ 웹: 구글 로그인 페이지 이동

func start_redirect_login() -> void:
	var state := "%x%x" % [randi(), randi()]
	var f := FileAccess.open("user://account_state.txt", FileAccess.WRITE)
	f.store_string(state)
	f.close()
	# OAuth 클라이언트에 등록한 리디렉션 URI 와 글자까지 같아야 하므로 index.html 은 뗀다
	var page: String = str(JavaScriptBridge.eval("location.origin + location.pathname")).trim_suffix("index.html")
	var url := "https://accounts.google.com/o/oauth2/v2/auth?client_id=%s&redirect_uri=%s&response_type=token&scope=%s&state=%s&prompt=select_account" % [
			web_client_id, page.uri_encode(), SCOPE.uri_encode(), state]
	JavaScriptBridge.eval("window.location.href = %s" % JSON.stringify(url))


func _consume_web_redirect() -> void:
	var hash_text: String = str(JavaScriptBridge.eval("location.hash"))
	if not hash_text.contains("access_token=") and not hash_text.contains("error="):
		return
	JavaScriptBridge.eval("history.replaceState(null, '', location.pathname + location.search)")
	var params := {}
	for pair in hash_text.trim_prefix("#").split("&"):
		var kv := pair.split("=", true, 1)
		if kv.size() == 2:
			params[kv[0]] = kv[1].uri_decode()
	var state_path := "user://account_state.txt"
	var expected := FileAccess.get_file_as_string(state_path) if FileAccess.file_exists(state_path) else ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state_path))
	var error := ""
	if not params.has("access_token"):
		error = "구글 로그인이 취소되었습니다."
	elif expected == "" or params.get("state", "") != expected:
		error = "로그인 요청이 올바르지 않습니다. 다시 시도해 주세요."
	else:
		error = await _firebase_sign_in("access_token=%s&providerId=google.com" % params.access_token)
	_pending = error
	login_done.emit(error)


# ------------------------------------------------------------------ 안드로이드/PC: 기기 코드

## 코드를 받으면 device_code_ready 를 보내고, 사용자가 브라우저에서 승인할 때까지 기다린다. 성공하면 ""
func start_device_login() -> String:
	if device_client_id == "":
		return "계정 연동이 아직 준비되지 않았습니다."
	_cancel_device = false
	var r := await _post_form("https://oauth2.googleapis.com/device/code", {"client_id": device_client_id, "scope": SCOPE})
	if r.code != 200:
		return "로그인 코드를 받지 못했습니다. 인터넷 연결을 확인해 주세요."
	var d: Dictionary = r.data
	device_code_ready.emit(d.user_code, d.get("verification_url", "https://www.google.com/device"))
	var interval := float(d.get("interval", 5))
	var deadline := Time.get_ticks_msec() + int(d.get("expires_in", 600)) * 1000
	while Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(interval).timeout
		if _cancel_device:
			return "로그인이 취소되었습니다."
		var t := await _post_form("https://oauth2.googleapis.com/token", {
			"client_id": device_client_id, "client_secret": device_client_secret,
			"device_code": d.device_code, "grant_type": "urn:ietf:params:oauth:grant-type:device_code"})
		if t.code == 200:
			return await _firebase_sign_in("id_token=%s&providerId=google.com" % t.data.id_token)
		var err: String = t.data.get("error", "") if t.data is Dictionary else ""
		if err == "slow_down":
			interval += 5
		elif err != "authorization_pending":
			return "구글 로그인이 거부되었습니다."
	return "로그인 시간이 지났습니다. 다시 시도해 주세요."


func cancel_device_login() -> void:
	_cancel_device = true


# ------------------------------------------------------------------ Firebase

func _firebase_sign_in(post_body: String) -> String:
	var r := await _post_json("https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=" + API_KEY, {
		"postBody": post_body, "requestUri": "http://localhost", "returnSecureToken": true})
	if r.code != 200 or not r.data is Dictionary:
		push_warning("Firebase 로그인 실패: %s" % str(r.data))
		return "계정 연동에 실패했습니다. 잠시 후 다시 시도해 주세요."
	uid = r.data.localId
	email = r.data.get("email", "")
	_refresh_token = r.data.refreshToken
	_id_token = r.data.idToken
	_expires_at = _now() + int(r.data.get("expiresIn", 3600))
	var f := FileAccess.open(ACCOUNT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"uid": uid, "email": email, "refresh_token": _refresh_token}))
	f.close()
	return ""


func _ensure_token() -> bool:
	if not is_linked():
		return false
	if _id_token != "" and _now() < _expires_at - 60:
		return true
	var r := await _post_form("https://securetoken.googleapis.com/v1/token?key=" + API_KEY,
			{"grant_type": "refresh_token", "refresh_token": _refresh_token})
	if r.code != 200 or not r.data is Dictionary:
		push_warning("Firebase 토큰 갱신 실패: %s" % str(r.data))
		return false
	_id_token = r.data.id_token
	_expires_at = _now() + int(r.data.get("expires_in", 3600))
	return true


## 클라우드의 저장 데이터 {user, updated}. 없으면 {}, 실패하면 null
func download() -> Variant:
	if not await _ensure_token():
		return null
	var r := await _request(HTTPClient.METHOD_GET, "%s/saves/%s.json?auth=%s" % [DB_URL, uid, _id_token])
	if r.code != 200:
		return null
	if not r.data is Dictionary:
		return {}
	# Realtime Database 는 숫자 키 객체를 배열로 바꾸므로 저장 데이터는 문자열로 넣어 둔다
	var user = JSON.parse_string(String(r.data.get("data", "")))
	return {"user": user, "updated": int(r.data.get("updated", 0))} if user is Dictionary else {}


func upload() -> bool:
	if Save.user.is_empty() or not await _ensure_token():
		return false
	_dirty = false
	var body := {"data": JSON.stringify(Save.user), "updated": _now(), "name": Save.user.get("name", "")}
	var r := await _request(HTTPClient.METHOD_PUT, "%s/saves/%s.json?auth=%s" % [DB_URL, uid, _id_token], JSON.stringify(body))
	if r.code != 200:
		_dirty = true
		push_warning("클라우드 저장 실패: %d" % r.code)
	return r.code == 200


func _auto_upload() -> void:
	# 개발용 시나리오 실행 중에는 테스트 데이터를 올리지 않는다
	if not _dirty or _uploading or not is_linked() or Dev._scenario != null:
		return
	_uploading = true
	await upload()
	_uploading = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_auto_upload()


# ------------------------------------------------------------------ HTTP

func _now() -> int:
	return int(Time.get_unix_time_from_system())


func _post_form(url: String, fields: Dictionary) -> Dictionary:
	var parts := []
	for key in fields:
		parts.append("%s=%s" % [key, String(fields[key]).uri_encode()])
	return await _request(HTTPClient.METHOD_POST, url, "&".join(parts), ["Content-Type: application/x-www-form-urlencoded"])


func _post_json(url: String, body: Dictionary) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, url, JSON.stringify(body), ["Content-Type: application/json"])


## {code, data}. 네트워크 오류면 code 는 0
func _request(method: int, url: String, body := "", headers: Array = []) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 20.0
	add_child(req)
	if req.request(url, PackedStringArray(headers), method, body) != OK:
		req.queue_free()
		return {"code": 0, "data": null}
	var res: Array = await req.request_completed
	req.queue_free()
	var text: String = res[3].get_string_from_utf8()
	return {"code": res[1] if res[0] == HTTPRequest.RESULT_SUCCESS else 0, "data": JSON.parse_string(text) if text != "" else null}
