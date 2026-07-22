"""The brain: a thin, direct wrapper around the `claude` CLI.

Replaces the old OpenClaw/JAVIS HTTP bridge. We invoke `claude -p` as a local
subprocess with an argv list (no shell → no quoting/injection surface) and feed
the prompt over stdin (no arg-length limits for long email/news blocks).

Auth: relies on your existing `claude login` (no ANTHROPIC_API_KEY needed). The
subprocess inherits your environment, so a logged-in CLI just works.
"""
from __future__ import annotations

import asyncio
import json
import os
import shutil
from dataclasses import dataclass
from pathlib import Path

from loguru import logger


class ClaudeNotFound(RuntimeError):
    """Raised when the `claude` binary can't be located."""


def find_claude_binary() -> str:
    """Locate the `claude` executable.

    Order: $CLAUDE_BIN → PATH → common install locations. Raises ClaudeNotFound
    with an actionable message if nothing is found.
    """
    override = os.environ.get("CLAUDE_BIN")
    if override:
        if Path(override).is_file() and os.access(override, os.X_OK):
            return override
        raise ClaudeNotFound(f"CLAUDE_BIN={override!r} is not an executable file")

    found = shutil.which("claude")
    if found:
        return found

    home = Path.home()
    candidates = [
        home / ".claude" / "local" / "claude",
        home / ".npm-global" / "bin" / "claude",
        home / ".local" / "bin" / "claude",
        Path("/opt/homebrew/bin/claude"),
        Path("/usr/local/bin/claude"),
    ]
    for c in candidates:
        if c.is_file() and os.access(c, os.X_OK):
            return str(c)

    raise ClaudeNotFound(
        "Could not find the `claude` CLI. Install it "
        "(`npm i -g @anthropic-ai/claude-code`), run `claude login`, or set "
        "CLAUDE_BIN in .env to its absolute path."
    )


@dataclass(frozen=True)
class BrainResult:
    text: str
    cost_usd: float | None
    num_turns: int | None
    ok: bool
    error: str | None = None


def _extract(raw: str) -> tuple[str, float | None, int | None]:
    """Pull text + metadata out of `claude -p --output-format json` output.

    Shape is {"type":"result","result":"...","total_cost_usd":..,"num_turns":..}.
    Falls back to the raw string if it isn't parseable (e.g. a truncated stream).
    """
    raw = (raw or "").strip()
    try:
        obj = json.loads(raw)
        if isinstance(obj, dict):
            text = str(obj.get("result") or obj.get("response") or raw)
            cost = obj.get("total_cost_usd")
            turns = obj.get("num_turns")
            return text, (float(cost) if cost is not None else None), (
                int(turns) if turns is not None else None
            )
    except (json.JSONDecodeError, ValueError, TypeError):
        pass
    return raw, None, None


class ClaudeBrain:
    """Runs prompts through the local `claude` CLI."""

    def __init__(
        self,
        *,
        allowed_tools: list[str],
        mcp_config: str | None,
        repo_root: Path,
        scratch_cwd: Path,
    ) -> None:
        self._binary = find_claude_binary()
        self._allowed_tools = allowed_tools
        # Only pass --mcp-config if a config actually defines servers. A local,
        # gitignored override (mcp.local.json) wins over the committed mcp.json —
        # so enabling optional add-ons (e.g. Gmail/Calendar) never touches the
        # shared, easy-by-default config.
        self._mcp_config: str | None = None
        if mcp_config:
            p = (repo_root / mcp_config) if not Path(mcp_config).is_absolute() else Path(mcp_config)
            local = p.with_name(p.stem + ".local" + p.suffix)  # config/mcp.local.json
            if local.is_file():
                p = local
            if p.is_file() and self._mcp_has_servers(p):
                self._mcp_config = str(p)
            else:
                # No servers configured — the default. Chat + news work with zero
                # setup; mail/calendar are an opt-in (see README §Gmail/Calendar).
                logger.info(
                    "[brain] no MCP servers configured — chat + news only "
                    "(add config/mcp.local.json to enable Gmail/Calendar)"
                )
        # The brain runs in a scratch cwd, never the repo root — it has no
        # business editing project files; tools are restricted to read/search.
        scratch_cwd.mkdir(parents=True, exist_ok=True)
        self._cwd = str(scratch_cwd)
        logger.info(f"[brain] claude binary: {self._binary}")

    @staticmethod
    def _mcp_has_servers(path: Path) -> bool:
        try:
            data = json.loads(path.read_text())
            return bool(data.get("mcpServers"))
        except (OSError, json.JSONDecodeError):
            return False

    def _build_args(self, *, model: str, system_prompt: str, max_turns: int) -> list[str]:
        args = [
            self._binary,
            "-p",
            "--output-format", "json",
            "--model", model,
            "--append-system-prompt", system_prompt,
            "--max-turns", str(max_turns),
        ]
        if self._allowed_tools:
            # The CLI splits a single space-separated string into the tool list.
            args += ["--allowedTools", " ".join(self._allowed_tools)]
        if self._mcp_config:
            args += ["--mcp-config", self._mcp_config]
        return args

    async def run(
        self,
        prompt: str,
        *,
        model: str,
        system_prompt: str,
        max_turns: int,
        timeout_s: float,
    ) -> BrainResult:
        """Run one prompt. Never raises — failures come back as BrainResult(ok=False)."""
        args = self._build_args(
            model=model, system_prompt=system_prompt, max_turns=max_turns
        )
        logger.info(
            f"[brain] run model={model} max_turns={max_turns} prompt={prompt[:80]!r}"
        )
        try:
            proc = await asyncio.create_subprocess_exec(
                *args,
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=self._cwd,
            )
        except FileNotFoundError:
            return BrainResult("", None, None, False, "claude binary vanished")

        try:
            stdout, stderr = await asyncio.wait_for(
                proc.communicate(input=prompt.encode()), timeout=timeout_s
            )
        except asyncio.TimeoutError:
            try:
                proc.kill()
                await proc.wait()
            except ProcessLookupError:
                pass
            logger.error(f"[brain] timeout after {timeout_s}s")
            return BrainResult("", None, None, False, f"timeout after {timeout_s}s")

        out = stdout.decode(errors="replace")
        if proc.returncode != 0:
            err = (stderr.decode(errors="replace") or out)[:500]
            logger.error(f"[brain] exit={proc.returncode} err={err!r}")
            return BrainResult("", None, None, False, err or f"exit {proc.returncode}")

        text, cost, turns = _extract(out)
        logger.info(f"[brain] ok cost={cost} turns={turns} len={len(text)}")
        return BrainResult(text, cost, turns, True)
