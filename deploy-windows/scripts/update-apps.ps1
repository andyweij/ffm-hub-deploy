# ========================================================
# update-apps.ps1 (按部就班 & 自動改名版)
# ========================================================
# 1. 權限檢查與自動提升 (UAC)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "正在請求管理員權限以更新應用程式..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$SCRIPT_DIR = $PSScriptRoot
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$AppFolder = Join-Path $PROJECT_ROOT "apps"
$BackupFolder = Join-Path $PROJECT_ROOT "apps\backup"

# 2. 載入 Windows Forms 模組以呼叫原生視窗
Add-Type -AssemblyName System.Windows.Forms

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AFS AI Hub 應用程式 逐步更新精靈" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ========================================================
# 宣告共用的「選檔函數」
# ========================================================
function Select-UpdateFile {
    param(
        [string]$ComponentName,
        [string]$TargetFileName
    )

    Write-Host ""
    # 詢問是否要更新該元件
    $Ask = Read-Host ">> 是否要更新 [$ComponentName] ? (Y/N，預設為 N)"
    if ($Ask -notmatch "^[Yy]$") {
        Write-Host "  -> 跳過更新 $ComponentName" -ForegroundColor Gray
        return $null
    }

    # 建立視窗
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.Title = "請選擇 $ComponentName 的更新檔 (將自動改名為 $TargetFileName)"
    $OpenFileDialog.Filter = "JAR 應用程式 (*.jar)|*.jar"
    $OpenFileDialog.Multiselect = $false  # 關閉多選，一次只能選一個
    $OpenFileDialog.InitialDirectory = Join-Path ([Environment]::GetFolderPath("UserProfile")) "Downloads"

    # 顯示視窗並擷取結果
    $DialogResult = $OpenFileDialog.ShowDialog()

    if ($DialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "  -> 已選擇: $(Split-Path $OpenFileDialog.FileName -Leaf)" -ForegroundColor Green
        return $OpenFileDialog.FileName
    } else {
        Write-Host "  -> 取消選擇，跳過更新 $ComponentName" -ForegroundColor Yellow
        return $null
    }
}

# ========================================================
# 3. 依序蒐集要更新的檔案 (此階段還不停止服務)
# ========================================================
# 步驟一：選擇 API Relay
$NewApiRelay = Select-UpdateFile -ComponentName "API Relay" -TargetFileName "api-relay.jar"

# 步驟二：選擇 AI Portal (根據你的腳本設定，檔名為 aiportal-backend.jar)
$NewAiPortal = Select-UpdateFile -ComponentName "AI Portal" -TargetFileName "aiportal-backend.jar"

# 檢查是否真的有選擇任何檔案
if ([string]::IsNullOrWhiteSpace($NewApiRelay) -and [string]::IsNullOrWhiteSpace($NewAiPortal)) {
    Write-Host ""
    Write-Host "未選擇任何更新檔案，更新程序結束。" -ForegroundColor Green
    Start-Sleep -Seconds 3
    exit
}

# ========================================================
# 4. 開始實際的更新流程 (停止服務、備份、覆蓋)
# ========================================================
Write-Host ""
Write-Host ">> 準備套用更新，正在停止所有背景服務..." -ForegroundColor Cyan
& "$SCRIPT_DIR\stop-all.ps1"

# 確保備份資料夾存在
if (-not (Test-Path $BackupFolder)) { New-Item -ItemType Directory -Path $BackupFolder -Force | Out-Null }

Write-Host ">> 正在備份現有應用程式至 apps\backup..." -ForegroundColor Gray
Copy-Item "$AppFolder\*.jar" -Destination $BackupFolder -Force -ErrorAction SilentlyContinue

Write-Host ">> 正在部署新版應用程式並進行標準化改名..." -ForegroundColor Cyan

# 處理 API Relay 的複製與改名
if (-not [string]::IsNullOrWhiteSpace($NewApiRelay)) {
    $TargetPath = Join-Path $AppFolder "api-relay.jar"
    Copy-Item -Path $NewApiRelay -Destination $TargetPath -Force
    Write-Host "  [成功] API Relay 已更新至 apps\api-relay.jar" -ForegroundColor Green
}

# 處理 AI Portal 的複製與改名
if (-not [string]::IsNullOrWhiteSpace($NewAiPortal)) {
    $TargetPath = Join-Path $AppFolder "aiportal-backend.jar"
    Copy-Item -Path $NewAiPortal -Destination $TargetPath -Force
    Write-Host "  [成功] AI Portal 已更新至 apps\aiportal-backend.jar" -ForegroundColor Green
}

# ========================================================
# 5. 重新啟動服務
# ========================================================
Write-Host ""
Write-Host ">> 更新套用完成，正在重新啟動服務..." -ForegroundColor Cyan
& "$SCRIPT_DIR\start-all.ps1"

Write-Host "========================================" -ForegroundColor Green
Write-Host "  應用程式更新並重新啟動完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Start-Sleep -Seconds 5