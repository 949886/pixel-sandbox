# Surface Opening Authoring

The opening is a continuous Pixel World, not a separate level scene. Its macro placement lives in
`DefaultWorldLayout.tscn`; its exact terrain lives in palette-colored material-layout PNGs referenced by
`SpecialChunkDef` resources.

## Data flow

```text
WorldDefinition
  -> WorldLayout
       -> BiomeLayer (Surface/Mine ownership)
       -> ChunkLayer (fixed Surface SpecialChunks)
       -> WorldAnchor (spawn/entrance/path semantics)
  -> WorldPresentationProfile
       -> WorldBackdrop
```

At runtime, fixed SpecialChunks reserve their complete footprint before random SpecialChunks and Piece generation.
The planner extracts the referenced Texture2D on the main thread and stores an RGBA8 Image on the placement; the
special-chunk worker only receives that Image.

## Default fixed sequence

| Chunk origin | Definition | Image size | Purpose |
|---|---|---:|---|
| `(-5,-1)` | `surface_left_boundary_chunk` | 512×512 | Classic far-west ground |
| `(-4,-1)` | `surface_ground_chunk` | 512×512 | West ground |
| `(-3,-1)` | `surface_grove_chunk` | 512×512 | Classic mid-west ground (legacy ID, no trees) |
| `(-2,-1)` | `surface_approach_chunk` | 512×512 | Classic mid-east ground |
| `(-1,-1)` | `surface_spawn_chunk` | 512×512 | Safe player spawn |
| `(0,-1)` | `surface_east_ground_chunk` | 512×512 | Entrance approach |
| `(1,-1)` | `surface_entrance_chunk` | 512×1024 | Classic right/down slope and vertical mine connection |

The last resource occupies two cells. Its bottom material opening and socket profile must both target slot 2 as
`OPEN_LARGE`.

## Default visual profile

The default Surface intentionally follows the earlier tool-mode prototype profile:

- one globally sampled low-amplitude sine surface across all seven fixed chunks;
- no trees, wooden supports, gold decoration, or authored landmark props;
- a broad classic right/down entrance cut followed by a vertical shaft;
- current material semantics rather than the old dynamic `organic` grass material.

The PNGs remain the runtime truth source. The matching `surface_ground_ratio = 0.62`,
`surface_height_variation = 0.045`, and generated fallback colors are kept on each `SpecialChunkDef` so the
resource metadata and emergency procedural fallback describe the same profile.

## Painting rules

- Preserve exact image dimensions; nearest-neighbor scaling is not an authoring operation.
- Alpha zero means air.
- Opaque pixels must use exact `MaterialPalette` colors.
- Broad decorative grass/foliage on authored Surface chunks must use `surface_foliage` (`RGB 46,92,42`, element `2058`). It is an inert, non-colliding, flammable visual material.
- Reserve `organic` (`RGB 53,57,35`, native element `14`) for places where autonomous growth is intentional. Do not paint thousands of `organic` pixels merely to obtain a grass color.
- Import authored material images losslessly, without mipmaps or resize limits; filtering affects only preview rendering and must never be used to resample source pixels.
- Keep cross-chunk surface seams continuous with the shared classic world-X height profile.
- Keep the spawn collider envelope clear above the surface.
- Keep the entrance shaft open all the way to the bottom edge.
- The default entrance contains no support beams; any later decoration must preserve at least a 13×21 pixel air envelope along the player route.
- Save critical chunks with `require_material_layout = true`.

## Verification

1. Open the World Layout dock and choose **Open World Layout**.
2. Confirm all seven Surface previews form one continuous strip.
3. Validate the layout.
4. Run `tests/WorldLayoutSmokeTest.tscn`.
5. Start a normal run and confirm the player remains disabled until the spawn collision is ready.
6. Walk right into the classic slope without firing or digging; the diagonal passage must remain directly traversable.
7. Confirm the first procedural Mine chunk connects without a solid seam.
