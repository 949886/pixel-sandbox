# Touch Controls

The mobile HUD uses two multi-touch controls:

- Left `CherryVirtualJoystick`: movement inside the normal circle; combined jump and active upward flight inside the upper 120-degree `JUMP / FLY` sector.
- Right `VirtualDirectionButton`: drag to aim and hold to fire continuously.

The former blue `JumpButton` is no longer instantiated. Entering the joystick's extra upper region sends the same virtual jump/flight state that the button previously sent, including jump buffering, coyote time, upward levitation thrust, release, re-entry with remaining fuel, and upward swimming.
