# CLAUDE.md — Train Alarm

> Agentic build spec for **Train Alarm**, a GPS + live-train-status journey alerting app for Indian Railways.
> Stack: **Flutter (Dart) · Firebase (Auth, Firestore, Cloud Functions) · SQLite · RailRadar API**.
> Build style: sequential, phase-gated. Do not start a phase until the previous phase's acceptance checks pass.

---

## 1. Product in one paragraph

A passenger picks a destination station (optionally + train number) and arms an alarm. The app raises a loud, full-screen, silent-mode-overriding alarm as the train reaches/nears that station. Two independent signals drive it: **native OS geofencing (GPS)** and **RailRadar live train status**. Whichever detects the station first fires. Live data also decides *when* to activate GPS, saving battery and staying inside the free API quota.

## 2. Non-negotiable constraints

- **API quota:** RailRadar free tier = **300 req/day, 10 req/min burst**. All polling MUST be adaptive (see §6). A single journey must fit comfortably (target ≤ 60 calls).
- **API key never in the client.** All RailRadar calls go through a Firebase **Cloud Function proxy** that injects the `Authorization: Bearer` header and caches responses.
- **Alarm must fire when the app is killed.** Use native geofencing (OS-level), not just an in-process timer.
- **Alarm overrides silent/DND.** Full-screen intent + alarm-manager wake + vibration.
- **Station search is offline.** 7,300+ stations ship bundled as SQLite. No API call for search.
- **Two modes:** simple (GPS-only, no train number) and train-aware (with train number). Simple mode must fully work with zero network.

## 3. Architecture

```
Flutter App
├── Presentation      Home · SetAlarm · LiveTracking · Ringing · Settings
├── Business Logic    AlarmManager · DetectionEngine (state machine) · AdaptivePoller
├── Device Services   Location/Geofence · Notifications · AlarmSound
└── Local Data        stations.db (SQLite, bundled) · cached live state

Firebase
├── Auth              Phone OTP
├── Firestore         users, alarms, history
└── Cloud Function    railradar proxy (+ cache, key injection, shared polling)

External           RailRadar REST API · GNSS/GPS
```

Layering rule: Presentation → Logic → (Services | Data). No widget calls the API or DB directly; it goes through a repository/service.

## 4. Data models

### 4.1 Local station DB — `stations` (SQLite, read-only, bundled asset)
| column | type | notes |
|---|---|---|
| `code` | TEXT PK | e.g. `NDLS` |
| `name` | TEXT | full name |
| `lat`  | REAL | for geofencing |
| `lng`  | REAL | for geofencing |
| `state`| TEXT | filter/label |

Index on `name` and `code` for fast `LIKE` search. Ship as `assets/stations.db`; copy to app docs dir on first run.

### 4.2 Firestore
```
users/{uid}                     { phone, displayName, createdAt, favouriteStations: [code] }
users/{uid}/alarms/{alarmId}    { stationCode, stationName, lat, lng,
                                  trainNo|null, triggerRadiusM, leadTimeMin,
                                  isActive, createdAt }
users/{uid}/history/{id}        { stationCode, trainNo, firedAt, method: 'gps'|'live' }
```
RLS/security rules: a user can read/write only under their own `users/{uid}`.

## 5. Detection engine — state machine (the core)

States per active alarm, destination = **T**:

| State | Enter when | Actions |
|---|---|---|
| `IDLE` | armed, far | train-aware: poll live every **20–30 min**; simple: OS significant-location-change only |
| `APPROACHING` | ETA(T) < 45 min **or** ≤ 2 stops **or** GPS < 20 km | register **2 km** geofence; poll every **5 min** |
| `NEAR` | `nextHalt == T` **or** GPS < 3 km **or** final `segmentProgress > 0.7` | pre-arrival notification; poll every **1–2 min** |
| `ARRIVED` | geofence entered (**< 800 m**) **or** live `currentStation == T` | fire full-screen alarm + sound + vibration; stop |

Fail-safes:
- **Overshoot:** live shows train *departed* T → fire immediately.
- **Diverted/rescheduled:** read `data.exceptions[]`; keep tracking, adjust ETA, surface a banner.
- **Whichever signal hits first wins.** Never wait for the second.

## 6. Adaptive polling (quota math)

Interval is a pure function of state: `IDLE→25m, APPROACHING→5m, NEAR→90s`. Reference budget for a long trip: mostly IDLE (~2–3/hr) tightening only in the last hour ⇒ **~30–60 calls/journey**. Poller must: (a) pause when app is offline, (b) dedupe via the Cloud Function cache, (c) hard-stop at ARRIVED.

## 7. RailRadar endpoints (via proxy)

Base: `https://api.railradar.in/v1` — Bearer key added by the Cloud Function only.

| Endpoint | Use |
|---|---|
| `GET /trains/{number}/live?includeCoordinates=true` | primary: position, `nextHalt`, `delayMinutes`, `currentLocation.segmentProgress`, per-stop `lat/lng` |
| `GET /trains/{number}` | schedule/details on alarm creation |
| `GET /stations/{code}/trains` | station board — find train when number unknown |
| `GET /lookup/trains` | cache once → client-side train-number search |

Response envelope: `{ success, data, meta }`. Handle `401/404/429/503`. On `429`, back off and lean on GPS.

## 8. Screens (keep it minimal)

1. **Home** — list of active alarms + big `＋ New Alarm`.
2. **Set Alarm** — station search → (optional) train number → trigger radius + lead time → Arm.
3. **Live Tracking** — map, next station, ETA, delay (train-aware only).
4. **Ringing** — full-screen "Arriving at {station}" · Dismiss / Snooze.
5. **Settings** — default radius, alarm sound, permissions, battery-optimisation prompt.

Design: light, clean, high-legibility, one-handed. Follow the frontend-design skill tokens.

## 9. Packages (pin exact versions at build time)

`firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `sqflite`, `path`, `geolocator`, `flutter_background_geolocation` *or* `geofence_service`, `flutter_local_notifications`, `android_alarm_manager_plus`, `flutter_riverpod` (or `provider`), `dio`.

## 10. Conventions

- State management: Riverpod. Immutable models with `freezed`/`json_serializable` (or hand-written `fromJson`).
- Folder: `lib/{features,core,data,services}`. Feature-first.
- No secrets in repo. `google-services.json` / `GoogleService-Info.plist` git-ignored.
- Every service has a fake for tests. Detection engine is pure Dart, unit-testable without Flutter.
- Commit per phase; tag `phase-N-done`.

---

# BUILD PLAN — phase-gated Claude Code prompt chain

Run each prompt in Claude Code from the project root. **Do not proceed until the phase's ✅ checks pass.**

### Phase 0 — Scaffold
```
Create a new Flutter app "train_alarm" (org in.napcodes). Set up feature-first folders
lib/{features,core,data,services}, add Riverpod, dio, and a placeholder MaterialApp with
a light clean theme (single seed color, Material 3). Add .gitignore for Firebase config
files. No functionality yet — just compile and run an empty Home scaffold.
```
✅ App builds and runs on emulator; empty Home shows.

### Phase 1 — Offline station DB + search
```
I have (or generate) a stations dataset (code,name,lat,lng,state) for 7,300+ Indian
Railways stations. Build assets/stations.db (SQLite) from it. On first launch copy it to
the app documents dir. Implement StationRepository with searchByNameOrCode(query) using
indexed LIKE queries. Build a StationSearch screen with an instant-filter search field and
result list. Everything offline. Add unit tests for the repository.
```
✅ Typing "NDLS" or "New Del" returns results instantly with no network.

### Phase 2 — Auth + Firestore alarm CRUD + Home
```
Wire Firebase (Auth, Firestore). Implement phone-OTP login flow and create users/{uid}
on first login. Define the Alarm model and AlarmRepository (create/read/update/delete under
users/{uid}/alarms). Build the Home screen listing active alarms with a ＋ New Alarm FAB,
and a Set Alarm screen: pick station (Phase 1 search) → trigger radius + lead time → Arm.
Train number optional field (store only for now). Add Firestore security rules limiting
access to the owner. 
```
✅ User logs in, creates/edits/deletes an alarm, sees it on Home, data in Firestore.

### Phase 3 — GPS geofence + notification + Ringing (SIMPLE-MODE MVP)
```
Implement LocationService using native geofencing (geofence_service or
flutter_background_geolocation): register a geofence at the alarm's (lat,lng) with the chosen
radius. On ENTER, trigger a full-screen alarm: flutter_local_notifications full-screen intent
+ android_alarm_manager_plus to ring/vibrate over silent/DND. Build the Ringing screen
(Arriving at {station}, Dismiss/Snooze). Ensure it fires when the app is killed. Add an
Android battery-optimisation exemption prompt. This completes a working GPS-only MVP.
```
✅ Enter the geofence (or mock location) with app killed → full-screen alarm rings; Dismiss/Snooze work.

### Phase 4 — Cloud Function proxy + live status UI
```
Create a Firebase Cloud Function `railradar` that proxies GET requests to
https://api.railradar.in/v1/*, injecting the Bearer key from function config, with a short
in-memory/Firestore cache keyed by (endpoint,trainNo,minute). Implement RailRadarService in
the app calling ONLY this proxy (never the API directly). Build the Live Tracking screen for
train-aware alarms: show next halt, delay, ETA, and status from /trains/{number}/live.
Parse the {success,data,meta} envelope and handle 401/404/429/503.
```
✅ For a running train number, the app shows correct live next-halt/delay/ETA; key is only in the function.

### Phase 5 — Hybrid detection engine + adaptive polling
```
Implement DetectionEngine as pure Dart: the IDLE→APPROACHING→NEAR→ARRIVED state machine
from CLAUDE.md §5, consuming both GPS distance and live-status data. Implement AdaptivePoller
with per-state intervals (25m/5m/90s), offline pause, and hard-stop at ARRIVED. Fire the
alarm on whichever signal hits first. Add the pre-arrival notification in NEAR. Handle
overshoot (train departed T → fire now) and exceptions[] (diverted/rescheduled). Write unit
tests for every transition and the quota budget (assert a simulated journey ≤ 60 calls).
```
✅ Simulated journeys fire correctly for: normal arrival, network loss (GPS fires), weak GPS (live fires), 40-min delay, overshoot. Call count within quota.

### Phase 6 — Hardening + polish
```
Harden background execution across OEMs (Xiaomi/Oppo/Vivo notes), verify iOS region
monitoring limits, finalise Settings (default radius, sound picker, permissions status),
add empty/error states, and apply final visual polish per the frontend-design skill.
Capture screenshots of Home, Set Alarm, Live Tracking, Ringing for the report.
```
✅ Reliable on a real device through a real/simulated journey; screenshots captured.

---

## Definition of Done
Simple mode works fully offline and fires when killed; train-aware mode shows accurate live ETA and fires via whichever signal is first; a full journey stays within the free API quota; the key is never in the client; and the five screens match the minimal design.
