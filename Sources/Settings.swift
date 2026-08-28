import Foundation
import Combine
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard

    @Published var bexioUserId: Int { didSet { d.set(bexioUserId, forKey: "bexioUserId") } }
    @Published var bexioUserName: String { didSet { d.set(bexioUserName, forKey: "bexioUserName") } }
    @Published var defaultServiceId: Int { didSet { d.set(defaultServiceId, forKey: "defaultServiceId") } }
    @Published var defaultServiceName: String { didSet { d.set(defaultServiceName, forKey: "defaultServiceName") } }
    @Published var defaultBillable: Bool { didSet { d.set(defaultBillable, forKey: "defaultBillable") } }
    /// Rounding step in minutes applied when sending (always rounds up). 1 = to the minute.
    @Published var roundingMinutes: Int { didSet { d.set(roundingMinutes, forKey: "roundingMinutes") } }
    /// Bexio timesheet status applied on send (3 = Terminé).
    @Published var sendStatusId: Int { didSet { d.set(sendStatusId, forKey: "sendStatusId") } }
    /// Auto-pause after this many minutes without keyboard/mouse input. 0 = disabled.
    @Published var idleMinutes: Int { didSet { d.set(idleMinutes, forKey: "idleMinutes") } }
    @Published var pauseOnLock: Bool { didSet { d.set(pauseOnLock, forKey: "pauseOnLock") } }

    private init() {
        d.register(defaults: [
            "defaultBillable": true,
            "roundingMinutes": 1,
            "sendStatusId": 3,
            "idleMinutes": 10,
            "pauseOnLock": true,
        ])
        bexioUserId = d.integer(forKey: "bexioUserId")
        bexioUserName = d.string(forKey: "bexioUserName") ?? ""
        defaultServiceId = d.integer(forKey: "defaultServiceId")
        defaultServiceName = d.string(forKey: "defaultServiceName") ?? ""
        defaultBillable = d.bool(forKey: "defaultBillable")
        roundingMinutes = d.integer(forKey: "roundingMinutes")
        sendStatusId = d.integer(forKey: "sendStatusId")
        idleMinutes = d.integer(forKey: "idleMinutes")
        pauseOnLock = d.bool(forKey: "pauseOnLock")
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Launch at login: \(error)")
            }
            objectWillChange.send()
        }
    }
}
