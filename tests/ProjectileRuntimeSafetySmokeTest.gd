extends Node2D

## Runtime regressions for V4.2.2 spell hardening.
## Covers zero collision normals, zero-length rays, weak projectile owners and
## timeout-style teleport impacts where no physics normal exists.
func _ready() -> void:
	_test_zero_normal_bounce()
	_test_projectile_weak_owner()
	_test_zero_normal_teleport()
	_test_zero_range_hitscan()
	_test_zero_radius_runtime()
	print("Projectile Runtime Safety Smoke Test: PASS")
	get_tree().quit()

func _test_zero_normal_bounce() -> void:
	var projectile := GameplayProjectile.new()
	add_child(projectile)
	projectile.velocity = Vector2(100.0, 0.0)
	projectile.direction = Vector2.RIGHT
	projectile._remaining_bounces = 1
	projectile._bounce_energy = 0.82
	var safe_normal: Vector2 = projectile._safe_collision_normal(Vector2.ZERO)
	assert(safe_normal.is_normalized())
	assert(safe_normal.is_equal_approx(Vector2.LEFT))
	var destroyed := projectile._impact({"normal": Vector2.ZERO})
	assert(not destroyed)
	assert(projectile.velocity.x < 0.0)
	projectile.free()

func _test_projectile_weak_owner() -> void:
	var caster := CharacterBody2D.new()
	add_child(caster)
	var projectile := GameplayProjectile.new()
	add_child(projectile)
	projectile.setup(Vector2.RIGHT, caster, self, 100.0, 1.0)
	assert(projectile.source == caster)
	caster.free()
	assert(projectile.source == null)
	assert(projectile.world_interface == self)
	projectile.free()

func _test_zero_normal_teleport() -> void:
	var caster := CharacterBody2D.new()
	add_child(caster)
	var context := CastContext.create(caster, caster, self, self, Vector2.ZERO, Vector2.RIGHT)
	context.hit_position = Vector2(30.0, 20.0)
	context.hit_normal = Vector2.ZERO
	var effect := TeleportCasterEffect.new()
	effect.safety_offset = 4.0
	effect.execute(context)
	assert(caster.global_position.is_equal_approx(Vector2(26.0, 20.0)))
	caster.free()

func _test_zero_range_hitscan() -> void:
	var caster := CharacterBody2D.new()
	add_child(caster)
	var context := CastContext.create(caster, caster, self, self, Vector2.ZERO, Vector2.ZERO)
	var effect := HitscanEffect.new()
	effect.cast_range = 0.0
	effect.collision_mask = 0
	effect.execute(context)
	caster.free()

func _test_zero_radius_runtime() -> void:
	var caster := CharacterBody2D.new()
	add_child(caster)
	var context := CastContext.create(caster, caster, self, self, Vector2.ZERO, Vector2.RIGHT)
	var runtime := SpecialSpellRuntime.new()
	add_child(runtime)
	runtime.setup(SpecialSpellRuntime.Mode.BLACK_HOLE, context, 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, Color.WHITE, Color.WHITE)
	assert(runtime.radius > 0.0)
	runtime.free()
	caster.free()
