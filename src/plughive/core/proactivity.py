"""Proactive-messaging gate (pure logic, salvaged verbatim from the old system).

The gate enforces, in order: critical override → snooze → quiet hours →
daily cap. Kept as pure functions so they're trivial to unit-test. The daily
counter is now backed by SQLite (see core.state) so it survives restarts.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

_URGENT_WORDS = ["critical", "urgent", "ฉุกเฉิน", "ด่วน"]


def is_critical(message: str, priority: str) -> bool:
    """A message is critical if explicitly prioritized or it screams urgency."""
    if priority == "critical":
        return True
    low = (message or "").lower()
    return any(w in low for w in _URGENT_WORDS)


def in_quiet_hours(now: datetime, quiet_start: int, quiet_end: int) -> bool:
    """Quiet window wraps midnight (e.g. 21:00–08:00)."""
    h = now.hour
    if quiet_start <= quiet_end:
        return quiet_start <= h < quiet_end
    return h >= quiet_start or h < quiet_end


def is_snoozed(now: datetime, snooze_until_iso: str | None) -> bool:
    """True while now < snooze_until. Bad/empty values → not snoozed (never raises)."""
    if not snooze_until_iso:
        return False
    try:
        until = datetime.fromisoformat(snooze_until_iso)
    except (ValueError, TypeError):
        return False
    if until.tzinfo is None and now.tzinfo is not None:
        until = until.replace(tzinfo=now.tzinfo)
    elif until.tzinfo is not None and now.tzinfo is None:
        now = now.replace(tzinfo=until.tzinfo)
    return now < until


@dataclass(frozen=True)
class GateDecision:
    allowed: bool
    reason: str  # "critical" | "ok" | "snoozed" | "quiet_hours" | "daily_cap"


def proactive_gate(
    *,
    message: str,
    priority: str,
    now: datetime,
    quiet_start: int,
    quiet_end: int,
    snooze_until_iso: str | None,
    daily_count: int,
    daily_cap: int,
) -> GateDecision:
    """Decide whether a proactive message to the Boss may be sent right now."""
    if is_critical(message, priority):
        return GateDecision(True, "critical")
    if is_snoozed(now, snooze_until_iso):
        return GateDecision(False, "snoozed")
    if in_quiet_hours(now, quiet_start, quiet_end):
        return GateDecision(False, "quiet_hours")
    if daily_cap > 0 and daily_count >= daily_cap:
        return GateDecision(False, "daily_cap")
    return GateDecision(True, "ok")
