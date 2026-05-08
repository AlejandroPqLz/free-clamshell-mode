import SwiftUI
import AppKit
@preconcurrency import UserNotifications
import ServiceManagement

@main
struct FreeClamshellApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - Settings

struct SettingsManager {
    private enum Key {
        static let hideFromDock = "hideFromDock"
        static let showWarnings = "showWarnings"
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.hideFromDock: true,
            Key.showWarnings: true,
        ])
    }

    var hideFromDock: Bool {
        get { UserDefaults.standard.bool(forKey: Key.hideFromDock) }
        set { UserDefaults.standard.set(newValue, forKey: Key.hideFromDock) }
    }

    var showWarnings: Bool {
        get { UserDefaults.standard.bool(forKey: Key.showWarnings) }
        set { UserDefaults.standard.set(newValue, forKey: Key.showWarnings) }
    }

    var isLaunchAtLoginEnabled: Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    mutating func toggleLaunchAtLogin() throws {
        guard #available(macOS 13.0, *) else { return }
        if SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
        } else {
            try SMAppService.mainApp.register()
        }
    }
}

// MARK: - Sudoers

enum SudoersManager {
    static let filePath = "/etc/sudoers.d/free-clamshell-mode"
    private static let pmsetPath = "/usr/bin/pmset"

    static func isConfigured(forUser username: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", "/usr/bin/pmset", "-g", "custom"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    // MUST be called from a background thread — blocks while the macOS password dialog is open.
    static func configure(forUser username: String) -> String? {
        let line = expectedLine(forUser: username)
        let shellCmd = """
            printf '%s\\n' '\(line)' > /tmp/free_clamshell_sudoers \
            && visudo -c -f /tmp/free_clamshell_sudoers \
            && install -o root -g wheel -m 0440 /tmp/free_clamshell_sudoers \(filePath) \
            && rm -f /tmp/free_clamshell_sudoers
            """
        let escaped = shellCmd.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let errPipe = Pipe()
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "Could not launch osascript: \(error.localizedDescription)"
        }

        if process.terminationStatus == 0 { return nil }
        let data = errPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? "Unknown error (status \(process.terminationStatus))"
    }

    private static func expectedLine(forUser username: String) -> String {
        "\(username) ALL=(ALL) NOPASSWD: \(pmsetPath)\n"
    }
}

// MARK: - Toggle Menu Item View

class ToggleMenuItemView: NSView {
    static let itemWidth: CGFloat  = 230
    static let itemHeight: CGFloat = 28

    private let titleLabel = NSTextField(labelWithString: "")
    private var toggleSwitch: NSSwitch?
    private var activeBackground: NSColor?
    private var modeColor: NSColor?
    private var isHovered = false

    var onToggle: (() -> Void)?

    func setActive(_ active: Bool) {
        activeBackground = active ? modeColor : nil
        needsDisplay = true
    }

    init(title: String, isOn: Bool, dotColor: NSColor? = nil,
         activeBackground: NSColor? = nil, showSwitch: Bool = true) {
        self.modeColor = activeBackground
        self.activeBackground = isOn ? activeBackground : nil
        super.init(frame: NSRect(x: 0, y: 0, width: Self.itemWidth, height: Self.itemHeight))

        var rightEdge = Self.itemWidth - 12

        if showSwitch {
            let sw = NSSwitch()
            sw.controlSize = .small
            sw.sizeToFit()
            sw.state = isOn ? .on : .off
            sw.target = self
            sw.action = #selector(switchChanged)
            sw.appearance = NSApp.effectiveAppearance
            sw.frame = NSRect(
                x: Self.itemWidth - sw.frame.width - 12,
                y: (Self.itemHeight - sw.frame.height) / 2,
                width: sw.frame.width,
                height: sw.frame.height
            )
            addSubview(sw)
            toggleSwitch = sw
            rightEdge = sw.frame.minX - 8
        }

        var x: CGFloat = 14
        if let color = dotColor {
            let d: CGFloat = 10
            let dot = NSView(frame: NSRect(x: x, y: (Self.itemHeight - d) / 2, width: d, height: d))
            dot.wantsLayer = true
            dot.layer?.backgroundColor = color.cgColor
            dot.layer?.cornerRadius = d / 2
            addSubview(dot)
            x += d + 8
        }

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize)
        titleLabel.isEditable = false
        titleLabel.isBezeled = false
        titleLabel.backgroundColor = .clear
        titleLabel.frame = NSRect(x: x, y: (Self.itemHeight - 17) / 2,
                                   width: rightEdge - x, height: 17)
        addSubview(titleLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        toggleSwitch?.appearance = NSApp.effectiveAppearance
        toggleSwitch?.needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeAlways],
                                       owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true;  needsDisplay = true }
    override func mouseExited(with event: NSEvent)  { isHovered = false; needsDisplay = true }

    @objc private func switchChanged() { onToggle?() }

    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if let sw = toggleSwitch {
            if !sw.frame.contains(loc) { sw.performClick(self) }
        } else {
            onToggle?()
        }
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 4, dy: 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        if let bg = activeBackground {
            bg.withAlphaComponent(0.30).setFill()
            path.fill()
        }
        if isHovered {
            NSColor.labelColor.withAlphaComponent(0.09).setFill()
            path.fill()
        }
        super.draw(dirtyRect)
    }
}

// MARK: - App Delegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem?
    var isActive = false
    var settings = SettingsManager()
    var toggleView: ToggleMenuItemView?

    let activeColor = NSColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0)

    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsManager.registerDefaults()
        applyDockPolicy()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()

        statusItem?.button?.target = self
        statusItem?.button?.action = #selector(handleClick(_:))
        statusItem?.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    func applicationWillTerminate(_ notification: Notification) {
        if isActive { runSudoPmset(value: 0) }
    }

    func applyDockPolicy() {
        NSApp.setActivationPolicy(settings.hideFromDock ? .accessory : .regular)
    }

    // MARK: Menu

    @objc func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        let isRightClick = event.type == .rightMouseUp ||
            (event.type == .leftMouseUp && event.modifierFlags.contains(.control))
        if isRightClick {
            let menu = NSMenu()
            menu.delegate = self
            statusItem?.menu = menu
            sender.performClick(nil)
        } else {
            toggle()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        let item = NSMenuItem(title: "Free Clamshell", action: nil, keyEquivalent: "")
        let view = ToggleMenuItemView(
            title: "Free Clamshell", isOn: isActive,
            dotColor: activeColor, activeBackground: activeColor, showSwitch: false
        )
        toggleView = view
        view.onToggle = { [weak self] in self?.toggle() }
        item.view = view
        menu.addItem(item)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        settingsItem.submenu = buildSettingsSubmenu()
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    func buildSettingsSubmenu() -> NSMenu {
        let sub = NSMenu()

        func toggleItem(title: String, isOn: Bool, action: @escaping () -> Void) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let view = ToggleMenuItemView(title: title, isOn: isOn)
            view.onToggle = action
            item.view = view
            return item
        }

        sub.addItem(toggleItem(title: "Launch at Login", isOn: settings.isLaunchAtLoginEnabled) { [weak self] in self?.toggleLaunchAtLogin() })
        sub.addItem(toggleItem(title: "Hide from Dock",  isOn: settings.hideFromDock)            { [weak self] in self?.toggleHideFromDock() })
        sub.addItem(.separator())
        sub.addItem(toggleItem(title: "Show Warnings",   isOn: settings.showWarnings)            { [weak self] in self?.toggleShowWarnings() })

        return sub
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem?.menu = nil
        toggleView = nil
    }

    // MARK: Toggle

    func toggle() {
        statusItem?.menu?.cancelTracking()
        if isActive {
            deactivate(silent: false)
        } else {
            activateWithConfirmation()
        }
    }

    func activateWithConfirmation() {
        if settings.showWarnings {
            let alert = NSAlert()
            alert.messageText = "Enable Free Clamshell?"
            alert.informativeText = "Your Mac will stay awake with the lid closed even without AC power. Battery drains faster."
            alert.addButton(withTitle: "Enable")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .warning
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        let username = NSUserName()
        if !SudoersManager.isConfigured(forUser: username) {
            let alert = NSAlert()
            alert.messageText = "Administrator Access Required"
            alert.informativeText = """
                Free Clamshell needs one-time access to configure passwordless \
                'pmset' so you won't be prompted every time.

                This writes one line to \(SudoersManager.filePath):
                  \(username) ALL=(ALL) NOPASSWD: /usr/bin/pmset

                You will be asked for your administrator password once.
                """
            alert.addButton(withTitle: "Configure Access")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .informational
            guard alert.runModal() == .alertFirstButtonReturn else { return }

            Task.detached(priority: .userInitiated) {
                let error = SudoersManager.configure(forUser: username)
                await MainActor.run {
                    if let msg = error {
                        let errAlert = NSAlert()
                        errAlert.messageText = "Could Not Configure Access"
                        errAlert.informativeText = msg.isEmpty ? "Setup was cancelled." : msg
                        errAlert.alertStyle = .warning
                        errAlert.runModal()
                    } else {
                        self.runPmsetAndFinalize(value: 1)
                    }
                }
            }
            return
        }

        runPmsetAndFinalize(value: 1)
    }

    func runPmsetAndFinalize(value: Int) {
        if let error = runSudoPmset(value: value) {
            showNotification(title: "Error", subtitle: error)
            return
        }
        isActive = (value == 1)
        updateIcon()
        toggleView?.setActive(isActive)
        let subtitle = "sudo pmset -a disablesleep \(value)"
        showNotification(title: isActive ? "Free Clamshell enabled" : "Free Clamshell disabled",
                         subtitle: subtitle)
    }

    func deactivate(silent: Bool) {
        if let error = runSudoPmset(value: 0), !silent {
            showNotification(title: "Error", subtitle: error)
        }
        isActive = false
        updateIcon()
        toggleView?.setActive(false)
        if !silent {
            showNotification(title: "Free Clamshell disabled", subtitle: "")
        }
    }

    @discardableResult
    func runSudoPmset(value: Int) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["/usr/bin/pmset", "-a", "disablesleep", "\(value)"]
        let errPipe = Pipe()
        process.standardError = errPipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "Could not run pmset: \(error.localizedDescription)"
        }
        if process.terminationStatus != 0 {
            let data = errPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? "pmset failed (status \(process.terminationStatus))"
        }
        return nil
    }

    // MARK: Icon

    func updateIcon() {
        statusItem?.button?.image = makeShellIcon(active: isActive)
    }

    func makeShellIcon(active: Bool) -> NSImage {
        let symbolName = active ? "fossil.shell.fill" : "fossil.shell"
        var config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        if active {
            config = config.applying(
                NSImage.SymbolConfiguration(paletteColors: [activeColor])
            )
        }
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) ?? NSImage()
        image.isTemplate = !active
        return image
    }

    // MARK: Settings Actions

    @objc func toggleLaunchAtLogin() {
        do {
            try settings.toggleLaunchAtLogin()
        } catch {
            showNotification(title: "Error", subtitle: "Could not change Launch at Login")
        }
    }

    @objc func toggleHideFromDock() {
        settings.hideFromDock.toggle()
        applyDockPolicy()
    }

    @objc func toggleShowWarnings() {
        settings.showWarnings.toggle()
    }

    // MARK: Notifications

    func showNotification(title: String, subtitle: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            if !subtitle.isEmpty { content.subtitle = subtitle }
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            center.add(request)
        }
    }
}