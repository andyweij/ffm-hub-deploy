#!/bin/bash

set -e
# 專案的根目錄，也就是 afs-ai-hub-installer/
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 定義其他目錄的路徑，方便引用
SCRIPT_DIR="${PROJECT_ROOT}/scripts"
CONFIG_DIR="${PROJECT_ROOT}/config"
ENV_FILE="${PROJECT_ROOT}/.env"

# 預設 IP 取得方式
IP_METHOD="local"

# 解析傳入的參數
if [[ "$1" == "--local-ip" ]]; then
  IP_METHOD="local"
  echo "將使用本地 IP 取得方式。"
elif [[ "$1" == "--public-ip" ]]; then
  IP_METHOD="public"
  echo "將使用公開 IP 取得方式。"
fi

# 將選擇的 IP 方式寫入 .env 檔案
# 檢查 .env 中是否「存在」 IP_ACQUISITION_METHOD 這一行
if grep -q "^IP_ACQUISITION_METHOD=" "$ENV_FILE"; then
    # 如果存在，就用 sed 取代
    sed -i "s/^IP_ACQUISITION_METHOD=.*/IP_ACQUISITION_METHOD=${IP_METHOD}/" "$ENV_FILE"
    echo "已更新 .env 中的 IP_ACQUISITION_METHOD 為：${IP_METHOD}"
else
    # 如果不存在，就用 echo 新增
    echo "" >> "$ENV_FILE"
    echo "IP_ACQUISITION_METHOD=${IP_METHOD}" >> "$ENV_FILE"
    echo "已新增 IP_ACQUISITION_METHOD 至 .env：${IP_METHOD}"
fi

echo "=== 開始執行 AFS AI Hub 安裝程序 ==="

echo "--- 步驟 1: 執行環境初始化與安裝 ---"
# 呼叫 scripts/ 目錄下的腳本
bash "${SCRIPT_DIR}/deploy-step1.sh"

# deploy-step1.sh 會觸發重開機，後續步驟由 systemd 接手
echo "=== 環境初始化完成，系統將會重啟以繼續後續步驟 ==="
echo "=== 重啟後，systemd 將自動執行 ${SCRIPT_DIR}/deploy-all.sh ==="