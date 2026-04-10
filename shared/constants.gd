class_name Constants

# --- Input ---
const STICK_DEADZONE_INNER: float = 0.15
const STICK_DEADZONE_OUTER: float = 0.95

# --- Movement speeds per role ---
const SPEED_ESCAPIST: float = 220.0
const SPEED_PREDATOR: float = 180.0
const SPEED_TRAPPER: float = 130.0

# --- Predator ---
const PREDATOR_DASH_DISTANCE: float = 140.0
const PREDATOR_DASH_DURATION: float = 0.12
const PREDATOR_DASH_COOLDOWN: float = 3.0
const PREDATOR_MISS_STUN: float = 1.5

# --- Trapper ---
const TRAP_MAX_ACTIVE: int = 3
const TRAP_LIFETIME: float = 30.0
const TRAP_COOLDOWN: float = 2.0
const TRAP_SLOW_DURATION: float = 1.0
const TRAP_SLOW_MULTIPLIER: float = 0.4
const TRAP_RADIUS: float = 30.0
const TRAP_FATIGUE_DURATION: float = 5.0
const TRAPPER_SPEED_BONUS_PER_TRAP: float = 25.0  # Added to base speed per active trap

# --- Phase durations ---
const OBSERVATION_DURATION: float = 10.0
const DEPLOY_TRAPPER: float = 0.0
const DEPLOY_PREDATOR: float = 3.0
const DEPLOY_ESCAPIST: float = 10.0
const ROUND_END_DURATION: float = 3.0

# --- Match ---
const ROUNDS_PER_MATCH: int = 4
const ROUNDS_TO_WIN: int = 3
const TIEBREAKER_ROUND: int = 5

# --- Character ---
const CHARACTER_RADIUS: float = 15.0
const SEPARATION_RADIUS: float = 32.0
const SEPARATION_FORCE: float = 800.0

# --- Collision layers (bit values) ---
const LAYER_WALLS: int = 1
const LAYER_CHARACTERS: int = 2
const LAYER_HITBOXES: int = 4
const LAYER_HURTBOXES: int = 8
const LAYER_GOAL_ZONES: int = 16
const LAYER_TRAPS: int = 32
