#!/usr/bin/env python3
"""Generate Godot 4 SpriteFrames resources from Noita-style RectAnimation XML.

Usage:
    python3 tools/generate_sprite_frames.py

The generated .tres files are committed to the project, so the game does not
need Python or XML parsing at runtime.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import xml.etree.ElementTree as ET

PROJECT_ROOT = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class Animation:
    name: str
    pos_x: int
    pos_y: int
    frame_count: int
    frame_width: int
    frame_height: int
    frames_per_row: int
    frame_wait: float
    loop: bool


def parse_animations(xml_path: Path) -> list[Animation]:
    root = ET.parse(xml_path).getroot()
    animations: list[Animation] = []
    for element in root.findall("RectAnimation"):
        a = element.attrib
        animations.append(
            Animation(
                name=a["name"],
                pos_x=int(a.get("pos_x", "0")),
                pos_y=int(a.get("pos_y", "0")),
                frame_count=int(a["frame_count"]),
                frame_width=int(a["frame_width"]),
                frame_height=int(a["frame_height"]),
                frames_per_row=max(1, int(a.get("frames_per_row", a["frame_count"]))),
                frame_wait=max(0.000001, float(a.get("frame_wait", "0.1"))),
                loop=a.get("loop", "1") != "0",
            )
        )
    return animations


def godot_float(value: float) -> str:
    text = f"{value:.9f}".rstrip("0").rstrip(".")
    return text if "." in text else f"{text}.0"


def write_sprite_frames(
    xml_relative: str,
    texture_resource_path: str,
    output_relative: str,
) -> tuple[int, int]:
    xml_path = PROJECT_ROOT / xml_relative
    output_path = PROJECT_ROOT / output_relative
    animations = parse_animations(xml_path)

    subresources: list[str] = []
    animation_blocks: list[str] = []
    resource_index = 0

    for animation in animations:
        frame_entries: list[str] = []
        for frame_index in range(animation.frame_count):
            resource_index += 1
            sub_id = f"AtlasTexture_{resource_index:03d}_{animation.name}"
            column = frame_index % animation.frames_per_row
            row = frame_index // animation.frames_per_row
            x = animation.pos_x + column * animation.frame_width
            y = animation.pos_y + row * animation.frame_height
            subresources.append(
                "\n".join(
                    [
                        f'[sub_resource type="AtlasTexture" id="{sub_id}"]',
                        'atlas = ExtResource("1_texture")',
                        (
                            "region = Rect2("
                            f"{x}, {y}, {animation.frame_width}, {animation.frame_height}"
                            ")"
                        ),
                    ]
                )
            )
            frame_entries.append(
                "{\n"
                '"duration": 1.0,\n'
                f'"texture": SubResource("{sub_id}")\n'
                "}"
            )

        speed = 1.0 / animation.frame_wait
        animation_blocks.append(
            "{\n"
            f'"frames": [{", ".join(frame_entries)}],\n'
            f'"loop": {str(animation.loop).lower()},\n'
            f'"name": &"{animation.name}",\n'
            f'"speed": {godot_float(speed)}\n'
            "}"
        )

    load_steps = resource_index + 2
    content = [
        f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3]',
        "",
        f'[ext_resource type="Texture2D" path="{texture_resource_path}" id="1_texture"]',
        "",
        "\n\n".join(subresources),
        "",
        "[resource]",
        f'animations = [{", ".join(animation_blocks)}]',
        "",
    ]
    output_path.write_text("\n".join(content), encoding="utf-8")
    return len(animations), resource_index


def main() -> None:
    body_animations, body_frames = write_sprite_frames(
        "assets/player/player.xml",
        "res://assets/player/player.png",
        "assets/player/player_sprite_frames.tres",
    )
    arm_animations, arm_frames = write_sprite_frames(
        "assets/player/player_arm.xml",
        "res://assets/player/player_arm.png",
        "assets/player/player_arm_sprite_frames.tres",
    )
    print(
        "Generated "
        f"{body_animations} body animations / {body_frames} frames and "
        f"{arm_animations} arm animations / {arm_frames} frames."
    )


if __name__ == "__main__":
    main()
