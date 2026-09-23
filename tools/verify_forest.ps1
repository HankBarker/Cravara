param([string]$FromSuite = '')
$ErrorActionPreference = 'Stop'
$rootDirectory = Split-Path $PSScriptRoot -Parent
$gameDirectory = Join-Path $rootDirectory 'game'
$logDirectory = Join-Path $rootDirectory 'art/forest-playtest'
$godotBinary = 'C:/Users/lorib/OneDrive/Desktop/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godotBinary)) { $godotBinary = (Get-Command godot -ErrorAction Stop).Source }
New-Item -ItemType Directory -Force $logDirectory | Out-Null
$suites = @(
    @{Name='world'; Args=@('res://Forest/ForestWorldTest.tscn')},
    @{Name='inventory'; Args=@('--script','res://Tests/forest_inventory_test.gd')},
    @{Name='creatures'; Args=@('res://Tests/ForestCreaturesTest.tscn')},
    @{Name='integration'; Args=@('res://Forest/ForestPlaytest.tscn'); UserArgs=@('--verify-forest')},
    @{Name='gui-input'; Args=@('--script','res://Tests/forest_ui_integration.gd')},
    @{Name='menu-flow'; Args=@('--script','res://Tests/forest_menu_flow.gd')},
    @{Name='ai-pass2'; Args=@('res://Tests/ForestAIPass2.tscn')},
    @{Name='equipment-pass2'; Args=@('res://Tests/ForestEquipmentPass2.tscn')},
    @{Name='ui-pass2'; Args=@('res://Tests/ForestUIV2Test.tscn')},
    @{Name='world-pass3'; Args=@('res://Tests/ForestWorldPass3.tscn')},
    @{Name='mount-pass3'; Args=@('res://Tests/ForestMountPass3.tscn')},
    @{Name='ui-pass3'; Args=@('res://Tests/ForestUIV3Test.tscn')},
    @{Name='root-pass3'; Args=@('res://Tests/ForestRootPass3.tscn')},
    @{Name='world-pass4'; Args=@('res://Tests/ForestWorldPass4.tscn')},
    @{Name='mount-pass4'; Args=@('res://Tests/ForestMountPass4.tscn')},
    @{Name='ui-pass4'; Args=@('res://Tests/ForestUIV4Test.tscn')},
    @{Name='root-pass4'; Args=@('res://Tests/ForestRootPass4.tscn')},
    @{Name='interaction-pass4'; Args=@('res://Tests/ForestInteractionPass4.tscn')},
    @{Name='mount-render-pass4'; Args=@('res://Tests/MountPass4RenderQA.tscn')},
    @{Name='world-pass5'; Args=@('res://Tests/ForestWorldPass5.tscn')},
    @{Name='rider-pass5'; Args=@('res://Tests/ForestRiderPass5.tscn')},
    @{Name='root-pass5'; Args=@('res://Tests/ForestRootPass5.tscn')},
    @{Name='fishing-pass5'; Args=@('res://Tests/ForestFishingTest.tscn')},
    @{Name='rider-render-pass5'; Args=@('res://Tests/RiderPass5RenderQA.tscn')},
    @{Name='root-pass6'; Args=@('res://Tests/ForestRootPass6.tscn')},
    @{Name='workers-pass6'; Args=@('res://Tests/ForestWorkersPass6.tscn')},
    @{Name='character-pass6'; Args=@('res://Tests/CharacterPass6.tscn')},
    @{Name='character-render-pass6'; Args=@('res://Tests/CharacterPass6Render.tscn')},
    @{Name='ui-pass6'; Args=@('res://Tests/ForestUIPass6.tscn')},
    @{Name='actions-pass6'; Args=@('res://Tests/ForestActionsPass6.tscn')},
    @{Name='save-compat-pass6'; Args=@('res://Tests/ForestSaveCompatPass6.tscn')},
    @{Name='wardrobe-pass7'; Args=@('res://Tests/WardrobePass7.tscn')},
    @{Name='wardrobe-editor-pass7'; Args=@('res://Tests/WardrobeEditorPass7.tscn')},
    @{Name='wardrobe-save-pass7'; Args=@('res://Tests/WardrobeSavePass7.tscn')}
)
if ($FromSuite -ne '' -and $FromSuite -notin $suites.Name) { throw ('Unknown suite: ' + $FromSuite) }
$started = $FromSuite -eq ''
foreach ($suite in $suites) {
    if ($suite.Name -eq $FromSuite) { $started = $true }
    if (-not $started) { continue }
    $logFile = Join-Path $logDirectory ('suite-' + $suite.Name + '.log')
    [string[]]$mode = @(if ($suite.Name -in @('gui-input','menu-flow','ui-pass2','ui-pass3','ui-pass4','interaction-pass4','mount-render-pass4','fishing-pass5','rider-render-pass5','ui-pass6','actions-pass6','character-render-pass6','wardrobe-editor-pass7')) { '--rendering-method'; 'gl_compatibility'; '--resolution'; '960x540' } else { '--headless' })
    # Bound power use and give timer-based UI/death tests enough real time even
    # after rendering optimizations greatly increase the available frame rate.
    $arguments = $mode + @('--path',$gameDirectory,'--max-fps','120','--quit-after','14400') + $suite.Args + @('--','--no-save-playtest') + $suite.UserArgs
    & $godotBinary @arguments 2>&1 | Out-File -LiteralPath $logFile -Encoding utf8
    $engineExit = $LASTEXITCODE
    $logText = Get-Content -LiteralPath $logFile -Raw
    if ($engineExit -ne 0 -or $logText -match '(?m)^(SCRIPT ERROR|ERROR):' -or $logText -notmatch '(FOREST_WORLD_TEST_PASS|failures=0|0 failures)') {
        Write-Output $logText
        throw ($suite.Name + ' failed; see ' + $logFile)
    }
    Write-Output ($suite.Name + ': passed')
}
