# 1. 權限檢查與自動提升 (UAC)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "正在請求管理員權限以更新系統設定..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$SCRIPT_DIR = $PSScriptRoot
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$LOG_DIR = Join-Path $PROJECT_ROOT "logs"
# ==========================================
# [新增] 讀取設定檔
# ==========================================
$ConfigPath = Join-Path $PROJECT_ROOT "config.json"
if (-not (Test-Path $ConfigPath)) {
    Write-Host "錯誤: 找不到 config.json，請先執行 deploy-all.ps1 進行部署！" -ForegroundColor Red
    exit 1
}

$Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
$VM_IP = $Config.Global.VM_IP
$GPU_PROVIDER = $Config.Global.GPU_PROVIDER
$JDK_PATH = $Config.Global.JDK_PATH

Write-Host ">> 載入設定: IP=$VM_IP, GPU=$GPU_PROVIDER" -ForegroundColor Gray

# --- 核心修正：手動指定並注入 Java 路徑 ---
if (Test-Path $JDK_PATH) {
    $env:JAVA_HOME = $JDK_PATH
    $env:Path = "$(Join-Path $JDK_PATH "bin");" + $env:Path
    Write-Host "已載入運行環境: JDK 17 ($JDK_PATH)" -ForegroundColor Gray
}

Write-Host "正在背景啟動 AFS AI Hub 所有服務..." -ForegroundColor Cyan

# 1. 啟動 Postgres (它內部會自己處理路徑)
Write-Host "[1/4]啟動 Postgres 服務..." -ForegroundColor Cyan
& "$SCRIPT_DIR\deploy-postgres.ps1" 

Write-Host "[2/4]啟動 Keycloak 服務..." -ForegroundColor Cyan
$KeycloakVersion = "26.2.0"
$KcBatPath = "$PROJECT_ROOT\runtime\keycloak-$KeycloakVersion\bin\kc.bat"

if (Test-Path $KcBatPath) {
    # 不需要 build，也不需要設定帳號密碼，直接 start --optimized
    $StartupBat = Join-Path $LOG_DIR "start-keycloak-$TimeStamp.bat"
    $KcLogFile = Join-Path $LOG_DIR "keycloak_start_$TimeStamp.log"
    
$BatContent = @"
@echo off
echo Starting Keycloak Optimized... > "$KcLogFile"
call "$KcBatPath" start --optimized --hostname-strict=false >> "$KcLogFile" 2>&1
"@
    Set-Content -Path $StartupBat -Value $BatContent -Encoding Default
    
    # 執行啟動腳本 (隱藏視窗)
    Start-Process cmd.exe "/c `"$StartupBat`"" -WindowStyle Hidden
    Write-Host "  -> Keycloak 已於背景啟動。" -ForegroundColor Green
} else {
    Write-Host "警告: 找不到 kc.bat 啟動檔。" -ForegroundColor Red
}

# 階段 7: 啟動 API Relay (背景執行，記得傳入 GPU 參數與 JDK_PATH)
Write-Host "[3/4] 開始在背景啟動 API Relay..." -ForegroundColor Yellow
$RelayCmd = "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$SCRIPT_DIR\start-api-relay.ps1`" -VM_IP $VM_IP -GPU_PROVIDER $GPU_PROVIDER -JDK_PATH `"$JDK_PATH`""
Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $RelayCmd } | Out-Null

# 階段 8: 啟動 AI Portal (背景執行，傳入 JDK_PATH)
Write-Host "[4/4] 開始在背景啟動 AI Portal..." -ForegroundColor Yellow
$PortalCmd = "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$SCRIPT_DIR\start-aiportal.ps1`" -VM_IP $VM_IP -JDK_PATH `"$JDK_PATH`""
Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $PortalCmd } | Out-Null


Write-Host "所有服務啟動指令已發送！" -ForegroundColor Green