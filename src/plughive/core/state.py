"""SQLite-backed local state — replaces the old Postgres/Qdrant stack.

Holds only what the assistant genuinely needs between runs: brief dedup, seen
mail ids, the persistent daily-send counter, and snooze windows. One file,
stdlib sqlite3, WAL mode so overlapping jobs don't block each other.
"""
from __future__ import annotations

import sqlite3
from pathlib import Path

from loguru import logger

_SCHEMA = """
CREATE TABLE IF NOT EXISTS sent_briefs (
    hash    TEXT PRIMARY KEY,
    sent_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS seen_mail (
    msg_id  TEXT PRIMARY KEY,
    seen_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS daily_sends (
    day   TEXT PRIMARY KEY,
    count INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS snooze (
    k         TEXT PRIMARY KEY,
    until_iso TEXT NOT NULL
);
"""


class StateStore:
    def __init__(self, db_path: Path) -> None:
        db_path.parent.mkdir(parents=True, exist_ok=True)
        self._conn = sqlite3.connect(str(db_path), isolation_level=None)
        self._conn.execute("PRAGMA journal_mode=WAL;")
        self._conn.executescript(_SCHEMA)
        logger.info(f"[state] sqlite ready at {db_path}")

    def close(self) -> None:
        self._conn.close()

    # ── brief dedup ────────────────────────────────────────────────────────
    def brief_already_sent(self, brief_hash: str) -> bool:
        cur = self._conn.execute(
            "SELECT 1 FROM sent_briefs WHERE hash=?", (brief_hash,)
        )
        return cur.fetchone() is not None

    def record_brief(self, brief_hash: str, sent_at_iso: str) -> None:
        self._conn.execute(
            "INSERT OR IGNORE INTO sent_briefs(hash, sent_at) VALUES (?, ?)",
            (brief_hash, sent_at_iso),
        )

    # ── mail dedup ─────────────────────────────────────────────────────────
    def mail_seen(self, msg_id: str) -> bool:
        cur = self._conn.execute("SELECT 1 FROM seen_mail WHERE msg_id=?", (msg_id,))
        return cur.fetchone() is not None

    def mark_mail_seen(self, msg_id: str, seen_at_iso: str) -> None:
        self._conn.execute(
            "INSERT OR IGNORE INTO seen_mail(msg_id, seen_at) VALUES (?, ?)",
            (msg_id, seen_at_iso),
        )

    # ── persistent daily counter ───────────────────────────────────────────
    def daily_count(self, day: str) -> int:
        cur = self._conn.execute("SELECT count FROM daily_sends WHERE day=?", (day,))
        row = cur.fetchone()
        return int(row[0]) if row else 0

    def increment_daily(self, day: str) -> None:
        self._conn.execute(
            "INSERT INTO daily_sends(day, count) VALUES (?, 1) "
            "ON CONFLICT(day) DO UPDATE SET count = count + 1",
            (day,),
        )

    # ── snooze ─────────────────────────────────────────────────────────────
    def get_snooze(self, key: str = "boss") -> str | None:
        cur = self._conn.execute("SELECT until_iso FROM snooze WHERE k=?", (key,))
        row = cur.fetchone()
        return row[0] if row else None

    def set_snooze(self, until_iso: str, key: str = "boss") -> None:
        self._conn.execute(
            "INSERT INTO snooze(k, until_iso) VALUES (?, ?) "
            "ON CONFLICT(k) DO UPDATE SET until_iso = excluded.until_iso",
            (key, until_iso),
        )

    def clear_snooze(self, key: str = "boss") -> None:
        self._conn.execute("DELETE FROM snooze WHERE k=?", (key,))
