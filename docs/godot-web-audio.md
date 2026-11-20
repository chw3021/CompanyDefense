# Godot 웹(HTML5) 사운드 묵음 — 원인과 해결 패턴

CompanyDefense(Godot 4.x 웹 배포)에서 **데스크톱/에디터에서는 소리가 나는데 웹만 묵음**이 반복된 과정을 정리한 실전 노트다.  
다른 Godot 웹 게임을 만들 때 체크리스트·복붙용 패턴으로 쓰면 된다.

참조 구현: `scripts/autoload/audio.gd`, `default_bus_layout.tres`, `.github/workflows/web.yml`

---

## 한 줄 요약

| 구분 | 웹에서 쓸 것 | 이유 |
|------|-------------|------|
| **SFX(짧은 효과음)** | Godot `AudioStreamPlayer` + **Sample** + 제스처 unlock | 짧고 잦은 재생에 적합. Sample 등록 필요 |
| **BGM(긴 루프)** | **HTML5 `Audio`** (`new Audio('bgm/xxx.wav')`) | Godot Stream/Sample 둘 다 싱글스레드 웹에서 장시간 BGM이 묵음인 경우가 많음 |
| **공통** | 첫 **사용자 제스처** 안에서 `AudioContext.resume()` + 실제 `play()` | 브라우저 자동재생 정책 |

네이티브(데스크톱/안드로이드)는 기존처럼 Godot 버스(`Master` → `BGM` / `SFX`)만 쓰면 된다.

---

## 증상이 같으면 의심할 원인 (우선순위)

1. **AudioContext suspended**  
   첫 클릭/터치 전에 브라우저가 오디오를 잠근다. Godot `play()`만 호출해도 `ctx.state === "suspended"`면 묵음.
2. **제스처 밖에서 unlock**  
   `await`/`call_deferred` 이후에 `play()` 하면 제스처 스택이 끊겨서 resume이 실패하거나 다시 잠긴다.
3. **Master 버스 mute / 볼륨 0**  
   설정·세이브 복원으로 Master가 mute면 SFX/BGM 전부 죽는다.
4. **웹 playback_type 꼬임 (Stream vs Sample)**  
   Godot 4.3+ 웹: Sample이 기본·권장이지만, **커스텀 버스·긴 루프**와 맞물리면 Sample/Stream 모두 스피커까지 안 가는 경우가 있다.
5. **WAV 임포트 압축**  
   `compress/mode`가 IMA-ADPCM 등이면 웹 샘플 파이프에서 깨지거나 묵음이 날 수 있다. **PCM(`compress/mode=0`)** 권장.
6. **긴 BGM을 Godot 오디오만으로 재생**  
   SFX는 나고 BGM만 안 나는 패턴 → CompanyDefense 최종 결론은 **HTML5 Audio 우회**.

---

## 해결 타임라인 (이 프로젝트에서 실제로 한 일)

| 단계 | 커밋 메시지 요약 | 한 일 |
|------|------------------|------|
| 1 | 웹 효과음 재생 복구 | 첫 제스처에서 `_web_unlocked` + click 한 번 `play()` |
| 2 | 웹 사운드 복구 | `default_bus_layout.tres`(BGM/SFX), Master unmute, 버튼에서 `ensure_web_unlocked()`, Stream 시도 |
| 3 | Sample 재생·로깅·묵음 재시도 | SFX를 Sample로, `register_stream_as_sample`, `[Audio]` 콘솔 로그 |
| 4 | AudioContext resume 재시도, PCM, Master 직행 | 제스처마다 resume, BGM을 Master 버스에 직결 시도 |
| 5 | Stream 전환 / 클릭 재시작 방지 | BGM을 Stream으로, unlock 후 no-op |
| 6 | **HTML5 Audio 우회** ★ | Godot BGM 포기 → `bgm/*.wav`를 빌드 산출물에 복사, JS `Audio`로 재생 |
| 7 | 루프 페이드 | HTML5 `timeupdate`/`ended`로 페이드아웃→처음으로→페이드인 |

핵심 교훈: **웹에서 “거의 다 고쳤는데 BGM만 묵음”이면 Godot 오디오 파이프를 더 파기보다 HTML5로 빼는 게 빠르다.**

---

## 체크리스트 (새 프로젝트 적용)

### A. 프로젝트 설정

- [ ] `default_bus_layout.tres`에 `BGM`, `SFX` 버스, `send = Master`
- [ ] Autoload `Audio` (또는 동등 싱글톤)
- [ ] WAV 임포트: `compress/mode=0` (PCM), 루프 BGM은 `edit/loop_mode=1` (네이티브용)
- [ ] 웹 빌드 후 **원본 BGM wav**를 `build/web/bgm/`에 복사 (PCK 밖 URL로 접근)

### B. 웹 unlock (SFX용 Godot 오디오)

- [ ] `OS.has_feature("web")`일 때 `_input` + `_unhandled_input`으로 제스처 감지
- [ ] pressed인 마우스/터치/키/패드만 처리
- [ ] 제스처 핸들러 **안에서** 순서대로:
  1. `GodotAudio.ctx.resume()` (JavaScriptBridge)
  2. Master unmute + 볼륨 적용
  3. 짧은 SFX `play()` 한 번
  4. BGM `play()` (HTML5면 여기도 제스처 안)
- [ ] UI 버튼 콜백에서도 `ensure_web_unlocked()` 호출 (GUI가 입력을 삼켜도 unlock)
- [ ] unlock 전에는 SFX `play` no-op (무의미한 play 폭주 방지)

### C. 웹 SFX

- [ ] `AudioStreamPlayer.playback_type = 2` (Sample)
- [ ] 로드 시 `AudioServer.register_stream_as_sample(stream)` (API 있으면)
- [ ] 풀링(10개 등) + 짧은 gap으로 중복 재생 제한

### D. 웹 BGM (권장: HTML5)

- [ ] 페이지 로드 시 `new Audio('bgm/id.wav')` preload
- [ ] unlock 제스처 안에서 `a.play()` (Promise catch로 NotAllowedError 로그)
- [ ] 볼륨 = `master * bgm` 를 JS `a.volume`에 동기화
- [ ] 곡 전환 시 이전 트랙 `pause()` + `currentTime = 0`
- [ ] 루프 끊김이 거슬리면 `loop=false` + ended에서 페이드 재시작

### E. 배포

- [ ] CI/로컬 export 후:

```bash
mkdir -p build/web/bgm
cp assets/bgm/*.wav build/web/bgm/
```

- [ ] GitHub Pages 등이면 `index.wasm`/`index.pck` 캐시 버스팅도 같이 (옛 빌드가 남아 “고쳤는데 안 들림”처럼 보임)

### F. 디버깅

- [ ] GDScript `print` + `JavaScriptBridge.eval("console.log(...)")` 로 `[Audio]` 접두 로그
- [ ] 브라우저 콘솔에서 `GodotAudio.ctx.state` → `running` 인지
- [ ] HTML5면 `[Audio/html] play fail` / NotAllowedError 확인
- [ ] SFX만 나고 BGM만 묵음 → HTML5 우회 후보

---

## 복붙용 패턴

### 1) AudioContext resume

```gdscript
func _resume_web_audio_context() -> String:
	if not OS.has_feature("web"):
		return "n/a"
	var state: Variant = JavaScriptBridge.eval("""
		(function () {
			try {
				var ctx = (typeof GodotAudio !== 'undefined' && GodotAudio.ctx)
					|| window.__godotAudioContext || null;
				if (!ctx) return 'no-ctx';
				window.__godotAudioContext = ctx;
				if (ctx.state === 'suspended' && ctx.resume) ctx.resume();
				try {
					var buf = ctx.createBuffer(1, 1, 22050);
					var src = ctx.createBufferSource();
					src.buffer = buf;
					src.connect(ctx.destination);
					src.start(0);
				} catch (e2) {}
				return String(ctx.state);
			} catch (e) {
				return 'error:' + String(e);
			}
		})();
	""")
	return str(state)
```

### 2) HTML5 BGM 재생 (상대 경로 `bgm/xxx.wav`)

```gdscript
# 사전: 빌드 산출물 옆에 bgm/lobby.wav 등이 있어야 함
func _html_bgm_play(id: String) -> void:
	var vol := clampf(Save.volume_bgm() * Save.volume_master(), 0.0, 1.0)
	JavaScriptBridge.eval("""
		(function () {
			window.__cdBgm = window.__cdBgm || {};
			var id = %s;
			var vol = %s;
			Object.keys(window.__cdBgm).forEach(function (k) {
				if (k === id || !window.__cdBgm[k]) return;
				window.__cdBgm[k].pause();
			});
			var a = window.__cdBgm[id] || new Audio('bgm/' + id + '.wav');
			a.volume = vol;
			window.__cdBgm[id] = a;
			var p = a.play();
			if (p && p.then) p.catch(function (e) {
				console.warn('[Audio/html] play fail', id, String(e));
			});
		})();
	""" % [JSON.stringify(id), JSON.stringify(vol)])
```

### 3) SFX Sample 등록

```gdscript
if OS.has_feature("web") and AudioServer.has_method("register_stream_as_sample"):
	AudioServer.register_stream_as_sample(stream)
player.playback_type = 2  # Sample
```

### 4) 버스 레이아웃 (`default_bus_layout.tres`)

```
Master
 ├─ BGM  (send → Master)
 └─ SFX  (send → Master)
```

런타임에 버스가 없으면 `AudioServer.add_bus`로 만들어도 되지만, 레이아웃 파일을 프로젝트에 두는 편이 안전하다.

---

## 하지 말아야 할 것

- unlock 직후 `await get_tree().create_timer(...)` 하고 나서야 BGM `play()` — 제스처 유실
- 매 클릭마다 BGM을 처음부터 다시 켬 — 끊김·재시작 폭주
- 웹에서만 Godot Stream/Sample을 몇 주째 튜닝 — BGM은 HTML5로 빼고 SFX에 집중하는 게 이득
- 웹 export에 BGM을 PCK에만 넣고 HTML5 URL로 기대 — **별도 파일 복사 필수**
- PowerShell `Set-Content -Encoding UTF8`로 `.gd`/`.import` 저장 — BOM 때문에 Godot 파싱 깨질 수 있음 (UTF-8 without BOM)

---

## 플랫폼별 권장 구성

```
[네이티브]
  AudioStreamPlayer × N (SFX 풀) → bus SFX
  AudioStreamPlayer × 1 (BGM)    → bus BGM
  WAV loop_mode = LOOP_FORWARD

[웹]
  SFX: 위와 동일 + Sample + register_stream_as_sample + 제스처 unlock
  BGM: JavaScriptBridge → HTML5 Audio + export 시 wav 복사
  징글(clear/defeated): HTML5 원샷 (loop false)
```

---

## 성공 기준 (검증)

1. 웹 빌드 열고 **아무 키/클릭 없이** → 묵음이 정상.
2. 첫 클릭 직후 → SFX click + BGM 시작, 콘솔에 `ctx=running` / `[Audio/html] playing`.
3. 탭 전환(로비↔상점) → BGM만 갈아끼우고 재시작 폭주 없음.
4. 음소거/볼륨 슬라이더 → SFX 버스 + HTML5 `volume` 둘 다 반영.
5. 새로고침 후 캐시 버스팅된 wasm/pck인지 확인 (옛 빌드 오인 방지).

---

## 관련 파일 (이 레포)

- `scripts/autoload/audio.gd` — 웹/네이티브 분기, HTML5 BGM, unlock
- `scripts/autoload/ui.gd` — 버튼에서 `Audio.ensure_web_unlocked()`
- `default_bus_layout.tres` — BGM/SFX 버스
- `assets/sfx/*.wav.import`, `assets/bgm/*.wav.import` — `compress/mode=0`
- `.github/workflows/web.yml` — export 후 `build/web/bgm/` 복사

이 문서만 보고 새 Godot 웹 게임에 옮길 때: **SFX는 Godot Sample + 제스처, BGM은 HTML5 + wav 배포**부터 깔고 시작하면 같은 삽질을 크게 줄일 수 있다.
