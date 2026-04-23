# ========================================
#   AFS AI Hub API Relay 啟動腳本
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

$VM_IP        = $Config.Global.VM_IP
$GPU_PROVIDER = $Config.Global.GPU_PROVIDER
$JDK_PATH     = $Config.Global.JDK_PATH
$CERT_PWD     = $Config.Global.CERT_PASSWORD

$CERT_DIR = Join-Path $PROJECT_ROOT "certs"
$SERVER_CERT_DIR = Join-Path $CERT_DIR "server"
$APP_ROOT = Join-Path $PROJECT_ROOT "apps"
$JAR_NAME = "api-relay.jar"

# ========== 2. 設定綠色版 Java 環境變數 ==========
if (-not [string]::IsNullOrWhiteSpace($JDK_PATH) -and (Test-Path $JDK_PATH)) {
    $env:JAVA_HOME = $JDK_PATH
    $env:PATH = "$JDK_PATH\bin;" + $env:PATH
    Write-Host "已載入綠色版 Java 環境: $JDK_PATH" -ForegroundColor Green
} else {
    Write-Host "[錯誤] config.json 中的 JDK_PATH 無效或找不到。" -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($VM_IP)) {
    Write-Host "錯誤：IP 位址不能為空" -ForegroundColor Red
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  AFS AI Hub API Relay 啟動腳本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================
# 3. 自動處理 Java 信任庫 (解決 SSLHandshakeException)
# ============================================
$TRUSTSTORE_PATH = Join-Path $SERVER_CERT_DIR "truststore.jks"
$CRT_FILE = Join-Path $SERVER_CERT_DIR "certificate.crt"
$JAVA_CACERTS = Join-Path $JDK_PATH "lib\security\cacerts"
$JAVA_BIN = Join-Path $JDK_PATH "bin"

$javaOpts = "-Dfile.encoding=UTF-8 -Dsun.stdout.encoding=UTF-8 -Dsun.stderr.encoding=UTF-8"
if (Test-Path $CRT_FILE) {
    Write-Host "[配置] 正在匯入憑證至 Java 信任庫..." -ForegroundColor Cyan
    $env:Path += ";$JAVA_BIN"

    if (-not (Test-Path $TRUSTSTORE_PATH)) {
        if (Test-Path $JAVA_CACERTS) {
            Copy-Item -Path $JAVA_CACERTS -Destination $TRUSTSTORE_PATH -Force
        }
    }
    & keytool -import -alias ffm-ca -file "$CRT_FILE" -keystore "$TRUSTSTORE_PATH" -storepass $CERT_PWD -noprompt 2>$null
    $javaOpts += " -Djavax.net.ssl.trustStore=$TRUSTSTORE_PATH -Djavax.net.ssl.trustStorePassword=$CERT_PWD"
}
$env:JAVA_TOOL_OPTIONS = $javaOpts

# ============================================
# 4. 引擎類型與 PATH (Llama.cpp)
# ============================================
$LLAMA_DIR = Join-Path $PROJECT_ROOT "runtime\llama-cpp"
if (Test-Path $LLAMA_DIR) {
    $env:PATH = "$LLAMA_DIR;" + $env:PATH
} else {
    Write-Host "[警告] 找不到 Llama.cpp 路徑: $LLAMA_DIR" -ForegroundColor Yellow
}

# ============================================
# 5. 注入環境變數 (從 Config 取值)
# ============================================
$env:SERVER_PORT                  = $Config.ApiRelay.SERVER_PORT
$env:SERVER_SSL_ENABLED           = "true"
$env:SERVER_SSL_KEYSTORE          = "$SERVER_CERT_DIR\keystore.p12"
$env:SERVER_SSL_KEYSTORE_PASSWORD = $CERT_PWD
$env:SERVER_SSL_KEYSTORE_TYPE     = "PKCS12"

$env:MODEL_ENGINE_TYPE = $Config.ApiRelay.MODEL_ENGINE_TYPE
$env:RUNTIME_TYPE      = $Config.ApiRelay.RUNTIME_TYPE
$env:GPU_PROVIDER      = $GPU_PROVIDER
$env:API_RELAY_PORT    = $Config.ApiRelay.SERVER_PORT
$env:HOST_IP           = $VM_IP

$env:KEYCLOAK_SERVER_URL = "https://${VM_IP}:$($Config.Keycloak.PORT)"
$env:KEYCLOAK_USERNAME   = $Config.Keycloak.APP_USERNAME
$env:KEYCLOAK_PASSWORD   = $Config.Keycloak.APP_PASSWORD

$env:SPRING_DATASOURCE_URL      = "jdbc:postgresql://$($Config.Database.POSTGRES_HOST):$($Config.Database.POSTGRES_PORT)/$($Config.Database.POSTGRES_DB)"
$env:SPRING_DATASOURCE_USERNAME = $Config.Database.POSTGRES_USER
$env:SPRING_DATASOURCE_PASSWORD = $Config.Database.POSTGRES_PASSWORD

$env:S3_END_POINT   = $Config.ApiRelay.S3_END_POINT
$env:S3_BUCKET_NAME = $Config.ApiRelay.S3_BUCKET_NAME
$env:MODEL_PREFIX   = $Config.ApiRelay.MODEL_PREFIX
$env:MODEL_LIST     = $Config.ApiRelay.MODEL_LIST
$env:AGENT_LIST     = $Config.ApiRelay.AGENT_LIST
$env:AGENT_PREFIX   = $Config.ApiRelay.AGENT_PREFIX

$env:LOCAL_DIR       = $Config.ApiRelay.LOCAL_DIR
$env:LOCAL_AGENT_DIR = $Config.ApiRelay.LOCAL_AGENT_DIR
$env:LOCAL_MODEL_DIR = $Config.ApiRelay.LOCAL_MODEL_DIR
$env:DATA_SOURCE     = $Config.ApiRelay.DATA_SOURCE
$env:HUB_NAME        = $Config.ApiRelay.HUB_NAME
$env:HARBOR_REGISTRY = $Config.ApiRelay.HARBOR_REGISTRY
$env:HARBOR_PROJECT  = $Config.ApiRelay.HARBOR_PROJECT
$env:HARBOR_USERNAME = $Config.ApiRelay.HARBOR_USERNAME
$env:HARBOR_PASSWORD = $Config.ApiRelay.HARBOR_PASSWORD

$env:SPRING_MVC_ASYNC_REQUEST_TIMEOUT = $Config.ApiRelay.TIMEOUT_ASYNC_MS
$env:KEYCLOAK_TIMEOUT_MILLIS          = $Config.ApiRelay.TIMEOUT_KEYCLOAK_MS
$env:TZ                               = $Config.Global.TZ

# ============================================
# 6. 啟動應用程式
# ============================================
$jarFile = Get-ChildItem -Path (Join-Path $APP_ROOT $JAR_NAME) -ErrorAction SilentlyContinue | Select-Object -First 1

if ($jarFile) {
    Write-Host "[啟動] 正在啟動 API Relay 服務 (背景 Console 輸出至 logs/api-relay-console.log)..." -ForegroundColor Cyan
    # 更改檔名，避免與 Log4j2 衝突
    $RelayLog = Join-Path $PROJECT_ROOT "logs\api-relay-console.log"
    if (-not (Test-Path (Split-Path $RelayLog))) { New-Item -ItemType Directory -Path (Split-Path $RelayLog) -Force }

    $JavaExe = Join-Path $JDK_PATH "bin\java.exe"
    $JarPath = $jarFile.FullName
    $CmdArgs = "/c `" `"$JavaExe`" -jar `"$JarPath`" > `"$RelayLog`" 2>&1 `""
    Start-Process -FilePath "cmd.exe" -ArgumentList $CmdArgs -WorkingDirectory $PROJECT_ROOT -WindowStyle Hidden
} else {
    Write-Host "[錯誤] 找不到可執行的 JAR 檔 ($JAR_NAME)" -ForegroundColor Red
    exit 1
}