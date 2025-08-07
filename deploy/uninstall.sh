#!/bin/bash

set -e

# 取得腳本所在的目錄
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="${PROJECT_ROOT}/scripts"
echo "--- [$(date)] --- Starting uninstall afs hub service and images ---"
# 執行 step2 腳本
bash "${SCRIPT_DIR}/uninstall-afs-ai-hub-service.sh"

echo "--- [$(date)] --- Starting uninstall tools ---"
# 執行 keycloak 初始化腳本
bash "${SCRIPT_DIR}/uninstall-tools.sh"

echo "--- [$(date)] --- All unstall steps completed successfully! ---"

exit 0