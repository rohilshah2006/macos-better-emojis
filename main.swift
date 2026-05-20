import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var state = EmojiPickerState()
    var window: CandidateWindow?
    
    var isEnabled = true
    private var permissionCheckTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the non-activating floating panel and bind selected emoji callback
        window = CandidateWindow(state: state) { selectedEmoji in
            KeyboardMonitor.shared.selectEmoji(selectedEmoji)
        }
        
        setupMenuBar()
        checkAndStartMonitor()
        
        // Set up a background timer to check for Accessibility approval changes
        // Once approved, we start the monitor and KILL the timer to save CPU.
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let isTrusted = AXIsProcessTrusted()
            self.updateMenu()
            if isTrusted && self.isEnabled {
                self.checkAndStartMonitor()
                self.permissionCheckTimer?.invalidate()
                self.permissionCheckTimer = nil
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        KeyboardMonitor.shared.stop()
        permissionCheckTimer?.invalidate()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        
        // Setup a beautiful smiling face image as menu bar icon
        if let image = NSImage(systemSymbolName: "face.smiling", accessibilityDescription: "Emoji Picker") {
            image.isTemplate = true // Matches system dark/light mode menu bar
            button.image = image
        } else {
            button.title = "😀"
        }
        
        updateMenu()
    }
    
    func updateMenu() {
        let menu = NSMenu()
        
        let isTrusted = AXIsProcessTrusted()
        
        // 1. Status Indicator
        let statusTitle = isTrusted ? "🟢 Keyboard Monitor: Active" : "🔴 Setup Needed (No Permissions)"
        let statusIndicatorItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusIndicatorItem.isEnabled = false
        menu.addItem(statusIndicatorItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. Action Items depending on Accessibility state
        if isTrusted {
            let toggleItem = NSMenuItem(
                title: isEnabled ? "Disable Emoji Picker" : "Enable Emoji Picker",
                action: #selector(toggleEnabled),
                keyEquivalent: ""
            )
            toggleItem.state = isEnabled ? .on : .off
            menu.addItem(toggleItem)
        } else {
            let grantItem = NSMenuItem(
                title: "⚠️ Grant Accessibility Permission...",
                action: #selector(requestAccessibilityPermission),
                keyEquivalent: ""
            )
            menu.addItem(grantItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. Info / Instructions
        let helpItem = NSMenuItem(title: "How to use...", action: #selector(showHelp), keyEquivalent: "")
        menu.addItem(helpItem)
        
        // 4. Quit
        let quitItem = NSMenuItem(title: "Quit Emoji Picker", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func toggleEnabled() {
        isEnabled.toggle()
        if isEnabled {
            checkAndStartMonitor()
        } else {
            KeyboardMonitor.shared.stop()
        }
        updateMenu()
    }
    
    @objc private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        if !accessEnabled {
            // Guide user directly to privacy/accessibility tab in System Settings
            if let prefUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(prefUrl)
            }
        }
        updateMenu()
    }
    
    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "Discord-like Emoji Picker Help"
        alert.informativeText = """
        How to Use:
        1. Open any text editor (TextEdit, Safari, VS Code, Discord, Notes, etc.).
        2. Type ':' (colon) followed by a keyword, e.g., ':smi' or ':happy'.
        3. A premium emoji overlay will float right under your text cursor!
        4. Use ↑ and ↓ arrow keys to highlight the emoji you want.
        5. Press Enter (Return) or Tab to insert the emoji. The typed prefix will be automatically replaced!
        6. Press Escape or type a Space to close the overlay.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Got it!")
        alert.runModal()
    }
    
    @objc private func quitApp() {
        KeyboardMonitor.shared.stop()
        NSApplication.shared.terminate(nil)
    }
    
    private func checkAndStartMonitor() {
        let isTrusted = AXIsProcessTrusted()
        if isTrusted && isEnabled {
            if let window = window {
                KeyboardMonitor.shared.start(state: state, window: window)
            }
        }
        updateMenu()
    }
}

// Global Application Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
