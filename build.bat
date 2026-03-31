@echo off
cls

REM ===== CONFIG =====
set "PROJ=C:\Users\bitzy\StudioProjects\foaie_prestatii_mvp"
set "GRADLEW=%PROJ%\android\gradlew.bat"
set "APK_PATH=%PROJ%\build\app\outputs\flutter-apk\app-release.apk"
set "AAB_PATH=%PROJ%\build\app\outputs\bundle\release\app-release.aab"
REM set "PATH=C:\Users\bitzy\AppData\Local\Android\Sdk\platform-tools;%PATH%"

cd /d "%PROJ%"

echo ===========================================================
echo =        BUILD SCRIPT - FOAIE PRESTATII MECANIC            =
echo ===========================================================
echo(

echo ----- STEP 0: stop Gradle -----
echo(
echo [0/5] Stopping Gradle daemon...
if exist "%GRADLEW%" (
  pushd "%PROJ%\android"
  call "%GRADLEW%" --stop >nul 2>&1
  popd
  echo [0/5] Gradle daemon stopped.
) else (
  echo [0/5] gradlew not found, skipping.
)
echo -----------------------------------------------------------
echo(

echo ----- STEP 1: flutter clean -----
echo(
echo [1/5] Running: flutter clean
call flutter clean
if errorlevel 1 (
  echo [1/5] ERROR: flutter clean failed. Trying retry...
  taskkill /F /IM java.exe /T >nul 2>&1
  if exist "%GRADLEW%" (
    pushd "%PROJ%\android"
    call "%GRADLEW%" --stop >nul 2>&1
    popd
  )
  call flutter clean
  if errorlevel 1 (
    echo [1/5] ERROR: flutter clean failed again. Aborting.
    goto ABORT
  )
)
echo [1/5] OK
echo -----------------------------------------------------------
echo(

echo ----- STEP 2: flutter pub get -----
echo(
echo [2/5] Running: flutter pub get
call flutter pub get
if errorlevel 1 (
  echo [2/5] ERROR: flutter pub get failed.
  goto ABORT
)
echo [2/5] OK
echo -----------------------------------------------------------
echo(

echo ----- STEP 3: flutter build apk --release -----
echo(
echo [3/5] Running: flutter build apk --release
call flutter build apk --release
if errorlevel 1 (
  echo [3/5] ERROR: flutter build apk failed.
  goto ABORT
)
echo [3/5] OK
echo -----------------------------------------------------------
echo(

echo ----- STEP 4: flutter build appbundle --release -----
echo(
echo [4/5] Running: flutter build appbundle --release
call flutter build appbundle --release
if errorlevel 1 (
  echo [4/5] ERROR: flutter build appbundle failed.
  goto ABORT
)
if not exist "%AAB_PATH%" (
  echo [4/5] ERROR: App Bundle not found:
  echo        %AAB_PATH%
  goto ABORT
)
echo [4/5] OK
echo -----------------------------------------------------------
echo(

echo ----- STEP 5: adb install -r ^<apk^> -----
echo(
echo [5/5] Installing APK on device with: adb install -r
if not exist "%APK_PATH%" (
  echo [5/5] ERROR: APK not found:
  echo        %APK_PATH%
  goto ABORT
)
rem adb install -r "%APK_PATH%"
if errorlevel 1 (
  echo [5/5] ERROR: adb install failed. Check USB debugging and authorization.
  goto ABORT
)
echo [5/5] Installed successfully.
echo -----------------------------------------------------------
echo(

echo ====================== DONE ======================
echo APK: %APK_PATH%
echo AAB: %AAB_PATH%
exit /b 0

:ABORT
echo ====================== FAILED ======================
exit /b 1
