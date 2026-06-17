#!/usr/bin/env python3
"""Reorganize dot shape assets from filename suffixes to category folders."""

from __future__ import annotations

import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHAPES = ROOT / "chocho/Assets.xcassets/public/shapes"
PIXEL_OLD = ROOT / "chocho/Assets.xcassets/public/像素波点"

CATEGORY_SUFFIXES = {
    "小物": "小物",
    "彩纸": "彩纸",
    "纽扣": "纽扣",
    "像素": "像素",
}

DELETE_SUFFIXES = {"贴纸", "布"}

NAMESPACE_JSON = {
    "info": {"author": "xcode", "version": 1},
    "properties": {"provides-namespace": True},
}

FOLDER_JSON = {
    "info": {"author": "xcode", "version": 1},
}


def parse_legacy_name(name: str) -> tuple[str, str | None]:
    if name.endswith(".dataset") or name.endswith(".imageset"):
        name = re.sub(r"\.(dataset|imageset)$", "", name)
    if "." not in name:
        return name, None
    base, suffix = name.rsplit(".", 1)
    if suffix in CATEGORY_SUFFIXES or suffix in DELETE_SUFFIXES:
        return base, suffix
    return name, None


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def rename_asset_contents(asset_dir: Path, new_leaf: str) -> None:
    contents_path = asset_dir / "Contents.json"
    if not contents_path.exists():
        return
    contents = json.loads(contents_path.read_text(encoding="utf-8"))
    if "images" in contents:
        for image in contents["images"]:
            old_filename = image.get("filename")
            if not old_filename:
                continue
            ext = Path(old_filename).suffix
            new_filename = f"{new_leaf}{ext}"
            old_path = asset_dir / old_filename
            new_path = asset_dir / new_filename
            if old_path.exists() and old_path != new_path:
                old_path.rename(new_path)
            image["filename"] = new_filename
    if "data" in contents:
        for item in contents["data"]:
            old_filename = item.get("filename")
            if not old_filename:
                continue
            ext = Path(old_filename).suffix
            new_filename = f"{new_leaf}{ext}"
            old_path = asset_dir / old_filename
            new_path = asset_dir / new_filename
            if old_path.exists() and old_path != new_path:
                old_path.rename(new_path)
            item["filename"] = new_filename
    write_json(contents_path, contents)


def ensure_folder(path: Path, *, namespace: bool) -> None:
    path.mkdir(parents=True, exist_ok=True)
    payload = NAMESPACE_JSON if namespace else FOLDER_JSON
    write_json(path / "Contents.json", payload)


def collect_assets(directory: Path) -> dict[str, list[Path]]:
    grouped: dict[str, list[Path]] = {}
    if not directory.exists():
        return grouped
    for entry in directory.iterdir():
        if not entry.is_dir():
            continue
        if not (entry.name.endswith(".dataset") or entry.name.endswith(".imageset")):
            continue
        leaf, suffix = parse_legacy_name(entry.name)
        key = f"{leaf}|{suffix or '基础'}"
        grouped.setdefault(key, []).append(entry)
    return grouped


def choose_asset(paths: list[Path]) -> Path:
    datasets = [path for path in paths if path.name.endswith(".dataset")]
    if datasets:
        return datasets[0]
    return paths[0]


def delete_paths(paths: list[Path]) -> None:
    for path in paths:
        shutil.rmtree(path, ignore_errors=True)


def move_asset(source: Path, destination_dir: Path, new_leaf: str) -> Path:
    suffix = ".dataset" if source.name.endswith(".dataset") else ".imageset"
    destination = destination_dir / f"{new_leaf}{suffix}"
    if destination.exists():
        shutil.rmtree(destination)
    shutil.move(str(source), str(destination))
    rename_asset_contents(destination, new_leaf)
    return destination


def reorganize_shapes() -> None:
    grouped = collect_assets(SHAPES)
    staging = SHAPES / "__staging__"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir()

    for key, paths in grouped.items():
        leaf, category = key.split("|", 1)
        if category in DELETE_SUFFIXES:
            delete_paths(paths)
            continue

        chosen = choose_asset(paths)
        extras = [path for path in paths if path != chosen]
        delete_paths(extras)

        target_category = "基础" if category == "基础" else category
        target_dir = staging / target_category
        ensure_folder(target_dir, namespace=True)
        move_asset(chosen, target_dir, leaf)

    for child in list(SHAPES.iterdir()):
        if child.name == "__staging__":
            continue
        if child.is_dir() and (child.name.endswith(".dataset") or child.name.endswith(".imageset")):
            shutil.rmtree(child, ignore_errors=True)

    for category_dir in staging.iterdir():
        if not category_dir.is_dir():
            continue
        destination = SHAPES / category_dir.name
        if destination.exists():
            shutil.rmtree(destination)
        shutil.move(str(category_dir), str(destination))

    shutil.rmtree(staging, ignore_errors=True)
    write_json(SHAPES / "Contents.json", NAMESPACE_JSON)


def reorganize_pixel() -> None:
    if not PIXEL_OLD.exists():
        return

    pixel_dir = SHAPES / "像素"
    if pixel_dir.exists():
        shutil.rmtree(pixel_dir)
    pixel_dir.mkdir()
    write_json(pixel_dir / "Contents.json", NAMESPACE_JSON)

    grouped = collect_assets(PIXEL_OLD)
    for key, paths in grouped.items():
        leaf, category = key.split("|", 1)
        if category != "像素":
            delete_paths(paths)
            continue
        chosen = choose_asset(paths)
        delete_paths([path for path in paths if path != chosen])
        move_asset(chosen, pixel_dir, leaf)

    shutil.rmtree(PIXEL_OLD, ignore_errors=True)


def main() -> None:
    reorganize_shapes()
    reorganize_pixel()
    print("Reorganized dot shape assets.")


if __name__ == "__main__":
    main()
