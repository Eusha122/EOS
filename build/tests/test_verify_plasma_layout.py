#!/usr/bin/python3
"""Regression tests for the shipped EOS Plasma layout verifier."""

from __future__ import annotations

import copy
import json
import re
import runpy
import subprocess
import sys
import unittest
from pathlib import Path


sys.dont_write_bytecode = True


PROJECT_ROOT = Path(__file__).resolve().parents[2]
VERIFIER = (
    PROJECT_ROOT
    / "build/live-build-config/includes.chroot/usr/local/lib/eos-privet/verify-plasma-layout"
)
DESKTOP_SETUP = (
    PROJECT_ROOT
    / "build/live-build-config/includes.chroot/usr/local/bin/eos-desktop-setup"
)
LAYOUT_SCRIPT = (
    PROJECT_ROOT
    / "build/live-build-config/includes.chroot/usr/share/plasma/look-and-feel/"
    "org.eos.privet.desktop/contents/layouts/org.kde.plasma.desktop-layout.js"
)
WELCOME_SCRIPT = (
    PROJECT_ROOT / "build/live-build-config/includes.chroot/usr/local/bin/eos-welcome"
)
WALLPAPER_SCRIPT = (
    PROJECT_ROOT / "build/live-build-config/includes.chroot/usr/local/bin/eos-wallpapers"
)
MODULE = runpy.run_path(str(VERIFIER), run_name="eos_layout_verifier")
LayoutError = MODULE["LayoutError"]
validate_live = MODULE["validate_live"]
validate_config = MODULE["validate_config"]
compare_live = MODULE["compare_live"]
WALLPAPER_URI = MODULE["WALLPAPER_URI"]
DOCK_LAUNCHERS = MODULE["DOCK_LAUNCHERS"]


def live_script(layout: dict) -> str:
    return (
        "var plasma = getApiVersion(1);\n\nvar layout = "
        + json.dumps(layout, indent=4)
        + "\n;\n\nplasma.loadSerializedLayout(layout);\n"
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
                "alignment": "left",
                "hiding": "normal",
                "height": 1.9,
                "applets": [
                    {
                        "plugin": "org.kde.plasma.kickoff",
                        "config": {"/General": {"icon": "eos-privet"}},
                    },
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
                "height": 3.2,
                "applets": [
                    {
                        "plugin": "org.kde.plasma.icontasks",
                        "config": {
                            "/General": {
                                "launchers": DOCK_LAUNCHERS,
                                "showOnlyCurrentActivity": "true",
                                "showOnlyCurrentDesktop": "false",
                            }
                        },
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

[Containments][10][Applets][11][Configuration][General]
icon=eos-privet

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
showOnlyCurrentActivity=true
showOnlyCurrentDesktop=false

[Containments][20][Applets][22]
plugin=org.kde.plasma.showdesktop
"""


def valid_persisted_shell_config() -> str:
    return """[PlasmaViews][Panel 10]
alignment=1
panelLengthMode=0
panelVisibility=0

[PlasmaViews][Panel 10][Defaults]
thickness=15

[PlasmaViews][Panel 20]
alignment=132
panelLengthMode=1
panelVisibility=2

[PlasmaViews][Panel 20][Defaults]
thickness=26
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

    def test_plasma_63_dump_without_live_length_mode_passes(self) -> None:
        layout = valid_live_layout()
        del layout["panels"][0]["lengthMode"]
        del layout["panels"][1]["lengthMode"]
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

    def test_panels_only_allows_wallpaper_to_finish_loading(self) -> None:
        layout = valid_live_layout()
        layout["desktops"][0]["wallpaperPlugin"] = "org.kde.color"
        layout["desktops"][0]["config"] = {}
        validate_live(live_script(layout), require_wallpaper=False)

    def test_duplicate_json_key_fails(self) -> None:
        script = live_script(valid_live_layout()).replace(
            '"serializationFormatVersion": "1",',
            '"serializationFormatVersion": "1",\n    "serializationFormatVersion": "1",',
            1,
        )
        with self.assertRaises(LayoutError):
            validate_live(script)

    def test_launcher_string_in_unrelated_group_fails(self) -> None:
        layout = valid_live_layout()
        layout["panels"][1]["applets"][0]["config"] = {
            "/Bogus": {"launchers": DOCK_LAUNCHERS}
        }
        with self.assertRaises(LayoutError):
            validate_live(live_script(layout))

    def test_wrong_launcher_icon_fails(self) -> None:
        layout = valid_live_layout()
        layout["panels"][0]["applets"][0]["config"]["/General"]["icon"] = "start-here-kde"
        with self.assertRaises(LayoutError):
            validate_live(live_script(layout))

    def test_non_object_applet_cannot_be_filtered_out(self) -> None:
        layout = valid_live_layout()
        layout["panels"][0]["applets"].append("not-an-applet")
        with self.assertRaises(LayoutError):
            validate_live(live_script(layout))

    def test_wrong_top_alignment_fails(self) -> None:
        layout = valid_live_layout()
        layout["panels"][0]["alignment"] = "center"
        with self.assertRaises(LayoutError):
            validate_live(live_script(layout))

    def test_trailing_code_fails(self) -> None:
        with self.assertRaises(LayoutError):
            validate_live(live_script(valid_live_layout()) + "doSomethingUnsafe();\n")

    def test_non_plasma_json_terminator_fails(self) -> None:
        script = live_script(valid_live_layout()).replace(
            "\n;\n\nplasma.loadSerializedLayout", ";\n\nplasma.loadSerializedLayout", 1
        )
        with self.assertRaises(LayoutError):
            validate_live(script)

    def test_semantically_equal_live_snapshots_pass(self) -> None:
        first = live_script(valid_live_layout())
        second = first.replace('"serializationFormatVersion": "1"', '"serializationFormatVersion":"1"')
        compare_live(first, second)

    def test_different_live_snapshots_fail(self) -> None:
        first = live_script(valid_live_layout())
        changed = valid_live_layout()
        changed["panels"][1]["hiding"] = "normal"
        with self.assertRaises(LayoutError):
            compare_live(first, live_script(changed))


class PersistedLayoutTests(unittest.TestCase):
    def test_exact_persisted_layout_passes(self) -> None:
        validate_config(valid_persisted_config(), valid_persisted_shell_config())

    def test_inactive_activity_may_keep_its_own_wallpaper(self) -> None:
        config = valid_persisted_config() + """
[Containments][2]
activityId=inactive-activity
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.image

[Containments][2][Wallpaper][org.kde.image][General]
FillMode=2
Image=file:///tmp/inactive-wallpaper.png
"""
        validate_config(
            config,
            valid_persisted_shell_config(),
            activity_id="activity-one",
            expected_desktop_count=1,
        )
        with self.assertRaises(LayoutError):
            validate_config(
                config,
                valid_persisted_shell_config(),
                activity_id="activity-one",
                expected_desktop_count=2,
            )

    def test_inactive_eos_wallpaper_cannot_mask_wrong_current_wallpaper(self) -> None:
        config = valid_persisted_config().replace(
            f"Image={WALLPAPER_URI}", "Image=file:///tmp/wrong-current-wallpaper.png", 1
        ) + f"""
[Containments][2]
activityId=inactive-activity
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.image

[Containments][2][Wallpaper][org.kde.image][General]
FillMode=2
Image={WALLPAPER_URI}
"""
        with self.assertRaises(LayoutError):
            validate_config(
                config,
                valid_persisted_shell_config(),
                activity_id="activity-one",
                expected_desktop_count=1,
            )

    def test_swapped_panel_locations_fail(self) -> None:
        config = valid_persisted_config().replace("location=3", "location=9", 1)
        with self.assertRaises(LayoutError):
            validate_config(config, valid_persisted_shell_config())

    def test_wrong_applet_order_fails(self) -> None:
        config = valid_persisted_config().replace(
            "AppletOrder=11;12;13;14", "AppletOrder=14;13;12;11"
        )
        with self.assertRaises(LayoutError):
            validate_config(config, valid_persisted_shell_config())

    def test_persisted_applet_without_plugin_fails(self) -> None:
        config = valid_persisted_config().replace(
            "[Containments][10][Applets][14]\nplugin=org.kde.plasma.digitalclock",
            "[Containments][10][Applets][14]",
        )
        with self.assertRaises(LayoutError):
            validate_config(config, valid_persisted_shell_config())

    def test_launcher_string_in_unrelated_group_fails(self) -> None:
        config = valid_persisted_config().replace(
            f"[Containments][20][Applets][21][Configuration][General]\nlaunchers={DOCK_LAUNCHERS}",
            f"[Containments][20][Bogus]\nlaunchers={DOCK_LAUNCHERS}",
        )
        with self.assertRaises(LayoutError):
            validate_config(config, valid_persisted_shell_config())

    def test_duplicate_key_fails(self) -> None:
        config = valid_persisted_config().replace(
            "plugin=org.kde.panel", "plugin=org.kde.panel\nplugin=org.kde.panel", 1
        )
        with self.assertRaises(LayoutError):
            validate_config(config, valid_persisted_shell_config())

    def test_kconfig_keys_are_case_sensitive(self) -> None:
        config = valid_persisted_config().replace("wallpaperplugin=", "WallpaperPlugin=", 1)
        with self.assertRaises(LayoutError):
            validate_config(config, valid_persisted_shell_config())

    def test_wallpaper_in_unrelated_kconfig_group_fails(self) -> None:
        config = valid_persisted_config().replace(
            "[Containments][1][Wallpaper][org.kde.image][General]",
            "[Containments][1][Bogus]",
            1,
        )
        with self.assertRaises(LayoutError):
            validate_config(config, valid_persisted_shell_config())

    def test_wrong_dock_alignment_fails(self) -> None:
        shell_config = valid_persisted_shell_config().replace("alignment=132", "alignment=0")
        with self.assertRaises(LayoutError):
            validate_config(valid_persisted_config(), shell_config)

    def test_missing_default_dock_alignment_passes(self) -> None:
        shell_config = valid_persisted_shell_config().replace("alignment=132\n", "")
        validate_config(valid_persisted_config(), shell_config)

    def test_missing_default_top_thickness_passes_when_pair_matches(self) -> None:
        shell_config = valid_persisted_shell_config().replace("thickness=15\n", "")
        shell_config = shell_config.replace("thickness=26\n", "thickness=51\n")
        validate_config(valid_persisted_config(), shell_config)

    def test_wrong_dock_visibility_fails(self) -> None:
        shell_config = valid_persisted_shell_config().replace(
            "panelVisibility=2", "panelVisibility=0"
        )
        with self.assertRaises(LayoutError):
            validate_config(valid_persisted_config(), shell_config)

    def test_wrong_panel_thickness_pair_fails(self) -> None:
        shell_config = valid_persisted_shell_config().replace("thickness=26", "thickness=27")
        with self.assertRaises(LayoutError):
            validate_config(valid_persisted_config(), shell_config)

    def test_impossible_odd_grid_unit_thickness_pair_fails(self) -> None:
        shell_config = valid_persisted_shell_config().replace("thickness=15", "thickness=17")
        shell_config = shell_config.replace("thickness=26", "thickness=29")
        with self.assertRaises(LayoutError):
            validate_config(valid_persisted_config(), shell_config)

    def test_panel_view_ids_must_match_containment_ids(self) -> None:
        shell_config = valid_persisted_shell_config().replace("Panel 20", "Panel 21")
        with self.assertRaises(LayoutError):
            validate_config(valid_persisted_config(), shell_config)


class DesktopSetupContractTests(unittest.TestCase):
    def test_every_persisted_verification_is_bound_to_current_activity(self) -> None:
        setup = DESKTOP_SETUP.read_text(encoding="utf-8")
        self.assertEqual(setup.count('--activity-id "$current_activity"'), 2)
        self.assertIn("org.kde.ActivityManager.Activities.CurrentActivity", setup)
        self.assertNotIn("plasma-apply-wallpaperimage", setup)
        self.assertEqual(setup.count("visual_preferences_match ||"), 2)
        layout = LAYOUT_SCRIPT.read_text(encoding="utf-8")
        self.assertNotIn("activityDesktops = desktops()", layout)
        welcome = WELCOME_SCRIPT.read_text(encoding="utf-8")
        self.assertIn('session_mode_file=/run/eos-privet/session-mode', welcome)
        self.assertIn('= fresh ] || exit 0', welcome)
        wallpaper_picker = WALLPAPER_SCRIPT.read_text(encoding="utf-8")
        self.assertNotIn("plasma-apply-wallpaperimage", wallpaper_picker)
        self.assertNotIn("activityDesktops = desktops()", wallpaper_picker)
        self.assertIn("desktopsForActivity(expectedActivity)", wallpaper_picker)

    def test_wallpaper_picker_javascript_is_valid(self) -> None:
        wallpaper_picker = WALLPAPER_SCRIPT.read_text(encoding="utf-8")
        match = re.search(
            r'\nplasma_script="\n(?P<script>.*?)\n"\n\nif ! apply_result=',
            wallpaper_picker,
            flags=re.DOTALL,
        )
        self.assertIsNotNone(match)
        script = match.group("script").replace(r'\"', '"')
        script = script.replace("$activity_id", "11111111-1111-4111-8111-111111111111")
        script = script.replace(
            "$wallpaper_uri",
            "file:///usr/share/wallpapers/EOSPrivet/contents/images/1672x941.png",
        )
        result = subprocess.run(
            ["node", "--check"],
            input=script,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
