#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

echo "[*] Compiling GreytNotch native macOS app..."
mkdir -p GreytNotch.app/Contents/MacOS
mkdir -p GreytNotch.app/Contents/Resources
cp src/Info.plist GreytNotch.app/Contents/Info.plist

swiftc -O -framework SwiftUI -framework AppKit -framework UserNotifications \
    src/AttendanceManager.swift \
    src/NotchViews.swift \
    src/NotchWindowController.swift \
    src/main.swift \
    -o GreytNotch.app/Contents/MacOS/GreytNotch

echo "[✓] Build complete: $DIR/GreytNotch.app"
