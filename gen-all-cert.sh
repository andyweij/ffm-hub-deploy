#!/bin/bash

# ========== Basic Configuration ==========
PASSWORD="changeit"
DAYS=3650
IP=$(curl -s ifconfig.me)
SERVICES=("aiportal" "api-relay" "keycloak")
EXT_TEMPLATE="./certs/v3_ext_template.ext"

# ========== Clean Previous Output ==========
rm -rf ./certs
mkdir -p certs

# ========== Create v3_ca.ext Template ==========
cat > $EXT_TEMPLATE <<EOF
basicConstraints = critical,CA:TRUE
keyUsage = critical, digitalSignature, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
subjectAltName = IP:$IP
EOF

# ========== Main Process ==========
for service in "${SERVICES[@]}"; do
  echo "Generating certificate for: $service"

  TARGET_DIR="./certs/$service"
  mkdir -p "$TARGET_DIR"

  # Step 1: Generate Private Key
  openssl genpkey -algorithm RSA -out "$TARGET_DIR/private.key" -pkeyopt rsa_keygen_bits:2048

  # Step 2: Create CSR
  openssl req -new -key "$TARGET_DIR/private.key" \
    -out "$TARGET_DIR/request.csr" \
    -subj "/C=TW/ST=Taiwan/L=Taipei/O=FFM/OU=$service/CN=$IP"

  # Step 3: Sign Certificate
  openssl x509 -req -in "$TARGET_DIR/request.csr" \
    -signkey "$TARGET_DIR/private.key" \
    -out "$TARGET_DIR/certificate.crt" \
    -days $DAYS -sha256 -extfile "$EXT_TEMPLATE"

  # Step 4: Verify SAN
  openssl x509 -in "$TARGET_DIR/certificate.crt" -noout -text | grep -A1 "Subject Alternative Name"

  # Step 5: Generate PKCS12 Keystore
  openssl pkcs12 -export \
    -in "$TARGET_DIR/certificate.crt" \
    -inkey "$TARGET_DIR/private.key" \
    -out "$TARGET_DIR/keystore.p12" \
    -name "$service" \
    -passout pass:$PASSWORD

  # Step 6: Convert to JKS Keystore (Optional)
#  keytool -importkeystore \
#    -destkeystore "$TARGET_DIR/keystore.jks" \
#    -srckeystore "$TARGET_DIR/keystore.p12" \
#    -srcstoretype PKCS12 \
#    -alias "$service" \
#    -deststorepass $PASSWORD \
#    -srcstorepass $PASSWORD

  # Step 7: Export PEM
#  openssl x509 -in "$TARGET_DIR/certificate.crt" -out "$TARGET_DIR/certificate.pem" -outform PEM

  echo "$service certificate generated successfully"
done

# ========== Check if keytool is Installed ==========
#if ! command -v keytool &> /dev/null; then
#  echo "keytool not found. Installing OpenJDK..."
#  sudo apt update
#  sudo apt install default-jdk -y
#else
#  echo "keytool already installed. Skipping installation."
#fi

# ========== Create Truststores ==========
#echo "Creating truststores..."

# aiportal imports api-relay certificate
#keytool -importcert -file ./certs/api-relay/certificate.pem -alias api-relay \
#  -keystore ./certs/aiportal/truststore.jks -storepass $PASSWORD -noprompt

# api-relay imports keycloak certificate
#keytool -importcert -file ./certs/keycloak/certificate.pem -alias keycloak \
#  -keystore ./certs/api-relay/truststore.jks -storepass $PASSWORD -noprompt

echo "All certificates have been created successfully."
