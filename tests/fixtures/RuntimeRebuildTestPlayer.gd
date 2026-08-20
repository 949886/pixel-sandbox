extends Player


func _ready() -> void:
	pass


func _physics_process(_delta: float) -> void:
	pass


func _process(_delta: float) -> void:
	pass


func _unhandled_input(_event: InputEvent) -> void:
	pass


func is_ready_for_gameplay() -> bool:
	return is_inside_tree() and is_starting_loadout_applied()
