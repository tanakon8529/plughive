"""Plug discovery + lifecycle.

1. glob plugs/*/manifest.yaml
2. gate each: enabled? required env present? required MCP servers resolvable?
   Unmet → log a warning and skip (boot never crashes on a bad/partial plug).
3. import the module, resolve the class named in `entrypoint`.
4. setup() all → start() all. On shutdown, stop() all in reverse.
"""
from __future__ import annotations

import importlib
import json
import os
from pathlib import Path

import yaml
from loguru import logger

from plugd.core.plugin import Plug, PlugContext, PlugManifest

_PLUGS_PKG = "plugd.plugs"


def _mcp_server_names(mcp_config_path: Path) -> set[str]:
    if not mcp_config_path.is_file():
        return set()
    try:
        data = json.loads(mcp_config_path.read_text())
        return set((data.get("mcpServers") or {}).keys())
    except (OSError, json.JSONDecodeError):
        return set()


class PlugRegistry:
    def __init__(self, plugs_dir: Path, *, enabled: list[str], mcp_config_path: Path) -> None:
        self._dir = plugs_dir
        self._enabled = set(enabled)
        self._mcp_names = _mcp_server_names(mcp_config_path)
        self._loaded: list[tuple[Plug, PlugContext]] = []

    def _discover_manifests(self) -> list[tuple[str, PlugManifest]]:
        out: list[tuple[str, PlugManifest]] = []
        for manifest_path in sorted(self._dir.glob("*/manifest.yaml")):
            folder = manifest_path.parent.name
            try:
                data = yaml.safe_load(manifest_path.read_text()) or {}
                out.append((folder, PlugManifest.from_dict(data)))
            except (OSError, yaml.YAMLError, KeyError) as e:
                logger.warning(f"[registry] bad manifest at {manifest_path}: {e}")
        return out

    def _should_load(self, folder: str, m: PlugManifest) -> bool:
        enabled = m.name in self._enabled or folder in self._enabled
        if not enabled:
            logger.info(f"[registry] '{m.name}' not in enabled_plugs — skipping")
            return False
        missing_env = [e for e in m.requires_env if not os.environ.get(e)]
        if missing_env:
            logger.warning(
                f"[registry] '{m.name}' skipped — missing env: {missing_env}"
            )
            return False
        missing_mcp = [s for s in m.requires_mcp if s not in self._mcp_names]
        if missing_mcp:
            # MCP is optional-degrade: warn but still load (news/chat work without it).
            logger.warning(
                f"[registry] '{m.name}' — MCP servers not configured: {missing_mcp} "
                "(mail/calendar features may be limited)"
            )
        return True

    def load_all(self, ctx: PlugContext) -> list[Plug]:
        for folder, manifest in self._discover_manifests():
            if not self._should_load(folder, manifest):
                continue
            try:
                module_file, _, class_name = manifest.entrypoint.partition(":")
                module_name = f"{_PLUGS_PKG}.{folder}.{module_file[:-3] if module_file.endswith('.py') else module_file}"
                mod = importlib.import_module(module_name)
                cls = getattr(mod, class_name)
                plug: Plug = cls()
                plug.manifest = manifest
                self._loaded.append((plug, ctx))
                logger.info(f"[registry] loaded plug '{manifest.name}' v{manifest.version}")
            except Exception as e:  # noqa: BLE001 - one bad plug shouldn't kill boot
                logger.error(f"[registry] failed to load '{manifest.name}': {e}")
        return [p for p, _ in self._loaded]

    async def setup_all(self) -> None:
        for plug, ctx in self._loaded:
            await plug.setup(ctx)

    async def start_all(self) -> None:
        for plug, _ in self._loaded:
            await plug.start()

    async def stop_all(self) -> None:
        for plug, _ in reversed(self._loaded):
            try:
                await plug.stop()
            except Exception as e:  # noqa: BLE001
                logger.warning(f"[registry] error stopping '{plug.manifest.name}': {e}")
