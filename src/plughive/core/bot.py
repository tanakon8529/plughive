"""Discord client manager (salvaged from the old BotManager, trimmed).

Keeps the multi-bot dict so adding a second bot identity later is free, and the
1900-char chunking that keeps messages under Discord's 2000-char limit.
"""
from __future__ import annotations

import asyncio

import discord
from loguru import logger


class BotManager:
    """Manages one or more Discord bot clients."""

    def __init__(self) -> None:
        self.bots: dict[str, discord.Client] = {}
        self._ready_events: dict[str, asyncio.Event] = {}
        self._ready_callbacks: dict[str, list] = {}

    def on_ready(self, name: str):
        """Decorator to register an async callback run once a bot is ready.

        discord.py allows only one @client.event on_ready, so plugs hook in here
        instead of overwriting it.
        """
        def deco(coro):
            self._ready_callbacks.setdefault(name, []).append(coro)
            return coro
        return deco

    def create_bot(self, name: str) -> discord.Client:
        """Create a Discord client with message-content intent + a slash tree."""
        intents = discord.Intents.default()
        intents.message_content = True
        client = discord.Client(intents=intents)
        client.tree = discord.app_commands.CommandTree(client)
        self.bots[name] = client
        self._ready_events[name] = asyncio.Event()

        @client.event
        async def on_ready() -> None:
            logger.info(f"Discord bot '{name}' online as {client.user}")
            try:
                synced = await client.tree.sync()
                if synced:
                    logger.info(f"Bot '{name}' synced {len(synced)} slash commands")
            except Exception as e:  # noqa: BLE001 - non-fatal
                logger.warning(f"Slash sync failed for '{name}': {e}")
            self._ready_events[name].set()
            for cb in self._ready_callbacks.get(name, []):
                try:
                    await cb(client)
                except Exception as e:  # noqa: BLE001
                    logger.warning(f"on_ready callback for '{name}' failed: {e}")

        return client

    async def wait_ready(self, name: str, timeout: float = 30.0) -> None:
        event = self._ready_events.get(name)
        if event:
            await asyncio.wait_for(event.wait(), timeout=timeout)

    async def send_message(self, bot_name: str, channel_id: int, content: str) -> None:
        """Send a message, chunked to stay under Discord's 2000-char limit."""
        bot = self.bots.get(bot_name)
        if not bot:
            raise ValueError(f"Bot '{bot_name}' not registered")
        channel = bot.get_channel(channel_id)
        if not channel:
            raise ValueError(f"Channel {channel_id} not found for bot '{bot_name}'")
        for chunk in [content[i : i + 1900] for i in range(0, len(content), 1900)]:
            await channel.send(chunk)

    async def start_all(self, tokens: dict[str, str]) -> None:
        """Start all bots concurrently. Blocks until all disconnect.

        A bot already created (so a plug could attach handlers in setup()) is
        reused; otherwise it's created on the fly.
        """
        tasks = []
        for name, token in tokens.items():
            if not token:
                logger.warning(f"Skipping bot '{name}': no token provided")
                continue
            if name not in self.bots:
                self.create_bot(name)
            tasks.append(self.bots[name].start(token))
        if tasks:
            await asyncio.gather(*tasks)
        else:
            logger.warning("No Discord bots started — no valid tokens")
            await asyncio.Event().wait()

    async def close_all(self) -> None:
        for name, bot in self.bots.items():
            try:
                await bot.close()
            except Exception as e:  # noqa: BLE001
                logger.warning(f"Error closing bot '{name}': {e}")
