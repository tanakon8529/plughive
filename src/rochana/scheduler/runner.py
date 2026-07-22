"""In-process APScheduler factory.

One scheduler shared by all plugs, timezone-aware (Asia/Bangkok by default).
The bot process is always-on anyway, so there's nothing to install (no cron,
no launchd) — plugs register their jobs in setup().
"""
from __future__ import annotations

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from loguru import logger


def create_scheduler(timezone: str) -> AsyncIOScheduler:
    scheduler = AsyncIOScheduler(timezone=timezone)
    logger.info(f"[scheduler] created (tz={timezone})")
    return scheduler
