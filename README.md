# 🏝️ GreytNotch: Dynamic Island greytHR Attendance Tracker

A native macOS Dynamic Island attendance widget for MacBook notches that automatically tracks your office work hours from **greytHR**. When you swipe in at the turnstile biometric reader, it captures your first swipe of the day and starts an 8-hour countdown timer, seamlessly accessible right from your MacBook's notch.

---

## ✨ Features

- **MacBook Notch Dynamic Island:**
  - **Hardware Aligned:** Sits flush directly under your MacBook's camera notch with zero top margin dead zones.
  - **Hover Trigger:** Springs smoothly downward into an Apple-style acrylic glass island when hovering over the notch.
  - **5 Native Animation Engines:**
    - 🧞‍♂️ **Genie:** Authentic Apple window minimization funnel suction directly into the camera cutout.
    - 🧊 **3D Visor:** Spatial perspective flip into 3D depth.
    - 🎾 **Bouncy:** Playful spring overshoot bounce.
    - 💧 **Liquid:** Fluid Dynamic Island morph stretch.
    - ⬇️ **Shutter:** Snappy, rapid vertical slide.
  - **Interactive Animation Switcher:** Switch animations on the fly via the 🪄 wand button in the header; preferences persist automatically.

- **Biometric Turnstile Sync:**
  - Polls your company's greytHR portal in the morning until the door biometric reader registers your first swipe.
  - Automatically records the exact timestamp (`First In`) and calculates your target checkout time (`First In + 8 hours`).
  - Native OpenSSL RSA-OAEP SHA-256 password encryption and OAuth2 PKCE turnstile sync.

- **Live Metrics & Visuals:**
  - 🕒 **First In Time**
  - 🏁 **Earliest Safe Exit Time (8 Hours)**
  - ⏳ **Elapsed Time & Remaining Countdown**
  - 📊 **Animated Gradient Glowing Progress Bar**
  - 🏷️ **macOS Dock-Style Tooltips:** Hovering over any action icon displays an elevated obsidian pill with specular sheen.

- **Native Notifications:**
  - ⏱ Reminder alert at **15 minutes left**.
  - 🎉 Completion alert when **8 hours are reached**.

- **Quick Controls:**
  - 📌 **Pin Window:** Keep the island pinned open while multitasking.
  - 🔄 **Live Sync:** Refresh turnstile swipes on demand.
  - ✏️ **Manual Time Override:** Manually set your swipe time if turnstile sync is delayed.
  - ⏻ **Quick Quit:** Instant clean exit from the island header.

---

## 🚀 Getting Started

### 1. Clone & Launch
```bash
git clone https://github.com/miradeem/greytNotch.git
cd greytNotch
./start.sh
```
*Move your cursor to the top center of your screen / camera notch to watch the Dynamic Island expand!*

### 2. Connect Your greytHR Account
Run the interactive configuration wizard:
```bash
./configure.sh
```
You will be prompted for:
1. **greytHR Domain:** e.g., if your office URL is `https://acme.greythr.com`, enter `acme`.
2. **Username:** Your Employee ID.
3. **Password:** Your greytHR password.

Credentials are saved locally in your user home directory at `~/.greythr_config.json` with strict `0600` permissions.

### 3. Stop the App & Daemon
```bash
./stop.sh
```
*(You can also click the **⏻** power button in the top right of the expanded island).*

---

## 🛠️ Testing Without greytHR (Manual Test Mode)

To test the island animation and timer immediately without connecting greytHR:
```bash
./greyt_sync.py --manual-in "09:30 AM"
```
The island will immediately update with `09:30 AM` as your first swipe and calculate `05:30 PM` as your 8-hour target.

You can also click the ✏️ **pencil** icon in the header to set your swipe time directly within the UI.

---

## ⚙️ Background Polling Daemon

To run the poller continuously in the background (polls every 5 minutes until today's swipe is found, then switches to low-frequency sleep):
```bash
python3 greyt_sync.py --daemon
```
*Note: `./start.sh` automatically starts this daemon in the background if credentials exist.*

---

## 🏗️ Rebuilding the App

The app is 100% native Swift and SwiftUI with zero third-party dependencies:
```bash
./build.sh
```
Binary output: `GreytNotch.app` (under 500 KB, ~20 MB RAM footprint).
