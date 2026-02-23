import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct PomodoroTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> PomodoroEntry {
        PomodoroEntry(
            date: Date(),
            phase: .work,
            remainingSeconds: 1500,
            totalSeconds: 1500,
            isRunning: true,
            completedPomodoros: 2,
            pomodorosUntilLongBreak: 4
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PomodoroEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PomodoroEntry>) -> Void) {
        let entry = currentEntry()

        // If timer is running, refresh more frequently
        let refreshDate: Date
        if entry.isRunning {
            refreshDate = Date().addingTimeInterval(15) // Refresh every 15 seconds when active
        } else {
            refreshDate = Date().addingTimeInterval(300) // Every 5 minutes when idle
        }

        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func currentEntry() -> PomodoroEntry {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)

        guard let stateJson = defaults?.string(forKey: AppConstants.timerStateKey),
              let state = TimerState.fromJSON(stateJson) else {
            return PomodoroEntry(
                date: Date(),
                phase: .idle,
                remainingSeconds: 1500,
                totalSeconds: 1500,
                isRunning: false,
                completedPomodoros: 0,
                pomodorosUntilLongBreak: 4
            )
        }

        // Adjust remaining time based on elapsed time since last update
        var adjustedRemaining = state.remainingSeconds
        if state.isRunning, let lastUpdate = defaults?.double(forKey: AppConstants.lastUpdateKey), lastUpdate > 0 {
            let elapsed = Int(Date().timeIntervalSince1970 - lastUpdate)
            adjustedRemaining = max(0, state.remainingSeconds - elapsed)
        }

        return PomodoroEntry(
            date: Date(),
            phase: state.phase,
            remainingSeconds: adjustedRemaining,
            totalSeconds: state.totalSeconds,
            isRunning: state.isRunning,
            completedPomodoros: state.completedPomodoros,
            pomodorosUntilLongBreak: state.pomodorosUntilLongBreak
        )
    }
}

// MARK: - Timeline Entry

struct PomodoroEntry: TimelineEntry {
    let date: Date
    let phase: TimerPhase
    let remainingSeconds: Int
    let totalSeconds: Int
    let isRunning: Bool
    let completedPomodoros: Int
    let pomodorosUntilLongBreak: Int

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Widget Views

struct PomodoroWidgetEntryView: View {
    var entry: PomodoroEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    // MARK: - Small Widget

    private var smallWidget: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(phaseColor.opacity(0.2), lineWidth: 6)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(phaseColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text(entry.formattedTime)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .monospacedDigit()

                    Text(entry.phase.emoji)
                        .font(.system(size: 12))
                }
            }

            Text(entry.phase.displayName)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .containerBackground(for: .widget) {
            Color(.windowBackgroundColor)
        }
    }

    // MARK: - Medium Widget

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            // Timer ring
            ZStack {
                Circle()
                    .stroke(phaseColor.opacity(0.2), lineWidth: 6)
                    .frame(width: 90, height: 90)

                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(phaseColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text(entry.formattedTime)
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(entry.phase.emoji)
                    Text(entry.phase.displayName)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.semibold)
                }

                Text(entry.isRunning ? "In Progress" : entry.phase == .idle ? "Ready to start" : "Paused")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)

                // Session dots
                HStack(spacing: 4) {
                    ForEach(0..<entry.pomodorosUntilLongBreak, id: \.self) { index in
                        Circle()
                            .fill(
                                index < (entry.completedPomodoros % entry.pomodorosUntilLongBreak)
                                    ? phaseColor
                                    : phaseColor.opacity(0.2)
                            )
                            .frame(width: 8, height: 8)
                    }

                    Spacer()

                    Text("\(entry.completedPomodoros) done")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.windowBackgroundColor)
        }
    }

    // MARK: - Colors

    private var phaseColor: Color {
        switch entry.phase {
        case .idle: return .gray
        case .work: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }
}

// MARK: - Widget Configuration

struct PomodoroWidget: Widget {
    let kind: String = AppConstants.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PomodoroTimelineProvider()) { entry in
            PomodoroWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Pomodoro Timer")
        .description("Track your focus sessions at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct PomodoroWidgetBundle: WidgetBundle {
    var body: some Widget {
        PomodoroWidget()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    PomodoroWidget()
} timeline: {
    PomodoroEntry(date: .now, phase: .work, remainingSeconds: 1234, totalSeconds: 1500, isRunning: true, completedPomodoros: 2, pomodorosUntilLongBreak: 4)
    PomodoroEntry(date: .now, phase: .shortBreak, remainingSeconds: 180, totalSeconds: 300, isRunning: true, completedPomodoros: 3, pomodorosUntilLongBreak: 4)
}

#Preview("Medium", as: .systemMedium) {
    PomodoroWidget()
} timeline: {
    PomodoroEntry(date: .now, phase: .work, remainingSeconds: 1234, totalSeconds: 1500, isRunning: true, completedPomodoros: 2, pomodorosUntilLongBreak: 4)
}
