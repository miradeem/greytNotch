# 🏝️ GreytNotch: Dynamic Island greytHR Attendance Tracker

A lightweight, native macOS Dynamic Island widget that tracks your office attendance and 8-hour workday directly from your MacBook's notch.

When you swipe in at your office turnstile biometric reader, GreytNotch automatically captures your first swipe via the **greytHR** portal and starts an 8-hour countdown timer with fluid, Apple-grade notch animations.

---

## ⚡ Quick Start

### 📋 Prerequisites
- **macOS Monterey (12.0) or later** (Optimized for MacBooks with a camera notch, e.g. M1/M2/M3/M4 MacBook Pro & Air).
- **Xcode Command Line Tools** (for the Swift compiler):
  ```bash
  xcode-select --install
  ```
- **Zero Third-Party Dependencies:** Uses standard macOS system frameworks (`SwiftUI`, `AppKit`, `UserNotifications`) and Python built-in standard library (`urllib`, `json`, `openssl`). No `pip install` or external package managers needed.

---

### 🚀 Setup in 3 Steps

#### 1. Clone the Repository
```bash
git clone https://github.com/miradeem/greytNotch.git
cd greytNotch
```

#### 2. Configure Your greytHR Account
Run the interactive setup wizard:
```bash
./configure.sh
```
You will be prompted for:
1. **greytHR Domain:** e.g., if your office portal URL is `https://acme.greythr.com`, enter `acme`.
2. **Employee ID:** Your office username.
3. **Password:** Your greytHR login password.

> **Security Note:** Credentials are encrypted using OpenSSL RSA-OAEP SHA-256 and stored strictly on your local machine at `~/.greythr_config.json` with strict `0600` (read/write owner only) permissions.

#### 3. Launch GreytNotch
```bash
./start.sh
```
*That's it!* 
- `./start.sh` will **automatically compile** the Swift app on your first run.
- The Dynamic Island will activate at the top of your screen.
- The background sync daemon will begin checking for your first turnstile swipe.

---

## 🎮 How to Use & Controls

Move your mouse cursor to the top center of your screen over your MacBook's camera notch to see the Dynamic Island expand.

| Button | Name | Action |
| :---: | :--- | :--- |
| 🪄 | **Animation Style** | Open the live switcher to choose between 5 native animation engines (Genie, Visor, Bouncy, Liquid, Shutter). |
| ✏️ | **Manual Swipe Time** | Set or override your first swipe time manually (e.g. `09:15 AM`) if turnstile sync is delayed. |
| 🔄 | **Refresh Attendance** | Manually trigger an immediate greytHR turnstile sync. |
| 📌 | **Pin Window** | Keep the Dynamic Island pinned open while multitasking. |
| ⏻ | **Quit** | Close the Dynamic Island and stop all processes immediately. |

---

## 🧪 Try It Without greytHR (Demo Mode)

Want to test the Dynamic Island animations and countdown timer without connecting a greytHR account?

1. Launch the app:
   ```bash
   ./start.sh
   ```
2. Feed a simulated morning swipe time:
   ```bash
   ./greyt_sync.py --manual-in "09:30 AM"
   ```
   *(Or simply hover over the notch, click the ✏️ pencil icon in the header, and type any time!)*

The island will immediately update with `09:30 AM` as your first swipe and calculate `05:30 PM` as your 8-hour target.

---

## 🛑 Stopping the App

To stop both the Dynamic Island widget and the background polling daemon:
```bash
./stop.sh
```
*(You can also simply click the **⏻** power button in the top right of the expanded Dynamic Island).*

---

## ✨ Features Breakdown

- **Authentic Apple Notch Integration:**
  - **Flush Hardware Cutout:** Aligned directly under the physical MacBook camera notch with zero top margin dead zones.
  - **No Menu Bar Clutter:** Runs as a pure Dynamic Island accessory widget without taking up space in your macOS menu bar.
  - **5 Animation Engines:**
    - 🧞‍♂️ **Genie:** Authentic Apple window minimization funnel suction into the camera cutout.
    - 🧊 **3D Visor:** Spatial perspective flip into 3D depth.
    - 🎾 **Bouncy:** Playful spring overshoot bounce.
    - 💧 **Liquid:** Fluid Dynamic Island morph stretch.
    - ⬇️ **Shutter:** Snappy, rapid vertical slide.
  - **macOS Dock-Style Tooltips:** Elevated obsidian black pills with specular edge sheens and drop shadows when hovering over action icons.

- **Automated Turnstile Sync:**
  - Modern greytHR UAS authentication using OpenSSL RSA-OAEP SHA-256 password encryption and OAuth2 PKCE.
  - Polls `/v3/api/attendance/swipes` in the morning until the turnstile registers your first swipe, then automatically sleeps in low-frequency mode to preserve battery and network bandwidth.

- **Native System Alerts:**
  - ⏱ Reminder notification at **15 minutes remaining**.
  - 🎉 Completion alert when your **8 hours are reached**.

---

## 🧑‍💻 For Developers & Contributing

You **never** need to run `build.sh` manually to use the app, because `./start.sh` automatically compiles the binary whenever it is missing.

However, if you are contributing or modifying the Swift code inside `src/`:

```bash
# Recompile the native Swift binary without launching
./build.sh
```

- **Output:** `GreytNotch.app` bundle (< 500 KB binary, ~20 MB RAM footprint).
- **Architecture:** 100% native Swift 5 + SwiftUI and AppKit. Zero third-party dependencies.
