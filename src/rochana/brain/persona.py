"""Load the persona markdown and inject runtime variables.

The persona is เก้า's voice. `{placeholders}` are filled at call time — most
importantly the current date/time, because the persona explicitly forbids the
model from guessing the date.
"""
from __future__ import annotations

from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

from loguru import logger

_THAI_DAYS = ["จันทร์", "อังคาร", "พุธ", "พฤหัสบดี", "ศุกร์", "เสาร์", "อาทิตย์"]


class PersonaLoader:
    def __init__(self, persona_path: Path, *, tz: str, variables: dict[str, object]) -> None:
        self._path = persona_path
        self._tz = ZoneInfo(tz)
        self._vars = dict(variables)
        self._template = persona_path.read_text(encoding="utf-8")
        logger.info(f"[persona] loaded {persona_path} ({len(self._template)} chars)")

    def now_line(self) -> str:
        now = datetime.now(self._tz)
        day = _THAI_DAYS[now.weekday()]
        return f"วัน{day}ที่ {now:%d/%m/%Y %H:%M} (Asia/Bangkok, ค.ศ. {now:%Y})"

    def system_prompt(self) -> str:
        """Persona text with variables + a current-time header injected."""
        body = self._template
        try:
            body = body.format(**self._vars)
        except (KeyError, IndexError, ValueError):
            # A stray brace in the persona shouldn't crash the bot — ship raw.
            logger.warning("[persona] template.format failed; using raw persona text")
        header = f"## เวลาปัจจุบัน\n{self.now_line()}\n\n"
        return header + body
