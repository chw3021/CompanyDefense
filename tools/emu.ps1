# 테스트용 가벼운 에뮬레이터(CD_Light)를 PC 가 멈추지 않게 띄우고, APK 를 설치해 실행한다.
#   powershell -File tools\emu.ps1            # 켜기 + 설치 + 실행
#   powershell -File tools\emu.ps1 -Shot a.png # 실행 후 스크린샷까지
#   powershell -File tools\emu.ps1 -Stop       # 에뮬레이터 끄기
param(
    [string]$Apk = "$PSScriptRoot\..\build\CompanyDefense-emu.apk",
    [string]$Shot = "",
    [switch]$Stop,
    [int]$MinFreeGB = 4,
    [string]$Gpu = "swangle_indirect"
)
# adb 는 부팅 중에 stderr 로 경고를 내므로 Stop 으로 두면 안 된다
$ErrorActionPreference = "Continue"
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$adb = "$sdk\platform-tools\adb.exe"
$pkg = "io.github.chw3021.companydefense"

if ($Stop) {
    & $adb emu kill
    return
}

# 1. 에뮬레이터가 없으면 띄운다. 여유 RAM 이 부족하면 켜지 않는다 (PC 멈춤 방지)
if (-not (Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue)) {
    $freeGB = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB
    if ($freeGB -lt $MinFreeGB) {
        Write-Host ("여유 RAM {0:N1}GB < {1}GB. 다른 프로그램(Godot 에디터, 브라우저 등)을 닫고 다시 실행하세요." -f $freeGB, $MinFreeGB)
        exit 1
    }
    Start-Process "$sdk\emulator\emulator.exe" -WindowStyle Minimized -ArgumentList @(
        "-avd", "CD_Light", "-no-snapshot", "-no-boot-anim", "-no-audio",
        "-gpu", $Gpu, "-camera-back", "none", "-camera-front", "none")
    # qemu 가 뜰 때까지 기다렸다가 우선순위를 낮추고 E코어(논리 CPU 8~15)에만 묶는다.
    # swiftshader 는 화면을 CPU 로 그려서 그냥 두면 모든 코어를 96% 까지 잡아 PC 가 멈춘다.
    for ($i = 0; $i -lt 30 -and -not (Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue); $i++) { Start-Sleep 1 }
    Get-Process qemu-system-x86_64, emulator -ErrorAction SilentlyContinue | ForEach-Object {
        $_.PriorityClass = "BelowNormal"
        $_.ProcessorAffinity = [IntPtr]0xFF00
    }
}

# 3. 부팅 완료 대기
& $adb wait-for-device
$deadline = (Get-Date).AddMinutes(5)
while ((& $adb shell getprop sys.boot_completed 2>$null) -ne "1") {
    if ((Get-Date) -gt $deadline) { Write-Host "부팅 시간 초과"; exit 1 }
    Start-Sleep 3
}
Write-Host "부팅 완료"

# 4. 설치 + 실행 (서명이 다른 예전 앱이 있으면 지우고 다시 설치)
$out = & $adb install -r $Apk 2>&1 | Out-String
if ($out -match "INSTALL_FAILED_UPDATE_INCOMPATIBLE|signatures do not match") {
    & $adb uninstall $pkg | Out-Null
    $out = & $adb install $Apk 2>&1 | Out-String
}
Write-Host $out.Trim()
& $adb shell monkey -p $pkg -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null

if ($Shot -ne "") {
    Start-Sleep 8
    # swiftshader 에서는 adb screencap 이 흰 화면이라 에뮬레이터 콘솔로 찍는다
    & $adb emu screenrecord screenshot $Shot | Out-Null
    Write-Host "스크린샷: $Shot"
}
