# Simulation Cadence V3.3 Validation

## Static checks completed

- 87 GDScript files scanned for balanced delimiters and unterminated strings.
- 76 `class_name` declarations checked for duplicates.
- All direct `res://` references checked against the packaged project tree.
- Updated setup signatures verified across normal chunks and special multi-chunk structures.
- Runtime profile fields verified in both PC and Mobile resources.
- Debug HUD format placeholders verified against supplied values.
- ZIP integrity is checked after packaging.

## Expected runtime behavior

- PC player chunk: up to 60 native simulation steps per second and up to 60 dirty repaints per second.
- PC neighboring active chunks: up to 12 steps/repaints per second.
- Mobile player chunk: up to 30 native simulation steps/repaints per second.
- Mobile neighboring rate: 8 Hz; the default mobile radius is zero, so this is normally unused.
- A clean native grid performs no color-image conversion or GPU texture upload.
- The current player chunk is scheduled before streaming warmup and collision work.

## Runtime limitation

The included Windows binaries still need to contain the V3.2 dirty API (`is_dirty`, `clear_dirty`, collision dirty methods). Rebuild the extension using the included build script if the project reports the legacy repaint warning. This environment does not contain a Godot 4.7 editor/runtime, so editor-side parsing and device frame profiling could not be executed here.
