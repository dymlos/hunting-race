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
- `shared/enums.gd` — GameState, Team, Role, CCType, TrapperCharacter + helpers
- `shared/constants.gd` — Speeds, timers, collision layers, per-ability tuning constants
- `shared/map_data.gd` — Data-driven map definitions (walls, spawns, goals)
- `shared/trapper_characters.gd` — Static data for 4 trapper characters (Araña, Hongo, Escorpión, Pulpo)

### Autoloads
- `autoloads/input_manager.gd` — Per-device controller polling (8 players), edge detection
- `autoloads/game_manager.gd` — Phase state machine, per-escapist scoring, team role swapping, character selections

### Components
- `components/movement_component.gd` — Velocity, speed modifiers, dash, soft separation (used by Escapist)
- `components/status_effect_component.gd` — Stun, root, slow with duration timers
- `components/poison_component.gd` — Poison state: timer, ally-cure mechanic, death on expire

### Scenes
- `scenes/main/main.gd` — Main orchestrator, view stack, character spawning, state transitions
- `scenes/arena/arena.gd` — Builds map geometry from MapData, goal detection
- `scenes/characters/base_character.gd` — Base CharacterBody2D class (used by Escapist)
- `scenes/characters/escapist/escapist.gd` — Physical character, runs to goal, poison/inversion support
- `scenes/characters/trapper/trapper.gd` — Non-physical cursor (Node2D), ability system, bot AI
- `scenes/objects/trap.gd` — Legacy Area2D trap (slow or lethal) — may be retired

### Trapper Abilities
- `scenes/characters/trapper/abilities/trapper_ability.gd` — Base class: cooldowns, multi-point placement, active object tracking
- `scenes/characters/trapper/abilities/arana/` — Expansive Web (3pt slow), Elastic Web (2pt bounce), Persistent Venom (poison)
- `scenes/characters/trapper/abilities/hongo/` — Confusing Mushroom (invert), Toxic Spore Zone (slow+poison), Fungal Teleport (linked pair)
- `scenes/characters/trapper/abilities/escorpion/` — Buried Stinger (hidden poison+stun), Quicksand (pull to death), Crushing Pincers (closing walls)
- `scenes/characters/trapper/abilities/pulpo/` — Ink Stain (visibility), Binding Tentacle (link players), Water Current (directional flow)

### UI
- `scenes/ui/team_setup.gd` — Join with A, pick team, START to begin (roles assigned per-round)
- `scenes/ui/stage_select.gd` — Pick map, START to confirm, SELECT to go back
- `scenes/ui/character_select.gd` — Per-round trapper character selection, no duplicates per team
- `scenes/ui/phase_overlay.gd` — Phase announcements (OBSERVE, HUNT, round/match end)
- `scenes/ui/game_hud.gd` — Scores, round number, escapist count, role indicator

## Cross-Cutting Patterns

### Game Flow
TeamSetup → StageSelect → CharacterSelect → OBSERVATION → HUNT → ROUND_END → CharacterSelect → repeat

### Asymmetric Round Flow
1. GameManager assigns roles based on `escapist_team` (flips each round)
2. Character select shown for trapping team (new trapper picks each round)
3. OBSERVATION → characters spawn, all frozen, countdown
4. HUNT → all unfrozen, escapists run, trappers use character-specific abilities
5. Round ends when all escapists scored or died
6. Teams swap → character select for new trapping team → next round

### Trapper Character System
4 unique characters (Araña, Hongo, Escorpión, Pulpo), each with 3 abilities mapped to A/RB/X.
Abilities use TrapperAbility base class with support for single-point and multi-point placement.
B cancels mid-placement for multi-point abilities.

### Input System
Godot's action map can't handle 8+ players — InputManager polls raw device state. Actions: `&"dash"` (A), `&"ability"` (RB), `&"cancel"` (B), `&"interact"` (X).

### View Stack & Input Bleed Prevention
`push_view()`/`pop_view()`/`replace_view()` with `input_blocked` and edge suppression.

### Shared Systems
- **Poison:** PoisonComponent on Escapist. Timer-based, ally touch cures, death on expire. Used by Araña, Hongo, Escorpión.
- **Control Inversion:** `controls_inverted` flag on Escapist, multiplies input by -1. Used by Hongo.

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
