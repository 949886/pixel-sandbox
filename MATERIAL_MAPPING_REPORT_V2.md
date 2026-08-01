# noita(15) 材质映射检查报告

## 资产范围

检查了：

```text
res://resources/pieces/textures/*.png
res://resources/generated_pieces/textures/*.png
```

共 60 张 piece 纹理、1,920,024 个像素、33 种不同 RGBA 颜色。

`default_material_palette.tres` 的精确颜色及别名可以覆盖全部 33 种颜色，未发现必须依赖最近色回退的打包纹理颜色。

## 映射后的源像素分布

| MaterialPalette 条目 | 源像素数 | sand-slide ID | 行为 |
|---|---:|---:|---|
| air | 1,254,124 | 0 | 空气/透明 |
| rock | 147,735 | 2048 | 自定义静态岩石 |
| metal | 134,318 | 17 | iron |
| snow_rock | 122,138 | 2050 | 自定义静态雪岩 |
| deep_rock | 100,861 | 2051 | 自定义静态深层岩石 |
| oil | 88,800 | 30 | 液体、可燃 |
| wood | 27,621 | 18 | 木材、可燃 |
| mine_dark_rock | 13,533 | 2049 | 自定义静态暗岩 |
| snow_dark_rock | 12,225 | 2053 | 自定义静态暗雪岩 |
| deep_dark_rock | 9,867 | 2054 | 自定义静态暗深岩 |
| crystal | 3,360 | 27 | 晶体 |
| lava | 3,168 | 20 | 熔岩液体 |
| organic | 1,833 | 14 | 草/有机物 |
| water | 397 | 3 | 水 |
| blood | 43 | 118 | 血液 |
| gold_decor | 1 | 2056 | 自定义静态装饰金 |

特殊结构生成器还会产生 ruins、treasure、shrine 等程序化颜色，这些颜色也已作为精确别名加入调色板。

## 尺寸检查

57 个纹理与 `size_units × 128` 完全一致。以下 3 张上传纹理会由 `PieceDef.prepare_image_cache()` 使用最近邻自动归一化：

| 纹理 | 原尺寸 | 运行时目标尺寸 |
|---|---:|---:|
| `oiltank_1.png` | 130×260 | 128×256 |
| `symbolroom_alt.png` | 260×130 | 256×128 |
| `laboratory.png` | 260×130 | 256×128 |

因此它们不会破坏 128 像素 unit 或 512 像素 chunk 对齐，但制作后续素材时仍建议直接导出目标尺寸。

## 制作建议

- `texture` 可以保留阴影、抗锯齿和装饰细节。
- `material_texture` 应使用调色板精确纯色，不使用半透明边缘或色彩滤镜。
- 没有设置 `material_texture` 时，系统会回退读取 `texture`；本 demo 的现有纹理已全部覆盖，但生产资产最好显式提供材质图。
