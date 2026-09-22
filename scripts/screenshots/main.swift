import AppKit
import Darwin

// Screenshot harness entry point — replaces Sources/.../main.swift in the harness build.
// Drives the app's real SettingsWindowController, MenuBarController and IdleController,
// fed with fictional settings and devices, and renders their windows to PNG in-process
// via CGWindowListCreateImage (own windows need no Screen Recording permission).
//
// Usage: BTAudioIdleScreenshots <output-dir> <light|dark>

let args = CommandLine.arguments
let outDir = URL(fileURLWithPath: args.count > 1 ? args[1] : "/tmp/bt-audio-idle-shots", isDirectory: true)
let appearanceName = args.count > 2 ? args[2] : "light"
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.appearance = NSAppearance(named: appearanceName == "dark" ? .darkAqua : .aqua)

func log(_ s: String) { FileHandle.standardError.write(Data("[harness] \(s)\n".utf8)) }

func seedFictionalSettings() {
    var s = GlobalSettings()
    s.globalTimeoutSeconds = 600
    s.preDisconnectGraceSeconds = 30
    s.snoozeOnCancelSeconds = 300
    s.devices = [
        DeviceSettings(address: "0a-1b-2c-3d-4e-01", name: "Studio Headphones", enabled: true, customTimeoutSeconds: nil),
        DeviceSettings(address: "0a-1b-2c-3d-4e-02", name: "Kitchen Speaker", enabled: true, customTimeoutSeconds: 1200),
        DeviceSettings(address: "0a-1b-2c-3d-4e-03", name: "Running Earbuds", enabled: true, customTimeoutSeconds: nil),
        DeviceSettings(address: "0a-1b-2c-3d-4e-04", name: "Office Headset", enabled: false, customTimeoutSeconds: nil),
    ]
    s.whitelistApps = [
        AppRule(bundleId: "us.zoom.xos", displayName: "zoom.us"),
        AppRule(bundleId: "com.microsoft.teams2", displayName: "Microsoft Teams"),
        AppRule(bundleId: "com.apple.FaceTime", displayName: "FaceTime"),
    ]
    SettingsStore.shared.settings = s
}

typealias CGWindowListCreateImageFn = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?

/// CGWindowListCreateImage is marked unavailable in the macOS 15+ SDK but still ships;
/// for windows owned by the calling process it needs no Screen Recording permission.
let windowListCreateImage: CGWindowListCreateImageFn? = {
    guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") else { return nil }
    return unsafeBitCast(sym, to: CGWindowListCreateImageFn.self)
}()

func serverSnapshot(windowNumber: Int, name: String) -> Bool {
    guard let fn = windowListCreateImage else { log("dlsym failed"); return false }
    // kCGWindowListOptionIncludingWindow = 1<<3, kCGWindowImageBoundsIgnoreFraming = 1<<0, BestResolution = 1<<3
    guard let img = fn(.null, 1 << 3, UInt32(windowNumber), (1 << 0) | (1 << 3))?.takeRetainedValue() else {
        log("server capture failed for \(name)"); return false
    }
    write(rep: NSBitmapImageRep(cgImage: img), name: name)
    return true
}

func write(rep: NSBitmapImageRep, name: String) {
    let url = outDir.appendingPathComponent("\(name)-\(appearanceName).png")
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: url)
    log("wrote \(url.path) \(rep.pixelsWide)x\(rep.pixelsHigh)")
}

func findTabView(in view: NSView) -> NSTabView? {
    if let t = view as? NSTabView { return t }
    for sub in view.subviews { if let t = findTabView(in: sub) { return t } }
    return nil
}

func dump(_ view: NSView, depth: Int = 0) {
    guard depth < 14 else { return }
    log(String(repeating: "  ", count: depth) + String(describing: type(of: view)) + " \(view.frame)")
    view.subviews.forEach { dump($0, depth: depth + 1) }
}

/// Pumps the run loop so SwiftUI can lay out, animations settle and timers tick.
func settle(_ seconds: TimeInterval) {
    RunLoop.main.run(until: Date().addingTimeInterval(seconds))
}

seedFictionalSettings()

let bluetoothManager = BluetoothManager()
let idleController = IdleController(
    bluetoothManager: bluetoothManager,
    appRunningMonitor: AppRunningMonitor(),
    settings: SettingsStore.shared,
    notifications: NotificationManager.shared
)
let menuBar = MenuBarController(
    idleController: idleController,
    bluetoothManager: bluetoothManager,
    settings: SettingsStore.shared
)

// Nothing is playing: arms the idle countdown exactly like AudioMonitor would report.
idleController.audioPlaybackChanged(isPlaying: false)

app.finishLaunching()
app.activate(ignoringOtherApps: true)

let settingsWC = SettingsWindowController(
    settings: SettingsStore.shared,
    bluetoothManager: bluetoothManager,
    idleController: idleController
)
settingsWC.showWindow(nil)
settle(1.5)

guard let window = settingsWC.window else { fatalError("no settings window") }
if ProcessInfo.processInfo.environment["HARNESS_DUMP"] != nil, let root = window.contentView?.superview {
    dump(root)
}

let tabs: [(index: Int, name: String)] = [(0, "general"), (1, "devices"), (2, "apps"), (3, "about")]
if let tabView = findTabView(in: window.contentView!) {
    for tab in tabs {
        tabView.selectTabViewItem(at: tab.index)
        settle(1.0)
        _ = serverSnapshot(windowNumber: window.windowNumber, name: "preferences-\(tab.name)")
    }
} else {
    log("NSTabView not found — capturing the default tab only")
    _ = serverSnapshot(windowNumber: window.windowNumber, name: "preferences-general")
}

// The menu bar item and its dropdown are not captured: on macOS 26 they are not
// windows this process can image without Screen Recording permission.

_ = menuBar
exit(0)
