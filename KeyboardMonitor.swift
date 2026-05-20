import Cocoa
import Carbon

// Standard Carbon Keycode Constants
private let kVK_Escape: CGKeyCode = 53
private let kVK_Return: CGKeyCode = 36
private let kVK_Tab: CGKeyCode = 48
private let kVK_Delete: CGKeyCode = 51
private let kVK_DownArrow: CGKeyCode = 125
private let kVK_UpArrow: CGKeyCode = 126

class KeyboardMonitor {
    static let shared = KeyboardMonitor()
    
    private var state: EmojiPickerState?
    private var window: CandidateWindow?
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // Prevent duplicate event taps from the permission timer
    private var isRunning = false
    
    // Buffering state — only accessed on main thread, no locks needed
    private var isBuffering = false
    private var buffer = ""
    
    // Apps that have their own emoji picker — skip ours when they're focused
    private let excludedBundleIDs: Set<String> = [
        "com.hnc.Discord",          // Discord
        "com.tinyspeck.slackmacgap", // Slack
    ]
    
    private init() {}
    
    /// Starts the global event tap on the MAIN run loop.
    /// Uses .defaultTap so we CAN intercept keys (Enter, Escape, arrows).
    /// Runs on main thread with no locks, no accessibility calls = instant callback.
    func start(state: EmojiPickerState, window: CandidateWindow) {
        // Prevent duplicate event taps from the permission timer
        if isRunning { return }
        
        self.state = state
        self.window = window
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                return monitor.handleEvent(event: event, type: type)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            print("❌ Failed to create event tap. Ensure Accessibility permissions are granted.")
            return
        }
        
        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        // Run on MAIN run loop — callback executes on main thread, so all state
        // access is safe without locks, and the callback is ultra-fast.
        CFRunLoopAddSource(CFRunLoopGetMain(), self.runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        print("✅ Global keyboard event tap started (active mode, main thread).")
    }
    
    /// Stops the global event tap
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isBuffering = false
        buffer = ""
        isRunning = false
        print("🛑 Global keyboard event tap stopped.")
    }
    
    /// The event tap callback. Runs on the MAIN THREAD.
    /// MUST return as fast as possible. No locks, no IPC, no accessibility calls.
    private func handleEvent(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        // Re-enable tap if macOS disabled it due to timeout
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = self.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        
        // Ignore auto-repeat events (user holding a key down)
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        if isRepeat {
            // While buffering, swallow repeats so they don't spam the text field
            if isBuffering {
                return Unmanaged.passUnretained(event)
            }
            return Unmanaged.passUnretained(event)
        }
        
        let keycode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        
        // Extract the typed character
        var count = 0
        event.keyboardGetUnicodeString(maxStringLength: 0, actualStringLength: &count, unicodeString: nil)
        var charStr = ""
        if count > 0 {
            var chars = [UniChar](repeating: 0, count: count)
            event.keyboardGetUnicodeString(maxStringLength: count, actualStringLength: &count, unicodeString: &chars)
            charStr = String(utf16CodeUnits: chars, count: count)
        }
        
        if isBuffering {
            // ESCAPE -> Dismiss picker
            if keycode == kVK_Escape {
                closePicker()
                return nil // Swallow
            }
            
            // RETURN or TAB -> Select emoji
            if keycode == kVK_Return || keycode == kVK_Tab {
                if let state = state, !state.matches.isEmpty {
                    let selected = state.selectedEmoji ?? state.matches[0]
                    selectEmoji(selected)
                    return nil // Swallow — do NOT send Enter to the app
                } else {
                    closePicker()
                    return Unmanaged.passUnretained(event) // No matches, pass through
                }
            }
            
            // DOWN ARROW
            if keycode == kVK_DownArrow {
                state?.moveSelectionDown()
                return nil // Swallow
            }
            
            // UP ARROW
            if keycode == kVK_UpArrow {
                state?.moveSelectionUp()
                return nil // Swallow
            }
            
            // BACKSPACE
            if keycode == kVK_Delete {
                if buffer.isEmpty {
                    closePicker()
                } else {
                    buffer.removeLast()
                    state?.updateQuery(buffer)
                }
                return Unmanaged.passUnretained(event) // Let backspace through to delete text
            }
            
            // Character input
            if !charStr.isEmpty {
                let char = charStr.first!
                
                if char.isWhitespace || char.isNewline {
                    closePicker()
                    return Unmanaged.passUnretained(event)
                }
                
                if char.isLetter || char.isNumber || char == "_" || char == "-" {
                    buffer.append(char)
                    state?.updateQuery(buffer)
                    return Unmanaged.passUnretained(event) // Let character through to text field
                } else {
                    closePicker()
                    return Unmanaged.passUnretained(event)
                }
            }
        } else {
            // Not buffering: wait for colon trigger
            if charStr == ":" {
                // Skip if the focused app has its own emoji picker
                if let frontApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                   excludedBundleIDs.contains(frontApp) {
                    return Unmanaged.passUnretained(event)
                }
                isBuffering = true
                buffer = ""
                state?.updateQuery("")
                state?.isVisible = true
                window?.positionNearCaret()
                window?.orderFrontRegardless()
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    func closePicker() {
        isBuffering = false
        buffer = ""
        state?.isVisible = false
        window?.orderOut(nil)
    }
    
    func selectEmoji(_ emoji: Emoji) {
        let textLengthToRemove = buffer.count + 1 // ":keyword"
        closePicker()
        
        // Delay slightly so the picker closes before we simulate keystrokes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.replaceTextWithEmoji(deleteLength: textLengthToRemove, emoji: emoji.emoji)
        }
    }
    
    /// Simulates Backspaces to delete typed prefix, then types the emoji character
    private func replaceTextWithEmoji(deleteLength: Int, emoji: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        
        for _ in 0..<deleteLength {
            let backDown = CGEvent(keyboardEventSource: source, virtualKey: kVK_Delete, keyDown: true)
            let backUp = CGEvent(keyboardEventSource: source, virtualKey: kVK_Delete, keyDown: false)
            backDown?.post(tap: .cghidEventTap)
            backUp?.post(tap: .cghidEventTap)
            usleep(5000)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            
            let utf16Chars = Array(emoji.utf16)
            utf16Chars.withUnsafeBufferPointer { buf in
                keyDown?.keyboardSetUnicodeString(stringLength: buf.count, unicodeString: buf.baseAddress)
                keyUp?.keyboardSetUnicodeString(stringLength: buf.count, unicodeString: buf.baseAddress)
            }
            
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }
}
