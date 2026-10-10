import asyncio
import logging
from typing import Callable, Dict, List, Any

logger = logging.getLogger("backend.events")

class AsyncEventBus:
    """
    Decoupled Asynchronous In-Memory Event Bus using asyncio.Queue.
    Acts as the EDA backbone for the FastAPI Cloud Backend, decoupling HTTP
    controllers from heavy operations (DB persistence, audit logging, push notifications).
    """
    def __init__(self):
        self._subscribers: Dict[str, List[Callable]] = {}
        self._queue: asyncio.Queue = asyncio.Queue()
        self._running = False
        self._worker_task: asyncio.Task = None

    def subscribe(self, event_type: str, handler: Callable):
        if event_type not in self._subscribers:
            self._subscribers[event_type] = []
        self._subscribers[event_type].append(handler)
        logger.info(f"[EventBus] Registered subscriber for: {event_type}")

    async def publish(self, event_type: str, payload: Any):
        """
        Non-blocking enqueue of domain event.
        Takes O(1) time so HTTP controllers return instantly.
        """
        await self._queue.put((event_type, payload))
        logger.info(f"[EventBus] Published domain event: {event_type}")

    async def start_processing(self):
        self._running = True
        logger.info("[EventBus] Background event processing loop started.")
        while self._running:
            try:
                event_type, payload = await self._queue.get()
                if event_type in self._subscribers:
                    for handler in self._subscribers[event_type]:
                        try:
                            if asyncio.iscoroutinefunction(handler):
                                asyncio.create_task(handler(payload))
                            else:
                                handler(payload)
                        except Exception as e:
                            logger.error(f"[EventBus] Error executing handler for {event_type}: {e}")
                self._queue.task_done()
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"[EventBus] Loop error: {e}")

    def stop_processing(self):
        self._running = False

event_bus = AsyncEventBus()
