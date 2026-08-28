import Foundation
import AppKit
import Combine
import CoreGraphics

// MARK: - Data types

enum PauseReason: String, Codable {
    case user, sleep, idle, lock

    var label: String {
        switch self {
        case .user: return "En pause"
        case .sleep: return "Pause auto — mise en veille"
        case .idle: return "Pause auto — inactivité"
        case .lock: return "Pause auto — écran verrouillé"
        }
    }
}

struct WorkTimer: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var contactId: Int?
    var contactName: String = ""
    var projectId: Int?
    var projectName: String = ""
    var serviceId: Int?
    var serviceName: String = ""
    var note: String = ""
    var billable: Bool = true
    var startedAt: Date = Date()
    var accumulated: TimeInterval = 0
    var runningSince: Date?
    var pauseReason: PauseReason?

    var isRunning: Bool { runningSince != nil }

    var elapsed: TimeInterval {
        accumulated + (runningSince.map { max(0, Date().timeIntervalSince($0)) } ?? 0)
    }

    var displayTitle: String {
        if !contactName.isEmpty { return contactName }
        if !projectName.isEmpty { return projectName }
        return "Chrono express"
    }
}

struct SentEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var seconds: Int
    var label: String
}

// MARK: - Formatting helpers

func formatHMS(_ t: TimeInterval) -> String {
    let s = Int(t.rounded())
    return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
}

func formatHM(_ seconds: Int) -> String {
    let m = seconds / 60
    return String(format: "%d h %02d", m / 60, m % 60)
}

// MARK: - Store

@MainActor
final class TimerStore: ObservableObject {
    @Published var timers: [WorkTimer] = []
    @Published var sentEntries: [SentEntry] = []
    @Published var lastError: String?
    @Published var lastInfo: String?

    let settings: AppSettings
    private var idleTimer: Timer?
    private var wasIdlePaused = false
    private var saveWorkItem: DispatchWorkItem?

    private var stateURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TyfTrack", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("state.json")
    }

    private struct PersistedState: Codable {
        var timers: [WorkTimer]
        var sentEntries: [SentEntry]
        var savedAt: Date
    }

    init(settings: AppSettings) {
        self.settings = settings
        load()
        registerPowerObservers()
        startIdleWatch()
    }

    // MARK: Timer lifecycle

    func addTimer(_ timer: WorkTimer, startImmediately: Bool = true) {
        var t = timer
        if startImmediately { t.runningSince = Date(); t.pauseReason = nil }
        timers.insert(t, at: 0)
        persist()
    }

    func addExpressTimer(note: String = "") {
        var t = WorkTimer()
        t.note = note
        t.billable = settings.defaultBillable
        if settings.defaultServiceId != 0 {
            t.serviceId = settings.defaultServiceId
            t.serviceName = settings.defaultServiceName
        }
        addTimer(t)
    }

    func pause(_ id: UUID, reason: PauseReason = .user) {
        guard let i = timers.firstIndex(where: { $0.id == id }), timers[i].isRunning else { return }
        timers[i].accumulated = timers[i].elapsed
        timers[i].runningSince = nil
        timers[i].pauseReason = reason
        persist()
    }

    func resume(_ id: UUID) {
        guard let i = timers.firstIndex(where: { $0.id == id }), !timers[i].isRunning else { return }
        timers[i].runningSince = Date()
        timers[i].pauseReason = nil
        persist()
    }

    func toggle(_ id: UUID) {
        guard let t = timers.first(where: { $0.id == id }) else { return }
        t.isRunning ? pause(t.id) : resume(t.id)
    }

    func delete(_ id: UUID) {
        timers.removeAll { $0.id == id }
        persist()
    }

    func update(_ timer: WorkTimer) {
        guard let i = timers.firstIndex(where: { $0.id == timer.id }) else { return }
        timers[i] = timer
        persist()
    }

    func pauseAll(reason: PauseReason) {
        var changed = false
        for t in timers where t.isRunning {
            pause(t.id, reason: reason)
            changed = true
        }
        if changed && reason != .user {
            lastInfo = reason.label
        }
    }

    func resumeAllPausedAutomatically() {
        for t in timers where !t.isRunning && t.pauseReason != nil && t.pauseReason != .user {
            resume(t.id)
        }
    }

    var runningCount: Int { timers.filter(\.isRunning).count }

    var totalToday: Int {
        let cal = Calendar.current
        let sent = sentEntries.filter { cal.isDateInToday($0.date) }.reduce(0) { $0 + $1.seconds }
        let live = timers.reduce(0.0) { $0 + $1.elapsed }
        return sent + Int(live)
    }

    // MARK: Send to Bexio

    /// Duration in minutes after applying the configured rounding (always rounds up).
    func roundedMinutes(for timer: WorkTimer) -> Int {
        let step = max(1, settings.roundingMinutes)
        let minutes = Int((timer.elapsed / 60.0).rounded(.up))
        let rounded = Int((Double(minutes) / Double(step)).rounded(.up)) * step
        return max(step, rounded)
    }

    func finishAndSend(_ id: UUID) async {
        guard let i = timers.firstIndex(where: { $0.id == id }) else { return }
        pause(id)
        var t = timers[i]

        guard let serviceId = t.serviceId else {
            lastError = "Choisis une activité (prestation) avant d'envoyer — ou définis une activité par défaut dans les réglages."
            return
        }
        guard settings.bexioUserId != 0 else {
            lastError = "Connexion Bexio non configurée : ouvre les réglages et teste ton jeton API."
            return
        }

        let minutes = roundedMinutes(for: t)
        do {
            _ = try await BexioAPI.shared.createTimesheet(
                userId: settings.bexioUserId,
                serviceId: serviceId,
                contactId: t.contactId,
                projectId: t.projectId,
                text: t.note,
                billable: t.billable,
                date: t.startedAt,
                durationMinutes: minutes
            )
            t = timers.first(where: { $0.id == id }) ?? t
            sentEntries.append(SentEntry(date: Date(), seconds: minutes * 60, label: t.displayTitle))
            timers.removeAll { $0.id == id }
            lastInfo = "\(t.displayTitle) — \(minutes) min envoyées dans Bexio ✓"
            lastError = nil
            persist()
        } catch {
            lastError = "Envoi Bexio échoué : \(error.localizedDescription)"
        }
    }

    // MARK: Persistence

    func persist() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.saveNow() }
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    func saveNow() {
        let state = PersistedState(timers: timers, sentEntries: sentEntries, savedAt: Date())
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: stateURL, options: .atomic)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else { return }
        var restored = state.timers
        // Timers that were running when the app quit: credit the time up to the
        // last save, then restore them paused (we cannot know if work continued).
        for i in restored.indices where restored[i].runningSince != nil {
            let ranUntil = min(state.savedAt, Date())
            if let since = restored[i].runningSince, ranUntil > since {
                restored[i].accumulated += ranUntil.timeIntervalSince(since)
            }
            restored[i].runningSince = nil
            restored[i].pauseReason = .user
        }
        timers = restored
        let cal = Calendar.current
        sentEntries = state.sentEntries.filter { cal.isDateInToday($0.date) }
    }

    // MARK: Sleep / lock / idle

    private func registerPowerObservers() {
        let wsnc = NSWorkspace.shared.notificationCenter
        wsnc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.pauseAll(reason: .sleep)
                self?.saveNow()
            }
        }
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.settings.pauseOnLock else { return }
                self.pauseAll(reason: .lock)
                self.saveNow()
            }
        }
    }

    private func startIdleWatch() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkIdle() }
        }
    }

    private func checkIdle() {
        let threshold = TimeInterval(settings.idleMinutes * 60)
        guard threshold > 0 else { return }
        let idle = Self.systemIdleSeconds()
        if idle >= threshold && runningCount > 0 {
            // Deduct the idle stretch: the user was away for `idle` seconds.
            for i in timers.indices where timers[i].isRunning {
                timers[i].accumulated = max(0, timers[i].elapsed - idle)
                timers[i].runningSince = nil
                timers[i].pauseReason = .idle
            }
            lastInfo = "Pause auto après \(Int(idle / 60)) min d'inactivité — ce temps a été déduit."
            wasIdlePaused = true
            persist()
        } else if idle < 5 && wasIdlePaused {
            wasIdlePaused = false
        }
    }

    static func systemIdleSeconds() -> TimeInterval {
        let types: [CGEventType] = [.keyDown, .mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel, .leftMouseDragged]
        let secs = types.map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
        return secs.min() ?? 0
    }
}
