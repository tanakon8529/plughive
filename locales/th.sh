# ภาษาไทยสำหรับ setup.sh
# วิธีเพิ่มภาษา: copy ไฟล์นี้เป็น locales/<code>.sh แล้วแปลค่า ตั้ง LANG_NAME
# เมนู setup จะเห็นภาษาใหม่เองอัตโนมัติ
LANG_NAME="ไทย"

M_subtitle="ตั้งค่าผู้ช่วยส่วนตัว"
M_tagline="Claude CLI × Discord · plug-and-play"

M_menu_header="เมนู (พิมพ์เลขแล้ว Enter)"
M_m_full="ติดตั้งทั้งหมด (แนะนำ)"
M_m_prereq="ตรวจ prerequisites"
M_m_tools="ติดตั้ง claude CLI + uv"
M_m_login="เข้าสู่ระบบ claude"
M_m_deps="ติดตั้ง Python dependencies"
M_m_env="ตั้งค่า Discord (.env)"
M_m_google="Gmail/Calendar (ออปชัน)"
M_m_verify="ตรวจความพร้อม"
M_m_run="รัน plughive"
M_m_lang="ภาษา"
M_m_help="ช่วยเหลือ"
M_m_exit="ออก"
M_choose="เลือก"
M_press_enter="กด Enter เพื่อไปต่อ…"
M_unknown="ไม่รู้จักตัวเลือกนี้"
M_bye="บาย 👋"
M_ready="พร้อมแล้ว"
M_install_missing="ติดตั้งตัวที่ขาดด้านบนก่อน แล้วรัน setup ใหม่"

M_step_prereq="1. ตรวจสอบเครื่องมือที่จำเป็น (prerequisites)"
M_step_tools="2. ติดตั้ง claude CLI + uv"
M_step_login="3. เข้าสู่ระบบ Claude (สมองของบอท)"
M_step_deps="4. ติดตั้ง Python dependencies"
M_step_env="5. ตั้งค่า Discord (.env)"
M_step_google="6. Gmail + Calendar (ไม่บังคับ)"
M_step_verify="7. ตรวจความพร้อม (verify)"
M_step_run="8. รัน plughive"
M_step_lang="ภาษา"

M_git_missing="git ไม่พบ →"
M_py_missing="python >= 3.11 ไม่พบ →"
M_node_missing="node/npm ไม่พบ (ต้องใช้ติดตั้ง claude CLI) →"
M_claude_missing_later="claude CLI ไม่พบ — เดี๋ยว step 2 จะติดตั้งให้"
M_uv_optional="uv ไม่พบ (ไม่บังคับ — จะ fallback ไป pip/venv)"

M_claude_present="claude CLI มีอยู่แล้ว"
M_ask_install_claude="ติดตั้ง claude CLI ผ่าน npm เลยไหม?"
M_claude_installed="ติดตั้ง claude แล้ว"
M_claude_install_fail="ติดตั้งไม่สำเร็จ — ลองเอง: npm i -g @anthropic-ai/claude-code"
M_need_npm="ต้องมี npm ก่อน →"
M_ask_install_uv="ติดตั้ง uv (จัดการ dependency เร็ว) ไหม?"
M_uv_installed="ติดตั้ง uv แล้ว (อาจต้องเปิด terminal ใหม่ให้ PATH อัปเดต)"
M_uv_not_ready="uv ยังไม่พร้อม — จะใช้ pip แทน"

M_login_info="บอทเรียก 'claude -p' โดยใช้การล็อกอินนี้ (ไม่ต้องมี API key)"
M_ask_login_now="รัน 'claude login' ตอนนี้เลยไหม? (จะเปิด browser)"
M_login_browser_hint="ถ้าเปิด browser ไม่ได้ ให้รัน 'claude login' เองใน terminal"
M_login_skip="ข้ามได้ — แต่ต้อง 'claude login' ก่อนบอทถึงจะคิดได้"
M_login_need_cli="ยังไม่มี claude CLI — ทำ step 2 ก่อน"

M_uv_sync_ok="uv sync สำเร็จ"
M_uv_sync_fail="uv sync ล้มเหลว"
M_venv_fail="สร้าง venv ไม่ได้"
M_pip_ok="ติดตั้งผ่าน pip/venv สำเร็จ (source .venv/bin/activate เพื่อใช้งาน)"
M_pip_fail="pip install ล้มเหลว"

M_env_bot_info="สร้าง Discord bot: https://discord.com/developers/applications"
M_env_intent="• เปิด privileged intent: MESSAGE CONTENT"
M_env_copyid="• เชิญบอทเข้า server, เปิด Developer Mode แล้ว Copy ID ของ 'ห้อง' (channel)"
M_env_paste_token="วาง DISCORD_BOT_TOKEN (เว้นว่าง = คงค่าเดิม): "
M_env_paste_channel="วาง DISCORD_CHANNEL_ID (channel id ของห้องที่จะให้ plughive โพสต์)"
M_env_updated=".env อัปเดตแล้ว (mode 600)"
M_env_has_token="มี token"
M_env_no_token="ยังไม่มี token"
M_env_has_channel="มี channel id"
M_env_no_channel="ยังไม่มี channel id (บอทจะบอกให้ตอนรัน)"

M_verify_ok="โมดูลโหลด + plug ถูกค้นพบ"
M_verify_fail="verify ล้มเหลว — ดู error ด้านบน"
M_claude_ready="claude CLI พร้อม"
M_claude_not="ยังไม่มี claude CLI"
M_token_set="มี Discord token"
M_token_not="ยังไม่ตั้ง token (step 5)"

M_run_no_token="ยังไม่มี token — ทำ step 5 ก่อน"
M_run_starting="กำลังสตาร์ต… (Ctrl+C เพื่อหยุด)"
M_done="เสร็จแล้ว! เลือกเมนู รัน หรือ: uv run plughive"

M_google_text="ค่าเริ่มต้นคือ ข่าว + แชท (ไม่ต้องตั้งอะไร). Mail/Calendar เป็นออปชัน: บอทเบื้องหลัง
  ใช้ connector ของ Claude ไม่ได้ (headless) เลยต้องมี Google credential ของตัวเองผ่าน
  local MCP server (npx, ไม่มี Docker). เมนูนี้จะตั้งให้ — คุณแค่สร้าง OAuth client ใน Google
  แล้วกด Allow ครั้งเดียว"
M_g_enable_q="เปิด Gmail + Calendar เลยไหม?"
M_g_skip="ข้ามไปก่อน — ใช้ ข่าว + แชท. กลับมาเปิดทีหลังจากเมนูนี้ได้"
M_g_need_claude="ติดตั้ง claude CLI ก่อน (เมนู 3)"
M_g_enabled_file="เปิด config/mcp.local.json แล้ว"
M_g_cloud="ขั้น A — สร้าง Google OAuth client (ในเบราว์เซอร์):
    1) เปิด Gmail + Calendar API (คลิกเดียว):
       https://console.cloud.google.com/flows/enableapi?apiid=gmail.googleapis.com,calendar-json.googleapis.com
    2) APIs & Services -> Credentials -> Create Credentials -> OAuth client ID
       -> Application type: Desktop app -> copy Client ID กับ Client secret
    3) OAuth consent screen: User type External; เพิ่ม scope gmail.modify,
       gmail.labels, calendar; เพิ่ม Google account ตัวเองใน Test users"
M_g_wait_creds="พอได้ Client ID + Secret แล้ว กด Enter เพื่อวาง"
M_g_paste_id="วาง GOOGLE_CLIENT_ID"
M_g_paste_secret="วาง GOOGLE_CLIENT_SECRET (ซ่อน): "
M_g_env_saved="บันทึก credentials ลง .env แล้ว"
M_g_need_creds="ยังไม่มี Client ID / Secret — กลับมาเมนูนี้ตอนได้แล้ว"
M_g_authorize_q="authorize เลยไหม? (เปิด browser ให้กดอนุญาต)"
M_g_authorizing="กำลัง authorize — กด Allow ในเบราว์เซอร์ที่เปิดขึ้น…"
M_g_authorized="authorize สำเร็จ — เก็บ token แล้ว; brief จะมี mail + calendar"
M_g_authorize_later="ข้าม authorize ไว้ก่อน รันทีหลังได้:"
M_g_done="เปิด Gmail + Calendar เรียบร้อย"

M_help_text="plughive — ผู้ช่วยส่วนตัวแบบ plug-and-play (Claude CLI × Discord)

  ทำงานยังไง: 1 process (bot + scheduler + sqlite) สมองคือ 'claude -p'
  ฟีเจอร์: ตอบเมื่อถูก @mention + สรุป brief ทุก 2 ชม. (mail/calendar/ข่าว)
           ที่ตัดสินใจเองว่าจะรายงานอะไร

  ลำดับที่แนะนำ (เมนู ติดตั้งทั้งหมด ทำให้ครบ):
    prereqs → ติดตั้ง claude/uv → claude login → deps → Discord token/channel
    → (ออปชัน) mail/calendar → verify → run

  Manual steps ที่ต้องทำเอง (script จะพาไปทีละอัน):
    • claude login (เปิด browser)
    • สร้าง Discord bot + เปิด MESSAGE CONTENT + copy token/channel id

  ไฟล์สำคัญ:
    .env                    = secret (token, channel id)
    config/plughive.yaml    = พฤติกรรม (รอบ brief, quiet hours, โมเดล, plugs)
    personas/rochana.md     = น้ำเสียงของ ROCHANA (เก้า)
    locales/<code>.sh       = คำแปลของ setup (เพิ่มไฟล์ = เพิ่มภาษา)

  Windows: รันใน Git Bash (มากับ Git for Windows) หรือ WSL
  ธง: ./setup.sh --all · --help · NO_COLOR=1 · PLUGHIVE_LANG=th"
