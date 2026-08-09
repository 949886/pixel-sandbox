# Visual Sectors V3.10

V3.10 adds an independent 64x64 Visual Sector grid alongside 16x16 Simulation Blocks and 64x64 Collision Sectors.

Runtime flow:

1. Native cell identity changes mark only the containing Visual Sector dirty.
2. Batched edits coalesce many pixel changes into one sector revision bump.
3. Godot queries `(sector_x, sector_y, revision)` triples.
4. Native generates only the dirty 64x64 RGBA payload.
5. A 64x64 RenderingDevice staging texture is updated, then copied into the matching region of one 512x512 destination texture.
6. The sector revision is acknowledged only after the copy command succeeds.
7. Initial activation and heavy dirty coverage keep a full-repaint fallback.

The destination is exposed to Sprite2D through `Texture2DRD`, so each chunk still renders with one texture and one Sprite2D.

Current conservative threshold: 24 dirty sectors trigger a full 512x512 repaint instead of many region copies. This value should be profiled on target PC and mobile GPUs.

Known follow-up: visual-only animation policies (materials whose color changes with time while element identity remains stable) should eventually be tracked independently from structural dirty sectors.
