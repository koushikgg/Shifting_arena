class_name RoleSettings
# ALL the balance numbers for roles are here. Change a number, run the game, and see.

# --- Who is on a team (4 per team). Bots fill the roles the human is not using. ---
const TEAM_ROLES := [Role.Type.ATTACKER, Role.Type.ATTACKER, Role.Type.DEFENDER, Role.Type.SHIFT_CONTROLLER]

# --- Defender turrets ---
const TURRET_MAX := 2                 # turrets a defender can have at once
const TURRET_PLACE_COOLDOWN := 10.0   # seconds before another turret can be placed
const TURRET_PLACE_RANGE := 15.0      # must be this close to your own core to place one
const TURRET := {
	"health": 50,        # enemies can destroy turrets
	"range": 15.0,       # how far a turret can shoot (metres)
	"damage": 3,         # damage per turret shot
	"fire_delay": 0.4,   # seconds between turret shots
}

# --- Shift Controller ---
const EARLY_SHIFTS_PER_MATCH := 1     # early shifts each team may call per match


# Numbers for one role:
#   speed_mult:       multiplies walking speed (1.0 = the base speed)
#   max_health:       starting and maximum health
#   damage:           damage of one bullet
#   fire_delay_mult:  multiplies time between shots (bigger = slower shooting)
static func of(role: Role.Type) -> Dictionary:
	match role:
		Role.Type.ATTACKER:
			return {"speed_mult": 1.2, "max_health": 100, "damage": 5, "fire_delay_mult": 1.0}
		Role.Type.DEFENDER:
			return {"speed_mult": 0.8, "max_health": 150, "damage": 5, "fire_delay_mult": 1.0}
		_:
			return {"speed_mult": 0.5, "max_health": 80, "damage": 2, "fire_delay_mult": 2.0}
