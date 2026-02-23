import AppKit
import Carbon

/// Manages global keyboard shortcuts for the Pomodoro timer.
/// Uses Carbon hotkey API for reliable system-wide shortcuts.
class HotkeyManager {

    // MARK: - Shortcut Definitions

    /// Ctrl + Option + P     → Toggle floating panel
    /// Ctrl + Option + Space → Toggle play/pause
    /// Ctrl + Option + R     → Reset
    /// Ctrl + Option + S     → Skip
    /// Ctrl + Option + ,     → Open Settings

    struct Shortcut {
        let keyCode: UInt32
        let modifiers: UInt32
        let id: UInt32
        let label: String
    }

    static let modifiers: UInt32 = UInt32(controlKey | optionKey)

    static let shortcuts: [Shortcut] = [
        Shortcut(keyCode: UInt32(kVK_ANSI_P),  modifiers: modifiers, id: 5, label: "Panel (⌃⌥P)"),
        Shortcut(keyCode: UInt32(kVK_Space),   modifiers: modifiers, id: 1, label: "Toggle (⌃⌥Space)"),
        Shortcut(keyCode: UInt32(kVK_ANSI_R),  modifiers: modifiers, id: 2, label: "Reset (⌃⌥R)"),
        Shortcut(keyCode: UInt32(kVK_ANSI_S),  modifiers: modifiers, id: 3, label: "Skip (⌃⌥S)"),
        Shortcut(keyCode: UInt32(kVK_ANSI_Comma), modifiers: modifiers, id: 4, label: "Settings (⌃⌥,)")
    ]

    // MARK: - Properties

    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?
    private weak var timerManager: PomodoroTimerManager?
    private weak var settingsController: SettingsWindowController?
    private let floatingPanel = FloatingTimerPanel()

    // MARK: - Init

    func register(timerManager: PomodoroTimerManager, settingsController: SettingsWindowController) {
        // Unregister existing before re-registering
        unregister()

        self.timerManager = timerManager
        self.settingsController = settingsController

        // Install Carbon event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handlerResult = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )

        guard handlerResult == noErr else {
            print("⚠️ Failed to install hotkey handler: \(handlerResult)")
            return
        }

        // Register each shortcut
        for shortcut in Self.shortcuts {
            var hotKeyID = EventHotKeyID(signature: OSType(0x504F4D4F), id: shortcut.id) // "POMO"
            var hotKeyRef: EventHotKeyRef?

            let status = RegisterEventHotKey(
                shortcut.keyCode,
                shortcut.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            if status == noErr {
                hotKeyRefs.append(hotKeyRef)
                print("⌨️  Registered hotkey: \(shortcut.label)")
            } else {
                print("⚠️ Failed to register hotkey \(shortcut.label): \(status)")
                hotKeyRefs.append(nil)
            }
        }
    }

    func unregister() {
        for ref in hotKeyRefs {
            if let ref = ref {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()

        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    deinit {
        unregister()
    }

    // MARK: - Handler

    fileprivate func handleHotKey(id: UInt32) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            switch id {
            case 5: // Toggle floating panel
                if let tm = self.timerManager {
                    self.floatingPanel.toggle(timerManager: tm)
                }
            case 1: // Toggle play/pause
                self.timerManager?.toggleStartPause()
            case 2: // Reset
                self.timerManager?.reset()
            case 3: // Skip
                self.timerManager?.skip()
            case 4: // Settings
                if let tm = self.timerManager {
                    self.settingsController?.open(timerManager: tm)
                }
            default:
                break
            }
        }
    }
}

// MARK: - Carbon Event Handler (C callback)

private func hotKeyHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event, let userData = userData else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        UInt32(kEventParamDirectObject),
        UInt32(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    guard status == noErr else { return status }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handleHotKey(id: hotKeyID.id)

    return noErr
}
