#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# deploy-nesdacore.sh — Deploy nesdacore chaincode على nesdachannel
# Usage: ./deploy-nesdacore.sh
# ═══════════════════════════════════════════════════════════════════════════

set -e

NETWORK_DIR="$HOME/nesdaR2/nesdafabric/fabric/fabric-samples/test-network"
CHAINCODE_SRC="$HOME/nesdaR2/nesdafabric/fabric/fabric-samples/test-network/chaincode-nesdacore"
CHANNEL="nesdachannel"
CC_NAME="nesdacore"
CC_VERSION="1.0"
CC_SEQUENCE="1"

# ── Colors ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${CYAN}[nesdacore]${NC} $1"; }
ok()   { echo -e "${GREEN}✔${NC} $1"; }
fail() { echo -e "${RED}✘${NC} $1"; exit 1; }

# ── Step 0: Copy chaincode ───────────────────────────────────────────────────
log "Copying chaincode to $CHAINCODE_SRC ..."
mkdir -p "$CHAINCODE_SRC"
cp -r "$(dirname "$0")"/* "$CHAINCODE_SRC/"
cd "$CHAINCODE_SRC" && npm install --quiet
ok "Chaincode copied & npm installed"

# ── Step 1: Set env ──────────────────────────────────────────────────────────
cd "$NETWORK_DIR"
source scripts/envVar.sh 2>/dev/null || true

export PATH="$NETWORK_DIR/../bin:$PATH"
export FABRIC_CFG_PATH="$NETWORK_DIR/../config/"

# ── Step 2: Package ──────────────────────────────────────────────────────────
log "Packaging chaincode..."
peer lifecycle chaincode package "${CC_NAME}.tar.gz" \
  --path "$CHAINCODE_SRC" \
  --lang node \
  --label "${CC_NAME}_${CC_VERSION}"
ok "Package created: ${CC_NAME}.tar.gz"

# ── Step 3: Install on Org1 ──────────────────────────────────────────────────
log "Installing on Org1..."
setGlobals 1
peer lifecycle chaincode install "${CC_NAME}.tar.gz"
ok "Installed on Org1"

# ── Step 4: Install on Org2 ──────────────────────────────────────────────────
log "Installing on Org2..."
setGlobals 2
peer lifecycle chaincode install "${CC_NAME}.tar.gz"
ok "Installed on Org2"

# ── Step 5: Get package ID ───────────────────────────────────────────────────
setGlobals 1
PACKAGE_ID=$(peer lifecycle chaincode queryinstalled | grep "${CC_NAME}_${CC_VERSION}" | awk '{print $3}' | tr -d ',')
log "Package ID: $PACKAGE_ID"

# ── Step 6: Approve Org1 ────────────────────────────────────────────────────
log "Approving for Org1..."
peer lifecycle chaincode approveformyorg \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --channelID "$CHANNEL" \
  --name "$CC_NAME" \
  --version "$CC_VERSION" \
  --package-id "$PACKAGE_ID" \
  --sequence "$CC_SEQUENCE" \
  --tls \
  --cafile "${NETWORK_DIR}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"
ok "Org1 approved"

# ── Step 7: Approve Org2 ────────────────────────────────────────────────────
log "Approving for Org2..."
setGlobals 2
peer lifecycle chaincode approveformyorg \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --channelID "$CHANNEL" \
  --name "$CC_NAME" \
  --version "$CC_VERSION" \
  --package-id "$PACKAGE_ID" \
  --sequence "$CC_SEQUENCE" \
  --tls \
  --cafile "${NETWORK_DIR}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"
ok "Org2 approved"

# ── Step 8: Commit ───────────────────────────────────────────────────────────
log "Committing chaincode to $CHANNEL..."
setGlobals 1
peer lifecycle chaincode commit \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --channelID "$CHANNEL" \
  --name "$CC_NAME" \
  --version "$CC_VERSION" \
  --sequence "$CC_SEQUENCE" \
  --tls \
  --cafile "${NETWORK_DIR}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles "${NETWORK_DIR}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" \
  --peerAddresses localhost:9051 \
  --tlsRootCertFiles "${NETWORK_DIR}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"
ok "Chaincode committed!"

# ── Step 9: Quick smoke test ─────────────────────────────────────────────────
log "Smoke test: submitApplication..."
peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls \
  --cafile "${NETWORK_DIR}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" \
  -C "$CHANNEL" -n "$CC_NAME" \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles "${NETWORK_DIR}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" \
  --peerAddresses localhost:9051 \
  --tlsRootCertFiles "${NETWORK_DIR}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt" \
  -c '{"function":"submitApplication","Args":["TEST-001","candidate-1","CDE","[]"]}'
sleep 2

log "Smoke test: verifyApplication..."
peer chaincode query \
  -C "$CHANNEL" -n "$CC_NAME" \
  -c '{"function":"verifyApplication","Args":["TEST-001"]}'

echo ""
ok "═══════════════════════════════════════"
ok "nesdacore deployed successfully! 🎉"
ok "Channel:  $CHANNEL"
ok "Chaincode: $CC_NAME v$CC_VERSION"
ok "═══════════════════════════════════════"
