#!/bin/bash
set -e

# 基本設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 日誌資料夾與檔案設定
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/uninstall_nvidia_docker.log"
INSTALLED_LOG="$LOG_DIR/deploy_installed.log"
REMOVED_LOG="$LOG_DIR/uninstall_removed.log"


exec > >(tee -a "$LOG_FILE") 2>&1
echo "Starting uninstall script : $(date)"

if [ ! -f "$INSTALLED_LOG" ]; then
    echo "找不到安裝紀錄檔案：$INSTALLED_LOG，無法進行卸載"
    exit 1
fi

# 讀取已安裝項目
mapfile -t INSTALLED_ITEMS < "$INSTALLED_LOG"

# 紀錄實際移除項目
REMOVED=()

# 判斷是否由我們安裝
function was_installed_by_us() {
    local item="$1"
    [[ " ${INSTALLED_ITEMS[*]} " == *" $item "* ]]
}

# NVIDIA Container Toolkit
if was_installed_by_us "NVIDIA Container Toolkit"; then

    echo "Removing NVIDIA Container Toolkit..."
	sudo apt-get purge -y nvidia-container-toolkit
	# 2. 【關鍵】刪除安裝時新增的 APT 軟體庫設定檔
	echo "Removing NVIDIA Container Toolkit APT source list..."
	sudo rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list

	# 3. 【關鍵】刪除安裝時新增的 GPG 金鑰
	echo "Removing NVIDIA Container Toolkit GPG key..."
	sudo rm -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

	sudo apt-get autoremove -y
    REMOVED+=("NVIDIA Container Toolkit")
fi

# jq
if was_installed_by_us "jq"; then
    echo "Removing jq..."
    sudo apt-get remove -y jq
    REMOVED+=("jq")
fi

# Docker Compose plugin
if was_installed_by_us "Docker Compose"; then
    echo "Removing Docker Compose plugin..."
    sudo apt-get remove -y docker-compose-plugin
    REMOVED+=("Docker Compose")
fi

# Docker
if was_installed_by_us "Docker"; then
    echo "Removing Docker..."
    sudo apt-get remove -y docker-ce docker-ce-cli containerd.io
    sudo rm -f /etc/apt/sources.list.d/docker.list
    sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg
    REMOVED+=("Docker")
fi

# NVIDIA Driver
if was_installed_by_us "NVIDIA Driver"; then
    echo "NVIDIA 驅動需手動移除，建議保留現狀"
    # 若想自動移除可補充：
    # sudo ubuntu-drivers uninstall
fi

# 使用者移出 docker 群組
if was_installed_by_us "Add user to docker group"; then
    echo "Removing user from docker group (需重啟後才生效)..."
    sudo gpasswd -d "$USER" docker
    REMOVED+=("Remove user from docker group")
fi

# 將要刪除的目標路徑存成變數，方便管理且不易出錯
TARGET_DIR="/opt/vllm-models"

# 首先，使用 -d 判斷目標路徑是否存在且是一個資料夾
if [ -d "$TARGET_DIR" ]; then
    echo "發現目標資料夾 ${TARGET_DIR}，正在嘗試刪除..."
    
    # 執行刪除
    sudo rm -R "$TARGET_DIR"
    
    # 檢查刪除操作的返回碼
    if [ $? -eq 0 ]; then
        echo "成功刪除資料夾: ${TARGET_DIR}"
    else
        echo "錯誤：刪除資料夾 ${TARGET_DIR} 失敗。請檢查權限或錯誤訊息。"
        exit 1
    fi
else
    # 如果資料夾一開始就不存在
    echo "目標資料夾 ${TARGET_DIR} 本來就不存在，無需執行刪除操作。"
fi

# 如果程式能走到這裡，代表最終狀態是成功的 (資料夾已不存在)
echo "操作完成。"

# 結尾輸出
echo "--------------------------------------------------"
echo "卸載總結："
if [ ${#REMOVED[@]} -gt 0 ]; then
    echo "已卸載："
    for item in "${REMOVED[@]}"; do
        echo "  - $item"
    done
    printf "%s\n" "${REMOVED[@]}" | sudo tee "$REMOVED_LOG" > /dev/null
else
    echo "沒有移除任何項目。"
fi
echo "--------------------------------------------------"
