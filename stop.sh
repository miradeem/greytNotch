#!/usr/bin/env bash
echo "[*] Stopping GreytNotch..."
killall GreytNotch 2>/dev/null && echo "[+] GreytNotch window closed." || echo "[-] GreytNotch was not running."

echo "[*] Stopping greytHR background poller daemon..."
pkill -f "greyt_sync.py --daemon" 2>/dev/null && echo "[+] Poller daemon stopped." || echo "[-] Poller daemon was not running."

echo "[✓] All GreytNotch processes stopped."
