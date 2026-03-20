# ========================================================
#   AFS AI Hub Windows 循序整合部署腳本 (deploy-all.ps1)
# ========================================================

# 1. 權限檢查與自動提升
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "正在請求管理員權限以執行整合部署..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$SCRIPT_DIR = $PSScriptRoot
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
# ==========================================
# 建立 Logs 資料夾與啟動紀錄 (Transcript)
# ==========================================
$LOG_DIR = Join-Path $PROJECT_ROOT "logs"
if (-not (Test-Path $LOG_DIR)) {
    New-Item -ItemType Directory -Force -Path $LOG_DIR | Out-Null
}

# 產生日誌檔名 (例如: deploy_20260309_115600.log)
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LOG_FILE = Join-Path $LOG_DIR "deploy_$TimeStamp.log"

# 開始側錄整個 PowerShell 視窗的輸出
Start-Transcript -Path $LOG_FILE -Append -NoClobber

# ==========================================
# 2. 獲取共用參數 (VM_IP)
# ==========================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  開始 AFS AI Hub 整合部署流程" -ForegroundColor Cyan
Write-Host "  日誌將儲存於: $LOG_FILE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ==========================================
# 2. 獲取共用參數 (VM_IP 與 GPU 環境)
# ==========================================

# 呼叫獨立腳本，並將它 Write-Output 回傳的值存入 $VM_IP
$VM_IP = & "$SCRIPT_DIR\get-ip.ps1"

if ([string]::IsNullOrWhiteSpace($VM_IP)) {
    Write-Host "錯誤：IP 位址獲取失敗，部署終止。" -ForegroundColor Red
    Stop-Transcript
    exit 1
}
Write-Host ""
Write-Host "請選擇本機的 GPU 環境 (將決定下載的 llama.cpp 版本與 API Relay 參數):" -ForegroundColor Cyan
Write-Host "  [1] AMD (HIP/Radeon)"
#Write-Host "  [2] NVIDIA (CUDA)"
#Write-Host "  [3] 無 GPU (僅使用 CPU)"
$GpuChoice = Read-Host "請輸入選項 (1，預設為 1)"

$GPU_PROVIDER = switch ($GpuChoice) {
    "1" { "amd" }
   # "2" { "nvidia" }
   # "3" { "cpu" }
    default { "amd" } # 防呆，預設給 amd
}
Write-Host ">> 已設定 GPU 類型為: $GPU_PROVIDER" -ForegroundColor Green

# =========================================================================
# 💡 [修正重點]：在這裡就提早將動態取得的設定寫入 config.json！
# 這樣後續所有步驟 (Postgres, Keycloak, ApiRelay) 讀到的都會是最新的正確資訊。
# =========================================================================
$JDK_PATH = Join-Path $PROJECT_ROOT "runtime\jdk-17"
$ConfigPath = Join-Path $PROJECT_ROOT "config.json"

if (Test-Path $ConfigPath) {
    # 讀取現有的預設設定檔
    $ConfigData = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    
    # 覆蓋安裝時動態獲取的資訊
    $ConfigData.Global.VM_IP        = $VM_IP
    $ConfigData.Global.GPU_PROVIDER = $GPU_PROVIDER
    $ConfigData.Global.JDK_PATH     = $JDK_PATH

    # 寫回檔案 (Depth 設為 5 確保巢狀結構不會被截斷)
    $ConfigData | ConvertTo-Json -Depth 5 | Set-Content -Path $ConfigPath -Encoding UTF8
    Write-Host ">> 初始化設定已成功合併並儲存至 $ConfigPath" -ForegroundColor Green
} else {
    Write-Host "錯誤: 找不到預設的 config.json，請確認安裝包結構完整！" -ForegroundColor Red
    Stop-Transcript
    exit 1
}

function Wait-ForNextStep {
    param([string]$NextStepName)
    Write-Host ""
    Write-Host ">> 當前階段已完成。" -ForegroundColor Green
  # Read-Host ">> 請按 [Enter] 鍵繼續部署下一個元件: $NextStepName (或按 Ctrl+C 中斷)"
    Write-Host ""
}

try {
    # 階段 1: 部署 Java JDK (綠色版)
    Write-Host "[1/7] 開始部署 Java JDK..." -ForegroundColor Yellow
    & "$SCRIPT_DIR\java-jdk.ps1"
    Wait-ForNextStep "OpenSSL"

    # 階段 2: 部署 OpenSSL
    Write-Host "[2/7] 開始部署 OpenSSL..." -ForegroundColor Yellow
    & "$SCRIPT_DIR\deploy-openSSL.ps1"
    Wait-ForNextStep "憑證生成 (Certs)"

    # 階段 3: 憑證生成 (Certs)
    Write-Host "[3/7] 開始生成共用憑證..." -ForegroundColor Yellow
    & "$SCRIPT_DIR\gen-all-cert.ps1" -VM_IP $VM_IP
    Wait-ForNextStep "PostgreSQL"

    # 階段 4: 部署 PostgreSQL
    Write-Host "[4/7] 開始部署 PostgreSQL..." -ForegroundColor Yellow
    & "$SCRIPT_DIR\deploy-postgres.ps1"
    Wait-ForNextStep "Keycloak"

# 階段 5: 部署與初始化 Keycloak
    Write-Host "[5/7] 開始部署 Keycloak..." -ForegroundColor Yellow
    & "$SCRIPT_DIR\deploy-keycloak.ps1" -VM_IP $VM_IP  # 這裡加上傳入 -VM_IP
# ========== 複製 Keycloak 主題 ==========
    Write-Host "準備配置 Keycloak 主題..." -ForegroundColor Cyan
    
    # 預設：假設是透過 EXE 安裝後的路徑 (與 apps, scripts 同級)
    $ThemeSourceDir = Join-Path $PROJECT_ROOT "keycloak_theme\aiportal-theme"
    
    # 防呆：如果預設路徑找不到，代表是在開發機上直接測試，那就往上找一層
    if (-not (Test-Path $ThemeSourceDir)) {
        $ThemeSourceDir = Join-Path (Split-Path $PROJECT_ROOT -Parent) "keycloak_theme\aiportal-theme"
    }

    $ThemeDestDir = Join-Path $PROJECT_ROOT "runtime\keycloak-26.2.0\themes\aiportal-theme"
    
    if (Test-Path $ThemeSourceDir) {
        Write-Host "  -> 找到主題來源: $ThemeSourceDir" -ForegroundColor Gray
        Write-Host "  -> 正在複製 aiportal-theme 到 Keycloak..." -ForegroundColor Cyan
        if (-not (Test-Path $ThemeDestDir)) { New-Item -ItemType Directory -Path $ThemeDestDir -Force | Out-Null }
        Copy-Item -Path "$ThemeSourceDir\*" -Destination $ThemeDestDir -Recurse -Force
        Write-Host "  -> 主題複製完成！" -ForegroundColor Green
    } else {
        Write-Host "  -> 警告: 找不到主題來源，將使用預設主題。" -ForegroundColor Yellow
    }
    # ===============================================
    Write-Host "啟動 Keycloak 服務 (將於背景執行)..." -ForegroundColor Cyan
    $KeycloakVersion = "26.2.0"
    $KcBatPath = "$PROJECT_ROOT\runtime\keycloak-$KeycloakVersion\bin\kc.bat"
    
    if (Test-Path $KcBatPath) {
        # 產生獨立的啟動腳本以避免 PowerShell 與 CMD 之間的引號與轉義問題
        $StartupBat = Join-Path $LOG_DIR "start-keycloak-$TimeStamp.bat"
        $KcLogFile = Join-Path $LOG_DIR "keycloak_start_$TimeStamp.log"
        
$BatContent = @"
@echo off
echo Starting Keycloak Build... > "$KcLogFile"
call "$KcBatPath" build >> "$KcLogFile" 2>&1
set KEYCLOAK_ADMIN=admin
set KEYCLOAK_ADMIN_PASSWORD=admin

echo Starting Keycloak Optimized... >> "$KcLogFile"
call "$KcBatPath" start --optimized --hostname-strict=false >> "$KcLogFile" 2>&1
"@
        Set-Content -Path $StartupBat -Value $BatContent -Encoding Default
        
        # 執行啟動腳本
        Start-Process cmd.exe "/c `"$StartupBat`"" -WindowStyle Hidden
    } else {
        Write-Host "警告: 找不到 kc.bat 啟動檔，請確認解壓縮路徑。" -ForegroundColor Red
    }

    Write-Host "等待 Keycloak 啟動並進行初始化設定..." -ForegroundColor Cyan
    & "$SCRIPT_DIR\init-keycloak.ps1" -VM_IP $VM_IP
    Wait-ForNextStep "Llama.cpp"

    # 階段 6: 部署 Llama.cpp
    Write-Host "[6/8] 開始部署 Llama.cpp ($GPU_PROVIDER 版)..." -ForegroundColor Yellow
    & "$SCRIPT_DIR\deploy-llama.ps1" -GPU_PROVIDER $GPU_PROVIDER
    Wait-ForNextStep "API Relay"

   # 階段 7: 啟動 API Relay (背景執行，不需傳參數，直接吃 config.json)
    Write-Host "[7/8] 開始在背景啟動 API Relay..." -ForegroundColor Yellow
    $RelayCmd = "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$SCRIPT_DIR\start-api-relay.ps1`""
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $RelayCmd } | Out-Null
    Wait-ForNextStep "AI Portal"

    # 階段 8: 啟動 AI Portal (背景執行，不需傳參數，直接吃 config.json)
    Write-Host "[8/8] 開始在背景啟動 AI Portal..." -ForegroundColor Yellow
    $PortalCmd = "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$SCRIPT_DIR\start-aiportal.ps1`""
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $PortalCmd } | Out-Null
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  所有元件啟動指令已發送完畢！" -ForegroundColor Green
    Write-Host "  完整日誌已儲存於: $LOG_FILE" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green

} catch {
    Write-Error "整合部署流程發生例外中斷: $_"
    Read-Host "按 Enter 鍵結束"
} finally {
    # 無論成功或失敗，最後都停止側錄
    Stop-Transcript
}
# 👇 強制關閉當前的 PowerShell 視窗
exit