@echo off
setlocal

echo =====================================================
echo  MIGRARE SERVICE EDITOR -> NOUA STRUCTURA
echo =====================================================
echo.

REM Rulam o singura comanda PowerShell care:
REM - plimba toate .dart
REM - raporteaza exact ce a gasit/înlocuit
REM - scrie inapoi doar daca a schimbat ceva

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$patterns = @(" ^
  "  @{ Find='service_editor_container_screen\.dart'; Replace='screens/Adauga_modifica_serviciu/adauga_modifica_serviciu.dart'; Label='import path (container)'}," ^
  "  @{ Find='service_editor_screen\.dart'; Replace='screens/Adauga_modifica_serviciu/adauga_serviciu.dart'; Label='import path (editor)'}," ^
  "  @{ Find='\bServiceEditorContainerScreen\b'; Replace='AdaugaModificaServiciuScreen'; Label='type name (container)'}," ^
  "  @{ Find='\bServiceEditorScreen\s*\('; Replace='AdaugaServiciuScreen('; Label='constructor (editor)'}" ^
  ");" ^
  "$dart = Get-ChildItem -Recurse -Filter *.dart;" ^
  "$changed = 0;" ^
  "foreach($f in $dart){" ^
  "  $original = Get-Content $f.FullName -Raw;" ^
  "  $content = $original;" ^
  "  $fileChanged = $false;" ^
  "  foreach($p in $patterns){" ^
  "    if([Text.RegularExpressions.Regex]::IsMatch($content, $p.Find)){" ^
  "      Write-Host '[MODIFIC]' $f.FullName;" ^
  "      Write-Host '  -' $p.Label ':' $p.Find '->' $p.Replace;" ^
  "      $content = [Text.RegularExpressions.Regex]::Replace($content, $p.Find, $p.Replace);" ^
  "      $fileChanged = $true;" ^
  "    }" ^
  "  }" ^
  "  if($fileChanged){" ^
  "    Set-Content -Path $f.FullName -Value $content -Encoding UTF8;" ^
  "    $changed++" ^
  "  }" ^
  "}" ^
  "if($changed -eq 0){" ^
  "  Write-Host 'Nicio potrivire gasita in fisierele .dart.'" ^
  "} else {" ^
  "  Write-Host ('TOTAL fisiere modificate: ' + $changed)" ^
  "}"

echo.
echo =====================================================
echo  GATA! Ruleaza:
echo    flutter clean && flutter pub get && flutter analyze
echo =====================================================
pause
