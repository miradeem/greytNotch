#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "=================================================="
echo "          greytHR Dynamic Island Tracker          "
echo "=================================================="

# Ensure app is built
if [ ! -d "$DIR/GreytNotch.app" ] || [ ! -f "$DIR/GreytNotch.app/Contents/MacOS/GreytNotch" ]; then
    echo "[*] App binary not found. Building GreytNotch..."
    "$DIR/build.sh"
fi

# Check if app is already running
if pgrep -x "GreytNotch" > /dev/null; then
    echo "[*] GreytNotch is already running! Restarting..."
    killall GreytNotch 2>/dev/null || true
    sleep 0.5
fi

# Open GreytNotch.app
open "$DIR/GreytNotch.app"
echo "[+] GreytNotch Dynamic Island launched!"
echo "    -> Move your mouse over your MacBook's notch to see it expand."

# Check if config exists, if so start the sync poller in background
if [ -f "$HOME/.greythr_config.json" ]; then
    echo "[*] Found greytHR credentials. Starting background poller daemon..."
    pkill -f "greyt_sync.py" 2>/dev/null || true
    nohup python3 "$DIR/greyt_sync.py" --daemon > "$HOME/.greythr_daemon.log" 2>&1 &
    echo "[+] Daemon running in background (logs: ~/.greythr_daemon.log)"
else
    echo "[!] No greytHR credentials found yet."
    echo "    Run './configure.sh' to enter your office greytHR username and password."
    echo "    Or hover on the notch and click the ✏️ pencil icon to manually set your time."
fi
