import SwiftUI

struct SettingsView: View {
    @ObservedObject var timerManager: PomodoroTimerManager

    @State private var workMinutes: Int
    @State private var shortBreakMinutes: Int
    @State private var longBreakMinutes: Int
    @State private var pomodorosUntilLongBreak: Double
    @State private var autoStartBreaks: Bool
    @State private var autoStartPomodoros: Bool
    @State private var playSoundAlert: Bool
    @State private var showNotificationAlert: Bool
    @State private var showFullScreenAlert: Bool
    @State private var globalShortcutsEnabled: Bool
    @State private var addToCalendar: Bool

    init(timerManager: PomodoroTimerManager) {
        self.timerManager = timerManager
        let config = timerManager.configuration
        _workMinutes = State(initialValue: config.workDuration / 60)
        _shortBreakMinutes = State(initialValue: config.shortBreakDuration / 60)
        _longBreakMinutes = State(initialValue: config.longBreakDuration / 60)
        _pomodorosUntilLongBreak = State(initialValue: Double(config.pomodorosUntilLongBreak))
        _autoStartBreaks = State(initialValue: config.autoStartBreaks)
        _autoStartPomodoros = State(initialValue: config.autoStartPomodoros)
        _playSoundAlert = State(initialValue: config.playSoundAlert)
        _showNotificationAlert = State(initialValue: config.showNotificationAlert)
        _showFullScreenAlert = State(initialValue: config.showFullScreenAlert)
        _globalShortcutsEnabled = State(initialValue: config.globalShortcutsEnabled)
        _addToCalendar = State(initialValue: config.addToCalendar)
    }

    var body: some View {
        TabView {
            timerSettings
                .tabItem {
                    Label("Timer", systemImage: "timer")
                }

            syncSettings
                .tabItem {
                    Label("Sync", systemImage: "qrcode")
                }

            aboutView
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 460, height: 520)
    }

    // MARK: - Timer Settings

    private var timerSettings: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    durationField(
                        title: "Focus Duration",
                        value: $workMinutes,
                        icon: "flame.fill",
                        color: .red
                    )

                    durationField(
                        title: "Short Break",
                        value: $shortBreakMinutes,
                        icon: "cup.and.saucer.fill",
                        color: .green
                    )

                    durationField(
                        title: "Long Break",
                        value: $longBreakMinutes,
                        icon: "leaf.fill",
                        color: .blue
                    )
                }

                Section {
                    HStack {
                        Label("Sessions until long break", systemImage: "repeat")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { Int(pomodorosUntilLongBreak) },
                            set: { pomodorosUntilLongBreak = Double($0) }
                        )) {
                            ForEach(2...8, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .frame(width: 60)
                    }
                }

                Section {
                    Toggle("Auto-start breaks", isOn: $autoStartBreaks)
                    Toggle("Auto-start focus sessions", isOn: $autoStartPomodoros)
                }

                Section("Alerts") {
                    Toggle("Sound", isOn: $playSoundAlert)
                    Toggle("Notification banner", isOn: $showNotificationAlert)
                    Toggle("Full-screen overlay", isOn: $showFullScreenAlert)
                }

                Section("Shortcuts") {
                    Toggle("Global keyboard shortcuts", isOn: $globalShortcutsEnabled)
                    if globalShortcutsEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            shortcutRow("⌃⌥P", "Show / hide timer")
                            shortcutRow("⌃⌥Space", "Play / pause")
                            shortcutRow("⌃⌥R", "Reset")
                            shortcutRow("⌃⌥S", "Skip phase")
                            shortcutRow("⌃⌥,", "Open settings")
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Integrations") {
                    Toggle("Add sessions to Calendar", isOn: $addToCalendar)
                        .onChange(of: addToCalendar) { _, enabled in
                            if enabled {
                                Task {
                                    let granted = await CalendarManager.shared.requestAccess()
                                    if !granted {
                                        await MainActor.run { addToCalendar = false }
                                    }
                                }
                            }
                        }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Apply") {
                    applySettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private func durationField(
        title: String,
        value: Binding<Int>,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                Spacer()
                TextField("", value: value, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                Text("min")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0) }
                ),
                in: 1...60,
                step: 1
            )
            .tint(color)
        }
    }

    private func applySettings() {
        timerManager.configuration = TimerConfiguration(
            workDuration: workMinutes * 60,
            shortBreakDuration: shortBreakMinutes * 60,
            longBreakDuration: longBreakMinutes * 60,
            pomodorosUntilLongBreak: Int(pomodorosUntilLongBreak),
            autoStartBreaks: autoStartBreaks,
            autoStartPomodoros: autoStartPomodoros,
            playSoundAlert: playSoundAlert,
            showNotificationAlert: showNotificationAlert,
            showFullScreenAlert: showFullScreenAlert,
            globalShortcutsEnabled: globalShortcutsEnabled,
            addToCalendar: addToCalendar
        )
    }

    private func shortcutRow(_ shortcut: String, _ action: String) -> some View {
        HStack {
            Text(shortcut)
                .frame(width: 70, alignment: .leading)
            Text(action)
        }
    }

    // MARK: - Server Settings

    private var syncSettings: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 8)

            // QR Code
            if let qrImage = NetworkUtils.generateQRCode(from: NetworkUtils.dashboardURL, size: 160) {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            }

            Text("Scan to sync on another device")
                .font(.system(.headline, design: .rounded))

            // URL display with copy button
            HStack(spacing: 8) {
                Text(NetworkUtils.dashboardURL)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.blue)
                    .textSelection(.enabled)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(NetworkUtils.dashboardURL, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy URL")

                Button {
                    timerManager.openWebUI()
                } label: {
                    Image(systemName: "safari")
                }
                .buttonStyle(.borderless)
                .help("Open in browser")
            }

            Divider().padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 6) {
                Label("Open this URL on any device on the same WiFi", systemImage: "wifi")
                Label("Timer state syncs in real-time via WebSocket", systemImage: "bolt.horizontal.fill")
                Label("No account or login required", systemImage: "lock.open.fill")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            if NetworkUtils.localIPAddress == nil {
                Label("No network connection detected", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - About

    private var aboutView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "timer")
                .font(.system(size: 48))
                .foregroundStyle(.red.gradient)

            Text("Pomodoro")
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)

            Text("A beautiful Pomodoro timer for your Mac menu bar\nwith synchronized web dashboard")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("v1.0.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding()
    }
}
