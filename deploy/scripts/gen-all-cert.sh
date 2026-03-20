#!/bin/bash

# ========== Basic Configuration ==========
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
CERT_DIR="${PROJECT_ROOT}/certs"
SERVER_CERT_DIR="${CERT_DIR}/server"
PASSWORD="changeit"
DAYS=3650
ENV_FILE="$PROJECT_ROOT/.env"
EXT_TEMPLATE="${CERT_DIR}/v3_ext_template.ext"

# 1. 檢查 .env 檔案是否存在
if [ ! -f "$ENV_FILE" ]; then
    echo "錯誤：找不到環境設定檔 .env 於 '$ENV_FILE'"
    exit 1
fi

# 2. 從 .env 檔案載入環境變數
set -o allexport
source "$ENV_FILE"
set +o allexport

# 3. 驗證 VM_IP 是否成功載入且不為空
if [ -z "$VM_IP" ]; then
    echo "錯誤：在 .env 檔案中未找到 VM_IP 或其值為空。"
    exit 1
fi

IP="${VM_IP}"

# ========== Clean Previous Output ==========
rm -rf "$CERT_DIR"
mkdir -p "$SERVER_CERT_DIR"

# ========== Create v3_ext Template with Multiple SANs ==========
# 加入 IP 以及容器名稱，方便容器間通訊與外部存取共用
cat > "$EXT_TEMPLATE" <<EOF
basicConstraints = critical,CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
subjectAltName = @alt_names

[alt_names]
IP.1 = $IP
IP.2 = 127.0.0.1
DNS.1 = aiportal
DNS.2 = api-relay
DNS.3 = keycloak
DNS.4 = localhost
EOF

# ========== Main Process (Single General Certificate) ==========
echo "Generating general server certificate..."

# Step 1: Generate Private Key
openssl genpkey -algorithm RSA -out "$SERVER_CERT_DIR/private.key" -pkeyopt rsa_keygen_bits:2048

# Step 2: Create CSR
openssl req -new -key "$SERVER_CERT_DIR/private.key" \
  -out "$SERVER_CERT_DIR/request.csr" \
  -subj "/C=TW/ST=Taiwan/L=Taipei/O=AFS/OU=Server/CN=$IP"

# Step 3: Sign Certificate (Self-signed as CA for simplicity in this dev/stage setup)
openssl x509 -req -in "$SERVER_CERT_DIR/request.csr" \
  -signkey "$SERVER_CERT_DIR/private.key" \
  -out "$SERVER_CERT_DIR/certificate.crt" \
  -days $DAYS -sha256 -extfile "$EXT_TEMPLATE"

# Step 4: Verify SAN
echo "Verifying SAN..."
openssl x509 -in "$SERVER_CERT_DIR/certificate.crt" -noout -text | grep -A1 "Subject Alternative Name"

# Step 5: Generate PKCS12 Keystore
openssl pkcs12 -export \
  -in "$SERVER_CERT_DIR/certificate.crt" \
  -inkey "$SERVER_CERT_DIR/private.key" \
  -out "$SERVER_CERT_DIR/keystore.p12" \
  -name "server" \
  -passout pass:$PASSWORD

echo "Server certificate generated successfully in $SERVER_CERT_DIR"
echo "All certificates have been created successfully."

