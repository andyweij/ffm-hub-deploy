# --- 設定區 ---
$JavaVersion = "17"
# 下載 JDK 17 的 ZIP 版本
$DownloadUrl = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.14%2B7/OpenJDK17U-jdk_x64_windows_hotspot_17.0.14_7.zip"
# 指定您想要的綠色安裝路徑
$SCRIPT_DIR = $PSScriptRoot
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$JdkFolder = "jdk-$JavaVersion"
$InstallBaseDir = Join-Path $PROJECT_ROOT "runtime"
$FullJdkPath = Join-Path $InstallBaseDir $JdkFolder
$ZipPath = Join-Path $PROJECT_ROOT "packages\openjdk17.zip"

function Write-Log {
    param ([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor Cyan
}

try {
    # 1. 建立目錄
    if (-not (Test-Path $InstallBaseDir)) { New-Item -ItemType Directory -Path $InstallBaseDir -Force | Out-Null }

    # 2. 檢查是否已經安裝過 Java
    if (-not (Test-Path $FullJdkPath)) {
        if (-not (Test-Path $ZipPath)) {
            Write-Log "正在下載 Java 17 ZIP 版..."
            Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -Verbose
        }

        # 3. 解壓縮
        Write-Log "正在解壓縮至 $FullJdkPath..."
        Expand-Archive -Path $ZipPath -DestinationPath $InstallBaseDir -Force

        # 給予防毒軟體一點時間緩衝 (先暫停 2 秒)
        Start-Sleep -Seconds 2
        
        # 修正解壓後多一層資料夾的問題
        $ExtractedFolder = Get-ChildItem -Path $InstallBaseDir -Directory -Filter "jdk-17*" | Select-Object -First 1
        if ($ExtractedFolder.Name -ne $JdkFolder) {
            $maxRetries = 5        # 最大重試次數
            $retryCount = 0
            $renameSuccess = $false

            while ($retryCount -lt $maxRetries -and -not $renameSuccess) {
                try {
                    # 嘗試更名，若失敗會觸發 catch
                    Rename-Item -Path $ExtractedFolder.FullName -NewName $JdkFolder -ErrorAction Stop
                    $renameSuccess = $true
                    Write-Log "JDK 資料夾更名成功。"
                } catch {
                    $retryCount++
                    Write-Log "資料夾正被系統或防毒軟體佔用，等待 2 秒後重試... ($retryCount/$maxRetries)"
                    Start-Sleep -Seconds 2
                }
            }

            if (-not $renameSuccess) {
                Write-Error "JDK 更名失敗，已達最大重試次數，請確認防毒軟體是否鎖定檔案。"
            }
        }
    } else {
        Write-Log "Java 已安裝於 $FullJdkPath，跳過下載與解壓。"
    }

    # 4. 設定環境變數 (僅限當前視窗，完美綠色版)
    $env:JAVA_HOME = $FullJdkPath
    $env:Path = "$FullJdkPath\bin;" + $env:Path
    # --- 刪除或註解掉以下這段 ---
    # [Environment]::SetEnvironmentVariable("JAVA_HOME", $FullJdkPath, "User")
    # 
    # $oldPath = [Environment]::GetEnvironmentVariable("Path", "User")
    # if ($oldPath -notlike "*$FullJdkPath\bin*") {
    #     $newPath = "$FullJdkPath\bin;" + $oldPath
    #     [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    #     Write-Log "已將 Java 加入使用者 PATH"
    # }
    # -----------------------------
    Write-Log "Java 綠色安裝完成！"
    Write-Log "JAVA_HOME 設定為: $env:JAVA_HOME"
    java -version

} catch {
    Write-Error "安裝失敗: $_"
} finally {
    if (Test-Path $ZipPath) { 
       # Remove-Item $ZipPath -Force 
    }
}