class_name Constants

# --- Input ---
const STICK_DEADZONE_INNER: float = 0.15
const STICK_DEADZONE_OUTER: float = 0.95

# --- Movement ---
const SPEED_ESCAPIST: float = 220.0
const TRAPPER_CURSOR_SPEED: float = 400.0

# --- Trapper ---
const TRAP_MAX_ACTIVE: int = 3
const TRAP_LIFETIME: float = 30.0
const TRAP_COOLDOWN: float = 2.0
const TRAP_SLOW_DURATION: float = 1.0
const TRAP_SLOW_MULTIPLIER: float = 0.4
const TRAP_RADIUS: float = 30.0
const TRAP_LETHAL_COOLDOWN: float = 8.0
const TRAP_LETHAL_RADIUS: float = 20.0

# --- Phase durations ---
const OBSERVATION_DURATION: float = 1.0
const ROUND_END_DURATION: float = 3.0

# --- Match ---
const SCORE_TO_WIN: int = 10  # Placeholder — tune later

# --- Character ---
const CHARACTER_RADIUS: float = 15.0
const SEPARATION_RADIUS: float = 32.0
const SEPARATION_FORCE: float = 800.0

# --- Map Hazards ---
const STICKY_WALL_STUN: float = 0.8          # Seconds frozen on contact
const STICKY_WALL_COOLDOWN: float = 0.5       # Can't get re-stuck for this long after
const STICKY_WALL_COLOR := Color(0.9, 0.3, 0.6)  # Pink/magenta
const MOVING_WALL_COLOR := Color(0.9, 0.6, 0.1)
const SLIPPERY_ZONE_COLOR := Color(0.3, 0.8, 1.0, 0.15)
const ONE_WAY_COLOR := Color(0.2, 1.0, 0.4, 0.4)
const SLIPPERY_MULTIPLIER: float = 1.2   # Faster on ice
const SLIPPERY_LERP_WEIGHT: float = 0.04 # How slowly input takes effect on ice
const ONE_WAY_PUSH_FORCE: float = 300.0

# --- Collision layers (bit values) ---
const LAYER_WALLS: int = 1
const LAYER_CHARACTERS: int = 2
const LAYER_GOAL_ZONES: int = 16
const LAYER_TRAPS: int = 32
