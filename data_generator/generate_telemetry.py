#!/usr/bin/env python3
"""
EcoDrive live telemetry simulator.

Pushes synthetic sensor readings into Firebase Realtime Database so the Flutter
app can show a real-time demo (live gauges, history, alerts).

Default transport: Firebase Auth email/password + RTDB REST
(same account the old ESP32 firmware used — no service-account JSON required).

Examples:
  python3 data_generator/generate_telemetry.py --scenario mixed
  python3 data_generator/generate_telemetry.py --scenario critical --interval 3
  python3 data_generator/generate_telemetry.py --dry-run --count 5
"""

from __future__ import annotations

import argparse
import json
import math
import random
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any


# Match former firmware calibration.
CLEAN_AIR = 200
MAX_SMOKE = 700
ALERT_THRESHOLD = 400

IST = timezone(timedelta(hours=5, minutes=30))

DEFAULT_DB_URL = "https://ecodrive-85155-default-rtdb.firebaseio.com"
DEFAULT_API_KEY = "AIzaSyBjlXZlC8fQiNmSLMzmQF-m5PjUxkxLWlc"
DEFAULT_EMAIL = "ecodrive@test.com"
DEFAULT_PASSWORD = "test1234"


@dataclass(frozen=True)
class ScenarioProfile:
    name: str
    raw_gas_center: float
    raw_gas_std: float
    spike_chance: float
    spike_magnitude: float
    temp_center: float
    humidity_center: float


SCENARIOS: dict[str, ScenarioProfile] = {
    "eco": ScenarioProfile("eco", 240.0, 12.0, 0.02, 40.0, 28.0, 55.0),
    "normal": ScenarioProfile("normal", 320.0, 18.0, 0.08, 80.0, 29.0, 58.0),
    "aggressive": ScenarioProfile("aggressive", 480.0, 35.0, 0.25, 140.0, 31.0, 52.0),
    "idle": ScenarioProfile("idle", 265.0, 4.0, 0.01, 20.0, 27.5, 60.0),
    "critical": ScenarioProfile("critical", 620.0, 40.0, 0.35, 100.0, 33.0, 48.0),
}


def emission_score_from_raw_gas(raw_gas: float) -> int:
    t = (raw_gas - CLEAN_AIR) / float(MAX_SMOKE - CLEAN_AIR)
    score = 50.0 + t * 450.0
    return int(max(50, min(500, round(score))))


def _now_ist() -> datetime:
    return datetime.now(tz=IST)


class TelemetryGenerator:
    def __init__(self, scenario: str, seed: int | None = None) -> None:
        self._rng = random.Random(seed)
        self._tick = 0
        self._scenario_name = scenario
        self._active = self._pick_profile(scenario)

    def _pick_profile(self, scenario: str) -> ScenarioProfile:
        if scenario == "mixed":
            return self._rng.choice(list(SCENARIOS.values()))
        if scenario not in SCENARIOS:
            raise ValueError(
                f"Unknown scenario {scenario!r}. "
                f"Choose from: {', '.join([*SCENARIOS, 'mixed'])}"
            )
        return SCENARIOS[scenario]

    def maybe_rotate_mixed(self) -> None:
        if self._scenario_name != "mixed":
            return
        if self._tick > 0 and self._tick % 12 == 0:
            self._active = self._rng.choice(list(SCENARIOS.values()))
            print(f"  ↪ style changed → {self._active.name}")

    def next_reading(self) -> dict[str, Any]:
        self.maybe_rotate_mixed()
        profile = self._active
        self._tick += 1

        # Force a hard peak of 500 around the midpoint (~25th record, then every 50).
        force_peak_500 = self._tick % 50 == 25

        if force_peak_500:
            raw = float(MAX_SMOKE)
            score = 500
            print(f"  ⚠ forced peak score=500 at record #{self._tick}")
        else:
            drift = 8.0 * math.sin(self._tick / 17.0)
            raw = self._rng.gauss(profile.raw_gas_center + drift, profile.raw_gas_std)
            if self._rng.random() < profile.spike_chance:
                raw += self._rng.uniform(0.4, 1.0) * profile.spike_magnitude

            raw = max(180.0, min(750.0, raw))
            score = emission_score_from_raw_gas(raw)

        temp = self._rng.gauss(profile.temp_center, 0.45)
        humidity = max(20.0, min(95.0, self._rng.gauss(profile.humidity_center, 1.2)))

        now = _now_ist()
        return {
            "rawGas": round(raw, 2),
            "temperature": round(temp, 2),
            "humidity": round(humidity, 2),
            "emissionScore": score,
            "timestamp": now.strftime("%Y-%m-%d %H:%M:%S"),
            "dateFolder": now.strftime("%Y-%m-%d"),
            "timeKey": now.strftime("%H-%M-%S"),
            "scenario": profile.name,
        }


class FirebaseRestClient:
    """Write to RTDB using email/password auth (bypasses needing Admin SDK)."""

    def __init__(self, db_url: str, api_key: str, email: str, password: str) -> None:
        self.db_url = db_url.rstrip("/")
        self.api_key = api_key
        self.email = email
        self.password = password
        self._id_token: str | None = None
        self._expires_at = 0.0

    def _http_json(self, method: str, url: str, body: dict[str, Any] | None = None) -> Any:
        data = None if body is None else json.dumps(body).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=data,
            method=method,
            headers={"Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                raw = resp.read().decode("utf-8")
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"HTTP {e.code} for {url}: {detail}") from e

    def ensure_token(self) -> str:
        if self._id_token and time.time() < self._expires_at - 60:
            return self._id_token

        url = (
            "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"
            f"?key={self.api_key}"
        )
        result = self._http_json(
            "POST",
            url,
            {
                "email": self.email,
                "password": self.password,
                "returnSecureToken": True,
            },
        )
        token = result.get("idToken")
        if not token:
            raise RuntimeError(f"Auth failed: {result}")
        expires_in = int(result.get("expiresIn", "3600"))
        self._id_token = token
        self._expires_at = time.time() + expires_in
        print(f"Signed in as {self.email}")
        return token

    def put(self, path: str, payload: dict[str, Any]) -> None:
        token = self.ensure_token()
        clean = path.strip("/")
        url = f"{self.db_url}/{clean}.json?auth={token}"
        self._http_json("PUT", url, payload)


def publish_reading(client: FirebaseRestClient, reading: dict[str, Any], write_alerts: bool) -> None:
    payload = {
        "rawGas": reading["rawGas"],
        "temperature": reading["temperature"],
        "humidity": reading["humidity"],
        "emissionScore": reading["emissionScore"],
        "timestamp": reading["timestamp"],
    }

    client.put("carEmissions/liveData", payload)
    history_path = f"carEmissions/history/{reading['dateFolder']}/{reading['timeKey']}"
    client.put(history_path, payload)

    if write_alerts and reading["emissionScore"] >= ALERT_THRESHOLD:
        alert_id = f"{reading['dateFolder']}_{reading['timeKey']}"
        client.put(
            f"carEmissions/alerts/{alert_id}",
            {
                "emissionScore": reading["emissionScore"],
                "message": "High emission event",
                "timestamp": reading["timestamp"],
            },
        )
        print(f"  ⚠ ALERT written ({reading['emissionScore']})")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Live EcoDrive Firebase telemetry simulator")
    p.add_argument(
        "--scenario",
        default="mixed",
        choices=[*SCENARIOS.keys(), "mixed"],
        help="Driving pattern (default: mixed — rotates and will trigger alerts).",
    )
    p.add_argument("--interval", type=float, default=3.0, help="Seconds between readings.")
    p.add_argument("--count", type=int, default=0, help="Stop after N readings (0 = forever).")
    p.add_argument("--seed", type=int, default=None)
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--no-alerts", action="store_true")
    p.add_argument("--db-url", default=DEFAULT_DB_URL)
    p.add_argument("--api-key", default=DEFAULT_API_KEY)
    p.add_argument("--email", default=DEFAULT_EMAIL)
    p.add_argument("--password", default=DEFAULT_PASSWORD)
    return p.parse_args()


def main() -> None:
    args = parse_args()
    gen = TelemetryGenerator(scenario=args.scenario, seed=args.seed)
    client: FirebaseRestClient | None = None

    if not args.dry_run:
        client = FirebaseRestClient(
            db_url=args.db_url,
            api_key=args.api_key,
            email=args.email,
            password=args.password,
        )
        client.ensure_token()
        print(
            f"Live simulation → Firebase every {args.interval}s "
            f"(scenario={args.scenario}). Ctrl+C to stop."
        )
        print("Watch the Flutter dashboard / Alerts tab update in real time.")
    else:
        print(f"Dry-run scenario={args.scenario}")

    published = 0
    try:
        while True:
            reading = gen.next_reading()
            line = (
                f"[{reading['scenario']}] score={reading['emissionScore']} "
                f"rawGas={reading['rawGas']} temp={reading['temperature']} "
                f"hum={reading['humidity']}"
            )
            if args.dry_run:
                print(line)
            else:
                assert client is not None
                publish_reading(client, reading, write_alerts=not args.no_alerts)
                print(f"Pushed {line}")

            published += 1
            if args.count > 0 and published >= args.count:
                break
            time.sleep(max(0.2, args.interval))
    except KeyboardInterrupt:
        print(f"\nStopped after {published} reading(s).")


if __name__ == "__main__":
    main()
