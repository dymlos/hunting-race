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
const OBSERVATION_DURATION: float = 10.0
const ROUND_END_DURATION: float = 3.0

# --- Match ---
const SCORE_TO_WIN: int = 3
const HUNT_DURATION: float = 30.0

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

# --- Araña ---
const ARANA_WEB_SLOW: float = 0.3
const ARANA_WEB_LIFETIME: float = 25.0
const ARANA_WEB_COOLDOWN: float = 12.0
const ARANA_WEB_MAX: int = 1
const ARANA_WEB_MAX_DIST: float = 240.0

const ARANA_ELASTIC_LIFETIME: float = 20.0
const ARANA_ELASTIC_COOLDOWN: float = 6.0
const ARANA_ELASTIC_MAX: int = 2
const ARANA_ELASTIC_BOUNCE_DIST: float = 120.0
const ARANA_ELASTIC_WIDTH: float = 20.0
const ARANA_ELASTIC_MAX_DIST: float = 300.0

const ARANA_VENOM_RADIUS: float = 25.0
const ARANA_VENOM_LIFETIME: float = 30.0
const ARANA_VENOM_COOLDOWN: float = 8.0
const ARANA_VENOM_MAX: int = 2

# --- Hongo ---
const HONGO_CONFUSE_LIFETIME: float = 25.0
const HONGO_CONFUSE_COOLDOWN: float = 10.0
const HONGO_CONFUSE_MAX: int = 2
const HONGO_CONFUSE_DURATION: float = 4.0
const HONGO_CONFUSE_RADIUS: float = 22.0

const HONGO_SPORE_RADIUS: float = 50.0
const HONGO_SPORE_SLOW: float = 0.4
const HONGO_SPORE_LIFETIME: float = 20.0
const HONGO_SPORE_COOLDOWN: float = 15.0
const HONGO_SPORE_MAX: int = 1

const HONGO_TELEPORT_RADIUS: float = 20.0
const HONGO_TELEPORT_LIFETIME: float = 30.0
const HONGO_TELEPORT_COOLDOWN: float = 12.0
const HONGO_TELEPORT_MAX: int = 1
const HONGO_TELEPORT_PLAYER_COOLDOWN: float = 3.0

# --- Escorpión ---
const ESCORPION_STINGER_RADIUS: float = 18.0
const ESCORPION_STINGER_LIFETIME: float = 40.0
const ESCORPION_STINGER_COOLDOWN: float = 6.0
const ESCORPION_STINGER_MAX: int = 3
const ESCORPION_STINGER_STUN: float = 1.5

const ESCORPION_QUICKSAND_RADIUS: float = 60.0
const ESCORPION_QUICKSAND_PULL: float = 80.0
const ESCORPION_QUICKSAND_KILL_RADIUS: float = 8.0
const ESCORPION_QUICKSAND_LIFETIME: float = 20.0
const ESCORPION_QUICKSAND_COOLDOWN: float = 18.0
const ESCORPION_QUICKSAND_MAX: int = 1

const ESCORPION_PINCERS_CLOSE_TIME: float = 1.0
const ESCORPION_PINCERS_RESET_TIME: float = 3.0
const ESCORPION_PINCERS_LIFETIME: float = 25.0
const ESCORPION_PINCERS_COOLDOWN: float = 15.0
const ESCORPION_PINCERS_MAX: int = 1
const ESCORPION_PINCERS_WALL_LENGTH: float = 50.0

# --- Pulpo ---
const PULPO_INK_RADIUS: float = 80.0
const PULPO_INK_LIFETIME: float = 15.0
const PULPO_INK_COOLDOWN: float = 10.0
const PULPO_INK_MAX: int = 2

const PULPO_TENTACLE_RADIUS: float = 25.0
const PULPO_TENTACLE_LINK_DURATION: float = 5.0
const PULPO_TENTACLE_LIFETIME: float = 30.0
const PULPO_TENTACLE_COOLDOWN: float = 14.0
const PULPO_TENTACLE_MAX: int = 1

const PULPO_CURRENT_WIDTH: float = 40.0
const PULPO_CURRENT_FORCE: float = 250.0
const PULPO_CURRENT_LIFETIME: float = 20.0
const PULPO_CURRENT_COOLDOWN: float = 8.0
const PULPO_CURRENT_MAX: int = 2

# --- Shared ability ---
const POISON_DURATION: float = 5.0
const POISON_CURE_RADIUS: float = 30.0
