'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// NESDA Core Chaincode — index.js
// ─────────────────────────────────────────────────────────────────────────────

const shim = require('fabric-shim');

const ApplicationRegistry  = require('./contracts/ApplicationRegistry');
const ReviewRegistry       = require('./contracts/ReviewRegistry');
const CertificateRegistry  = require('./contracts/CertificateRegistry');
const CertificateNFT       = require('./contracts/CertificateNFT');
const NotificationRegistry = require('./contracts/NotificationRegistry');

// Instantiate contracts
const appRegistry   = new ApplicationRegistry();
const revRegistry   = new ReviewRegistry();
const certRegistry  = new CertificateRegistry();
const nftRegistry   = new CertificateNFT();
const notifRegistry = new NotificationRegistry();

// ── Route table ──────────────────────────────────────────────────────────────
const ROUTES = {

  // ── Application ──
  submitApplication:         (s, p) => appRegistry.submitApplication(s, p),
  updateApplicationStatus:   (s, p) => appRegistry.updateApplicationStatus(s, p),
  getApplication:            (s, p) => appRegistry.getApplication(s, p),
  getApplicationHistory:     (s, p) => appRegistry.getApplicationHistory(s, p),
  getApplicationsByCandidate:(s, p) => appRegistry.getApplicationsByCandidate(s, p),
  verifyApplication:         (s, p) => appRegistry.verifyApplication(s, p),

  // ── Review ──
  submitReview:              (s, p) => revRegistry.submitReview(s, p),
  getReview:                 (s, p) => revRegistry.getReview(s, p),
  getReviewsByApplication:   (s, p) => revRegistry.getReviewsByApplication(s, p),
  getReviewsByType:          (s, p) => revRegistry.getReviewsByType(s, p),
  getReviewsBySupervisor:    (s, p) => revRegistry.getReviewsBySupervisor(s, p),
  verifyReview:              (s, p) => revRegistry.verifyReview(s, p),

  // ── Certificate ──
  issueCertificate:          (s, p) => certRegistry.issueCertificate(s, p),
  // FIX 1: alias "anchor" → issueCertificate (called by blockchain.ts gateway client)
  anchor:                    (s, p) => certRegistry.issueCertificate(s, p),
  linkNFT:                   (s, p) => certRegistry.linkNFT(s, p),
  revokeCertificate:         (s, p) => certRegistry.revokeCertificate(s, p),
  getCertificate:            (s, p) => certRegistry.getCertificate(s, p),
  verifyCertificate:         (s, p) => certRegistry.verifyCertificate(s, p),
  verifyCertificateBySHA256: (s, p) => certRegistry.verifyCertificateBySHA256(s, p),
  verifyCertificateByNumber: (s, p) => certRegistry.verifyCertificateByNumber(s, p),
  getCertificatesByHolder:   (s, p) => certRegistry.getCertificatesByHolder(s, p),
  getCertificateHistory:     (s, p) => certRegistry.getCertificateHistory(s, p),

  // ── NFT ──
  mintCertificateNFT:        (s, p) => nftRegistry.mintCertificateNFT(s, p),
  getNFT:                    (s, p) => nftRegistry.getNFT(s, p),
  getNFTByCertificate:       (s, p) => nftRegistry.getNFTByCertificate(s, p),
  getNFTsByOwner:            (s, p) => nftRegistry.getNFTsByOwner(s, p),
  verifyNFT:                 (s, p) => nftRegistry.verifyNFT(s, p),
  burnNFT:                   (s, p) => nftRegistry.burnNFT(s, p),
  totalSupply:               (s, p) => nftRegistry.totalSupply(s, p),

  // ── Notification ──
  logNotification:              (s, p) => notifRegistry.logNotification(s, p),
  checkInvitationExpiry:        (s, p) => notifRegistry.checkInvitationExpiry(s, p),
  getNotification:              (s, p) => notifRegistry.getNotification(s, p),
  getNotificationsByRecipient:  (s, p) => notifRegistry.getNotificationsByRecipient(s, p),
  getNotificationsByEntity:     (s, p) => notifRegistry.getNotificationsByEntity(s, p),
};

// ── Helper: safely convert any return value to a Buffer-ready string ─────────
// FIX 2: contracts may return string | object | undefined — normalise all cases
function toPayload(result) {
  if (result === undefined || result === null) return '{}';
  if (typeof result === 'string') return result;
  // object / array → JSON
  return JSON.stringify(result);
}

// ── Main Chaincode Class ─────────────────────────────────────────────────────
class NESDACore {

  async Init(stub) {
    const args = stub.getFunctionAndParameters();
    console.log('NESDACore chaincode initialized', args);
    return shim.success(Buffer.from('NESDACore initialized'));
  }

  async Invoke(stub) {
    const { fcn, params } = stub.getFunctionAndParameters();
    console.log(`[NESDACore] Invoke: ${fcn}`, params);

    const handler = ROUTES[fcn];

    if (!handler) {
      const errMsg = `Function "${fcn}" not found. Available: ${Object.keys(ROUTES).join(', ')}`;
      console.error(errMsg);
      // shim.error() requires a Buffer — was already correct, kept as-is
      return shim.error(Buffer.from(errMsg));
    }

    try {
      const result = await handler(stub, params);
      // FIX 2: use toPayload() so Buffer.from() always receives a string
      return shim.success(Buffer.from(toPayload(result)));
    } catch (err) {
      const msg = (err && err.message) ? err.message : String(err);
      console.error(`[NESDACore] Error in ${fcn}:`, msg);
      return shim.error(Buffer.from(msg));
    }
  }
}

shim.start(new NESDACore());