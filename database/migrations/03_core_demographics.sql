-- ==============================================================================
-- KLIP MIGRATION 03: Core Normalized Demographics & Household Profiles
-- Maps Survey Sections A & B (Main Sheet + family_member_details + outside_members)
-- ==============================================================================

-- 1. Geographical Hierarchy
CREATE TABLE IF NOT EXISTS core.panchayat (
    panchayat_id VARCHAR(30) PRIMARY KEY,              -- 'KL-ALP-KANJIKUZHI'
    name_en VARCHAR(100) NOT NULL,
    name_ml VARCHAR(100) NOT NULL,
    district VARCHAR(50) NOT NULL,
    block VARCHAR(50) NOT NULL,
    boundary GEOMETRY(MultiPolygon, 4326),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS core.ward (
    ward_id VARCHAR(40) PRIMARY KEY,                  -- 'KANJIKUZHI-W01' to 'KANJIKUZHI-W19'
    panchayat_id VARCHAR(30) REFERENCES core.panchayat(panchayat_id),
    ward_number INT NOT NULL,
    ward_name_en VARCHAR(100) NOT NULL,
    ward_name_ml VARCHAR(100) NOT NULL,
    pilot_active BOOLEAN DEFAULT FALSE,               -- Active pilot ward flag (e.g. Ward 7)
    boundary GEOMETRY(MultiPolygon, 4326),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_ward_num UNIQUE (panchayat_id, ward_number)
);

-- 2. Bilingual Codelist & Localization Dictionary
CREATE TABLE IF NOT EXISTS core.codelist_choice (
    codelist_id SERIAL PRIMARY KEY,
    codelist_name VARCHAR(60) NOT NULL,               -- e.g. 'RATION_CARD_TYPE', 'HOUSE_OWNERSHIP'
    code VARCHAR(60) NOT NULL,                        -- e.g. 'AAY_YELLOW', 'OWNED'
    label_ml VARCHAR(200) NOT NULL,                   -- e.g. 'മഞ്ഞ കാർഡ് (AAY)'
    label_en VARCHAR(200) NOT NULL,                   -- e.g. 'Yellow Card (Antyodaya Anna Yojana)'
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT uq_codelist_code UNIQUE (codelist_name, code)
);

CREATE INDEX IF NOT EXISTS idx_codelist_lookup ON core.codelist_choice(codelist_name, code);

-- 3. Household Anchor
CREATE TABLE IF NOT EXISTS core.household (
    household_uuid UUID PRIMARY KEY REFERENCES pii_vault.household_identity(household_uuid) ON DELETE CASCADE,
    ward_id VARCHAR(40) REFERENCES core.ward(ward_id),
    spatial_h3_res9 VARCHAR(15),                      -- Anonymized ~100m hexagonal spatial index
    created_wave INT DEFAULT 1,
    current_version INT DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_household_ward ON core.household(ward_id);

-- 4. Household Structural Profile (Section A: Pothu Vivarangal)
CREATE TABLE IF NOT EXISTS core.household_profile (
    profile_id BIGSERIAL PRIMARY KEY,
    household_uuid UUID REFERENCES core.household(household_uuid) ON DELETE CASCADE,
    house_ownership_code VARCHAR(40),                 -- OWNED, RENTED, PURAMBOKE, RELATIVE
    is_govt_scheme_house BOOLEAN DEFAULT FALSE,
    scheme_built_code VARCHAR(50),                    -- LIFE_MISSION, IAY, PMAY, NONE, OTHER
    house_area_sqft INT,                              -- A 6. വീടിന്റെ വിസ്തീർണ്ണം ചതുരശ്ര അടിയിൽ
    room_count INT,                                   -- A 7. മുറികളുടെ എണ്ണം
    roof_type_code VARCHAR(40),                       -- CONCRETE, TILED, SHEET, THATCHED
    land_area_cents NUMERIC(8,2),                     -- A 9. ഉടമസ്ഥതയിലുള്ള ഭൂമിയുടെ ആകെ (സെന്റ്)
    land_outside_panchayat_cents NUMERIC(8,2),        -- A 9.1 ബ്ലോക്കിന് പുറത്തുള്ള ഭൂമി
    has_sacred_grove_kaavu BOOLEAN DEFAULT FALSE,     -- A 10. കാവ്
    has_homestead_pond BOOLEAN DEFAULT FALSE,         -- A 11. കുളം
    has_open_well BOOLEAN DEFAULT FALSE,              -- A 12. കിണർ
    has_borewell BOOLEAN DEFAULT FALSE,               -- A 13. കുഴൽക്കിണർ
    ration_card_type VARCHAR(40),                     -- A 14. AAY_YELLOW, PHH_PINK, NPHH_BLUE, NPS_WHITE
    has_study_laptop BOOLEAN DEFAULT FALSE,           -- A 15. ലാപ്‌ടോപ്പ്
    has_broadband BOOLEAN DEFAULT FALSE,              -- A 16. ബ്രോഡ് ബാൻഡ്
    broadband_provider VARCHAR(50),                   -- KFON, BSNL, CABLE, OTHER
    mgnregs_active_members INT DEFAULT 0,             -- A 17. തൊഴിലുറപ്പ് അംഗത്വം
    recorded_member_count INT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_profile_ration ON core.household_profile(ration_card_type);
CREATE INDEX IF NOT EXISTS idx_profile_roof ON core.household_profile(roof_type_code);

-- 5. Household Utilities & Environmental Baseline
CREATE TABLE IF NOT EXISTS core.household_utilities (
    utility_id BIGSERIAL PRIMARY KEY,
    household_uuid UUID REFERENCES core.household(household_uuid) ON DELETE CASCADE,
    drinking_water_source VARCHAR(60),                -- OWN_WELL, PUBLIC_TAP, KWA_PIPE, WATER_KIOSK, NEIGHBOR_WELL
    drinking_water_adequacy VARCHAR(40),              -- YEAR_ROUND_ADEQUATE, SUMMER_SCARCE, CHRONIC_SCARCE
    toilet_type VARCHAR(50),                          -- FLUSH_SEPTIC, PIT_LATRINE, ECOSAN, NONE
    electricity_connected BOOLEAN DEFAULT TRUE,
    cooking_fuel_primary VARCHAR(40),                 -- LPG, BIOGAS, FIREWOOD, ELECTRIC
    waste_disposal_method VARCHAR(60),                -- COMPOST_BIN, BIO_GAS, HARITHA_KARMA_SENA, OPEN_BURNING
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Individual Family Members (Section B: family_member_details repeat sheet)
CREATE TABLE IF NOT EXISTS core.person (
    person_id BIGSERIAL PRIMARY KEY,
    household_uuid UUID REFERENCES core.household(household_uuid) ON DELETE CASCADE,
    survey_member_index INT,                          -- _index in Kobo repeat sheet
    relationship_to_head VARCHAR(50) NOT NULL,        -- HEAD, SPOUSE, SON, DAUGHTER, PARENT, etc.
    gender VARCHAR(20) NOT NULL,                      -- MALE, FEMALE, TRANSGENDER
    age INT,                                          -- B 3. പ്രായം
    birth_year INT,
    blood_group VARCHAR(15),                          -- B 4. രക്ത ഗ്രൂപ്പ്
    social_category VARCHAR(40),                      -- B 5. GENERAL, OBC, SC, ST, OEC
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_person_household ON core.person(household_uuid);
CREATE INDEX IF NOT EXISTS idx_person_gender_age ON core.person(gender, age);

-- 7. Person Education, Employment & Skill Status
CREATE TABLE IF NOT EXISTS core.person_wave_status (
    status_id BIGSERIAL PRIMARY KEY,
    person_id BIGINT REFERENCES core.person(person_id) ON DELETE CASCADE,
    highest_education VARCHAR(60),                    -- B 6. SSLC, PLUS_TWO, DIPLOMA, DEGREE, PG, PROFESSIONAL
    course_name VARCHAR(120),                         -- B 6.1 / B 6.2 കോഴ്സ്
    is_currently_studying BOOLEAN DEFAULT FALSE,      -- B 11. പഠിച്ചു കൊണ്ടിരിക്കുകയാണെങ്കിൽ
    study_institution_type VARCHAR(50),               -- GOVT, AIDED, PRIVATE, SELF_FINANCING
    institution_name VARCHAR(150),
    employment_status VARCHAR(60),                    -- B 10. REGULAR_SALARIED, SELF_EMPLOYED, CASUAL_LABOUR, UNEMPLOYED, RETIRED, HOMEMAKER
    unemployment_duration VARCHAR(60),                -- B 10.1
    unemployment_reason VARCHAR(150),                 -- B 10.2 (Health, marriage, caretaking, etc.)
    training_interested BOOLEAN DEFAULT FALSE,        -- B 10.3 / B 12
    training_sector_code VARCHAR(120),                -- B 12.1 നൈപുണ്യ വികസന മേഖല
    interested_in_local_jobs BOOLEAN DEFAULT FALSE,   -- B 10.4
    interested_in_new_enterprise BOOLEAN DEFAULT FALSE,-- B 10.5
    job_type_details VARCHAR(120),                    -- B 13 / B 13.1
    monthly_income NUMERIC(10,2),                     -- B 14. പ്രതിമാസ വരുമാനം
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_person_employment ON core.person_wave_status(employment_status);
CREATE INDEX IF NOT EXISTS idx_person_education ON core.person_wave_status(highest_education);

-- 8. Outside / Migrant Household Members (outside_members_repeat sheet)
CREATE TABLE IF NOT EXISTS core.outside_migrant_member (
    migrant_id BIGSERIAL PRIMARY KEY,
    household_uuid UUID REFERENCES core.household(household_uuid) ON DELETE CASCADE,
    survey_member_index INT,
    relationship_to_head VARCHAR(50),
    gender VARCHAR(20),
    age INT,
    destination_type VARCHAR(40),                     -- GULF, OTHER_COUNTRY, OTHER_STATE
    destination_place VARCHAR(100),
    occupation_abroad VARCHAR(120),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
