#!/usr/bin/python3
"""Regression tests for the shipped EOS Plasma layout verifier."""

from __future__ import annotations

import copy
import json
import runpy
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
VERIFIER = (
    PROJECT_ROOT
    / "build/live-build-config/includes.chroot/usr/local/lib/eos-privet/verify-plasma-layout"
)
MODULE = runpy.run_path(str(VERIFIER), run_name="eos_layout_verifier")
LayoutError = MODULE["LayoutError"]
validate_live = MODULE["validate_live"]
validate_config = MODULE["validate_config"]
WALLPAPER_URI = MODULE["WALLPAPER_URI"]
DOCK_LAUNCHERS = MODULE["DOCK_LAUNCHERS"]


def live_script(layout: dict) -> str:
    return (
        "var plasma = getApiVersion(1);\n\nvar layout = "
        + json.dumps(layout, indent=4)
        + ";\n\nplasma.loadSerializedLayout(layout);\n"
    )


def valid_live_layout() -> dict:
    return {
        "serializationFormatVersion": "1",
        "desktops": [
            {
                "wallpaperPlugin": "org.kde.image",
                "config": {
                    "/Wallpaper/org.kde.image/General": {
                        "Image": WALLPAPER_URI,
                        "FillMode": "2",
                    }
                },
                "applets": [],
            }
        ],
        "panels": [
            {
                "location": "top",
                "lengthMode": "fill",
                "hiding": "normal",
                "applets": [
                    {"plugin": "org.kde.plasma.kickoff", "config": {}},
                    {"plugin": "org.kde.plasma.panelspacer", "config": {}},
                    {"plugin": "org.kde.plasma.systemtray", "config": {}},
                    {"plugin": "org.kde.plasma.digitalclock", "config": {}},
                ],
            },
            {
                "location": "bottom",
                "lengthMode": "fit",
                "alignment": "center",
                "hiding": "dodgewindows",
                "applets": [
                    {
                        "plugin": "org.kde.plasma.icontasks",
                        "config": {"/General": {"launchers": DOCK_LAUNCHERS}},
                    },
                    {"plugin": "org.kde.plasma.showdesktop", "config": {}},
                ],
            },
        ],
    }


def valid_persisted_config() -> str:
    return f"""[Containments][1]
activityId=activity-one
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.image

[Containments][1][Wallpaper][org.kde.image][General]
FillMode=2
Image={WALLPAPER_URI}

[Containments][10]
formfactor=2
location=3
plugin=org.kde.panel

[Containments][10][General]
AppletOrder=11;12;13;14

[Containments][10][Applets][11]
plugin=org.kde.plasma.kickoff

[Containments][10][Applets][12]
plugin=org.kde.plasma.panelspacer

[Containments][10][Applets][13]
plugin=org.kde.plasma.systemtray

[Containments][10][Applets][14]
plugin=org.kde.plasma.digitalclock

[Containments][20]
formfactor=2
location=4
plugin=org.kde.panel

[Containments][20][General]
AppletOrder=21;22

[Containments][20][Applets][21]
plugin=org.kde.plasma.icontasks

[Containments][20][Applets][21][Configuration][General]
launchers={DOCK_LAUNCHERS}

[Containments][20][Applets][22]
plugin=org.kde.plasma.showdesktop
"""


class LiveLayoutTests(unittest.TestCase):
    def test_exact_layout_passes_with_reversed_panel_array(self) -> None:
        layout = valid_live_layout()
        layout["panels"].reverse()
        validate_live(live_script(layout))

    def test_multiple_eos_desktops_pass(self) -> None:
        layout = valid_live_layout()
        layout["desktops"].append(copy.deepcopy(layout["desktops"][0]))
        validate_live(live_script(layout))

    def test_integer_serialization_version_fails(self) -> None:
        layout = valid_live_layout()
        layout["serializationFormatVersion"] = 1
        with self.assertRaises(LayoutError):
            validate_live(live_script(layout))

    def test_wallpaper_in_unrelated_group_fails(self) -> None:
        layout = valid_live_layout()
        layout["desktops"][0]["config"] = {"/Bogus": {"Image": WALLPAPER_URI}}
        with self.assertRaises(LayoutError):
            validate_live(live_script(layout))

    def test_launcher_string_in_unrelated_group_fails(self) -> None:
        layout = valid_live_layout()
        layout["panels"][1]["applets"][0]["config"] = {
            "/Bogus": {"launchers": DOCK_LAUNCHERS}
        }
        with self.assertRaises(LayoutError):
            validate_live(live_script(layout))

    def test_trailing_code_fails(self) -> None:
        with self.assertRaises(LayoutError):
            validate_live(live_script(valid_live_layout()) + "doSomethingUnsafe();\n")


class PersistedLayoutTests(unittest.TestCase):
    def test_exact_persisted_layout_passes(self) -> None:
        validate_config(valid_persisted_config())

    def test_swapped_panel_locations_fail(self) -> None:
        config = valid_persisted_config().replace("location=3", "location=9", 1)
        with self.assertRaises(LayoutError):
            validate_config(config)

    def test_wrong_applet_order_fails(self) -> None:
        config = valid_persisted_config().replace(
            "AppletOrder=11;12;13;14", "AppletOrder=14;13;12;11"
        )
        with self.assertRaises(LayoutError):
            validate_config(config)

    def test_launcher_string_in_unrelated_group_fails(self) -> None:
        config = valid_persisted_config().replace(
            f"[Containments][20][Applets][21][Configuration][General]\nlaunchers={DOCK_LAUNCHERS}",
            f"[Containments][20][Bogus]\nlaunchers={DOCK_LAUNCHERS}",
        )
        with self.assertRaises(LayoutError):
            validate_config(config)

    def test_duplicate_key_fails(self) -> None:
        config = valid_persisted_config().replace(
            "plugin=org.kde.panel", "plugin=org.kde.panel\nplugin=org.kde.panel", 1
        )
        with self.assertRaises(LayoutError):
            validate_config(config)


if __name__ == "__main__":
    unittest.main()
