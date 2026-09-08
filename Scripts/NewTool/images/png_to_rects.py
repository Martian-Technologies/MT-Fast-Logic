from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import numpy as np
from PIL import Image, ImageDraw


@dataclass
class Rect:
    x: int
    y: int
    w: int
    h: int
    color: int
    gain: int = 0
    area: int = 0


def color_to_rgb(c: int) -> list[int]:
    return [(c >> 16) & 255, (c >> 8) & 255, c & 255]


def color_to_hex(c: int) -> str:
    r, g, b = color_to_rgb(c)
    return f"#{r:02x}{g:02x}{b:02x}"


def load_png_target(path: str, partial_alpha: str):
    """
    Returns:
      target: int64 HxW array of RGB-packed colors. Transparent pixels are -1.
      opaque: bool HxW mask. Rectangles may only cover True pixels.
      normalized_rgba: uint8 HxWx4 exact target after applying alpha policy.
      width, height
    """
    img = Image.open(path).convert("RGBA")
    arr = np.array(img, dtype=np.uint8)
    h, w = arr.shape[:2]

    alpha = arr[:, :, 3].copy()
    partial = (alpha > 0) & (alpha < 255)

    if partial.any():
        n = int(partial.sum())
        if partial_alpha == "error":
            raise SystemExit(
                f"Found {n} semi-transparent pixels. Opaque rectangles cannot "
                f"reproduce partial alpha exactly. Use "
                f"--partial-alpha transparent or --partial-alpha opaque to threshold them."
            )
        elif partial_alpha == "transparent":
            alpha[partial] = 0
        elif partial_alpha == "opaque":
            alpha[partial] = 255
        else:
            raise ValueError(partial_alpha)

    opaque = alpha == 255

    rgb = arr[:, :, :3].astype(np.int64)
    target = (rgb[:, :, 0] << 16) | (rgb[:, :, 1] << 8) | rgb[:, :, 2]
    target = target.astype(np.int64)
    target[~opaque] = -1

    normalized = np.zeros((h, w, 4), dtype=np.uint8)
    normalized[opaque, :3] = arr[opaque, :3]
    normalized[opaque, 3] = 255

    return target, opaque, normalized, w, h


def best_sum_rect(valid: np.ndarray, weight: np.ndarray):
    """
    Finds the valid axis-aligned rectangle with maximum total weight.

    valid[y, x] == False means the rectangle may not include that pixel.
    weight may contain positive, zero, or negative values.

    Returns (x, y, w, h, gain, area), or None if no positive-gain rect exists.

    Complexity: O(min(H, W)^2 * max(H, W)).
    """
    h, w = valid.shape

    # Scan the smaller dimension quadratically.
    if h > w:
        result = best_sum_rect(valid.T, weight.T)
        if result is None:
            return None

        tx, ty, tw, th, gain, area = result

        # Map transposed coordinates back.
        # In transpose: row = original x, col = original y.
        x = ty
        y = tx
        rw = th
        rh = tw
        return x, y, rw, rh, gain, area

    best = None
    best_gain = 0
    best_area = 0

    for top in range(h):
        good_cols = np.ones(w, dtype=bool)
        colsum = np.zeros(w, dtype=np.int32)

        for bottom in range(top, h):
            good_cols &= valid[bottom]
            colsum += weight[bottom]

            if not good_cols.any():
                continue

            cur_sum = 0
            cur_start = 0
            height = bottom - top + 1

            for x in range(w):
                if not good_cols[x]:
                    cur_sum = 0
                    cur_start = x + 1
                    continue

                v = int(colsum[x])

                # Kadane, but keep zero-prefixes because larger same-gain
                # rectangles are often useful for background layers.
                if cur_sum < 0:
                    cur_sum = v
                    cur_start = x
                else:
                    cur_sum += v

                if cur_sum > 0:
                    width = x - cur_start + 1
                    area = width * height

                    if cur_sum > best_gain or (
                        cur_sum == best_gain and area > best_area
                    ):
                        best_gain = cur_sum
                        best_area = area
                        best = (cur_start, top, width, height, best_gain, best_area)

    return best


def mismatch_row_runs(target: np.ndarray, mismatch: np.ndarray) -> list[Rect]:
    """
    Safe fallback: emits horizontal runs of currently mismatched pixels.
    These never cover transparent pixels or already-correct pixels.
    """
    h, w = target.shape
    rects: list[Rect] = []

    for y in range(h):
        x = 0
        while x < w:
            if not mismatch[y, x]:
                x += 1
                continue

            c = int(target[y, x])
            x0 = x
            x += 1

            while x < w and mismatch[y, x] and int(target[y, x]) == c:
                x += 1

            rects.append(Rect(x=x0, y=y, w=x - x0, h=1, color=c, gain=x - x0, area=x - x0))

    return rects


def make_rectangles(
    target: np.ndarray,
    opaque: np.ndarray,
    *,
    max_colors_per_pass: int = 32,
    min_gain: int = 2,
    progress: bool = False,
) -> tuple[list[Rect], np.ndarray]:
    """
    Greedy bottom-to-top painter.

    The canvas starts transparent. Each rectangle is opaque RGB and may only
    cover pixels where opaque == True.

    At each pass, for several candidate colors, it finds the rectangle with the
    best net improvement:
      +1 for each currently-wrong pixel fixed by this color
      -1 for each currently-correct pixel broken by this color
       0 for no change in correctness

    If no good rectangle remains, it falls back to row runs.
    """
    h, w = target.shape
    canvas = np.full((h, w), -1, dtype=np.int64)

    rects: list[Rect] = []
    step = 0

    while True:
        mismatch = opaque & (canvas != target)
        remaining = int(mismatch.sum())

        if remaining == 0:
            break

        ids, counts = np.unique(target[mismatch], return_counts=True)
        order = np.argsort(counts)[::-1]

        if max_colors_per_pass > 0:
            order = order[:max_colors_per_pass]

        matched = opaque & (canvas == target)

        best: Optional[Rect] = None

        for cid_raw in ids[order]:
            cid = int(cid_raw)

            target_is_c = target == cid

            weight = np.zeros((h, w), dtype=np.int16)

            # Painting color cid fixes these pixels.
            weight[opaque & target_is_c & (canvas != cid)] = 1

            # Painting color cid breaks these pixels.
            weight[opaque & (~target_is_c) & matched] = -1

            result = best_sum_rect(opaque, weight)
            if result is None:
                continue

            x, y, rw, rh, gain, area = result
            if gain <= 0:
                continue

            candidate = Rect(x=x, y=y, w=rw, h=rh, color=cid, gain=gain, area=area)

            if best is None or (candidate.gain, candidate.area) > (best.gain, best.area):
                best = candidate

        if best is None or best.gain < min_gain:
            fallback = mismatch_row_runs(target, mismatch)
            for r in fallback:
                canvas[r.y : r.y + r.h, r.x : r.x + r.w] = r.color
            rects.extend(fallback)

            if progress:
                print(
                    f"fallback: added {len(fallback)} row-run rectangles",
                    file=sys.stderr,
                )

            break

        # Safety check: no rectangle is allowed to cover transparent pixels.
        if not opaque[best.y : best.y + best.h, best.x : best.x + best.w].all():
            raise AssertionError("Internal error: rectangle crossed transparent pixels")

        rects.append(best)
        canvas[best.y : best.y + best.h, best.x : best.x + best.w] = best.color

        step += 1
        if progress and step % 10 == 0:
            now_remaining = int((opaque & (canvas != target)).sum())
            print(
                f"step {step}: rectangles={len(rects)}, remaining mismatches={now_remaining}",
                file=sys.stderr,
            )

    return rects, canvas


def render_rectangles(width: int, height: int, rects: list[Rect]) -> Image.Image:
    """
    Renders the rectangle list onto a transparent canvas.
    Rectangles are drawn in list order: bottom to top.
    """

    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(out, "RGBA")

    for i, r in enumerate(rects):
        rr, gg, bb = color_to_rgb(r.color)
        draw.rectangle(
            [r.x, r.y, r.x + r.w - 1, r.y + r.h - 1],
            fill=(rr, gg, bb, 255),
        )

    return out


def conflicts(a: Rect, b: Rect) -> bool:
    """
    True if a and b cannot be placed on the same z layer.

    Same-color overlaps are allowed because opaque same-color painting is
    visually/order-equivalent.
    """
    geometrically_overlap = not (
        a.x + a.w <= b.x or
        b.x + b.w <= a.x or
        a.y + a.h <= b.y or
        b.y + b.h <= a.y
    )

    return geometrically_overlap and a.color != b.color


def assign_layers(rects: list[Rect]) -> tuple[list[int], int]:
    """
    Assign compact z-layers for this fixed bottom-to-top draw order.

    Rectangles may share a z layer if they do not geometrically overlap,
    or if they overlap but have the same opaque RGB color.
    """
    layers: list[int] = []

    for i, r in enumerate(rects):
        z = 0

        for j in range(i):
            if conflicts(rects[j], r):
                z = max(z, layers[j] + 1)

        layers.append(z)

    return layers, max(layers, default=-1) + 1


def rects_to_json(width: int, height: int, rects: list[Rect]) -> dict:
    layers, layer_count = assign_layers(rects)

    color_palette = list({r.color for r in rects})

    return {
        "width": width,
        "height": height,
        "layer_count": layer_count,
        "color_palette": [color_to_rgb(c) for c in color_palette],
        "rectangles": [
            {
                "z": layers[i],
                "x": r.x,
                "y": r.y,
                "w": r.w,
                "h": r.h,
                "c": color_palette.index(r.color),
            }
            for i, r in enumerate(rects)
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert a PNG into an opaque rectangle draw list."
    )
    parser.add_argument("input", help="Input PNG")
    parser.add_argument("-o", "--output", default="rectangles.json", help="Output JSON path")
    parser.add_argument(
        "--preview",
        default=None,
        help="Optional output PNG reconstructed from the rectangles",
    )
    parser.add_argument(
        "--partial-alpha",
        choices=["error", "transparent", "opaque"],
        default="error",
        help=(
            "How to handle semi-transparent pixels. Default: error. "
            "'transparent' treats them as off-limits; 'opaque' treats them as fully opaque."
        ),
    )
    parser.add_argument(
        "--max-colors-per-pass",
        type=int,
        default=32,
        help=(
            "Candidate colors considered each greedy pass. "
            "Use 0 to consider all remaining colors, which is slower."
        ),
    )
    parser.add_argument(
        "--min-gain",
        type=int,
        default=2,
        help=(
            "Minimum net improvement for a greedy rectangle. "
            "If lower, the script switches to safe row-run fallback."
        ),
    )
    parser.add_argument("--progress", action="store_true", help="Print progress to stderr")
    args = parser.parse_args()

    target, opaque, normalized, width, height = load_png_target(
        args.input,
        args.partial_alpha,
    )

    rects, canvas = make_rectangles(
        target,
        opaque,
        max_colors_per_pass=args.max_colors_per_pass,
        min_gain=max(1, args.min_gain),
        progress=args.progress,
    )

    # Verify opaque pixels exactly match.
    if not np.array_equal(canvas[opaque], target[opaque]):
        raise SystemExit("Verification failed: opaque pixels do not match target")

    payload = rects_to_json(width, height, rects)

    output_path = Path(args.output)
    output_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    if args.preview:
        preview = render_rectangles(width, height, rects)

        # Verify full RGBA image if preview is generated.
        preview_arr = np.array(preview, dtype=np.uint8)
        if not np.array_equal(preview_arr, normalized):
            raise SystemExit("Verification failed: rendered PNG does not match normalized target")

        preview.save(args.preview)

    layers, layer_count = assign_layers(rects)

    print(f"Wrote {len(rects)} rectangles to {output_path}")
    print(f"Layer count (minimum for this draw order): {layer_count}")
    print(f"Opaque pixels: {int(opaque.sum())}")
    print(f"Transparent pixels left untouched: {int((~opaque).sum())}")


if __name__ == "__main__":
    main()