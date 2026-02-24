import SwiftUI

// MARK: - Settings Window Controller

/// Manages a standalone settings window, since MenuBarExtra apps
/// can't reliably use the built-in Settings scene.
class SettingsWindowController: ObservableObject {
    private var window: NSWindow?
    
    func open(timerManager: PomodoroTimerManager) {
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView(timerManager: timerManager)
        let hostingView = NSHostingView(rootView: settingsView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pomodoro Settings"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

@main
struct PomodoroApp: App {
    @StateObject private var timerManager = PomodoroTimerManager()
    @StateObject private var settingsController = SettingsWindowController()
    @StateObject private var tunnelManager = TunnelManager()
    private let hotkeyManager = HotkeyManager()

    var body: some Scene {
        // Menu Bar Extra — the main interface
        MenuBarExtra {
            MenuBarView(timerManager: timerManager, settingsController: settingsController, tunnelManager: tunnelManager)
                .onAppear {
                    syncShortcuts()
                }
                .onChange(of: timerManager.configuration.globalShortcutsEnabled) { _ in
                    syncShortcuts()
                }
        } label: {
            MenuBarLabel(timerManager: timerManager)
        }
        .menuBarExtraStyle(.window)
    }

    private func syncShortcuts() {
        if timerManager.configuration.globalShortcutsEnabled {
            hotkeyManager.register(timerManager: timerManager, settingsController: settingsController)
        } else {
            hotkeyManager.unregister()
        }
    }
}

// MARK: - Menu Bar Label

struct MenuBarLabel: View {
    @ObservedObject var timerManager: PomodoroTimerManager

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: menuBarIcon)
                .font(.system(size: 13))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor)

            if timerManager.state.phase != .idle {
                Text(timerManager.state.shortFormattedTime)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .monospacedDigit()
            }
        }
    }

    private var menuBarIcon: String {
        switch timerManager.state.phase {
        case .idle: return "timer"
        case .work: return timerManager.state.isRunning ? "flame.fill" : "flame"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "leaf.fill"
        }
    }

    private var iconColor: Color {
        switch timerManager.state.phase {
        case .idle: return .secondary
        case .work: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }
}
