#!/usr/bin/env bash
# Run the Godot console binary against the game project. Usage: tools/keeper/godot.sh <godot args...>
G="C:/Users/lorib/OneDrive/Desktop/Godot_v4.6.1-stable_win64.exe/Godot_v4.6.1-stable_win64_console.exe"
exec "$G" --path C:/Cravera/game "$@"
