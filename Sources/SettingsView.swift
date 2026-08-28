import SwiftUI

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
                Text("Réglages")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 10)) }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
            }

            // Bexio connection
            VStack(alignment: .leading, spacing: 6) {
                Text("CONNEXION BEXIO").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.secondary)
                SecureField("Jeton API Bexio (developer.bexio.com)", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                HStack(spacing: 8) {
                    Button {
                        testConnection()
                    } label: {
                        if testing { ProgressView().controlSize(.small) }
                        else { Text("Tester et enregistrer").font(.system(size: 11.5, weight: .semibold)) }
                    }
                    .buttonStyle(GlassButtonStyle(prominent: true))
                    .disabled(testing || token.isEmpty)

                    if let result = testResult {
                        Label(result, systemImage: testOK ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .font(.system(size: 10.5))
                            .foregroundStyle(testOK ? Brand.accent : .orange)
                            .lineLimit(2)
                    } else if settings.bexioUserId != 0 {
                        Label("Connecté : \(settings.bexioUserName)", systemImage: "person.badge.shield.checkmark")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Crée un jeton personnel sur developer.bexio.com → API Tokens. Il est stocké dans le trousseau macOS.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }

            Divider()

            // Defaults
            VStack(alignment: .leading, spacing: 8) {
                Text("VALEURS PAR DÉFAUT").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.secondary)

                HStack {
                    Text("Activité par défaut").font(.system(size: 12))
                    Spacer()
                    Picker("", selection: defaultServiceBinding) {
                        Text("— Aucune —").tag(0)
                        ForEach(cache.services) { s in Text(s.name).tag(s.id) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 170)
                }

                Toggle("Facturable par défaut", isOn: $settings.defaultBillable)
                    .font(.system(size: 12)).toggleStyle(.switch).controlSize(.small)

                HStack {
                    Text("Arrondi à l'envoi").font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $settings.roundingMinutes) {
                        Text("À la minute").tag(1)
                        Text("5 min (sup.)").tag(5)
                        Text("6 min (sup.)").tag(6)
                        Text("15 min (sup.)").tag(15)
                    }
                    .labelsHidden()
                    .frame(maxWidth: 170)
                }
            }

            Divider()

            // Presence
            VStack(alignment: .leading, spacing: 8) {
                Text("PRÉSENCE").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.secondary)
                Text("La mise en veille met toujours les chronos en pause.")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                Toggle("Pause quand l'écran se verrouille", isOn: $settings.pauseOnLock)
                    .font(.system(size: 12)).toggleStyle(.switch).controlSize(.small)
                HStack {
                    Text("Pause auto après inactivité").font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $settings.idleMinutes) {
                        Text("Désactivée").tag(0)
                        Text("5 min").tag(5)
                        Text("10 min").tag(10)
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                    }
                    .labelsHidden()
                    .frame(maxWidth: 170)
                }
                Text("Le temps d'inactivité est automatiquement déduit du chrono.")
                    .font(.system(size: 9.5)).foregroundStyle(.tertiary)
            }

            Divider()

            Toggle("Lancer TyfTrack à l'ouverture de session", isOn: $launchAtLogin)
                .font(.system(size: 12)).toggleStyle(.switch).controlSize(.small)
                .onChange(of: launchAtLogin) { _, newValue in
                    if settings.launchAtLogin != newValue { settings.launchAtLogin = newValue }
                }

            HStack {
                if let sync = cache.lastSync {
                    Text("Données Bexio synchronisées \(sync.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 9.5)).foregroundStyle(.tertiary)
                }
                Spacer()
                Button {
                    Task { await cache.refresh() }
                } label: {
                    if cache.syncing { ProgressView().controlSize(.small) }
                    else { Label("Synchroniser", systemImage: "arrow.triangle.2.circlepath").font(.system(size: 11)) }
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
