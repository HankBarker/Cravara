param([switch]$FreshPreview, [switch]$ArmorPreview, [switch]$DinoPreview, [switch]$FolkPreview, [switch]$IntroPreview, [switch]$WildsPreview, [switch]$BlenderPreview)
$ErrorActionPreference = 'Stop'
$gameDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) 'game'
$godotBinary = 'C:/Users/lorib/OneDrive/Desktop/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64.exe'
if (-not (Test-Path -LiteralPath $godotBinary)) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $godotCommand) { throw 'Godot 4.6 is required. Open game/project.godot in Godot and press F5.' }
    $godotBinary = $godotCommand.Source
}
$launchArguments = @('--path', $gameDirectory, '--rendering-method', 'gl_compatibility', '--resolution', '1440x810')
if ($FreshPreview -or $ArmorPreview -or $DinoPreview -or $FolkPreview -or $IntroPreview -or $WildsPreview -or $BlenderPreview) { $launchArguments += @('res://Forest/ForestPlaytest.tscn', '--', '--no-save-playtest') }
if ($ArmorPreview) { $launchArguments += '--armor-playtest' }
# Every dinosaur near the start plus a saddled stego and trike to ride.
if ($DinoPreview) { $launchArguments += '--dino-playtest' }
# The folk within reach: a cache by camp (the trader), two dodos (the warden)
# and the makings of two stone houses.
if ($FolkPreview) { $launchArguments += '--folk-playtest' }
# The opening story and Orrin's first words, on a fresh no-save journey.
if ($IntroPreview) { $launchArguments += '--intro-playtest' }
# Pass 11's wilds on a fresh no-save journey: a boat, the Grave Horn, eggs, an
# incubator, a sword, a bow and crystal armour.
if ($WildsPreview) { $launchArguments += '--wilds-playtest' }
# Pass 12's Blender-made dinosaur (the Scarhorn) on its own: one follows you,
# one stands by a PixelLab allosaur to compare, a wild one hunts east of camp.
if ($BlenderPreview) { $launchArguments += '--blender-playtest' }
# This is the interactive game window requested for review.
Start-Process -FilePath $godotBinary -WorkingDirectory $gameDirectory -ArgumentList $launchArguments
