# 구글 계정 연동과 클라우드 저장 (Firebase Auth REST + Realtime Database REST).
# 웹은 구글 로그인 페이지로 이동했다가 돌아오는 방식(OAuth implicit), 그 외(안드로이드, PC)는
# 기기 코드 방식(google.com/device 에 코드 입력)으로 구글 토큰을 받아 Firebase 로그인한다.
# 연동 정보(refresh token)는 user://account.json 에만 두고 클라우드 저장 데이터에는 넣지 않는다.
extends Node

## 웹 redirect / 기기 코드 로그인이 끝나면 (error 가 "" 이면 성공)
signal login_done(error: String)
signal device_code_ready(user_code: String, url: String)
## 프로필(이름, 사진)이 바뀌었을 때 (연동, 해제, 사진을 다 받았을 때)
signal profile_changed

const API_KEY := "AIzaSyBR1kQXuUPKbRROAN8u-EHDOFcPna0ZM0E"
## OAuth 클라이언트 값은 커밋하지 않는 파일에 둔다 (account_keys.example.gd 참고, 웹 배포는 GitHub Actions 시크릿으로 만든다)
const KEYS_PATH := "res://scripts/autoload/account_keys.gd"
const DB_URL := "https://company-defense-default-rtdb.firebaseio.com"
const ACCOUNT_PATH := "user://account.json"
const ANON_PATH := "user://anon.json"  # 구글 연동 전 닉네임 등록에 쓰는 기기별 익명 계정 {uid, refresh_token}
const AVATAR_PATH := "user://avatar.bin"  # 구글 프로필 사진 캐시 (원본 바이트)
const SCOPE := "openid email profile"
const UPLOAD_INTERVAL := 20.0
## 슈퍼계정 (골드/시간 무한, 전 스테이지와 직원 최대 레벨). Firebase 콘솔 > Authentication > 사용자의 UID 를 넣는다
const SUPER_UIDS: Array[String] = ["l9csSd4AsET2ciaLLVSLg6Ryv482", "poG6CZrbcNb6QWPbU4Bip54z1xf1", "31mb0ULOX0aGjdcAlDvV0qve74b2"]

var web_client_id := ""
## "TV 및 입력 제한 기기" 유형 OAuth 클라이언트 (기기 코드 로그인)
var device_client_id := ""
var device_client_secret := ""
var uid := ""
var email := ""
var display_name := ""
var photo_url := ""
var avatar: Texture2D  # 프로필 사진 (없거나 아직 못 받았으면 null)
var _profile_loading := false
var _refresh_token := ""
var _id_token := ""
var _expires_at := 0
var _dirty := false
var _uploading := false
var _cancel_device := false
var _anon := {}  # {uid, refresh_token, id_token, expires_at}
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
		display_name = data.get("name", "")
		photo_url = data.get("photo", "")
		_refresh_token = data.get("refresh_token", "")
	var anon = JSON.parse_string(FileAccess.get_file_as_string(ANON_PATH)) if FileAccess.file_exists(ANON_PATH) else null
	if anon is Dictionary and anon.has("uid") and anon.has("refresh_token"):
		_anon = {"uid": anon.uid, "refresh_token": anon.refresh_token, "id_token": "", "expires_at": 0}
	# Save 가 먼저 로드되어 그때는 연동 정보를 몰랐으므로 여기서 슈퍼계정 혜택을 적용한다
	if is_super() and Save.has_user():
		Save.apply_rich_start()
		Save.save()
	Save.changed.connect(func(): _dirty = true)
	var timer := Timer.new()
	timer.wait_time = UPLOAD_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_auto_upload)
	add_child(timer)
	if OS.has_feature("web"):
		_consume_web_redirect()
	_load_profile()


func is_linked() -> bool:
	return uid != "" and _refresh_token != ""


func is_super() -> bool:
	return is_linked() and uid in SUPER_UIDS


func use_redirect_login() -> bool:
	return OS.has_feature("web")


func take_pending() -> Variant:
	var p = _pending
	_pending = null
	return p


func unlink() -> void:
	uid = ""
	email = ""
	display_name = ""
	photo_url = ""
	avatar = null
	_refresh_token = ""
	_id_token = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ACCOUNT_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AVATAR_PATH))
	profile_changed.emit()


func _save_account() -> void:
	var f := FileAccess.open(ACCOUNT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"uid": uid, "email": email, "refresh_token": _refresh_token,
			"name": display_name, "photo": photo_url}))
	f.close()


# ------------------------------------------------------------------ 프로필 (이름, 사진)

## 보여 줄 이름: 구글 이름이 없으면 이메일 앞부분
func profile_name() -> String:
	if display_name != "":
		return display_name
	return email.get_slice("@", 0)


## 연동돼 있으면 프로필 사진을 준비한다. 예전에 연동해 사진 주소가 없으면 한 번 조회해 온다
func _load_profile() -> void:
	if not is_linked() or _profile_loading:
		return
	_profile_loading = true
	if photo_url == "" and display_name == "" and await _ensure_token():
		var r := await _post_json("https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=" + API_KEY, {"idToken": _id_token})
		if r.code == 200 and r.data is Dictionary and not r.data.get("users", []).is_empty():
			var u: Dictionary = r.data.users[0]
			display_name = u.get("displayName", "")
			photo_url = u.get("photoUrl", "")
			_save_account()
	var bytes := PackedByteArray()
	if FileAccess.file_exists(AVATAR_PATH):
		bytes = FileAccess.get_file_as_bytes(AVATAR_PATH)
	elif photo_url != "":
		bytes = await _download(photo_url)
		if not bytes.is_empty():
			var f := FileAccess.open(AVATAR_PATH, FileAccess.WRITE)
			f.store_buffer(bytes)
			f.close()
	avatar = _decode_image(bytes)
	_profile_loading = false
	profile_changed.emit()


func _download(url: String) -> PackedByteArray:
	var req := HTTPRequest.new()
	req.timeout = 20.0
	req.accept_gzip = false
	add_child(req)
	if req.request(url) != OK:
		req.queue_free()
		return PackedByteArray()
	var res: Array = await req.request_completed
	req.queue_free()
	return res[3] if res[0] == HTTPRequest.RESULT_SUCCESS and res[1] == 200 else PackedByteArray()


## PNG / JPG / WEBP 바이트를 텍스처로 (형식은 앞 몇 바이트로 구분)
static func _decode_image(bytes: PackedByteArray) -> Texture2D:
	if bytes.size() < 12:
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0x89 and bytes[1] == 0x50:
		err = img.load_png_from_buffer(bytes)
	elif bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = img.load_jpg_from_buffer(bytes)
	elif bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		err = img.load_webp_from_buffer(bytes)
	return ImageTexture.create_from_image(img) if err == OK else null


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
		push_warning("Firebase 로그인 실패 (%d): %s" % [r.code, str(r.data)])
		return "계정 연동에 실패했습니다. 잠시 후 다시 시도해 주세요."
	uid = r.data.localId
	email = r.data.get("email", "")
	display_name = r.data.get("displayName", r.data.get("fullName", ""))
	photo_url = r.data.get("photoUrl", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AVATAR_PATH))  # 다른 계정 사진이 남지 않게
	_refresh_token = r.data.refreshToken
	_id_token = r.data.idToken
	_expires_at = _now() + int(r.data.get("expiresIn", 3600))
	_save_account()
	profile_changed.emit()  # 사진을 받기 전에도 이름 첫 글자로 바로 보이게
	_load_profile()
	await _hand_over_name()
	return ""


func _ensure_token() -> bool:
	if not is_linked():
		return false
	if _id_token != "" and _now() < _expires_at - 60:
		return true
	var r := await _post_form("https://securetoken.googleapis.com/v1/token?key=" + API_KEY,
			{"grant_type": "refresh_token", "refresh_token": _refresh_token})
	if r.code != 200 or not r.data is Dictionary:
		push_warning("Firebase 토큰 갱신 실패 (%d): %s" % [r.code, str(r.data)])
		return false
	_id_token = r.data.id_token
	_expires_at = _now() + int(r.data.get("expires_in", 3600))
	return true


# ------------------------------------------------------------------ 닉네임 (중복 방지)
# names/<키> = 주인 uid. 구글 연동이면 그 계정, 아니면 기기별 익명 계정이 주인이다.
# DB 규칙이 "비어 있거나 내 것일 때만 쓰기"를 보장하므로 동시에 같은 이름을 잡아도 한 명만 성공한다.

## 대소문자를 무시하고, DB 키에 못 쓰는 글자(. $ # [ ] /)가 있어도 되도록 16진수로 바꾼다
static func name_key(nick: String) -> String:
	return nick.strip_edges().to_lower().to_utf8_buffer().hex_encode()


## 익명 계정의 ID 토큰 (없으면 만든다). 실패하면 ""
func _anon_token() -> String:
	if _anon.is_empty():
		var r := await _post_json("https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + API_KEY, {"returnSecureToken": true})
		if r.code != 200 or not r.data is Dictionary:
			push_warning("익명 로그인 실패 (%d): %s" % [r.code, str(r.data)])
			return ""
		_anon = {"uid": r.data.localId, "refresh_token": r.data.refreshToken, "id_token": r.data.idToken,
				"expires_at": _now() + int(r.data.get("expiresIn", 3600))}
		var f := FileAccess.open(ANON_PATH, FileAccess.WRITE)
		f.store_string(JSON.stringify({"uid": _anon.uid, "refresh_token": _anon.refresh_token}))
		f.close()
	elif _anon.id_token == "" or _now() >= int(_anon.expires_at) - 60:
		var r := await _post_form("https://securetoken.googleapis.com/v1/token?key=" + API_KEY,
				{"grant_type": "refresh_token", "refresh_token": _anon.refresh_token})
		if r.code != 200 or not r.data is Dictionary:
			push_warning("익명 토큰 갱신 실패 (%d): %s" % [r.code, str(r.data)])
			return ""
		_anon.id_token = r.data.id_token
		_anon.expires_at = _now() + int(r.data.get("expires_in", 3600))
	return _anon.id_token


## 닉네임을 등록할 계정 {uid, token}. 실패하면 {}
func _name_session() -> Dictionary:
	if is_linked():
		return {"uid": uid, "token": _id_token} if await _ensure_token() else {}
	var token := await _anon_token()
	return {"uid": _anon.uid, "token": token} if token != "" else {}


## nick 을 내 닉네임으로 등록하고 old 는 풀어 준다. 성공하면 "", 실패하면 보여 줄 문구.
## 기본 이름은 여러 명이 같이 쓰므로 등록하지 않는다
func claim_name(nick: String, old: String) -> String:
	if name_key(nick) == name_key(old):
		return ""
	var s := await _name_session()
	if s.is_empty():
		return "닉네임을 확인하지 못했습니다. 인터넷 연결을 확인해 주세요."
	if nick != Save.DEFAULT_NAME:
		var url := "%s/names/%s.json?auth=%s" % [DB_URL, name_key(nick), s.token]
		var r := await _request(HTTPClient.METHOD_GET, url)
		if r.code != 200:
			return "닉네임을 확인하지 못했습니다. 인터넷 연결을 확인해 주세요."
		if r.data != null and r.data != s.uid:
			return "이미 사용 중인 닉네임입니다."
		r = await _request(HTTPClient.METHOD_PUT, url, JSON.stringify(s.uid))
		if r.code == 401 or r.code == 403:  # 그 사이 다른 사람이 먼저 등록했다
			return "이미 사용 중인 닉네임입니다."
		if r.code != 200:
			return "닉네임을 확인하지 못했습니다. 인터넷 연결을 확인해 주세요."
	if old.strip_edges() != "" and old != Save.DEFAULT_NAME:
		# 내 것이 아니면 규칙이 막으므로 결과는 보지 않는다
		await _request(HTTPClient.METHOD_DELETE, "%s/names/%s.json?auth=%s" % [DB_URL, name_key(old), s.token])
	return ""


## 구글 연동 직후: 익명 계정이 잡아 둔 지금 닉네임의 주인을 구글 계정으로 넘기고 익명 계정은 버린다.
## ponytail: 넘기기가 네트워크 오류로 실패하면 그 닉네임은 주인 없는 채로 잠긴다. 자주 생기면 실패 시 익명 계정을 남겨 두고 다음 연동 때 다시 넘긴다
func _hand_over_name() -> void:
	if _anon.is_empty():
		return
	if Save.has_user() and Save.user.name != Save.DEFAULT_NAME:
		var token := await _anon_token()
		if token != "":
			await _request(HTTPClient.METHOD_PUT, "%s/names/%s.json?auth=%s" % [DB_URL, name_key(Save.user.name), token], JSON.stringify(uid))
	_anon = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ANON_PATH))


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
	# 웹에서는 브라우저가 이미 압축을 풀어 주므로 Godot 가 다시 풀다 실패해 응답이 비어 버린다
	req.accept_gzip = false
	add_child(req)
	if req.request(url, PackedStringArray(headers), method, body) != OK:
		req.queue_free()
		return {"code": 0, "data": null}
	var res: Array = await req.request_completed
	req.queue_free()
	var text: String = res[3].get_string_from_utf8()
	return {"code": res[1] if res[0] == HTTPRequest.RESULT_SUCCESS else 0, "data": JSON.parse_string(text) if text != "" else null}
