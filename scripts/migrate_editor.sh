@echo off
setlocal enabledelayedexpansion

echo ======================================================
echo  MIGRARE SERVICE EDITOR -> NOUA STRUCTURA
echo ======================================================
echo.

set "root=%cd%"

REM caută toate fișierele .dart și aplică înlocuirile cu powershell inline
for /r "%root%" %%F in (*.dart) do (
  powershell -NoProfile -ExecutionPolicy Bypass ^
    -Command "(Get-Content '%%F') -replace 'service_editor_container_screen\.dart', 'screens/Adauga_modifica_serviciu/adauga_modifica_serviciu.dart' `
      -replace 'service_editor_screen\.dart', 'screens/Adauga_modifica_serviciu/adauga_serviciu.dart' `
      -replace '\bServiceEditorContainerScreen\b', 'AdaugaModificaServiciuScreen' `
      -replace '\bServiceEditorScreen\s*\(', 'AdaugaServiciuScreen(' | Set-Content '%%F'"
)

echo.
echo ======================================================
echo  GATA! Ruleaza:
echo    flutter clean && flutter pub get && flutter analyze
echo ======================================================
pause
