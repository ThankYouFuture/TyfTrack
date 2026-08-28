import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var cache: BexioCache
    @Environment(\.dismiss) private var dismiss

    @State private var token: String = Keychain.loadToken() ?? ""
    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false
    @State private var launchAtLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L("settings.title"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 10)) }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
            }

            // Bexio connection
            VStack(alignment: .leading, spacing: 6) {
                Text(L("settings.bexio")).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.secondary)
                SecureField(L("settings.token.placeholder"), text: $token)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                HStack(spacing: 8) {
                    Button {
                        testConnection()
                    } label: {
                        if testing { ProgressView().controlSize(.small) }
                        else { Text(L("settings.test")).font(.system(size: 11.5, weight: .semibold)) }
                    }
                    .buttonStyle(GlassButtonStyle(prominent: true))
                    .disabled(testing || token.isEmpty)

                    if let result = testResult {
                        Label(result, systemImage: testOK ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .font(.system(size: 10.5))
                            .foregroundStyle(testOK ? Brand.accent : .orange)
                            .lineLimit(2)
                    } else if settings.bexioUserId != 0 {
                        Label(L("settings.connected", settings.bexioUserName), systemImage: "person.badge.shield.checkmark")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(L("settings.token.hint"))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }

            Divider()

            // Defaults
            VStack(alignment: .leading, spacing: 8) {
                Text(L("settings.defaults")).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.secondary)

                HStack {
                    Text(L("settings.defaultActivity")).font(.system(size: 12))
                    Spacer()
                    Picker("", selection: defaultServiceBinding) {
                        Text(L("settings.noneF")).tag(0)
                        ForEach(cache.services) { s in Text(s.name).tag(s.id) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 170)
                }

                Toggle(L("settings.defaultBillable"), isOn: $settings.defaultBillable)
                    .font(.system(size: 12)).toggleStyle(.switch).controlSize(.small)

                HStack {
                    Text(L("settings.status")).font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $settings.sendStatusId) {
                        ForEach(BexioAPI.timesheetStatuses, id: \.id) { s in
                            Text(s.label).tag(s.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 170)
                }

                HStack {
                    Text(L("settings.rounding")).font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $settings.roundingMinutes) {
                        Text(L("settings.rounding.minute")).tag(1)
                        Text(L("settings.rounding.up", 5)).tag(5)
                        Text(L("settings.rounding.up", 6)).tag(6)
                        Text(L("settings.rounding.up", 15)).tag(15)
                    }
                    .labelsHidden()
                    .frame(maxWidth: 170)
                }
            }

            Divider()

            // Presence
            VStack(alignment: .leading, spacing: 8) {
                Text(L("settings.presence")).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.secondary)
                Text(L("settings.sleepNote"))
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                Toggle(L("settings.lock"), isOn: $settings.pauseOnLock)
                    .font(.system(size: 12)).toggleStyle(.switch).controlSize(.small)
                HStack {
                    Text(L("settings.idle")).font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $settings.idleMinutes) {
                        Text(L("settings.idle.off")).tag(0)
                        Text(L("settings.min", 5)).tag(5)
                        Text(L("settings.min", 10)).tag(10)
                        Text(L("settings.min", 15)).tag(15)
                        Text(L("settings.min", 30)).tag(30)
                    }
                    .labelsHidden()
                    .frame(maxWidth: 170)
                }
                Text(L("settings.idleNote"))
                    .font(.system(size: 9.5)).foregroundStyle(.tertiary)
            }

            Divider()

            Toggle(L("settings.login"), isOn: $launchAtLogin)
                .font(.system(size: 12)).toggleStyle(.switch).controlSize(.small)
                .onChange(of: launchAtLogin) { _, newValue in
                    if settings.launchAtLogin != newValue { settings.launchAtLogin = newValue }
                }

            HStack {
                Button {
                    NSWorkspace.shared.open(URL(string: "https://github.com/ThankYouFuture/TyfTrack/blob/main/HELP.md")!)
                } label: {
                    Label(L("settings.help"), systemImage: "questionmark.circle").font(.system(size: 11))
                }
                .buttonStyle(GlassButtonStyle())
                if let sync = cache.lastSync {
                    Text(L("settings.synced", sync.formatted(date: .abbreviated, time: .shortened)))
                        .font(.system(size: 9.5)).foregroundStyle(.tertiary)
                }
                Spacer()
                Button {
                    Task { await cache.refresh() }
                } label: {
                    if cache.syncing { ProgressView().controlSize(.small) }
                    else { Label(L("settings.sync"), systemImage: "arrow.triangle.2.circlepath").font(.system(size: 11)) }
                }
                .buttonStyle(GlassButtonStyle())
            }
        }
        .padding(18)
        .frame(width: 360)
        .onAppear { launchAtLogin = settings.launchAtLogin }
    }

    private var defaultServiceBinding: Binding<Int> {
        Binding(
            get: { settings.defaultServiceId },
            set: { newId in
                settings.defaultServiceId = newId
                settings.defaultServiceName = cache.services.first(where: { $0.id == newId })?.name ?? ""
            }
        )
    }

    private func testConnection() {
        testing = true
        testResult = nil
        let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            Keychain.saveToken(t)
            BexioAPI.shared.token = t
            do {
                let me = try await BexioAPI.shared.me()
                settings.bexioUserId = me.id
                settings.bexioUserName = me.displayName
                testOK = true
                testResult = "Connecté : \(me.displayName)"
                await cache.refresh()
            } catch {
                testOK = false
                testResult = error.localizedDescription
            }
            testing = false
        }
    }
}
