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
    # Suites written before the folk run without them (--no-folk): Orrin stands
    # beside the keeper and would rightly take the E they aim at companions.
    @{Name='ui-pass2'; Args=@('res://Tests/ForestUIV2Test.tscn'); UserArgs=@('--no-folk')},
    @{Name='world-pass3'; Args=@('res://Tests/ForestWorldPass3.tscn')},
    @{Name='mount-pass3'; Args=@('res://Tests/ForestMountPass3.tscn')},
    @{Name='ui-pass3'; Args=@('res://Tests/ForestUIV3Test.tscn')},
    @{Name='root-pass3'; Args=@('res://Tests/ForestRootPass3.tscn')},
    @{Name='world-pass4'; Args=@('res://Tests/ForestWorldPass4.tscn')},
    @{Name='mount-pass4'; Args=@('res://Tests/ForestMountPass4.tscn')},
    @{Name='ui-pass4'; Args=@('res://Tests/ForestUIV4Test.tscn')},
    @{Name='root-pass4'; Args=@('res://Tests/ForestRootPass4.tscn')},
    @{Name='interaction-pass4'; Args=@('res://Tests/ForestInteractionPass4.tscn'); UserArgs=@('--no-folk')},
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
    @{Name='wardrobe-save-pass7'; Args=@('res://Tests/WardrobeSavePass7.tscn')},
    # Keeper v2 rig contracts: armour on every cel of every clip, facing and set.
    @{Name='keeper-rig-pass8'; Args=@('--script','res://Tests/keeper_rig_pass8.gd')},
    @{Name='armor-capture-pass8'; Args=@('res://Tests/ArmorWardrobeCapture.tscn')},
    @{Name='keeper-feel-pass8'; Args=@('res://Tests/KeeperFeelCapture.tscn')},
    # The Keeper Y-sorts by his feet: in front of a trunk his feet stand before.
    @{Name='keeper-sort-pass8'; Args=@('res://Tests/KeeperSortCapture.tscn')},
    # Dinosaur v2: clip catalogue, every move's telegraph/contact/shape/shove,
    # behaviours and riders (headless), then every species in the real forest.
    @{Name='dino-v2'; Args=@('res://Tests/DinoV2Suite.tscn')},
    @{Name='dino-capture'; Args=@('res://Tests/DinoCapture.tscn')},
    @{Name='dino-behaviour'; Args=@('res://Tests/DinoBehaviourCapture.tscn')},
    # Points of interest: ruins, idols, caches, relic mounds and wild roots are
    # placed the same every time, never touch an old journey's edits, open or
    # dig once (surviving saves) and file their carvings in the journal.
    @{Name='world-poi'; Args=@('res://Tests/WorldPOISuite.tscn')},
    # The folk: stone building, the housing rules, who arrives when (and from
    # where), moving in and out, trade and tending, talking, saves.
    @{Name='folk'; Args=@('res://Tests/FolkSuite.tscn')},
    # The opening: the story plays only for a menu-started expedition, can be
    # clicked through or skipped, the keeper walks out of the tent, and
    # Orrin's first words run once (resumed if the keeper walks off).
    @{Name='intro'; Args=@('res://Tests/IntroSuite.tscn')},
    # Pass 10 beasts: allosaurus, lystrosaurus, the alpha boss and its den,
    # patient taming, nets that knock predators down, hunting, wildlife
    # placed per world with one rex, voices and roars.
    @{Name='beasts'; Args=@('res://Tests/BeastsSuite.tscn')},
    # Pass 10 map: the Bonelands east of the forest. The forest's original
    # square is unchanged (the legacy signature), the seam is open, the new
    # edge is walled, and older journeys gain the new wildlife once.
    @{Name='bonelands'; Args=@('res://Tests/BonelandsSuite.tscn')},
    # Pass 11 life: babies and their kin, nests and guardians, eggs, the
    # incubator, breeding, needs, companion gifts, the folk's tasks, regions,
    # bone heaps, nameplates, and all of it through a save.
    @{Name='life'; Args=@('res://Tests/LifeSuite.tscn')},
    # Pass 11 wilds: Glassmere, the Pale Hills and the Sunscar Dunes round the
    # old map, the seams open, deep water and the boat (saved afloat), the
    # wilds' harvests and beasts, the Buried King called with the Grave Horn
    # and fought, Old Maw in the deep, the piranha bay, and old journeys.
    @{Name='wilds'; Args=@('res://Tests/WildsSuite.tscn')},
    # Pass 12 hunting and hardship: hunters notice from further off and run
    # the keeper down, tire and give up, rivals break off, wedged beasts work
    # free, babies need their kin gone, rare guarded nests, the incubator
    # after Skarn, apex hunters out beyond the green, tough beasts.
    @{Name='hunt'; Args=@('res://Tests/HuntSuite.tscn')},
    # Pass 12 gear: each beast's materials, the weapon ladder, the Hornguard,
    # Plateback and Rustback sets on the rig, and whole-set bonuses.
    @{Name='gear'; Args=@('res://Tests/GearSuite.tscn')},
    # Pass 12 tribes: the Sunward oasis and the Ashen war camp, raiders on
    # sight (not in Ashen dress), trade and grudges, bands with tamed beasts,
    # archers, wild hunters taking tribesmen, the tribes' memory.
    @{Name='tribes'; Args=@('res://Tests/TribeSuite.tscn')},
    # Pass 12 wilds: the Blender Scarhorn's clips, the raptor coats, the bog,
    # barren dunes and ashen Pale Lands, territory, plates, swarms, the
    # dimetrodon's sun, the ash in the air, the Sun Sail.
    @{Name='wilds12'; Args=@('res://Tests/Wilds12Suite.tscn')}
)
if ($FromSuite -ne '' -and $FromSuite -notin $suites.Name) { throw ('Unknown suite: ' + $FromSuite) }
$started = $FromSuite -eq ''
foreach ($suite in $suites) {
    if ($suite.Name -eq $FromSuite) { $started = $true }
    if (-not $started) { continue }
    $logFile = Join-Path $logDirectory ('suite-' + $suite.Name + '.log')
    [string[]]$mode = @(if ($suite.Name -in @('gui-input','menu-flow','ui-pass2','ui-pass3','ui-pass4','interaction-pass4','mount-render-pass4','fishing-pass5','rider-render-pass5','ui-pass6','actions-pass6','character-render-pass6','wardrobe-editor-pass7','keeper-feel-pass8','keeper-sort-pass8','dino-capture','dino-behaviour')) { '--rendering-method'; 'gl_compatibility'; '--resolution'; '960x540' } else { '--headless' })
    # Bound power use and give timer-based UI/death tests enough real time even
    # after rendering optimizations greatly increase the available frame rate.
    # The Dummy audio driver still mixes in real time, so rendered suites no
    # longer depend on the machine's output device: a stalled or missing device
    # never stops playbacks and Godot reports them as resources in use at exit.
    $arguments = $mode + @('--audio-driver','Dummy','--path',$gameDirectory,'--max-fps','120','--quit-after','14400') + $suite.Args + @('--','--no-save-playtest') + $suite.UserArgs
    # Windows PowerShell wraps each engine stderr line (WARNING:, ERROR:,
    # SCRIPT ERROR:) in an error record; under 'Stop' the first one aborted the
    # run before the log below was checked. Log both streams as plain lines so
    # the ERROR-line check sees exactly what Godot printed.
    $ErrorActionPreference = 'Continue'
    & $godotBinary @arguments 2>&1 | ForEach-Object { "$_" } | Out-File -LiteralPath $logFile -Encoding utf8
    $engineExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $logText = Get-Content -LiteralPath $logFile -Raw
    if ($engineExit -ne 0 -or $logText -match '(?m)^(SCRIPT ERROR|ERROR):' -or $logText -notmatch '(FOREST_WORLD_TEST_PASS|failures=0|0 failures)') {
        Write-Output $logText
        throw ($suite.Name + ' failed; see ' + $logFile)
    }
    Write-Output ($suite.Name + ': passed')
}
