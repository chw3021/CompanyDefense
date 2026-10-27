---
name: commit-deploy
description: CompanyDefense 변경 사항을 커밋하고 main 에 푸시해 웹(GitHub Pages) 배포를 확인하며, 서명 키가 있으면 릴리스 APK 까지 빌드한다. 사용자가 "커밋", "배포", "커밋배포", "푸시", "올려줘", "APK 빌드" 를 말할 때 사용한다.
---

# 커밋 + 배포

배포는 두 갈래다.
- 웹: `main` 에 푸시하면 `.github/workflows/web.yml` 이 GitHub Pages 에 자동 배포한다.
- 안드로이드: `tools/build.ps1` 이 릴리스 APK 를 만든다. 실행할 때마다 `export_presets.cfg` 의 `version/code` 를 1 올린다.

## 순서

1. **변경 확인**: `git status --short` 와 `git diff --stat`
   - 이번 요청과 관련된 파일만 스테이징한다. 새 에셋의 `.import` 파일은 같이 넣는다.
   - 관련 없는 변경(Godot 가 만든 `.uid` 등)은 커밋하지 않고 보고만 한다.
   - `keys/`, `*.keystore`, `*.jks`, `account_keys.gd` 같은 비밀 파일은 절대 스테이징하지 않는다.

2. **APK 빌드 (커밋 전에)**: 버전 코드 변경을 같은 커밋에 넣기 위해 먼저 빌드한다.
   - 서명 정보 위치: 저장소 루트 기준 `../keys/release.properties`
   - 파일이 없으면 APK 는 건너뛰고 이유를 보고한다. 새 키스토어를 만들거나 다른 키로 서명하지 않는다. 다른 키로 서명하면 기존 설치 앱을 업데이트할 수 없다.
   - 파일이 있으면 `powershell -File tools/build.ps1` 을 실행한다. 사용자가 표시 버전을 말하면 `-Version x.y.z` 를 붙인다. 빌드는 몇 분 걸리므로 `block_until_ms` 를 넉넉하게 준다.
   - 빌드가 성공하면 `export_presets.cfg` 를, `-Version` 을 썼으면 `project.godot` 도 같이 스테이징한다.
   - `-Me` 빌드(개인용, 골드 99999999)는 사용자가 명시적으로 요청할 때만 쓴다.

3. **커밋**: 기존 로그처럼 한국어 한 줄 요약으로 쓴다. 무엇이 바뀌었는지를 적고, 필요하면 본문을 덧붙인다.
   - 예: `협상 성공 확률을 등급별로 변경 (1성 80% ~ 5성 10%)`

4. **푸시**: `git fetch origin` 다음에 `git status -sb` 로 앞서거나 뒤처졌는지 확인한다.
   - 뒤처져 있으면 `git pull --rebase origin main` 을 실행한다. 충돌이 나면 멈추고 보고한다.
   - `git push origin main`. force push 는 하지 않는다.
   - PowerShell 은 git 의 stderr 를 빨간 `NativeCommandError` 로 보여 주지만, 출력에 `main -> main` 이 있으면 성공이다.

5. **웹 배포 확인**:
   ```powershell
   gh run list --workflow web.yml --limit 1
   gh run watch <run-id> --exit-status
   ```
   실패하면 `gh run view <run-id> --log-failed` 로 원인을 확인해 보고한다.

## 보고

- 커밋 해시와 메시지
- 웹 배포 결과와 실행 링크 (`https://github.com/chw3021/CompanyDefense/actions/runs/<run-id>`)
- APK: `build/CompanyDefense-v<버전>.apk` 와 버전 코드, 또는 건너뛴 이유
- 커밋하지 않고 남긴 파일

## 주의

- 위험한 셸 명령(`Remove-Item -Recurse -Force`, `reset --hard`, force push)은 훅이 막을 수 있다. 막히면 우회하지 말고 다른 방법을 쓴다. 예를 들어 임시 폴더는 지우는 대신 새 이름으로 만든다.
- Godot 경로: `$env:LOCALAPPDATA/Programs/Godot/Godot_v4.7.2-stable_win64_console.exe`
