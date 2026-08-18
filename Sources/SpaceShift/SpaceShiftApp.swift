import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
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
            Image(systemName: "rectangle.2.swap")
                .accessibilityLabel("SpaceShift")
        }
        .menuBarExtraStyle(.menu)
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
            NSApp.orderFrontStandardAboutPanel(options: [:])
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
