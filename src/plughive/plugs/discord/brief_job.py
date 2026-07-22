"""The every-2-hours brief: mail + calendar + Thai/international news.

One brief = one `claude -p` call. We hand the brain the task and let *it* decide
what's worth reporting and in what format (the "self-deciding" behaviour). It
fetches mail/calendar via MCP tools and news via WebSearch itself. If nothing is
worth saying, it returns the sentinel __SKIP__ and we stay silent.

Before sending we apply: __SKIP__ check → MD5 dedup (SQLite) → proactive gate
(quiet hours / daily cap / snooze).
"""
from __future__ import annotations

import hashlib
from datetime import datetime
from zoneinfo import ZoneInfo

from loguru import logger

from plughive.core.plugin import PlugContext
from plughive.core.proactivity import proactive_gate

SKIP_TOKEN = "__SKIP__"

_SECTION_TEXT = {
    "mail": (
        "1) Email: ใช้ Gmail tools ดูอีเมลที่ยังไม่ได้อ่าน (is:unread) ใน 1 วันล่าสุด "
        "สรุปเฉพาะฉบับที่สำคัญ/ต้องรู้จริงๆ — ใคร, เรื่อง, ทำไมสำคัญ. โฆษณา/สแปม/newsletter "
        "ทั่วไปข้ามได้."
    ),
    "calendar": (
        "2) Calendar: ใช้ Calendar tools ดูนัดหมายวันนี้และ 24 ชม.ข้างหน้า — เวลา, เรื่อง, "
        "สถานที่/link. ถ้ามีนัดใกล้ (ภายใน ~2 ชม.) ให้เน้น."
    ),
    "news": (
        "3) ข่าว: ใช้ WebSearch ค้น 2 กลุ่ม (ก) ข่าวเด่นไทยวันนี้ (ข) ข่าวโลก/เทคโนโลยีที่สำคัญวันนี้ "
        "ใส่ปี ค.ศ. ปัจจุบันใน query. เลือกมา 3-5 ข่าวที่ 'น่าสนใจ/มีผลกระทบจริง' เท่านั้น "
        "(ไม่เอา filler) แต่ละข่าว: หัวข้อ + สรุปไทย 1 บรรทัด + วันที่ + URL. ทิ้งข่าวเก่ากว่า 2 วัน."
    ),
}


def _build_prompt(include: list[str]) -> str:
    sections = "\n".join(_SECTION_TEXT[s] for s in include if s in _SECTION_TEXT)
    return f"""\
ถึงเวลาสรุป brief รอบนี้ให้ {{boss}} แล้ว. ทำตามนี้ (ใช้ tools จริง อย่าเดา):

{sections}

จากนั้น **ตัดสินใจเอง** ว่ามีอะไรที่ควรรบกวน {{boss}} ในรอบนี้ไหม:
- ถ้ามีเรื่องน่ารายงาน → เขียนสรุปสั้น กระชับ เป็นภาษาไทยด้วยน้ำเสียงของเก้า
  ขึ้นหัวว่า "🔔 อัปเดตรอบ [เวลา]" แล้วแบ่งเป็นหัวข้อย่อยเท่าที่มีของจริง
  (ข้ามหัวข้อที่ไม่มีอะไร ไม่ต้องเขียนว่า "ไม่มี")
- ถ้ารอบนี้ไม่มีอะไรสำคัญเลย (ไม่มีเมลเด่น ไม่มีนัดใกล้ ไม่มีข่าวโดดเด่น) →
  ตอบกลับมาเป็นข้อความเดียวว่า {SKIP_TOKEN} เท่านั้น ห้ามมีอย่างอื่น

สำคัญ: เขียนให้ {{boss}} อ่านรวดเดียวจบ ไม่ต้องเกริ่น ไม่ต้องถามกลับ.
"""


class BriefJob:
    def __init__(self, ctx: PlugContext) -> None:
        self._ctx = ctx
        self._tz = ZoneInfo(ctx.settings.timezone)

    async def run(self) -> None:
        ctx = self._ctx
        s = ctx.settings
        now = datetime.now(self._tz)
        logger.info(f"[brief] run at {now:%Y-%m-%d %H:%M}")

        prompt = _build_prompt(s.brief.include).replace("{boss}", s.boss_nickname)

        result = await ctx.brain.run(
            prompt,
            model=s.brain.brief_model,
            system_prompt=ctx.persona.system_prompt(),
            max_turns=s.brain.brief_max_turns,
            timeout_s=s.brain.brief_timeout_s,
        )
        if not result.ok:
            logger.error(f"[brief] brain failed: {result.error}")
            return

        text = (result.text or "").strip()
        if not text or SKIP_TOKEN in text:
            logger.info("[brief] nothing worth reporting (__SKIP__)")
            return

        # Dedup: don't repeat an identical brief within the state's memory.
        brief_hash = hashlib.md5(_normalize(text).encode()).hexdigest()
        if ctx.state.brief_already_sent(brief_hash):
            logger.info("[brief] identical to a previous brief — suppressed")
            return

        # Proactive gate: quiet hours / daily cap / snooze.
        day = now.strftime("%Y-%m-%d")
        decision = proactive_gate(
            message=text,
            priority="normal",
            now=now,
            quiet_start=s.proactivity.quiet_start,
            quiet_end=s.proactivity.quiet_end,
            snooze_until_iso=ctx.state.get_snooze(),
            daily_count=ctx.state.daily_count(day),
            daily_cap=s.proactivity.max_daily_boss_messages,
        )
        if not decision.allowed:
            logger.info(f"[brief] gate blocked send: {decision.reason}")
            return

        await ctx.bot.send_message(s.bot_name, s.boss_channel_id, text)
        ctx.state.record_brief(brief_hash, now.isoformat())
        ctx.state.increment_daily(day)
        logger.info(f"[brief] sent ({len(text)} chars, cost={result.cost_usd})")


def _normalize(text: str) -> str:
    """Strip time-ish noise so two briefs that differ only by a timestamp in the
    header still dedup against each other."""
    import re

    t = re.sub(r"\d{1,2}[:.]\d{2}", "", text)      # times
    t = re.sub(r"\d{1,2}/\d{1,2}/\d{2,4}", "", t)   # dates
    return " ".join(t.split()).lower()
