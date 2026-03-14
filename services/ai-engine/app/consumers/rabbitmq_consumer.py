"""
RabbitMQ consumer — listens to health_os.tasks queues and dispatches
to the Smart Router for processing.

Runs as a background task started at FastAPI startup.
Uses aio-pika for async consumption compatible with the FastAPI event loop.

On task completion:
  1. Persists result to omni_chat_tasks via psycopg2 (polling fallback)
  2. Publishes {taskId, userId, status, result} to task-completed-queue
     → Spring Boot TaskCompletionListener → WebSocket push to mobile
"""
import asyncio
import json
import logging
import os
import uuid

logger = logging.getLogger(__name__)

RABBITMQ_URL      = os.getenv("RABBITMQ_URL", "amqp://health_rabbit:health_rabbit_pass@localhost:5672/")
FOOD_QUEUE        = "food-vision-queue"
MEDICAL_QUEUE     = "medical-ocr-queue"
RAG_QUEUE         = "rag-insight-queue"
COMPLETED_QUEUE   = "task-completed-queue"   # Spring Boot listens here → WS push
EXCHANGE          = "health_os.tasks"
COMPLETED_KEY     = "task.completed"

# ── DB helpers ────────────────────────────────────────────────────────────────

def _get_db_conn():
    """Return a psycopg2 connection or None if DB unavailable."""
    try:
        import psycopg2
        return psycopg2.connect(
            host     = os.getenv("POSTGRES_HOST", "db"),
            port     = int(os.getenv("POSTGRES_PORT", "5432")),
            dbname   = os.getenv("POSTGRES_DB",   "healthcoach"),
            user     = os.getenv("POSTGRES_USER",  "healthcoach"),
            password = os.getenv("POSTGRES_PASSWORD", ""),
        )
    except Exception as e:
        logger.warning("DB unavailable for task result write: %s", e)
        return None


def _update_task(task_id: str, status: str, result: dict | None, error: str | None = None):
    """Persist task result to omni_chat_tasks."""
    conn = _get_db_conn()
    if conn is None:
        return
    try:
        with conn:
            with conn.cursor() as cur:
                cur.execute(
                    """UPDATE omni_chat_tasks
                       SET status = %s,
                           result_json = %s,
                           error_message = %s,
                           completed_at = NOW()
                       WHERE id = %s::uuid""",
                    (
                        status,
                        json.dumps(result) if result else None,
                        error,
                        task_id,
                    )
                )
    except Exception as e:
        logger.error("Failed to update task %s in DB: %s", task_id, e)
    finally:
        conn.close()


# ── WS notification helper ────────────────────────────────────────────────────

async def _publish_completion(channel, task_id: str, user_id: str, status: str, result: dict | None):
    """
    Publish a task completion event to task-completed-queue.
    Spring Boot's TaskCompletionListener receives this and pushes to WebSocket.
    """
    try:
        import aio_pika
        body = json.dumps({
            "taskId":  task_id,
            "userId":  user_id,
            "status":  status,
            "result":  result,
        }).encode()
        exchange = await channel.get_exchange(EXCHANGE)
        await exchange.publish(
            aio_pika.Message(body=body, content_type="application/json"),
            routing_key=COMPLETED_KEY,
        )
        logger.debug("Published completion for task %s → /topic/tasks/%s", task_id, user_id)
    except Exception as e:
        logger.warning("Could not publish completion event for task %s: %s", task_id, e)


# ── Message processing ────────────────────────────────────────────────────────

async def _process_message(message, queue_type: str, channel):
    """Parse a RabbitMQ message, dispatch to Smart Router, notify via WS."""
    from app.routers.smart_router import route_task
    async with message.process():
        payload = {}
        task_id = "unknown"
        user_id = "0"
        try:
            payload      = json.loads(message.body)
            task_id      = payload.get("taskId", str(uuid.uuid4()))
            user_id      = str(payload.get("userId", "0"))
            user_context = payload.get("userContext", {})

            logger.info("Processing %s task %s for user %s", queue_type, task_id, user_id)

            result = route_task(
                task_type    = queue_type,
                task_id      = task_id,
                user_id      = user_id,
                payload      = payload,
                user_context = user_context,
            )

            final_status = result.get("status", "COMPLETED")
            _update_task(task_id, final_status, result)
            await _publish_completion(channel, task_id, user_id, final_status, result)
            logger.info("Task %s → %s", task_id, final_status)

        except Exception as e:
            logger.error("Failed to process %s task %s: %s", queue_type, task_id, e, exc_info=True)
            _update_task(task_id, "FAILED", None, error=str(e))
            await _publish_completion(channel, task_id, user_id, "FAILED", {"error": str(e)})


# ── Startup ───────────────────────────────────────────────────────────────────

async def start_consumers():
    """Start all queue consumers. Called from FastAPI lifespan."""
    try:
        import aio_pika
    except ImportError:
        logger.warning("aio-pika not installed — RabbitMQ consumer disabled. Run: pip install aio-pika")
        return

    try:
        connection = await aio_pika.connect_robust(RABBITMQ_URL, timeout=10)
        channel    = await connection.channel()
        await channel.set_qos(prefetch_count=5)

        food_q    = await channel.declare_queue(FOOD_QUEUE,    durable=True)
        medical_q = await channel.declare_queue(MEDICAL_QUEUE, durable=True)
        rag_q     = await channel.declare_queue(RAG_QUEUE,     durable=True)
        # Ensure completed queue exists (Spring Boot also declares it)
        await channel.declare_queue(COMPLETED_QUEUE, durable=True)

        await food_q.consume(lambda m: _process_message(m, "FOOD",   channel))
        await medical_q.consume(lambda m: _process_message(m, "REPORT", channel))
        await rag_q.consume(lambda m: _process_message(m, "TEXT",   channel))

        logger.info("RabbitMQ consumers started on 3 queues (WS notifications enabled)")
        asyncio.get_event_loop().create_task(_keepalive(connection))

    except Exception as e:
        logger.warning("RabbitMQ not available at startup: %s — consumers will not run", e)


async def _keepalive(connection):
    """Keep the consumer connection alive indefinitely."""
    while True:
        await asyncio.sleep(60)
        if connection.is_closed:
            logger.warning("RabbitMQ connection closed — consumers stopped")
            break
