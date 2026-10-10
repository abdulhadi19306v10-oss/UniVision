from typing import Dict, Any
from ..events.event_bus import desktop_event_bus
from ..storage.sync_client import CloudSyncClient
from ..storage.local_db import LocalStorage

class SyncController:
    """
    MVC Controller managing cloud data synchronization between local SQLite queue
    and the central FastAPI cloud backend.
    """
    def __init__(self, storage: LocalStorage, sync_client: CloudSyncClient):
        self.storage = storage
        self.sync_client = sync_client

    def sync_to_cloud(self, backend_url: str, email: str, password: str) -> Dict[str, Any]:
        self.sync_client.base_url = backend_url.rstrip("/")
        
        desktop_event_bus.sync_status_changed.emit("Authenticating with Cloud API...", {"step": "AUTH"})
        if not self.sync_client.login_teacher(email, password):
            error_result = {"status": "FAILED", "error": "Teacher authentication failed"}
            desktop_event_bus.sync_status_changed.emit("❌ Authentication Failed: Invalid credentials or network error.", error_result)
            return error_result

        desktop_event_bus.sync_status_changed.emit("Uploading queued attendance records...", {"step": "UPLOAD"})
        stats = self.sync_client.sync_pending_records()

        summary_msg = f"✅ Sync Completed: {stats.get('synced', 0)} uploaded | {stats.get('failed', 0)} failed | {stats.get('pending', 0)} pending."
        desktop_event_bus.sync_status_changed.emit(summary_msg, stats)
        return stats
