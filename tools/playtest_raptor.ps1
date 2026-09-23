$godotBinary = 'C:/Users/lorib/OneDrive/Desktop/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe'
if (-not (Test-Path -LiteralPath $godotBinary)) {
    $godotBinary = (Get-Command godot -ErrorAction Stop).Source
}
$gameDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) 'game'
# This is the interactive game window, not a background helper.
Start-Process -FilePath $godotBinary -WorkingDirectory $gameDirectory -ArgumentList @('--path', '.', '--rendering-method', 'gl_compatibility', '--resolution', '960x540', 'res://Tests/RaptorPlaytest.tscn', '--', '--no-save-playtest')
