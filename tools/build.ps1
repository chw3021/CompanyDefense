# 배포용(릴리스 서명) APK 를 만든다. 빌드할 때마다 version/code 를 1 올린다.
#   powershell -File tools\build.ps1                  # 버전 코드만 올려서 빌드
#   powershell -File tools\build.ps1 -Version 2.1.0   # 표시 버전도 바꿔서 빌드
#   powershell -File tools\build.ps1 -Me              # 내 전용 (골드 99999999, 시간 무한, 스테이지/직원 최대 해금), 버전은 그대로
# 결과: build\CompanyDefense.apk (폰 설치용) + build\CompanyDefense-v<버전>.apk (친구 공유용)
#       -Me 는 build\CompanyDefense-me.apk 만 만든다. 친구에게 주지 말 것.
# 서명 키는 저장소 밖 ..\..\keys 에 있다. 잃어버리면 같은 앱으로 업데이트할 수 없으니 꼭 백업할 것.
param([string]$Version = "", [switch]$Me)
$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\.."
$godot = "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe"
$props = "$root\..\keys\release.properties"
if (-not (Test-Path $props)) { throw "서명 정보가 없습니다: $props" }

$cfg = @{}
foreach ($line in Get-Content $props -Encoding UTF8) {
    if ($line -match "^\s*([^=]+?)\s*=\s*(.*)$") { $cfg[$matches[1]] = $matches[2] }
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$presets = "$root\export_presets.cfg"
$text = [IO.File]::ReadAllText($presets, $utf8)
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $cfg["keystore"]
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $cfg["alias"]
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $cfg["password"]
New-Item -ItemType Directory -Force "$root\build" | Out-Null

if ($Me) {
    # 기능 태그 rich_start 를 잠깐 켜서 빌드하고 프리셋은 원래대로 돌려 놓는다
    $apk = "$root\build\CompanyDefense-me.apk"
    if (Test-Path $apk) { Remove-Item $apk }
    $rich = ([regex]'custom_features=""').Replace($text, 'custom_features="rich_start"', 1)
    [IO.File]::WriteAllText($presets, $rich, $utf8)
    try { & $godot --headless --path $root --export-release "Android" $apk 2>&1 | Out-Null }
    finally { [IO.File]::WriteAllText($presets, $text, $utf8) }
    if (-not (Test-Path $apk)) { throw "빌드 실패: APK 가 만들어지지 않았습니다." }
    Write-Host "완료: build\CompanyDefense-me.apk (내 전용, 친구에게 주지 말 것)"
    return
}

# 버전 올리기 (모든 프리셋 + project.godot)
$code = ([int]([regex]::Match($text, "version/code=(\d+)").Groups[1].Value)) + 1
$text = [regex]::Replace($text, "version/code=\d+", "version/code=$code")
if ($Version -ne "") {
    $text = [regex]::Replace($text, 'version/name="[^"]*"', "version/name=`"$Version`"")
    $proj = "$root\project.godot"
    $p = [IO.File]::ReadAllText($proj, $utf8)
    [IO.File]::WriteAllText($proj, [regex]::Replace($p, 'config/version="[^"]*"', "config/version=`"$Version`""), $utf8)
}
[IO.File]::WriteAllText($presets, $text, $utf8)
$name = [regex]::Match($text, 'version/name="([^"]*)"').Groups[1].Value
Write-Host "버전 $name (코드 $code) 빌드 중..."

$apk = "$root\build\CompanyDefense.apk"
if (Test-Path $apk) { Remove-Item $apk }
& $godot --headless --path $root --export-release "Android" $apk 2>&1 | Out-Null
if (-not (Test-Path $apk)) { throw "빌드 실패: APK 가 만들어지지 않았습니다." }
Copy-Item $apk "$root\build\CompanyDefense-v$name.apk" -Force
Write-Host "완료: build\CompanyDefense-v$name.apk ($([math]::Round((Get-Item $apk).Length / 1MB, 1))MB)"
