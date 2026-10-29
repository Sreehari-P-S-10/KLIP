-- ==============================================================================
-- KLIP MIGRATION 02: Ingestion Staging, PII Vault & Audit Schema
-- Statutory Compliance: Digital Personal Data Protection Act, 2023 (Sec. 4, 6)
-- ==============================================================================

-- 1. Immutable Raw Ingestion Mirror (Zero Data Loss Architecture)
CREATE TABLE IF NOT EXISTS raw_staging.survey_submission_batch (
    batch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_name VARCHAR(255) NOT NULL,
    file_hash_sha256 VARCHAR(64) NOT NULL,
    total_sheets INT NOT NULL DEFAULT 23,
    total_records INT NOT NULL DEFAULT 0,
    ingestion_mode VARCHAR(50) DEFAULT 'OFFLINE_ETL',
    ingested_by VARCHAR(100) DEFAULT 'SYSTEM',
    ingested_at TIMESTAMPTZ DEFAULT NOW(),
    status VARCHAR(30) DEFAULT 'COMPLETED'
);

CREATE TABLE IF NOT EXISTS raw_staging.survey_raw_record (
    record_id BIGSERIAL PRIMARY KEY,
    batch_id UUID REFERENCES raw_staging.survey_submission_batch(batch_id) ON DELETE CASCADE,
    sheet_name VARCHAR(100) NOT NULL,
    row_index INT NOT NULL,
    submission_uuid VARCHAR(100),
    parent_submission_uuid VARCHAR(100),
    payload_json JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_raw_submission_uuid ON raw_staging.survey_raw_record(submission_uuid);
CREATE INDEX IF NOT EXISTS idx_raw_sheet_name ON raw_staging.survey_raw_record(sheet_name);
CREATE INDEX IF NOT EXISTS idx_raw_payload_gin ON raw_staging.survey_raw_record USING GIN(payload_json);

-- 2. DPDP High-Security Isolated PII Vault
-- Only accessed during authenticated citizen sessions or authorized field visits
CREATE TABLE IF NOT EXISTS pii_vault.household_identity (
    household_uuid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_uuid VARCHAR(100) UNIQUE,              -- KoBoToolbox _uuid foreign linkage
    head_name_encrypted BYTEA,                         -- AES-256 encrypted using PII_AES_KEY
    house_name_number_encrypted BYTEA,                 -- Address / House number encrypted
    mobile_hash VARCHAR(64) NOT NULL,                  -- SHA-256(mobile + PII_PEPPER_KEY) for O(1) lookup
    mobile_encrypted BYTEA NOT NULL,                   -- Reversible AES-256 for SMS OTP delivery
    surveyor_name_encrypted BYTEA,                     -- Enumerator identity encrypted
    surveyor_phone_encrypted BYTEA,                    -- Enumerator contact encrypted
    mgnregs_jobcard_encrypted BYTEA,                   -- Job card identifier encrypted
    revenue_survey_no VARCHAR(100),                    -- Cadastral survey number
    exact_geom GEOMETRY(Point, 4326),                  -- Raw precision GPS coordinate (restricted)
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pii_mobile_hash ON pii_vault.household_identity(mobile_hash);
CREATE INDEX IF NOT EXISTS idx_pii_submission_uuid ON pii_vault.household_identity(submission_uuid);

-- 3. Append-Only Change Data Capture & Audit Log
CREATE TABLE IF NOT EXISTS audit.data_change_log (
    log_id BIGSERIAL PRIMARY KEY,
    schema_name VARCHAR(50) NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    record_uuid UUID,
    action VARCHAR(20) NOT NULL,                       -- INSERT, UPDATE, DELETE
    old_values JSONB,
    new_values JSONB,
    performed_by VARCHAR(100) NOT NULL,
    client_ip VARCHAR(50),
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS audit.access_audit_log (
    access_id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(100) NOT NULL,
    user_role VARCHAR(50) NOT NULL,
    accessed_schema VARCHAR(50) NOT NULL,
    accessed_table VARCHAR(100) NOT NULL,
    access_type VARCHAR(30) NOT NULL,                  -- 'PII_READ', 'CITIZEN_LOGIN', 'PLANNER_EXPORT'
    ward_filter VARCHAR(40),
    justification TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_table ON audit.data_change_log(table_name, record_uuid);
CREATE INDEX IF NOT EXISTS idx_audit_time ON audit.data_change_log(timestamp);
