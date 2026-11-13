# EcoDrive — Technical Documentation (IEEE-Ready)

**Project:** EcoDrive (Smart Vehicle Emission Monitoring + On-device ML)  
**Repository:** `pollutionapp`  
**Document type:** System technical documentation suitable for an IEEE-style project report

---

## Cover page blurb (copy/paste)

EcoDrive is an end-to-end smart vehicle monitoring system that integrates a Python telemetry data generator, cloud data synchronization (Firebase Realtime Database), and a Flutter mobile application with on-device machine learning. The system streams emission-related telemetry, logs historical data, triggers alerts, and provides interpretable insights for both driver behavior and vehicle health. ML models are trained using a Firebase-seeded hybrid pipeline (real historical distributions + realistic synthetic sessions) and deployed as quantized TensorFlow Lite for efficient inference on mobile devices.

---

## Abstract (150–200 words)

Vehicle emissions reflect complex interactions between driver behavior, vehicle condition, and environment; as a result, point-wise thresholds often produce noisy alerts. This project presents EcoDrive, an end-to-end monitoring system combining a Python data generator, cloud synchronization, and mobile analytics with on-device machine learning. A Python script generates realistic gas and environmental readings, computes an emission score, and writes live and historical data into Firebase Realtime Database. A Flutter application consumes Firebase streams to render dashboards, time-series graphs, and alert logs, and runs session-based ML inference locally to estimate driver behavior and vehicle health. The ML pipeline transforms Firebase history into session windows, derives statistical structure, generates realistic synthetic sessions, applies rule-based pseudo-labeling for supervised training, and exports int8 quantized TensorFlow Lite models with consistent preprocessing metadata. The resulting system supports real-time monitoring, historical review, and portable inference, while emphasizing reproducible workflows and clear interfaces between the data generator, cloud data paths, and app components.

---

## Keywords

Cloud computing; Python data generator; Firebase Realtime Database; Flutter; TensorFlow Lite; Quantization; Edge ML; Emission monitoring.

---

## 1. System overview

EcoDrive consists of three major subsystems:

- **Data generator (`data_generator/`)**: Python script generates emission telemetry and writes it to Firebase (replaces physical sensors + MQTT).
- **ML pipeline (`ML/`)**: Python pipeline builds session-based models for driver behavior and vehicle health; exports TFLite artifacts for mobile.
- **Mobile app (Flutter `lib/`)**: UI + state management, connects to Firebase, renders dashboards/graphs/alerts, runs TFLite inference locally, and displays camera stream URLs when available.

### Data-plane summary

- **Realtime telemetry**: Python generator → Firebase `carEmissions/liveData` (JSON object).
- **Cloud state**: Firebase Realtime Database (RTDB), under the `carEmissions/` namespace.

---

## 2. Repository layout

Top-level structure (key folders):

- `data_generator/` — Python telemetry generator (writes Firebase live/history/alerts)
- `iot_code/` — optional legacy ESP32-CAM firmware only
- `ML/` — Python ML pipeline, training scripts, and exported models
- `lib/` — Flutter application code (UI, providers, services)
- `docs/` — project documentation (this file, plus ML methodology)

---

## 3. Interfaces and data contracts

### 3.1 Telemetry contract (Python data generator → Firebase → app)

- **Producer**: `data_generator/generate_telemetry.py`
- **Transport**: Firebase Realtime Database writes (no MQTT)
- **Payload fields** (JSON object):
  - `rawGas` (float)
  - `temperature` (float)
  - `humidity` (float)
  - `emissionScore` (int)
  - `timestamp` (string, IST `YYYY-MM-DD HH:MM:SS`)

**Implementation notes**

- The generator publishes on a fixed interval (default 5 s) into `liveData` and appends the same record under `history`.
- Scenarios (`eco`, `normal`, `aggressive`, `idle`, `critical`, `mixed`) control noise, spikes, and score range.
- Flutter listens only to Firebase; no broker subscription is required.

### 3.2 Firebase RTDB schema (generator/app shared)

All project paths are under `carEmissions/`:

- `carEmissions/liveData`  
  Latest telemetry record (JSON object).

- `carEmissions/history/<YYYY-MM-DD>/<HH-MM-SS>`  
  Historical records keyed by date folder and time key (JSON object).

- `carEmissions/alerts/<alertId>`  
  Alert records; written when the emission score crosses the threshold. Producers:
  - **Python data generator**: writes a small JSON alert when `emissionScore >= 400`.
  - **Optional ESP32-CAM (`iot_code/cam.cpp`)**: can write alert metadata and a JPEG blob under `carEmissions/alerts/<alertId>/image`.

- `carEmissions/camera` *(optional app configuration)*  
  Camera stream configuration used by the Flutter app (`CameraStreamProvider`). This node may be set manually (or by a separate process) and supports:
  - `streamUrl` (string, e.g., `http://<ip>/`)
  - alternative keys accepted by the app: `url`, `stream`

---

## 4. Data generator subsystem (`data_generator/`)

### 4.1 Role

Replaces physical MQ-7 / DHT sensors and MQTT publishing. Generates realistic telemetry locally and pushes it to Firebase so the mobile app and ML history path keep the same schema.

### 4.2 Generator logic

Key behaviors in `data_generator/generate_telemetry.py`:

- Load Firebase Admin credentials from `ML/.env`
- Every `--interval` seconds (default 5):
  - sample `rawGas`, `temperature`, `humidity` from the selected scenario
  - compute `emissionScore` using the calibrated mapping
  - write `liveData`, append into `history`, and conditionally write `alerts`

### 4.3 Emission score computation

The generator maps raw gas readings into a bounded score (same calibration as the former firmware):

- `cleanAir = 200` and `maxSmoke = 700` calibrate the expected raw range.
- Score maps raw values into approximately `[50, 500]`.

### 4.4 Optional ESP32-CAM support

Camera capability remains optional via separate firmware:

- **File**: `iot_code/cam.cpp`
- **Stream endpoint**: `http://<ip>/` (MJPEG stream served by an embedded HTTP server)
- **Trigger source**: polls Firebase `carEmissions/liveData/emissionScore`
- **On threshold**: when the score exceeds the threshold (400) and the cooldown allows, it captures a JPEG and uploads:
  - metadata JSON under `carEmissions/alerts/<alertId>`
  - JPEG bytes as an RTDB blob under `carEmissions/alerts/<alertId>/image`

**Procedure to enable**

- Build/flash `iot_code/cam.cpp` for an ESP32-CAM board (AI Thinker pinmap is included)
- Ensure the Python data generator is already publishing `emissionScore` into Firebase (`carEmissions/liveData/emissionScore`)

---

## 5. Mobile app subsystem (Flutter)

### 5.1 Core dependencies

From `pubspec.yaml` (selected):

- `firebase_core`, `firebase_database`, `firebase_storage`
- `provider`
- `tflite_flutter`
- `flutter_local_notifications`
- `fl_chart`, `syncfusion_flutter_gauges`

### 5.2 Application architecture

- **Entry point**: `lib/main.dart`
- **State management**: `provider` (ChangeNotifier + MultiProvider)
- **Navigation**: bottom navigation + `IndexedStack` (Dashboard, Camera, Alerts, Graphs, Insights, Settings)

### 5.3 Telemetry ingestion

`DriverScoreProvider`:

- Connects to Firebase RTDB:
  - live: `carEmissions/liveData` (populated by the Python data generator)
  - alerts: `carEmissions/alerts`
  - history: `carEmissions/history`
- Applies Firebase live updates to in-app state.
- Maintains a rolling history list (also used by on-device ML inference).

### 5.4 Camera URL ingestion

`CameraStreamProvider`:

- Listens to RTDB path `carEmissions/camera`
- Extracts a URL from `streamUrl` (also accepts `url` or `stream`) and exposes it to the UI
- Falls back to a built-in local IP when Firebase has no stream URL (see `lib/providers/camera_stream_provider.dart`)

**Implementation note:** The current ESP32-CAM firmware (`iot_code/cam.cpp`) serves the stream over HTTP but does **not** publish its IP/URL into `carEmissions/camera`. If you want fully automatic camera discovery in the app, add a small write from the camera firmware to that node (or update the app to discover it another way).

### 5.5 Alerts and reminders

- Threshold-based alerts are generated in firmware (score ≥ 400) and logged under `carEmissions/alerts`.
- The app schedules reminders using `flutter_local_notifications` and stores scheduling state via a settings service.

---

## 6. ML subsystem (`ML/`) and deployment to Flutter

### 6.1 Pipeline purpose

The ML subsystem provides two session-based classifiers:

- Driver behavior: Eco / Normal / Aggressive / Idle-heavy
- Vehicle health: Healthy / Needs Service / Critical

### 6.2 Pipeline workflow (scripts)

Typical end-to-end run (see `ML/README.md`):

- `scripts.01_fetch_firebase` — fetch history from Firebase
- `scripts.02_prepare_dataset` — flatten + sessionize + compute stats
- `scripts.03_generate_synthetic` — generate realistic synthetic sessions
- `scripts.04_train_driver` — train driver behavior models
- `scripts.05_train_vehicle` — train vehicle health models
- `scripts.06_export_tflite` — export quantized TFLite models
- `scripts.07_export_preprocess_json` — export StandardScaler parameters to JSON for Flutter

### 6.3 Model artifacts used by Flutter

These artifacts are bundled as Flutter assets:

- `ML/models/driver_model.tflite`
- `ML/models/vehicle_model.tflite`
- `ML/models/driver_classes.txt`
- `ML/models/vehicle_classes.txt`
- `ML/models/driver_preprocess.json`
- `ML/models/vehicle_preprocess.json`

### 6.4 On-device inference (Flutter)

The on-device inference service:

- Computes session features from recent buffered telemetry (rolling window)
- Applies standardization using `*_preprocess.json`
- Quantizes to int8 based on the interpreter tensor parameters
- Runs inference using `tflite_flutter`
- Dequantizes outputs and applies softmax to compute confidence/probabilities

---

## 7. Setup and run procedures

### 7.1 Firebase setup (project-level)

The Flutter app expects Firebase to be configured. Standard procedure:

1. Install FlutterFire CLI.
2. Run `flutterfire configure` for this Flutter project.
3. Ensure `Firebase.initializeApp()` succeeds at runtime.

If Firebase is not configured, the app falls back to mock/demo behavior for some views.

### 7.2 Flutter app (local development)

From repository root:

- `flutter pub get`
- `flutter run`

Android build:

- `flutter build apk --debug`

### 7.3 Data generator execution

From the repository root (with `ML/.env` configured and the `ML` venv activated):

```bash
python data_generator/generate_telemetry.py --scenario normal
```

Useful variants: `--scenario mixed`, `--scenario critical`, `--dry-run`, `--count N`.

Optional camera firmware (`iot_code/cam.cpp`) still requires Arduino IDE / PlatformIO if used; it is not part of the default cloud data path.

### 7.4 ML pipeline execution

From `ML/`:

1. Create and activate a Python venv.
2. Install `requirements.txt`.
3. Configure `.env` (service account JSON, RTDB URL, history path).
4. Run scripts 01→06 to train and export models; run 07 to export scaler JSON.

---

## 8. Recommended figures (IEEE-style placeholders)

**Fig. 1. System Architecture.** Python data generator, Firebase RTDB schema, and Flutter app modules (dashboard, graphs, alerts, camera, ML insights).

*(Placeholder: Insert an end-to-end architecture diagram with data flows and protocols.)*

**Fig. 2. RTDB Data Model.** Key-value structure under `carEmissions/` showing `liveData`, `history`, `alerts`, and `camera` nodes.

*(Placeholder: Insert a tree diagram of RTDB paths and example JSON payload.)*

**Fig. 3. ML Training Pipeline.** Offline pipeline: fetch → flatten → sessionize → stats → synthetic generation → pseudo-labeling → train → export (TFLite + preprocess JSON).

*(Placeholder: Insert a flowchart aligned with `ML/scripts/01–07`.)*

**Fig. 4. On-device Inference Flow.** Rolling buffer → feature extractor → standardize → quantize → TFLite inference → dequantize/softmax → UI cards.

*(Placeholder: Insert a block diagram; show artifacts: `.tflite`, `*_preprocess.json`, `*_classes.txt`.)*

**Fig. 5. Mobile UI Screens.** Dashboard, Graphs, Alerts, Camera feed, ML Insights, Settings.

*(Placeholder: Insert annotated screenshots.)*

---

## 9. Implementation notes (engineering details)

### 9.1 Reliability and offline behavior

- The Flutter app ingests live telemetry only from Firebase (written by the Python data generator).
- When the generator is stopped, previously stored Firebase history can still support ML analysis.
- Camera connectivity is exposed as a URL contract; the app does not depend on a specific camera transport beyond HTTP stream URL availability.

### 9.2 Security considerations (recommended)

For production deployments:

- Avoid hardcoding credentials in firmware source.
- Use Firebase Security Rules to restrict read/write paths.
- Prefer per-device auth tokens and scoped permissions.

---

## 10. References (IEEE-style)

[1] TensorFlow Lite, “TensorFlow Lite Documentation (Model Conversion and Quantization).”  
[2] Flutter, “Flutter Documentation (Assets, Packaging, and Platform Integration).”  
[3] scikit-learn, “StandardScaler, Pipeline, and ColumnTransformer Documentation.”  
[4] L. Breiman, “Random Forests,” *Machine Learning*, vol. 45, no. 1, pp. 5–32, 2001.  
[5] T. Chen and C. Guestrin, “XGBoost: A Scalable Tree Boosting System,” in *Proc. 22nd ACM SIGKDD*, 2016.  
[6] I. Goodfellow, Y. Bengio, and A. Courville, *Deep Learning*. MIT Press, 2016.  
[7] C. M. Bishop, *Pattern Recognition and Machine Learning*. Springer, 2006.

