from __future__ import annotations

import json
import re
import string
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFont
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[3]
TEXT_ROOT = ROOT / "Scripts" / "NewTool" / "text"
FONT_PATH = TEXT_ROOT / "fonts" / "DepartureMono-Regular.otf"
GENERATED = TEXT_ROOT / "generated"
LOCALIZATION_PATH = ROOT / "Scripts" / "util" / "Localization.json"
NEWTOOL_LUA_PATHS = [
    ROOT / "Scripts" / "NewTool" / "ActionRegistry.lua",
    ROOT / "Scripts" / "NewTool" / "MenuManifest.lua",
]

FONT_SIZE = 11
FALLBACK_CHAR = "?"
DEFAULT_LAYOUTS = {
    "hub_label": {"max_columns": 18, "max_lines": 1, "align": "center"},
    "hub_preview_title": {"max_columns": 56, "max_lines": 1, "align": "left"},
    "hub_preview_description": {"max_columns": 56, "max_lines": 3, "align": "left"},
}


def code_key(ch: str) -> str:
    return f"{ord(ch):04X}"


def load_supported_codepoints(font_path: Path) -> set[int]:
    font = TTFont(str(font_path))
    supported: set[int] = set()
    for table in font["cmap"].tables:
        supported.update(table.cmap.keys())
    return supported


def unescape_lua_string(value: str) -> str:
    # The current NewTool strings are plain ASCII, but handle common escapes so
    # this scanner remains useful when labels/descriptions evolve.
    return bytes(value, "utf-8").decode("unicode_escape")


def collect_newtool_phrases() -> set[str]:
    phrases: set[str] = set()
    label_desc_re = re.compile(r"(?:label|description)\s*=\s*\"((?:\\.|[^\"])*)\"")
    call_re = re.compile(
        r"(?:dummyTool|command)\(\s*\"(?:\\.|[^\"])*\"\s*,\s*"
        r"\"((?:\\.|[^\"])*)\"\s*,\s*\"((?:\\.|[^\"])*)\""
    )

    for path in NEWTOOL_LUA_PATHS:
        text = path.read_text(encoding="utf-8")
        for match in label_desc_re.finditer(text):
            phrases.add(unescape_lua_string(match.group(1)))
        for match in call_re.finditer(text):
            phrases.add(unescape_lua_string(match.group(1)))
            phrases.add(unescape_lua_string(match.group(2)))

    return {phrase for phrase in phrases if phrase}


def collect_localization_phrases() -> set[str]:
    if not LOCALIZATION_PATH.exists():
        return set()

    data = json.loads(LOCALIZATION_PATH.read_text(encoding="utf-8"))
    phrases: set[str] = set()
    for entry in data.values():
        if isinstance(entry, dict):
            for value in entry.values():
                if isinstance(value, str) and value:
                    phrases.add(value)
    return phrases


def collect_phrases() -> set[str]:
    return collect_newtool_phrases() | collect_localization_phrases()


def collect_chars(phrases: Iterable[str]) -> list[str]:
    chars = set(string.printable[:-5])  # printable ASCII without whitespace controls
    chars.add(" ")
    chars.add(FALLBACK_CHAR)
    for phrase in phrases:
        chars.update(ch for ch in phrase if ch not in "\r\n\t")
    return sorted(chars, key=ord)


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


def text_len(text: str) -> int:
    return len(text)


def split_word(word: str, max_columns: int) -> list[str]:
    if max_columns <= 0:
        return [word]
    return [word[i : i + max_columns] for i in range(0, len(word), max_columns)] or [""]


def wrap_text(text: str, max_columns: int, max_lines: int) -> list[str]:
    if max_columns <= 0:
        return []

    lines: list[str] = []
    paragraphs = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")

    for paragraph in paragraphs:
        words = paragraph.split()
        if not words:
            lines.append("")
            if len(lines) >= max_lines:
                return lines[:max_lines]
            continue

        current = ""
        for word in words:
            word_parts = split_word(word, max_columns) if text_len(word) > max_columns else [word]
            for part in word_parts:
                if current == "":
                    current = part
                elif text_len(current) + 1 + text_len(part) <= max_columns:
                    current += " " + part
                else:
                    lines.append(current)
                    if len(lines) >= max_lines:
                        return lines[:max_lines]
                    current = part
        if current != "":
            lines.append(current)
            if len(lines) >= max_lines:
                return lines[:max_lines]

    return lines[:max_lines]


def horizontal_runs(bits: list[list[bool]]) -> list[list[int]]:
    rects: list[list[int]] = []
    active: dict[tuple[int, int], list[int]] = {}

    for y, row in enumerate(bits):
        current_active: dict[tuple[int, int], list[int]] = {}
        x = 0
        while x < len(row):
            if not row[x]:
                x += 1
                continue
            start = x
            while x < len(row) and row[x]:
                x += 1
            width = x - start
            key = (start, width)
            prev = active.get(key)
            if prev is not None and prev[1] + prev[3] == y:
                prev[3] += 1
                current_active[key] = prev
            else:
                rect = [start, y, width, 1]
                rects.append(rect)
                current_active[key] = rect
        active = current_active

    return rects


def compile_text_payload(text: str, layout: dict, glyphs: dict, cell_width: int, cell_height: int) -> dict:
    max_columns = int(layout["max_columns"])
    max_lines = int(layout["max_lines"])
    align = layout.get("align", "left")
    lines = wrap_text(text, max_columns, max_lines)

    width = max_columns * cell_width
    height = max(max_lines, 1) * cell_height
    bits = [[False for _ in range(width)] for _ in range(height)]

    for line_index, line in enumerate(lines):
        line_len = min(len(line), max_columns)
        if align == "center":
            cell_offset = max((max_columns - line_len) // 2, 0)
        elif align == "right":
            cell_offset = max(max_columns - line_len, 0)
        else:
            cell_offset = 0

        for char_index, ch in enumerate(line[:max_columns]):
            glyph = glyphs.get(code_key(ch)) or glyphs[code_key(FALLBACK_CHAR)]
            x0 = (cell_offset + char_index) * cell_width
            y0 = line_index * cell_height
            for gy, row in enumerate(glyph["rows"]):
                for gx, value in enumerate(row):
                    if value == "1":
                        bits[y0 + gy][x0 + gx] = True

    return {
        "w": width,
        "h": height,
        "r": horizontal_runs(bits),
    }


def main() -> None:
    GENERATED.mkdir(parents=True, exist_ok=True)

    phrases = collect_phrases()
    chars = collect_chars(phrases)
    supported = load_supported_codepoints(FONT_PATH)
    missing = sorted(ch for ch in chars if ord(ch) not in supported)
    if missing:
        raise SystemExit("Departure Mono missing required glyphs: " + " ".join(repr(ch) for ch in missing))

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
    (GENERATED / "glyph_pool.json").write_text(json.dumps(glyph_payload, ensure_ascii=False, indent=2), encoding="utf-8")

    entries = []
    for layout_id, layout in DEFAULT_LAYOUTS.items():
        for phrase in sorted(phrases):
            entries.append({
                "layout": layout_id,
                "text": phrase,
                "rects": compile_text_payload(phrase, layout, glyphs, cell_width, cell_height),
            })

    layouts = {}
    for layout_id, layout in DEFAULT_LAYOUTS.items():
        layouts[layout_id] = dict(layout)
        layouts[layout_id]["width"] = int(layout["max_columns"]) * cell_width
        layouts[layout_id]["height"] = int(layout["max_lines"]) * cell_height

    phrase_payload = {
        "font": "Departure Mono",
        "layouts": layouts,
        "entries": entries,
    }
    (GENERATED / "phrase_cache.json").write_text(
        json.dumps(phrase_payload, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )

    print(f"Wrote {len(glyphs)} glyphs to {GENERATED / 'glyph_pool.json'}")
    print(f"Wrote {len(entries)} phrase/layout entries to {GENERATED / 'phrase_cache.json'}")
    print(f"Cell: {cell_width}x{cell_height}; phrases: {len(phrases)}")


if __name__ == "__main__":
    main()
