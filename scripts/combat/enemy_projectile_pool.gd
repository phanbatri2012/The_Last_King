class_name EnemyProjectilePool
extends Node2D

const PROJECTILE_SCENE := preload("res://scenes/gameplay/enemy_projectile.tscn")

@export_range(0, 128, 1) var prewarm_count := 24
@export_range(1, 256, 1) var maximum_count := 96

var _available: Array[EnemyProjectile] = []
var _active: Dictionary = {}
var _total_created := 0
var _combat_enabled := true


func _ready() -> void:
	for _index in mini(prewarm_count, maximum_count):
		var projectile := _create_projectile()
		if projectile != null:
			_available.append(projectile)


func request_projectile(request: Dictionary) -> EnemyProjectile:
	if not _combat_enabled:
		return null
	var projectile: EnemyProjectile
	if not _available.is_empty():
		projectile = _available.pop_back()
	elif _total_created < maximum_count:
		projectile = _create_projectile()
	if projectile == null:
		return null
	_active[projectile.get_instance_id()] = projectile
	projectile.activate(request)
	return projectile


func set_combat_enabled(enabled: bool) -> void:
	_combat_enabled = enabled
	if enabled:
		return
	for projectile_value in _active.values().duplicate():
		var projectile := projectile_value as EnemyProjectile
		if is_instance_valid(projectile):
			projectile.deactivate()
			_recycle_projectile(projectile)


func get_active_count() -> int:
	return _active.size()


func get_total_created() -> int:
	return _total_created


func _create_projectile() -> EnemyProjectile:
	var projectile := PROJECTILE_SCENE.instantiate() as EnemyProjectile
	if projectile == null:
		return null
	add_child(projectile)
	projectile.resolved.connect(_on_projectile_resolved)
	_total_created += 1
	return projectile


func _on_projectile_resolved(projectile: EnemyProjectile) -> void:
	_active.erase(projectile.get_instance_id())
	call_deferred("_recycle_projectile", projectile)


func _recycle_projectile(projectile: EnemyProjectile) -> void:
	if not is_instance_valid(projectile):
		return
	_active.erase(projectile.get_instance_id())
	if not _available.has(projectile):
		_available.append(projectile)
