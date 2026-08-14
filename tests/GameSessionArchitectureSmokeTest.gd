extends Node

func _ready() -> void:
	assert(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/Main.tscn")

	var world_scene: PackedScene = load("res://scenes/World.tscn") as PackedScene
	assert(world_scene != null)
	var world: Node = world_scene.instantiate()
	assert(world.get_node_or_null("Player") != null)
	assert(world.get_node_or_null("GameplayWorld") != null)
	assert(world.get_node_or_null("GameModeManager") == null)
	assert(world.get_node_or_null("CreativeBrush") == null)
	assert(world.get_node_or_null("CreativeEntities") == null)
	assert(world.get_node_or_null("CreativeUI") == null)
	assert(world.get_node_or_null("StarterSpellPickup") == null)
	assert(world.get_node_or_null("CaveEyeA") == null)
	world.free()

	var normal_scene: PackedScene = load("res://scenes/sessions/NormalGameSession.tscn") as PackedScene
	assert(normal_scene != null)
	var normal_session: Node = normal_scene.instantiate()
	assert(normal_session.get_node_or_null("World") != null)
	assert(normal_session.get_node_or_null("World/CreativeBrush") == null)
	normal_session.free()

	var creative_scene: PackedScene = load("res://scenes/sessions/CreativeSession.tscn") as PackedScene
	assert(creative_scene != null)
	var creative_session: Node = creative_scene.instantiate()
	assert(creative_session.get_node_or_null("World/GameModeManager") != null)
	assert(creative_session.get_node_or_null("World/CreativeBrush") != null)
	assert(creative_session.get_node_or_null("World/CreativeEntities") != null)
	assert(creative_session.get_node_or_null("World/CreativeUI") != null)
	assert(creative_session.get_node_or_null("World/SandboxFixtures") != null)
	var mode_manager: GameModeManager = creative_session.get_node("World/GameModeManager") as GameModeManager
	assert(mode_manager.start_in_creative)
	assert(not mode_manager.allow_input_mode_toggle)
	creative_session.free()

	var main_scene: PackedScene = load("res://scenes/Main.tscn") as PackedScene
	assert(main_scene != null)
	var main: Node = main_scene.instantiate()
	var host: GameSessionHost = main.get_node_or_null("GameSessionHost") as GameSessionHost
	assert(host != null)
	assert(host.normal_session_scene != null)
	assert(host.creative_session_scene != null)
	main.free()

	print("Game Session Architecture Smoke Test: PASS")
	get_tree().quit()
