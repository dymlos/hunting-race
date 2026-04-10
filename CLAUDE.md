# Project: Javi

Local multiplayer 2D chase game. Godot 4.6, GDScript, controller-only.
3v3 symmetric teams: each team has 1 Escapist + 1 Predator + 1 Trapper. Both Escapists race to cross the enemy goal. Round ends on first kill or first goal crossing.

## Reference Projects
- `E:\Users\Lunaroh\Documents\Godot\OmegaStrikers` — InputManager, view stack, retro draw, GameManager pattern
- `E:\Users\Lunaroh\Documents\Godot\Battlerite` — Component system (movement, health, hitbox/hurtbox, status effects, abilities)

## Maintenance Rule
After any session that adds, removes, or restructures files, systems, or patterns: update this file and any relevant docs.

## File Map

### Shared
- `shared/enums.gd` — GameState, Team, Role, CCType enums + team_color(), role_color(), role_name()
- `shared/constants.gd` — Speeds, timers, collision layers, character sizes
- `shared/map_data.gd` — Data-driven map definitions (walls, spawns, goals)

### Autoloads
- `autoloads/input_manager.gd` — Per-device controller polling (8 players), double-buffered edge detection, disconnect/reconnect
- `autoloads/game_manager.gd` — Phase state machine (OBSERVATION → DEPLOYMENT → HUNT → ROUND_END), scoring, deployment queue, role rotation

### Components
- `components/movement_component.gd` — Velocity, speed modifiers, dash, soft separation
- `components/status_effect_component.gd` — Stun, root, slow with duration timers
- `components/hitbox_component.gd` — Damage dealer Area2D (activated during attacks)
- `components/hurtbox_component.gd` — Damage receiver Area2D (always active on Escapist)

### Scenes
- `scenes/main/main.gd` — Main orchestrator, view stack, character spawning, state transitions, pause
- `scenes/arena/arena.gd` — Builds map geometry from MapData, wall/goal rendering, goal detection
- `scenes/characters/base_character.gd` — Base class: input, movement, rendering
- `scenes/characters/escapist/escapist.gd` — Fastest, has hurtbox, must reach goal
- `scenes/characters/predator/predator.gd` — Dash attack, one-hit kill, self-stun on miss
- `scenes/characters/trapper/trapper.gd` — Places traps (max 3), speed scales with active traps
- `scenes/objects/trap.gd` — Area2D trap: slows enemies, has lifetime, destroyable by Predator dash

### UI
- `scenes/ui/team_setup.gd` — Join with A, pick team with stick, auto-assign roles, START to begin
- `scenes/ui/phase_overlay.gd` — Phase announcements (OBSERVE, DEPLOY, HUNT, round/match end)
- `scenes/ui/game_hud.gd` — Round number, score, phase indicator

## Cross-Cutting Patterns

### Input System
Godot's action map can't handle 8+ players — use a custom InputManager that polls `Input.is_joy_button_pressed(device_id, ...)` directly. RT is an axis (`&"rt_axis"`), not a button. Use double-buffered edge detection for just-pressed/just-released.

### View Stack & Input Bleed Prevention
Manage views via a `_view_stack` with `push_view()`, `pop_view()`, `replace_view()`. Only the top view processes input — views below have `input_blocked = true`. On transitions, suppress edge detection for a few frames to prevent false triggers. Screens using raw `Input.is_joy_button_pressed()` must update `_prev_*` states even when `input_blocked` to prevent stale edge detection.

## Design Philosophy
- **Systematize, don't special-case.** If two abilities do similar things, refactor into a shared system in a component or base class.
- **No workarounds in plans.** Before finalizing any plan, check for: ad-hoc fixes that don't generalize, per-instance boilerplate that must be duplicated, special-case branches instead of polymorphism, manual state management that an existing system handles. Propose the scalable alternative instead.

## GDScript Rules
- **Variant inference fails.** GDScript can't infer types from Variant sources: Dictionary values, untyped array elements (`get_children()`, `get_nodes_in_group()`), `get()` results, and math builtins that return Variant (`sign()`, `clamp()`, `lerp()`, etc.). Use explicit casts (`node as Node2D`, `area as BaseProjectile`) or type annotations (`var x: float = ...`) before accessing properties or using the result in further expressions.

## Collision Layers
| Layer | Purpose |
|-------|---------|
| 1 | Walls (StaticBody2D arena boundary) |
| 2 | Characters (CharacterBody2D) |
| 3 | Hitboxes (Predator dash, Area2D) |
| 4 | Hurtboxes (Escapist vulnerable zone, Area2D) |
| 5 | Goal zones (Area2D, scoring detection) |
| 6 | Traps (Area2D, slow/stun trigger) |

## Common Gotchas
*(add as discovered)*
