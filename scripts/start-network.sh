#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# NESDA — Hyperledger Fabric Network Startup Script
# Starts a minimal 1-org, 1-peer, 1-orderer network for benchmarking
# ═══════════════════════════════════════════════════════════════════════════

set -e

FABRIC_VERSION="2.5.0"
CA_VERSION="1.5.7"
CHANNEL_NAME="nesdachannel"
CHAINCODE_NAME="documentregistry"
CHAINCODE_PATH="./chaincode/documentregistry"
CHAINCODE_VERSION="1.0"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[NESDA-FABRIC]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Step 1: Check prerequisites ─────────────────────────────────────────────
log "Checking prerequisites..."
command -v docker >/dev/null 2>&1 || error "Docker not installed. Run: sudo apt install docker.io -y"
command -v docker-compose >/dev/null 2>&1 || error "Docker Compose not installed."
command -v peer >/dev/null 2>&1 || warn "Fabric binaries not in PATH. Run install-fabric.sh first."

# ── Step 2: Pull Fabric test network if not exists ──────────────────────────
if [ ! -d "fabric-samples" ]; then
  log "Downloading Fabric samples..."
  curl -sSL https://bit.ly/2ysbOFE | bash -s -- $FABRIC_VERSION $CA_VERSION
fi

# ── Step 3: Start network using test-network ────────────────────────────────
log "Starting Fabric network..."
cd fabric-samples/test-network

./network.sh down 2>/dev/null || true
./network.sh up createChannel -c $CHANNEL_NAME -ca

log "Network started. Channel: $CHANNEL_NAME"

# ── Step 4: Install and commit chaincode ───────────────────────────────────
log "Deploying DocumentRegistry chaincode..."

# Copy chaincode to test-network location
cp -r ../../chaincode/documentregistry ./chaincode-nesda

./network.sh deployCC \
  -ccn $CHAINCODE_NAME \
  -ccp ./chaincode-nesda \
  -ccl javascript \
  -c $CHANNEL_NAME

log "✅ Chaincode deployed: $CHAINCODE_NAME"

# ── Step 5: Test the chaincode ──────────────────────────────────────────────
log "Testing chaincode..."

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

# Test anchor
peer chaincode invoke \
  -o localhost:7050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile "${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem" \
  -C $CHANNEL_NAME \
  -n $CHAINCODE_NAME \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles "${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt" \
  -c '{"function":"anchor","Args":["testhash123","QmTestCID123"]}'

sleep 3

# Test verify
peer chaincode query \
  -C $CHANNEL_NAME \
  -n $CHAINCODE_NAME \
  -c '{"function":"verify","Args":["testhash123"]}'

log "✅ Chaincode test passed!"
log ""
log "═══════════════════════════════════════════════════════"
log "Network is running! Connection details:"
log "  Peer endpoint  : localhost:7051"
log "  Orderer        : localhost:7050"
log "  Channel        : $CHANNEL_NAME"
log "  Chaincode      : $CHAINCODE_NAME"
log ""
log "Connection profile saved at:"
log "  fabric-samples/test-network/organizations/peerOrganizations/"
log "    org1.example.com/connection-org1.json"
log "═══════════════════════════════════════════════════════"
