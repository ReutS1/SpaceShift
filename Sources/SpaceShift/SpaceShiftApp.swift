// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

enum AppPreferences {
    /// When true, the settings window is not shown at launch; SpaceShift
    /// starts with only its menu bar icon.
    static let startHiddenKey = "startHiddenInMenuBar"

    static var startHidden: Bool {
        UserDefaults.standard.bool(forKey: startHiddenKey)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Opens the settings window. Provided by the menu bar label, which is
    /// the only SwiftUI view guaranteed to exist when the window is hidden.
    var openMainWindow: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if AppPreferences.startHidden {
            closeMainWindows()
        }
    }

    /// SwiftUI opens (or restores) the settings window during launch.
    /// `defaultLaunchBehavior(.suppressed)` would avoid that, but it needs
    /// macOS 15 and cannot be applied conditionally inside a `SceneBuilder`.
    private func closeMainWindows() {
        for window in NSApp.windows where window.identifier?.rawValue.hasPrefix("main") == true {
            window.close()
        }
    }

    /// Opening the app again (Finder, Spotlight, Dock) while it is already
    /// running in the menu bar brings the settings window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag, let openMainWindow else { return true }
        openMainWindow()
        NSApp.activate(ignoringOtherApps: true)
        return false
    }
}

@main
struct SpaceShiftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = MotionController()
    @StateObject private var launchAtLogin = LaunchAtLoginManager()

    var body: some Scene {
        WindowGroup("SpaceShift", id: "main") {
            ContentView(controller: controller, launchAtLogin: launchAtLogin)
                .frame(width: 480)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Window("Donate", id: "donate") {
            DonationView()
                .frame(width: 420)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarView(controller: controller, launchAtLogin: launchAtLogin)
        } label: {
            MenuBarLabel(appDelegate: appDelegate)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarLabel: View {
    let appDelegate: AppDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "rectangle.2.swap")
            .accessibilityLabel("SpaceShift")
            .onAppear {
                appDelegate.openMainWindow = { openWindow(id: "main") }
            }
    }
}

private struct MenuBarView: View {
    @ObservedObject var controller: MotionController
    @ObservedObject var launchAtLogin: LaunchAtLoginManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("Enabled", isOn: $controller.isEnabled)

        Toggle("Launch at Login", isOn: Binding(
            get: { launchAtLogin.isEnabled },
            set: { launchAtLogin.setEnabled($0) }
        ))

        Menu("Speed  \(controller.approximateMultiplier)") {
            speedButton("1×", 40)
            speedButton("1.5×", 60)
            speedButton("2×", 80)
            speedButton("2.5×", 100)
        }

        Divider()

        Button("Test Right") { controller.testRight() }
            .disabled(!controller.isRunning)

        Button("Open SpaceShift…") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("About SpaceShift") {
            let sourceText = "github.com/ReutS1/SpaceShift"
            let credits = NSMutableAttributedString(
                string: "Licensed under GNU GPL v3.0.\nSource code: \(sourceText)"
            )
            credits.addAttribute(
                .link,
                value: URL(string: "https://github.com/ReutS1/SpaceShift")!,
                range: (credits.string as NSString).range(of: sourceText)
            )
            NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Donate ☕️") {
            openWindow(id: "donate")
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        Button("Quit SpaceShift") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    @ViewBuilder
    private func speedButton(_ title: String, _ value: Double) -> some View {
        Button {
            controller.setPreset(value)
        } label: {
            if abs(controller.speed - value) < 1 {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}
