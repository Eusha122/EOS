// EOS Privet's first-session layout for Plasma 6.
// This owns the complete panel layout so Debian's default launchers cannot
// leak into the live session as blank icons.

var wallpaperUri = "file:///usr/share/wallpapers/EOSPrivet/contents/images/1672x941.png";
var dockLaunchers = [
    "applications:void-browser.desktop",
    "applications:org.kde.dolphin.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:eos-welcome.desktop"
].join(",");

function widgetAvailable(pluginId) {
    return knownWidgetTypes.indexOf(pluginId) !== -1;
}

function addWidgetIfAvailable(panel, pluginId) {
    if (!widgetAvailable(pluginId)) {
        print("EOS layout: missing optional widget " + pluginId);
        return null;
    }
    return panel.addWidget(pluginId);
}

// Applying this layout is deliberately idempotent. A versioned migration may
// evaluate it once to repair a bad first login without creating extra panels.
var oldPanels = panels();
for (var p = 0; p < oldPanels.length; p++) {
    oldPanels[p].remove();
}

var activityDesktops = desktopsForActivity(currentActivity());
if (activityDesktops.length === 0) {
    activityDesktops = desktops();
}
for (var d = 0; d < activityDesktops.length; d++) {
    activityDesktops[d].wallpaperPlugin = "org.kde.image";
    activityDesktops[d].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    activityDesktops[d].writeConfig("Image", wallpaperUri);
    activityDesktops[d].writeConfig("FillMode", 2);
}

// A slim status bar keeps system controls visible without copying Apple UI.
var topBar = new Panel();
topBar.location = "top";
topBar.lengthMode = "fill";
topBar.hiding = "none";
topBar.height = Math.round(gridUnit * 1.9);

var launcher = addWidgetIfAvailable(topBar, "org.kde.plasma.kickoff");
if (launcher !== null) {
    launcher.currentConfigGroup = ["General"];
    launcher.writeConfig("icon", "eos-privet");
    launcher.globalShortcut = "Alt+F1";
}
addWidgetIfAvailable(topBar, "org.kde.plasma.panelspacer");
addWidgetIfAvailable(topBar, "org.kde.plasma.systemtray");
addWidgetIfAvailable(topBar, "org.kde.plasma.digitalclock");

// Plasma's native panel is used as the dock for reliable Wayland behaviour.
var dock = new Panel();
dock.location = "bottom";
dock.lengthMode = "fit";
dock.alignment = "center";
dock.hiding = "dodgewindows";
dock.height = Math.round(gridUnit * 3.2);

var tasks = addWidgetIfAvailable(dock, "org.kde.plasma.icontasks");
if (tasks !== null) {
    tasks.currentConfigGroup = ["General"];
    tasks.writeConfig("launchers", dockLaunchers);
    tasks.writeConfig("showOnlyCurrentActivity", true);
    tasks.writeConfig("showOnlyCurrentDesktop", false);
}
addWidgetIfAvailable(dock, "org.kde.plasma.showdesktop");
