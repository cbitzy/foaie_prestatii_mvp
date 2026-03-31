@echo off
setlocal EnableExtensions EnableDelayedExpansion
cls

REM ===========================================================
REM =            INSTALL SCRIPT - FOAIE PRESTATII             =
REM =   Instaleaza ultimul APK generat (fara rebuild)         =
REM ===========================================================

REM --- Detect project root (folderul unde se afla acest .bat) ---
set "PROJ=%~dp0"
if "%PROJ:~-1%"=="\" set "PROJ=%PROJ:~0,-1%"

REM --- Candidate roots where APK may exist ---
set "R1=%PROJ%\build\app\outputs\flutter-apk"
set "R2=%PROJ%\build\app\outputs\apk\release"
set "R3=%PROJ%\build\app\outputs\apk"
set "R4=%PROJ%\android\app\build\outputs\apk\release"

echo ===========================================================
echo PROJ: %PROJ%
echo ===========================================================
echo(

REM --- Check adb availability ---
where adb >nul 2>&1
if errorlevel 1 (
  echo ERROR: adb nu este in PATH.
  echo        Instaleaza platform-tools sau adauga-l in PATH.
  goto ABORT
)

REM --- Check a device is connected ---
adb get-state 1>nul 2>nul
if errorlevel 1 (
  echo ERROR: Nu e detectat niciun device.
  echo        Conecteaza telefonul si activeaza USB debugging.
  goto ABORT
)

REM --- Find newest APK from candidate roots ---
set "APK_PATH="

for /f "usebackq delims=" %%F in (`
  powershell -NoProfile -Command ^
    "$roots=@('%R1%','%R2%','%R3%','%R4%');" ^
    "$all=@();" ^
    "foreach($r in $roots){ if(Test-Path $r){ $all += Get-ChildItem -Path $r -Recurse -Filter *.apk -ErrorAction SilentlyContinue } }" ^
    "if(-not $all){ exit 1 }" ^
    "$pick = ($all | Sort-Object LastWriteTime -Descending | Select-Object -First 1);" ^
    "Write-Output $pick.FullName"
`) do (
  if not defined APK_PATH set "APK_PATH=%%F"
)

if not defined APK_PATH (
  echo ERROR: Nu am gasit niciun APK in:
  echo   %R1%
  echo   %R2%
  echo   %R3%
  echo   %R4%
  echo(
  echo Ruleaza mai intai unul din scripturile de build.
  goto ABORT
)

if not exist "%APK_PATH%" (
  echo ERROR: APK detectat dar nu exista pe disk:
  echo   %APK_PATH%
  goto ABORT
)

echo APK detectat:
echo   %APK_PATH%
echo(

REM --- Install (update) ---
echo Installing (adb install -r -d -t)...
adb install -r -d -t "%APK_PATH%"
if errorlevel 1 (
  echo ERROR: adb install a esuat.
  echo        Verifica autorizarea USB (Allow) si ca APK-ul e compatibil cu device-ul.
  goto ABORT
)

echo(
echo DONE: APK instalat cu succes.
exit /b 0

:ABORT
echo(
echo FAILED.
exit /b 1
