@echo off
cls

REM ===== CONFIG =====
set "PROJ=C:\Users\bitzy\StudioProjects\foaie_prestatii_mvp"
set "GRADLEW=%PROJ%\android\gradlew.bat"
set "APK_PATH=%PROJ%\build\app\outputs\flutter-apk\app-release.apk"
REM set "PATH=C:\Users\bitzy\AppData\Local\Android\Sdk\platform-tools;%PATH%"

REM --- Auto-detect PACKAGE (applicationId) ---
set "MANIFEST=%PROJ%\android\app\src\main\AndroidManifest.xml"
set "APP_GRADLE=%PROJ%\android\app\build.gradle"
set "PACKAGE="

REM 1) Încearcă din build.gradle: applicationId "com.xyz.app"
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command ^
  "$p=(Get-Content -Raw '%APP_GRADLE%' 2>$null) -split \"`n\" |" ^
  "  Where-Object { $_ -match 'applicationId\s*\"([^\"]+)' } |" ^
  "  ForEach-Object { $Matches[1] } | Select-Object -First 1;" ^
  "if($p){Write-Output $p}"`) do (
  if not defined PACKAGE set "PACKAGE=%%A"
)

REM 2) Dacă nu e găsit, încearcă din AndroidManifest.xml: package="com.xyz.app"
if not defined PACKAGE (
  for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command ^
    "$m=(Get-Content -Raw '%MANIFEST%' 2>$null) -split \"`n\" |" ^
    "  Where-Object { $_ -match 'manifest[^>]*\spackage=\"([^\"]+)' } |" ^
    "  ForEach-Object { $Matches[1] } | Select-Object -First 1;" ^
    "if($m){Write-Output $m}"`) do (
    if not defined PACKAGE set "PACKAGE=%%A"
  )
)

if defined PACKAGE (
  echo [pre] Found package in sources: %PACKAGE%
) else (
  echo [pre] Package not found in sources; will detect after build.
)

cd /d "%PROJ%"

echo ===========================================================
echo =        BUILD SCRIPT - FOAIE PRESTATII MECANIC            =
echo ===========================================================
echo(

echo ----- STEP 0: stop Gradle -----
echo(
echo [0/4] Stopping Gradle daemon...
if exist "%GRADLEW%" (
  pushd "%PROJ%\android"
  call "%GRADLEW%" --stop >nul 2>&1
  popd
  echo [0/4] Gradle daemon stopped.
) else (
  echo [0/4] gradlew not found, skipping.
)
echo -----------------------------------------------------------
echo(

echo ----- STEP 1: flutter clean -----
echo(
echo [1/4] Running: flutter clean
call flutter clean
if errorlevel 1 (
  echo [1/4] ERROR: flutter clean failed. Trying retry...
  taskkill /F /IM java.exe /T >nul 2>&1
  if exist "%GRADLEW%" (
    pushd "%PROJ%\android"
    call "%GRADLEW%" --stop >nul 2>&1
    popd
  )
  call flutter clean
  if errorlevel 1 (
    echo [1/4] ERROR: flutter clean failed again. Aborting.
    goto ABORT
  )
)
echo [1/4] OK
echo -----------------------------------------------------------
echo(

echo ----- STEP 2: flutter pub get -----
echo(
echo [2/4] Running: flutter pub get
call flutter pub get
if errorlevel 1 (
  echo [2/4] ERROR: flutter pub get failed.
  goto ABORT
)
echo [2/4] OK
echo -----------------------------------------------------------
echo(

echo ----- STEP 3: flutter build apk --release -----
echo(
echo [3/4] Running: flutter build apk --release
call flutter build apk --release
if errorlevel 1 (
  echo [3/4] ERROR: flutter build failed.
  goto ABORT
)
echo [3/4] OK
echo -----------------------------------------------------------
echo(

echo ----- STEP 4: adb install -r ^<apk^> -----
echo(
echo [4/4] Installing APK on device with: adb install -r

REM STEP 3.5: Fresh install -> dezinstalează aplicația existentă (dacă am detectat package)
if defined PACKAGE (
  echo [3.5/4] Fresh install ON: uninstall "%PACKAGE%"...
  adb uninstall "%PACKAGE%" >nul 2>&1
) else (
  echo [3.5/4] Fresh install SKIPPED (package undetected).
)

if not exist "%APK_PATH%" (
  echo [4/4] ERROR: APK not found:
  echo        %APK_PATH%
  goto ABORT
)
REM --- Detect package FROM Gradle output-metadata.json + fresh uninstall ---
if not defined PACKAGE (
  set "META=%PROJ%\android\app\build\outputs\apk\release\output-metadata.json"
  if exist "%META%" (
    for /f "usebackq delims=" %%P in (`
      powershell -NoProfile -Command ^
        "$m = Get-Content -Raw '%META%' | ConvertFrom-Json;" ^
        "if($m -and $m.elements -and $m.elements.Count -gt 0){" ^
        "  $appId = $m.elements[0].applicationId;" ^
        "  if($appId){ Write-Output $appId }" ^
        "}"
    `) do (
      if not defined PACKAGE set "PACKAGE=%%P"
    )
  )
)

if defined PACKAGE (
  echo [3.5/4] Uninstall existing app (from build output): "%PACKAGE%"
  adb uninstall "%PACKAGE%" >nul 2>&1
) else (
  echo [3.5/4] Could not detect package from build output; proceeding without uninstall.
)

adb install "%APK_PATH%"

if errorlevel 1 (
  echo [4/4] ERROR: adb install failed. Check USB debugging and authorization.
  goto ABORT
)
echo [4/4] Installed successfully.
echo -----------------------------------------------------------
echo(

echo ====================== DONE ======================
exit /b 0

:ABORT
echo ====================== FAILED ======================
exit /b 1
