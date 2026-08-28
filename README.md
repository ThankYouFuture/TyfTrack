# TyfTrack ⏱

Mini-app macOS **toujours au premier plan** pour chronométrer le travail par client / projet et envoyer les heures directement dans **Bexio** (`POST /2.0/timesheet`). Design *liquid glass* aux couleurs de [tyf.ch](https://tyf.ch).

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-SwiftUI-orange)

## Fonctionnalités

- **Chronos multiples en parallèle** — un par client/projet, panneau flottant au-dessus de toutes les fenêtres.
- **Pause / reprise** par chrono, ou tout mettre en pause d'un coup depuis la barre de menus.
- **Envoi manuel uniquement** : rien ne part dans Bexio avant le clic sur ✈ (Terminer & envoyer).
- **Mise en veille = pause automatique** (toujours). Options : pause au verrouillage de l'écran, pause après X min d'inactivité clavier/souris **avec déduction du temps d'absence**.
- **Chrono express** ⚡ : démarre immédiatement, tu qualifies client/projet plus tard.
- **Arrondi configurable** à l'envoi : minute, 5, 6 ou 15 min (arrondi supérieur).
- **Barre de menus** : temps qui défile, liste des chronos, pause/reprise rapide.
- **Persistance** : les chronos survivent à un redémarrage de l'app (restaurés en pause).
- **Cache local** clients / projets / activités Bexio (recherche instantanée, projets filtrés par client).
- Jeton API stocké dans le **trousseau macOS**.

## Installation / build

```bash
./Scripts/build.sh
open build/TyfTrack.app
```

Compile avec les Command Line Tools seuls (pas besoin d'Xcode). `python3 Scripts/make_icon.py` régénère l'icône depuis `Resources/logo-tyf.png`.

## Configuration Bexio

1. Crée un jeton API personnel sur [developer.bexio.com](https://developer.bexio.com) (API Tokens).
2. Ouvre TyfTrack → ⚙︎ Réglages → colle le jeton → **Tester et enregistrer**.
3. L'app récupère ton `user_id` (`GET /3.0/users/me`) et synchronise contacts (`/2.0/contact`), projets (`/2.0/pr_project`) et activités (`/2.0/client_service`).
4. À l'envoi : `POST /2.0/timesheet` avec `tracking: {type: "duration", date, duration}` — la date est celle du **début** du chrono.

## Siri / Raccourcis

L'app expose un schéma d'URL `tyftrack://` utilisable dans l'app **Raccourcis** (action « Ouvrir l'URL ») puis à la voix : *« Dis Siri, chrono TYF »*.

| URL | Action |
|---|---|
| `tyftrack://start?note=…` | Démarre un chrono express |
| `tyftrack://pause` | Met tout en pause |
| `tyftrack://resume` | Reprend les chronos en pause |
| `tyftrack://show` | Affiche le panneau |

> Des App Intents Siri natifs (« Démarre un chrono pour Ayliffe ») nécessitent une compilation avec Xcode complet — prévu quand Xcode 26 sera installé, tout comme l'adoption de l'API native `.glassEffect`.

## Architecture

```
Sources/
├── main.swift            Point d'entrée AppKit
├── AppDelegate.swift     Panneau flottant, barre de menus, URL scheme
├── Models.swift          TimerStore : chronos, veille/verrouillage/inactivité, persistance
├── BexioAPI.swift        Client REST api.bexio.com + cache local
├── Keychain.swift        Stockage du jeton
├── Settings.swift        Préférences (UserDefaults)
└── *View*.swift          SwiftUI, style liquid glass custom
```
