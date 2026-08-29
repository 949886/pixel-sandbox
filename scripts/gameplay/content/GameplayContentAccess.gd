class_name GameplayContentAccess
extends Object

## Finds the nearest scene-composed gameplay content provider without relying on
## a node path or a global resource path. World roots expose get_gameplay_content().
static func find_from(node: Node) -> GameplayContentDB:
	var current: Node = node
	while current != null and is_instance_valid(current):
		if current.has_method(&"get_gameplay_content"):
			var value: Variant = current.call(&"get_gameplay_content")
			if value is GameplayContentDB:
				return value as GameplayContentDB
		current = current.get_parent()
	return null
