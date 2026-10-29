-- ==============================================================================
-- KLIP MIGRATION 04: Health Registers, Disability & Welfare Schemes
-- Compliant with National Health Data Management Policy (De-Linked Health Cases)
-- Covers 11 Health sheets, disability_name_type, pension_specify, insurance sheets
-- ==============================================================================

-- 1. De-Linked Non-Communicable & Chronic Health Case Register
-- Note: Does NOT point to person_id or citizen names; preserves privacy boundary
CREATE TABLE IF NOT EXISTS core.health_condition_case (
    case_id BIGSERIAL PRIMARY KEY,
    household_uuid UUID REFERENCES core.household(household_uuid) ON DELETE CASCADE,
    condition_category VARCHAR(50) NOT NULL,          -- HYPERTENSION, DIABETES, CHOLESTEROL, CARDIAC, RESPIRATORY, CANCER, ARTHRITIS, RENAL, HEPATIC, PARALYSIS, MENTAL_HEALTH
    condition_subtype VARCHAR(120),                   -- Specific diagnosis details (e.g. breast cancer, asthma)
    age INT,                                          -- Age at survey
    age_band VARCHAR(20),                             -- '0-18', '19-35', '36-60', '60+'
    gender VARCHAR(20),                               -- MALE, FEMALE, TRANSGENDER
    is_under_treatment BOOLEAN DEFAULT TRUE,
    notes TEXT,
    survey_sheet_source VARCHAR(60),                  -- e.g. 'cancer_names', 'bp_names'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_health_condition ON core.health_condition_case(condition_category);
CREATE INDEX IF NOT EXISTS idx_health_household ON core.health_condition_case(household_uuid);

-- 2. Disability Case Register (disability_name_type sheet)
CREATE TABLE IF NOT EXISTS core.disability_case (
    disability_id BIGSERIAL PRIMARY KEY,
    household_uuid UUID REFERENCES core.household(household_uuid) ON DELETE CASCADE,
    disability_category VARCHAR(60) NOT NULL,         -- LOCOMOTOR, VISUAL, HEARING, INTELLECTUAL, MULTIPLE, AUTISM, CEREBRAL_PALSY
    disability_type_details VARCHAR(150),
    percentage_band VARCHAR(30),                      -- 'BELOW_40', '40_TO_75', 'ABOVE_75'
    assistive_device_needed VARCHAR(150),
    has_udid_card BOOLEAN DEFAULT FALSE,
    receives_disability_pension BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_disability_cat ON core.disability_case(disability_category);

-- 3. Social Welfare Pensions (pension_specify sheet)
CREATE TABLE IF NOT EXISTS core.pension_record (
    pension_id BIGSERIAL PRIMARY KEY,
    household_uuid UUID REFERENCES core.household(household_uuid) ON DELETE CASCADE,
    pension_type VARCHAR(60) NOT NULL,                -- OLD_AGE, WIDOW, DISABILITY, AGRICULTURE_LABOUR, UNMARRIED_WOMEN, WEAVERS
    beneficiary_count INT DEFAULT 1,
    is_regularly_received BOOLEAN DEFAULT TRUE,
    remarks VARCHAR(150),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pension_type ON core.pension_record(pension_type);

-- 4. Health & Life Insurance Coverage (insurance_details & insurance_schemes sheets)
CREATE TABLE IF NOT EXISTS core.insurance_record (
    insurance_id BIGSERIAL PRIMARY KEY,
    household_uuid UUID REFERENCES core.household(household_uuid) ON DELETE CASCADE,
    scheme_name VARCHAR(100) NOT NULL,                -- MEDISEP, PMJAY_CHIS, KARUNYA_BENEVOLENT, RSBY, PRIVATE_HEALTH, LIFE_INSURANCE
    coverage_amount_band VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_insurance_scheme ON core.insurance_record(scheme_name);

-- 5. Civic Participation & Youth Development (dev_participation & arts_and_sports sheets)
CREATE TABLE IF NOT EXISTS core.civic_participation (
    participation_id BIGSERIAL PRIMARY KEY,
    household_uuid UUID REFERENCES core.household(household_uuid) ON DELETE CASCADE,
    organization_type VARCHAR(60) NOT NULL,           -- KUDUMBASHREE, GRAMA_SABHA, WARD_VIGILANCE, HARITHA_KARMA_SENA, YOUTH_CLUB
    has_active_membership BOOLEAN DEFAULT TRUE,
    member_count INT DEFAULT 1,
    has_sports_arts_talent BOOLEAN DEFAULT FALSE,
    talent_details VARCHAR(150),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
