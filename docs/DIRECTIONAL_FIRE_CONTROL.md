# Directional fire touch control

The mobile/Web-mobile fire button is now a directional hold control inspired by
`UI.zip/Joystick/VirtualDirectionButton.gd`.

## Input behavior

- Touch inside the right fire disc to start continuous wand fire.
- The vector from the disc center to the finger becomes the normalized aim direction.
- Drag while held to update the aim direction continuously.
- Dragging beyond the visual circle remains captured, so aiming does not stop at the edge.
- Release the tracked finger to stop firing.
- The last valid aim direction is preserved after release.
- A center press inside the dead zone fires in the last aim direction.

The control emits direct signals instead of injecting InputMap actions. This keeps
mouse input, keyboard input, movement joystick input, jump input, and multi-touch
fire input independent.
