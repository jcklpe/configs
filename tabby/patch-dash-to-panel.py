#!/usr/bin/env python3
"""Hide only Tabby in Dash to Panel; fail closed if upstream changes the hook."""
import argparse
from pathlib import Path

ORIGINAL = "    return appInfos\n"
REPLACEMENT = (
    "    // Local preference: Tabby is controlled by Quake Anything, not the taskbar.\n"
    "    return appInfos.filter((appInfo) => appInfo.app.get_id() !== 'tabby.desktop')\n"
)


def patch(source: str) -> str:
    if source.count(REPLACEMENT) == 1 and ORIGINAL not in source:
        return source
    if source.count(ORIGINAL) != 1 or REPLACEMENT in source:
        raise ValueError("Unsupported Dash to Panel taskbar.js: expected exactly one unmodified return hook")
    return source.replace(ORIGINAL, REPLACEMENT)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("taskbar", type=Path)
    args = parser.parse_args()
    source = args.taskbar.read_text()
    result = patch(source)
    if result != source:
        args.taskbar.write_text(result)


if __name__ == "__main__":
    main()
