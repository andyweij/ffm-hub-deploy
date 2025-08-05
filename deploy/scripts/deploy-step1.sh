#!/bin/bash
set -e

# 變數定義
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
# 日誌資料夾與檔案設定
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/deploy_nvidia_docker.log"

# 若 logs 資料夾不存在，則建立
mkdir -p "$LOG_DIR"

exec > >(tee -a "$LOG_FILE") 2>&1
echo "Starting deployment script : $(date)"

# 安裝紀錄
INSTALLED=()
SKIPPED=()

if command -v curl >/dev/null 2>&1; then
    echo "curl 已安裝，跳過安裝步驟。"
    SKIPPED+=("curl")
else
    echo "安裝 curl..."
    sudo apt-get update
    sudo apt-get install -y curl || {
        echo "Failed to install curl"
        exit 1
    }
    INSTALLED+=("curl")
fi


# 檢查是否需要執行初始安裝
echo "Running initial installation process..."

if command -v docker >/dev/null 2>&1; then
    echo "Docker 已安裝，跳過安裝步驟。"
	SKIPPED+=("Docker")
else
    # 1. 安裝 Docker
	echo "Installing Docker..."
	sudo apt-get update
	sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

	# 添加 Docker GPG 鍵
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

	# 添加 Docker APT 軟體庫
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

	# 更新並安裝 Docker
	sudo apt-get update
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io || {
		echo "Failed to install Docker"
		exit 1
	}

	# 啟動並啟用 Docker 服務
	sudo systemctl start docker
	sudo systemctl enable docker
    INSTALLED+=("Docker")
fi

if docker compose version>/dev/null 2>&1; then
    echo "Docker compose 已安裝，跳過安裝步驟。"
    SKIPPED+=("Docker Compose")
else
	# 安裝 Docker Compose 插件
	echo "Installing Docker Compose plugin..."
	sudo apt-get install -y docker-compose-plugin || {
		echo "Failed to install Docker Compose plugin"
		exit 1
	}
    INSTALLED+=("Docker Compose")
fi


# 確保 docker 群組存在
sudo groupadd docker 2>/dev/null || true

if groups "$USER" | grep -qw docker; then
    echo "使用者已在 docker 群組中，無需再次加入。"
	SKIPPED+=("Add user to docker group")
else
    echo "Add a new user to the docker group..."
	sudo usermod -aG docker "$USER"
	INSTALLED+=("Add user to docker group")
fi

	# 2. 安裝 NVIDIA 驅動
if nvidia-smi >/dev/null 2>&1; then
    echo "NVIDIA 驅動已安裝，跳過安裝步驟"
    SKIPPED+=("NVIDIA Driver")
else
    echo "Installing NVIDIA driver..."
	sudo apt-get install -y ubuntu-drivers-common
	sudo ubuntu-drivers install || {
		echo "Failed to install NVIDIA driver"
		exit 1
	}
    INSTALLED+=("NVIDIA Driver")
fi

# 4. 安裝 NVIDIA Container Toolkit
if dpkg -s nvidia-container-toolkit >/dev/null 2>&1; then
    echo "NVIDIA Container Toolkit 已安裝，跳過安裝步驟。"
	SKIPPED+=("NVIDIA Container Toolkit")
else
	echo "Installing NVIDIA Container Toolkit..."
	curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
	curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
		sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
		sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
	sudo sed -i -e '/experimental/ s/^#//g' /etc/apt/sources.list.d/nvidia-container-toolkit.list
	sudo apt-get update
	sudo apt-get install -y nvidia-container-toolkit || {
		echo "Failed to install NVIDIA Container Toolkit"
		exit 1
	}
	INSTALLED+=("NVIDIA Container Toolkit")
fi

sudo nvidia-ctk runtime configure --runtime=docker

# jq
if command -v jq &>/dev/null; then
    echo "jq 已安裝，跳過安裝步驟。"
    SKIPPED+=("jq")
else
    echo "Installing jq..."
    sudo apt-get update && sudo apt-get install -y jq || {
        echo "Failed to install jq"
        exit 1
    }
    INSTALLED+=("jq")
fi

echo "--------------------------------------------------"
echo "安裝總結："
if [ ${#INSTALLED[@]} -gt 0 ]; then
    echo "已安裝："
    for item in "${INSTALLED[@]}"; do
        echo "  - $item"
    done
	printf "%s\n" "${INSTALLED[@]}" | tee "$LOG_DIR/deploy_installed.log" > /dev/null
fi

if [ ${#SKIPPED[@]} -gt 0 ]; then
    echo "跳過安裝："
    for item in "${SKIPPED[@]}"; do
        echo "  - $item"
    done
fi
echo "--------------------------------------------------"

# 只有當有安裝新套件時才重啟
if [ ${#INSTALLED[@]} -gt 0 ]; then
    echo "Rebooting system to complete installation..."
    echo "正在設定開機自動執行 deploy-all.sh"

SERVICE_CONTENT="[Unit]
Description=Run All Deployment Steps After Reboot
After=network-online.target docker.service
Wants=network-online.target docker.service

[Service]
Type=oneshot
User=$(whoami)
WorkingDirectory=${SCRIPT_DIR}
ExecStart=${SCRIPT_DIR}/deploy-all.sh
# --- 新增這一行，在主要任務成功後執行清理 ---
ExecStartPost=${SCRIPT_DIR}/cleanup-service.sh deploy-all.service

StandardOutput=append:${LOG_DIR}/install.log
StandardError=append:${LOG_DIR}/install.log

[Install]
WantedBy=multi-user.target"

echo "$SERVICE_CONTENT" | sudo tee /etc/systemd/system/deploy-all.service > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable deploy-all.service

    sleep 5
    sudo systemctl reboot
else
    echo "無新套件安裝，跳過重啟步驟。"
fi