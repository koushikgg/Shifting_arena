class_name Team
# Teams. Anything that belongs to a team (players, cores) has a "team" property
# that uses this list. Use it like:  Team.Type.BLUE  or  Team.Type.RED
# Keeping it in its own file means every part of the game shares the same idea of "team".

enum Type { BLUE, RED }


# The display colour for a team.
static func color_of(team: Type) -> Color:
	return Color(0.2, 0.45, 1.0) if team == Type.BLUE else Color(1.0, 0.25, 0.25)


# The team's name as text, e.g. "Blue".
static func name_of(team: Type) -> String:
	return "Blue" if team == Type.BLUE else "Red"


# Returns the other team.
static func opponent_of(team: Type) -> Type:
	return Type.RED if team == Type.BLUE else Type.BLUE
