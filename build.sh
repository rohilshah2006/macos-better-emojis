#!/bin/bash
set -e

echo "🔨 Compiling Emoji Picker..."

# Determine SDK path automatically
SDK_PATH=""
if command -v xcrun &>/dev/null; then
    SDK_PATH=$(xcrun --show-sdk-path 2>/dev/null || true)
fi

if [ -z "$SDK_PATH" ]; then
    if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk" ]; then
        SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
    else
        SDK_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
    fi
fi

echo "📦 Using macOS SDK at: $SDK_PATH"

# Clean old artifacts
rm -rf EmojiPicker.app
rm -f EmojiPicker

# Compile swift source files
swiftc -O -sdk "$SDK_PATH" \
       -framework SwiftUI \
       -framework AppKit \
       -framework Carbon \
       -framework Foundation \
       -o EmojiPicker \
       EmojiData.swift \
       EmojiDatabase.swift \
       CandidateView.swift \
       CandidateWindow.swift \
       KeyboardMonitor.swift \
       main.swift

echo "✅ Binary compiled successfully."

# Package into macOS .app bundle structure
echo "📂 Packaging into EmojiPicker.app..."
mkdir -p EmojiPicker.app/Contents/MacOS
mkdir -p EmojiPicker.app/Contents/Resources

# Move binary and Info.plist
mv EmojiPicker EmojiPicker.app/Contents/MacOS/
cp Info.plist EmojiPicker.app/Contents/

# Copy AppIcon if it exists
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns EmojiPicker.app/Contents/Resources/
fi

# Set executable permissions
chmod +x EmojiPicker.app/Contents/MacOS/EmojiPicker

echo "🚀 EmojiPicker.app created successfully in $(pwd)!"
echo "To run the app, type: open EmojiPicker.app"
