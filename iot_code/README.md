# iot_code (removed)

Physical sensor firmware and the ESP32-CAM module have been removed.

Live telemetry is simulated by:

```text
data_generator/generate_telemetry.py  →  Firebase RTDB  →  Flutter app
```

See `data_generator/README.md`.
