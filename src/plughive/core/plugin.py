"""Plug interface + shared context.

A "plug" is a self-contained capability under src/plughive/plugs/<name>/ with a
manifest.yaml and a plug.py exposing a Plug subclass. Plugs share one process:
one Discord connection, one scheduler, one SQLite file. Adding a capability =
drop a folder + list it in config/plughive.yaml. That's the "dynamic scaling".
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from apscheduler.schedulers.asyncio import AsyncIOScheduler

    from plughive.brain.claude_cli import ClaudeBrain
    from plughive.brain.persona import PersonaLoader
    from plughive.config import Settings
    from plughive.core.bot import BotManager
    from plughive.core.state import StateStore


@dataclass(frozen=True)
class PlugManifest:
    name: str
    version: str
    description: str
    entrypoint: str                       # "plug.py:ClassName"
    provides: list[str] = field(default_factory=list)
    requires_env: list[str] = field(default_factory=list)
    requires_mcp: list[str] = field(default_factory=list)
    enabled_default: bool = True

    @staticmethod
    def from_dict(d: dict) -> "PlugManifest":
        return PlugManifest(
            name=str(d["name"]),
            version=str(d.get("version", "0.0.0")),
            description=str(d.get("description", "")),
            entrypoint=str(d["entrypoint"]),
            provides=list(d.get("provides", []) or []),
            requires_env=list(d.get("requires_env", []) or []),
            requires_mcp=list(d.get("requires_mcp", []) or []),
            enabled_default=bool(d.get("enabled_default", True)),
        )


@dataclass
class PlugContext:
    """Everything a plug is handed at setup time."""

    settings: "Settings"
    brain: "ClaudeBrain"
    bot: "BotManager"
    scheduler: "AsyncIOScheduler"
    state: "StateStore"
    persona: "PersonaLoader"


class Plug(ABC):
    manifest: PlugManifest

    @abstractmethod
    async def setup(self, ctx: PlugContext) -> None:
        """Wire dependencies, register Discord handlers / scheduler jobs."""

    async def start(self) -> None:
        """Begin work. Called after all plugs have been set up."""

    async def stop(self) -> None:
        """Graceful teardown. Called in reverse order on shutdown."""

    def health(self) -> dict:
        return {"name": self.manifest.name, "ok": True}
