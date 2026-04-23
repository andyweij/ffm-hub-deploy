# ==========================================
# deploy-keycloak.ps1 (純淨版)
# ==========================================

$SCRIPT_DIR = $PSScriptRoot
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR

# 1. 載入 config.json
$ConfigPath = Join-Path $PROJECT_ROOT "config.json"
if (-not (Test-Path $ConfigPath)) {
    Write-Host "[錯誤] 找不到 config.json" -ForegroundColor Red
    exit 1
}
$Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

# 2. 定義安裝與路徑變數
$KeycloakVersion = "26.2.0"
$InstallDir = Join-Path $PROJECT_ROOT "runtime"
if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null }
$KeycloakZip = "keycloak-$KeycloakVersion.zip"
$DownloadUrl = "https://github.com/keycloak/keycloak/releases/download/$KeycloakVersion/$KeycloakZip"
$ZipPath = Join-Path $PROJECT_ROOT "packages\$KeycloakZip"
$KeycloakDist = "keycloak-$KeycloakVersion"
$KeycloakHome = Join-Path $InstallDir $KeycloakDist

function Write-Log { param ([string]$Message) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor Cyan }

# --- 自動下載與解壓縮邏輯 ---
if (-not (Test-Path $ZipPath)) {
    Write-Log "正在下載 Keycloak $KeycloakVersion..."
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath
} else {
    Write-Log "Keycloak 壓縮檔已存在，跳過下載。"
}

if (-not (Test-Path $KeycloakHome)) {
    Write-Log "正在解壓縮 Keycloak..."
    Expand-Archive -Path $ZipPath -DestinationPath $InstallDir -Force
    # --- [加入緩衝] 讓防毒軟體有時間掃描 ---
    Start-Sleep -Seconds 3
    # 檢查是否有「資料夾套資料夾」的情況，有的話把它移出來
    $NestedDir = Join-Path $InstallDir $KeycloakDist
    if (Test-Path "$NestedDir\$KeycloakDist") {
        # --- [加入重試機制] ---
        $maxRetries = 5
        $retryCount = 0
        $moveSuccess = $false

        while ($retryCount -lt $maxRetries -and -not $moveSuccess) {
            try {
                Move-Item "$NestedDir\$KeycloakDist\*" "$NestedDir\" -Force -ErrorAction Stop
                Remove-Item "$NestedDir\$KeycloakDist" -Recurse -Force -ErrorAction Stop
                $moveSuccess = $true
            } catch {
                $retryCount++
                Write-Log "資料夾正被佔用，等待 2 秒後重試移動... ($retryCount/$maxRetries)"
                Start-Sleep -Seconds 2
            }
        }
        if (-not $moveSuccess) { Write-Error "Keycloak 資料夾移動失敗，請檢查權限或防毒軟體。" }
    }
} else {
    Write-Log "Keycloak 資料夾已存在，跳過解壓縮。"
}

# 3. 定義路徑與資訊
$BaseDirForConf = $PROJECT_ROOT.Replace('\', '/') 
$ConfPath = Join-Path $KeycloakHome "conf\keycloak.conf"

# 4. 定義完整的配置 Map (替換為從 $Config 動態取值)
$Settings = @{
    # 資料庫設定 (動態組合)
    "db"                         = "postgres"
    "db-url"                     = "jdbc:postgresql://$($Config.Database.POSTGRES_HOST):$($Config.Database.POSTGRES_PORT)/$($Config.Keycloak.DB_NAME)"
    "db-username"                = $Config.Keycloak.DB_USER
    "db-password"                = $Config.Keycloak.DB_PASSWORD
    
    # 網路與主機設定
    "http-enabled"               = "false"
    "health-enabled"             = "true"
    
    # 憑證設定 (確保使用正斜線路徑)
    "https-certificate-file"     = "$BaseDirForConf/certs/server/certificate.crt"
    "https-certificate-key-file" = "$BaseDirForConf/certs/server/private.key"
}

if (Test-Path $ConfPath) {
    Write-Log "正在同步 keycloak.conf 配置項目..."

    # 讀取現有內容
    $content = Get-Content $ConfPath -Encoding utf8

    foreach ($key in $Settings.Keys) {
        $value = $Settings[$key]
        $newLine = "$key=$value"
        
        # 檢查該 Key 是否已存在
        if ($content -match "^$key=") {
            $content = $content | ForEach-Object {
                if ($_ -match "^$key=") { $newLine } else { $_ }
            }
        } else {
            $content += $newLine
        }
    }

    # 寫回檔案 (使用無 BOM 的 UTF8)
    $Utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($ConfPath, $content, $Utf8NoBom)
    
    Write-Log "所有配置已寫入成功！"
    Write-Log "目前憑證指向: $($Settings['https-certificate-file'])"
} else {
    Write-Error "找不到設定檔: $ConfPath"
}