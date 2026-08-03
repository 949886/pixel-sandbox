# Dirty-driven V3.2 validation

Completed in the integration environment:

- Checked all 87 GDScript files for balanced delimiters and project-consistent indentation.
- Checked every new native method for matching declaration, implementation and ClassDB binding.
- Compiled `sand_simulation.cpp` with a Godot API stub using C++17 syntax checking.
- Ran a native dirty-state unit harness covering:
  - non-empty write sets visual and collision dirty;
  - same-ID write does not set either dirty flag;
  - solid-to-non-solid sets collision dirty;
  - non-solid-to-non-solid sets visual dirty only;
  - native coarse collision rectangle generation.
- Checked changed renderer setup signatures and all call sites.

Not completed in this environment:

- A real Godot editor run.
- A Windows/Android/iOS GDExtension build, because the uploaded project does not contain the `godot-cpp` submodule contents or target toolchains.

The source package therefore retains the old DLL as a compatibility fallback. Rebuild the native extension before measuring dirty-driven performance.
