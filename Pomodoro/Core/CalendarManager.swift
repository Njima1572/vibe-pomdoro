import EventKit
import AppKit

/// Manages calendar integration via EventKit.
/// Creates events in a dedicated "Pomodoro" calendar when focus sessions complete.
class CalendarManager {
    static let shared = CalendarManager()

    private let eventStore = EKEventStore()
    private let calendarTitle = "Pomodoro"
    private let calendarColorHex = NSColor.systemRed
    private let calendarIdKey = "pomodoroCalendarIdentifier"

    // MARK: - Authorization

    /// Current authorization status
    var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// Request full calendar access. Returns true if granted.
    func requestAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            print("📅 Calendar access request failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Calendar

    /// Find or create the dedicated "Pomodoro" calendar.
    private func pomodoroCalendar() -> EKCalendar? {
        // Try cached identifier first
        if let savedId = UserDefaults.standard.string(forKey: calendarIdKey),
           let calendar = eventStore.calendar(withIdentifier: savedId) {
            return calendar
        }

        // Search existing calendars by title
        let existing = eventStore.calendars(for: .event).first { $0.title == calendarTitle }
        if let existing {
            UserDefaults.standard.set(existing.calendarIdentifier, forKey: calendarIdKey)
            return existing
        }

        // Create a new calendar
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarTitle
        calendar.cgColor = calendarColorHex.cgColor

        // Use the default calendar source (iCloud, local, etc.)
        if let defaultSource = eventStore.defaultCalendarForNewEvents?.source {
            calendar.source = defaultSource
        } else if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = localSource
        } else {
            print("📅 No calendar source available")
            return nil
        }

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            UserDefaults.standard.set(calendar.calendarIdentifier, forKey: calendarIdKey)
            print("📅 Created 'Pomodoro' calendar")
            return calendar
        } catch {
            print("📅 Failed to create calendar: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Event Logging

    /// Log a completed focus session as a calendar event.
    /// - Parameters:
    ///   - taskTitle: The task the user was working on (nil if empty)
    ///   - duration: Session duration in seconds
    ///   - sessionNumber: The completed session number (1-based)
    ///   - endDate: When the session ended (defaults to now)
    func logSession(
        taskTitle: String?,
        duration: Int,
        sessionNumber: Int,
        endDate: Date = Date()
    ) {
        guard isAuthorized else {
            print("📅 Calendar not authorized, skipping event creation")
            return
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            guard let calendar = self.pomodoroCalendar() else { return }

            let event = EKEvent(eventStore: self.eventStore)

            // Title
            if let title = taskTitle, !title.isEmpty {
                event.title = "🍅 Focus: \(title)"
            } else {
                event.title = "🍅 Focus Session"
            }

            // Time
            event.startDate = endDate.addingTimeInterval(-Double(duration))
            event.endDate = endDate

            // Notes
            let minutes = duration / 60
            event.notes = "Session #\(sessionNumber) · \(minutes) min"

            // Calendar
            event.calendar = calendar

            do {
                try self.eventStore.save(event, span: .thisEvent)
                print("📅 Logged session #\(sessionNumber) to calendar")
            } catch {
                print("📅 Failed to save event: \(error.localizedDescription)")
            }
        }
    }
}
