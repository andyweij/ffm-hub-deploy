# ========================================
#   AFS AI Hub AI Portal 啟動腳本
#   Windows 環境 (非 Docker 部署)
#   (純淨版：完全依賴 config.json 讀取環境變數)
# ========================================

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR

# ============================================
# 1. 載入 config.json (單一設定來源)
# ============================================
$ConfigPath = Join-Path $PROJECT_ROOT "config.json"
if (-not (Test-Path $ConfigPath)) {
    Write-Host "[錯誤] 找不到 config.json，請確認設定檔是否存在！" -ForegroundColor Red
    exit 1
}
$Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

$VM_IP    = $Config.Global.VM_IP
$JDK_PATH = $Config.Global.JDK_PATH
$CERT_PWD = $Config.Global.CERT_PASSWORD

$CERT_DIR = Join-Path $PROJECT_ROOT "certs"
$SERVER_CERT_DIR = Join-Path $CERT_DIR "server"
$APP_ROOT = Join-Path $PROJECT_ROOT "apps"
$JAR_NAME = "aiportal-backend.jar"

# ========== 2. 設定綠色版 Java 環境變數 ==========
if (-not [string]::IsNullOrWhiteSpace($JDK_PATH) -and (Test-Path $JDK_PATH)) {
    $env:JAVA_HOME = $JDK_PATH
    $env:PATH = "$JDK_PATH\bin;" + $env:PATH
    Write-Host "已載入綠色版 Java 環境: $JDK_PATH" -ForegroundColor Green
} else {
    Write-Host "[錯誤] config.json 中的 JDK_PATH 無效或找不到。" -ForegroundColor Red
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AFS AI Hub AI Portal 啟動腳本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================
# 3. 注入環境變數 (從 Config 取值)
# ============================================
$env:SERVER_PORT                  = $Config.AiPortal.SERVER_PORT
$env:SERVER_SSL_ENABLED           = "true"
$env:SERVER_SSL_KEYSTORE          = "$SERVER_CERT_DIR\keystore.p12"
$env:SERVER_SSL_KEYSTORE_PASSWORD = $CERT_PWD
$env:SERVER_SSL_KEYSTORE_TYPE     = "PKCS12"

$env:SPRING_PROFILES_ACTIVE       = $Config.AiPortal.SPRING_PROFILES_ACTIVE
$env:APIMODULE_URL                = "https://${VM_IP}:$($Config.ApiRelay.SERVER_PORT)"
$env:FRONTEND_KEYCLOAK_URL        = "https://${VM_IP}:$($Config.Keycloak.PORT)"
$env:FRONTEND_KEYCLOAK_REALM      = $Config.Keycloak.REALM_NAME
$env:FRONTEND_KEYCLOAK_CLIENTID   = $Config.Keycloak.CLIENT_ID
$env:GRAFANA_URL                  = $Config.AiPortal.GRAFANA_URL
$env:API_DOC_URL                  = $Config.AiPortal.API_DOC_URL
$env:TZ                           = $Config.Global.TZ
# --- 新增：管理介面開關 ---
$env:PLATFORM_MANAGEMENT_OVERVIEW_ENABLED              = $Config.AiPortal.PLATFORM_MANAGEMENT_OVERVIEW_ENABLED
$env:PLATFORM_MANAGEMENT_USER_MANAGEMENT_ENABLED       = $Config.AiPortal.PLATFORM_MANAGEMENT_USER_MANAGEMENT_ENABLED
$env:PLATFORM_MANAGEMENT_GROUP_MANAGEMENT_ENABLED      = $Config.AiPortal.PLATFORM_MANAGEMENT_GROUP_MANAGEMENT_ENABLED
$env:PLATFORM_MANAGEMENT_LDAP_MANAGEMENT_ENABLED       = $Config.AiPortal.PLATFORM_MANAGEMENT_LDAP_MANAGEMENT_ENABLED
$env:PLATFORM_MANAGEMENT_MODEL_MANAGEMENT_ENABLED      = $Config.AiPortal.PLATFORM_MANAGEMENT_MODEL_MANAGEMENT_ENABLED
$env:PLATFORM_MANAGEMENT_AGENT_MANAGEMENT_ENABLED      = $Config.AiPortal.PLATFORM_MANAGEMENT_AGENT_MANAGEMENT_ENABLED
$env:PLATFORM_MANAGEMENT_API_ENDPOINT_MANAGEMENT_ENABLED = $Config.AiPortal.PLATFORM_MANAGEMENT_API_ENDPOINT_MANAGEMENT_ENABLED
$env:PLATFORM_MANAGEMENT_API_KEY_MANAGEMENT_ENABLED    = $Config.AiPortal.PLATFORM_MANAGEMENT_API_KEY_MANAGEMENT_ENABLED
$env:PLATFORM_MANAGEMENT_SYSTEN_LOG_MANAGEMENT_ENABLED = $Config.AiPortal.PLATFORM_MANAGEMENT_SYSTEN_LOG_MANAGEMENT_ENABLED

# --- 新增：IP 模式與路徑設定 ---
$env:IP_MODE_ENABLED                  = $Config.AiPortal.IP_MODE_ENABLED
$env:IP_MODE_APIMODULE_PATH           = $Config.AiPortal.IP_MODE_APIMODULE_PATH
$env:IP_MODE_FRONTEND_KEYCLOAK_PATH   = $Config.AiPortal.IP_MODE_FRONTEND_KEYCLOAK_PATH
$env:IP_MODE_API_DOC_PATH             = $Config.AiPortal.IP_MODE_API_DOC_PATH

Write-Host "[配置] 當前 Profile: $env:SPRING_PROFILES_ACTIVE" -ForegroundColor Yellow
Write-Host "[配置] IP 模式啟用狀態: $env:IP_MODE_ENABLED" -ForegroundColor Yellow

# ============================================
# 4. 啟動應用程式
# ============================================
$jarPath = Join-Path $APP_ROOT $JAR_NAME
if (Test-Path $jarPath) {
    Write-Host "[啟動] 正在啟動 AI Portal 服務 (背景輸出至 logs/ai-portal.log)..." -ForegroundColor Cyan
    $PortalLog = Join-Path $PROJECT_ROOT "logs\ai-portal.log"
    
    $JavaExe = Join-Path $JDK_PATH "bin\java.exe"
    $CmdArgs = "/c `" `"$JavaExe`" -jar `"$jarPath`" > `"$PortalLog`" 2>&1 `""
    Start-Process -FilePath "cmd.exe" -ArgumentList $CmdArgs -WindowStyle Hidden
} else {
    Write-Host "[錯誤] 找不到 $jarPath，請確認是否已放置 JAR 檔。" -ForegroundColor Red
    exit 1
}