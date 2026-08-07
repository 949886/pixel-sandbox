#!/usr/bin/env python3
"""Reference-model test for exact 1px collision rectangle merging and sector dirties."""
from __future__ import annotations
import random

SIZE = 64


def merge(mask: list[list[bool]]) -> list[tuple[int, int, int, int]]:
    used = [[False] * SIZE for _ in range(SIZE)]
    rects: list[tuple[int, int, int, int]] = []
    for y in range(SIZE):
        for x in range(SIZE):
            if not mask[y][x] or used[y][x]:
                continue
            width = 1
            while x + width < SIZE and mask[y][x + width] and not used[y][x + width]:
                width += 1
            height = 1
            while y + height < SIZE:
                if any(not mask[y + height][x + xx] or used[y + height][x + xx] for xx in range(width)):
                    break
                height += 1
            for yy in range(height):
                for xx in range(width):
                    used[y + yy][x + xx] = True
            rects.append((x, y, width, height))
    return rects


def validate(mask: list[list[bool]], rects: list[tuple[int, int, int, int]]) -> None:
    coverage = [[0] * SIZE for _ in range(SIZE)]
    for x, y, width, height in rects:
        for yy in range(y, y + height):
            for xx in range(x, x + width):
                coverage[yy][xx] += 1
    for y in range(SIZE):
        for x in range(SIZE):
            assert coverage[y][x] <= 1, (x, y, "overlap")
            assert bool(coverage[y][x]) == mask[y][x], (x, y, "coverage mismatch")


def sectors_for_circle(cx: float, cy: float, radius: float) -> set[tuple[int, int]]:
    dirty: set[tuple[int, int]] = set()
    for y in range(max(0, int(cy - radius)), min(127, int(cy + radius) + 1) + 1):
        for x in range(max(0, int(cx - radius)), min(127, int(cx + radius) + 1) + 1):
            dx = x + 0.5 - cx
            dy = y + 0.5 - cy
            if dx * dx + dy * dy <= radius * radius:
                dirty.add((x // SIZE, y // SIZE))
    return dirty


def main() -> None:
    random.seed(0xC0111510)
    for _ in range(200):
        mask = [[random.random() < 0.35 for _ in range(SIZE)] for _ in range(SIZE)]
        validate(mask, merge(mask))
    expected = {(0, 0), (1, 0), (0, 1), (1, 1)}
    assert sectors_for_circle(64.0, 64.0, 3.0) == expected
    print("collision sector model: PASS (200 random masks + four-sector boundary circle)")


if __name__ == "__main__":
    main()
