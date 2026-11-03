class_name Role
# The three roles a player or bot can have. Each team of 4 has:
# 2 Attackers, 1 Defender and 1 Shift Controller.
# (The numbers for each role - speed, health and so on - are in role_settings.gd.)

enum Type { ATTACKER, DEFENDER, SHIFT_CONTROLLER }


static func name_of(role: Type) -> String:
	match role:
		Type.ATTACKER:
			return "Attacker"
		Type.DEFENDER:
			return "Defender"
		_:
			return "Shift Controller"


# A short sentence shown on the role-select screen.
static func description_of(role: Type) -> String:
	match role:
		Type.ATTACKER:
			return "Fast. Pushes toward the enemy core."
		Type.DEFENDER:
			return "Slow but tough. Guards the core and places turrets (T)."
		_:
			return "Slow, weak gun. Top-down map (M) and one early shift (F). Protect them!"


# The colour used for the role text and the little marker above bots' heads.
static func color_of(role: Type) -> Color:
	match role:
		Type.ATTACKER:
			return Color(1.0, 0.6, 0.15)
		Type.DEFENDER:
			return Color(0.3, 0.9, 0.4)
		_:
			return Color(0.75, 0.4, 1.0)
