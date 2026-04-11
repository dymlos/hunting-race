# Project: Javi

Local multiplayer 2D chase game. Godot 4.6, GDScript, controller-only.
Asymmetric rounds: one team plays as Escapists (physical characters running to goal), other as Trappers (cursors placing traps). Teams swap roles each round. Points per escapist reaching goal.

## Reference Projects
- `E:\Users\Lunaroh\Documents\Godot\OmegaStrikers` — InputManager, view stack, GameManager pattern
- `E:\Users\Lunaroh\Documents\Godot\Battlerite` — Component system (movement, status effects)

## Maintenance Rule
After any session that adds, removes, or restructures files, systems, or patterns: update this file and any relevant docs.

## File Map

### Shared
- `shared/enums.gd` — GameState, Team, Role (ESCAPIST/TRAPPER), CCType + helpers
- `shared/constants.gd` — Speeds, timers, collision layers, trap params, scoring
- `shared/map_data.gd` — Data-driven map definitions (walls, spawns, goals)

### Autoloads
- `autoloads/input_manager.gd` — Per-device controller polling (8 players), edge detection
- `autoloads/game_manager.gd` — Phase state machine (OBSERVATION → HUNT → ROUND_END), per-escapist scoring, team role swapping

### Components
- `components/movement_component.gd` — Velocity, speed modifiers, dash, soft separation (used by Escapist)
- `components/status_effect_component.gd` — Stun, root, slow with duration timers

### Scenes
- `scenes/main/main.gd` — Main orchestrator, view stack, character spawning, state transitions
- `scenes/arena/arena.gd` — Builds map geometry from MapData, goal detection
- `scenes/characters/base_character.gd` — Base CharacterBody2D class (used by Escapist)
- `scenes/characters/escapist/escapist.gd` — Physical character, runs to goal, can be killed by lethal traps
- `scenes/characters/trapper/trapper.gd` — Non-physical cursor (Node2D), moves freely, places slow and lethal traps
- `scenes/objects/trap.gd` — Area2D trap: slow or lethal, has lifetime

### UI
- `scenes/ui/team_setup.gd` — Join with A, pick team, START to begin (roles assigned per-round)
- `scenes/ui/phase_overlay.gd` — Phase announcements (OBSERVE, HUNT, round/match end)
- `scenes/ui/game_hud.gd` — Scores, round number, escapist count, role indicator

## Cross-Cutting Patterns

### Asymmetric Round Flow
1. GameManager assigns roles based on `escapist_team` (flips each round)
2. OBSERVATION → characters spawn, all frozen, 10s countdown
3. HUNT → all unfrozen, escapists run, trappers place traps
4. Round ends when all escapists scored or died
5. Teams swap → next round

### Input System
Godot's action map can't handle 8+ players — InputManager polls raw device state. Actions: `&"dash"` (A), `&"ability"` (RB), `&"cancel"` (B), `&"interact"` (X).

### View Stack & Input Bleed Prevention
`push_view()`/`pop_view()`/`replace_view()` with `input_blocked` and edge suppression.

### Trapper Cursor
Trappers are Node2D (not CharacterBody2D). They move freely through walls via stick input. RB places slow trap, A places lethal trap. Max 3 active traps.

## Design Philosophy
- **Systematize, don't special-case.**
- **No workarounds in plans.**

## GDScript Rules
- **Variant inference fails.** Use explicit casts or type annotations for Dictionary values, `get_children()`, `get()`, and math builtins.

## Collision Layers
| Layer | Purpose |
|-------|---------|
| 1 | Walls (StaticBody2D) |
| 2 | Characters (Escapist CharacterBody2D) |
| 5 | Goal zones (Area2D) |
| 6 | Traps (Area2D) |

## Common Gotchas
*(add as discovered)*
