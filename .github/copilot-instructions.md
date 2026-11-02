# Copilot instructions for Roguelikepuzzle

## Project and commands

This is a Godot 4.4 project. `project.godot` sets `title_screen.tscn` as the main scene, uses the Compatibility renderer, and registers `settings_manager.gd` as the `SettingsManager` autoload. There is no package manager, CI build, repository lint configuration, or test framework.

Run commands from the repository root with a Godot 4 executable:

```text
# Open the project in the editor
godot --editor --path .

# Run the game
godot --path .

# Run one headless integration/test script
godot --headless --path . --script res://test_user_requests.gd

# Run the other standalone SceneTree checks (one command per script)
godot --headless --path . --script res://test_elemental_system.gd
godot --headless --path . --script res://test_new_skill_relic_system.gd
godot --headless --path . --script res://test_poison_and_multi_skill.gd
godot --headless --path . --script res://test_animations_vfx.gd

# Export the configured Windows Desktop preset
godot --headless --path . --export-debug "Windows Desktop" build/Roguelikepuzzle.exe
```

The test files are custom `SceneTree` scripts, not a test runner: assertions execute from `_init()` and failures are reported through Godot's process exit/output. There is no separate lint command; use the Godot editor/script parser and a headless project launch as the basic syntax/load checks.

## Architecture

- `title_screen.tscn` is the configured entry scene. `title_screen.gd` builds much of the menu in code, controls difficulty/settings/tutorial actions, and transitions to `current_stage.tscn`.
- `current_stage.tscn` is the gameplay composition root. It contains `PuzzleBoard`, `ScoreManager`, `StageManager`, and `BuffManager`; `current_stage.gd` dynamically adds `RelicManager` and `RelicUIManager`, and adds `TutorialManager` when `SettingsManager.is_tutorial_mode` is enabled.
- `puzzle_board.gd` owns the 13x13 match-three board, fixed piece types, swapping/match/cascade state machine, falling animations, special pieces, elemental hazards/synergies, and the player/enemy turn sequence. Its `BoardState` transitions are central to input and combat timing.
- `stage_manager.gd` owns stage/encounter progression, enemy definitions and animations, player/enemy HP, difficulty-scaled combat, stage-clear/game-over sequences, backgrounds/audio, and relic-offer timing. It coordinates with `ScoreManager` and `RelicManager`.
- `score_manager.gd` owns score and per-piece resources, combo/fever-related values, the coin shop, potion skill tree, and their UI. `relic_manager.gd` applies relic effects through event/turn hooks; `relic_database.gd`, `element_data.gd`, and `glossary_database.gd` are data registries.
- `settings_manager.gd` is global and applies fullscreen, volume, audio pitch, game speed, difficulty, and tutorial/seed state. Gameplay scripts commonly retrieve it through `/root/SettingsManager`.
- `.tscn` files define the node hierarchy, UI/audio resources, signal connections, and script attachment. Prefer changing the owning scene/script rather than recreating an existing node elsewhere.

## Repository-specific conventions

- Treat the `PieceType` enum values and `PIECE_TEXTURES` ordering in `puzzle_board.gd` as a compatibility contract: `SHIELD=0`, `SWORD=1`, `COIN=2`, `POTION=3`, `FOOD=4`. Grid arrays use row/column coordinates and must stay synchronized with piece sprites.
- Keep board behavior inside the existing `BoardState` flow. Player input is normally accepted only in `IDLE`; swap, match, break, falling, cascade, and turn-sequence code deliberately gate one another.
- Use the existing signals (`combat_event`, tutorial signals, `stage_clear`, relic signals, and `difficulty_changed`) for cross-system notifications. Avoid adding direct circular calls when a signal or existing manager hook represents the event.
- Preserve the data-driven registries and string IDs used by skills, relics, elements, and enemies. Add a registry entry and update its consumers rather than scattering special cases across UI and combat code.
- Use `res://` resource paths and `preload()`/`load()` patterns already used by the project. Scene node names and paths are part of the runtime API because scripts frequently use `get_node_or_null()` and signal connections.
- Game timing is affected by `SettingsManager.game_speed` through `Engine.time_scale`; new animation, cooldown, and turn logic must remain correct when the speed setting changes.
- Keep Japanese UI text and the existing font-fallback approach intact. The project uses `font/g_comickoin_freeR.ttf` plus system fallbacks for Japanese and emoji.
- The root contains many dated `backups/` files and exploratory/generated material under `scratch/`; they are historical or tooling artifacts, not alternate runtime implementations. Make runtime changes in the active root scripts/scenes and do not use backup copies as the source of truth.
- Standalone test scripts may instantiate scripts/nodes directly and call private-looking helper methods. Preserve those helpers and their expected data shapes when refactoring, or update the focused test script at the same time.
