# Discord Emoji Picker for macOS

A lightning-fast, zero-overhead, global emoji picker for macOS that brings the Discord typing experience to every app on your Mac.

<img src="icon.png" width="128" alt="App Icon">

![Swift](https://img.shields.io/badge/Swift-F05138?style=flat-square&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-007AFF?style=flat-square&logo=swift&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-000000?style=flat-square&logo=apple&logoColor=white)

## Features
- **Global `:<keyword>` trigger:** Type `:` followed by any keyword (e.g. `:smile`) in any app (Notes, Chrome, Safari, VS Code, etc.).
- **Instant Search:** Uses a pre-built O(1) hash index for zero-latency lookups, identical to Discord's performance.
- **Zero CPU Overhead:** Built entirely on macOS `CoreFoundation` Event Taps. The app uses 0% CPU while idle and only wakes up when you type.
- **Smart App Exclusion:** Automatically disables itself in apps that already have their own emoji pickers (like Discord and Slack) to prevent overlapping menus.

## Installation & Setup

1. **Download the App:** 
   Move `EmojiPicker.app` into your `/Applications` folder.

2. **Launch the App:**
   Double-click `EmojiPicker` in your Applications folder to launch it. A smiling face icon 🟢 will appear in your Mac's menu bar at the top right.

3. **Bypass macOS Gatekeeper (Unidentified Developer Warning):**
   Since this is an open-source tool and not signed by an Apple Developer account, macOS might warn you that the app cannot be opened.
   - If you see a warning, click **"OK"** or **"Cancel"**.
   - Open **System Settings** -> **Privacy & Security**.
   - Scroll down to the Security section, where you'll see a message saying "EmojiPicker was blocked from use".
   - Click **"Open Anyway"** and confirm.

4. **Grant Accessibility Permissions:**
   The app needs accessibility access to monitor your keystrokes for the `:` trigger and to simulate backspaces to replace your text with the emoji.
   - Click the smiling face icon in your menu bar.
   - Click **"⚠️ Grant Accessibility Permission..."**.
   - This will open System Settings. Toggle the switch next to `EmojiPicker` to **ON**.
   - *(Note: If the switch is already on but the menu bar still shows a warning, select `EmojiPicker` in the list, click the `-` (minus) button to delete it, then try granting permission again.)*

5. **Ready to go!**
   When the menu bar icon says **"🟢 Keyboard Monitor: Active"**, you are fully set up! Try typing `:smi` in any text editor.

## How to use
- Type `:` followed by a keyword (e.g. `:heart`).
- Use the **Up/Down Arrow** keys to navigate the results.
- Press **Enter** or **Tab** to instantly insert the emoji and replace the typed text.
- Press **Escape** to close the picker without inserting anything.

## Our Development Journey & Architecture

Building a global keyboard hook on macOS is notoriously tricky. Here is the story of the hurdles we overcame to make this app lightning fast:

### 1. Conquering the Infamous "Spam Bug"
Early in development, we faced a severe issue where typing a single letter would cause it to spam uncontrollably (e.g., `sssssssss`). 
- **The Problem:** We were using a standard `CGEventTap` on a background thread. However, because we only intercepted the `keyDown` event and bypassed `keyUp`, the macOS kernel received the `keyUp` *before* the `keyDown` had finished passing through our tap. The OS assumed the key was physically stuck down and started firing aggressive auto-repeats.
- **The Solution:** We completely scrapped the background thread approach. We rewrote the architecture to use a **Hybrid Active-Interception Mode** strictly on the main thread. By synchronizing both `keyDown` and `keyUp` events seamlessly and ignoring OS-level auto-repeats, we eliminated the pipeline stalls and killed the spam bug entirely.

### 2. Achieving Zero-Latency O(1) Search
Initially, typing inside the picker had a noticeable `0.2s` lag. 
- **The Problem:** The app was running a linear `O(n)` string search across 1,870+ emojis on every single keystroke, causing the SwiftUI thread to choke.
- **The Solution:** We engineered a highly optimized **O(1) Hash Index**. Now, when the app launches, it pre-computes every possible prefix for every emoji and scores them. When you type `:smi`, it's no longer searching—it's executing a single, instantaneous dictionary lookup, delivering the exact same performance as Discord's native picker.

### 3. Absolute Zero Overhead
We wanted this app to be completely invisible to your CPU. The final architecture relies 100% on Apple's CoreFoundation event-driven systems. There are absolutely **zero background loops** running. The app uses `0.0% CPU` and only wakes up exactly when a keystroke is fired.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
Created by Rohil
