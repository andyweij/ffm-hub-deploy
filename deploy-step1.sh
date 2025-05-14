#!/bin/bash
set -e

# 變數定義
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/config/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Can't find .env file: $ENV_FILE"
    exit 1
fi

# 從 .env 檔案載入環境變數
set -o allexport
source "$ENV_FILE"
set +o allexport
# 重新取得最新的 IP（避免被上面覆蓋）
VM_IP=$(curl -s ifconfig.me)

if grep -q "^VM_IP=" "$ENV_FILE"; then
    echo ".env is already exists VM_IP , will overwrite"
    # 使用 sed 修改原有的 VM_IP 內容
    sed -i "s/^VM_IP=.*/VM_IP=$VM_IP/" "$ENV_FILE"
else
    echo "Create VM_IP in .env"
    echo -e "\nVM_IP=$VM_IP" >> "$ENV_FILE"
fi

# 日誌設置
LOG_FILE="$SCRIPT_DIR/deploy_nvidia_docker.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Starting deployment script : $(date)"
REBOOT_FLAG="/tmp/reboot_flag"

# 檢查是否需要執行初始安裝
echo "Running initial installation process..."
touch "$REBOOT_FLAG"

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

# 安裝 Docker Compose 插件
echo "Installing Docker Compose plugin..."
sudo apt-get install -y docker-compose-plugin || {
    echo "Failed to install Docker Compose plugin"
    exit 1
}

# 設置 Docker 權限
sudo groupadd docker || true
sudo usermod -aG docker "$USER"

# 2. 安裝 NVIDIA 驅動
echo "Installing NVIDIA driver..."
# sudo apt-get update
sudo apt-get install -y ubuntu-drivers-common
sudo ubuntu-drivers install || {
    echo "Failed to install NVIDIA driver"
    exit 1
}


# 4. 安裝 NVIDIA Container Toolkit
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
sudo nvidia-ctk runtime configure --runtime=docker

echo "Rebooting system to complete installation..."
sleep 2

sudo systemctl reboot
