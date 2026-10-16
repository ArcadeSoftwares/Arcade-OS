// ─── TOP BAR ────────────────────────────────────────────────────
var topPanel = new Panel
topPanel.location = "top"
topPanel.height = Math.round(gridUnit * 1.8)
topPanel.floating = true
topPanel.hiding = "none"
topPanel.lengthMode = "fill"

topPanel.addWidget("org.kde.plasma.kickoff")
topPanel.addWidget("org.kde.plasma.appmenu")
topPanel.addWidget("org.kde.plasma.panelspacer")

topPanel.addWidget("org.kde.plasma.arcadeprivacyindicator")
topPanel.addWidget("org.kde.plasma.marginsseparator")
topPanel.addWidget("org.kde.plasma.marginsseparator")

// Media — auto-hides when nothing playing
var media = topPanel.addWidget("org.kde.plasma.mediacontroller")
media.currentConfigGroup = ["General"]
media.writeConfig("displayWhenNoPlayer", false)

topPanel.addWidget("org.kde.plasma.marginsseparator")

// Tray — ONLY VPN + screen recording, everything else suppressed
var tray = topPanel.addWidget("org.kde.plasma.systemtray")
tray.currentConfigGroup = ["General"]
tray.writeConfig("knownItems", [
    "org.kde.plasma.screenrecording",
    "org.kde.plasma.vpn",
    "org.kde.plasma.privacy",
    "org.kde.plasma.battery",
    "org.kde.plasma.volume",
    "org.kde.plasma.brightness",
    "org.kde.plasma.networkmanagement",
    "org.kde.plasma.bluetooth",
    "org.kde.kscreen",
    "org.kde.plasma.clipboard",
    "org.kde.plasma.notifications",
    "org.kde.plasma.mediacontroller",
])
tray.writeConfig("hiddenItems", [
    "org.kde.plasma.privacy",
    "org.kde.plasma.battery",
    "org.kde.plasma.volume",
    "org.kde.plasma.brightness",
    "org.kde.plasma.networkmanagement",
    "org.kde.plasma.bluetooth",
    "org.kde.kscreen",
    "org.kde.plasma.clipboard",
    "org.kde.plasma.notifications",
    "org.kde.plasma.mediacontroller",
])
tray.writeConfig("shownItems", [
    "org.kde.plasma.screenrecording",
    "org.kde.plasma.vpn",
])
topPanel.addWidget("org.kde.plasma.marginsseparator")
topPanel.addWidget("org.kde.plasma.marginsseparator")
topPanel.addWidget("org.kde.plasma.networkmanagement")  
topPanel.addWidget("org.kde.plasma.marginsseparator") 
topPanel.addWidget("org.kde.plasma.marginsseparator")// wifi standalone
topPanel.addWidget("org.kde.plasma.arcadebattery") // your battery
topPanel.addWidget("org.kde.plasma.marginsseparator")

// Control Center button — triggers your custom dropdown
// topPanel.addWidget("org.kde.plasma.arcadecontrolcenter")

topPanel.addWidget("org.kde.plasma.marginsseparator")

// Clock — precise format
var clock = topPanel.addWidget("org.kde.plasma.digitalclock")
clock.currentConfigGroup = ["Appearance"]
clock.writeConfig("showDate", "true")
clock.writeConfig("dateFormat", "custom")
clock.writeConfig("customDateFormat", "ddd, d MMM")
clock.writeConfig("showSeconds", "false")
clock.writeConfig("use24hFormat", "0")

topPanel.opacity = "translucent"



// ─── BOTTOM FLOATING DOCK ───────────────────────────────────────
var dock = new Panel
dock.location = "bottom"
dock.height = 64
dock.floating = true
dock.hiding = "none"
dock.lengthMode = "fit"
dock.alignment = "center"

var tasks = dock.addWidget("org.kde.plasma.icontasks")
tasks.currentConfigGroup = ["General"]
tasks.writeConfig("launchers", [
    "preferred://filemanager",
    "applications:org.kde.konsole.desktop",
    "preferred://browser",
    "applications:org.kde.plasma-systemmonitor.desktop",
    "applications:systemsettings.desktop",
])

dock.opacity = "translucent"

