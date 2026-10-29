-- ==============================================================================
-- KLIP MIGRATION 05: Agriculture, Livestock, Fisheries & Citizen Feedback
-- Maps other_agri, sea_fisher_details, micro-enterprises & citizen voice channels
-- ==============================================================================

-- 1. Agricultural Land & Cultivation Summary
CREATE TABLE IF NOT EXISTS core.agri_land_summary (
    land_id BIGSERIAL PRIMARY KEY,
    household_uuid UUID REFERENCES core.household(household_uuid) ON DELETE CASCADE,
    tenure_type VARCHAR(40) NOT NULL,                 -- OWNED_CULTIVATED, OWNED_UNCULTIVATED, LEASED_IN
    area_cents NUMERIC(8,2) NOT NULL,
    irrigation_source VARCHAR(50),                    -- OPEN_WELL, BOREWELL, CANAL, RAINFED
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Crop Production & Seasonal Farming (other_agri sheet)
CREATE TABLE IF NOT EXISTS core.crop_record (
    crop_id BIGSERIAL PRIMARY KEY,
    household_uuid UUID REFERENCES core.household(household_uuid) ON DELETE CASCADE,
    crop_name VARCHAR(100) NOT NULL,                  -- PADDY, COCONUT, BANANA, TUBERS, VEGETABLES, BETEL_VINE
    cultivated_area_cents NUMERIC(8,2),
    production_qty_raw NUMERIC(10,2),
    unit_of_measure VARCHAR(30),                      -- KG, NUMBER, TONNES
    major_marketing_barrier VARCHAR(100),             -- LOW_PRICE, LACK_OF_STORAGE, INTERMEDIARIES, TRANSPORT
    affected_by_wild_animals BOOLEAN DEFAULT FALSE,
    crop_insurance_enrolled BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_crop_name ON core.crop_record(crop_name);

-- 3. Livestock & Animal Husbandry
CREATE TABLE IF NOT EXISTS core.livestock_record (
    livestock_id BIGSERIAL PRIMARY KEY,
    household_uuid UUID REFERENCES core.household(household_uuid) ON DELETE CASCADE,
    animal_type VARCHAR(50) NOT NULL,                 -- COW, BUFFALO, GOAT, POULTRY, DUCK
    head_count INT NOT NULL DEFAULT 1,
    daily_milk_yield_litres NUMERIC(6,2),
    marketing_channel VARCHAR(50),                    -- MILMA_SOCIETY, LOCAL_CONSUMERS, PRIVATE_DAIRY
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_livestock_type ON core.livestock_record(animal_type);

-- 4. Marine & Inland Fisheries (sea_fisher_details sheet)
CREATE TABLE IF NOT EXISTS core.fisheries_record (
    fishery_id BIGSERIAL PRIMARY KEY,
    household_uuid UUID REFERENCES core.household(household_uuid) ON DELETE CASCADE,
    fishing_type VARCHAR(50) NOT NULL,                -- MARINE, INLAND_BACKWATER, PRAWN_FARMING, AQUACULTURE
    owns_craft_gear BOOLEAN DEFAULT FALSE,
    matsyaboard_registered BOOLEAN DEFAULT FALSE,
    lean_season_distress BOOLEAN DEFAULT FALSE,
    monthly_fishing_income NUMERIC(10,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fisheries_type ON core.fisheries_record(fishing_type);

-- 5. Micro-Enterprises & Livelihood Units (begin_repeat_U43y2Rngg sheet)
CREATE TABLE IF NOT EXISTS core.enterprise_record (
    enterprise_id BIGSERIAL PRIMARY KEY,
    household_uuid UUID REFERENCES core.household(household_uuid) ON DELETE CASCADE,
    enterprise_name_masked VARCHAR(100),
    activity_sector VARCHAR(60) NOT NULL,             -- AGRO_PROCESSING, COIR, TEXTILES, RETAIL, FOOD_SERVICE, IT
    is_udyam_registered BOOLEAN DEFAULT FALSE,
    employment_count INT DEFAULT 1,
    major_challenge VARCHAR(100),                     -- CAPITAL, MARKETING, RAW_MATERIALS, SKILLED_LABOUR
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Citizen Stated Channel (Survey Feedback + Ongoing Citizen Portal)
CREATE TABLE IF NOT EXISTS core.citizen_concern (
    concern_id BIGSERIAL PRIMARY KEY,
    household_uuid UUID REFERENCES core.household(household_uuid) ON DELETE CASCADE,
    ward_id VARCHAR(40) REFERENCES core.ward(ward_id),
    channel VARCHAR(30) NOT NULL,                     -- 'ENUMERATOR_SURVEY', 'CITIZEN_PORTAL', 'WHISPER_VOICE'
    category_code VARCHAR(60) NOT NULL,               -- 'WATER_SCARCITY', 'WATERLOGGING', 'WASTE_DUMP', 'ROADS', 'UNEMPLOYMENT', 'HEALTHCARE'
    concern_text_original TEXT NOT NULL,              -- Original Unicode Malayalam / English text
    concern_text_sanitized TEXT,                      -- PII-scrubbed text for topic clustering
    language_code VARCHAR(10) DEFAULT 'ml',
    urgency_level VARCHAR(20) DEFAULT 'MEDIUM',       -- LOW, MEDIUM, HIGH, CRITICAL
    status VARCHAR(30) DEFAULT 'SUBMITTED',           -- SUBMITTED, UNDER_REVIEW, CONSOLIDATED, RESOLVED
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_concern_ward ON core.citizen_concern(ward_id);
CREATE INDEX IF NOT EXISTS idx_concern_category ON core.citizen_concern(category_code);
