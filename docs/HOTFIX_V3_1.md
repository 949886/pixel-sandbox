# V3.1 GDScript Parse Hotfix

修复 `scripts/pixel_world/PixelChunkCanvas.gd` 中静态预览纹理尺寸判断的类型错误。

Godot 4.7 中：

- `ImageTexture.get_size()` 返回 `Vector2`
- `Image.get_size()` 返回 `Vector2i`

V3 原代码直接用 `==` 比较两者，导致脚本无法解析，并连带使 `PieceChunkRenderer.gd` 与 `WorldManager.gd` 编译失败。

V3.1 改为分别使用 `get_width()` 和 `get_height()` 比较整数尺寸，不改变运行逻辑与性能优化行为。
