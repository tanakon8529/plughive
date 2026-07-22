# plughive 🔌🐝

A **minimal, plug-and-play personal AI framework**. The [Claude CLI](https://docs.claude.com/en/docs/claude-code) is the brain; Discord is the face. One always-on Python process — no Docker, no database, no web dashboard.

Out of the box the bot:

- **Chats** on Discord — @mention it and it answers via the Claude CLI, using WebSearch + your Gmail/Calendar tools.
- **Briefs you every 2 hours** (08:00–20:00) with your unread mail, upcoming calendar, and interesting news — and **decides on its own** what's worth reporting and how. Nothing notable? It stays silent.

Everything is a **plug**. Add a folder, list it in one YAML file, restart — that's a new capability. The persona is just config: the framework ships a neutral assistant, plus **ROCHANA (เก้า)** — a polite Thai persona — as a ready example you enable in one line.

---

## Quickstart

```bash
git clone <your-fork-url> plughive && cd plughive
./setup.sh          # guided setup: installs deps, logs into Claude, writes .env, runs
```

The **`setup.sh`** wizard (macOS · Linux · WSL · Git Bash) walks you through everything with a menu — it checks prerequisites, installs the `claude` CLI + `uv`, runs `claude login`, installs dependencies, and prompts you for your Discord token & channel id. It **pauses and waits** whenever a step needs you (browser login, creating the bot). Run `./setup.sh --all` for the whole flow, `./setup.sh --help` for details.

- **Windows (native):** `./setup.ps1` in PowerShell — or just use `./setup.sh` in Git Bash.
- **Language:** the wizard speaks **English & ไทย** — switch any time via the `l` menu item, or start with `PLUGHIVE_LANG=en ./setup.sh`. Add a language by dropping a `locales/<code>.sh` file (copy `locales/en.sh`, translate) — the menu picks it up automatically.
- **Prefer to do it by hand?** See [Manual setup](#manual-setup) below.

That's it. @mention the bot to chat; the 2-hour brief runs automatically.

**Prerequisites the wizard can't auto-install:** Python ≥ 3.11, Node.js, Git. It detects your package manager (brew/apt/dnf/pacman/winget/choco) and prints the exact install command if any are missing.

<details id="manual-setup">
<summary><b>Manual setup</b></summary>

```bash
npm i -g @anthropic-ai/claude-code && claude login   # brain (no API key needed)
cp .env.example .env                                  # fill DISCORD_BOT_TOKEN + DISCORD_CHANNEL_ID
uv sync                                               # or: python -m venv .venv && pip install -e .
uv run plughive                                        # or: python -m plughive
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

- **Brain** (`src/plughive/brain/claude_cli.py`) — spawns `claude -p --output-format json` directly (argv, no shell), feeds the prompt over stdin, parses the JSON result. Auth is your existing `claude login`.
- **State** (`.runtime/state.sqlite`) — brief dedup, seen mail, a persistent daily-send cap, snooze. One SQLite file, that's the whole "database".
- **Gate** (`core/proactivity.py`) — critical override → snooze → quiet hours → daily cap, so the bot never spams you.

## The plug model

A plug is a folder under `src/plughive/plugs/<name>/`:

```
plugs/my_plug/
├── manifest.yaml        # name, entrypoint, requires_env, requires_mcp
└── plug.py              # class implementing setup()/start()/stop()
```

Add its name to `enabled_plugs:` in `config/plughive.yaml`, restart. To disable, remove it from the list. To share an upgrade, open a PR that adds one plug. Every plug shares one Discord connection, one scheduler, and one SQLite store (`PlugContext`).

The shipped plug is [`discord`](src/plughive/plugs/discord/) — the chat bot + the 2-hour brief.

## Gmail + Calendar (optional add-on)

**By default the bot needs no Google setup at all** — chat + news work out of the box. Mail/Calendar in the brief are opt-in.

> **Why it isn't one-click:** a *background* bot runs the Claude CLI headless (`claude -p`), and Claude's own claude.ai Gmail/Calendar connectors **only work in an interactive `claude` session** — a headless process can't see them (and Google's endpoint refuses `claude mcp login`). So any always-on bot that reads your inbox needs its **own** Google credential. That's a Google/Claude-Code constraint, not a plughive one. If you don't need mail/calendar, skip this entirely.

To enable it, the brief reads mail/calendar via a **local Google MCP server** ([`@dguido/google-workspace-mcp`](https://github.com/dguido/google-workspace-mcp)) the brain launches on demand via `npx` (no Docker, nothing in the background):

**1. Turn the add-on on**
```bash
cp config/mcp.local.example.json config/mcp.local.json   # gitignored; overrides the empty default
```

**2. Create a Google OAuth client (once, ~3 min)**
- Enable the Gmail + Calendar APIs: [one-click link](https://console.cloud.google.com/flows/enableapi?apiid=gmail.googleapis.com,calendar-json.googleapis.com)
- **APIs & Services → Credentials → Create Credentials → OAuth client ID → Application type: Desktop app**. Copy the **Client ID** and **Client secret**.
- **OAuth consent screen**: user type *External*, add the scopes `gmail.modify`, `gmail.labels`, `calendar`, and add your own Google account under **Test users**. (Prefer read-only? use `gmail.readonly` + `calendar.readonly`.)

**3. Put the credentials in `.env`**
```
GOOGLE_CLIENT_ID=xxxxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=xxxxx
```

**4. Authorize once (opens a browser)**
```bash
claude -p "List my 3 most recent emails." --mcp-config config/mcp.local.json --allowedTools "mcp__google__*"
```
Approve in the browser — a token is saved to `~/.config/google-workspace-mcp/tokens.json` (0600). After that the always-on bot uses it headlessly and the brief includes mail + calendar.

## Configuration

The framework code is generic — **all personality lives in config**, so you never edit code to make it yours.

| File | What |
|---|---|
| `.env` | secrets: Discord token (`DISCORD_BOT_TOKEN`), channel id (`DISCORD_CHANNEL_ID`), optional `ANTHROPIC_API_KEY` / `CLAUDE_BIN` |
| `config/plughive.yaml` | shared, generic defaults: `bot_name`, `boss_nickname`, `persona_file`, models, brief cadence, quiet hours, enabled plugs |
| `config/plughive.local.yaml` | **your** personal overrides (gitignored) — deep-merges over the shared config. Copy from `plughive.local.example.yaml` |
| `personas/*.md` | the voice. Ships `assistant.md` (neutral default) and `rochana.md` (เก้า, Thai example). Point `persona_file` at any of them |
| `config/mcp.json` | MCP servers for the brain (empty by default) |
| `config/mcp.local.json` | **your** MCP override (gitignored) — enables the optional Gmail/Calendar add-on. Copy from `mcp.local.example.json` |

**Make it yours without touching the shared config or any code:**
```bash
cp config/plughive.local.example.yaml config/plughive.local.yaml
# edit bot_name / boss_nickname / persona_file — or write your own personas/<you>.md
```
Change the brief cadence via `brief.cron_hours` (cron hour expression, e.g. `"8-20/2"` or `"*/2"` for 24h).

## Slash commands

`/status` · `/cost` · `/pause [minutes]` · `/brief` (run a brief now)

## Contributing / forking

This repo ships the [`scrutinize`](.claude/skills/scrutinize/SKILL.md) skill — an outsider-perspective code-review skill. Run `/scrutinize` in Claude Code before opening a PR.

## Keeping it running (optional)

The process is meant to stay up. For auto-restart on macOS, wrap `uv run plughive` in a `launchd` plist (or `pm2` / `systemd` on Linux). This is optional — the scheduler lives inside the process, not in cron.

## License

MIT — see [LICENSE](LICENSE). Clone it, fork it, reskin เก้า, add plugs.
