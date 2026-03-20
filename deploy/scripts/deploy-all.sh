#!/bin/bash

# 如果任何一個指令失敗，就立刻終止腳本
set -e

# 取得腳本所在的目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "--- [$(date)] --- Starting Step 2: Main Deployment ---"
# 執行 step2 腳本
bash "${SCRIPT_DIR}/deploy-step2.sh"

# =========================================================
echo "--- [$(date)] --- 執行 GPU 喚醒與驗證 (Work Run) ---"

# 給 Docker 一點點時間啟動服務
sleep 5 

# 強制讓 api-relay 容器跑一次 nvidia-smi
# 這能確保驅動被載入，且如果失敗，腳本會立刻停下報錯，不會假裝成功
if docker exec api-relay nvidia-smi > /dev/null 2>&1; then
    echo "SUCCESS: GPU 已成功掛載至 api-relay 容器。"
else
    echo "ERROR: api-relay 無法存取 GPU！嘗試重啟 Docker 服務..."
    sudo systemctl restart docker
    # 重新嘗試啟動容器
    cd "$SCRIPT_DIR/.." && docker compose up -d --force-recreate
    
    # 再次檢查
    sleep 5
    if ! docker exec api-relay nvidia-smi; then
        echo "致命錯誤：即便重啟後仍無法偵測 GPU，請檢查驅動安裝狀態。"
        exit 1
    fi
fi
# =========================================================

echo "--- [$(date)] --- Step 2 Completed. Starting Step 3: Keycloak Init ---"
# 執行 keycloak 初始化腳本
bash "${SCRIPT_DIR}/init-keycloak.sh"

echo "--- [$(date)] --- All deployment steps completed successfully! ---"

exit 0