#!/bin/bash
# Script to convert any PNG/JPG into a macOS AppIcon and apply it

if [ -z "$1" ]; then
  echo "Usage: ./set_icon.sh <path_to_image>"
  exit 1
fi

IMAGE=$1
if [ ! -f "$IMAGE" ]; then
    echo "Error: File $IMAGE not found."
    exit 1
fi

echo "🎨 Creating macOS AppIcon format..."
ICONSET="AppIcon.iconset"
mkdir -p "$ICONSET"

# Generate all required icon sizes for retina and non-retina displays
sips -z 16 16     "$IMAGE" --out "$ICONSET/icon_16x16.png" > /dev/null 2>&1
sips -z 32 32     "$IMAGE" --out "$ICONSET/icon_16x16@2x.png" > /dev/null 2>&1
sips -z 32 32     "$IMAGE" --out "$ICONSET/icon_32x32.png" > /dev/null 2>&1
sips -z 64 64     "$IMAGE" --out "$ICONSET/icon_32x32@2x.png" > /dev/null 2>&1
sips -z 128 128   "$IMAGE" --out "$ICONSET/icon_128x128.png" > /dev/null 2>&1
sips -z 256 256   "$IMAGE" --out "$ICONSET/icon_128x128@2x.png" > /dev/null 2>&1
sips -z 256 256   "$IMAGE" --out "$ICONSET/icon_256x256.png" > /dev/null 2>&1
sips -z 512 512   "$IMAGE" --out "$ICONSET/icon_256x256@2x.png" > /dev/null 2>&1
sips -z 512 512   "$IMAGE" --out "$ICONSET/icon_512x512.png" > /dev/null 2>&1
sips -z 1024 1024 "$IMAGE" --out "$ICONSET/icon_512x512@2x.png" > /dev/null 2>&1

# Convert iconset directory to an .icns file
iconutil -c icns "$ICONSET"
rm -rf "$ICONSET"

# Keep AppIcon.icns in the root directory so build.sh can copy it automatically!
echo "📦 AppIcon.icns generated! Run ./build.sh to package it into the app."
echo "✅ Icon generation successful."
