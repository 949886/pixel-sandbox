extends Node2D

var gold: int = 0


func add_gold(amount: int) -> void:
	if amount > 0:
		gold += amount
