#!/usr/bin/env bash
# plughive one-shot setup — macOS · Linux · WSL · Git Bash (Windows)
# Run:  ./setup.sh          (interactive menu)
#       ./setup.sh --all    (full setup)
#       ./setup.sh --help
#       PLUGHIVE_LANG=en ./setup.sh   ·   NO_COLOR=1 ./setup.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1
LOCALES_DIR="$SCRIPT_DIR/locales"
LANG_FILE="$SCRIPT_DIR/.runtime/lang"

# ── colours (auto-off if no tty or NO_COLOR) ────────────────────────────────
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  B=$'\033[1m'; DIM=$'\033[2m'; R=$'\033[0m'
  RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; BLU=$'\033[34m'; CYN=$'\033[36m'
else
  B=""; DIM=""; R=""; RED=""; GRN=""; YLW=""; BLU=""; CYN=""
fi
ok()   { printf "  ${GRN}✔${R} %s\n" "$*"; }
warn() { printf "  ${YLW}!${R} %s\n" "$*"; }
err()  { printf "  ${RED}x${R} %s\n" "$*"; }
info() { printf "  ${CYN}i${R} %s\n" "$*"; }
step() { printf "\n${B}${BLU}▸ %s${R}\n" "$*"; }
pause(){ printf "\n${DIM}%s${R}" "$M_press_enter"; read -r _; }
ask()  { local q="$1" d="${2:-}" a
  if [ -n "$d" ]; then printf "%s ${DIM}[%s]${R}: " "$q" "$d" >&2; else printf "%s: " "$q" >&2; fi
  read -r a; printf "%s" "${a:-$d}"; }
yesno(){ local q="$1" d="${2:-y}" a
  printf "%s ${DIM}[%s]${R} " "$q" "$( [ "$d" = y ] && echo 'Y/n' || echo 'y/N')"
  read -r a; a="${a:-$d}"; case "$a" in [Yy]*) return 0;; *) return 1;; esac; }

# ── i18n (locale files in locales/*.sh — drop one in to add a language) ──────
available_langs(){ local f; for f in "$LOCALES_DIR"/*.sh; do [ -f "$f" ] || continue; basename "$f" .sh; done; }
lang_name(){ ( # shellcheck source=/dev/null
  . "$LOCALES_DIR/$1.sh" 2>/dev/null; printf '%s' "${LANG_NAME:-$1}" ); }
load_lang(){ local c="$1"
  [ -f "$LOCALES_DIR/$c.sh" ] || c=en
  # shellcheck source=/dev/null
  . "$LOCALES_DIR/$c.sh"; CUR_LANG="$c"
  mkdir -p "$(dirname "$LANG_FILE")" 2>/dev/null && printf '%s' "$c" > "$LANG_FILE" 2>/dev/null || true; }
default_lang(){
  [ -f "$LANG_FILE" ] && { cat "$LANG_FILE"; return; }
  if [ -n "${PLUGHIVE_LANG:-}" ] && [ -f "$LOCALES_DIR/$PLUGHIVE_LANG.sh" ]; then echo "$PLUGHIVE_LANG"; return; fi
  case "${LANG:-}" in th*|TH*) [ -f "$LOCALES_DIR/th.sh" ] && echo th || echo en;; *) echo en;; esac; }
choose_lang(){
  banner; step "$M_step_lang"
  local n=1 map="" c
  for c in $(available_langs); do printf "    %d) %s ${DIM}(%s)${R}\n" "$n" "$(lang_name "$c")" "$c"; map="$map $n:$c"; n=$((n+1)); done
  local pick; pick="$(ask "  $M_choose")"
  for kv in $map; do [ "${kv%%:*}" = "$pick" ] && { load_lang "${kv#*:}"; return; }; done
  warn "$M_unknown"; sleep 1; }

# ── OS / arch ───────────────────────────────────────────────────────────────
OS=unknown; PKG=""
case "$(uname -s 2>/dev/null)" in
  Darwin) OS=mac;; Linux) OS=linux;; MINGW*|MSYS*|CYGWIN*) OS=windows;;
esac
detect_pkg(){
  if   command -v brew   >/dev/null 2>&1; then PKG=brew
  elif command -v apt-get>/dev/null 2>&1; then PKG=apt
  elif command -v dnf    >/dev/null 2>&1; then PKG=dnf
  elif command -v pacman >/dev/null 2>&1; then PKG=pacman
  elif command -v winget >/dev/null 2>&1; then PKG=winget
  elif command -v choco  >/dev/null 2>&1; then PKG=choco
  fi; }
detect_pkg
PY=""; for c in python3 python; do command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }; done

banner(){
  clear 2>/dev/null || true
  printf "${B}${CYN}
  ╭───────────────────────────────────────────────╮
  │              p l u g h i v e                    │
  ╰───────────────────────────────────────────────╯${R}
  ${DIM}%s · %s${R}
  ${DIM}OS: %s   pkg: %s   python: %s   lang: %s${R}\n" \
  "$M_subtitle" "$M_tagline" "$OS" "${PKG:-none}" "${PY:-missing}" "${CUR_LANG:-en}"
}

py_ok(){ [ -n "$PY" ] && "$PY" -c 'import sys; raise SystemExit(0 if sys.version_info>=(3,11) else 1)' 2>/dev/null; }
install_hint(){ case "$1:$PKG" in
    node:brew) echo "brew install node";; node:apt) echo "sudo apt-get install -y nodejs npm";;
    node:dnf) echo "sudo dnf install -y nodejs";; node:pacman) echo "sudo pacman -S nodejs npm";;
    node:winget) echo "winget install OpenJS.NodeJS.LTS";; node:choco) echo "choco install nodejs-lts -y";;
    node:*) echo "https://nodejs.org/en/download";;
    python:brew) echo "brew install python@3.12";; python:apt) echo "sudo apt-get install -y python3 python3-venv";;
    python:dnf) echo "sudo dnf install -y python3";; python:pacman) echo "sudo pacman -S python";;
    python:winget) echo "winget install Python.Python.3.12";; python:choco) echo "choco install python -y";;
    python:*) echo "https://www.python.org/downloads (>= 3.11)";;
    git:*) echo "https://git-scm.com/downloads";; esac; }

check_prereqs(){
  step "$M_step_prereq"; local missing=0
  if command -v git >/dev/null 2>&1; then ok "git $(git --version | awk '{print $3}')"; else err "$M_git_missing $(install_hint git)"; missing=1; fi
  if py_ok; then ok "python $("$PY" -c 'import platform;print(platform.python_version())') ($PY)"; else err "$M_py_missing $(install_hint python)"; missing=1; fi
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then ok "node $(node --version) / npm $(npm --version)"; else warn "$M_node_missing $(install_hint node)"; missing=1; fi
  if command -v claude >/dev/null 2>&1; then ok "claude CLI $(claude --version 2>/dev/null | head -1)"; else warn "$M_claude_missing_later"; fi
  if command -v uv >/dev/null 2>&1; then ok "uv $(uv --version | awk '{print $2}')"; else info "$M_uv_optional"; fi
  echo; if [ "$missing" -eq 0 ]; then ok "${B}${M_ready}${R}"; else warn "$M_install_missing"; fi
  return "$missing"; }

install_tools(){
  step "$M_step_tools"
  if command -v claude >/dev/null 2>&1; then ok "$M_claude_present"
  elif command -v npm >/dev/null 2>&1; then
    if yesno "$M_ask_install_claude"; then npm i -g @anthropic-ai/claude-code && ok "$M_claude_installed" || err "$M_claude_install_fail"; fi
  else err "$M_need_npm $(install_hint node)"; fi
  if ! command -v uv >/dev/null 2>&1; then
    if yesno "$M_ask_install_uv"; then
      if [ "$OS" = windows ]; then "$PY" -m pip install --user uv; else curl -LsSf https://astral.sh/uv/install.sh | sh; fi
      command -v uv >/dev/null 2>&1 && ok "$M_uv_installed" || warn "$M_uv_not_ready"
    fi
  fi; }

claude_login(){
  step "$M_step_login"
  command -v claude >/dev/null 2>&1 || { err "$M_login_need_cli"; return 1; }
  info "$M_login_info"
  if yesno "$M_ask_login_now"; then claude login || warn "$M_login_browser_hint"; else info "$M_login_skip"; fi; }

install_deps(){
  step "$M_step_deps"
  if command -v uv >/dev/null 2>&1; then uv sync && ok "$M_uv_sync_ok" || { err "$M_uv_sync_fail"; return 1; }
  else
    "$PY" -m venv .venv || { err "$M_venv_fail"; return 1; }
    # shellcheck disable=SC1091
    if [ -f .venv/bin/activate ]; then . .venv/bin/activate; else . .venv/Scripts/activate; fi
    "$PY" -m pip install -q --upgrade pip && "$PY" -m pip install -q -e . && ok "$M_pip_ok" || { err "$M_pip_fail"; return 1; }
  fi; }

configure_env(){
  step "$M_step_env"
  [ -f .env ] || cp .env.example .env
  info "$M_env_bot_info"; info "$M_env_intent"; info "$M_env_copyid"; echo
  local tok cid
  printf "  %s" "$M_env_paste_token"; stty -echo 2>/dev/null; read -r tok; stty echo 2>/dev/null; echo
  cid="$(ask "  $M_env_paste_channel")"
  TOK="$tok" CID="$cid" "$PY" - <<'PY'
import os, re, pathlib
p = pathlib.Path(".env"); lines = p.read_text().splitlines()
def setkv(lines, key, val):
    if not val: return lines
    out, seen = [], False
    for ln in lines:
        if re.match(rf'^\s*#?\s*{re.escape(key)}=', ln): out.append(f"{key}={val}"); seen=True
        else: out.append(ln)
    if not seen: out.append(f"{key}={val}")
    return out
lines = setkv(lines, "DISCORD_BOT_TOKEN", os.environ.get("TOK",""))
lines = setkv(lines, "DISCORD_CHANNEL_ID", os.environ.get("CID",""))
p.write_text("\n".join(lines) + "\n")
PY
  chmod 600 .env 2>/dev/null || true
  ok "$M_env_updated"
  grep -q '^DISCORD_BOT_TOKEN=.\+' .env && ok "$M_env_has_token" || warn "$M_env_no_token"
  grep -q '^DISCORD_CHANNEL_ID=[0-9]\+' .env && ok "$M_env_has_channel" || warn "$M_env_no_channel"; }

google_mcp(){ step "$M_step_google"; printf "  %s\n" "$M_google_text"
  if command -v claude >/dev/null 2>&1; then echo; info "claude mcp list:"; claude mcp list 2>/dev/null | grep -vE 'Checking' | sed 's/^/    /' | head; fi; }

verify(){
  step "$M_step_verify"
  local runpy=("$PY"); command -v uv >/dev/null 2>&1 && runpy=(uv run python)
  "${runpy[@]}" - <<'PY' && ok "$M_verify_ok" || err "$M_verify_fail"
import os
os.environ.setdefault("DISCORD_BOT_TOKEN","x"); os.environ.setdefault("DISCORD_CHANNEL_ID","1")
from plughive.config import load_settings
from plughive.core.registry import PlugRegistry
s=load_settings()
r=PlugRegistry(s.root/"src"/"plughive"/"plugs", enabled=s.enabled_plugs, mcp_config_path=s.root/s.brain.mcp_config)
ms=r._discover_manifests(); assert ms, "no plugs found"
print("   plugs:", ", ".join(m.name for _,m in ms))
PY
  command -v claude >/dev/null 2>&1 && ok "$M_claude_ready" || warn "$M_claude_not"
  grep -q '^DISCORD_BOT_TOKEN=.\+' .env 2>/dev/null && ok "$M_token_set" || warn "$M_token_not"; }

run_bot(){
  step "$M_step_run"
  grep -q '^DISCORD_BOT_TOKEN=.\+' .env 2>/dev/null || { err "$M_run_no_token"; return 1; }
  info "$M_run_starting"
  if command -v uv >/dev/null 2>&1; then exec uv run plughive
  elif [ -f .venv/bin/activate ]; then . .venv/bin/activate; exec plughive
  elif [ -f .venv/Scripts/activate ]; then . .venv/Scripts/activate; exec plughive
  else exec "$PY" -m plughive; fi; }

full_setup(){
  banner; check_prereqs || { pause; return; }
  install_tools; claude_login; install_deps || { pause; return; }
  configure_env; google_mcp; verify
  echo; ok "${B}${M_done}${R}"; pause; }

show_help(){ banner; printf "%s\n" "$M_help_text"; pause; }

menu(){
  while true; do
    banner
    printf "\n  ${B}%s${R}\n" "$M_menu_header"
    printf "    ${GRN}1)${R} ${B}%s${R}\n" "$M_m_full"
    printf "    2) %s\n" "$M_m_prereq"
    printf "    3) %s\n" "$M_m_tools"
    printf "    4) %s\n" "$M_m_login"
    printf "    5) %s\n" "$M_m_deps"
    printf "    6) %s\n" "$M_m_env"
    printf "    7) %s\n" "$M_m_google"
    printf "    8) %s\n" "$M_m_verify"
    printf "    ${CYN}9)${R} ${B}%s${R}\n" "$M_m_run"
    printf "    l) %s\n" "$M_m_lang"
    printf "    h) %s\n" "$M_m_help"
    printf "    0) %s\n" "$M_m_exit"
    case "$(ask "  $M_choose")" in
      1) full_setup;; 2) banner; check_prereqs; pause;; 3) banner; install_tools; pause;;
      4) banner; claude_login; pause;; 5) banner; install_deps; pause;; 6) banner; configure_env; pause;;
      7) banner; google_mcp; pause;; 8) banner; verify; pause;; 9) run_bot;;
      l|L|lang) choose_lang;; h|H|help) show_help;;
      0|q|exit) echo; ok "$M_bye"; exit 0;;
      *) warn "$M_unknown"; sleep 1;;
    esac
  done; }

load_lang "$(default_lang)"
case "${1:-}" in
  --all|-a)  full_setup;;
  --help|-h) show_help;;
  --lang)    [ -n "${2:-}" ] && load_lang "$2"; menu;;
  "" )       menu;;
  * )        err "unknown flag '$1' — try --help"; exit 1;;
esac
