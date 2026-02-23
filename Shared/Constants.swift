import Foundation

enum AppConstants {
    static let appGroupIdentifier = "group.com.kochi.pomodoro"
    static let httpPort: UInt16 = 8094
    static let webSocketPort: UInt16 = 8095

    // UserDefaults keys for shared state
    static let timerStateKey = "timerState"
    static let timerConfigKey = "timerConfig"
    static let lastUpdateKey = "lastUpdate"

    // Widget kind
    static let widgetKind = "PomodoroWidget"
}

// Shared UserDefaults accessor
extension UserDefaults {
    static var shared: UserDefaults {
        UserDefaults(suiteName: AppConstants.appGroupIdentifier) ?? .standard
    }
}
