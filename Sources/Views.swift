import SwiftUI
import AppKit

// MARK: - Brand

enum Brand {
    static let accent = Color(red: 0.22, green: 0.84, blue: 0.76)      // teal tyf
    static let accent2 = Color(red: 0.35, green: 0.52, blue: 0.98)     // blue
    static let accent3 = Color(red: 0.62, green: 0.40, blue: 0.95)     // violet
}

// MARK: - Liquid glass building blocks

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Blurred colored orbs floating behind the content — the tyf liquid-glass backdrop.
struct OrbBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle().fill(Brand.accent.opacity(0.55))
                    .frame(width: geo.size.width * 0.7)
                    .offset(x: -geo.size.width * 0.25, y: -geo.size.height * 0.30)
                Circle().fill(Brand.accent2.opacity(0.45))
                    .frame(width: geo.size.width * 0.8)
                    .offset(x: geo.size.width * 0.45, y: geo.size.height * 0.05)
                Circle().fill(Brand.accent3.opacity(0.40))
                    .frame(width: geo.size.width * 0.7)
                    .offset(x: -geo.size.width * 0.1, y: geo.size.height * 0.55)
            }
            .blur(radius: 70)
        }
        .allowsHitTesting(false)
    }
}

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var tint: Color = .white

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    // specular highlight (top sheen)
                    shape.fill(
                        LinearGradient(
                            colors: [tint.opacity(0.22), tint.opacity(0.04), .clear],
                            startPoint: .topLeading, endPoint: .center
                        )
                    )
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.55), .white.opacity(0.08), .white.opacity(0.25)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                }
            }
            .clipShape(shape)
            .shadow(color: .black.opacity(0.30), radius: 12, y: 6)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, tint: Color = .white) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, tint: tint))
    }
}

struct GlassButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                let shape = Capsule()
                ZStack {
                    if prominent {
                        shape.fill(LinearGradient(colors: [Brand.accent, Brand.accent2],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing))
                            .opacity(configuration.isPressed ? 0.7 : 0.9)
                    } else {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(Color.white.opacity(configuration.isPressed ? 0.15 : 0.06))
                    }
                    shape.strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
                }
            }
            .foregroundStyle(prominent ? Color.black.opacity(0.85) : Color.primary)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Root view

struct ContentView: View {
    @EnvironmentObject var store: TimerStore
    @EnvironmentObject var cache: BexioCache
    @EnvironmentObject var settings: AppSettings
    @State private var showNewTimer = false
    @State private var showSettings = false
    @State private var editingTimer: WorkTimer?

    var body: some View {
        ZStack {
            VisualEffectBackground()
            OrbBackdrop()

            VStack(spacing: 12) {
                header
                banners

                if store.timers.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(store.timers) { timer in
                                TimerCard(timer: timer) { editingTimer = timer }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 4)
                    }
                }

                bottomBar
            }
            .padding(.top, 30)
            .padding(.bottom, 14)
        }
        .ignoresSafeArea()
        .frame(minWidth: 340, idealWidth: 372, maxWidth: 480, minHeight: 380, idealHeight: 520, maxHeight: .infinity)
        .sheet(isPresented: $showNewTimer) {
            TimerEditorView(mode: .create)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(item: $editingTimer) { timer in
            TimerEditorView(mode: .edit(timer))
        }
        .onAppear {
            if settings.bexioUserId == 0 && Keychain.loadToken() == nil {
                showSettings = true
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let img = Bundle.main.image(named: "logo-tyf") {
                Image(nsImage: img)
                    .resizable().scaledToFit()
                    .frame(width: 30, height: 30)
                    .colorMultiply(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("TyfTrack")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text("Aujourd'hui : \(formatHM(store.totalToday))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 13))
            }
            .buttonStyle(GlassButtonStyle())
            .help("Réglages")
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var banners: some View {
        if let err = store.lastError {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(err).font(.system(size: 11)).lineLimit(3)
                Spacer()
                Button { store.lastError = nil } label: { Image(systemName: "xmark").font(.system(size: 9)) }
                    .buttonStyle(.plain)
            }
            .padding(10)
            .glassCard(cornerRadius: 12, tint: .orange)
            .padding(.horizontal, 14)
        }
        if let info = store.lastInfo {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Brand.accent)
                Text(info).font(.system(size: 11)).lineLimit(2)
                Spacer()
                Button { store.lastInfo = nil } label: { Image(systemName: "xmark").font(.system(size: 9)) }
                    .buttonStyle(.plain)
            }
            .padding(10)
            .glassCard(cornerRadius: 12, tint: Brand.accent)
            .padding(.horizontal, 14)
            .task {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                store.lastInfo = nil
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "timer")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text("Aucun chrono en cours")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Lance un chrono par client et projet,\nplusieurs en parallèle si tu veux.")
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button {
                showNewTimer = true
            } label: {
                Label("Nouveau chrono", systemImage: "plus")
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .buttonStyle(GlassButtonStyle(prominent: true))

            Button {
                store.addExpressTimer()
            } label: {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .buttonStyle(GlassButtonStyle())
            .help("Chrono express : démarre tout de suite, tu choisis le client plus tard")

            if !store.recents.isEmpty {
                Menu {
                    ForEach(store.recents.prefix(3)) { r in
                        Button {
                            store.restart(r)
                        } label: {
                            Text(r.projectName.isEmpty ? r.displayTitle : "\(r.displayTitle) — \(r.projectName)")
                        }
                    }
                } label: {
                    Label("Reprendre", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background {
                    ZStack {
                        Capsule().fill(.ultraThinMaterial)
                        Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
                    }
                }
                .help("Relancer un des derniers chronos envoyés")
            }
        }
        .padding(.horizontal, 14)
    }
}

// MARK: - Timer card

struct TimerCard: View {
    @EnvironmentObject var store: TimerStore
    @EnvironmentObject var settings: AppSettings
    let timer: WorkTimer
    var onEdit: () -> Void
    @State private var sending = false
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timer.displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Modifier client / projet / activité")
            }

            HStack(alignment: .center, spacing: 10) {
                TimelineView(.periodic(from: .now, by: timer.isRunning ? 1 : 3600)) { _ in
                    Text(formatHMS(timer.elapsed))
                        .font(.system(size: 26, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(timer.isRunning ? Color.primary : Color.secondary)
                        .contentTransition(.numericText())
                }
                if timer.isRunning {
                    Circle().fill(Brand.accent).frame(width: 7, height: 7)
                        .shadow(color: Brand.accent, radius: 4)
                }
                Spacer()

                Button { store.toggle(timer.id) } label: {
                    Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 18)
                }
                .buttonStyle(GlassButtonStyle())
                .help(timer.isRunning ? "Mettre en pause" : "Reprendre")

                Button {
                    sending = true
                    Task {
                        await store.finishAndSend(timer.id)
                        sending = false
                    }
                } label: {
                    if sending {
                        ProgressView().controlSize(.small).frame(width: 18)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 18)
                    }
                }
                .buttonStyle(GlassButtonStyle(prominent: true))
                .disabled(sending)
                .help("Terminer et envoyer dans Bexio (\(store.roundedMinutes(for: timer)) min)")

                Button { confirmDelete = true } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Abandonner ce chrono (rien n'est envoyé)")
                .confirmationDialog("Abandonner « \(timer.displayTitle) » (\(formatHMS(timer.elapsed))) sans envoyer ?",
                                    isPresented: $confirmDelete) {
                    Button("Abandonner", role: .destructive) { store.delete(timer.id) }
                    Button("Annuler", role: .cancel) {}
                }
            }

            if let reason = timer.pauseReason, !timer.isRunning, reason != .user {
                Label(reason.label, systemImage: "moon.zzz.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }

            TextField("Note pour la prestation…", text: noteBinding)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)))
        }
        .padding(12)
        .glassCard(tint: timer.isRunning ? Brand.accent : .white)
    }

    private var subtitle: String {
        var parts: [String] = []
        if !timer.projectName.isEmpty { parts.append(timer.projectName) }
        if !timer.serviceName.isEmpty { parts.append(timer.serviceName) }
        parts.append(timer.billable ? "facturable" : "non facturable")
        return parts.joined(separator: " • ")
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { store.timers.first(where: { $0.id == timer.id })?.note ?? "" },
            set: { newValue in
                var t = store.timers.first(where: { $0.id == timer.id }) ?? timer
                t.note = newValue
                store.update(t)
            }
        )
    }
}

extension Bundle {
    func image(named name: String) -> NSImage? {
        guard let url = url(forResource: name, withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }
}
