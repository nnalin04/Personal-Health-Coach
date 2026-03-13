"""
RabbitMQ consumer — listens to health_os.tasks queues and dispatches
to the Smart Router for processing.

Runs as a background thread started at FastAPI startup.
Uses aio-pika for async consumption compatible with the FastAPI event loop.
"""
import asyncio
import json
import logging
import os

logger = logging.getLogger(__name__)

RABBITMQ_URL  = os.getenv("RABBITMQ_URL", "amqp://health_rabbit:health_rabbit_pass@localhost:5672/")
FOOD_QUEUE    = "food-vision-queue"
MEDICAL_QUEUE = "medical-ocr-queue"
RAG_QUEUE     = "rag-insight-queue"


async def _process_message(message, queue_type: str):
    """Parse a RabbitMQ message and dispatch to the Smart Router."""
    from app.routers.smart_router import route_task
    async with message.process():
        try:
            payload = json.loads(message.body)
            task_id     = payload.get("taskId", "unknown")
            user_id     = payload.get("userId", "unknown")
            user_context = payload.get("userContext", {})

            logger.info("Processing %s task %s for user %s", queue_type, task_id, user_id)

            result = route_task(
                task_type=queue_type,
                task_id=task_id,
                user_id=user_id,
                payload=payload,
                user_context=user_context,
            )

            # TODO: store result in omni_chat_tasks via DB, then push WebSocket notification
            logger.info("Task %s completed: %s", task_id, result.get("status"))

        except Exception as e:
            logger.error("Failed to process %s task: %s", queue_type, e, exc_info=True)


async def start_consumers():
    """Start all queue consumers. Called from FastAPI lifespan."""
    try:
        import aio_pika
    except ImportError:
        logger.warning("aio-pika not installed — RabbitMQ consumer disabled. Run: pip install aio-pika")
        return

    try:
        connection = await aio_pika.connect_robust(RABBITMQ_URL, timeout=10)
        channel = await connection.channel()
        await channel.set_qos(prefetch_count=5)

        food_q    = await channel.declare_queue(FOOD_QUEUE,    durable=True)
        medical_q = await channel.declare_queue(MEDICAL_QUEUE, durable=True)
        rag_q     = await channel.declare_queue(RAG_QUEUE,     durable=True)

        await food_q.consume(lambda m: _process_message(m, "FOOD"))
        await medical_q.consume(lambda m: _process_message(m, "REPORT"))
        await rag_q.consume(lambda m: _process_message(m, "TEXT"))

        logger.info("RabbitMQ consumers started on %s queues", 3)
        # Keep the connection alive (do not close)
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
