-- ==============================================================================
-- KLIP MIGRATION 07: Analytics, Indicator Catalogue & 4-Stage Governance
-- Enforces the Anti-Hallucination Covenant & Human-in-the-Loop Lifecycle
-- ==============================================================================

-- 1. Master Indicator Catalogue (42 Strategic Planning Indicators)
CREATE TABLE IF NOT EXISTS analytics.indicator_catalogue (
    indicator_code VARCHAR(60) PRIMARY KEY,           -- e.g. 'IND-WATER-01'
    sector VARCHAR(50) NOT NULL,                      -- WATER, EMPLOYMENT, HEALTH, HOUSING, AGRI
    name_en VARCHAR(200) NOT NULL,
    name_ml VARCHAR(200) NOT NULL,
    definition_formula TEXT NOT NULL,
    target_direction VARCHAR(20) NOT NULL,            -- 'LOWER_IS_BETTER' or 'HIGHER_IS_BETTER'
    critical_threshold NUMERIC(8,2) NOT NULL,         -- e.g. 35.0 (% households)
    threshold_source VARCHAR(100) NOT NULL,           -- 'NITI_AAYOG_SDG', 'LSGD_BENCHMARK', 'PANCHAYAT_TARGET'
    denominator_description TEXT NOT NULL
);

-- 2. Stage 1: Detected Patterns (Deterministic Statistical & Spatial Flags)
CREATE TABLE IF NOT EXISTS analytics.detected_pattern (
    pattern_id BIGSERIAL PRIMARY KEY,
    discovery_engine VARCHAR(50) NOT NULL,            -- 'RULE_ENGINE', 'STAT_DEVIATION', 'GEOSPATIAL_HOTSPOT', 'TEXT_TOPIC'
    ward_id VARCHAR(40) REFERENCES core.ward(ward_id),
    indicator_code VARCHAR(60) REFERENCES analytics.indicator_catalogue(indicator_code),
    observed_value NUMERIC(10,2),
    benchmark_value NUMERIC(10,2),
    deviation_score NUMERIC(8,2),                     -- Z-score or IQR distance
    affected_households_count INT,
    detected_at TIMESTAMPTZ DEFAULT NOW(),
    status VARCHAR(30) DEFAULT 'ACTIVE'               -- ACTIVE, FUSED, EXPIRED
);

CREATE INDEX IF NOT EXISTS idx_pattern_ward ON analytics.detected_pattern(ward_id);
CREATE INDEX IF NOT EXISTS idx_pattern_indicator ON analytics.detected_pattern(indicator_code);

-- 3. Stage 2: Issue Candidate Object (Synthesized Policy Hypotheses)
CREATE TABLE IF NOT EXISTS analytics.issue_candidate (
    candidate_id VARCHAR(60) PRIMARY KEY,             -- e.g. 'CAND-KANJIKUZHI-2026-0001'
    ward_id VARCHAR(40) REFERENCES core.ward(ward_id),
    primary_domain VARCHAR(50) NOT NULL,
    summary_title_en VARCHAR(255) NOT NULL,
    summary_title_ml VARCHAR(255) NOT NULL,
    evidence_package_json JSONB NOT NULL,             -- Fused counts, statistics, and citations (Zero PII)
    evidence_strength VARCHAR(50) NOT NULL,           -- 'HIGH_CONFIDENCE_COMBINED', 'MODERATE_DATA_ONLY', 'EMERGING_CITIZEN_VOICE'
    suggested_schemes JSONB,                          -- Matched scheme IDs and excerpt references
    llm_explanation_en TEXT,                          -- Grounded policy briefing note
    llm_explanation_ml TEXT,
    known_limitations TEXT NOT NULL,                  -- Explicit data caveats and sample bounds
    current_status VARCHAR(40) DEFAULT 'REVIEW_REQUIRED', -- REVIEW_REQUIRED, VERIFIED_PROBLEM, OFFICIAL_RECOMMENDATION, REJECTED, DEFERRED
    assigned_reviewer VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_candidate_ward ON analytics.issue_candidate(ward_id);
CREATE INDEX IF NOT EXISTS idx_candidate_status ON analytics.issue_candidate(current_status);

-- 4. Stage 3 & 4: Panchayat Recommendation Lifecycle Audit
CREATE TABLE IF NOT EXISTS analytics.recommendation_lifecycle_log (
    log_id BIGSERIAL PRIMARY KEY,
    candidate_id VARCHAR(60) REFERENCES analytics.issue_candidate(candidate_id) ON DELETE CASCADE,
    previous_status VARCHAR(40),
    new_status VARCHAR(40) NOT NULL,
    changed_by_user VARCHAR(100) NOT NULL,
    panchayat_resolution_ref VARCHAR(100),            -- Council resolution number
    review_comments TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lifecycle_cand ON analytics.recommendation_lifecycle_log(candidate_id);

-- 5. High-Speed Pre-Aggregated Materialized Views for Dashboards
-- Ward General Socio-Economic Summary
CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.mv_ward_summary AS
SELECT 
    w.ward_id,
    w.ward_number,
    w.ward_name_en,
    w.ward_name_ml,
    COUNT(DISTINCT h.household_uuid) AS total_households,
    COUNT(DISTINCT p.person_id) AS total_population,
    COUNT(DISTINCT CASE WHEN hp.ration_card_type IN ('AAY_YELLOW', 'PHH_PINK') THEN h.household_uuid END) AS bpl_households,
    COUNT(DISTINCT CASE WHEN hp.has_open_well = TRUE THEN h.household_uuid END) AS households_with_well,
    COUNT(DISTINCT CASE WHEN hp.has_homestead_pond = TRUE THEN h.household_uuid END) AS households_with_pond,
    COUNT(DISTINCT CASE WHEN hp.has_sacred_grove_kaavu = TRUE THEN h.household_uuid END) AS households_with_kaavu,
    COUNT(DISTINCT CASE WHEN hp.mgnregs_active_members > 0 THEN h.household_uuid END) AS mgnregs_registered_households
FROM core.ward w
LEFT JOIN core.household h ON w.ward_id = h.ward_id AND h.is_active = TRUE
LEFT JOIN core.household_profile hp ON h.household_uuid = hp.household_uuid
LEFT JOIN core.person p ON h.household_uuid = p.household_uuid
GROUP BY w.ward_id, w.ward_number, w.ward_name_en, w.ward_name_ml;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_ward_id ON analytics.mv_ward_summary(ward_id);

-- Ward Chronic Health Burden Aggregate (With k-anonymity masking safeguard)
CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.mv_ward_health_summary AS
SELECT 
    w.ward_id,
    w.ward_number,
    w.ward_name_en,
    w.ward_name_ml,
    hc.condition_category,
    COUNT(hc.case_id) AS raw_case_count,
    -- Apply k-anonymity (mask counts < 5 to protect individual privacy in small wards)
    CASE 
        WHEN COUNT(hc.case_id) > 0 AND COUNT(hc.case_id) < 5 THEN -1 
        ELSE COUNT(hc.case_id) 
    END AS masked_case_count
FROM core.ward w
JOIN core.household h ON w.ward_id = h.ward_id AND h.is_active = TRUE
JOIN core.health_condition_case hc ON h.household_uuid = hc.household_uuid
GROUP BY w.ward_id, w.ward_number, w.ward_name_en, w.ward_name_ml, hc.condition_category;

CREATE INDEX IF NOT EXISTS idx_mv_health_ward_cat ON analytics.mv_ward_health_summary(ward_id, condition_category);
