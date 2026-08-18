import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: MotionController
    @ObservedObject var launchAtLogin: LaunchAtLoginManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 24) {
            header
            if !controller.hasAccessibilityPermission { permissionRow }
            speedControl
            launchAtLoginRow
            statusRow
        }
        .padding(28)
        .background {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.accentColor.opacity(0.045)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .onAppear { launchAtLogin.refresh() }
    }

    private var header: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.accentColor.gradient)
                    .frame(width: 44, height: 44)
                Image(systemName: "rectangle.2.swap")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("SpaceShift")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Spacer()
            Button {
                openWindow(id: "donate")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "cup.and.saucer.fill")
            }
            .buttonStyle(.borderless)
            .help("Donate")
            Toggle("", isOn: $controller.isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private var permissionRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .foregroundStyle(Color.accentColor)
            Text("Accessibility permission required")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Button("Allow…") { controller.requestAccessibilityPermission() }
                .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var speedControl: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Speed")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(controller.approximateMultiplier)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
            }
            Slider(value: $controller.speed, in: 40...100, step: 5)
                .disabled(!controller.isEnabled)
        }
        .padding(17)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var statusRow: some View {
        HStack {
            Circle()
                .fill(controller.isRunning ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(controller.isRunning ? "Active" : controller.message)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Test →") { controller.testRight() }
                .buttonStyle(.bordered)
                .disabled(!controller.isRunning)
        }
    }

    private var launchAtLoginRow: some View {
        HStack {
            Image(systemName: "power")
                .foregroundStyle(.secondary)
            Text("Launch at Login")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Toggle("", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
    }
}
