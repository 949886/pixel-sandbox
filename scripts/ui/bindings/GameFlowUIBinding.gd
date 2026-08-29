extends GameFlowUI

var _ui_context: GameUIContext = null


func bind_context(
		context: GameUIContext,
		quit_handler: Callable = Callable(),
	) -> bool:
	if context == null or not context.is_persistent_ready():
		return false
	if _ui_context != null:
		return _ui_context == context
	_ui_context = context
	return setup(context.game_manager, context.summary_store, quit_handler)
