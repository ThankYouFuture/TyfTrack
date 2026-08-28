# TyfTrack — User Guide

TyfTrack is a tiny always-on-top macOS timer that books your work hours straight into **Bexio**. This page explains everything you need to run it day to day. The app follows your macOS language (English, French, German).

## 1. Setup

1. Build or download the app (see the [README](README.md)), move `TyfTrack.app` to `/Applications` and launch it.
2. Create a **personal API token** for your Bexio account on [developer.bexio.com](https://developer.bexio.com) → *API Tokens*.
3. In TyfTrack, open **⚙︎ Settings**, paste the token and click **Test & save**. The token is stored securely in the macOS **Keychain** — it never touches the disk in clear text.
4. TyfTrack fetches your Bexio user and caches your **contacts, projects and business activities** locally, so pickers and search are instant. Use **Sync** whenever you add data in Bexio.
5. Recommended: set a **default activity** and enable **Launch at login**.

> **First keychain prompt** — macOS may ask whether TyfTrack is allowed to read the token: click **Always Allow**.

## 2. Daily use

| Action | How |
|---|---|
| Start a timer | **＋ New timer** → pick client (searchable), project (filtered by client), activity, note → **Start** |
| Quick timer | **⚡** starts instantly with your defaults — assign client/project later via ✎ |
| Run several timers | Just start more — timers run in parallel |
| Pause / resume | ⏸ / ▶ on each card, or from the menu bar |
| Edit a running timer | ✎ on the card (client, project, activity, note, billable) |
| **Send to Bexio** | **✈** — nothing is ever sent before you click it |
| Discard | 🗑 — asks for confirmation, nothing is booked |
| Resume a sent entry | **🕘** lists the last 3 sent timers |

### What sending does

`✈` books a Bexio timesheet (`POST /2.0/timesheet`) with the duration (rounded per your settings — to the minute, or up to 5/6/15 min), the note, the billable flag and the status you configured (default **Done**). The date is the day the timer was started.

### Resuming a sent entry

Picking a timer under **🕘** the same day *continues* it: the clock restarts from the time already sent, the Bexio entry is flagged **In progress**, and the next `✈` **updates the same entry** with the new total — no duplicates in your books. On a later day it simply starts a fresh timer for that client/project.

## 3. Presence detection

- **Sleep** always pauses all running timers — closed lid means you stopped working.
- **Screen lock** pauses too (optional, on by default).
- **Inactivity**: after N minutes without keyboard/mouse (default 10), timers auto-pause **and the idle time is deducted** — walking away doesn't inflate your hours. Configurable or disableable in Settings.

Auto-paused cards show the reason; hit ▶ when you're back.

## 4. Menu bar

The tyf icon lives in the menu bar with the running timer ticking next to it. Click it to show/hide the panel, pause/resume any timer, start a quick timer, resume a recent one, or quit. Closing the panel (✕) keeps the app running in the menu bar.

## 5. Automation (Shortcuts / Siri)

TyfTrack exposes a URL scheme you can call from the macOS **Shortcuts** app (action *Open URL*), and therefore by voice with Siri:

| URL | Effect |
|---|---|
| `tyftrack://start?note=...` | Start a quick timer |
| `tyftrack://pause` | Pause all timers |
| `tyftrack://resume` | Resume paused timers |
| `tyftrack://show` | Show the panel |

## 6. Files & troubleshooting

| What | Where |
|---|---|
| Timers & recents (survive restarts) | `~/Library/Application Support/TyfTrack/state.json` |
| Bexio cache | `~/Library/Application Support/TyfTrack/cache.json` |
| Debug log (API/keychain errors) | `~/Library/Application Support/TyfTrack/tyftrack.log` |
| API token | macOS Keychain, service `ch.tyf.TyfTrack` |

- **"No API token configured"** → Settings, paste token, *Test & save*, accept the keychain prompt with *Always Allow*.
- **Empty pickers** → click Sync (⟳) and check the token.
- **Gatekeeper blocks a downloaded app** ("damaged / unidentified developer") → the release builds are not notarized; run once:
  `xattr -d com.apple.quarantine /Applications/TyfTrack.app`
- Timers that were running when the app quits are restored **paused**, credited up to the last save.

---
Made by [TYF](https://tyf.ch) · Questions & issues: [GitHub issues](https://github.com/ThankYouFuture/TyfTrack/issues)
