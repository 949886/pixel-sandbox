extends Node
class_name Main

# Initializes the SandSimulation object and acts as an interface for other nodes to 
# interact with said object. Also runs the main processing of the simulation.

var sim: SandSimulation

static var active: bool = false

@onready var canvas: Canvas = %Canvas

func _ready() -> void:
	sim = SandSimulation.new()
	# I haven't benchmarked extensively yet, but this chunk size has reasonable 
	# performance.
	sim.set_chunk_size(16)
	
	await get_tree().get_root().ready
	canvas.resized.connect(_on_window_resized)
	
	# This method would not be called without signals normally, but the window size
	# must be initialized at the start of the game.
	_on_window_resized()

func _on_window_resized() -> void:
	sim.resize(int(canvas.size.x / Settings.px_scale), int(canvas.size.y / Settings.px_scale))
	canvas.repaint()

func _process(_delta: float) -> void:
	if active:
		sim.step(Settings.simulation_speed)
		canvas.repaint()
