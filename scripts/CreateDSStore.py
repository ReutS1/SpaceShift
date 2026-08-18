#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-only
import sys

from ds_store import DSStore, DSStoreEntry
from ds_store.store import ILocCodec, PlistCodec
from mac_alias import Alias


if len(sys.argv) != 3:
    raise SystemExit("usage: CreateDSStore.py OUTPUT BACKGROUND_PNG")

output_path, background_path = sys.argv[1:]
background_alias = Alias.for_file(background_path).to_bytes()

window_options = {
    "ShowStatusBar": False,
    "ShowToolbar": False,
    "ShowTabView": False,
    "ContainerShowSidebar": False,
    "WindowBounds": "{{200, 180}, {800, 400}}",
    "ShowSidebar": False,
}

icon_options = {
    "backgroundColorBlue": 1.0,
    "labelOnBottom": True,
    "gridSpacing": 100.0,
    "textSize": 16.0,
    "backgroundColorRed": 1.0,
    "backgroundType": 2,
    "backgroundColorGreen": 1.0,
    "gridOffsetX": 0.0,
    "gridOffsetY": 0.0,
    "axTextSize": 16.0,
    "showItemInfo": False,
    "viewOptionsVersion": 1,
    "arrangeBy": "none",
    "backgroundImageAlias": background_alias,
    "iconSize": 100.0,
    "showIconPreview": True,
}

entries = [
    DSStoreEntry(".", b"bwsp", PlistCodec, window_options),
    DSStoreEntry(".", b"icvp", PlistCodec, icon_options),
    DSStoreEntry("Applications", b"Iloc", ILocCodec, (600, 190)),
    DSStoreEntry("SpaceShift.app", b"Iloc", ILocCodec, (200, 190)),
]

with DSStore.open(output_path, "w+", initial_entries=entries):
    pass
