# Cravara

**Sixth forest pass:** persistent keeper customization, fitted cloth/leather equipment, 52 directional action clips, bows and mounted shooting, gardens and cooking, dinosaur gathering jobs, species voices, inventory sort/quick-stack, and tool power progression. Start with the [sixth-pass review route](docs/SKYFANG_PLAYTEST.md).

**New forest playtest:** double-click [Play Cravera.cmd](Play%20Cravera.cmd), or open `game/project.godot` in Godot 4.6 and press F5. The default launch now opens **Cravera: The Skyfang Wilds**. See the [playtest guide](docs/SKYFANG_PLAYTEST.md) for controls, implemented systems, validation, and known limitations. The earlier playground remains available at `game/playground.tscn`.

The fourth forest pass adds one-key interaction and mounting, illustrated saddled variants with seated rider animations, mount attacks and feeding, textured ground, grounded shadows, doors over floors, aligned roofing, bed-bound respawning, miniature floating loot, rustic foley, and optional corner shortcuts. See the guide's **Fourth-pass review route** and [validation evidence](art/forest-pass4/VALIDATION.md).

The fifth pass restores the original hero identity while riding, adds cloth and darker leather gear, rider knock-offs, fishing holes and a Space-controlled fishing game, mushrooms and refillable tonics, compact overhead furniture, reclaimable tents, and a two-meter survival system with lasting meals. See the guide's **Fifth-pass review route**.

A top-down 2D pixel-art survival and crafting game built in **Godot 4.4** using GDScript.

Inspired by Core Keeper, Terraria, Stardew Valley, and Ark: Survival Evolved.

## Game Concept

Players explore vibrant prehistoric biomes, tame dinosaurs through a trust-based system, craft tools and structures, and uncover the mystery behind alien crystalline structures that crashed into the planet during an event known as **The Fall of the Sky-Fangs**.

Core pillars:
- Exploration across prehistoric biomes
- Dinosaur taming (trust-based system)
- Crafting and base building
- NPC towns and tribe diplomacy
- Mutated dinosaurs with biome-specific traits
- Boss progression tied to biome advancement
- Fossil resurrection and DNA fusion systems
- Dynamic world events (meteor showers, eruptions)

## Getting Started

1. Install [Godot 4.4](https://godotengine.org/download) or later
2. Clone this repository
3. Open `game/project.godot` in the Godot editor
4. Press F5 to run the game

## Repository Structure

```
Cravara/
├── README.md               # This file
├── docs/                   # Architecture and project documentation
│   ├── ARCHITECTURE.md
│   ├── SYSTEMS_ARCHITECTURE.md
│   └── CURRENT_STATE.md
├── ai/                     # AI development instructions
│   ├── AI_INSTRUCTIONS.md
│   └── CODE_STYLE.md
├── assets_raw/             # Source assets (Aseprite files, music, concept art)
└── game/                   # Godot 4.4 project
    ├── project.godot
    ├── Player/             # Player character, states, inventory
    ├── Items/              # Item definitions and dropped item system
    ├── WorldObjects/       # Trees, rocks, workbench (destructible objects)
    ├── Sprites/            # Character and creature sprite sheets
    ├── UI/                 # Inventory UI, drag-and-drop, HUD
    ├── Tile Maps/          # Tileset and tilemap definitions
    ├── Systems/            # Modular game systems (placement, etc.)
    ├── Scripts/            # Core utilities (crafting, spawning, base classes)
    └── Autoloads/          # Global singletons (SignalBus)
```

## Current Features

- Player movement with state machine (idle, walk, run, attack, hurt, dead)
- 35-slot inventory system with 8-slot hotbar
- Item system with tools, resources, and placeables
- Crafting system (workbench, torch, wooden plank)
- Destructible world objects (trees, rocks, fallen logs) with loot drops
- T-Rex enemy with chase/attack AI
- Object placement system (workbench)
- Procedural resource spawning
- Drag-and-drop inventory management

## Technical Details

- **Engine**: Godot 4.4 (Forward Plus rendering)
- **Resolution**: 480x270 viewport scaled to 1920x1080 (pixel-perfect)
- **Input**: WASD movement, Shift sprint, mouse attack, 1-8 hotbar, ESC inventory

## Documentation

- [Architecture Overview](docs/ARCHITECTURE.md)
- [Systems Architecture](docs/SYSTEMS_ARCHITECTURE.md)
- [Current State](docs/CURRENT_STATE.md)
- [AI Development Instructions](ai/AI_INSTRUCTIONS.md)
- [Code Style Guide](ai/CODE_STYLE.md)
