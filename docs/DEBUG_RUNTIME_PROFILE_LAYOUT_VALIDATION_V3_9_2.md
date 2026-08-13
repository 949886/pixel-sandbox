# V3.9.2 Debug / Runtime Profile Layout Validation

## Scope

This validation covers only the Debug Overlay and Runtime Profile organization refactor. Native API remains 11 and no GDExtension rebuild is required.

## Profile compatibility

PASS:

- All exported `WorldRuntimeProfile` fields from V3.9.1 are still present.
- PC profile resource keys are unchanged.
- PC profile runtime values are unchanged.
- Mobile profile resource keys are unchanged.
- Mobile profile runtime values are unchanged.
- Intentional display-only change: `Mobile PC Budgets` -> `Mobile Active Blocks`.
- Inspector categories detected: 8.
- Debug Overlay sections detected: 10.

## Regression validation

PASS:

- `validate_active_blocks_v3_9.py`
- `validate_native_flow_v3_8.py`
- `validate_collision_performance_v3_7_2.py`
- `validate_mobile_pc_budgets_v3_7_3.py`
- `validate_debug_profile_layout_v3_9_2.py`

The V3.7.2 collision validator was updated so it validates each grouped Debug Overlay formatted section instead of requiring the removed monolithic `stats_label`.

## Known environment warnings

The static collision validator continues to report 12 pre-existing missing-platform-binary warnings for extension targets that are not included in this package/runtime environment. No new warning category was introduced by V3.9.2.

## Runtime verification recommended

Because this environment does not include a runnable Godot 4.7 editor/runtime, visually confirm once in the editor:

1. Open either runtime profile resource and verify category/group presentation in Inspector.
2. Press F1 and verify the two-column overlay fits the intended desktop viewport.
3. Check that long Special/Chamber names wrap instead of overlapping the right column.
4. Verify F1 still toggles correctly and F2/F6 debug layers are unaffected.
