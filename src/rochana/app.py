"""Boot sequence: config → brain/bot/scheduler/state → discover plugs → run.

This is the whole runtime. One process: a Discord connection, an APScheduler,
a SQLite file, and however many plugs are enabled.
"""
from __future__ import annotations

import asyncio
import signal
import sys

from loguru import logger

from rochana.brain.claude_cli import ClaudeBrain, ClaudeNotFound
from rochana.brain.persona import PersonaLoader
from rochana.config import Settings, load_settings
from rochana.core.bot import BotManager
from rochana.core.plugin import PlugContext
from rochana.core.registry import PlugRegistry
from rochana.core.state import StateStore
from rochana.scheduler.runner import create_scheduler


def _build_context(settings: Settings) -> tuple[PlugContext, StateStore, BotManager]:
    brain = ClaudeBrain(
        allowed_tools=settings.brain.allowed_tools,
        mcp_config=settings.brain.mcp_config,
        repo_root=settings.root,
        scratch_cwd=settings.brain_scratch_cwd,
    )
    persona = PersonaLoader(
        settings.persona_path,
        tz=settings.timezone,
        variables={
            "boss_nickname": settings.boss_nickname,
            "boss_name": settings.boss_nickname,
            "quiet_start": settings.proactivity.quiet_start,
            "quiet_end": settings.proactivity.quiet_end,
            "max_daily_boss_messages": settings.proactivity.max_daily_boss_messages,
        },
    )
    bot = BotManager()
    # Pre-create the primary client so plugs can attach handlers in setup(),
    # before start_all() connects it.
    bot.create_bot("rochana")
    scheduler = create_scheduler(settings.timezone)
    state = StateStore(settings.state_db_path)
    ctx = PlugContext(
        settings=settings,
        brain=brain,
        bot=bot,
        scheduler=scheduler,
        state=state,
        persona=persona,
    )
    return ctx, state, bot


async def run() -> None:
    settings = load_settings()

    if not settings.discord_token:
        logger.error(
            "DISCORD_ROCHANA_TOKEN is not set. Copy .env.example to .env and fill it in."
        )
        sys.exit(1)

    try:
        ctx, state, bot = _build_context(settings)
    except ClaudeNotFound as e:
        logger.error(str(e))
        sys.exit(1)

    registry = PlugRegistry(
        settings.root / "src" / "rochana" / "plugs",
        enabled=settings.enabled_plugs,
        mcp_config_path=settings.root / settings.brain.mcp_config,
    )
    loaded = registry.load_all(ctx)
    if not loaded:
        logger.error("No plugs loaded — nothing to do. Check config/rochana.yaml.")
        sys.exit(1)

    await registry.setup_all()
    ctx.scheduler.start()
    await registry.start_all()

    stop_event = asyncio.Event()

    def _request_stop(*_: object) -> None:
        logger.info("[app] shutdown signal received")
        stop_event.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, _request_stop)
        except NotImplementedError:  # pragma: no cover - non-unix
            pass

    logger.info("[app] ROCHANA is up. Starting Discord…")
    bot_task = asyncio.create_task(
        bot.start_all({"rochana": settings.discord_token})
    )

    await stop_event.wait()

    logger.info("[app] shutting down…")
    await registry.stop_all()
    ctx.scheduler.shutdown(wait=False)
    await bot.close_all()
    bot_task.cancel()
    state.close()
    logger.info("[app] bye")


def run_blocking() -> None:
    try:
        asyncio.run(run())
    except KeyboardInterrupt:
        pass
