-- ==============================================================================
-- KLIP MIGRATION 06: Scheme Knowledge Base & Vector Indexing
-- Authoritative Central & Kerala State Welfare Schemes for Local RAG
-- ==============================================================================

-- 1. Master Scheme Repository
CREATE TABLE IF NOT EXISTS scheme_kb.scheme (
    scheme_id VARCHAR(60) PRIMARY KEY,                -- e.g. 'KL-LIFE-MISSION-2024'
    title_en VARCHAR(255) NOT NULL,
    title_ml VARCHAR(255) NOT NULL,
    sponsoring_agency VARCHAR(100) NOT NULL,          -- CENTRAL, STATE, PANCHAYAT, K-DISC, NABARD
    sector VARCHAR(60) NOT NULL,                      -- HOUSING, WATER, AGRI, LIVELIHOOD, HEALTH, SOCIAL_SECURITY
    target_criteria_json JSONB NOT NULL,              -- Machine-readable eligibility criteria
    benefits_summary TEXT NOT NULL,
    benefits_summary_ml TEXT,
    document_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_scheme_sector ON scheme_kb.scheme(sector);
CREATE INDEX IF NOT EXISTS idx_scheme_agency ON scheme_kb.scheme(sponsoring_agency);

-- 2. Scheme Document Chunks for Hybrid Retrieval (FTS + Dense Vector)
CREATE TABLE IF NOT EXISTS scheme_kb.scheme_chunk (
    chunk_id BIGSERIAL PRIMARY KEY,
    scheme_id VARCHAR(60) REFERENCES scheme_kb.scheme(scheme_id) ON DELETE CASCADE,
    chunk_text TEXT NOT NULL,
    chunk_text_ml TEXT,
    chunk_tokens INT,
    fts_tokens TSVECTOR GENERATED ALWAYS AS (
        to_tsvector('simple', chunk_text || ' ' || COALESCE(chunk_text_ml, ''))
    ) STORED
);

CREATE INDEX IF NOT EXISTS idx_scheme_chunk_fts ON scheme_kb.scheme_chunk USING GIN(fts_tokens);

-- Dynamically attach vector(1024) column if pgvector extension is available
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vector') THEN
        BEGIN
            ALTER TABLE scheme_kb.scheme_chunk ADD COLUMN IF NOT EXISTS embedding vector(1024);
            CREATE INDEX IF NOT EXISTS idx_scheme_vector_hnsw 
            ON scheme_kb.scheme_chunk USING hnsw (embedding vector_cosine_ops);
            RAISE NOTICE 'Vector column and HNSW index attached to scheme_kb.scheme_chunk';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not create HNSW index; vector column created without index.';
        END;
    ELSE
        RAISE NOTICE 'pgvector not installed; scheme_chunk will use FTS keywords and external vector store.';
    END IF;
END $$;
