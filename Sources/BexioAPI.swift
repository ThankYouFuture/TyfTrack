import Foundation

/// Append-only debug log: ~/Library/Application Support/TyfTrack/tyftrack.log
enum TyfLog {
    static let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TyfTrack", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("tyftrack.log")
    }()

    static func append(_ message: String) {
        let df = ISO8601DateFormatter()
        let line = "\(df.string(from: Date())) \(message)\n"
        NSLog("TyfTrack: %@", message)
        if let data = line.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }
}

struct BexioError: LocalizedError {
    let status: Int
    let message: String
    var errorDescription: String? { "HTTP \(status) — \(message)" }
}

final class BexioAPI: @unchecked Sendable {
    static let shared = BexioAPI()
    private let base = URL(string: "https://api.bexio.com")!

    var token: String? = Keychain.loadToken()

    // MARK: Models

    struct Me: Codable {
        let id: Int
        let firstname: String?
        let lastname: String?
        let email: String?
        var displayName: String {
            let name = [firstname, lastname].compactMap { $0 }.joined(separator: " ")
            return name.isEmpty ? (email ?? "Utilisateur \(id)") : name
        }
    }

    struct Contact: Codable, Identifiable, Hashable {
        let id: Int
        let name_1: String
        let name_2: String?
        let nr: String?
        var displayName: String { [name_1, name_2].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ") }
    }

    struct Project: Codable, Identifiable, Hashable {
        let id: Int
        let name: String
        let contact_id: Int?
    }

    struct Service: Codable, Identifiable, Hashable {
        let id: Int
        let name: String
    }

    // MARK: Core request

    private func request(_ method: String, _ path: String, body: Data? = nil) async throws -> Data {
        if token == nil || token?.isEmpty == true {
            token = Keychain.loadToken()
        }
        guard let token, !token.isEmpty else {
            TyfLog.append("\(method) \(path) — ABANDON: aucun jeton (trousseau vide ou inaccessible)")
            throw BexioError(status: 0, message: "Aucun jeton API configuré")
        }
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = method
        req.httpBody = body
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            var message = String(data: data, encoding: .utf8) ?? ""
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let m = obj["message"] as? String { message = m }
                if let errs = obj["errors"] as? [String] { message += " " + errs.joined(separator: ", ") }
            }
            TyfLog.append("\(method) \(path) — HTTP \(status): \(String(message.prefix(200)))")
            throw BexioError(status: status, message: String(message.prefix(300)))
        }
        return data
    }

    private func get(_ path: String) async throws -> Data { try await request("GET", path) }

    // MARK: Endpoints

    func me() async throws -> Me {
        try JSONDecoder().decode(Me.self, from: try await get("3.0/users/me"))
    }

    private func fetchAllPages<T: Codable>(_ path: String, as type: T.Type) async throws -> [T] {
        var all: [T] = []
        var offset = 0
        let limit = 500
        while true {
            let data = try await get("\(path)?limit=\(limit)&offset=\(offset)")
            let page = try JSONDecoder().decode([T].self, from: data)
            all.append(contentsOf: page)
            if page.count < limit || all.count > 10_000 { break }
            offset += limit
        }
        return all
    }

    func contacts() async throws -> [Contact] {
        try await fetchAllPages("2.0/contact", as: Contact.self)
    }

    func projects() async throws -> [Project] {
        try await fetchAllPages("2.0/pr_project", as: Project.self)
    }

    func services() async throws -> [Service] {
        try await fetchAllPages("2.0/client_service", as: Service.self)
    }

    /// Fixed Bexio system statuses for timesheets (GET /2.0/timesheet_status,
    /// stable ids with translation keys — the web UI localizes them).
    static let timesheetStatuses: [(id: Int, label: String)] = [
        (1, "Ouvert"), (2, "En cours"), (3, "Terminé"),
    ]

    private func timesheetPayload(userId: Int, serviceId: Int, contactId: Int?, projectId: Int?,
                                  text: String, billable: Bool, date: Date, durationMinutes: Int,
                                  statusId: Int) throws -> Data {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = .current
        let duration = String(format: "%02d:%02d", durationMinutes / 60, durationMinutes % 60)

        var payload: [String: Any] = [
            "user_id": userId,
            "client_service_id": serviceId,
            "allowable_bill": billable,
            "status_id": statusId,
            "text": text,
            "tracking": [
                "type": "duration",
                "date": df.string(from: date),
                "duration": duration,
            ],
        ]
        if let contactId { payload["contact_id"] = contactId }
        if let projectId { payload["pr_project_id"] = projectId }
        return try JSONSerialization.data(withJSONObject: payload)
    }

    /// POST /2.0/timesheet — duration-based tracking. Returns the new timesheet id.
    func createTimesheet(userId: Int, serviceId: Int, contactId: Int?, projectId: Int?,
                         text: String, billable: Bool, date: Date, durationMinutes: Int,
                         statusId: Int) async throws -> Int {
        let body = try timesheetPayload(userId: userId, serviceId: serviceId, contactId: contactId,
                                        projectId: projectId, text: text, billable: billable,
                                        date: date, durationMinutes: durationMinutes, statusId: statusId)
        let data = try await request("POST", "2.0/timesheet", body: body)
        struct Created: Codable { let id: Int }
        return (try? JSONDecoder().decode(Created.self, from: data))?.id ?? 0
    }

    /// POST /2.0/timesheet/{id} — replaces the entry's duration with the new total.
    func editTimesheet(id: Int, userId: Int, serviceId: Int, contactId: Int?, projectId: Int?,
                       text: String, billable: Bool, date: Date, durationMinutes: Int,
                       statusId: Int) async throws {
        let body = try timesheetPayload(userId: userId, serviceId: serviceId, contactId: contactId,
                                        projectId: projectId, text: text, billable: billable,
                                        date: date, durationMinutes: durationMinutes, statusId: statusId)
        _ = try await request("POST", "2.0/timesheet/\(id)", body: body)
    }
}

// MARK: - Reference-data cache (contacts / projects / activities)

@MainActor
final class BexioCache: ObservableObject {
    @Published var contacts: [BexioAPI.Contact] = []
    @Published var projects: [BexioAPI.Project] = []
    @Published var services: [BexioAPI.Service] = []
    @Published var lastSync: Date?
    @Published var syncing = false
    @Published var syncError: String?

    private var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TyfTrack", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("cache.json")
    }

    private struct Persisted: Codable {
        var contacts: [BexioAPI.Contact]
        var projects: [BexioAPI.Project]
        var services: [BexioAPI.Service]
        var lastSync: Date
    }

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: cacheURL),
              let p = try? JSONDecoder().decode(Persisted.self, from: data) else { return }
        contacts = p.contacts
        projects = p.projects
        services = p.services
        lastSync = p.lastSync
    }

    func refresh() async {
        guard !syncing else { return }
        syncing = true
        syncError = nil
        do {
            async let c = BexioAPI.shared.contacts()
            async let p = BexioAPI.shared.projects()
            async let s = BexioAPI.shared.services()
            let (cc, pp, ss) = try await (c, p, s)
            contacts = cc.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            projects = pp.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            services = ss.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            lastSync = Date()
            let persisted = Persisted(contacts: contacts, projects: projects, services: services, lastSync: lastSync!)
            if let data = try? JSONEncoder().encode(persisted) {
                try? data.write(to: cacheURL, options: .atomic)
            }
        } catch {
            syncError = error.localizedDescription
        }
        syncing = false
    }

    func projects(forContact contactId: Int?) -> [BexioAPI.Project] {
        guard let contactId else { return projects }
        let filtered = projects.filter { $0.contact_id == contactId }
        return filtered.isEmpty ? projects : filtered
    }
}
