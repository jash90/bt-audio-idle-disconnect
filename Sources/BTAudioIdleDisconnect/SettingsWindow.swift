import AppKit
import SwiftUI

enum SettingsTab: Hashable {
    case general, devices, apps, about
}

final class SettingsTabSelection: ObservableObject {
    @Published var tab: SettingsTab = .general
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let selection = SettingsTabSelection()

    init(
        settings: SettingsStore,
        bluetoothManager: BluetoothManager,
        idleController: IdleController
    ) {
        let view = SettingsView(
            settings: settings,
            bluetoothManager: bluetoothManager,
            idleController: idleController,
            selection: selection
        )
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = L10n.tr("BT Audio Idle — Preferences")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 620, height: 520))
        super.init(window: window)
        window.center()
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func selectTab(_ tab: SettingsTab) {
        selection.tab = tab
    }
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    let bluetoothManager: BluetoothManager
    let idleController: IdleController
    @ObservedObject var selection: SettingsTabSelection

    var body: some View {
        TabView(selection: $selection.tab) {
            GeneralTab(settings: settings)
                .tabItem { Label(L10n.tr("General"), systemImage: "gearshape") }
                .tag(SettingsTab.general)
            DevicesTab(
                settings: settings,
                bluetoothManager: bluetoothManager,
                idleController: idleController
            )
                .tabItem { Label(L10n.tr("Devices"), systemImage: "headphones") }
                .tag(SettingsTab.devices)
            AppsTab(settings: settings)
                .tabItem { Label(L10n.tr("Apps"), systemImage: "app.badge") }
                .tag(SettingsTab.apps)
            AboutTab()
                .tabItem { Label(L10n.tr("About"), systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(minWidth: 600, minHeight: 500)
        .padding()
    }
}

private struct GeneralTab: View {
    @ObservedObject var settings: SettingsStore
    @State private var loginAtStart: Bool = LoginItemManager.shared.isEnabled
    @State private var loginStatus: String = LoginItemManager.shared.localizedStatusDescription

    var body: some View {
        Form {
            Section(L10n.tr("Timing")) {
                SliderRow(
                    title: L10n.tr("Idle timeout"),
                    value: Binding(
                        get: { settings.settings.globalTimeoutSeconds / 60 },
                        set: { settings.settings.globalTimeoutSeconds = $0 * 60 }
                    ),
                    range: 1...60, step: 1,
                    formatter: { L10n.tr("%ld min", Int($0)) }
                )
                SliderRow(
                    title: L10n.tr("Pre-disconnect grace"),
                    value: Binding(
                        get: { settings.settings.preDisconnectGraceSeconds },
                        set: { settings.settings.preDisconnectGraceSeconds = $0 }
                    ),
                    range: 0...120, step: 5,
                    formatter: { L10n.tr("%lds", Int($0)) }
                )
                SliderRow(
                    title: L10n.tr("Snooze on cancel"),
                    value: Binding(
                        get: { settings.settings.snoozeOnCancelSeconds / 60 },
                        set: { settings.settings.snoozeOnCancelSeconds = $0 * 60 }
                    ),
                    range: 1...60, step: 1,
                    formatter: { L10n.tr("%ld min", Int($0)) }
                )
                SliderRow(
                    title: L10n.tr("Confirm playback after"),
                    value: Binding(
                        get: { settings.settings.playbackConfirmSeconds },
                        set: { settings.settings.playbackConfirmSeconds = $0 }
                    ),
                    range: 0...15, step: 1,
                    formatter: { L10n.tr("%lds", Int($0)) }
                )
                Text(L10n.tr("Audio shorter than this counts as a system beep, not playback, and does not reset the idle timer."))
                    .font(.caption).foregroundColor(.secondary)
                SliderRow(
                    title: L10n.tr("Reconnect cooldown"),
                    value: Binding(
                        get: { settings.settings.reconnectCooldownSeconds },
                        set: { settings.settings.reconnectCooldownSeconds = $0 }
                    ),
                    range: 0...300, step: 30,
                    formatter: { L10n.tr("%lds", Int($0)) }
                )
            }
            Section(L10n.tr("Behavior")) {
                Toggle(L10n.tr("Notify before disconnecting"), isOn: Binding(
                    get: { settings.settings.notificationsEnabled },
                    set: { settings.settings.notificationsEnabled = $0 }
                ))
                Toggle(L10n.tr("Play a sound with that notification"), isOn: Binding(
                    get: { settings.settings.notificationSoundEnabled },
                    set: { settings.settings.notificationSoundEnabled = $0 }
                ))
                .disabled(!settings.settings.notificationsEnabled)
                Toggle(L10n.tr("Pause timer when system sleeps"), isOn: Binding(
                    get: { settings.settings.pauseOnSleep },
                    set: { settings.settings.pauseOnSleep = $0 }
                ))
                Toggle(L10n.tr("Disconnect immediately on system sleep"), isOn: Binding(
                    get: { settings.settings.disconnectOnSleep },
                    set: { settings.settings.disconnectOnSleep = $0 }
                ))
            }
            Section(L10n.tr("Launch & Updates")) {
                Toggle(L10n.tr("Launch at login"), isOn: Binding(
                    get: { loginAtStart },
                    set: { newValue in
                        loginAtStart = newValue
                        LoginItemManager.shared.setEnabled(newValue)
                        loginStatus = LoginItemManager.shared.localizedStatusDescription
                    }
                ))
                Text(L10n.tr("Status: %@", loginStatus)).font(.caption).foregroundColor(.secondary)
                Toggle(L10n.tr("Check for updates automatically"), isOn: Binding(
                    get: { settings.settings.autoCheckForUpdates },
                    set: { settings.settings.autoCheckForUpdates = $0 }
                ))
                Text(lastCheckedText).font(.caption).foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var lastCheckedText: String {
        guard let last = settings.settings.lastUpdateCheck else { return L10n.tr("Last checked: never") }
        return L10n.tr("Last checked: %@", last.formatted(date: .abbreviated, time: .shortened))
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: TimeInterval
    let range: ClosedRange<TimeInterval>
    let step: TimeInterval
    let formatter: (TimeInterval) -> String

    var body: some View {
        HStack {
            Text(title)
            Slider(value: $value, in: range, step: step)
            Text(formatter(value)).frame(width: 70, alignment: .trailing).monospacedDigit()
        }
    }
}

private struct DevicesTab: View {
    @ObservedObject var settings: SettingsStore
    let bluetoothManager: BluetoothManager
    let idleController: IdleController
    @State private var devices: [BTDeviceInfo] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.tr("Paired Bluetooth audio devices")).font(.headline)
                Spacer()
                Button(L10n.tr("Refresh")) { reload() }
            }

            if devices.isEmpty {
                Spacer()
                Text(L10n.tr("No paired Bluetooth audio devices found."))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(devices) { device in
                            DeviceRow(
                                settings: settings,
                                device: device,
                                onChange: { idleController.recomputeMonitoredState() }
                            )
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .onAppear { reload() }
    }

    private func reload() {
        devices = bluetoothManager.pairedAudioDeviceInfos()
        for d in devices where settings.deviceSettings(for: d.address) == nil {
            settings.upsertDevice(DeviceSettings(
                address: d.address, name: d.name,
                enabled: true, customTimeoutSeconds: nil
            ))
        }
    }
}

private struct DeviceRow: View {
    @ObservedObject var settings: SettingsStore
    let device: BTDeviceInfo
    let onChange: () -> Void

    var body: some View {
        let usingCustom = settings.deviceSettings(for: device.address)?.customTimeoutSeconds != nil
        let enabled = settings.deviceSettings(for: device.address)?.enabled ?? true

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading) {
                    Text(device.name).font(.body.weight(.medium))
                    Text(device.address).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if device.isConnected {
                    Label(L10n.tr("connected"), systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label(L10n.tr("offline"), systemImage: "moon.zzz")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Toggle(L10n.tr("Monitor"), isOn: Binding(
                    get: { enabled },
                    set: {
                        settings.setDeviceEnabled(address: device.address, enabled: $0)
                        onChange()
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
            HStack {
                Toggle(L10n.tr("Custom timeout"), isOn: Binding(
                    get: { usingCustom },
                    set: { newValue in
                        if newValue {
                            settings.setDeviceTimeout(
                                address: device.address,
                                timeout: settings.settings.globalTimeoutSeconds
                            )
                        } else {
                            settings.setDeviceTimeout(address: device.address, timeout: nil)
                        }
                        onChange()
                    }
                ))
                if usingCustom {
                    Slider(
                        value: Binding(
                            get: {
                                (settings.deviceSettings(for: device.address)?.customTimeoutSeconds
                                 ?? settings.settings.globalTimeoutSeconds) / 60
                            },
                            set: {
                                settings.setDeviceTimeout(address: device.address, timeout: $0 * 60)
                                onChange()
                            }
                        ),
                        in: 1...60, step: 1
                    )
                    Text(L10n.tr("%ld min", Int((settings.deviceSettings(for: device.address)?.customTimeoutSeconds ?? settings.settings.globalTimeoutSeconds) / 60)))
                        .frame(width: 60, alignment: .trailing).monospacedDigit()
                } else {
                    Text(L10n.tr("uses global (%ld min)", Int(settings.settings.globalTimeoutSeconds / 60)))
                        .font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }
}

private struct AppsTab: View {
    @ObservedObject var settings: SettingsStore
    @State private var pickerPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("Whitelist — keep BT audio connected while these apps run"))
                .font(.headline)
            Text(L10n.tr("Useful for video calls, music apps that pause without 'playing' state, etc."))
                .font(.caption).foregroundColor(.secondary)

            if settings.settings.whitelistApps.isEmpty {
                Spacer()
                Text(L10n.tr("No apps in whitelist.")).foregroundColor(.secondary).frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(settings.settings.whitelistApps) { rule in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(rule.displayName)
                                    Text(rule.bundleId).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: { remove(rule) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
                        }
                    }
                }
            }

            HStack {
                Button(L10n.tr("Add running app…")) { pickerPresented = true }
                Spacer()
            }
        }
        .padding()
        .sheet(isPresented: $pickerPresented) {
            AddAppSheet(
                onPick: { app in
                    addRule(bundleId: app.bundleId, name: app.name)
                    pickerPresented = false
                },
                onCancel: { pickerPresented = false }
            )
        }
    }

    private func addRule(bundleId: String, name: String) {
        guard !settings.settings.whitelistApps.contains(where: { $0.bundleId == bundleId }) else { return }
        settings.settings.whitelistApps.append(AppRule(bundleId: bundleId, displayName: name))
    }

    private func remove(_ rule: AppRule) {
        settings.settings.whitelistApps.removeAll { $0.bundleId == rule.bundleId }
    }
}

private struct AddAppSheet: View {
    let onPick: ((bundleId: String, name: String)) -> Void
    let onCancel: () -> Void

    @State private var filter: String = ""
    @State private var apps: [(bundleId: String, name: String)] = []

    var filtered: [(bundleId: String, name: String)] {
        let sorted = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if filter.isEmpty { return sorted }
        return sorted.filter {
            $0.name.localizedCaseInsensitiveContains(filter) ||
            $0.bundleId.localizedCaseInsensitiveContains(filter)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(L10n.tr("Pick an app to whitelist")).font(.headline)
                Spacer()
                Button(L10n.tr("Cancel"), action: onCancel).keyboardShortcut(.escape, modifiers: [])
            }
            TextField(L10n.tr("Filter by name or bundle id"), text: $filter)
                .textFieldStyle(.roundedBorder)

            List(filtered, id: \.bundleId) { item in
                Button(action: { onPick(item) }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.name)
                            Text(item.bundleId).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(width: 520, height: 420)
        .onAppear { apps = AppRunningMonitor().allRunningApps() }
    }
}

private struct AboutTab: View {
    var body: some View {
        ScrollView {
            content
                .padding(24)
                .frame(maxWidth: .infinity)
        }
    }

    private var content: some View {
        VStack(spacing: 12) {
            Image(systemName: "headphones")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text(verbatim: "BT Audio Idle Disconnect").font(.title2.weight(.semibold))
            Text(L10n.tr("Version %@ (build %@)", UpdateChecker.currentVersionString, UpdateChecker.currentBuildString))
                .font(.callout)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
            Text(L10n.tr("Disconnects paired Bluetooth audio devices after a configurable idle period."))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            Divider().padding(.vertical, 8)
            UpdatesSection(updater: UpdateChecker.shared)
            Divider().padding(.vertical, 8)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("Log file:")).font(.caption).foregroundColor(.secondary)
                Text(AppLogger.shared.logFileURL.path)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            Button(L10n.tr("Open log file")) {
                NSWorkspace.shared.open(AppLogger.shared.logFileURL)
            }
            Divider().padding(.vertical, 8)
            VStack(spacing: 4) {
                Text(L10n.tr("Developer")).font(.caption).foregroundColor(.secondary)
                Text(verbatim: "Bartłomiej Zimny").font(.callout.weight(.medium))
                Link("raccoonsoftware.pl", destination: URL(string: "https://raccoonsoftware.pl")!)
                    .font(.callout)
                Link("bartlomiejzimny@outlook.com", destination: URL(string: "mailto:bartlomiejzimny@outlook.com")!)
                    .font(.callout)
            }
        }
    }
}

private struct UpdatesSection: View {
    @ObservedObject var updater: UpdateChecker

    var body: some View {
        VStack(spacing: 8) {
            Text(L10n.tr("Updates")).font(.caption).foregroundColor(.secondary)
            switch updater.state {
            case .idle:
                checkButton(L10n.tr("Check for Updates"))
            case .checking:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(L10n.tr("Checking for updates…"))
                }
            case .upToDate:
                Text(L10n.tr("You're up to date.")).font(.callout)
                checkButton(L10n.tr("Check Again"))
            case .available(let release):
                available(release)
            case .downloading(let progress):
                ProgressView(value: progress) {
                    Text(L10n.tr("Downloading update… %ld%%", Int(progress * 100))).font(.callout)
                }
                .frame(maxWidth: 320)
            case .installing:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(L10n.tr("Installing — the app will relaunch."))
                }
            case .manualInstallRequired:
                Text(L10n.tr("The app's folder isn't writable, so the update was verified and its disk image opened. Drag BT Audio Idle onto Applications to finish."))
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            case .failed(let message):
                Text(message)
                    .font(.callout)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                checkButton(L10n.tr("Try Again"))
            }
        }
    }

    private func checkButton(_ title: String) -> some View {
        Button(title) { updater.check(userInitiated: true) }
    }

    @ViewBuilder
    private func available(_ release: Release) -> some View {
        Text(L10n.tr("Version %1$@ is available — you have %2$@.", release.displayVersion, UpdateChecker.currentVersionString))
            .font(.callout.weight(.medium))
        if let notes = release.body?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            ScrollView {
                Text(Self.markdown(notes))
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(height: 140)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)))
            .padding(.horizontal)
        }
        HStack(spacing: 12) {
            Button(L10n.tr("Download & Install")) { updater.downloadAndInstall() }
                .keyboardShortcut(.defaultAction)
                .disabled(release.dmgAsset == nil)
            Link(L10n.tr("View on GitHub"), destination: release.htmlURL)
        }
    }

    private static func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
