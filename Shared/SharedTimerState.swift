import Foundation

// MARK: - Timer Phase

enum TimerPhase: String, Codable, Sendable {
    case idle
    case work
    case shortBreak
    case longBreak

    var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .work: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    var emoji: String {
        switch self {
        case .idle: return "🍅"
        case .work: return "🔥"
        case .shortBreak: return "☕"
        case .longBreak: return "🌿"
        }
    }

    var isBreak: Bool {
        self == .shortBreak || self == .longBreak
    }
}

// MARK: - Timer State

struct TimerState: Codable, Sendable {
    var phase: TimerPhase
    var remainingSeconds: Int
    var totalSeconds: Int
    var isRunning: Bool
    var completedPomodoros: Int
    var pomodorosUntilLongBreak: Int

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var shortFormattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static var idle: TimerState {
        TimerState(
            phase: .idle,
            remainingSeconds: 25 * 60,
            totalSeconds: 25 * 60,
            isRunning: false,
            completedPomodoros: 0,
            pomodorosUntilLongBreak: 4
        )
    }

    // JSON encoding for WebSocket communication
    var jsonString: String {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func fromJSON(_ json: String) -> TimerState? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let data = json.data(using: .utf8) else { return nil }
        return try? decoder.decode(TimerState.self, from: data)
    }
}

// MARK: - Timer Configuration

struct TimerConfiguration: Codable, Sendable, Equatable {
    var workDuration: Int
    var shortBreakDuration: Int
    var longBreakDuration: Int
    var pomodorosUntilLongBreak: Int
    var autoStartBreaks: Bool
    var autoStartPomodoros: Bool
    var playSoundAlert: Bool
    var showNotificationAlert: Bool
    var showFullScreenAlert: Bool
    var globalShortcutsEnabled: Bool
    var addToCalendar: Bool

    static var `default`: TimerConfiguration {
        TimerConfiguration(
            workDuration: 25 * 60,
            shortBreakDuration: 5 * 60,
            longBreakDuration: 15 * 60,
            pomodorosUntilLongBreak: 4,
            autoStartBreaks: true,
            autoStartPomodoros: false,
            playSoundAlert: true,
            showNotificationAlert: true,
            showFullScreenAlert: true,
            globalShortcutsEnabled: true,
            addToCalendar: false
        )
    }

    init(workDuration: Int, shortBreakDuration: Int, longBreakDuration: Int,
         pomodorosUntilLongBreak: Int, autoStartBreaks: Bool, autoStartPomodoros: Bool,
         playSoundAlert: Bool = true, showNotificationAlert: Bool = true,
         showFullScreenAlert: Bool = true, globalShortcutsEnabled: Bool = true,
         addToCalendar: Bool = false) {
        self.workDuration = workDuration
        self.shortBreakDuration = shortBreakDuration
        self.longBreakDuration = longBreakDuration
        self.pomodorosUntilLongBreak = pomodorosUntilLongBreak
        self.autoStartBreaks = autoStartBreaks
        self.autoStartPomodoros = autoStartPomodoros
        self.playSoundAlert = playSoundAlert
        self.showNotificationAlert = showNotificationAlert
        self.showFullScreenAlert = showFullScreenAlert
        self.globalShortcutsEnabled = globalShortcutsEnabled
        self.addToCalendar = addToCalendar
    }

    // Provide defaults for new fields so existing saved configs don't fail to decode
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workDuration = try container.decode(Int.self, forKey: .workDuration)
        shortBreakDuration = try container.decode(Int.self, forKey: .shortBreakDuration)
        longBreakDuration = try container.decode(Int.self, forKey: .longBreakDuration)
        pomodorosUntilLongBreak = try container.decode(Int.self, forKey: .pomodorosUntilLongBreak)
        autoStartBreaks = try container.decode(Bool.self, forKey: .autoStartBreaks)
        autoStartPomodoros = try container.decode(Bool.self, forKey: .autoStartPomodoros)
        playSoundAlert = try container.decodeIfPresent(Bool.self, forKey: .playSoundAlert) ?? true
        showNotificationAlert = try container.decodeIfPresent(Bool.self, forKey: .showNotificationAlert) ?? true
        showFullScreenAlert = try container.decodeIfPresent(Bool.self, forKey: .showFullScreenAlert) ?? true
        globalShortcutsEnabled = try container.decodeIfPresent(Bool.self, forKey: .globalShortcutsEnabled) ?? true
        addToCalendar = try container.decodeIfPresent(Bool.self, forKey: .addToCalendar) ?? false
    }

    var jsonString: String {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func fromJSON(_ json: String) -> TimerConfiguration? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let data = json.data(using: .utf8) else { return nil }
        return try? decoder.decode(TimerConfiguration.self, from: data)
    }
}
