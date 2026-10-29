-- ==============================================================================
-- KLIP MIGRATION 01: Extensions and Database Schemas
-- System Master Specification v1.0 / DPDP Act Compliant Dual-Database Architecture
-- ==============================================================================

-- 1. Enable Core Cryptographic & Spatial Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enable PostGIS for geospatial analysis (wards, coordinates, H3 indices)
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS postgis;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'PostGIS extension could not be loaded directly; continuing with standard geometry types.';
END $$;

-- Enable pgvector for scheme semantic retrieval (if installed)
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS vector;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pgvector extension not installed in environment; dense vector columns will use fallback numeric arrays if needed.';
END $$;

-- 2. Create Isolated Domain Schemas
-- raw_staging: Immutable audit mirror of uploaded survey spreadsheets
CREATE SCHEMA IF NOT EXISTS raw_staging;

-- pii_vault: Isolated high-security vault for encrypted identifiers & exact GPS
CREATE SCHEMA IF NOT EXISTS pii_vault;

-- core: Normalized socio-economic, demographic, agricultural & utility records
CREATE SCHEMA IF NOT EXISTS core;

-- scheme_kb: Government welfare schemes, guidelines, and search indices
CREATE SCHEMA IF NOT EXISTS scheme_kb;

-- analytics: Pre-aggregated indicator views, statistical anomalies & 4-stage lifecycle
CREATE SCHEMA IF NOT EXISTS analytics;

-- audit: Append-only triggers and administrative access tracking
CREATE SCHEMA IF NOT EXISTS audit;

COMMENT ON SCHEMA raw_staging IS 'Zero-loss immutable raw ingestion storage for survey spreadsheets';
COMMENT ON SCHEMA pii_vault IS 'DPDP Act protected PII vault with AES-256 encrypted personal identity data';
COMMENT ON SCHEMA core IS 'De-identified normalized relational domain models for local governance';
COMMENT ON SCHEMA scheme_kb IS 'Authoritative Central and Kerala state welfare scheme corpus';
COMMENT ON SCHEMA analytics IS 'Deterministic indicators, geospatial clusters, and issue candidate tracking';
COMMENT ON SCHEMA audit IS 'Append-only change data capture and compliance audit logs';
