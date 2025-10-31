#!/bin/bash

set -e

# 取得腳本所在的目錄
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="${PROJECT_ROOT}/scripts"
echo "--- [$(date)] --- Starting uninstall afs hub service and images ---"
# 執行 uninstall 移除主要WEB服務腳本
bash "${SCRIPT_DIR}/uninstall-afs-ai-hub-service.sh" || true

read -p "是否要繼續進行刪除相關工具？(y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
  echo "操作取消"
  exit 0
fi

echo "--- [$(date)] --- Starting uninstall tools ---"
# 執行 uninstall移除相關工具腳本
bash "${SCRIPT_DIR}/uninstall-tools.sh"

echo "--- [$(date)] --- All unstall steps completed successfully! ---"

exit 0