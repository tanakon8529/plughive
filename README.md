# ROCHANA 🔔

A **minimal, plug-and-play personal AI**. The [Claude CLI](https://docs.claude.com/en/docs/claude-code) is the brain; Discord is the face. One always-on Python process — no Docker, no database, no web dashboard.

Out of the box, ROCHANA (persona: *เก้า / Kao*):

- **Chats** on Discord — @mention her and she answers via the Claude CLI, using WebSearch + your Gmail/Calendar tools.
- **Briefs you every 2 hours** (08:00–20:00) with your unread mail, upcoming calendar, and interesting Thai + international news — and **decides on her own** what's worth reporting and how. Nothing notable? She stays silent.

Everything is a **plug**. Add a folder, list it in one YAML file, restart — that's a new capability.

---

## Quickstart

```bash
git clone <your-fork-url> plugd && cd plugd
./setup.sh          # guided setup: installs deps, logs into Claude, writes .env, runs
```

The **`setup.sh`** wizard (macOS · Linux · WSL · Git Bash) walks you through everything with a menu — it checks prerequisites, installs the `claude` CLI + `uv`, runs `claude login`, installs dependencies, and prompts you for your Discord token & channel id. It **pauses and waits** whenever a step needs you (browser login, creating the bot). Run `./setup.sh --all` for the whole flow, `./setup.sh --help` for details.

- **Windows (native):** `./setup.ps1` in PowerShell — or just use `./setup.sh` in Git Bash.
- **Prefer to do it by hand?** See [Manual setup](#manual-setup) below.

That's it. @mention the bot to chat; the 2-hour brief runs automatically.

**Prerequisites the wizard can't auto-install:** Python ≥ 3.11, Node.js, Git. It detects your package manager (brew/apt/dnf/pacman/winget/choco) and prints the exact install command if any are missing.

<details id="manual-setup">
<summary><b>Manual setup</b></summary>

```bash
npm i -g @anthropic-ai/claude-code && claude login   # brain (no API key needed)
cp .env.example .env                                  # fill DISCORD_ROCHANA_TOKEN + BOSS_DISCORD_CHANNEL_ID
uv sync                                               # or: python -m venv .venv && pip install -e .
uv run plugd                                        # or: python -m plugd
```
Create the Discord bot at https://discord.com/developers/applications, enable the **Message Content** intent, invite it, and copy the target channel's ID (Developer Mode → right-click channel → Copy ID).
</details>

---

## How it works

```
Discord  ──@mention──▶  plug  ──▶  ClaudeBrain.run()  ──▶  `claude -p` (subprocess)
                          │                                     │
APScheduler ──every 2h──▶ brief_job                       WebSearch + Gmail/Calendar MCP
                          │
                          ▼
                  proactive gate ──▶ Discord (Boss channel)
```

- **Brain** (`src/plugd/brain/claude_cli.py`) — spawns `claude -p --output-format json` directly (argv, no shell), feeds the prompt over stdin, parses the JSON result. Auth is your existing `claude login`.
- **State** (`.runtime/state.sqlite`) — brief dedup, seen mail, a persistent daily-send cap, snooze. One SQLite file, that's the whole "database".
- **Gate** (`core/proactivity.py`) — critical override → snooze → quiet hours → daily cap, so ROCHANA never spams you.

## The plug model

A plug is a folder under `src/plugd/plugs/<name>/`:

```
plugs/my_plug/
├── manifest.yaml        # name, entrypoint, requires_env, requires_mcp
└── plug.py              # class implementing setup()/start()/stop()
```

Add its name to `enabled_plugs:` in `config/plugd.yaml`, restart. To disable, remove it from the list. To share an upgrade, open a PR that adds one plug. Every plug shares one Discord connection, one scheduler, and one SQLite store (`PlugContext`).

The shipped plug is [`discord_rochana`](src/plugd/plugs/discord_rochana/) — the chat bot + the 2-hour brief.

## Gmail + Calendar

ROCHANA reads mail/calendar through **MCP connectors registered in your `claude` CLI**. The recommended setup uses Google's **remote HTTP MCP endpoints** — nothing runs locally (no Docker, no `npx`), you just authorize them once:

```bash
claude mcp add --transport http --scope user gmail https://gmailmcp.googleapis.com/mcp/v1
claude mcp login gmail        # opens a browser, one-time OAuth
claude mcp add --transport http --scope user gcal  https://calendarmcp.googleapis.com/mcp/v1
claude mcp login gcal
```

Run `claude mcp list` — both should show `✔ Connected`. That's it: the bot's `claude -p` brain inherits these user-scope connectors automatically (server names **must** be `gmail` and `gcal` so the tools match `mcp__gmail__*` / `mcp__gcal__*` in `config/plugd.yaml`).

> `claude mcp login` needs an **interactive terminal** (it can't run headless). Run the two `login` commands yourself once; after that the always-on bot uses the stored auth.

**Fork alternative:** to self-host, add a Google Workspace MCP server under `mcpServers` in `config/mcp.json` — the brain passes it to `claude -p` via `--mcp-config`.

Without any of this, ROCHANA still works — the brief just does **news only** (mail/calendar are skipped, not errored). News needs no setup; it uses the Claude CLI's built-in **WebSearch**.

## Configuration

| File | What |
|---|---|
| `.env` | secrets: Discord token, channel id, optional Google OAuth / `ANTHROPIC_API_KEY` / `CLAUDE_BIN` |
| `config/plugd.yaml` | behaviour: models, brief cadence, quiet hours, daily cap, enabled plugs |
| `config/mcp.json` | MCP servers handed to the brain |
| `personas/rochana.md` | เก้า's voice — reskin the assistant without touching code |

Change the brief cadence in `config/plugd.yaml` → `brief.cron_hours` (cron hour expression, e.g. `"8-20/2"` or `"*/2"` for 24h).

## Slash commands

`/status` · `/cost` · `/pause [minutes]` · `/brief` (run a brief now)

## Contributing / forking

This repo ships the [`scrutinize`](.claude/skills/scrutinize/SKILL.md) skill — an outsider-perspective code-review skill. Run `/scrutinize` in Claude Code before opening a PR.

## Keeping it running (optional)

The process is meant to stay up. For auto-restart on macOS, wrap `uv run plugd` in a `launchd` plist (or `pm2` / `systemd` on Linux). This is optional — the scheduler lives inside the process, not in cron.

## License

MIT — see [LICENSE](LICENSE). Clone it, fork it, reskin เก้า, add plugs.
