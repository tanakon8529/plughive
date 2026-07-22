# English strings for setup.sh
# To add a language: copy this file to locales/<code>.sh, translate the values,
# set LANG_NAME. The setup menu discovers it automatically.
LANG_NAME="English"

M_subtitle="personal AI setup"
M_tagline="Claude CLI × Discord · plug-and-play"

M_menu_header="Menu (type a number)"
M_m_full="Full setup (recommended)"
M_m_prereq="Check prerequisites"
M_m_tools="Install claude CLI + uv"
M_m_login="Claude login"
M_m_deps="Install Python dependencies"
M_m_env="Configure Discord (.env)"
M_m_google="Gmail/Calendar (optional)"
M_m_verify="Verify"
M_m_run="Run plughive"
M_m_lang="Language"
M_m_help="Help"
M_m_exit="Exit"
M_choose="choose"
M_press_enter="Press Enter to continue…"
M_unknown="unknown option"
M_bye="bye 👋"
M_ready="Ready"
M_install_missing="Install the missing tools above, then run setup again."

M_step_prereq="1. Prerequisites"
M_step_tools="2. Install claude CLI + uv"
M_step_login="3. Claude login (the brain)"
M_step_deps="4. Python dependencies"
M_step_env="5. Configure Discord (.env)"
M_step_google="6. Gmail + Calendar (optional)"
M_step_verify="7. Verify"
M_step_run="8. Run plughive"
M_step_lang="Language"

M_git_missing="git not found →"
M_py_missing="python >= 3.11 not found →"
M_node_missing="node/npm not found (needed to install claude CLI) →"
M_claude_missing_later="claude CLI not found — step 2 will install it"
M_uv_optional="uv not found (optional — will fall back to pip/venv)"

M_claude_present="claude CLI already installed"
M_ask_install_claude="Install claude CLI via npm now?"
M_claude_installed="claude installed"
M_claude_install_fail="install failed — try: npm i -g @anthropic-ai/claude-code"
M_need_npm="need npm first →"
M_ask_install_uv="Install uv (fast dependency manager)?"
M_uv_installed="uv installed (you may need a new terminal for PATH)"
M_uv_not_ready="uv not ready — will use pip instead"

M_login_info="The bot calls 'claude -p' using this login (no API key needed)"
M_ask_login_now="Run 'claude login' now? (opens a browser)"
M_login_browser_hint="if the browser doesn't open, run 'claude login' yourself"
M_login_skip="skipped — but you must 'claude login' before the bot can think"
M_login_need_cli="no claude CLI yet — do step 2 first"

M_uv_sync_ok="uv sync done"
M_uv_sync_fail="uv sync failed"
M_venv_fail="could not create venv"
M_pip_ok="installed via pip/venv (activate .venv to use)"
M_pip_fail="pip install failed"

M_env_bot_info="Create a Discord bot: https://discord.com/developers/applications"
M_env_intent="• enable the privileged intent: MESSAGE CONTENT"
M_env_copyid="• invite the bot, enable Developer Mode, copy the channel ID"
M_env_paste_token="Paste DISCORD_BOT_TOKEN (blank = keep current): "
M_env_paste_channel="Paste DISCORD_CHANNEL_ID (the channel plughive posts to)"
M_env_updated=".env updated (mode 600)"
M_env_has_token="token present"
M_env_no_token="no token yet"
M_env_has_channel="channel id present"
M_env_no_channel="no channel id yet (the bot will tell you at runtime)"

M_verify_ok="modules load + plug discovered"
M_verify_fail="verify failed — see the error above"
M_claude_ready="claude CLI ready"
M_claude_not="no claude CLI yet"
M_token_set="Discord token set"
M_token_not="token not set yet (step 5)"

M_run_no_token="no token yet — do step 5 first"
M_run_starting="starting… (Ctrl+C to stop)"
M_done="Done! Pick menu Run, or: uv run plughive"

M_google_text="Default is news + chat (zero setup). Mail/Calendar is an optional add-on: a
  background bot can't use Claude's connectors (headless), so it needs its own Google
  credential via a local MCP server (npx, no Docker). This wizard sets it up for you —
  you only create the OAuth client in Google and click Allow once."
M_g_enable_q="Enable Gmail + Calendar now?"
M_g_skip="Skipped — running news + chat. You can enable it later from this menu."
M_g_need_claude="Install the claude CLI first (menu 3)."
M_g_enabled_file="enabled config/mcp.local.json"
M_g_cloud="STEP A — create your Google OAuth client (in the browser):
    1) Enable Gmail + Calendar APIs (one click):
       https://console.cloud.google.com/flows/enableapi?apiid=gmail.googleapis.com,calendar-json.googleapis.com
    2) APIs & Services -> Credentials -> Create Credentials -> OAuth client ID
       -> Application type: Desktop app -> copy the Client ID and Client secret
    3) OAuth consent screen: User type External; add scopes gmail.modify,
       gmail.labels, calendar; add your own Google account under Test users."
M_g_wait_creds="When you have the Client ID + Secret, press Enter to paste them"
M_g_paste_id="Paste GOOGLE_CLIENT_ID"
M_g_paste_secret="Paste GOOGLE_CLIENT_SECRET (hidden): "
M_g_env_saved="credentials saved to .env"
M_g_need_creds="Client ID / Secret missing — run this menu again when you have them."
M_g_authorize_q="Authorize now? (opens a browser to approve access)"
M_g_authorizing="Authorizing — approve in the browser that opens…"
M_g_authorized="authorized — token saved; the brief now includes mail + calendar"
M_g_authorize_later="Skipped authorization. Run it later:"
M_g_done="Gmail + Calendar enabled."

M_help_text="plughive — a plug-and-play personal AI (Claude CLI × Discord).

  How it works: one process (bot + scheduler + sqlite). The brain is 'claude -p'.
  Features: replies when @mentioned + a brief every 2h (mail/calendar/news) that
            decides on its own what's worth reporting.

  Recommended order (menu Full does it all):
    prereqs → install claude/uv → claude login → deps → Discord token/channel
    → (optional) mail/calendar → verify → run

  Manual steps you do yourself (the wizard pauses for each):
    • claude login (opens a browser)
    • create a Discord bot, enable MESSAGE CONTENT, copy token + channel id

  Key files:
    .env                    = secrets (token, channel id)
    config/plughive.yaml    = behaviour (brief cadence, quiet hours, models, plugs)
    personas/rochana.md     = the ROCHANA (เก้า) voice
    locales/<code>.sh       = setup translations (add a file = add a language)

  Windows: run in Git Bash (comes with Git for Windows) or WSL.
  Flags: ./setup.sh --all · --help · NO_COLOR=1 · PLUGHIVE_LANG=en"
