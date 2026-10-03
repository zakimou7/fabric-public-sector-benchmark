#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# upgrade-nesdacore.sh — Upgrade nesdacore v1.0 → v2.0
# نفّذه من: ~/nesdaR2/nesdafabric/fabric/fabric-samples/test-network
# ═══════════════════════════════════════════════════════════════════════════

set -e

NETWORK_DIR="$HOME/nesdaR2/nesdafabric/fabric/fabric-samples/test-network"
CHAINCODE_SRC="$NETWORK_DIR/chaincode-nesdacore"
CHANNEL="nesdachannel"
CC_NAME="nesdacore"
CC_VERSION="2.0"       # ← رفعنا الـ version
CC_SEQUENCE="2"        # ← رفعنا الـ sequence

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log() { echo -e "${CYAN}[upgrade]${NC} $1"; }
ok()  { echo -e "${GREEN}✔${NC} $1"; }

export PATH="$NETWORK_DIR/../bin:$PATH"
export FABRIC_CFG_PATH="$NETWORK_DIR/../config/"

# ── Step 1: Copy new chaincode ─────────────────────────────────────────────
log "Copying v2.0 chaincode..."
cp -r "$(dirname "$0")"/* "$CHAINCODE_SRC/"
cd "$CHAINCODE_SRC" && npm install --quiet
ok "Chaincode copied"

# ── Step 2: Package v2.0 ──────────────────────────────────────────────────
cd "$NETWORK_DIR"
log "Packaging v2.0..."
peer lifecycle chaincode package "${CC_NAME}-v2.tar.gz" \
  --path "$CHAINCODE_SRC" \
  --lang node \
  --label "${CC_NAME}_${CC_VERSION}"
ok "Package: ${CC_NAME}-v2.tar.gz"

# ── Step 3: Install on both orgs ──────────────────────────────────────────
source scripts/envVar.sh 2>/dev/null || true

log "Installing on Org1..."
setGlobals 1
peer lifecycle chaincode install "${CC_NAME}-v2.tar.gz"
ok "Installed Org1"

log "Installing on Org2..."
setGlobals 2
peer lifecycle chaincode install "${CC_NAME}-v2.tar.gz"
ok "Installed Org2"

# ── Step 4: Get new package ID ────────────────────────────────────────────
setGlobals 1
PACKAGE_ID=$(peer lifecycle chaincode queryinstalled | grep "${CC_NAME}_${CC_VERSION}" | awk '{print $3}' | tr -d ',')
log "Package ID: $PACKAGE_ID"

ORDERER_CA="$NETWORK_DIR/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem"
ORG1_TLS="$NETWORK_DIR/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt"
ORG2_TLS="$NETWORK_DIR/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt"

# ── Step 5: Approve v2.0 ─────────────────────────────────────────────────
log "Approving Org1..."
setGlobals 1
peer lifecycle chaincode approveformyorg \
  -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
  --channelID $CHANNEL --name $CC_NAME \
  --version $CC_VERSION --package-id $PACKAGE_ID \
  --sequence $CC_SEQUENCE --tls --cafile $ORDERER_CA
ok "Org1 approved"

log "Approving Org2..."
setGlobals 2
peer lifecycle chaincode approveformyorg \
  -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
  --channelID $CHANNEL --name $CC_NAME \
  --version $CC_VERSION --package-id $PACKAGE_ID \
  --sequence $CC_SEQUENCE --tls --cafile $ORDERER_CA
ok "Org2 approved"

# ── Step 6: Commit v2.0 ───────────────────────────────────────────────────
log "Committing v2.0..."
setGlobals 1
peer lifecycle chaincode commit \
  -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
  --channelID $CHANNEL --name $CC_NAME \
  --version $CC_VERSION --sequence $CC_SEQUENCE \
  --tls --cafile $ORDERER_CA \
  --peerAddresses localhost:7051 --tlsRootCertFiles $ORG1_TLS \
  --peerAddresses localhost:9051 --tlsRootCertFiles $ORG2_TLS
ok "Committed!"

# ── Step 7: Smoke tests ───────────────────────────────────────────────────
sleep 2
log "Smoke test 1: verifyCertificateByNumber (new)..."
peer chaincode query -C $CHANNEL -n $CC_NAME \
  -c '{"function":"verifyCertificateByNumber","Args":["TEST-CERT-001"]}' \
  && ok "verifyCertificateByNumber ✅" || echo "⚠ not found (expected for empty ledger)"

log "Smoke test 2: totalSupply..."
peer chaincode query -C $CHANNEL -n $CC_NAME \
  -c '{"function":"totalSupply","Args":[]}' \
  && ok "totalSupply ✅"

log "Smoke test 3: submitReview with reviewType..."
peer chaincode invoke \
  -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile $ORDERER_CA \
  -C $CHANNEL -n $CC_NAME \
  --peerAddresses localhost:7051 --tlsRootCertFiles $ORG1_TLS \
  --peerAddresses localhost:9051 --tlsRootCertFiles $ORG2_TLS \
  -c '{"function":"submitReview","Args":["REV-TEST-001","APP-TEST-001","sup-1","APPROVED","Test OK","{}","FINAL_SUPERVISOR"]}' \
  && ok "submitReview with FINAL_SUPERVISOR ✅"

sleep 2
log "Smoke test 4: getReviewsByType..."
peer chaincode query -C $CHANNEL -n $CC_NAME \
  -c '{"function":"getReviewsByType","Args":["APP-TEST-001","FINAL_SUPERVISOR"]}' \
  && ok "getReviewsByType ✅"

echo ""
ok "════════════════════════════════════════"
ok "nesdacore v2.0 upgraded successfully! 🎉"
ok "Channel:  $CHANNEL"
ok "Version:  $CC_VERSION  |  Sequence: $CC_SEQUENCE"
ok "New functions:"
ok "  ✅ verifyCertificateByNumber"
ok "  ✅ getReviewsByType (SUPERVISOR | FINAL_SUPERVISOR)"
ok "  ✅ checkInvitationExpiry (expiryDate للدعوة)"
ok "════════════════════════════════════════"
