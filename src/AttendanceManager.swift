import Foundation
import Combine
import UserNotifications

struct AttendanceData: Codable {
    var status: String?          // "TRACKING", "WAITING_FOR_SWIPE", "COMPLETED"
    var date: String?            // "2026-11-06"
    var first_in: String?        // "9:30 AM"
    var first_in_iso: String?    // "2026-11-06T09:30:00"
    var target_out: String?      // "5:30 PM"
    var target_out_iso: String?  // "2026-11-06T17:30:00"
    var required_hours: Double?  // 8.0
    var last_synced: String?     // "05:56 PM"
    var domain: String?          // company domain
}

class AttendanceManager: ObservableObject {
    @Published var data: AttendanceData = AttendanceData()
    @Published var elapsedSeconds: Double = 0
    @Published var remainingSeconds: Double = 0
    @Published var progress: Double = 0
    @Published var isCompleted: Bool = false
    @Published var isSyncing: Bool = false
    @Published var statusMessage: String = "Waiting for swipe..."
    
    private var timer: Timer?
    private var fileWatcherTimer: Timer?
    private var lastFileModDate: Date?
    private var notified15Min = false
    private var notifiedCompletion = false

    var statusFilePath: String {
        return ("~/.greythr_status.json" as NSString).expandingTildeInPath
    }
    
    var syncScriptPath: String {
        let downloadsPath = ("~/Downloads/projects/greythr-notch/greyt_sync.py" as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: downloadsPath) {
            return downloadsPath
        }
        return "greyt_sync.py"
    }

    init() {
        requestNotificationPermission()
        loadStatusFile()
        startTimers()
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func startTimers() {
        // Live second ticker for smooth countdown
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        
        // Watch for file updates every 3 seconds
        fileWatcherTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkForFileUpdates()
        }
    }

    func checkForFileUpdates() {
        let path = statusFilePath
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let modDate = attrs[.modificationDate] as? Date else { return }
        
        if lastFileModDate == nil || modDate > (lastFileModDate ?? Date.distantPast) {
            lastFileModDate = modDate
            DispatchQueue.main.async {
                self.loadStatusFile()
            }
        }
    }

    func loadStatusFile() {
        let path = statusFilePath
        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let decoded = try? JSONDecoder().decode(AttendanceData.self, from: fileData) else {
            return
        }
        
        self.data = decoded
        self.tick()
    }

    func tick() {
        guard let iso = data.first_in_iso,
              let firstDate = ISO8601DateFormatter().date(from: iso) ?? parseFlexibleDate(iso) else {
            if data.status == "WAITING_FOR_SWIPE" {
                statusMessage = "Waiting for door turnstile..."
            } else {
                statusMessage = "No swipe recorded"
            }
            elapsedSeconds = 0
            remainingSeconds = 0
            progress = 0
            isCompleted = false
            return
        }

        let reqHours = data.required_hours ?? 8.0
        let totalRequired = reqHours * 3600.0
        let now = Date()
        let elapsed = max(0, now.timeIntervalSince(firstDate))
        let remaining = max(0, totalRequired - elapsed)
        
        self.elapsedSeconds = elapsed
        self.remainingSeconds = remaining
        self.progress = min(1.0, elapsed / totalRequired)
        self.isCompleted = remaining <= 0
        
        if isCompleted {
            statusMessage = "8 Hours Complete 🎉"
            if !notifiedCompletion {
                notifiedCompletion = true
                sendNotification(title: "🎉 8 Hours Completed!", body: "You've met today's attendance requirement. Safe to swipe out!")
            }
        } else {
            statusMessage = "\(formatHoursMinutes(remaining)) left"
            if remaining <= 900 && remaining > 0 && !notified15Min {
                notified15Min = true
                sendNotification(title: "⏱ 15 Minutes Remaining", body: "Almost done! 15 minutes left until you hit 8 hours.")
            }
        }
    }

    func formatHoursMinutes(_ seconds: Double) -> String {
        let totalMins = Int(seconds) / 60
        let hrs = totalMins / 60
        let mins = totalMins % 60
        return String(format: "%02dh %02dm", hrs, mins)
    }

    func formatElapsed() -> String {
        let totalMins = Int(elapsedSeconds) / 60
        let hrs = totalMins / 60
        let mins = totalMins % 60
        return String(format: "%02dh %02dm", hrs, mins)
    }

    private func parseFlexibleDate(_ str: String) -> Date? {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            df.dateFormat = fmt
            if let d = df.date(from: str) { return d }
        }
        return nil
    }

    func triggerSync() {
        guard !isSyncing else { return }
        isSyncing = true
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            proc.arguments = [self.syncScriptPath]
            try? proc.run()
            proc.waitUntilExit()
            
            DispatchQueue.main.async {
                self.isSyncing = false
                self.loadStatusFile()
            }
        }
    }

    func setManualTime(_ timeString: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            proc.arguments = [self.syncScriptPath, "--manual-in", timeString]
            try? proc.run()
            proc.waitUntilExit()
            
            DispatchQueue.main.async {
                self.loadStatusFile()
            }
        }
    }

    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }
}
