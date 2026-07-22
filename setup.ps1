# ROCHANA setup for Windows (PowerShell).  Run:  ./setup.ps1
# macOS/Linux/WSL/Git-Bash users: use ./setup.sh instead.
$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Ok($m){ Write-Host "  [ok] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "  [!]  $m" -ForegroundColor Yellow }
function Err($m){ Write-Host "  [x]  $m" -ForegroundColor Red }
function Info($m){ Write-Host "  [i]  $m" -ForegroundColor Cyan }
function Step($m){ Write-Host "`n> $m" -ForegroundColor Blue }
function Has($c){ [bool](Get-Command $c -ErrorAction SilentlyContinue) }
function Py(){ if(Has python){"python"}elseif(Has python3){"python3"}else{""} }

function Banner {
  Clear-Host
  Write-Host "  +-----------------------------------------------+" -ForegroundColor Cyan
  Write-Host "  |    R O C H A N A  -  personal AI setup        |" -ForegroundColor Cyan
  Write-Host "  |   Claude CLI x Discord - plug-and-play        |" -ForegroundColor Cyan
  Write-Host "  +-----------------------------------------------+" -ForegroundColor Cyan
}

function Check-Prereqs {
  Step "1. Prerequisites"
  $ok = $true
  if(Has git){ Ok "git $((git --version).Split(' ')[2])" } else { Err "git missing -> https://git-scm.com/downloads"; $ok=$false }
  $p = Py
  if($p){
    $v = & $p -c "import sys;print('.'.join(map(str,sys.version_info[:3])))"
    $good = & $p -c "import sys;print(1 if sys.version_info>=(3,11) else 0)"
    if($good -eq "1"){ Ok "python $v ($p)" } else { Err "python >=3.11 needed (have $v) -> winget install Python.Python.3.12"; $ok=$false }
  } else { Err "python missing -> winget install Python.Python.3.12"; $ok=$false }
  if((Has node) -and (Has npm)){ Ok "node $(node --version) / npm $(npm --version)" } else { Warn "node/npm missing -> winget install OpenJS.NodeJS.LTS"; $ok=$false }
  if(Has claude){ Ok "claude CLI present" } else { Warn "claude CLI missing - step 2 installs it" }
  if(Has uv){ Ok "uv present" } else { Info "uv missing (optional; pip fallback)" }
  if($ok){ Ok "Ready" } else { Warn "Install the missing tools above, then re-run." }
  return $ok
}

function Install-Tools {
  Step "2. Install claude CLI + uv"
  if(Has claude){ Ok "claude present" }
  elseif(Has npm){ npm i -g @anthropic-ai/claude-code; Ok "claude installed" }
  else { Err "need npm first" }
  if(-not (Has uv)){ & (Py) -m pip install --user uv; if(Has uv){ Ok "uv installed" } else { Warn "uv not ready; pip will be used" } }
}

function Claude-Login {
  Step "3. Claude login (the brain)"
  if(-not (Has claude)){ Err "install claude first (step 2)"; return }
  $a = Read-Host "Run 'claude login' now? opens a browser (Y/n)"
  if($a -eq "" -or $a -match "^[Yy]"){ claude login }
}

function Install-Deps {
  Step "4. Python dependencies"
  if(Has uv){ uv sync; Ok "uv sync done" }
  else {
    & (Py) -m venv .venv
    & ".\.venv\Scripts\python.exe" -m pip install -q --upgrade pip
    & ".\.venv\Scripts\python.exe" -m pip install -q -e .
    Ok "pip/venv done (.\.venv\Scripts\Activate.ps1 to use)"
  }
}

function Configure-Env {
  Step "5. Discord (.env)"
  if(-not (Test-Path .env)){ Copy-Item .env.example .env }
  Info "Bot: https://discord.com/developers/applications  (enable MESSAGE CONTENT intent)"
  Info "Copy the target channel id (Developer Mode -> right-click channel -> Copy ID)"
  $tok = Read-Host "DISCORD_ROCHANA_TOKEN (blank = keep)" -AsSecureString
  $tokPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($tok))
  $cid = Read-Host "BOSS_DISCORD_CHANNEL_ID"
  $lines = Get-Content .env
  function SetKV($lines,$k,$v){ if(-not $v){return $lines}; $seen=$false
    $out = $lines | ForEach-Object { if($_ -match "^\s*#?\s*$k="){ $seen=$true; "$k=$v" } else { $_ } }
    if(-not $seen){ $out += "$k=$v" }; return $out }
  $lines = SetKV $lines "DISCORD_ROCHANA_TOKEN" $tokPlain
  $lines = SetKV $lines "BOSS_DISCORD_CHANNEL_ID" $cid
  Set-Content .env $lines
  Ok ".env updated"
}

function Verify {
  Step "6. Verify"
  $env:DISCORD_ROCHANA_TOKEN = "x"; $env:BOSS_DISCORD_CHANNEL_ID = "1"
  $code = @"
from plugd.config import load_settings
from plugd.core.registry import PlugRegistry
s=load_settings()
r=PlugRegistry(s.root/'src'/'plugd'/'plugs', enabled=s.enabled_plugs, mcp_config_path=s.root/s.brain.mcp_config)
ms=r._discover_manifests(); assert ms; print('plugs:', ', '.join(m.name for _,m in ms))
"@
  if(Has uv){ $code | uv run python - } else { $code | & (Py) - }
  if($LASTEXITCODE -eq 0){ Ok "modules load + plug discovered" } else { Err "verify failed" }
}

function Run-Bot {
  Step "7. Run ROCHANA"
  if(Has uv){ uv run plugd }
  elseif(Test-Path .\.venv\Scripts\plugd.exe){ .\.venv\Scripts\plugd.exe }
  else { & (Py) -m plugd }
}

function Full { Banner; if(Check-Prereqs){ Install-Tools; Claude-Login; Install-Deps; Configure-Env; Verify; Ok "Done! menu 7 to run, or: uv run plugd" } }

function Menu {
  while($true){
    Banner
    Write-Host "`n  Menu (type number)`n"
    Write-Host "    1) Full setup (recommended)" -ForegroundColor Green
    Write-Host "    2) Check prerequisites"
    Write-Host "    3) Install claude CLI + uv"
    Write-Host "    4) claude login"
    Write-Host "    5) Python dependencies"
    Write-Host "    6) Configure Discord (.env)"
    Write-Host "    7) Run ROCHANA" -ForegroundColor Cyan
    Write-Host "    0) Exit"
    switch(Read-Host "`n  choose"){
      "1"{Full; Read-Host "Enter"}
      "2"{Banner;[void](Check-Prereqs);Read-Host "Enter"}
      "3"{Banner;Install-Tools;Read-Host "Enter"}
      "4"{Banner;Claude-Login;Read-Host "Enter"}
      "5"{Banner;Install-Deps;Read-Host "Enter"}
      "6"{Banner;Configure-Env;Read-Host "Enter"}
      "7"{Run-Bot}
      "0"{Ok "bye"; return}
      default{Warn "unknown option"}
    }
  }
}

if($args -contains "--all"){ Full } elseif($args -contains "--help"){ Get-Content $PSCommandPath -TotalCount 3 } else { Menu }
