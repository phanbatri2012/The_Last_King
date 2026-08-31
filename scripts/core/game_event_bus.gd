extends Node

signal battle_started(session_id: String)
signal battle_paused(reason: StringName)
signal battle_resumed(reason: StringName)
signal battle_finished(session_id: String, result: Dictionary)

signal enemy_killed(enemy_id: StringName, context: Dictionary)
signal elite_killed(enemy_id: StringName, context: Dictionary)
signal boss_killed(boss_id: StringName, context: Dictionary)

signal unit_summoned(unit_id: StringName, context: Dictionary)
signal unit_died(unit_id: StringName, context: Dictionary)

signal enemy_braced(enemy_id: StringName, context: Dictionary)
signal enemy_exposed(enemy_id: StringName, context: Dictionary)
signal king_level_up(run_level: int)
