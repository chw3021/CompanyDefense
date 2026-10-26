# USB 로 연결한 실제 폰에 APK 를 설치해 실행한다. (PC 부담 없음)
#   powershell -File tools\phone.ps1             # 설치 + 실행
#   powershell -File tools\phone.ps1 -Shot a.png  # 실행 후 스크린샷까지
param(
    [string]$Apk = "$PSScriptRoot\..\build\CompanyDefense.apk",
    [string]$Shot = ""
)
$ErrorActionPreference = "Continue"
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$pkg = "io.github.chw3021.companydefense"

& $adb start-server 2>&1 | Out-Null   # 서버 시작 메시지가 상태값에 섞이지 않게 먼저 띄운다
$state = (& $adb -d get-state 2>&1 | Out-String).Trim()
if ($state -ne "device") {
    Write-Host "폰이 안 보입니다 ($state). USB 디버깅을 켜고, 폰에 뜨는 'USB 디버깅 허용'을 눌러 주세요."
    exit 1
}

# 서명이 다른 예전 앱이 있으면 지우고 다시 설치
$out = & $adb -d install -r $Apk 2>&1 | Out-String
if ($out -match "INSTALL_FAILED_UPDATE_INCOMPATIBLE|signatures do not match") {
    & $adb -d uninstall $pkg | Out-Null
    $out = & $adb -d install $Apk 2>&1 | Out-String
}
Write-Host $out.Trim()
& $adb -d shell monkey -p $pkg -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null

if ($Shot -ne "") {
    Start-Sleep 6
    & $adb -d shell screencap -p /sdcard/cd_shot.png
    & $adb -d pull /sdcard/cd_shot.png $Shot | Out-Null
    & $adb -d shell rm /sdcard/cd_shot.png
    Write-Host "스크린샷: $Shot"
}
