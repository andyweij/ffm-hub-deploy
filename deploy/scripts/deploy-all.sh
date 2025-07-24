#!/bin/bash

# 如果任何一個指令失敗，就立刻終止腳本
set -e

# 取得腳本所在的目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "--- [$(date)] --- Starting Step 2: Main Deployment ---"
# 執行 step2 腳本
bash "${SCRIPT_DIR}/deploy-step2.sh"

echo "--- [$(date)] --- Step 2 Completed. Starting Step 3: Keycloak Init ---"
# 執行 keycloak 初始化腳本
bash "${SCRIPT_DIR}/init-keycloak.sh"

echo "--- [$(date)] --- All deployment steps completed successfully! ---"

exit 0