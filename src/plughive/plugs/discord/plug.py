"""The first plug: Claude CLI × Discord bot ROCHANA.

- Chat: reply to @mentions by running the message (plus a little rolling
  history) through the Claude CLI brain, in เก้า's voice.
- Brief: register the every-2-hours mail/calendar/news brief on the scheduler.
- Slash: /status, /cost, /pause, /brief.
"""
from __future__ import annotations

import asyncio
from collections import defaultdict, deque
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

import discord
from apscheduler.triggers.cron import CronTrigger
from loguru import logger

from plughive.core.plugin import Plug, PlugContext
from plughive.plugs.discord.brief_job import BriefJob

_HISTORY_LEN = 10
BRIEF_JOB_ID = "discord_brief"


class DiscordPlug(Plug):
    async def setup(self, ctx: PlugContext) -> None:
        self._ctx = ctx
        self._tz = ZoneInfo(ctx.settings.timezone)
        self._brief = BriefJob(ctx)
        self._history: dict[int, deque[str]] = defaultdict(
            lambda: deque(maxlen=_HISTORY_LEN)
        )
        self._locks: dict[int, asyncio.Lock] = defaultdict(asyncio.Lock)
        self._session_cost = 0.0

        client = ctx.bot.bots[ctx.settings.bot_name]
        self._client = client
        self._register_chat(client)
        self._register_commands(client)
        self._register_brief(ctx)
        self._register_ready_check(ctx)
        logger.info("[discord] setup complete")

    def _register_ready_check(self, ctx: PlugContext) -> None:
        """On connect, verify the Boss ID resolves to a postable text channel.
        If it's actually a server/guild id, list that guild's text channels so
        the user can pick the right one."""
        cid = ctx.settings.boss_channel_id

        @ctx.bot.on_ready(ctx.settings.bot_name)
        async def _check(client: discord.Client) -> None:
            ch = client.get_channel(cid)
            if isinstance(ch, discord.TextChannel):
                logger.info(f"[discord] ✅ Boss channel = #{ch.name} (guild: {ch.guild.name})")
                return
            guild = client.get_guild(cid)
            if guild is not None:
                chans = [f"{c.id}  #{c.name}" for c in guild.text_channels]
                listing = "\n  ".join(chans) or "(bot can see no text channels)"
                logger.warning(
                    f"[discord] ⚠️ {cid} is a SERVER id, not a channel. "
                    f"Set DISCORD_CHANNEL_ID to one of these channels in '{guild.name}':\n  {listing}"
                )
                return
            logger.warning(
                f"[discord] ⚠️ id {cid} resolves to neither a channel nor a "
                "guild the bot is in. Check the bot is invited and the id is correct."
            )

    # ── chat ───────────────────────────────────────────────────────────────
    def _register_chat(self, client: discord.Client) -> None:
        ctx = self._ctx

        @client.event
        async def on_message(message: discord.Message) -> None:
            if message.author.bot or message.author == client.user:
                return
            # Only engage when ROCHANA is mentioned.
            if client.user is None or client.user not in message.mentions:
                self._history[message.channel.id].append(f"{message.author.display_name}: {message.clean_content}")
                return

            text = message.clean_content.replace(f"@{client.user.display_name}", "").strip()
            self._history[message.channel.id].append(f"{message.author.display_name}: {text}")

            async with self._locks[message.channel.id]:
                async with message.channel.typing():
                    reply = await self._think(message.channel.id, text)
            await ctx.bot.send_message(ctx.settings.bot_name, message.channel.id, reply)
            self._history[message.channel.id].append(f"เก้า: {reply[:300]}")

    async def _think(self, channel_id: int, text: str) -> str:
        ctx = self._ctx
        s = ctx.settings
        history = "\n".join(self._history[channel_id])
        prompt = (
            f"บริบทแชทล่าสุด:\n{history}\n\n"
            f"ข้อความล่าสุดจาก {s.boss_nickname} (ตอบข้อความนี้):\n{text}"
        )
        result = await ctx.brain.run(
            prompt,
            model=s.brain.chat_model,
            system_prompt=ctx.persona.system_prompt(),
            max_turns=s.brain.chat_max_turns,
            timeout_s=s.brain.chat_timeout_s,
        )
        if not result.ok:
            logger.error(f"[discord] brain failed: {result.error}")
            return "ขอโทษค่ะ ตอนนี้เก้าเชื่อมต่อสมอง (claude) ไม่ได้ ลองใหม่อีกครั้งนะคะ"
        if result.cost_usd:
            self._session_cost += result.cost_usd
        return result.text or "ค่ะ"

    # ── slash commands ───────────────────────────────────────────────────────
    def _register_commands(self, client: discord.Client) -> None:
        tree: discord.app_commands.CommandTree = client.tree
        ctx = self._ctx

        @tree.command(name="status", description="สถานะของ ROCHANA")
        async def status(interaction: discord.Interaction) -> None:
            job = ctx.scheduler.get_job(BRIEF_JOB_ID)
            nxt = job.next_run_time.strftime("%H:%M %d/%m") if job and job.next_run_time else "—"
            await interaction.response.send_message(
                f"🟢 ROCHANA ออนไลน์ค่ะ\n• brief รอบถัดไป: {nxt}\n"
                f"• plug: discord", ephemeral=True
            )

        @tree.command(name="cost", description="ค่าใช้จ่าย claude ในเซสชันนี้")
        async def cost(interaction: discord.Interaction) -> None:
            await interaction.response.send_message(
                f"💰 ใช้ไปประมาณ ${self._session_cost:.4f} ในเซสชันนี้ค่ะ", ephemeral=True
            )

        @tree.command(name="pause", description="พักการแจ้งเตือน (นาที)")
        @discord.app_commands.describe(minutes="กี่นาที (default 480 = 8 ชม.)")
        async def pause(interaction: discord.Interaction, minutes: int = 480) -> None:
            until = datetime.now(self._tz) + timedelta(minutes=max(1, minutes))
            ctx.state.set_snooze(until.isoformat())
            await interaction.response.send_message(
                f"🔕 พักการแจ้งเตือนถึง {until:%H:%M %d/%m} ค่ะ", ephemeral=True
            )

        @tree.command(name="brief", description="สั่งสรุป brief เดี๋ยวนี้")
        async def brief(interaction: discord.Interaction) -> None:
            await interaction.response.send_message("📝 กำลังสรุปให้นะคะ…", ephemeral=True)
            await self._brief.run()

    # ── brief job ────────────────────────────────────────────────────────────
    def _register_brief(self, ctx: PlugContext) -> None:
        b = ctx.settings.brief
        ctx.scheduler.add_job(
            self._brief.run,
            CronTrigger(hour=b.cron_hours, minute=b.cron_minute, timezone=self._tz),
            id=BRIEF_JOB_ID,
            misfire_grace_time=300,
            max_instances=1,
        )
        logger.info(f"[discord] brief scheduled: hour={b.cron_hours} min={b.cron_minute}")

    async def stop(self) -> None:
        logger.info("[discord] stopped")
