import SwiftUI

struct MenuBarView: View {
    @ObservedObject var timerManager: PomodoroTimerManager
    @ObservedObject var settingsController: SettingsWindowController
    @ObservedObject var tunnelManager: TunnelManager

    var body: some View {
        VStack(spacing: 0) {
            // Phase header
            phaseHeader
                .padding(.horizontal, 20)
                .padding(.top, 16)

            // Task title
            taskTitleField
                .padding(.horizontal, 20)
                .padding(.top, 4)

            // Timer ring
            timerRing
                .padding(.vertical, 16)

            // Controls
            controlButtons
                .padding(.horizontal, 20)

            // Session progress
            sessionProgress
                .padding(.horizontal, 20)
                .padding(.top, 12)

            Divider()
                .padding(.top, 16)

            // Bottom actions
            bottomActions
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(width: 280)
    }

    // MARK: - Phase Header

    private var phaseHeader: some View {
        HStack {
            Text(timerManager.state.phase.emoji)
                .font(.title2)

            Text(timerManager.state.phase.displayName)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(phaseColor)

            Spacer()

            if timerManager.state.phase != .idle {
                statusBadge
            }
        }
    }

    private var taskTitleField: some View {
        TextField("What are you working on?", text: $timerManager.taskTitle)
            .textFieldStyle(.plain)
            .font(.system(size: 12, design: .rounded))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    private var statusBadge: some View {
        Text(timerManager.state.isRunning ? "RUNNING" : "PAUSED")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(timerManager.state.isRunning ? Color.green : Color.orange)
            )
    }

    // MARK: - Timer Ring

    private var timerRing: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(phaseColor.opacity(0.15), lineWidth: 8)
                .frame(width: 140, height: 140)

            // Progress ring
            Circle()
                .trim(from: 0, to: timerManager.state.progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [phaseColor.opacity(0.6), phaseColor]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: timerManager.state.progress)

            // Time display
            VStack(spacing: 2) {
                Text(timerManager.state.formattedTime)
                    .font(.system(size: 36, weight: .light, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                if timerManager.state.phase != .idle {
                    Text(timerManager.state.phase.isBreak ? "Relax" : "Stay focused")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Controls

    private var controlButtons: some View {
        HStack(spacing: 12) {
            // Reset button
            Button {
                timerManager.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.quaternary)
                    )
            }
            .buttonStyle(.plain)
            .disabled(timerManager.state.phase == .idle)

            // Play/Pause button
            Button {
                timerManager.toggleStartPause()
            } label: {
                Image(systemName: timerManager.state.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(phaseColor.gradient)
                            .shadow(color: phaseColor.opacity(0.4), radius: 8, y: 4)
                    )
            }
            .buttonStyle(.plain)

            // Skip button
            Button {
                timerManager.skip()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.quaternary)
                    )
            }
            .buttonStyle(.plain)
            .disabled(timerManager.state.phase == .idle)
        }
    }

    // MARK: - Session Progress

    private var sessionProgress: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Sessions")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(timerManager.state.completedPomodoros) completed")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach(0..<timerManager.configuration.pomodorosUntilLongBreak, id: \.self) { index in
                    Circle()
                        .fill(
                            index < (timerManager.state.completedPomodoros % timerManager.configuration.pomodorosUntilLongBreak)
                                ? phaseColor
                                : phaseColor.opacity(0.2)
                        )
                        .frame(width: 10, height: 10)
                        .animation(.spring(response: 0.3), value: timerManager.state.completedPomodoros)
                }
                Spacer()
            }
        }
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(spacing: 0) {
            Button {
                timerManager.openWebUI()
            } label: {
                Label("Open Web Dashboard", systemImage: "globe")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Tunnel toggle
            if TunnelManager.isCloudflaredInstalled {
                Divider()

                Button {
                    if tunnelManager.isRunning {
                        tunnelManager.stop()
                    } else {
                        tunnelManager.start(localPort: AppConstants.httpPort)
                    }
                } label: {
                    HStack {
                        Label(
                            tunnelManager.isRunning ? "Stop Tunnel" : "Share via Tunnel",
                            systemImage: tunnelManager.isRunning ? "icloud.fill" : "icloud"
                        )
                        Spacer()
                        if tunnelManager.isRunning {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if let url = tunnelManager.tunnelURL {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url, forType: .string)
                    } label: {
                        HStack {
                            Text(url)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.blue)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            Button {
                settingsController.open(timerManager: timerManager)
            } label: {
                Label("Settings…", systemImage: "gear")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Pomodoro", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    // MARK: - Colors

    private var phaseColor: Color {
        switch timerManager.state.phase {
        case .idle: return .gray
        case .work: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }
}
