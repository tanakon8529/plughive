#!/usr/bin/env bash
# ROCHANA one-shot setup — macOS · Linux · WSL · Git Bash (Windows)
# Run:  ./setup.sh        (interactive menu)
#       ./setup.sh --all  (full setup, non-interactive where possible)
#       ./setup.sh --help
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

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
pause(){ printf "\n${DIM}กด Enter เพื่อไปต่อ…${R}"; read -r _; }
ask()  { # ask "question" [default] -> echoes answer
  local q="$1" d="${2:-}" a
  if [ -n "$d" ]; then printf "%s ${DIM}[%s]${R}: " "$q" "$d" >&2; else printf "%s: " "$q" >&2; fi
  read -r a; printf "%s" "${a:-$d}"
}
yesno(){ # yesno "question" [Y/n default y] -> returns 0 for yes
  local q="$1" d="${2:-y}" a
  printf "%s ${DIM}[%s]${R} " "$q" "$( [ "$d" = y ] && echo 'Y/n' || echo 'y/N')"
  read -r a; a="${a:-$d}"; case "$a" in [Yy]*) return 0;; *) return 1;; esac
}

# ── OS / arch ───────────────────────────────────────────────────────────────
OS=unknown; PKG=""
case "$(uname -s 2>/dev/null)" in
  Darwin) OS=mac;;
  Linux)  OS=linux;;
  MINGW*|MSYS*|CYGWIN*) OS=windows;;
esac
detect_pkg() {
  if   command -v brew   >/dev/null 2>&1; then PKG=brew
  elif command -v apt-get>/dev/null 2>&1; then PKG=apt
  elif command -v dnf    >/dev/null 2>&1; then PKG=dnf
  elif command -v pacman >/dev/null 2>&1; then PKG=pacman
  elif command -v winget >/dev/null 2>&1; then PKG=winget
  elif command -v choco  >/dev/null 2>&1; then PKG=choco
  fi
}
detect_pkg

# Pick a python command (python3 preferred; Windows Git Bash often has `python`)
PY=""
for c in python3 python; do command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }; done

banner() {
  clear 2>/dev/null || true
  cat <<EOF
${B}${CYN}
  ╭───────────────────────────────────────────────╮
  │    R O C H A N A  ·  personal AI setup         │
  │   Claude CLI × Discord · plug-and-play         │
  ╰───────────────────────────────────────────────╯${R}
  ${DIM}OS: ${OS}   pkg: ${PKG:-none}   python: ${PY:-missing}${R}
EOF
}

# ── prerequisite checks ─────────────────────────────────────────────────────
py_ok() { [ -n "$PY" ] && "$PY" -c 'import sys; raise SystemExit(0 if sys.version_info>=(3,11) else 1)' 2>/dev/null; }

install_hint() { # install_hint <tool>
  case "$1:$PKG" in
    node:brew)   echo "brew install node";;
    node:apt)    echo "sudo apt-get install -y nodejs npm";;
    node:dnf)    echo "sudo dnf install -y nodejs";;
    node:pacman) echo "sudo pacman -S nodejs npm";;
    node:winget) echo "winget install OpenJS.NodeJS.LTS";;
    node:choco)  echo "choco install nodejs-lts -y";;
    node:*)      echo "https://nodejs.org/en/download";;
    python:brew) echo "brew install python@3.12";;
    python:apt)  echo "sudo apt-get install -y python3 python3-venv";;
    python:dnf)  echo "sudo dnf install -y python3";;
    python:pacman) echo "sudo pacman -S python";;
    python:winget) echo "winget install Python.Python.3.12";;
    python:choco)  echo "choco install python -y";;
    python:*)    echo "https://www.python.org/downloads (>= 3.11)";;
    git:*)       echo "https://git-scm.com/downloads";;
  esac
}

check_prereqs() {
  step "1. ตรวจสอบเครื่องมือที่จำเป็น (prerequisites)"
  local missing=0

  if command -v git >/dev/null 2>&1; then ok "git $(git --version | awk '{print $3}')"
  else err "git ไม่พบ → $(install_hint git)"; missing=1; fi

  if py_ok; then ok "python $("$PY" -c 'import platform;print(platform.python_version())') ($PY)"
  else err "python >= 3.11 ไม่พบ → $(install_hint python)"; missing=1; fi

  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    ok "node $(node --version) / npm $(npm --version)"
  else warn "node/npm ไม่พบ (ต้องใช้ติดตั้ง claude CLI) → $(install_hint node)"; missing=1; fi

  if command -v claude >/dev/null 2>&1; then ok "claude CLI $(claude --version 2>/dev/null | head -1)"
  else warn "claude CLI ไม่พบ — เดี๋ยว step 2 จะติดตั้งให้"; fi

  if command -v uv >/dev/null 2>&1; then ok "uv $(uv --version | awk '{print $2}')"
  else info "uv ไม่พบ (ไม่บังคับ — จะ fallback ไป pip/venv)"; fi

  echo
  if [ "$missing" -eq 0 ]; then ok "${B}พร้อมแล้ว${R}"; else warn "ติดตั้งตัวที่ขาดด้านบนก่อน แล้วรัน setup ใหม่"; fi
  return "$missing"
}

# ── install claude CLI + uv ─────────────────────────────────────────────────
install_tools() {
  step "2. ติดตั้ง claude CLI + uv"
  if command -v claude >/dev/null 2>&1; then ok "claude CLI มีอยู่แล้ว"
  else
    if command -v npm >/dev/null 2>&1; then
      if yesno "ติดตั้ง claude CLI ผ่าน npm เลยไหม?"; then
        npm i -g @anthropic-ai/claude-code && ok "ติดตั้ง claude แล้ว" || err "ติดตั้งไม่สำเร็จ — ลองเอง: npm i -g @anthropic-ai/claude-code"
      fi
    else err "ต้องมี npm ก่อน → $(install_hint node)"; fi
  fi
  if ! command -v uv >/dev/null 2>&1; then
    if yesno "ติดตั้ง uv (จัดการ dependency เร็ว) ไหม?"; then
      if [ "$OS" = windows ]; then "$PY" -m pip install --user uv
      else curl -LsSf https://astral.sh/uv/install.sh | sh; fi
      command -v uv >/dev/null 2>&1 && ok "ติดตั้ง uv แล้ว (อาจต้องเปิด terminal ใหม่ให้ PATH อัปเดต)" || warn "uv ยังไม่พร้อม — จะใช้ pip แทน"
    fi
  fi
}

# ── claude login ────────────────────────────────────────────────────────────
claude_login() {
  step "3. เข้าสู่ระบบ Claude (สมองของบอท)"
  if ! command -v claude >/dev/null 2>&1; then err "ยังไม่มี claude CLI — ทำ step 2 ก่อน"; return 1; fi
  info "บอทเรียก 'claude -p' โดยใช้การล็อกอินนี้ (ไม่ต้องมี API key)"
  if yesno "รัน 'claude login' ตอนนี้เลยไหม? (จะเปิด browser)"; then
    claude login || warn "ถ้าเปิด browser ไม่ได้ ให้รัน 'claude login' เองใน terminal"
  else info "ข้ามได้ — แต่ต้อง 'claude login' ก่อนบอทถึงจะคิดได้"; fi
}

# ── python deps ─────────────────────────────────────────────────────────────
install_deps() {
  step "4. ติดตั้ง Python dependencies"
  if command -v uv >/dev/null 2>&1; then
    uv sync && ok "uv sync สำเร็จ" || { err "uv sync ล้มเหลว"; return 1; }
  else
    "$PY" -m venv .venv || { err "สร้าง venv ไม่ได้"; return 1; }
    # shellcheck disable=SC1091
    if [ -f .venv/bin/activate ]; then . .venv/bin/activate; else . .venv/Scripts/activate; fi
    "$PY" -m pip install -q --upgrade pip && "$PY" -m pip install -q -e . \
      && ok "ติดตั้งผ่าน pip/venv สำเร็จ (source .venv/bin/activate เพื่อใช้งาน)" || { err "pip install ล้มเหลว"; return 1; }
  fi
}

# ── .env wizard ─────────────────────────────────────────────────────────────
configure_env() {
  step "5. ตั้งค่า Discord (.env)"
  [ -f .env ] || cp .env.example .env
  info "สร้าง Discord bot: https://discord.com/developers/applications"
  info "  • เปิด privileged intent: ${B}MESSAGE CONTENT${R}"
  info "  • เชิญบอทเข้า server, เปิด Developer Mode แล้ว Copy ID ของ 'ห้อง' (channel)"
  echo
  local tok cid
  printf "  วาง ${B}DISCORD_ROCHANA_TOKEN${R} (เว้นว่าง = คงค่าเดิม): "
  stty -echo 2>/dev/null; read -r tok; stty echo 2>/dev/null; echo
  cid="$(ask "  วาง BOSS_DISCORD_CHANNEL_ID (channel id ของห้องที่จะให้ ROCHANA โพสต์)")"

  # write via python for safe in-place update (no sed portability issues)
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
lines = setkv(lines, "DISCORD_ROCHANA_TOKEN", os.environ.get("TOK",""))
lines = setkv(lines, "BOSS_DISCORD_CHANNEL_ID", os.environ.get("CID",""))
p.write_text("\n".join(lines) + "\n")
PY
  chmod 600 .env 2>/dev/null || true
  ok ".env อัปเดตแล้ว (mode 600)"
  grep -q '^DISCORD_ROCHANA_TOKEN=.\+' .env && ok "มี token" || warn "ยังไม่มี token"
  grep -q '^BOSS_DISCORD_CHANNEL_ID=[0-9]\+' .env && ok "มี channel id" || warn "ยังไม่มี channel id (บอทจะบอกให้ตอนรัน)"
}

# ── Gmail / Calendar (optional) ─────────────────────────────────────────────
google_mcp() {
  step "6. Gmail + Calendar (ไม่บังคับ)"
  cat <<EOF
  ${DIM}ข่าวใช้ได้เลยไม่ต้องตั้งอะไร (WebSearch ในตัว claude).${R}
  Mail/Calendar ในตัว brief เป็น ${B}ออปชัน${R}:

  ${B}A) Claude connector (claude.ai)${R} — สะดวกตอนแชทเอง แต่ headless (บอท) มองไม่เห็น
     และ endpoint ของ Google ไม่รองรับ 'claude mcp login' (dynamic client registration)
  ${B}B) Google Workspace MCP (local, ผ่าน npx)${R} — ใช้ได้กับบอท ต้องมี Google OAuth client
     ของตัวเอง แล้วใส่ server ลง ${B}config/mcp.json${R} (ดู README §Gmail/Calendar)

  แนะนำ: เริ่มด้วย ${B}news-only${R} ก่อน แล้วค่อยเพิ่ม Mail/Calendar ทีหลังถ้าต้องการ.
EOF
  if command -v claude >/dev/null 2>&1; then
    echo; info "MCP ที่ claude CLI เห็นตอนนี้:"; claude mcp list 2>/dev/null | grep -vE 'Checking' | sed 's/^/    /' | head
  fi
}

# ── verify ──────────────────────────────────────────────────────────────────
verify() {
  step "7. ตรวจความพร้อม (verify)"
  local runpy=("$PY"); command -v uv >/dev/null 2>&1 && runpy=(uv run python)
  "${runpy[@]}" - <<'PY' && ok "โมดูลโหลด + plug ถูกค้นพบ" || err "verify ล้มเหลว — ดู error ด้านบน"
import os
os.environ.setdefault("DISCORD_ROCHANA_TOKEN","x"); os.environ.setdefault("BOSS_DISCORD_CHANNEL_ID","1")
from plughive.config import load_settings
from plughive.core.registry import PlugRegistry
s=load_settings()
r=PlugRegistry(s.root/"src"/"plughive"/"plugs", enabled=s.enabled_plugs, mcp_config_path=s.root/s.brain.mcp_config)
ms=r._discover_manifests(); assert ms, "no plugs found"
print("   plugs:", ", ".join(m.name for _,m in ms))
PY
  command -v claude >/dev/null 2>&1 && ok "claude CLI พร้อม" || warn "ยังไม่มี claude CLI"
  grep -q '^DISCORD_ROCHANA_TOKEN=.\+' .env 2>/dev/null && ok "มี Discord token" || warn "ยังไม่ตั้ง token (step 5)"
}

# ── run ─────────────────────────────────────────────────────────────────────
run_bot() {
  step "8. รัน ROCHANA"
  if ! grep -q '^DISCORD_ROCHANA_TOKEN=.\+' .env 2>/dev/null; then err "ยังไม่มี token — ทำ step 5 ก่อน"; return 1; fi
  info "กำลังสตาร์ต… (Ctrl+C เพื่อหยุด)"
  if command -v uv >/dev/null 2>&1; then exec uv run plughive
  elif [ -f .venv/bin/activate ]; then . .venv/bin/activate; exec plughive
  elif [ -f .venv/Scripts/activate ]; then . .venv/Scripts/activate; exec plughive
  else exec "$PY" -m plughive; fi
}

full_setup() {
  banner
  check_prereqs || { pause; return; }
  install_tools
  claude_login
  install_deps || { pause; return; }
  configure_env
  google_mcp
  verify
  echo; ok "${B}เสร็จแล้ว!${R} เลือกเมนู 8 เพื่อรัน หรือ: ${B}uv run plughive${R}"
  pause
}

show_help() {
  banner
  cat <<EOF
${B}ROCHANA — ผู้ช่วยส่วนตัว Claude CLI × Discord${R}

  ทำงานยังไง: 1 process เดียว (bot + scheduler + sqlite). สมองคือ 'claude -p'.
  ฟีเจอร์: แชทตอบเมื่อถูก @mention + สรุป brief ทุก 2 ชม. (mail/calendar/ข่าว)
           ที่ตัดสินใจเองว่าจะรายงานอะไร.

  ${B}ลำดับที่แนะนำ${R} (เมนู 1 ทำให้ทั้งหมด):
    1) ตรวจ prerequisites → 2) ติดตั้ง claude/uv → 3) claude login
    → 4) ติดตั้ง deps → 5) ใส่ Discord token/channel → 6) (ออปชัน) mail/calendar
    → 7) verify → 8) run

  ${B}Manual steps ที่คุณต้องทำเอง${R} (script จะพาไปทีละอัน):
    • claude login (เปิด browser)
    • สร้าง Discord bot + เปิด MESSAGE CONTENT intent + copy token/channel id

  ${B}ไฟล์สำคัญ${R}:
    .env                 = secret (token, channel id)
    config/plughive.yaml  = พฤติกรรม (รอบ brief, quiet hours, โมเดล, plugs)
    personas/rochana.md  = น้ำเสียงของ 'เก้า'

  ${B}Windows${R}: รันไฟล์นี้ใน Git Bash (มากับ Git for Windows) หรือ WSL.
  ${B}ธง${R}: ./setup.sh --all (ทำครบ)  ·  --help  ·  NO_COLOR=1 (ปิดสี)
EOF
  pause
}

menu() {
  while true; do
    banner
    cat <<EOF

  ${B}เมนู${R}  ${DIM}(พิมพ์เลขแล้ว Enter)${R}
    ${GRN}1)${R} ${B}ติดตั้งทั้งหมด (แนะนำ)${R}
    2) ตรวจ prerequisites
    3) ติดตั้ง claude CLI + uv
    4) เข้าสู่ระบบ claude (claude login)
    5) ติดตั้ง Python dependencies
    6) ตั้งค่า Discord (.env)
    7) Gmail/Calendar (ออปชัน)
    8) ตรวจความพร้อม (verify)
    ${CYN}9)${R} ${B}รัน ROCHANA${R}
    h) ช่วยเหลือ / อธิบาย
    0) ออก
EOF
    case "$(ask "  เลือก" )" in
      1) full_setup;;
      2) banner; check_prereqs; pause;;
      3) banner; install_tools; pause;;
      4) banner; claude_login; pause;;
      5) banner; install_deps; pause;;
      6) banner; configure_env; pause;;
      7) banner; google_mcp; pause;;
      8) banner; verify; pause;;
      9) run_bot;;
      h|H|help) show_help;;
      0|q|exit) echo; ok "บาย 👋"; exit 0;;
      *) warn "ไม่รู้จักตัวเลือกนี้"; sleep 1;;
    esac
  done
}

case "${1:-}" in
  --all|-a)   full_setup;;
  --help|-h)  show_help;;
  "" )        menu;;
  * )         err "ไม่รู้จักธง '$1' — ลอง --help"; exit 1;;
esac
