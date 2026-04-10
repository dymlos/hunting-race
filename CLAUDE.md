# Project: Javi

Local multiplayer 2D game. Godot 4.6, GDScript, controller-only.

## Maintenance Rule
After any session that adds, removes, or restructures files, systems, or patterns: update this file and any relevant docs.

## File Map

*(empty — update as files are added)*

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

## Common Gotchas
*(add as discovered)*
