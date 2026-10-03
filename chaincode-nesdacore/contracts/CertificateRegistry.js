'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// CertificateRegistry — يسجل الشهادات على Fabric
// يغطي: certificates + certificate_registrations من الـ schema
// Key format: CERT-{certId}
// ─────────────────────────────────────────────────────────────────────────────

class CertificateRegistry {

  // ── Issue a new certificate ─────────────────────────────────────────────
  async issueCertificate(stub, params) {
    if (params.length < 6) {
      throw new Error('issueCertificate: needs certId, holderId, holderName, certType, sha256, ipfsCid, [applicationId], [issuedBy], [metaJson]');
    }

    const [certId, holderId, holderName, certType, sha256, ipfsCid,
           applicationId = '', issuedBy = '', metaJson = '{}'] = params;

    // Check duplicate
    const existing = await stub.getState(`CERT-${certId}`);
    if (existing && existing.length > 0) {
      throw new Error(`Certificate ${certId} already exists on ledger`);
    }

    // Also check SHA256 uniqueness
    const sha256Index = await stub.getState(`CERTSHA-${sha256}`);
    if (sha256Index && sha256Index.length > 0) {
      throw new Error(`Certificate with SHA256 ${sha256} already exists on ledger`);
    }

    let meta = {};
    try { meta = JSON.parse(metaJson); } catch { meta = {}; }

    const cert = {
      certId,
      holderId,
      holderName,
      certType,                            // CDE | CFC | CAP | OTHER
      sha256,                              // hash of the PDF
      ipfsCid,                             // IPFS CID of the PDF
      applicationId,                       // linked application
      issuedBy,                            // admin/supervisor ID
      status: 'ISSUED',
      nftTokenId: null,                    // filled after mintNFT
      meta,                                // extra fields (wilaya, trainingCenter, etc.)
      issuedAt:  new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      txId:      stub.getTxID(),
    };

    await stub.putState(`CERT-${certId}`, Buffer.from(JSON.stringify(cert)));

    // SHA256 index for fast lookup
    await stub.putState(`CERTSHA-${sha256}`, Buffer.from(JSON.stringify({ certId, holderId })));

    // Certificate number index (رقم الشهادة الرسمي من meta)
    // meta.certificateNumber = رقم الشهادة اللي يدخله مشرف الشهادة
    const certNumber = meta.certificateNumber || meta.certificate_number || '';
    if (certNumber) {
      await stub.putState(
        `CERTNUM-${certNumber}`,
        Buffer.from(JSON.stringify({ certId, holderId, holderName, certType }))
      );
    }

    // Holder index: CERTOWNER-{holderId}-{certId}
    await stub.putState(
      `CERTOWNER-${holderId}-${certId}`,
      Buffer.from(JSON.stringify({ certId, holderId, certType, status: 'ISSUED' }))
    );

    stub.setEvent('CERTIFICATE_ISSUED', Buffer.from(JSON.stringify({
      certId, holderId, holderName, certType
    })));

    return JSON.stringify({ success: true, certId, txId: stub.getTxID() });
  }

  // ── Link NFT token to certificate ──────────────────────────────────────
  async linkNFT(stub, params) {
    if (params.length < 2) throw new Error('linkNFT: needs certId, nftTokenId');
    const [certId, nftTokenId] = params;

    const raw = await stub.getState(`CERT-${certId}`);
    if (!raw || raw.length === 0) throw new Error(`Certificate ${certId} not found`);

    const cert = JSON.parse(raw.toString());
    cert.nftTokenId = nftTokenId;
    cert.updatedAt = new Date().toISOString();

    await stub.putState(`CERT-${certId}`, Buffer.from(JSON.stringify(cert)));
    return JSON.stringify({ success: true, certId, nftTokenId });
  }

  // ── Revoke a certificate ────────────────────────────────────────────────
  async revokeCertificate(stub, params) {
    if (params.length < 2) throw new Error('revokeCertificate: needs certId, reason, [revokedBy]');
    const [certId, reason, revokedBy = ''] = params;

    const raw = await stub.getState(`CERT-${certId}`);
    if (!raw || raw.length === 0) throw new Error(`Certificate ${certId} not found`);

    const cert = JSON.parse(raw.toString());
    if (cert.status === 'REVOKED') throw new Error(`Certificate ${certId} is already revoked`);

    cert.status = 'REVOKED';
    cert.revokedAt = new Date().toISOString();
    cert.revokeReason = reason;
    cert.revokedBy = revokedBy;
    cert.updatedAt = new Date().toISOString();

    await stub.putState(`CERT-${certId}`, Buffer.from(JSON.stringify(cert)));
    stub.setEvent('CERTIFICATE_REVOKED', Buffer.from(JSON.stringify({ certId, reason, revokedBy })));

    return JSON.stringify({ success: true, certId, status: 'REVOKED' });
  }

  // ── Get single certificate ──────────────────────────────────────────────
  async getCertificate(stub, params) {
    if (params.length < 1) throw new Error('getCertificate: needs certId');
    const [certId] = params;

    const raw = await stub.getState(`CERT-${certId}`);
    if (!raw || raw.length === 0) throw new Error(`Certificate ${certId} not found`);

    return raw.toString();
  }

  // ── Verify certificate by ID ────────────────────────────────────────────
  async verifyCertificate(stub, params) {
    if (params.length < 1) throw new Error('verifyCertificate: needs certId');
    const [certId] = params;

    const raw = await stub.getState(`CERT-${certId}`);
    if (!raw || raw.length === 0) {
      return JSON.stringify({ verified: false, certId });
    }

    const cert = JSON.parse(raw.toString());
    return JSON.stringify({
      verified:    true,
      certId,
      holderName:  cert.holderName,
      certType:    cert.certType,
      status:      cert.status,
      issuedAt:    cert.issuedAt,
      nftTokenId:  cert.nftTokenId,
      txId:        cert.txId,
    });
  }

  // ── Verify certificate by SHA256 ────────────────────────────────────────
  async verifyCertificateBySHA256(stub, params) {
    if (params.length < 1) throw new Error('verifyCertificateBySHA256: needs sha256');
    const [sha256] = params;

    const indexRaw = await stub.getState(`CERTSHA-${sha256}`);
    if (!indexRaw || indexRaw.length === 0) {
      return JSON.stringify({ verified: false, sha256 });
    }

    const { certId } = JSON.parse(indexRaw.toString());
    const raw = await stub.getState(`CERT-${certId}`);
    if (!raw || raw.length === 0) return JSON.stringify({ verified: false, sha256 });

    const cert = JSON.parse(raw.toString());
    return JSON.stringify({
      verified:   true,
      certId,
      holderName: cert.holderName,
      certType:   cert.certType,
      status:     cert.status,
      issuedAt:   cert.issuedAt,
      ipfsCid:    cert.ipfsCid,
      nftTokenId: cert.nftTokenId,
      txId:       cert.txId,
    });
  }

  // ── Verify certificate by official number (رقم الشهادة الرسمي) ────────────
  // هذا هو التحقق اللي يستخدمه المترشح في بداية التسجيل
  async verifyCertificateByNumber(stub, params) {
    if (params.length < 1) throw new Error('verifyCertificateByNumber: needs certificateNumber');
    const [certificateNumber] = params;

    const indexRaw = await stub.getState(`CERTNUM-${certificateNumber}`);
    if (!indexRaw || indexRaw.length === 0) {
      return JSON.stringify({
        verified:  false,
        exists:    false,
        certificateNumber,
        message:   'رقم الشهادة غير موجود في قاعدة البيانات',
      });
    }

    const { certId, holderName, certType } = JSON.parse(indexRaw.toString());

    // Get full cert
    const raw = await stub.getState(`CERT-${certId}`);
    if (!raw || raw.length === 0) {
      return JSON.stringify({ verified: false, exists: false, certificateNumber });
    }

    const cert = JSON.parse(raw.toString());

    return JSON.stringify({
      verified:          cert.status === 'ISSUED',
      exists:            true,
      certificateNumber,
      certId,
      holderName,
      certType,
      status:            cert.status,
      issuedAt:          cert.issuedAt,
      wilaya:            cert.meta?.wilaya           || '',
      trainingCenter:    cert.meta?.trainingCenter   || '',
      nftTokenId:        cert.nftTokenId,
      // ⚠️ للأمان: ما نرجعوش SHA256 أو IPFS للعموم هنا
    });
  }

  // ── Get certificates by holder ──────────────────────────────────────────
  async getCertificatesByHolder(stub, params) {
    if (params.length < 1) throw new Error('getCertificatesByHolder: needs holderId');
    const [holderId] = params;

    const startKey = `CERTOWNER-${holderId}-`;
    const endKey   = `CERTOWNER-${holderId}-~`;
    const iterator = await stub.getStateByRange(startKey, endKey);

    const results = [];
    while (true) {
      const res = await iterator.next();
      if (res.value && res.value.value.toString()) {
        const idx = JSON.parse(res.value.value.toString());
        const raw = await stub.getState(`CERT-${idx.certId}`);
        if (raw && raw.length > 0) results.push(JSON.parse(raw.toString()));
      }
      if (res.done) { await iterator.close(); break; }
    }

    return JSON.stringify(results);
  }

  // ── Get full audit history for a certificate ────────────────────────────
  async getCertificateHistory(stub, params) {
    if (params.length < 1) throw new Error('getCertificateHistory: needs certId');
    const [certId] = params;

    const iterator = await stub.getHistoryForKey(`CERT-${certId}`);
    const results = [];

    while (true) {
      const res = await iterator.next();
      if (res.value && res.value.value.toString()) {
        results.push({
          txId:      res.value.tx_id,
          timestamp: new Date(res.value.timestamp.seconds.low * 1000).toISOString(),
          isDelete:  res.value.is_delete,
          data:      JSON.parse(res.value.value.toString()),
        });
      }
      if (res.done) { await iterator.close(); break; }
    }

    return JSON.stringify(results);
  }
}

module.exports = CertificateRegistry;
