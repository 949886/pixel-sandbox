# Touch controls validation

Static validation completed for the touch-control layer:

- `World.tscn` instantiates `TouchControls.tscn`.
- Native desktop, native mobile, Web desktop, and Web mobile branches remain present.
- World runtime profile selection uses the same native/Web mobile classification.
- A real Web touch event enables controls for ambiguous/PWA user agents.
- Joystick and action buttons emit direct state; InputMap action injection is disabled.
- The ordinary joystick circle does not contribute to jump, crouch, or fast-fall decisions.
- The joystick upper semicircle emits a separate hover state while preserving movement output.
- The dedicated jump button preserves jump buffering and variable jump height, but no longer owns touch levitation.
- The dedicated fire button supports held continuous firing and shares the existing wand cooldown.
- Joystick, jump, and fire controls each track an independent touch index.
- Hiding the HUD releases movement, hover, jump, aim-fire state.
- Touch mode ignores emulated mouse movement when choosing facing direction.
- Responsive radii, action-button placement, resize, orientation, and safe-area handling are present.
- All literal `res://` references in modified integration files resolve.

The current environment does not contain a Godot executable or the project's Linux
x86_64 falling-sand extension, so native runtime and browser export execution could
not be performed here. Test the exported project on Android/iOS and desktop/mobile
browsers, especially simultaneous three-finger input and Safari safe-area behavior.
