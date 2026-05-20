import Cocoa
import SwiftUI

class CandidateWindow: NSPanel {
    init(state: EmojiPickerState, onSelect: @escaping (Emoji) -> Void) {
        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 300),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.level = .popUpMenu // Floating menu level
        self.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle] // Join full-screen apps
        
        // Host the SwiftUI view
        let contentView = CandidateView(state: state, onSelect: onSelect)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 300)
        self.contentView = hostingView
    }
    
    override var canBecomeKey: Bool {
        return false // Never take focus!
    }
    
    override var canBecomeMain: Bool {
        return false // Never take focus!
    }
    
    /// Repositions the candidate window near the active text cursor (caret) or mouse cursor if caret is unavailable.
    func positionNearCaret() {
        // To avoid catastrophic Accessibility XPC deadlocks with the Window Server that cause the Spam Bug,
        // we position the picker near the mouse cursor instead of querying the focused app's caret.
        let mouseLoc = NSEvent.mouseLocation
        let windowWidth = self.frame.width
        let windowHeight = self.frame.height
        
        var targetX = mouseLoc.x + 15
        var targetY = mouseLoc.y - windowHeight - 15
        
        if let screen = NSScreen.main {
            if targetX + windowWidth > screen.frame.maxX {
                targetX = screen.frame.maxX - windowWidth - 10
            }
            if targetY < screen.frame.minY {
                targetY = mouseLoc.y + 15
            }
        }
        
        self.setFrameOrigin(NSPoint(x: targetX, y: targetY))
    }
    
    /// Positions the window at the current mouse pointer location.
    func positionAtMouse() {
        let mouseLoc = NSEvent.mouseLocation
        let windowWidth = self.frame.width
        let windowHeight = self.frame.height
        
        var targetX = mouseLoc.x + 10
        var targetY = mouseLoc.y - windowHeight - 10
        
        if let screen = NSScreen.main {
            let screenWidth = screen.frame.width
            
            if targetX + windowWidth > screenWidth {
                targetX = mouseLoc.x - windowWidth - 10
            }
            if targetY < 0 {
                targetY = mouseLoc.y + 10
            }
        }
        
        self.setFrameOrigin(NSPoint(x: targetX, y: targetY))
    }
}
