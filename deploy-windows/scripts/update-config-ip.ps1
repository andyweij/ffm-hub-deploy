# 1. 權限檢查與自動提升 (UAC)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "正在請求管理員權限以更新系統設定..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$SCRIPT_DIR = $PSScriptRoot
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$ConfigPath = Join-Path $PROJECT_ROOT "config.json"

if (-not (Test-Path $ConfigPath)) {
    Write-Host "錯誤: 找不到 config.json，請先執行部署。" -ForegroundColor Red
    exit 1
}

# 讀取現有設定
$Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
$OldIP = $Config.Global.VM_IP

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  更新 AFS AI Hub 環境設定" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 提示輸入新值 (若直接按 Enter 則保留原值)
$NewIP = Read-Host "請輸入新 IP 位址 [目前: $($Config.Global.VM_IP)]"
if ([string]::IsNullOrWhiteSpace($NewIP)) { $NewIP = $Config.Global.VM_IP }

$NewGPU = Read-Host "請輸入新 GPU (amd/nvidia/cpu) [目前: $($Config.Global.GPU_PROVIDER)]"
if ([string]::IsNullOrWhiteSpace($NewGPU)) { $NewGPU = $Config.Global.GPU_PROVIDER }

$NewJDK = Read-Host "請輸入新 JDK 路徑 [目前: $($Config.Global.JDK_PATH)]"
if ([string]::IsNullOrWhiteSpace($NewJDK)) { $NewJDK = $Config.Global.JDK_PATH }

# 更新設定檔
$Config.Global.VM_IP = $NewIP
$Config.Global.GPU_PROVIDER = $NewGPU
$Config.Global.JDK_PATH = $NewJDK
$Config | ConvertTo-Json -Depth 2 | Set-Content -Path $ConfigPath -Encoding UTF8
Write-Host ">> config.json 已更新！" -ForegroundColor Green

# 判斷是否需要重新生成憑證與更新 Keycloak (只有 IP 改變時才需要)
if ($OldIP -ne $NewIP) {
    Write-Host ">> 偵測到 IP 已更改，正在重新生成憑證並更新 Keycloak..." -ForegroundColor Yellow
    
    # 1. 更新憑證
    & "$SCRIPT_DIR\gen-all-cert.ps1" -VM_IP $NewIP

    # 2. 更新 Keycloak 內的 Redirect URI
    & "$SCRIPT_DIR\init-keycloak.ps1" -VM_IP $NewIP
    
    Write-Host ">> IP 相關配置已更新完畢！" -ForegroundColor Green
}

Write-Host ">> 設定更新完成，正在為您重新啟動服務以套用新設定..." -ForegroundColor Yellow

# 1. 停止所有服務
Write-Host ">> 執行 stop-all.ps1..." -ForegroundColor Cyan
& "$SCRIPT_DIR\stop-all.ps1"

# 2. 啟動所有服務
Write-Host ">> 執行 start-all.ps1..." -ForegroundColor Cyan
& "$SCRIPT_DIR\start-all.ps1"

Write-Host "========================================" -ForegroundColor Green
Write-Host "  設定已成功套用，系統已重新啟動完畢！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# 讓視窗停留 5 秒鐘，讓使用者能看清楚執行結果再自動關閉
Start-Sleep -Seconds 5