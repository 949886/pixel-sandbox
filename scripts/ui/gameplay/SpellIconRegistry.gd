class_name SpellIconRegistry
extends RefCounted

## Compatibility facade for existing UI/Pickup code. Spell icons are owned directly
## by SpellDef resources, so there are no runtime path lookups, directory scans, or
## string-to-resource maps to break when the atlas directory is reorganized.
static func texture_for_spell(spell: SpellDef) -> Texture2D:
	return spell.icon if spell != null else null
