#!/bin/bash

set -e
# 專案的根目錄，也就是 afs-hub-installer/
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 定義其他目錄的路徑，方便引用
SCRIPT_DIR="${PROJECT_ROOT}/scripts"
CONFIG_DIR="${PROJECT_ROOT}/config"

echo "=== 開始執行 AFS Hub 安裝程序 ==="

echo "--- 步驟 1: 執行環境初始化與安裝 ---"
# 呼叫 scripts/ 目錄下的腳本
bash "${SCRIPT_DIR}/deploy-step1.sh"

# deploy-step1.sh 會觸發重開機，後續步驟由 systemd 接手
echo "=== 環境初始化完成，系統將會重啟以繼續後續步驟 ==="
echo "=== 重啟後，systemd 將自動執行 ${SCRIPT_DIR}/deploy-step2.sh ==="