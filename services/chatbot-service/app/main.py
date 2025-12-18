from fastapi import FastAPI, WebSocket
import aio_pika
import asyncio

app = FastAPI(title="Chatbot Service")
clients = set()

@app.websocket("/ws/events")
async def ws_events(ws: WebSocket):
    await ws.accept()
    clients.add(ws)
    try:
        while True:
            # keepalive / ignore client messages for now
            await ws.receive_text()
    except Exception:
        pass
    finally:
        clients.discard(ws)

async def rabbit_consumer_loop():
    while True:
        try:
            conn = await aio_pika.connect_robust("amqp://guest:guest@rabbitmq/")
            ch = await conn.channel()
            ex = await ch.declare_exchange("events", aio_pika.ExchangeType.FANOUT, durable=True)
            q = await ch.declare_queue("", exclusive=True)
            await q.bind(ex)

            async with q.iterator() as it:
                async for msg in it:
                    async with msg.process():
                        text = msg.body.decode("utf-8", errors="replace")
                        dead = []
                        for c in list(clients):
                            try:
                                await c.send_text(text)
                            except Exception:
                                dead.append(c)
                        for d in dead:
                            clients.discard(d)

        except Exception as e:
            print(f"[chatbot] RabbitMQ not ready/disconnected: {e}")
            await asyncio.sleep(2)

@app.on_event("startup")
async def startup():
    asyncio.create_task(rabbit_consumer_loop())

@app.get("/health")
def health():
    return {"ok": True}

