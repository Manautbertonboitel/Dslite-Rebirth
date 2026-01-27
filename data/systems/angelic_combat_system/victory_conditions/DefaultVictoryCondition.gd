class_name DefaultVictoryCondition
extends VictoryCondition

func evaluate(fighters):
	var players_alive = fighters.any(
		func(f): return f.is_alive() and f.faction == Faction.Type.PLAYER
	)
	var enemies_alive = fighters.any(
		func(f): return f.is_alive() and f.faction == Faction.Type.ENEMY
	)

	if not players_alive:
		return Result.DEFEAT
	if not enemies_alive:
		return Result.VICTORY

	return Result.ONGOING
