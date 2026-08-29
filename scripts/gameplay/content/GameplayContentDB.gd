class_name GameplayContentDB
extends Resource

## Root composition object for gameplay content. Runtime systems receive this
## resource from scene/bootstrap composition; they do not discover content by
## loading paths or by maintaining code-side registration lists.
@export var default_flow_id: StringName = &""
@export var flow_catalog: GameFlowCatalog
@export var default_starting_loadout: StartingLoadoutDef
@export var spell_catalog: SpellCatalog
@export var enemy_catalog: EnemyCatalog
@export var encounter_catalog: EncounterCatalog
@export var wand_generation_catalog: WandGenerationCatalog
@export var reward_catalog: RewardCatalog
@export var creative_entity_catalog: CreativeEntityCatalog
@export var creative_rules: GameRules
@export var status_rules: StatusRulesDef
@export var creative_wand_template: WandDef


func is_valid() -> bool:
	if default_flow_id == &"" or flow_catalog == null or not flow_catalog.is_valid():
		return false
	if flow_catalog.get_flow(default_flow_id) == null:
		return false
	if default_starting_loadout == null or not default_starting_loadout.is_valid():
		return false
	if spell_catalog == null or not spell_catalog.is_valid():
		return false
	if enemy_catalog == null or not enemy_catalog.is_valid():
		return false
	if encounter_catalog == null or not encounter_catalog.is_valid(enemy_catalog):
		return false
	if wand_generation_catalog == null or not wand_generation_catalog.is_valid():
		return false
	if reward_catalog == null or not reward_catalog.is_valid(wand_generation_catalog):
		return false
	if creative_entity_catalog == null or not creative_entity_catalog.is_valid():
		return false
	if creative_rules == null or status_rules == null or creative_wand_template == null:
		return false
	return true
