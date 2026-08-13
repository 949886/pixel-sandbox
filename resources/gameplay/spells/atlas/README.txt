Noita spell icon atlas for Godot

Files:
- noita_spell_icons_atlas.png: packed atlas image containing all 638 sprites
- noita_spell_icons_atlas.json: JSON manifest with regions
- noita_spell_icons_atlas.csv: CSV manifest with regions
- atlas_textures/*.tres: one Godot AtlasTexture resource per sprite (Godot 4 style)

Atlas layout:
- Sprite size: 16x16
- Padding: 1px transparent border around each sprite
- Columns: 32
- Rows: 20
- Atlas size: 576x360

Recommended install:
1. Copy the entire `atlas` folder into your Godot project root so it appears as `res://resources/gameplay/spells/atlas/`
2. The included `.tres` files will then work immediately
3. Use files in `res://resources/gameplay/spells/atlas/atlas_textures/` as textures anywhere AtlasTexture is accepted

Notes:
- The JSON/CSV manifest can also be used to build your own loading system
- The `.tres` files reference the atlas at `res://resources/gameplay/spells/atlas/noita_spell_icons_atlas.png`
