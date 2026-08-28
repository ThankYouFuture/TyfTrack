import SwiftUI

/// Create a new timer or edit an existing one (client / project / activity / note).
struct TimerEditorView: View {
    enum Mode {
        case create
        case edit(WorkTimer)
    }

    let mode: Mode
    @EnvironmentObject var store: TimerStore
    @EnvironmentObject var cache: BexioCache
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var draft = WorkTimer()
    @State private var contactQuery = ""
    @State private var initialized = false

    private var isCreate: Bool {
        if case .create = mode { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(isCreate ? "Nouveau chrono" : "Modifier le chrono")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                if cache.syncing {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await cache.refresh() }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .help("Recharger clients, projets et activités depuis Bexio")
                }
            }

            if cache.contacts.isEmpty && !cache.syncing {
                Label("Aucune donnée Bexio en cache — clique sur ⟳ ou vérifie ton jeton dans les réglages.",
                      systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
            if let err = cache.syncError {
                Text(err).font(.system(size: 10.5)).foregroundStyle(.orange).lineLimit(2)
            }

            // Client
            VStack(alignment: .leading, spacing: 4) {
                Text("CLIENT").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.secondary)
                TextField("Rechercher un client…", text: $contactQuery)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                if !filteredContacts.isEmpty && selectedContactNeedsList {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(filteredContacts.prefix(30)) { c in
                                Button {
                                    draft.contactId = c.id
                                    draft.contactName = c.displayName
                                    contactQuery = c.displayName
                                    if let p = cache.projects.first(where: { $0.contact_id == c.id }),
                                       cache.projects.filter({ $0.contact_id == c.id }).count == 1 {
                                        draft.projectId = p.id
                                        draft.projectName = p.name
                                    }
                                } label: {
                                    HStack {
                                        Text(c.displayName).font(.system(size: 11.5))
                                        Spacer()
                                        if let nr = c.nr { Text(nr).font(.system(size: 9.5)).foregroundStyle(.tertiary) }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 3)
                                .padding(.horizontal, 6)
                                .background(draft.contactId == c.id ? Brand.accent.opacity(0.25) : .clear,
                                            in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .frame(maxHeight: 110)
                }
                if draft.contactId != nil {
                    HStack(spacing: 6) {
                        Label(draft.contactName, systemImage: "person.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Brand.accent)
                        Button {
                            draft.contactId = nil; draft.contactName = ""
                            draft.projectId = nil; draft.projectName = ""
                            contactQuery = ""
                        } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 10)) }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                }
            }

            // Projet
            VStack(alignment: .leading, spacing: 4) {
                Text("PROJET (optionnel)").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.secondary)
                Picker("", selection: projectBinding) {
                    Text("— Aucun —").tag(0)
                    ForEach(cache.projects(forContact: draft.contactId)) { p in
                        Text(p.name).tag(p.id)
                    }
                }
                .labelsHidden()
            }

            // Activité
            VStack(alignment: .leading, spacing: 4) {
                Text("ACTIVITÉ / PRESTATION").font(.system(size: 9.5, weight: .semibold)).foregroundStyle(.secondary)
                Picker("", selection: serviceBinding) {
                    Text("— Choisir —").tag(0)
                    ForEach(cache.services) { s in
                        Text(s.name).tag(s.id)
                    }
                }
                .labelsHidden()
            }

            TextField("Note (description de la prestation)", text: $draft.note)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            Toggle("Facturable", isOn: $draft.billable)
                .font(.system(size: 12))
                .toggleStyle(.switch)
                .controlSize(.small)

            HStack {
                Button("Annuler") { dismiss() }
                    .buttonStyle(GlassButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    save()
                } label: {
                    Label(isCreate ? "Démarrer" : "Enregistrer",
                          systemImage: isCreate ? "play.fill" : "checkmark")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .buttonStyle(GlassButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 330)
        .onAppear { initializeDraft() }
        .task {
            if cache.contacts.isEmpty && !cache.syncing { await cache.refresh() }
        }
    }

    private func initializeDraft() {
        guard !initialized else { return }
        initialized = true
        switch mode {
        case .create:
            draft = WorkTimer()
            draft.billable = settings.defaultBillable
            if settings.defaultServiceId != 0 {
                draft.serviceId = settings.defaultServiceId
                draft.serviceName = settings.defaultServiceName
            }
        case .edit(let t):
            draft = t
            contactQuery = t.contactName
        }
    }

    private var filteredContacts: [BexioAPI.Contact] {
        let q = contactQuery.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return cache.contacts }
        return cache.contacts.filter { $0.displayName.localizedCaseInsensitiveContains(q) || ($0.nr ?? "").contains(q) }
    }

    private var selectedContactNeedsList: Bool {
        draft.contactId == nil || contactQuery != draft.contactName
    }

    private var projectBinding: Binding<Int> {
        Binding(
            get: { draft.projectId ?? 0 },
            set: { newId in
                if newId == 0 {
                    draft.projectId = nil; draft.projectName = ""
                } else if let p = cache.projects.first(where: { $0.id == newId }) {
                    draft.projectId = p.id
                    draft.projectName = p.name
                    if draft.contactId == nil, let cid = p.contact_id,
                       let c = cache.contacts.first(where: { $0.id == cid }) {
                        draft.contactId = c.id
                        draft.contactName = c.displayName
                        contactQuery = c.displayName
                    }
                }
            }
        )
    }

    private var serviceBinding: Binding<Int> {
        Binding(
            get: { draft.serviceId ?? 0 },
            set: { newId in
                if newId == 0 {
                    draft.serviceId = nil; draft.serviceName = ""
                } else if let s = cache.services.first(where: { $0.id == newId }) {
                    draft.serviceId = s.id
                    draft.serviceName = s.name
                }
            }
        )
    }

    private func save() {
        switch mode {
        case .create:
            store.addTimer(draft)
        case .edit:
            store.update(draft)
        }
        dismiss()
    }
}
