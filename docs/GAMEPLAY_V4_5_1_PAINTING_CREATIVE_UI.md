# Gameplay V4.5.1 — Painting Creative UI

Creative Mode now uses the project Painting module as its visual UI foundation instead of the Noita-style gameplay chrome.

## Visual foundation

- CreativeUI root uses `res://painting/ui/_theme/theme.tres` directly.
- Poppins, Painting Button/CheckButton/ScrollBar/Tab styling and palette are inherited from the Painting theme.
- The bottom dock uses the Painting module's gray-violet panel surface and spacing language.
- Active tabs, tools and selected materials use the Painting orange selection family.
- Brush / Erase / Pick reuse the Painting module's existing `tap.png`, `eraser.png`, and `edit.png` icons.
- Search fields and Wand stat editors use Painting-style gray-violet input surfaces.

## Spell and Wand editing

Normal gameplay still uses the Noita-like UI. `SpellSlot` now supports an optional Painting visual profile used only by Creative Mode. Creative spell library tiles and Creative Wand Deck slots use 48×48 Painting-style cards with 4px corners, bottom-depth shading, orange selection and blue valid-drop feedback.

## Performance

The change is visual only. It does not alter Creative brush batching, Native falling-sand painting, Wand runtime mutation, spell catalog caching, or gameplay simulation. The Painting Theme is preloaded once, UI is still event-driven, and no per-frame theme rebuilding or resource scanning was added.
