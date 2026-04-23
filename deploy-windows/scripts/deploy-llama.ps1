# ==========================================
# deploy-llama.ps1
# ==========================================
param([string]$GPU_PROVIDER = "amd")

$SCRIPT_DIR = $PSScriptRoot
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$RuntimeDir = Join-Path $PROJECT_ROOT "runtime"
$LlamaDir = Join-Path $RuntimeDir "llama-cpp"

$VersionTag = "b8416"

# 根據選擇的 GPU 決定檔名
$ZipName = switch ($GPU_PROVIDER) {
 #   "nvidia" { "llama-${VersionTag}-bin-win-cuda-cu12.2.0-x64.zip" }
    "amd"    { "llama-${VersionTag}-bin-win-hip-radeon-x64.zip" }
 #   "cpu"    { "llama-${VersionTag}-bin-win-avx2-x64.zip" }
    default  { "llama-${VersionTag}-bin-win-hip-radeon-x64.zip" }
}

$DownloadUrl = "https://github.com/ggerganov/llama.cpp/releases/download/$VersionTag/$ZipName"
$ZipPath = Join-Path $PROJECT_ROOT "packages\$ZipName"

function Write-Log { 
    param ([string]$Message) 
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor Cyan 
}

try {
    if (-not (Test-Path $RuntimeDir)) { 
        New-Item -ItemType Directory -Path $RuntimeDir -Force | Out-Null 
    }

    if (-not (Test-Path $LlamaDir)) {
        if (-not (Test-Path $ZipPath)) {
            Write-Log "正在下載 Llama.cpp ($GPU_PROVIDER 版本)..."
            Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing -ErrorAction Stop
        } else {
            Write-Log "找到本地 Llama.cpp 壓縮檔，準備解壓縮..."
        }

        Write-Log "解壓縮中..."
        Expand-Archive -Path $ZipPath -DestinationPath $LlamaDir -Force
        
        if (Test-Path $ZipPath) {
          # Remove-Item $ZipPath -Force -ErrorAction SilentlyContinue
        }
        Write-Log "Llama.cpp 部署完成！路徑: $LlamaDir"
    } 
    else {
        Write-Host "Llama.cpp 資料夾已存在，跳過下載。" -ForegroundColor Green
    }
}
catch {
    Write-Error "Llama.cpp 下載或解壓縮失敗: $($_.Exception.Message)"
    exit 1
}