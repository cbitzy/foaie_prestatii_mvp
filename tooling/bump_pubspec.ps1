param(
  [Parameter(Mandatory = $true)]
  [string]$Path
)

# Citește pubspec.yaml ca text brut
$text = Get-Content -LiteralPath $Path -Raw

# Versiune: x.y.z (+build optional)
$re = [regex]'^version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)(?:\+([0-9]+))?'

$m = $re.Match($text)
if (-not $m.Success) {
  Write-Error "Nu am găsit o linie 'version: x.y.z[+n]' validă în $Path"
  exit 1
}

$maj   = [int]$m.Groups[1].Value
$min   = [int]$m.Groups[2].Value
$patch = [int]$m.Groups[3].Value
$build = if ($m.Groups[4].Success) { [int]$m.Groups[4].Value } else { 0 }

# Bump DOAR build number
$build++
$newVersion = "$maj.$min.$patch+$build"

# Înlocuiește linia version:
$lines = $text -split "`r?`n"
for ($i = 0; $i -lt $lines.Length; $i++) {
  if ($lines[$i] -match '^\s*version:') {
    $lines[$i] = "version: $newVersion"
    break
  }
}
[IO.File]::WriteAllLines($Path, $lines)

# Trimite în STDOUT două valori separate prin |
# 1) x.y.z  2) build
Write-Output ("{0}|{1}" -f "$maj.$min.$patch", $build)
