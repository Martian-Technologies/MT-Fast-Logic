#!/usr/bin/env python3
"""Generate the Scrap Mechanic icon atlas with ContentCompiler."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from xml.etree import ElementTree

from dotenv import load_dotenv
from PIL import Image, UnidentifiedImageError

ICON_SIZE = 96
TOOLSET_REFERENCE = "$CONTENT_DATA/Tools/Database/ToolSets/pi-icon-generator.toolset"
COLOR_PATTERN = re.compile(r"^[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?$")


class GenerationError(RuntimeError):
    pass


def read_json(path: Path) -> object:
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as error:
        raise GenerationError(f"could not read {path}: {error}") from error


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=4) + "\n", encoding="utf-8")


def atomic_copy(source: Path, destination: Path) -> None:
    temporary = destination.with_name(f".{destination.name}.tmp-{os.getpid()}")
    try:
        shutil.copy2(source, temporary)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def enable_custom_icons(path: Path) -> None:
    try:
        raw = path.read_bytes()
    except OSError as error:
        raise GenerationError(f"could not read {path}: {error}") from error

    has_bom = raw.startswith(b"\xef\xbb\xbf")
    text = raw.decode("utf-8-sig")
    pattern = re.compile(r'("custom_icons"\s*:\s*)(?:false|true)', re.IGNORECASE)
    text, count = pattern.subn(r"\g<1>true", text, count=1)
    if count != 1:
        raise GenerationError("description.json has no custom_icons field")

    try:
        path.write_bytes((b"\xef\xbb\xbf" if has_bom else b"") + text.encode())
    except OSError as error:
        raise GenerationError(f"could not update {path}: {error}") from error


@dataclass
class AtlasBackup:
    directory: Path
    icon_png: Path
    icon_xml: Path
    had_png: bool
    had_xml: bool

    @classmethod
    def create(cls, root: Path) -> AtlasBackup:
        backup_root = root / "IconMapsBackups"
        stamp = datetime.now(UTC).astimezone().strftime("%Y%m%d-%H%M%S")
        directory = backup_root / stamp
        suffix = 1
        while directory.exists():
            directory = backup_root / f"{stamp}-{suffix}"
            suffix += 1
        directory.mkdir(parents=True)

        icon_png = root / "Gui/IconMap.png"
        icon_xml = root / "Gui/IconMap.xml"
        had_png = icon_png.is_file()
        had_xml = icon_xml.is_file()
        if had_png:
            shutil.copy2(icon_png, directory / icon_png.name)
        if had_xml:
            shutil.copy2(icon_xml, directory / icon_xml.name)
        return cls(directory, icon_png, icon_xml, had_png, had_xml)

    def restore(self) -> None:
        replacements = []
        try:
            for had_file, destination in (
                (self.had_png, self.icon_png),
                (self.had_xml, self.icon_xml),
            ):
                if not had_file:
                    continue
                source = self.directory / destination.name
                temporary = destination.with_name(
                    f".{destination.name}.restore-{os.getpid()}"
                )
                shutil.copy2(source, temporary)
                replacements.append((temporary, destination))

            for temporary, destination in replacements:
                os.replace(temporary, destination)
            if not self.had_png:
                self.icon_png.unlink(missing_ok=True)
            if not self.had_xml:
                self.icon_xml.unlink(missing_ok=True)
        finally:
            for temporary, _ in replacements:
                temporary.unlink(missing_ok=True)


class RenderablePreparer:
    def __init__(self, root: Path, compiler: Path, output_dir: Path) -> None:
        self.root = root
        self.output_dir = output_dir
        self.texture_dir = output_dir / "textures"
        game_root = compiler.parent.parent
        self.alias_roots = {
            "$CONTENT_DATA": root,
            "$GAME_DATA": game_root / "Data",
            "$SURVIVAL_DATA": game_root / "Survival",
            "$CHALLENGE_DATA": game_root / "ChallengeData",
            "$CUSTOMIZATION_DATA": game_root / "Data",
            "$FUTURE_DATA": game_root / "Future",
            "$TEST_DATA": game_root / "Test",
        }
        self.image_cache: dict[Path, Image.Image | None] = {}
        self.baked_texture_cache: dict[tuple[Path, str], str] = {}
        self.solid_texture_cache: dict[str, str] = {}
        self.warnings: set[str] = set()
        self.colored_shapes = 0
        self.rewritten_slots = 0

    def resolve_data_path(self, value: str) -> Path:
        normalized = value.replace("\\", "/")
        for alias, base in self.alias_roots.items():
            prefix = f"{alias}/"
            if normalized.startswith(prefix):
                return base.joinpath(*normalized[len(prefix) :].split("/"))
        path = Path(value)
        return path if path.is_absolute() else self.root / path

    def content_reference(self, path: Path) -> str:
        return "$CONTENT_DATA/" + path.relative_to(self.root).as_posix()

    def read_image(self, path: Path) -> Image.Image | None:
        if path in self.image_cache:
            return self.image_cache[path]
        try:
            with Image.open(path) as source:
                image = source.convert("RGBA")
                image.load()
        except (OSError, UnidentifiedImageError) as error:
            if path.suffix.lower() in {".png", ".tga"}:
                raise GenerationError(
                    f"could not decode texture {path}: {error}"
                ) from error
            image = None
        self.image_cache[path] = image
        return image

    @staticmethod
    def bake_color(image: Image.Image, color_hex: str) -> Image.Image:
        color = tuple(bytes.fromhex(color_hex))
        source = image.convert("RGB")
        solid = Image.new("RGB", image.size, color)
        result = Image.composite(source, solid, image.getchannel("A"))
        result.putalpha(255)
        return result

    def solid_texture(self, color_hex: str) -> str:
        cached = self.solid_texture_cache.get(color_hex)
        if cached is not None:
            return cached

        path = self.texture_dir / f"pi-icon-solid-{color_hex}.png"
        Image.new("RGBA", (1, 1), f"#{color_hex}").save(path)
        reference = self.content_reference(path)
        self.solid_texture_cache[color_hex] = reference
        return reference

    def bake_texture(self, reference: str, color_hex: str) -> tuple[str, bool]:
        source = self.resolve_data_path(reference)
        if not source.is_file():
            self.warnings.add(
                f"missing diffuse texture {reference}; using a solid color"
            )
            return self.solid_texture(color_hex), True

        key = (source.resolve(), color_hex)
        cached = self.baked_texture_cache.get(key)
        if cached is not None:
            return cached, True

        image = self.read_image(source)
        if image is None:
            self.warnings.add(
                f"unsupported diffuse texture {reference}; leaving it unchanged"
            )
            return reference, False

        digest = hashlib.sha256(f"{key[0]}\0{color_hex}".encode()).hexdigest()[:20]
        output_path = self.texture_dir / f"pi-icon-texture-{digest}.png"
        self.bake_color(image, color_hex).save(output_path, optimize=True)
        output_reference = self.content_reference(output_path)
        self.baked_texture_cache[key] = output_reference
        return output_reference, True

    def rewrite_renderable(self, renderable: object, color_hex: str) -> int:
        rewrite_count = 0

        def visit(value: object) -> None:
            nonlocal rewrite_count
            if isinstance(value, list):
                for child in value:
                    visit(child)
                return
            if not isinstance(value, dict):
                return

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
                    replacement, changed = self.bake_texture(texture_list[0], color_hex)
                    if changed:
                        texture_list[0] = replacement
                        rewrite_count += 1

                textures = value.get("textures")
                if isinstance(textures, dict):
                    for key in ("diffuse", "dif"):
                        reference = textures.get(key)
                        if isinstance(reference, str) and reference:
                            found_diffuse = True
                            replacement, changed = self.bake_texture(
                                reference, color_hex
                            )
                            if changed:
                                textures[key] = replacement
                                rewrite_count += 1
                            break

                if not found_diffuse and material == "ConnectJoint":
                    value["material"] = "Dif"
                    value["textureList"] = [self.solid_texture(color_hex)]
                    rewrite_count += 1

            for child in value.values():
                visit(child)

        visit(renderable)
        return rewrite_count

    def load_renderable(self, value: object) -> object:
        if isinstance(value, dict):
            return copy.deepcopy(value)
        if isinstance(value, str):
            path = self.resolve_data_path(value)
            if not path.is_file():
                raise GenerationError(f"renderable {value} was not found")
            return copy.deepcopy(read_json(path))
        raise GenerationError("shape has no renderable")

    def prepare_tools(self) -> list[dict[str, object]]:
        self.texture_dir.mkdir(parents=True, exist_ok=True)
        tools: list[dict[str, object]] = []
        preview_rotation = [1, 0, 0, 0, 0, -1, 0, 1, 0]

        shape_sets = sorted(
            (self.root / "Objects/Database/ShapeSets").glob("*.shapeset")
        )
        for shape_path in shape_sets:
            data = read_json(shape_path)
            if not isinstance(data, dict):
                raise GenerationError(f"{shape_path} does not contain a JSON object")
            for list_name in ("blockList", "partList"):
                shapes = data.get(list_name, [])
                if not isinstance(shapes, list):
                    raise GenerationError(f"{shape_path}: {list_name} is not a list")
                for shape in shapes:
                    if not isinstance(shape, dict) or not isinstance(
                        shape.get("uuid"), str
                    ):
                        raise GenerationError(f"{shape_path}: shape has no UUID")
                    uuid = shape["uuid"]
                    color_hex = str(shape.get("color", "ffffff")).lstrip("#")
                    if not COLOR_PATTERN.fullmatch(color_hex):
                        raise GenerationError(
                            f"shape {uuid} has invalid color {color_hex!r}"
                        )
                    color_hex = color_hex[:6].lower()
                    renderable = shape.get("renderable")

                    if color_hex == "ffffff" and isinstance(renderable, str):
                        preview = renderable
                    else:
                        try:
                            preview_data = self.load_renderable(renderable)
                            if color_hex != "ffffff":
                                rewritten = self.rewrite_renderable(
                                    preview_data, color_hex
                                )
                                self.rewritten_slots += rewritten
                                self.colored_shapes += 1
                                if rewritten == 0:
                                    self.warnings.add(
                                        f"shape {uuid} has no paint-mask texture to bake"
                                    )
                            rend_path = self.output_dir / f"pi-icon-{uuid}.rend"
                            write_json(rend_path, preview_data)
                            preview = self.content_reference(rend_path)
                        except (OSError, GenerationError) as error:
                            raise GenerationError(
                                f"could not prepare shape {uuid}: {error}"
                            ) from error

                    tools.append(
                        {
                            "name": shape.get("name", uuid),
                            "previewRenderable": preview,
                            "previewRotation": preview_rotation,
                            "script": {
                                "class": "MTMultitool",
                                "data": {},
                                "file": "$CONTENT_DATA/Scripts/MTMultitool/MTMultitool.lua",
                            },
                            "showInInventory": True,
                            "uuid": uuid,
                        }
                    )
        return tools


def clear_generator_cache(root: Path) -> None:
    patterns = (
        "Cache/Data/toolsets_*.dco",
        "Cache/Data/pi-icon-*.dco",
        "Cache/Data/pi_icon_*.dco",
        "Cache/Textures/pi-icon-*",
        "Cache/Textures/pi_icon_*",
        "Cache/Raw/pi-icon-*",
        "Cache/Raw/pi_icon_*",
    )
    for pattern in patterns:
        for path in root.glob(pattern):
            if path.is_dir():
                shutil.rmtree(path)
            else:
                path.unlink(missing_ok=True)


def cleanup_temporary_files(
    root: Path,
    tooldb_backup: Path,
    tooldb_path: Path,
    toolset_path: Path,
    output_dir: Path,
) -> None:
    errors: list[OSError] = []
    actions = (
        lambda: atomic_copy(tooldb_backup, tooldb_path),
        lambda: toolset_path.unlink(missing_ok=True),
        lambda: shutil.rmtree(output_dir, ignore_errors=False),
        lambda: clear_generator_cache(root),
    )
    for action in actions:
        try:
            action()
        except FileNotFoundError:
            pass
        except OSError as error:
            errors.append(error)
    if errors:
        details = "; ".join(str(error) for error in errors)
        raise GenerationError(f"could not clean up temporary files: {details}")


def register_temporary_tools(
    root: Path, compiler: Path, tooldb_path: Path, toolset_path: Path, output_dir: Path
) -> None:
    preparer = RenderablePreparer(root, compiler, output_dir)
    tools = preparer.prepare_tools()
    write_json(toolset_path, {"toolList": tools})

    tooldb = read_json(tooldb_path)
    if not isinstance(tooldb, dict):
        raise GenerationError(f"{tooldb_path} does not contain a JSON object")
    toolsets = tooldb.setdefault("toolSetList", [])
    if not isinstance(toolsets, list):
        raise GenerationError(f"{tooldb_path}: toolSetList is not a list")
    if TOOLSET_REFERENCE not in toolsets:
        toolsets.append(TOOLSET_REFERENCE)
    write_json(tooldb_path, tooldb)

    print(f"Temporarily registered {len(tools)} shapes as tools.")
    print(
        f"Baked {preparer.colored_shapes} default colors into "
        f"{len(preparer.baked_texture_cache)} preview textures "
        f"({preparer.rewritten_slots} uses).",
        flush=True,
    )
    for warning in sorted(preparer.warnings):
        print(f"Warning: {warning}", file=sys.stderr)


def windows_mod_path(root: Path, drive_c: Path) -> str:
    try:
        relative = root.relative_to(drive_c)
    except ValueError as error:
        raise GenerationError(
            "the mod is outside the Proton C: drive and cannot be passed to ContentCompiler"
        ) from error
    return "C:/" + relative.as_posix()


def run_compiler(
    compiler: Path,
    proton: Path,
    steam_root: Path,
    compat_data: Path,
    drive_c: Path,
    windows_mod: str,
    app_id: int,
) -> None:
    batch_name = f"pi-content-compiler-{os.getpid()}.bat"
    batch_file = drive_c / batch_name
    batch_windows = f"C:/{batch_name}"
    compiler_windows = "Z:" + compiler.as_posix()
    runner_environment = {
        "STEAM_COMPAT_DATA_PATH": str(compat_data),
        "STEAM_COMPAT_CLIENT_INSTALL_PATH": str(steam_root),
        "SteamAppId": str(app_id),
        "SteamGameId": str(app_id),
        "STEAM_APPID": str(app_id),
    }
    environment = os.environ.copy()
    environment.update(runner_environment)

    steam_run = shutil.which("steam-run")
    if steam_run:
        assignments = [f"{key}={value}" for key, value in runner_environment.items()]
        command = [steam_run, "env", *assignments, str(proton), "run"]
    else:
        command = [str(proton), "run"]
    command.extend([r"C:\windows\system32\cmd.exe", "/d", "/s", "/c", batch_windows])

    try:
        batch_file.write_text(
            f'@echo off\n"{compiler_windows}" --ugc="{windows_mod}"\n'
            "exit /b %errorlevel%\n",
            encoding="utf-8",
            newline="\r\n",
        )
        result = subprocess.run(
            command, cwd=compiler.parent, env=environment, check=False
        )
    except OSError as error:
        raise GenerationError(f"could not start ContentCompiler: {error}") from error
    finally:
        batch_file.unlink(missing_ok=True)

    if result.returncode != 0:
        raise GenerationError(f"ContentCompiler exited with code {result.returncode}")


def shape_uuids(root: Path) -> set[str]:
    uuids: set[str] = set()
    for path in sorted((root / "Objects/Database/ShapeSets").glob("*.shapeset")):
        data = read_json(path)
        if not isinstance(data, dict):
            continue
        for list_name in ("blockList", "partList"):
            for item in data.get(list_name, []):
                if isinstance(item, dict) and isinstance(item.get("uuid"), str):
                    uuids.add(item["uuid"])
    return uuids


def read_icon_frames(icon_xml: Path) -> dict[str, tuple[int, int]]:
    try:
        xml_root = ElementTree.parse(icon_xml).getroot()
    except (OSError, ElementTree.ParseError) as error:
        raise GenerationError(f"could not read {icon_xml}: {error}") from error

    frames: dict[str, tuple[int, int]] = {}
    for index in xml_root.iter("Index"):
        name = index.get("name")
        if not name or name == "Empty":
            continue
        frame = index.find("Frame")
        try:
            values = tuple(int(value) for value in frame.get("point", "").split())
        except (AttributeError, ValueError) as error:
            raise GenerationError(f"icon {name!r} has an invalid frame") from error
        if len(values) != 2:
            raise GenerationError(f"icon {name!r} has an invalid frame")
        if name in frames:
            raise GenerationError(f"IconMap.xml contains duplicate icon {name!r}")
        frames[name] = values
    return frames


def read_icon_names(value: object, field: str, entry_label: str) -> set[str]:
    if value is None:
        return set()
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise GenerationError(f"{entry_label} {field} must be a list of icon names")
    return set(value)


def read_icon_overlay_entries(gui_dir: Path) -> list[tuple[Path, int, object]]:
    manifest_paths = sorted(gui_dir.glob("IconOverlays_*.json"))
    default_manifest = gui_dir / "IconOverlays.json"
    if default_manifest.is_file():
        manifest_paths.insert(0, default_manifest)
    if not manifest_paths:
        raise GenerationError("Gui contains no IconOverlays.json manifests")

    entries = []
    for manifest_path in manifest_paths:
        manifest = read_json(manifest_path)
        if not isinstance(manifest, dict) or not isinstance(
            manifest.get("overlays"), list
        ):
            raise GenerationError(f"{manifest_path.name} must contain an overlays list")
        entries.extend(
            (manifest_path, position, entry)
            for position, entry in enumerate(manifest["overlays"], start=1)
        )
    return entries


def composite_underlay(
    atlas: Image.Image, underlay: Image.Image, position: tuple[int, int]
) -> None:
    x, y = position
    left = max(x, 0)
    top = max(y, 0)
    right = min(x + underlay.width, atlas.width)
    bottom = min(y + underlay.height, atlas.height)
    if left >= right or top >= bottom:
        return

    source = underlay.crop((left - x, top - y, right - x, bottom - y))
    foreground = atlas.crop((left, top, right, bottom))
    atlas.paste(Image.alpha_composite(source, foreground), (left, top))


def apply_icon_overlays(root: Path) -> None:
    gui_dir = root / "Gui"
    icon_png = gui_dir / "IconMap.png"
    overlay_entries = read_icon_overlay_entries(gui_dir)

    frames = read_icon_frames(gui_dir / "IconMap.xml")
    shapes = shape_uuids(root)
    try:
        with Image.open(icon_png) as source:
            atlas = source.convert("RGBA")
            atlas.load()
    except (OSError, UnidentifiedImageError) as error:
        raise GenerationError(f"could not load {icon_png}: {error}") from error

    applied_counts: list[tuple[str, int]] = []
    for manifest_path, position, entry in overlay_entries:
        entry_label = f"{manifest_path.name}: overlay {position}"
        if not isinstance(entry, dict):
            raise GenerationError(f"{entry_label} is not an object")
        image_name = entry.get("image")
        if not isinstance(image_name, str) or not image_name:
            raise GenerationError(f"{entry_label} has no image")
        all_shapes = entry.get("all_shapes", False)
        if not isinstance(all_shapes, bool):
            raise GenerationError(f"{entry_label} all_shapes must be a boolean")
        underlay = entry.get("underlay", False)
        if not isinstance(underlay, bool):
            raise GenerationError(f"{entry_label} underlay must be a boolean")

        targets = set(shapes) if all_shapes else set()
        targets.update(read_icon_names(entry.get("icons"), "icons", entry_label))
        targets.difference_update(
            read_icon_names(entry.get("exclude_icons"), "exclude_icons", entry_label)
        )
        if not targets:
            raise GenerationError(f"{entry_label} has no targets")
        missing = targets - frames.keys()
        if missing:
            examples = ", ".join(sorted(missing)[:5])
            raise GenerationError(f"{entry_label} targets missing icons: {examples}")

        offset = entry.get("offset", [0, 0])
        if (
            not isinstance(offset, list)
            or len(offset) != 2
            or not all(isinstance(value, int) for value in offset)
        ):
            raise GenerationError(f"{entry_label} offset must contain two integers")
        offset_x, offset_y = offset

        image_path = gui_dir / image_name
        try:
            with Image.open(image_path) as source:
                overlay = source.convert("RGBA")
                overlay.load()
        except (OSError, UnidentifiedImageError) as error:
            raise GenerationError(
                f"could not load overlay {image_path}: {error}"
            ) from error
        alpha_bounds = overlay.getchannel("A").getbbox()
        if alpha_bounds is None:
            raise GenerationError(f"overlay {image_path} is empty")

        left, top, right, bottom = alpha_bounds
        frame_points = {frames[name] for name in targets}
        for frame_x, frame_y in frame_points:
            x = frame_x + offset_x
            y = frame_y + offset_y
            if (
                x + left < 0
                or y + top < 0
                or x + right > atlas.width
                or y + bottom > atlas.height
            ):
                raise GenerationError(
                    f"overlay {image_name} for frame {frame_x} {frame_y} "
                    "would be outside IconMap.png"
                )
            if underlay:
                composite_underlay(atlas, overlay, (x, y))
            else:
                atlas.paste(overlay, (x, y), overlay)
        applied_counts.append((image_name, len(frame_points)))

    temporary = icon_png.with_name(f".{icon_png.name}.overlays-{os.getpid()}")
    try:
        atlas.save(temporary, format="PNG", optimize=True)
        os.replace(temporary, icon_png)
    except OSError as error:
        raise GenerationError(f"could not save the icon overlays: {error}") from error
    finally:
        temporary.unlink(missing_ok=True)

    for image_name, count in applied_counts:
        print(f"Applied {image_name} to {count} icons.")


def verify_atlas(root: Path) -> None:
    icon_png = root / "Gui/IconMap.png"
    icon_xml = root / "Gui/IconMap.xml"
    if not icon_png.is_file() or icon_png.stat().st_size == 0:
        raise GenerationError("ContentCompiler did not create Gui/IconMap.png")
    if not icon_xml.is_file() or icon_xml.stat().st_size == 0:
        raise GenerationError("ContentCompiler did not create Gui/IconMap.xml")

    try:
        with Image.open(icon_png) as atlas:
            atlas.load()
            width, height = atlas.size
    except (OSError, UnidentifiedImageError) as error:
        raise GenerationError(
            f"the generated IconMap.png is invalid: {error}"
        ) from error

    try:
        xml_root = ElementTree.parse(icon_xml).getroot()
    except (OSError, ElementTree.ParseError) as error:
        raise GenerationError(
            f"the generated IconMap.xml is invalid: {error}"
        ) from error

    indices: set[str] = set()
    for index in xml_root.iter("Index"):
        name = index.get("name")
        frames = index.findall("Frame")
        if not name or len(frames) != 1 or not frames[0].get("point"):
            raise GenerationError(f"icon {name!r} does not have exactly one frame")
        try:
            x, y = (int(value) for value in frames[0].get("point", "").split())
        except ValueError as error:
            raise GenerationError(
                f"icon {name!r} has an invalid frame point"
            ) from error
        if x < 0 or y < 0 or x + ICON_SIZE > width or y + ICON_SIZE > height:
            raise GenerationError(f"icon {name!r} points outside IconMap.png")
        if name != "Empty":
            indices.add(name)

    required = shape_uuids(root)
    missing = required - indices
    if missing:
        examples = ", ".join(sorted(missing)[:5])
        raise GenerationError(
            f"the generated atlas is missing {len(missing)} block/part icons "
            f"(for example: {examples})"
        )
    print(
        f"Generated {len(indices)} icons, including {len(required)} block/part icons."
    )


def generate(args: argparse.Namespace) -> None:
    root = Path(__file__).resolve().parent
    description = root / "description.json"
    configuration = {
        "STEAM_ROOT": args.steam_root,
        "CONTENT_COMPILER": args.compiler,
        "STEAM_COMPAT_DATA_PATH": args.compat_data,
        "PROTON": args.proton,
        "PROTONTRICKS_APPID": args.app_id,
    }
    missing = [name for name, value in configuration.items() if value is None]
    if missing:
        raise GenerationError(
            f"missing configuration: {', '.join(missing)}; set it in .env or pass its option"
        )

    steam_root = args.steam_root.expanduser().resolve()
    compiler = args.compiler.expanduser().resolve()
    compat_data = args.compat_data.expanduser().resolve()
    proton = args.proton.expanduser().resolve()
    drive_c = compat_data / "pfx/drive_c"

    if not description.is_file():
        raise GenerationError(f"description.json was not found in {root}")
    if not compiler.is_file():
        raise GenerationError(f"ContentCompiler.exe was not found at {compiler}")
    if not drive_c.is_dir():
        raise GenerationError(f"the Proton C: drive was not found under {compat_data}")
    if not proton.is_file() or not os.access(proton, os.X_OK):
        raise GenerationError(f"Proton was not found at {proton}")

    windows_mod = windows_mod_path(root, drive_c.resolve())
    enable_custom_icons(description)
    backup = AtlasBackup.create(root)

    print(f"Generating icons for:\n  {root}")
    print(f"ContentCompiler path:\n  {windows_mod}")
    print(f"Backup directory:\n  {backup.directory}\n", flush=True)

    tooldb_path = root / "Tools/Database/toolsets.tooldb"
    toolset_path = root / "Tools/Database/ToolSets/pi-icon-generator.toolset"
    output_dir = root / "Renderable/pi-icon-generator"
    tooldb_backup = backup.directory / tooldb_path.name
    if not tooldb_path.is_file():
        backup.restore()
        raise GenerationError("Tools/Database/toolsets.tooldb was not found")
    shutil.copy2(tooldb_path, tooldb_backup)

    try:
        try:
            toolset_path.unlink(missing_ok=True)
            shutil.rmtree(output_dir, ignore_errors=True)
            register_temporary_tools(
                root, compiler, tooldb_path, toolset_path, output_dir
            )
            clear_generator_cache(root)
            run_compiler(
                compiler,
                proton,
                steam_root,
                compat_data,
                drive_c,
                windows_mod,
                args.app_id,
            )
            apply_icon_overlays(root)
            verify_atlas(root)
        finally:
            cleanup_temporary_files(
                root, tooldb_backup, tooldb_path, toolset_path, output_dir
            )
    except BaseException:
        backup.restore()
        raise

    print("\nDone. custom_icons remains enabled in description.json.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--steam-root", type=Path, default=os.getenv("STEAM_ROOT"))
    parser.add_argument("--compiler", type=Path, default=os.getenv("CONTENT_COMPILER"))
    parser.add_argument(
        "--compat-data", type=Path, default=os.getenv("STEAM_COMPAT_DATA_PATH")
    )
    parser.add_argument("--proton", type=Path, default=os.getenv("PROTON"))
    parser.add_argument("--app-id", type=int, default=os.getenv("PROTONTRICKS_APPID"))
    return parser.parse_args()


def main() -> int:
    load_dotenv(Path(__file__).resolve().with_name(".env"))
    try:
        generate(parse_args())
    except GenerationError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    except OSError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\nCanceled.", file=sys.stderr)
        return 130
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
