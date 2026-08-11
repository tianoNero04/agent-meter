#!/usr/bin/env python3
"""Remove only the border-connected dark backdrop from a glass UI PNG.

The image's dark UI interiors are intentionally not treated as a color key.
Pixels are removed only when they are both background-like and connected to the
image border without crossing a visible UI edge. A small protected margin keeps
edge light, shadows and glow around the detected glass panels.

Requires Python 3 with Pillow and NumPy:
    python3 Scripts/extract-glass-ui-alpha.py input.png output.png
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


def border_connected(passable: np.ndarray) -> np.ndarray:
    """Return passable pixels connected to any image border (8-neighbor)."""
    try:
        from scipy import ndimage

        labels, _ = ndimage.label(passable, structure=np.ones((3, 3), dtype=np.uint8))
        border_labels = np.unique(
            np.concatenate((labels[0], labels[-1], labels[:, 0], labels[:, -1]))
        )
        border_labels = border_labels[border_labels != 0]
        return np.isin(labels, border_labels)
    except ImportError:
        # Pillow + NumPy are enough for users who do not have SciPy installed.
        height, width = passable.shape
        connected = np.zeros_like(passable, dtype=bool)
        queue: deque[tuple[int, int]] = deque()

        for x in range(width):
            for y in (0, height - 1):
                if passable[y, x] and not connected[y, x]:
                    connected[y, x] = True
                    queue.append((y, x))
        for y in range(height):
            for x in (0, width - 1):
                if passable[y, x] and not connected[y, x]:
                    connected[y, x] = True
                    queue.append((y, x))

        while queue:
            y, x = queue.popleft()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if not (dy or dx):
                        continue
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < height and 0 <= nx < width:
                        if passable[ny, nx] and not connected[ny, nx]:
                            connected[ny, nx] = True
                            queue.append((ny, nx))
        return connected


def dilate(mask: np.ndarray, radius: int) -> np.ndarray:
    if radius <= 0:
        return mask
    image = Image.fromarray(np.where(mask, 255, 0).astype(np.uint8), mode="L")
    size = radius * 2 + 1
    return np.asarray(image.filter(ImageFilter.MaxFilter(size)), dtype=np.uint8) > 0


def extract_alpha(
    rgba: np.ndarray,
    *,
    border_band: int,
    background_tolerance: float,
    max_luminance: float,
    edge_threshold: float,
    barrier_luminance: float,
    preserve_margin: int,
) -> tuple[np.ndarray, dict[str, float]]:
    rgb = rgba[:, :, :3].astype(np.float32)
    height, width = rgb.shape[:2]
    band = max(1, min(border_band, height // 2, width // 2))

    border_pixels = np.concatenate(
        (
            rgb[:band].reshape(-1, 3),
            rgb[-band:].reshape(-1, 3),
            rgb[:, :band].reshape(-1, 3),
            rgb[:, -band:].reshape(-1, 3),
        ),
        axis=0,
    )
    background_color = np.median(border_pixels, axis=0)
    luminance = np.dot(rgb, np.array([0.299, 0.587, 0.114], dtype=np.float32))
    color_distance = np.linalg.norm(rgb - background_color, axis=2)

    # Adjacent-pixel gradients form barriers at the bright glass boundary,
    # while the dark UI interior remains enclosed and therefore protected.
    dy, dx = np.gradient(luminance)
    edge_strength = np.abs(dx) + np.abs(dy)
    background_like = (color_distance <= background_tolerance) & (luminance <= max_luminance)
    visible_edge = (edge_strength >= edge_threshold) | (luminance >= barrier_luminance)
    passable = background_like & ~visible_edge
    outside = border_connected(passable)

    # Keep a halo around every detected edge so that soft shadows and glow are
    # not eaten by the background removal.
    protected = dilate(~passable, preserve_margin)
    transparent = outside & ~protected

    alpha = rgba[:, :, 3].copy()
    alpha[transparent] = 0
    stats = {
        "removed_fraction": float(transparent.mean()),
        "background_red": float(background_color[0]),
        "background_green": float(background_color[1]),
        "background_blue": float(background_color[2]),
    }
    return alpha, stats


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="source PNG")
    parser.add_argument("output", type=Path, help="destination PNG with alpha")
    parser.add_argument("--border-band", type=int, default=8)
    parser.add_argument("--background-tolerance", type=float, default=24.0)
    parser.add_argument("--max-luminance", type=float, default=60.0)
    parser.add_argument("--edge-threshold", type=float, default=8.0)
    parser.add_argument("--barrier-luminance", type=float, default=62.0)
    parser.add_argument("--preserve-margin", type=int, default=12)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    with Image.open(args.input) as source:
        rgba = np.asarray(source.convert("RGBA"), dtype=np.uint8).copy()

    alpha, stats = extract_alpha(
        rgba,
        border_band=args.border_band,
        background_tolerance=args.background_tolerance,
        max_luminance=args.max_luminance,
        edge_threshold=args.edge_threshold,
        barrier_luminance=args.barrier_luminance,
        preserve_margin=args.preserve_margin,
    )
    rgba[:, :, 3] = alpha
    args.output.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, mode="RGBA").save(args.output, format="PNG", optimize=True)
    print(
        f"saved {args.output} ({rgba.shape[1]}x{rgba.shape[0]} RGBA); "
        f"removed {stats['removed_fraction']:.1%} border-connected backdrop "
        f"(estimated border RGB {stats['background_red']:.1f}, "
        f"{stats['background_green']:.1f}, {stats['background_blue']:.1f})"
    )


if __name__ == "__main__":
    main()
