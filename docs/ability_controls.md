# Trapper Ability Controls — Testing Reference

All trappers move with **Left Stick**. Abilities are mapped to **A**, **RB**, **X**.
**B** cancels multi-point placement in progress.

---

## ARAÑA (Spider) — Purple

| Button | Ability | Points | Effect |
|--------|---------|--------|--------|
| **A** | Telaraña expansiva | 3 | Place 3 points → slow zone polygon (30% speed) |
| **RB** | Telaraña elástica | 2 | Place 2 points → bounce line (knocks back) |
| **X** | Veneno persistente | 1 | Poison puddle — ally touch cures, else death in 5s |

## HONGO (Mushroom) — Green

| Button | Ability | Points | Effect |
|--------|---------|--------|--------|
| **A** | Hongo confusor | 1 | Inverts controls for 4s. Single-use on contact |
| **RB** | Esporas tóxicas | 1 | Slow zone (40%) + poison on exit |
| **X** | Teletransporte fúngico | 2 | Place 2 portals → teleports anyone who steps in |

## ESCORPIÓN (Scorpion) — Orange

| Button | Ability | Points | Effect |
|--------|---------|--------|--------|
| **A** | Aguijón enterrado | 1 | Nearly invisible trap — poison + 1.5s stun. Single-use |
| **RB** | Arena movediza | 1 | Pulls to center → death at center. Escape by circling |
| **X** | Tenaza trituradora | 2 | Place 2 walls → close and crush when escapist enters |

## PULPO (Octopus) — Blue

| Button | Ability | Points | Effect |
|--------|---------|--------|--------|
| **A** | Mancha de tinta | 1 | Large dark fog zone — hides everything inside |
| **RB** | Tentáculo enlazador | 1 | Roots first victim. Second victim → both linked 5s |
| **X** | Corriente de agua | 2 | Place 2 points → directional push current |

---

## Multi-point placement flow

Abilities with **Points > 1** require multiple presses:
1. Press the button → first point placed at cursor (shown as dot)
2. Move cursor, press again → second point
3. (If 3 points) Press again → third point, ability activates
4. **B** at any time cancels and refunds the placement

## Shared mechanics

- **Poison** (green tint + timer arc): Cured if a non-poisoned ally Escapist touches within 30px. Otherwise kills after 5s.
- **Control inversion** (magenta tint): Movement input flipped for 4s.
- **Stun**: Frozen in place, can't move.

## Cooldowns & limits per ability

| Character | A cd / max | RB cd / max | X cd / max |
|-----------|-----------|------------|-----------|
| Araña | 12s / 1 | 6s / 2 | 8s / 2 |
| Hongo | 10s / 2 | 15s / 1 | 12s / 1 |
| Escorpión | 6s / 3 | 18s / 1 | 15s / 1 |
| Pulpo | 10s / 2 | 14s / 1 | 8s / 2 |
