-- ═══════════════════════════════════════════════════════════════════════════
-- NESDA v2 — Database Migration
-- Adds Fabric blockchain columns to existing Turso tables
-- Run: turso db shell <db-name> < migration.sql
-- ═══════════════════════════════════════════════════════════════════════════

-- ── applications ────────────────────────────────────────────────────────────
ALTER TABLE applications ADD COLUMN fabric_tx_hash TEXT;
ALTER TABLE applications ADD COLUMN fabric_status  TEXT DEFAULT 'NOT_SENT';
-- fabric_status: NOT_SENT | SUBMITTED | UNDER_REVIEW | APPROVED | REJECTED

-- ── reviews ─────────────────────────────────────────────────────────────────
ALTER TABLE reviews ADD COLUMN fabric_tx_hash TEXT;
ALTER TABLE reviews ADD COLUMN fabric_status  TEXT DEFAULT 'NOT_SENT';

-- ── notifications ────────────────────────────────────────────────────────────
ALTER TABLE notifications ADD COLUMN fabric_tx_hash TEXT;
ALTER TABLE notifications ADD COLUMN fabric_logged   INTEGER DEFAULT 0;

-- ── certificate_registrations ────────────────────────────────────────────────
-- (already has sha256, ipfs_cid, blockchain_tx, chain_status — extend for NFT)
ALTER TABLE certificate_registrations ADD COLUMN nft_token_id   TEXT;
ALTER TABLE certificate_registrations ADD COLUMN nft_minted_at  TEXT;
ALTER TABLE certificate_registrations ADD COLUMN nft_tx_hash    TEXT;
ALTER TABLE certificate_registrations ADD COLUMN cert_chain_id  TEXT;
-- cert_chain_id = the CERT-{id} key on Fabric

-- ── certificates ─────────────────────────────────────────────────────────────
ALTER TABLE certificates ADD COLUMN fabric_tx_hash TEXT;
ALTER TABLE certificates ADD COLUMN fabric_cert_id TEXT;
-- fabric_cert_id = the CERT-{id} key on Fabric

-- ── Indexes ──────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_applications_fabric  ON applications  (fabric_tx_hash);
CREATE INDEX IF NOT EXISTS idx_reviews_fabric        ON reviews        (fabric_tx_hash);
CREATE INDEX IF NOT EXISTS idx_certreg_nft          ON certificate_registrations (nft_token_id);
CREATE INDEX IF NOT EXISTS idx_certreg_cert_chain   ON certificate_registrations (cert_chain_id);
