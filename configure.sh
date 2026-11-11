#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if ! command -v python3 &> /dev/null; then
    echo "[!] python3 not found. Please install Python 3 or Xcode Command Line Tools:"
    echo "    xcode-select --install"
    exit 1
fi

python3 "$DIR/greyt_sync.py" "$@"
