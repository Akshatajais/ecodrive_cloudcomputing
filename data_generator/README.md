# EcoDrive live data generator

Simulates vehicle sensors and pushes readings into Firebase.

**Note:** The Flutter app now auto-starts the same simulation in Dart when it
opens (`lib/services/live_telemetry_simulator.dart`). You usually do **not**
need to run this Python script for demos on a phone.

Use this Python script only if you want a separate Mac/server process writing
to Firebase (e.g. multi-device testing).

## Quick start (optional / desktop)

```bash
# From repo root
python3 -u data_generator/generate_telemetry.py --scenario mixed --interval 3
```

Then watch:

- **Dashboard** — emission score / gas / temp / humidity change every ~3s  
- **Graphs** — history grows under `carEmissions/history`  
- **Alerts** — when score ≥ 400 (common in `critical` / parts of `mixed`)

### Force many alerts

```bash
python3 data_generator/generate_telemetry.py --scenario critical --interval 2
```

### Print only (no Firebase)

```bash
python3 data_generator/generate_telemetry.py --dry-run --count 10
```

## What it writes

| Path | When |
|------|------|
| `carEmissions/liveData` | every tick |
| `carEmissions/history/YYYY-MM-DD/HH-MM-SS` | every tick |
| `carEmissions/alerts/<id>` | when `emissionScore >= 400` |

## Scenarios

`eco` · `normal` · `aggressive` · `idle` · `critical` · `mixed`

## Flutter side

1. `flutter run`
2. If you still see `Permission denied`, open RTDB rules for `carEmissions` read/write (or keep Auth-based rules and ensure the app can read).
3. Hot restart (`R`) after changing rules.
