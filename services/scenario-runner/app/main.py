from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
import aio_pika
import uuid
import os
import json
from datetime import datetime, timezone

app = FastAPI(title="DevOps Simulator - Scenario Runner")

# -----------------------------------------------------------------------------
# RabbitMQ config
# -----------------------------------------------------------------------------
RABBIT_URL = os.getenv("RABBIT_URL", "amqp://guest:guest@rabbitmq/")
CONTROL_EXCHANGE = "ioa.control"
ROUTING_KEY = "scenario.start"


def now_iso():
    return datetime.now(timezone.utc).isoformat()


async def publish_start_event(scenario: str, run_id: str) -> None:
    """
    Publish a control-plane message so the worker can execute the scenario.
    """
    payload = {
        "scenario": scenario,
        "run_id": run_id,
        "ts": now_iso(),
        "source": "scenario-runner",
        "type": "scenario.start",
    }

    try:
        connection = await aio_pika.connect_robust(RABBIT_URL)
        channel = await connection.channel()

        exchange = await channel.declare_exchange(
            CONTROL_EXCHANGE,
            aio_pika.ExchangeType.TOPIC,
            durable=True,
        )

        await exchange.publish(
            aio_pika.Message(
                body=json.dumps(payload).encode("utf-8"),
                content_type="application/json",
            ),
            routing_key=ROUTING_KEY,
        )

        await connection.close()

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to dispatch scenario to RabbitMQ: {e}",
        )


async def handle_start(scenario: str) -> JSONResponse:
    """
    One canonical handler for starting a scenario.
    IMPORTANT:
    - We DO NOT validate scenario names here.
    - The worker is the source of truth and will publish an error event if unknown.
    """
    scenario = (scenario or "").strip()
    if not scenario:
        raise HTTPException(status_code=400, detail="Scenario name is required")

    run_id = str(uuid.uuid4())
    await publish_start_event(scenario=scenario, run_id=run_id)

    return JSONResponse(
        {
            "status": "started",
            "scenario": scenario,
            "run_id": run_id,
            "ts": now_iso(),
        }
    )


# -----------------------------------------------------------------------------
# Routes
#
# WHY MULTIPLE ROUTES?
# Your gateway uses:
#   location ^~ /api/scenarios/ {
#     proxy_pass http://scenario-runner:8003/;
#   }
#
# With a trailing slash, Nginx strips the prefix and forwards:
#   POST /api/scenarios/db_latency/start  ->  POST /db_latency/start
#
# So we support BOTH:
#   /api/scenarios/{scenario}/start   (direct)
#   /{scenario}/start                (via gateway)
# -----------------------------------------------------------------------------

@app.post("/api/scenarios/{scenario}/start")
async def start_scenario_api(scenario: str):
    return await handle_start(scenario)


@app.post("/{scenario}/start")
async def start_scenario_gateway_passthrough(scenario: str):
    return await handle_start(scenario)


# Optional: a simple health endpoint (useful for debugging)
@app.get("/health")
async def health():
    return {"status": "ok", "service": "scenario-runner", "ts": now_iso()}
