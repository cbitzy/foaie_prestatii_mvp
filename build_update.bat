@echo off
setlocal EnableExtensions EnableDelayedExpansion
cls

REM ====== CONFIG ======
set "PROJ=C:\Users\bitzy\StudioProjects\foaie_prestatii_mvp"
set "FLUTTER_BIN=C:\src\flutter\bin\flutter.bat"
if not exist "%FLUTTER_BIN%" set "FLUTTER_BIN=flutter"

REM Directorul unde vrei APK-ul final (copiat acolo la sfarsit):
set "PREF_OUT=%PROJ%\android\app\build\outputs\apk\release"
set "PREF_APK=%PREF_OUT%\app-release.apk"

set "GRADLEW=%PROJ%\android\gradlew.bat"

cd /d "%PROJ%"

echo ===========================================================
echo =        BUILD SCRIPT - FOAIE PRESTATII MECANIC            =
echo ===========================================================
echo(

echo ----- STEP 0: stop Gradle -----
echo(
echo [0/6] Stopping Gradle daemon...
if exist "%GRADLEW%" (
  pushd "%PROJ%\android"
  call "%GRADLEW%" --stop >nul 2>&1
  popd
  echo [0/6] Gradle daemon stopped.
) else (
  echo [0/6] gradlew not found, skipping.
)
echo -----------------------------------------------------------
echo(

REM ----- STEP A: read build-number from pubspec.yaml -----
echo ----- STEP A: read build number from pubspec.yaml -----
echo(

set "APP_VER="
set "APP_BUILD="

for /f "usebackq tokens=1,2 delims=|" %%A in (`
  powershell -NoProfile -Command ^
    "$p='%PROJ%\pubspec.yaml';" ^
    "$y=Get-Content $p -Raw;" ^
    "if($y -notmatch 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+(\d+)'){ throw 'Nu am gasit version: x.y.z+N in pubspec.yaml' }" ^
    "$ver=$Matches[1]; $bn=[int]$Matches[2];" ^
    "Write-Output ($ver + '|' + $bn);"
`) do (
  set "APP_VER=%%A"
  set "APP_BUILD=%%B"
)

if not defined APP_VER (
  echo [A] ERROR: Nu am putut citi versiunea din pubspec.yaml
  goto ABORT
)
echo [A] Found version in pubspec.yaml: %APP_VER%+%APP_BUILD%
echo -----------------------------------------------------------
echo(

echo ----- STEP 1: flutter clean -----
echo(
echo [1/6] Running: flutter clean
call "%FLUTTER_BIN%" clean
if errorlevel 1 (
  echo [1/6] ERROR: flutter clean failed. Trying retry...
  taskkill /F /IM java.exe /T >nul 2>&1
  if exist "%GRADLEW%" (
    pushd "%PROJ%\android"
    call "%GRADLEW%" --stop >nul 2>&1
    popd
  )
  call "%FLUTTER_BIN%" clean
  if errorlevel 1 (
    echo [1/6] ERROR: flutter clean failed again. Aborting.
    goto ABORT
  )
)
echo [1/6] OK
echo -----------------------------------------------------------
echo(

echo ----- STEP 2: flutter pub get -----
echo(
echo [2/6] Running: flutter pub get
call "%FLUTTER_BIN%" pub get
if errorlevel 1 (
  echo [2/6] ERROR: flutter pub get failed.
  goto ABORT
)
echo [2/6] OK
echo -----------------------------------------------------------
echo(

echo ----- STEP 3: flutter build apk --release -----
echo(
echo [3/6] Running: flutter build apk --release --build-name %APP_VER% --build-number %APP_BUILD%
call "%FLUTTER_BIN%" build apk --release --build-name %APP_VER% --build-number %APP_BUILD%
if errorlevel 1 (
  echo [3/6] ERROR: flutter build failed.
  goto ABORT
)
echo [3/6] OK
echo -----------------------------------------------------------
echo(

REM ----- Găsește APK-ul produs -----
set "FOUND_APK="
for /f "usebackq delims=" %%F in (`
  powershell -NoProfile -Command ^
  "$roots = @('build\app\outputs\flutter-apk','build\app\outputs\apk\release','build\app\outputs\apk');" ^
  "$all = @(); foreach($r in $roots){ if(Test-Path $r){ $all += Get-ChildItem -Path $r -Recurse -Filter *.apk -ErrorAction SilentlyContinue } }" ^
  "if(-not $all){ exit 1 }" ^
  "$pick = ($all | Sort-Object LastWriteTime -Descending | Select-Object -First 1);" ^
  "Write-Output $pick.FullName"`
) do (
  set "FOUND_APK=%%F"
)

if not defined FOUND_APK (
  echo [X] Nu am gasit niciun APK in build\app\outputs\...
  echo     Verifica manual cu:  dir /b /s build\app\outputs\*.apk
  goto ABORT
)
echo [X] Detectat APK build: %FOUND_APK%

REM ----- Copiază în folderul preferat -----
if not exist "%PREF_OUT%" mkdir "%PREF_OUT%" >nul 2>&1
copy /Y "%FOUND_APK%" "%PREF_APK%" >nul
if errorlevel 1 (
  echo [X] Nu am reusit copierea in %PREF_APK%
  goto ABORT
)
set "APK_PATH=%PREF_APK%"
echo [X] APK final: %APK_PATH%
echo -----------------------------------------------------------
echo(

echo ----- STEP 4: verifica device conectat -----
echo(
adb get-state 1>nul 2>nul
if errorlevel 1 (
  echo [4/6] ERROR: Nu e detectat niciun device. Activeaza USB debugging si conecteaza telefonul.
  goto ABORT
)
echo [4/6] Device OK
echo -----------------------------------------------------------
echo(

echo ----- STEP 5: UPDATE prin adb install -r -d -t -----
echo(
echo [5/6] Updating APK pe device (fara dezinstalare)...
adb install -r -d -t "%APK_PATH%"
if errorlevel 1 (
  echo [5/6] ERROR: adb install failed. Posibil APK nesemnat ^(release^) sau problema de autorizare USB.
  echo        Daca nu ai configurat semnarea release, foloseste:  flutter build apk --debug
  goto ABORT
)
echo [5/6] Success
echo -----------------------------------------------------------
echo(

echo ====================== DONE ======================
echo Versiune instalata: %APP_VER%+%APP_BUILD%
echo APK: %APK_PATH%
exit /b 0

:ABORT
echo ====================== FAILED ======================
exit /b 1
