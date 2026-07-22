"""Load .env + config/rochana.yaml into a typed Settings object.

Secrets come from the environment (.env); behaviour comes from the YAML. No
DB, no config service — just two files a forker can read and edit.
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

import yaml
from dotenv import load_dotenv
from loguru import logger


def repo_root() -> Path:
    # src/rochana/config.py → repo root is three parents up.
    return Path(__file__).resolve().parents[2]


@dataclass
class BrainCfg:
    chat_model: str = "claude-sonnet-4-5"
    brief_model: str = "claude-sonnet-4-5"
    chat_max_turns: int = 6
    brief_max_turns: int = 12
    chat_timeout_s: int = 120
    brief_timeout_s: int = 300
    allowed_tools: list[str] = field(default_factory=lambda: ["WebSearch"])
    mcp_config: str = "config/mcp.json"


@dataclass
class ProactivityCfg:
    quiet_start: int = 21
    quiet_end: int = 8
    max_daily_boss_messages: int = 8


@dataclass
class BriefCfg:
    cron_hours: str = "8-20/2"
    cron_minute: int = 0
    include: list[str] = field(default_factory=lambda: ["mail", "calendar", "news"])


@dataclass
class Settings:
    root: Path
    timezone: str
    boss_nickname: str
    persona_file: str
    enabled_plugs: list[str]
    brain: BrainCfg
    proactivity: ProactivityCfg
    brief: BriefCfg

    # secrets / env
    discord_token: str
    boss_channel_id: int

    @property
    def persona_path(self) -> Path:
        p = Path(self.persona_file)
        return p if p.is_absolute() else self.root / p

    @property
    def state_db_path(self) -> Path:
        return self.root / ".runtime" / "state.sqlite"

    @property
    def brain_scratch_cwd(self) -> Path:
        return self.root / ".runtime" / "brain_cwd"


def load_settings() -> Settings:
    root = repo_root()
    load_dotenv(root / ".env")

    cfg_path = root / "config" / "rochana.yaml"
    raw = yaml.safe_load(cfg_path.read_text()) if cfg_path.is_file() else {}
    raw = raw or {}

    brain_raw = raw.get("brain", {}) or {}
    proact_raw = raw.get("proactivity", {}) or {}
    brief_raw = raw.get("brief", {}) or {}

    settings = Settings(
        root=root,
        timezone=str(raw.get("timezone", "Asia/Bangkok")),
        boss_nickname=str(raw.get("boss_nickname", "Boss")),
        persona_file=str(raw.get("persona_file", "personas/rochana.md")),
        enabled_plugs=list(raw.get("enabled_plugs", []) or []),
        brain=BrainCfg(
            chat_model=str(brain_raw.get("chat_model", BrainCfg.chat_model)),
            brief_model=str(brain_raw.get("brief_model", BrainCfg.brief_model)),
            chat_max_turns=int(brain_raw.get("chat_max_turns", 6)),
            brief_max_turns=int(brain_raw.get("brief_max_turns", 12)),
            chat_timeout_s=int(brain_raw.get("chat_timeout_s", 120)),
            brief_timeout_s=int(brain_raw.get("brief_timeout_s", 300)),
            allowed_tools=list(brain_raw.get("allowed_tools", ["WebSearch"]) or []),
            mcp_config=str(brain_raw.get("mcp_config", "config/mcp.json")),
        ),
        proactivity=ProactivityCfg(
            quiet_start=int(proact_raw.get("quiet_start", 21)),
            quiet_end=int(proact_raw.get("quiet_end", 8)),
            max_daily_boss_messages=int(proact_raw.get("max_daily_boss_messages", 8)),
        ),
        brief=BriefCfg(
            cron_hours=str(brief_raw.get("cron_hours", "8-20/2")),
            cron_minute=int(brief_raw.get("cron_minute", 0)),
            include=list(brief_raw.get("include", ["mail", "calendar", "news"]) or []),
        ),
        discord_token=os.environ.get("DISCORD_ROCHANA_TOKEN", ""),
        # Accept BOSS_DISCORD_CHANNEL_ID, or fall back to BOSS_DISCORD_SERVER_ID
        # (the name the old system used). This must resolve to a *channel* id;
        # a startup check warns if it's actually a server/guild id.
        boss_channel_id=int(
            (os.environ.get("BOSS_DISCORD_CHANNEL_ID")
             or os.environ.get("BOSS_DISCORD_SERVER_ID")
             or "0") or "0"
        ),
    )
    logger.info(
        f"[config] tz={settings.timezone} plugs={settings.enabled_plugs} "
        f"brief={settings.brief.cron_hours}"
    )
    return settings
