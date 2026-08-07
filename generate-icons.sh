#!/usr/bin/env bash
set -u
set -o pipefail

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
mod_dir=$script_dir
description="$mod_dir/description.json"

[[ -f "$description" ]] || fail "description.json was not found in $mod_dir"

steam_root=${STEAM_ROOT:-"$HOME/.local/share/Steam"}
compiler=${CONTENT_COMPILER:-"$steam_root/steamapps/common/Scrap Mechanic/Release/ContentCompiler.exe"}
appid=${PROTONTRICKS_APPID:-588870}

[[ -f "$compiler" ]] || fail "ContentCompiler.exe was not found at $compiler"

# The compiler skips block and part icons unless this flag is enabled.
python3 - "$description" <<'PY' || exit 1
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
raw = path.read_bytes()
has_bom = raw.startswith(b"\xef\xbb\xbf")
text = raw.decode("utf-8-sig")
pattern = re.compile(r'("custom_icons"\s*:\s*)(?:false|true)', re.IGNORECASE)
text, count = pattern.subn(r'\g<1>true', text, count=1)
if count != 1:
    raise SystemExit("Error: description.json has no custom_icons field")
path.write_bytes((b"\xef\xbb\xbf" if has_bom else b"") + text.encode("utf-8"))
PY

stamp=$(date +%Y%m%d-%H%M%S)
backup_dir="$mod_dir/IconMapsBackups/$stamp"
mkdir -p -- "$backup_dir"

had_png=0
had_xml=0
if [[ -f "$mod_dir/Gui/IconMap.png" ]]; then
    cp -p -- "$mod_dir/Gui/IconMap.png" "$backup_dir/IconMap.png"
    had_png=1
fi
if [[ -f "$mod_dir/Gui/IconMap.xml" ]]; then
    cp -p -- "$mod_dir/Gui/IconMap.xml" "$backup_dir/IconMap.xml"
    had_xml=1
fi

restore_icons() {
    rm -f -- "$mod_dir/Gui/IconMap.png" "$mod_dir/Gui/IconMap.xml"
    (( had_png )) && cp -p -- "$backup_dir/IconMap.png" "$mod_dir/Gui/IconMap.png"
    (( had_xml )) && cp -p -- "$backup_dir/IconMap.xml" "$mod_dir/Gui/IconMap.xml"
}

compat_data=${STEAM_COMPAT_DATA_PATH:-"$steam_root/steamapps/compatdata/$appid"}
drive_c=$(cd -- "$compat_data/pfx/drive_c" 2>/dev/null && pwd -P) || {
    restore_icons
    fail "the Proton C: drive was not found under $compat_data"
}

case "$mod_dir/" in
    "$drive_c/"*) windows_mod="C:${mod_dir#"$drive_c"}" ;;
    *)
        restore_icons
        fail "the mod is outside the Proton C: drive and cannot be passed to ContentCompiler"
        ;;
esac

printf 'Generating icons for:\n  %s\n' "$mod_dir"
printf 'ContentCompiler path:\n  %s\n' "$windows_mod"
printf 'Backup directory:\n  %s\n\n' "$backup_dir"

# Recent compiler versions only discover tools. Expose every shape as a
# temporary tool so the built-in renderer includes it in the atlas.
tooldb="$mod_dir/Tools/Database/toolsets.tooldb"
temp_toolset="$mod_dir/Tools/Database/ToolSets/pi-icon-generator.toolset"
temp_renderables="$mod_dir/Renderable/pi-icon-generator"
tooldb_backup="$backup_dir/toolsets.tooldb"
[[ -f "$tooldb" ]] || {
    restore_icons
    fail "Tools/Database/toolsets.tooldb was not found"
}
cp -p -- "$tooldb" "$tooldb_backup"

clear_icon_generator_cache() {
    rm -f -- "$mod_dir"/Cache/Data/toolsets_*.dco \
        "$mod_dir"/Cache/Data/pi-icon-*.dco \
        "$mod_dir"/Cache/Data/pi_icon_*.dco \
        "$mod_dir"/Cache/Textures/pi-icon-* \
        "$mod_dir"/Cache/Textures/pi_icon_* \
        "$mod_dir"/Cache/Raw/pi-icon-* \
        "$mod_dir"/Cache/Raw/pi_icon_*
}

if ! python3 - "$mod_dir" "$tooldb" "$temp_toolset" "$temp_renderables" "$compiler" <<'PY'
from pathlib import Path
import binascii
import copy
import hashlib
import json
import re
import struct
import sys
import zlib

root, tooldb_path, toolset_path, renderable_dir, compiler_path = map(
    Path, sys.argv[1:]
)
game_root = compiler_path.parent.parent
texture_dir = renderable_dir / "textures"
texture_dir.mkdir(parents=True, exist_ok=True)

alias_roots = {
    "$CONTENT_DATA": root,
    "$GAME_DATA": game_root / "Data",
    "$SURVIVAL_DATA": game_root / "Survival",
    "$CHALLENGE_DATA": game_root / "ChallengeData",
    "$CUSTOMIZATION_DATA": game_root / "Data",
    "$FUTURE_DATA": game_root / "Future",
    "$TEST_DATA": game_root / "Test",
}
color_pattern = re.compile(r"^[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?$")
image_cache = {}
baked_texture_cache = {}
solid_texture_cache = {}
warnings = set()


def resolve_data_path(value):
    normalized = value.replace("\\", "/")
    for alias, base in alias_roots.items():
        prefix = alias + "/"
        if normalized.startswith(prefix):
            return base.joinpath(*normalized[len(prefix):].split("/"))
    path = Path(value)
    return path if path.is_absolute() else root / path


def content_reference(path):
    return "$CONTENT_DATA/" + path.relative_to(root).as_posix()


def png_chunk(kind, payload):
    checksum = binascii.crc32(kind + payload) & 0xFFFFFFFF
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", checksum)


def paeth(left, above, upper_left):
    estimate = left + above - upper_left
    left_distance = abs(estimate - left)
    above_distance = abs(estimate - above)
    corner_distance = abs(estimate - upper_left)
    if left_distance <= above_distance and left_distance <= corner_distance:
        return left
    if above_distance <= corner_distance:
        return above
    return upper_left


def read_png(path):
    raw = path.read_bytes()
    if not raw.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"{path} is not a PNG file")

    position = 8
    header = None
    compressed = []
    while position < len(raw):
        length = struct.unpack_from(">I", raw, position)[0]
        kind = raw[position + 4:position + 8]
        payload = raw[position + 8:position + 8 + length]
        position += length + 12
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", payload)
        elif kind == b"IDAT":
            compressed.append(payload)
        elif kind == b"IEND":
            break

    if header is None:
        raise ValueError(f"{path} has no PNG header")
    width, height, depth, color_type, compression, filtering, interlace = header
    if (depth, color_type, compression, filtering, interlace) != (8, 6, 0, 0, 0):
        return None

    channels = 4
    stride = width * channels
    filtered = zlib.decompress(b"".join(compressed))
    if len(filtered) != (stride + 1) * height:
        raise ValueError(f"{path} has an invalid PNG data length")

    pixels = bytearray(stride * height)
    previous = bytearray(stride)
    source_offset = 0
    for row_index in range(height):
        filter_type = filtered[source_offset]
        source_offset += 1
        row = bytearray(filtered[source_offset:source_offset + stride])
        source_offset += stride

        if filter_type == 1:
            for index in range(channels, stride):
                row[index] = (row[index] + row[index - channels]) & 0xFF
        elif filter_type == 2:
            for index in range(stride):
                row[index] = (row[index] + previous[index]) & 0xFF
        elif filter_type == 3:
            for index in range(stride):
                left = row[index - channels] if index >= channels else 0
                row[index] = (row[index] + ((left + previous[index]) // 2)) & 0xFF
        elif filter_type == 4:
            for index in range(stride):
                left = row[index - channels] if index >= channels else 0
                upper_left = previous[index - channels] if index >= channels else 0
                row[index] = (
                    row[index] + paeth(left, previous[index], upper_left)
                ) & 0xFF
        elif filter_type != 0:
            raise ValueError(f"{path} uses unknown PNG filter {filter_type}")

        destination = row_index * stride
        pixels[destination:destination + stride] = row
        previous = row

    return {
        "format": "png",
        "width": width,
        "height": height,
        "pixels": pixels,
        "order": "rgba",
    }


def write_png(path, image, pixels):
    width = image["width"]
    height = image["height"]
    stride = width * 4
    scanlines = bytearray((stride + 1) * height)
    for row_index in range(height):
        source = row_index * stride
        destination = row_index * (stride + 1)
        scanlines[destination + 1:destination + 1 + stride] = pixels[
            source:source + stride
        ]

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", header)
        + png_chunk(b"IDAT", zlib.compress(scanlines, 9))
        + png_chunk(b"IEND", b"")
    )


def read_tga(path):
    raw = path.read_bytes()
    if len(raw) < 18:
        raise ValueError(f"{path} has no TGA header")

    id_length = raw[0]
    color_map_type = raw[1]
    image_type = raw[2]
    width, height = struct.unpack_from("<HH", raw, 12)
    depth = raw[16]
    descriptor = raw[17]
    if color_map_type != 0 or image_type not in (2, 10) or depth != 32:
        return None

    pixel_size = 4
    pixel_count = width * height
    position = 18 + id_length
    pixels = bytearray()
    if image_type == 2:
        end = position + pixel_count * pixel_size
        pixels.extend(raw[position:end])
    else:
        while len(pixels) < pixel_count * pixel_size:
            packet = raw[position]
            position += 1
            count = (packet & 0x7F) + 1
            if packet & 0x80:
                pixel = raw[position:position + pixel_size]
                position += pixel_size
                pixels.extend(pixel * count)
            else:
                size = count * pixel_size
                pixels.extend(raw[position:position + size])
                position += size

    if len(pixels) != pixel_count * pixel_size:
        raise ValueError(f"{path} has an invalid TGA data length")
    return {
        "format": "tga",
        "width": width,
        "height": height,
        "pixels": pixels,
        "order": "bgra",
        "descriptor": descriptor,
    }


def write_tga(path, image, pixels):
    descriptor = (image["descriptor"] & 0x30) | 8
    header = struct.pack(
        "<BBBHHBHHHHBB",
        0, 0, 2, 0, 0, 0, 0, 0,
        image["width"], image["height"], 32, descriptor,
    )
    path.write_bytes(header + pixels)


def read_image(path):
    cached = image_cache.get(path)
    if cached is not None:
        return cached

    suffix = path.suffix.lower()
    if suffix == ".png":
        image = read_png(path)
    elif suffix == ".tga":
        image = read_tga(path)
    else:
        image = None
    image_cache[path] = image
    return image


def bake_pixels(image, color):
    pixels = image["pixels"]
    output = bytearray(pixels)
    red_index, green_index, blue_index = (
        (0, 1, 2) if image["order"] == "rgba" else (2, 1, 0)
    )
    target_red, target_green, target_blue = color

    # Diffuse alpha is an inverse paint mask. Bake the shape color into RGB,
    # then make every pixel immune to the tool renderer's white paint color.
    for alpha_index in range(3, len(output), 4):
        alpha = output[alpha_index]
        pixel_index = alpha_index - 3
        if alpha == 0:
            output[pixel_index + red_index] = target_red
            output[pixel_index + green_index] = target_green
            output[pixel_index + blue_index] = target_blue
        elif alpha != 255:
            inverse = 255 - alpha
            output[pixel_index + red_index] = (
                output[pixel_index + red_index] * alpha + target_red * inverse + 127
            ) // 255
            output[pixel_index + green_index] = (
                output[pixel_index + green_index] * alpha + target_green * inverse + 127
            ) // 255
            output[pixel_index + blue_index] = (
                output[pixel_index + blue_index] * alpha + target_blue * inverse + 127
            ) // 255
        output[alpha_index] = 255
    return output


def solid_texture(color_hex):
    cached = solid_texture_cache.get(color_hex)
    if cached is not None:
        return cached

    red, green, blue = bytes.fromhex(color_hex)
    path = texture_dir / f"pi-icon-solid-{color_hex}.tga"
    header = struct.pack(
        "<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, 1, 1, 32, 8
    )
    path.write_bytes(header + bytes((blue, green, red, 255)))
    reference = content_reference(path)
    solid_texture_cache[color_hex] = reference
    return reference


def bake_texture(reference, color_hex):
    source = resolve_data_path(reference)
    if not source.is_file():
        warnings.add(f"missing diffuse texture {reference}; using a solid color")
        return solid_texture(color_hex), True

    key = (source.resolve(), color_hex)
    cached = baked_texture_cache.get(key)
    if cached is not None:
        return cached, True

    image = read_image(source)
    if image is None:
        warnings.add(f"unsupported diffuse texture {reference}; leaving it unchanged")
        return reference, False

    digest = hashlib.sha256(
        (str(key[0]) + "\0" + color_hex).encode("utf-8")
    ).hexdigest()[:20]
    suffix = ".png" if image["format"] == "png" else ".tga"
    output_path = texture_dir / f"pi-icon-texture-{digest}{suffix}"
    pixels = bake_pixels(image, bytes.fromhex(color_hex))
    if image["format"] == "png":
        write_png(output_path, image, pixels)
    else:
        write_tga(output_path, image, pixels)

    output_reference = content_reference(output_path)
    baked_texture_cache[key] = output_reference
    return output_reference, True


def rewrite_renderable(renderable, color_hex):
    rewrite_count = 0

    def visit(value):
        nonlocal rewrite_count
        if isinstance(value, dict):
            material = value.get("material")
            skip_material = isinstance(material, str) and any(
                marker in material.lower() for marker in ("lightcone", "lightflare")
            )
            found_diffuse = False
            if isinstance(material, str) and not skip_material:
                texture_list = value.get("textureList")
                if (
                    isinstance(texture_list, list)
                    and texture_list
                    and isinstance(texture_list[0], str)
                    and texture_list[0]
                ):
                    found_diffuse = True
                    replacement, changed = bake_texture(texture_list[0], color_hex)
                    if changed:
                        texture_list[0] = replacement
                        rewrite_count += 1

                textures = value.get("textures")
                if isinstance(textures, dict):
                    for key in ("diffuse", "dif"):
                        if isinstance(textures.get(key), str) and textures[key]:
                            found_diffuse = True
                            replacement, changed = bake_texture(textures[key], color_hex)
                            if changed:
                                textures[key] = replacement
                                rewrite_count += 1
                            break

                if not found_diffuse and material == "ConnectJoint":
                    value["material"] = "Dif"
                    value["textureList"] = [solid_texture(color_hex)]
                    rewrite_count += 1

            for child in value.values():
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)

    visit(renderable)
    return rewrite_count


def load_renderable(value):
    if isinstance(value, dict):
        return copy.deepcopy(value)
    if isinstance(value, str):
        path = resolve_data_path(value)
        if not path.is_file():
            raise ValueError(f"renderable {value} was not found")
        return json.loads(path.read_text(encoding="utf-8-sig"))
    raise ValueError("shape has no renderable")


tools = []
colored_shapes = 0
rewritten_slots = 0
# Keep the tool preview tilt, but turn it 180 degrees to match part icons.
part_preview_rotation = [1, 0, 0, 0, 0, -1, 0, 1, 0]
for shape_path in (root / "Objects/Database/ShapeSets").glob("*.shapeset"):
    data = json.loads(shape_path.read_text(encoding="utf-8-sig"))
    for list_name in ("blockList", "partList"):
        for shape in data.get(list_name, []):
            uuid = shape["uuid"]
            color_hex = str(shape.get("color", "ffffff")).lstrip("#")
            if not color_pattern.fullmatch(color_hex):
                raise SystemExit(f"Error: shape {uuid} has invalid color {color_hex!r}")
            color_hex = color_hex[:6].lower()
            renderable = shape.get("renderable")

            try:
                if color_hex == "ffffff" and isinstance(renderable, str):
                    preview = renderable
                else:
                    preview_data = load_renderable(renderable)
                    if color_hex != "ffffff":
                        rewritten = rewrite_renderable(preview_data, color_hex)
                        rewritten_slots += rewritten
                        colored_shapes += 1
                        if rewritten == 0:
                            warnings.add(
                                f"shape {uuid} has no paint-mask texture to bake"
                            )
                    rend_path = renderable_dir / f"pi-icon-{uuid}.rend"
                    rend_path.write_text(
                        json.dumps(preview_data, indent=4), encoding="utf-8"
                    )
                    preview = content_reference(rend_path)
            except (OSError, ValueError, json.JSONDecodeError) as error:
                raise SystemExit(f"Error: could not prepare shape {uuid}: {error}")

            tools.append({
                "name": shape.get("name", uuid),
                "previewRenderable": preview,
                "previewRotation": part_preview_rotation,
                "script": {
                    "class": "MTMultitool",
                    "data": {},
                    "file": "$CONTENT_DATA/Scripts/MTMultitool/MTMultitool.lua"
                },
                "showInInventory": True,
                "uuid": uuid
            })

toolset_path.write_text(json.dumps({"toolList": tools}, indent=4), encoding="utf-8")
tooldb = json.loads(tooldb_path.read_text(encoding="utf-8-sig"))
tooldb.setdefault("toolSetList", []).append(
    "$CONTENT_DATA/Tools/Database/ToolSets/pi-icon-generator.toolset"
)
tooldb_path.write_text(json.dumps(tooldb, indent=4), encoding="utf-8")
print(f"Temporarily registered {len(tools)} shapes as tools.")
print(
    f"Baked {colored_shapes} default colors into "
    f"{len(baked_texture_cache)} preview textures ({rewritten_slots} uses)."
)
for warning in sorted(warnings):
    print(f"Warning: {warning}", file=sys.stderr)
PY
then
    rm -f -- "$temp_toolset"
    rm -rf -- "$temp_renderables"
    cp -p -- "$tooldb_backup" "$tooldb"
    clear_icon_generator_cache
    restore_icons
    exit 1
fi

# Remove tool database caches so the temporary toolset is discovered.
clear_icon_generator_cache

# ContentCompiler parses the raw Windows command line and requires quotes
# around only the UGC path. A batch file preserves that exact format.
batch_name="pi-content-compiler-$$.bat"
batch_file="$drive_c/$batch_name"
batch_windows="C:/$batch_name"
compiler_windows="Z:$compiler"
printf '@echo off\r\n"%s" --ugc="%s"\r\nexit /b %%errorlevel%%\r\n' \
    "$compiler_windows" "$windows_mod" > "$batch_file"

cleanup() {
    rm -f -- "$batch_file" "$temp_toolset"
    rm -rf -- "$temp_renderables"
    cp -p -- "$tooldb_backup" "$tooldb"
    clear_icon_generator_cache
}
trap cleanup EXIT

proton=${PROTON:-"$steam_root/steamapps/common/Proton - Experimental/proton"}
[[ -x "$proton" ]] || {
    restore_icons
    fail "Proton was not found at $proton"
}

runner_env=(
    "STEAM_COMPAT_DATA_PATH=$compat_data"
    "STEAM_COMPAT_CLIENT_INSTALL_PATH=$steam_root"
    "SteamAppId=$appid"
    "SteamGameId=$appid"
    "STEAM_APPID=$appid"
)

# NixOS needs steam-run for graphics and font libraries. Other systems can
# invoke Proton directly.
if command -v steam-run >/dev/null 2>&1; then
    runner=(steam-run env "${runner_env[@]}" "$proton" run)
else
    runner=(env "${runner_env[@]}" "$proton" run)
fi

(
    cd -- "$(dirname -- "$compiler")" || exit 1
    "${runner[@]}" 'C:\windows\system32\cmd.exe' /d /s /c "$batch_windows"
)
compiler_status=$?

if (( compiler_status != 0 )); then
    restore_icons
    fail "ContentCompiler exited with code $compiler_status; the previous icons were restored"
fi

if [[ ! -s "$mod_dir/Gui/IconMap.png" || ! -s "$mod_dir/Gui/IconMap.xml" ]]; then
    restore_icons
    fail "ContentCompiler did not create both IconMap files; the previous icons were restored"
fi

python3 - "$mod_dir" <<'PY'
from pathlib import Path
import json
import re
import sys

root = Path(sys.argv[1])
xml = (root / "Gui/IconMap.xml").read_text(encoding="utf-8-sig")
indices = set(re.findall(r'<Index\s+name="([^"]+)"', xml))
indices.discard("Empty")

shape_uuids = set()
for path in (root / "Objects/Database/ShapeSets").glob("*.shapeset"):
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    for list_name in ("blockList", "partList"):
        shape_uuids.update(item["uuid"] for item in data.get(list_name, []))

missing_icons = shape_uuids - indices
if missing_icons:
    examples = ", ".join(sorted(missing_icons)[:5])
    raise SystemExit(
        f"Error: the generated atlas is missing {len(missing_icons)} block/part "
        f"icons (for example: {examples})"
    )

print(f"Generated {len(indices)} icons, including {len(shape_uuids)} block/part icons.")
PY
verify_status=$?

if (( verify_status != 0 )); then
    restore_icons
    fail "icon verification failed; the previous icons were restored"
fi

printf '\nDone. custom_icons remains enabled in description.json.\n'
