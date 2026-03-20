# ========================================================
#   deploy-postgres.ps1
#   (純淨版：自動依賴 config.json 讀取資料庫環境變數)
# ========================================================

$SCRIPT_DIR = $PSScriptRoot
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR

# ============================================
# 1. 載入 config.json (單一設定來源)
# ============================================
$ConfigPath = Join-Path $PROJECT_ROOT "config.json"
if (-not (Test-Path $ConfigPath)) {
    Write-Host "[錯誤] 找不到 config.json，請先確認設定檔存在！" -ForegroundColor Red
    exit 1
}
$Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

# 從 Config 提取資料庫變數
$DB_NAME = $Config.Database.POSTGRES_DB
$DB_USER = $Config.Database.POSTGRES_USER
$DB_PASS = $Config.Database.POSTGRES_PASSWORD

# postgres 預設的超級管理員密碼 (因屬內部初始管理用途，暫時保留預設值)
$PG_SUPER_PASS = "password"

# ============================================
# 2. 設定安裝路徑與變數
# ============================================
$PgVersion = "16.13-1"
$DownloadUrl = "https://get.enterprisedb.com/postgresql/postgresql-$PgVersion-windows-x64-binaries.zip"
$RuntimeDir = Join-Path $PROJECT_ROOT "runtime"
$PgHome = Join-Path $RuntimeDir "pgsql"
$PgData = Join-Path $PgHome "data"
$ZipPath = Join-Path $PROJECT_ROOT "packages\postgresql-bin.zip"

function Write-Log { 
    param ([string]$Message) 
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor Cyan 
}

try {
    # ============================================
    # 3. 下載與解壓縮
    # ============================================
    if (-not (Test-Path $PgHome)) {
        if (-not (Test-Path $RuntimeDir)) { New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null }
        
        # 檢查 ZipPath 防呆邏輯
        if (-not (Test-Path $ZipPath)) {
            Write-Log "本地找不到 PostgreSQL 壓縮檔，正在從網路下載 16.13..."
            Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -Verbose
        } else {
            Write-Log "找到本地 PostgreSQL 壓縮檔，準備解壓縮..."
        }
        
        Write-Log "解壓縮中..."
        Expand-Archive -Path $ZipPath -DestinationPath $RuntimeDir -Force
    }

    # ============================================
    # 4. 初始化數據目錄 (initdb)
    # ============================================
    if (-not (Test-Path $PgData)) {
        Write-Log "執行 initdb 初始化資料庫..."
        $PassFile = Join-Path $PgHome "pg_pass.txt"
        $PG_SUPER_PASS | Out-File -FilePath $PassFile -Encoding ascii
        
        & "$PgHome\bin\initdb.exe" -U postgres -A md5 --pwfile=$PassFile -E UTF8 -D $PgData
        Remove-Item $PassFile
        Write-Log "資料庫初始化完成。"
    }

    # ============================================
    # 5. 啟動資料庫
    # ============================================
    Write-Log "啟動 PostgreSQL 以進行初步設定..."
    Start-Process "$PgHome\bin\pg_ctl.exe" -ArgumentList "start -D `"$PgData`" -l `"$PgHome\pg_server.log`"" -WindowStyle Hidden
    Start-Sleep -Seconds 5

    $env:PGPASSWORD = $PG_SUPER_PASS
    $PgBin = Join-Path $PgHome "bin"
    $PsqlExe = Join-Path $PgBin "psql.exe"
    
    Write-Log "正在檢查並建立資料庫與使用者..."

    # ============================================
    # 6. 動態建立資料庫與使用者 (來自 config.json)
    # ============================================
    
    # --- A. 建立共用 User (預設: admin) ---
    $userCheck = & $PsqlExe -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'"
    if ($userCheck -ne "1") {
        Write-Host "正在建立使用者 $DB_USER..." -ForegroundColor Yellow
        "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';" | & $PsqlExe -U postgres
    }

    # --- B. 建立 AI Hub 專用 Database (預設: afs-ai-hub_db) ---
    $dbHubCheck = & $PsqlExe -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'"
    if ($dbHubCheck -ne "1") {
        Write-Host "正在建立 $DB_NAME 資料庫並設定 Owner..." -ForegroundColor Yellow
        
        # 使用 Pipe 方式，直接傳送含雙引號的 SQL 字串 (解決大小寫及橫線名稱問題)
        "CREATE DATABASE `"$DB_NAME`" OWNER $DB_USER;" | & $PsqlExe -U postgres
        
        # 針對 PG 15+ 授權 public schema
        "GRANT ALL ON SCHEMA public TO $DB_USER;" | & $PsqlExe -U postgres -d "$DB_NAME"
        
        Write-Host "$DB_NAME 建立完成並已授權給 $DB_USER。" -ForegroundColor Green
    } else {
        Write-Host "資料庫 $DB_NAME 已存在，跳過建立。" -ForegroundColor Green
    }

# 提取 Keycloak DB 變數
    $KC_DB_NAME = $Config.Keycloak.DB_NAME
    $KC_DB_USER = $Config.Keycloak.DB_USER
    $KC_DB_PASS = $Config.Keycloak.DB_PASSWORD

    # --- C. 建立 Keycloak 專用使用者與資料庫 ---
    $kcUserCheck = & $PsqlExe -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$KC_DB_USER'"
    if ($kcUserCheck -ne "1") {
        Write-Host "正在建立使用者 $KC_DB_USER..." -ForegroundColor Yellow
        "CREATE USER $KC_DB_USER WITH PASSWORD '$KC_DB_PASS';" | & $PsqlExe -U postgres
    }

    $dbKkCheck = & $PsqlExe -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$KC_DB_NAME'"
    if ($dbKkCheck -ne "1") {
        Write-Host "正在建立 $KC_DB_NAME 資料庫..." -ForegroundColor Yellow
        "CREATE DATABASE `"$KC_DB_NAME`" OWNER $KC_DB_USER;" | & $PsqlExe -U postgres
        Write-Host "資料庫 $KC_DB_NAME 建立完成並已設定 Owner。" -ForegroundColor Green
    } else {
        Write-Host "資料庫 $KC_DB_NAME 已存在，跳過建立。" -ForegroundColor Green
    }

    Write-Log "PostgreSQL 綠色版部署與資料庫配置完成！"

} catch {
    Write-Error "PostgreSQL 部署發生錯誤: $_"
}