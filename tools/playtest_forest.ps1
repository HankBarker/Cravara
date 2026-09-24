param([switch]$FreshPreview, [switch]$ArmorPreview, [switch]$DinoPreview)
$ErrorActionPreference = 'Stop'
$gameDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) 'game'
$godotBinary = 'C:/Users/lorib/OneDrive/Desktop/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe'
if (-not (Test-Path -LiteralPath $godotBinary)) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $godotCommand) { throw 'Godot 4.6 is required. Open game/project.godot in Godot and press F5.' }
    $godotBinary = $godotCommand.Source
}
$launchArguments = @('--path', $gameDirectory, '--rendering-method', 'gl_compatibility', '--resolution', '1440x810')
if ($FreshPreview -or $ArmorPreview -or $DinoPreview) { $launchArguments += @('res://Forest/ForestPlaytest.tscn', '--', '--no-save-playtest') }
if ($ArmorPreview) { $launchArguments += '--armor-playtest' }
# Every dinosaur near the start plus a saddled stego and trike to ride.
if ($DinoPreview) { $launchArguments += '--dino-playtest' }
# This is the interactive game window requested for review.
Start-Process -FilePath $godotBinary -WorkingDirectory $gameDirectory -ArgumentList $launchArguments
