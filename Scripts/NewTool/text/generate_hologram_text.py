from __future__ import annotations

import json
from pathlib import Path

from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

TEXT_ROOT = Path(__file__).resolve().parent
FONT_PATH = TEXT_ROOT / "fonts" / "DepartureMono-Regular.otf"
GENERATED = TEXT_ROOT / "generated"

FONT_SIZE = 11
FALLBACK_CHAR = "?"


def code_key(ch: str) -> str:
    return f"{ord(ch):04X}"


def load_supported_codepoints(font_path: Path) -> set[int]:
    font = TTFont(str(font_path))
    supported: set[int] = set()
    for table in font["cmap"].tables:
        supported.update(table.cmap.keys())
    return supported


def rasterize_glyphs(chars: list[str]) -> tuple[dict, int, int]:
    font = ImageFont.truetype(str(FONT_PATH), FONT_SIZE)
    ascent, descent = font.getmetrics()
    cell_width = int(round(font.getlength("M")))
    cell_height = ascent + descent

    glyphs = {}
    for ch in chars:
        image = Image.new("1", (cell_width, cell_height), 0)
        draw = ImageDraw.Draw(image)
        draw.fontmode = "1"
        draw.text((0, 0), ch, font=font, fill=1)

        rows: list[str] = []
        for y in range(cell_height):
            rows.append("".join("1" if image.getpixel((x, y)) else "0" for x in range(cell_width)))

        glyphs[code_key(ch)] = {
            "char": ch,
            "rows": rows,
        }

    return glyphs, cell_width, cell_height


def main() -> None:
    GENERATED.mkdir(parents=True, exist_ok=True)

    supported = load_supported_codepoints(FONT_PATH)
    if ord(FALLBACK_CHAR) not in supported:
        raise SystemExit(f"Departure Mono does not contain the fallback glyph {FALLBACK_CHAR!r}")

    chars = [chr(codepoint) for codepoint in sorted(supported)]
    glyphs, cell_width, cell_height = rasterize_glyphs(chars)
    glyph_payload = {
        "font": "Departure Mono",
        "font_file": "$CONTENT_DATA/Scripts/NewTool/text/fonts/DepartureMono-Regular.otf",
        "font_size": FONT_SIZE,
        "cell_width": cell_width,
        "cell_height": cell_height,
        "fallback": code_key(FALLBACK_CHAR),
        "glyphs": glyphs,
    }
    output_path = GENERATED / "glyph_pool.json"
    output_path.write_text(json.dumps(glyph_payload, ensure_ascii=False), encoding="utf-8")

    print(f"Wrote {len(glyphs)} glyphs to {output_path}")
    print(f"Cell: {cell_width}x{cell_height}")


if __name__ == "__main__":
    main()
