import aio_pika
import asyncio
import os
import json
import time
from datetime import datetime, timezone

from prometheus_client import start_http_server, Gauge, Counter, Histogram

RABBIT_URL = os.getenv("RABBIT_URL", "amqp://guest:guest@rabbitmq/")

CONTROL_EXCHANGE = "ioa.control"
EVENTS_EXCHANGE = "events"

ROUTING_START = "scenario.start"

# ---- Prometheus metrics ----
INCIDENT_ACTIVE = Gauge("incident_active", "1 if scenario is running", ["scenario"])
INCIDENT_STEP = Gauge("incident_step", "Current step number", ["scenario"])
INCIDENT_RUNS = Counter("incident_runs_total", "Total scenario runs started", ["scenario"])
STEP_DURATION = Histogram("incident_step_duration_seconds", "Step duration seconds", ["scenario"])

# -----------------------------------------------------------------------------
# Scenario catalog (8 total)
# -----------------------------------------------------------------------------
SCENARIOS = {
    "db_latency": [
        ("info",    "🚀 Starting scenario: DB Latency", 0.8),
        ("info",    "🔎 Checking DB connectivity", 0.8),
        ("info",    "🧪 Injecting artificial latency (p95 target: 1200ms)", 1.0),
        ("warn",    "📈 Latency rising... p95 breached threshold", 1.0),
        ("warn",    "🚨 Alert fired: db_latency_p95_high", 0.8),
        ("info",    "📘 Runbook: switching app to safe mode + draining queue", 1.2),
        ("info",    "🛠 Mitigation: reducing pool size + retry backoff", 1.0),
        ("success", "✅ Latency normalized (p95 back under threshold)", 1.0),
        ("success", "🏁 Scenario completed: DB Latency", 0.6),
    ],
    "crash_loop": [
        ("info",    "🚀 Starting scenario: Crash Loop", 0.8),
        ("info",    "🔎 Detecting unstable container restarts", 1.0),
        ("warn",    "💥 Pod enters CrashLoopBackOff (simulated)", 1.0),
        ("warn",    "🚨 Alert fired: pod_crashloop_rate_high", 0.8),
        ("info",    "📘 Runbook: inspect last logs + config + env", 1.0),
        ("info",    "🛠 Mitigation: roll back to last stable version", 1.2),
        ("success", "✅ Restarts stopped (stable)", 1.0),
        ("success", "🏁 Scenario completed: Crash Loop", 0.6),
    ],

    # --- NEW ---
    "memory_leak": [
        ("info",    "🚀 Starting scenario: Memory Leak", 0.8),
        ("info",    "🔎 Monitoring RSS growth + GC pressure", 1.0),
        ("warn",    "📈 Memory steadily increasing (simulated)", 1.0),
        ("warn",    "🚨 Alert fired: memory_usage_high", 0.8),
        ("info",    "📘 Runbook: capture heap dump + top allocators", 1.1),
        ("info",    "🛠 Mitigation: restart pod + enable leak guardrails", 1.1),
        ("success", "✅ Memory stabilized after restart", 0.9),
        ("success", "🏁 Scenario completed: Memory Leak", 0.6),
    ],
    "cpu_spike": [
        ("info",    "🚀 Starting scenario: CPU Spike", 0.8),
        ("info",    "🔎 Inspecting CPU saturation + throttling", 1.0),
        ("warn",    "🔥 CPU usage spikes above 90% (simulated)", 1.0),
        ("warn",    "🚨 Alert fired: cpu_high", 0.8),
        ("info",    "📘 Runbook: check hot endpoints + profiling", 1.1),
        ("info",    "🛠 Mitigation: scale out + apply rate limit", 1.1),
        ("success", "✅ CPU returned to baseline", 0.9),
        ("success", "🏁 Scenario completed: CPU Spike", 0.6),
    ],
    "disk_full": [
        ("info",    "🚀 Starting scenario: Disk Full", 0.8),
        ("info",    "🔎 Checking node filesystem usage", 1.0),
        ("warn",    "💽 Disk usage reaches 95% (simulated)", 1.0),
        ("warn",    "🚨 Alert fired: disk_space_low", 0.8),
        ("info",    "📘 Runbook: find largest dirs + log growth", 1.1),
        ("info",    "🛠 Mitigation: rotate logs + increase volume", 1.1),
        ("success", "✅ Free space restored", 0.9),
        ("success", "🏁 Scenario completed: Disk Full", 0.6),
    ],
    "network_loss": [
        ("info",    "🚀 Starting scenario: Network Loss", 0.8),
        ("info",    "🔎 Checking service connectivity + DNS", 1.0),
        ("warn",    "📡 Intermittent packet loss (simulated)", 1.0),
        ("warn",    "🚨 Alert fired: upstream_unreachable", 0.8),
        ("info",    "📘 Runbook: trace route + check network policies", 1.1),
        ("info",    "🛠 Mitigation: rollback policy + restart sidecar", 1.1),
        ("success", "✅ Connectivity restored", 0.9),
        ("success", "🏁 Scenario completed: Network Loss", 0.6),
    ],
    "bad_deploy": [
        ("info",    "🚀 Starting scenario: Bad Deploy", 0.8),
        ("info",    "🔎 Detecting error-rate regression", 1.0),
        ("warn",    "📦 New version increases 5xx errors (simulated)", 1.0),
        ("warn",    "🚨 Alert fired: error_rate_high", 0.8),
        ("info",    "📘 Runbook: compare diff + check config/env changes", 1.1),
        ("info",    "🛠 Mitigation: rollback deployment + freeze promotions", 1.1),
        ("success", "✅ Error rate back to normal after rollback", 0.9),
        ("success", "🏁 Scenario completed: Bad Deploy", 0.6),
    ],
    "secrets_expired": [
        ("info",    "🚀 Starting scenario: Secrets Expired", 0.8),
        ("info",    "🔎 Checking token/cert validity windows", 1.0),
        ("warn",    "🔐 Secret expired causes auth failures (simulated)", 1.0),
        ("warn",    "🚨 Alert fired: auth_failures_high", 0.8),
        ("info",    "📘 Runbook: rotate secret + restart dependent pods", 1.1),
        ("info",    "🛠 Mitigation: renew cert + update secret store", 1.1),
        ("success", "✅ Authentication restored", 0.9),
        ("success", "🏁 Scenario completed: Secrets Expired", 0.6),
    ],
}


def now_iso():
    return datetime.now(timezone.utc).isoformat()


async def publish_event(ex, scenario: str, run_id: str, level: str, step: int, message: str):
    event = {
        "type": "log",
        "scenario": scenario,
        "run_id": run_id,
        "level": level,
        "step": step,
        "message": message,
        "ts": now_iso(),
    }
    await ex.publish(
        aio_pika.Message(
            body=json.dumps(event).encode("utf-8"),
            content_type="application/json",
        ),
        routing_key="",
    )


async def execute_scenario(events_exchange, scenario: str, run_id: str):
    steps = SCENARIOS.get(scenario)
    if not steps:
        # Unknown scenario should still show something in the UI (clear signal)
        await publish_event(events_exchange, scenario, run_id, "error", 0, f"❌ Unknown scenario '{scenario}' (worker has no definition)")
        return

    INCIDENT_RUNS.labels(scenario=scenario).inc()
    INCIDENT_ACTIVE.labels(scenario=scenario).set(1)
    INCIDENT_STEP.labels(scenario=scenario).set(0)

    try:
        for idx, (level, msg, delay) in enumerate(steps, start=1):
            start = time.time()
            INCIDENT_STEP.labels(scenario=scenario).set(idx)

            await publish_event(events_exchange, scenario, run_id, level, idx, msg)
            await asyncio.sleep(delay)

            STEP_DURATION.labels(scenario=scenario).observe(time.time() - start)
    finally:
        INCIDENT_ACTIVE.labels(scenario=scenario).set(0)
        INCIDENT_STEP.labels(scenario=scenario).set(0)


async def main():
    # Metrics server (Prometheus will scrape worker:9000/metrics)
    start_http_server(9000)
    print("[worker] Prometheus metrics available on :9000/metrics")

    while True:
        try:
            conn = await aio_pika.connect_robust(RABBIT_URL)
            ch = await conn.channel()

            control_ex = await ch.declare_exchange(CONTROL_EXCHANGE, aio_pika.ExchangeType.TOPIC, durable=True)
            events_ex = await ch.declare_exchange(EVENTS_EXCHANGE, aio_pika.ExchangeType.FANOUT, durable=True)

            q = await ch.declare_queue("ioa.worker.control", durable=True)
            await q.bind(control_ex, routing_key=ROUTING_START)

            print("[worker] Ready. Waiting for control events...")

            async with q.iterator() as it:
                async for msg in it:
                    async with msg.process():
                        raw = msg.body.decode("utf-8", errors="replace")

                        data = None
                        try:
                            data = json.loads(raw)
                        except Exception:
                            data = {"scenario": "unknown", "run_id": "unknown"}

                        scenario = data.get("scenario", "unknown")
                        run_id = data.get("run_id", "unknown")

                        asyncio.create_task(execute_scenario(events_ex, scenario, run_id))

        except Exception as e:
            print(f"[worker] RabbitMQ not ready/disconnected: {e}")
            await asyncio.sleep(2)


if __name__ == "__main__":
    asyncio.run(main())
