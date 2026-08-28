import Foundation

/// Lightweight localization: French, English, German — follows the OS language.
enum L10n {
    static let lang: String = {
        for l in Locale.preferredLanguages {
            let code = String(l.prefix(2)).lowercased()
            if ["fr", "en", "de"].contains(code) { return code }
        }
        return "en"
    }()

    // [key: [fr, en, de]]
    static let table: [String: [String]] = [
        "app.today": ["Aujourd'hui : %@", "Today: %@", "Heute: %@"],
        "help.settings": ["Réglages", "Settings", "Einstellungen"],
        "help.logo": ["Ouvrir tyf.ch", "Open tyf.ch", "tyf.ch öffnen"],
        "empty.title": ["Aucun chrono en cours", "No timer running", "Kein Timer aktiv"],
        "empty.subtitle": ["Lance un chrono par client et projet,\nplusieurs en parallèle si tu veux.",
                           "Start one timer per client and project —\nrun several in parallel if you like.",
                           "Starte einen Timer pro Kunde und Projekt —\ngerne mehrere parallel."],
        "btn.new": ["Nouveau chrono", "New timer", "Neuer Timer"],
        "help.express": ["Chrono express : démarre tout de suite, tu choisis le client plus tard",
                         "Quick timer: starts right away, pick the client later",
                         "Express-Timer: startet sofort, Kunde später wählen"],
        "help.resumeMenu": ["Reprendre un des derniers chronos envoyés et le continuer",
                            "Resume one of the last sent timers and keep going",
                            "Einen der zuletzt gesendeten Timer fortsetzen"],
        "recent.continue": [" (continuer, %d min)", " (continue, %d min)", " (fortsetzen, %d Min.)"],
        "timer.express": ["Chrono express", "Quick timer", "Express-Timer"],
        "card.billable": ["facturable", "billable", "verrechenbar"],
        "card.nonbillable": ["non facturable", "non-billable", "nicht verrechenbar"],
        "card.note.placeholder": ["Note pour la prestation…", "Note for the entry…", "Notiz zur Leistung…"],
        "card.linked": ["Continue la saisie Bexio (%d min déjà envoyées, le total la remplacera)",
                        "Continues the Bexio entry (%d min already sent, the total will replace it)",
                        "Setzt den Bexio-Eintrag fort (%d Min. bereits gesendet, das Total ersetzt ihn)"],
        "help.pause": ["Mettre en pause", "Pause", "Pausieren"],
        "help.resumeTimer": ["Reprendre", "Resume", "Fortsetzen"],
        "help.send": ["Terminer et envoyer dans Bexio (%d min)", "Finish and send to Bexio (%d min)",
                      "Abschliessen und an Bexio senden (%d Min.)"],
        "help.discard": ["Abandonner ce chrono (rien n'est envoyé)", "Discard this timer (nothing is sent)",
                         "Timer verwerfen (nichts wird gesendet)"],
        "confirm.discard": ["Abandonner « %@ » (%@) sans envoyer ?", "Discard “%@” (%@) without sending?",
                            "„%@“ (%@) verwerfen, ohne zu senden?"],
        "btn.discard": ["Abandonner", "Discard", "Verwerfen"],
        "btn.cancel": ["Annuler", "Cancel", "Abbrechen"],
        "btn.start": ["Démarrer", "Start", "Starten"],
        "btn.save": ["Enregistrer", "Save", "Sichern"],

        "pause.user": ["En pause", "Paused", "Pausiert"],
        "pause.sleep": ["Pause auto — mise en veille", "Auto-paused — Mac went to sleep", "Auto-Pause — Ruhezustand"],
        "pause.idle": ["Pause auto — inactivité", "Auto-paused — inactivity", "Auto-Pause — Inaktivität"],
        "pause.lock": ["Pause auto — écran verrouillé", "Auto-paused — screen locked", "Auto-Pause — Bildschirm gesperrt"],

        "err.noservice": ["Choisis une activité (prestation) avant d'envoyer — ou définis une activité par défaut dans les réglages.",
                          "Pick a business activity before sending — or set a default one in Settings.",
                          "Wähle vor dem Senden eine Tätigkeit — oder lege in den Einstellungen eine Standard-Tätigkeit fest."],
        "err.noconfig": ["Connexion Bexio non configurée : ouvre les réglages et teste ton jeton API.",
                         "Bexio connection not configured: open Settings and test your API token.",
                         "Bexio-Verbindung nicht konfiguriert: Einstellungen öffnen und API-Token testen."],
        "info.updated": ["%@ — saisie Bexio mise à jour : total %d min ✓", "%@ — Bexio entry updated: total %d min ✓",
                         "%@ — Bexio-Eintrag aktualisiert: total %d Min. ✓"],
        "info.sent": ["%@ — %d min envoyées dans Bexio ✓", "%@ — %d min sent to Bexio ✓",
                      "%@ — %d Min. an Bexio gesendet ✓"],
        "err.send": ["Envoi Bexio échoué : %@", "Sending to Bexio failed: %@", "Senden an Bexio fehlgeschlagen: %@"],
        "info.idle": ["Pause auto après %d min d'inactivité — ce temps a été déduit.",
                      "Auto-paused after %d min of inactivity — that time was deducted.",
                      "Auto-Pause nach %d Min. Inaktivität — diese Zeit wurde abgezogen."],

        "editor.new": ["Nouveau chrono", "New timer", "Neuer Timer"],
        "editor.edit": ["Modifier le chrono", "Edit timer", "Timer bearbeiten"],
        "editor.reload.help": ["Recharger clients, projets et activités depuis Bexio",
                               "Reload clients, projects and activities from Bexio",
                               "Kunden, Projekte und Tätigkeiten aus Bexio neu laden"],
        "editor.nocache": ["Aucune donnée Bexio en cache — clique sur ⟳ ou vérifie ton jeton dans les réglages.",
                           "No Bexio data cached — click ⟳ or check your token in Settings.",
                           "Keine Bexio-Daten im Cache — ⟳ klicken oder Token in den Einstellungen prüfen."],
        "editor.client": ["CLIENT", "CLIENT", "KUNDE"],
        "editor.client.search": ["Rechercher un client…", "Search for a client…", "Kunde suchen…"],
        "editor.project": ["PROJET (optionnel)", "PROJECT (optional)", "PROJEKT (optional)"],
        "editor.none": ["— Aucun —", "— None —", "— Keines —"],
        "editor.activity": ["ACTIVITÉ / PRESTATION", "BUSINESS ACTIVITY", "TÄTIGKEIT"],
        "editor.choose": ["— Choisir —", "— Choose —", "— Wählen —"],
        "editor.note": ["Note (description de la prestation)", "Note (work description)",
                        "Notiz (Beschreibung der Leistung)"],
        "editor.billable": ["Facturable", "Billable", "Verrechenbar"],

        "settings.title": ["Réglages", "Settings", "Einstellungen"],
        "settings.bexio": ["CONNEXION BEXIO", "BEXIO CONNECTION", "BEXIO-VERBINDUNG"],
        "settings.token.placeholder": ["Jeton API Bexio (developer.bexio.com)", "Bexio API token (developer.bexio.com)",
                                       "Bexio-API-Token (developer.bexio.com)"],
        "settings.test": ["Tester et enregistrer", "Test & save", "Testen & sichern"],
        "settings.connected": ["Connecté : %@", "Connected: %@", "Verbunden: %@"],
        "settings.token.hint": ["Crée un jeton personnel sur developer.bexio.com → API Tokens. Il est stocké dans le trousseau macOS.",
                                "Create a personal token on developer.bexio.com → API Tokens. It is stored in the macOS Keychain.",
                                "Erstelle einen persönlichen Token auf developer.bexio.com → API Tokens. Er wird im macOS-Schlüsselbund gespeichert."],
        "settings.defaults": ["VALEURS PAR DÉFAUT", "DEFAULTS", "STANDARDWERTE"],
        "settings.defaultActivity": ["Activité par défaut", "Default activity", "Standard-Tätigkeit"],
        "settings.noneF": ["— Aucune —", "— None —", "— Keine —"],
        "settings.defaultBillable": ["Facturable par défaut", "Billable by default", "Standardmässig verrechenbar"],
        "settings.status": ["Statut Bexio à l'envoi", "Bexio status on send", "Bexio-Status beim Senden"],
        "settings.rounding": ["Arrondi à l'envoi", "Rounding on send", "Rundung beim Senden"],
        "settings.rounding.minute": ["À la minute", "To the minute", "Auf die Minute"],
        "settings.rounding.up": ["%d min (sup.)", "%d min (up)", "%d Min. (auf)"],
        "settings.presence": ["PRÉSENCE", "PRESENCE", "ANWESENHEIT"],
        "settings.sleepNote": ["La mise en veille met toujours les chronos en pause.",
                               "Sleep always pauses the timers.",
                               "Der Ruhezustand pausiert die Timer immer."],
        "settings.lock": ["Pause quand l'écran se verrouille", "Pause when the screen locks", "Pause bei Bildschirmsperre"],
        "settings.idle": ["Pause auto après inactivité", "Auto-pause after inactivity", "Auto-Pause nach Inaktivität"],
        "settings.idle.off": ["Désactivée", "Off", "Aus"],
        "settings.min": ["%d min", "%d min", "%d Min."],
        "settings.idleNote": ["Le temps d'inactivité est automatiquement déduit du chrono.",
                              "Idle time is automatically deducted from the timer.",
                              "Inaktive Zeit wird automatisch vom Timer abgezogen."],
        "settings.login": ["Lancer TyfTrack à l'ouverture de session", "Launch TyfTrack at login",
                           "TyfTrack beim Anmelden starten"],
        "settings.synced": ["Données Bexio synchronisées %@", "Bexio data synced %@", "Bexio-Daten synchronisiert %@"],
        "settings.sync": ["Synchroniser", "Sync", "Synchronisieren"],
        "settings.help": ["Aide", "Help", "Hilfe"],

        "status.open": ["Ouvert", "Open", "Offen"],
        "status.inprogress": ["En cours", "In progress", "In Arbeit"],
        "status.done": ["Terminé", "Done", "Erledigt"],
        "err.notoken": ["Aucun jeton API configuré", "No API token configured", "Kein API-Token konfiguriert"],

        "menu.show": ["Afficher TyfTrack", "Show TyfTrack", "TyfTrack einblenden"],
        "menu.hide": ["Masquer TyfTrack", "Hide TyfTrack", "TyfTrack ausblenden"],
        "menu.express": ["⚡ Chrono express", "⚡ Quick timer", "⚡ Express-Timer"],
        "menu.resume": ["↻ Reprendre", "↻ Resume", "↻ Fortsetzen"],
        "menu.pauseAll": ["Tout mettre en pause", "Pause all", "Alle pausieren"],
        "menu.quit": ["Quitter TyfTrack", "Quit TyfTrack", "TyfTrack beenden"],
    ]
}

func L(_ key: String) -> String {
    guard let entry = L10n.table[key] else { return key }
    switch L10n.lang {
    case "fr": return entry[0]
    case "de": return entry[2]
    default: return entry[1]
    }
}

func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), arguments: args)
}
