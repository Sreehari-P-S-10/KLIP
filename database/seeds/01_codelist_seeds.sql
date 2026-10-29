-- ==============================================================================
-- KLIP SEED DATA: Panchayat, 19 Wards & Bilingual Codelists
-- System Master Specification v1.0
-- ==============================================================================

-- 1. Panchayat Baseline
INSERT INTO core.panchayat (panchayat_id, name_en, name_ml, district, block)
VALUES ('KL-ALP-KANJIKUZHI', 'Kanjikuzhi', 'കഞ്ഞിക്കുഴി', 'Alappuzha', 'Kanjikuzhi')
ON CONFLICT (panchayat_id) DO NOTHING;

-- 2. Official 19 Wards of Kanjikuzhi Grama Panchayat
INSERT INTO core.ward (ward_id, panchayat_id, ward_number, ward_name_en, ward_name_ml, pilot_active) VALUES
('KANJIKUZHI-W01', 'KL-ALP-KANJIKUZHI', 1,  'Ward 1 - Cheruvaipu',          'വാർഡ് 1 - ചെറുവൈപ്പ്',         FALSE),
('KANJIKUZHI-W02', 'KL-ALP-KANJIKUZHI', 2,  'Ward 2 - Puthenkavu',          'വാർഡ് 2 - പുത്തൻകാവ്',         FALSE),
('KANJIKUZHI-W03', 'KL-ALP-KANJIKUZHI', 3,  'Ward 3 - Kumarakapuram',       'വാർഡ് 3 - കുമാരപുരം',         FALSE),
('KANJIKUZHI-W04', 'KL-ALP-KANJIKUZHI', 4,  'Ward 4 - Kanjikkuzhi Central',  'വാർഡ് 4 - കഞ്ഞിക്കുഴി സെൻട്രൽ', FALSE),
('KANJIKUZHI-W05', 'KL-ALP-KANJIKUZHI', 5,  'Ward 5 - Chirakkal',           'വാർഡ് 5 - ചിറക്കൽ',          FALSE),
('KANJIKUZHI-W06', 'KL-ALP-KANJIKUZHI', 6,  'Ward 6 - Thannermukkom Road',  'വാർഡ് 6 - തണ്ണീർമുക്കം റോഡ്',  FALSE),
('KANJIKUZHI-W07', 'KL-ALP-KANJIKUZHI', 7,  'Ward 7 - Kannarkad (Pilot)',   'വാർഡ് 7 - കണ്ണാർകാട് (പൈലറ്റ്)', TRUE),
('KANJIKUZHI-W08', 'KL-ALP-KANJIKUZHI', 8,  'Ward 8 - Kalathil',            'വാർഡ് 8 - കളത്തിൽ',           FALSE),
('KANJIKUZHI-W09', 'KL-ALP-KANJIKUZHI', 9,  'Ward 9 - SN Puram North',      'വാർഡ് 9 - എസ്.എൻ. പുരം വടക്ക്', FALSE),
('KANJIKUZHI-W10', 'KL-ALP-KANJIKUZHI', 10, 'Ward 10 - SN Puram South',     'വാർഡ് 10 - എസ്.എൻ. പുരം തെക്ക്', FALSE),
('KANJIKUZHI-W11', 'KL-ALP-KANJIKUZHI', 11, 'Ward 11 - Mayithara East',     'വാർഡ് 11 - മായിത്തറ കിഴക്ക്',    FALSE),
('KANJIKUZHI-W12', 'KL-ALP-KANJIKUZHI', 12, 'Ward 12 - Mayithara West',     'വാർഡ് 12 - മായിത്തറ പടിഞ്ഞാറ്',  FALSE),
('KANJIKUZHI-W13', 'KL-ALP-KANJIKUZHI', 13, 'Ward 13 - Illikkal',           'വാർഡ് 13 - ഇല്ലിക്കൽ',         FALSE),
('KANJIKUZHI-W14', 'KL-ALP-KANJIKUZHI', 14, 'Ward 14 - Kottamkulangara',    'വാർഡ് 14 - കൊറ്റംകുളങ്ങര',     FALSE),
('KANJIKUZHI-W15', 'KL-ALP-KANJIKUZHI', 15, 'Ward 15 - Muhamma Road',       'വാർഡ് 15 - മുഹമ്മ റോഡ്',      FALSE),
('KANJIKUZHI-W16', 'KL-ALP-KANJIKUZHI', 16, 'Ward 16 - Varanam North',      'വാർഡ് 16 - വാരണം വടക്ക്',      FALSE),
('KANJIKUZHI-W17', 'KL-ALP-KANJIKUZHI', 17, 'Ward 17 - Varanam South',      'വാർഡ് 17 - വാരണം തെക്ക്',      FALSE),
('KANJIKUZHI-W18', 'KL-ALP-KANJIKUZHI', 18, 'Ward 18 - Maruthorvattom East','വാർഡ് 18 - മരുത്തോർവട്ടം കിഴക്ക്', FALSE),
('KANJIKUZHI-W19', 'KL-ALP-KANJIKUZHI', 19, 'Ward 19 - Railway Station Road','വാർഡ് 19 - റെയിൽവേ സ്റ്റേഷൻ റോഡ്', FALSE)
ON CONFLICT (panchayat_id, ward_number) DO UPDATE SET 
    ward_name_en = EXCLUDED.ward_name_en,
    ward_name_ml = EXCLUDED.ward_name_ml,
    pilot_active = EXCLUDED.pilot_active;

-- 3. Bilingual Codelist Dictionary Entries
-- Ration Card Types (Section A)
INSERT INTO core.codelist_choice (codelist_name, code, label_ml, label_en, sort_order) VALUES
('RATION_CARD_TYPE', 'AAY_YELLOW', 'മഞ്ഞ കാർഡ് (AAY - അന്ത്യോദയ അന്നയോജന)', 'Yellow Card (Antyodaya Anna Yojana)', 1),
('RATION_CARD_TYPE', 'PHH_PINK',   'പിങ്ക് കാർഡ് (PHH - മുൻഗണന വിഭാഗം)',     'Pink Card (Priority Household)', 2),
('RATION_CARD_TYPE', 'NPHH_BLUE',  'നീല കാർഡ് (NPHH - സബ്‌സിഡി രഹിത മുൻഗണനേതര വിഭാഗം)', 'Blue Card (Non-Priority Subsidy)', 3),
('RATION_CARD_TYPE', 'NPS_WHITE',  'വെള്ള കാർഡ് (NPS - പൊതുവിഭാഗം)',          'White Card (Non-Priority Non-Subsidy)', 4),
('RATION_CARD_TYPE', 'NONE',       'റേഷൻ കാർഡില്ലാത്തവർ',                     'No Ration Card', 5)
ON CONFLICT (codelist_name, code) DO NOTHING;

-- House Ownership Types (Section A 5)
INSERT INTO core.codelist_choice (codelist_name, code, label_ml, label_en, sort_order) VALUES
('HOUSE_OWNERSHIP', 'OWNED',       'സ്വന്തം വീട്',       'Owned House', 1),
('HOUSE_OWNERSHIP', 'RENTED',      'വാടക വീട്',        'Rented House', 2),
('HOUSE_OWNERSHIP', 'PURAMBOKE',   'പുറമ്പോക്ക് / കോളനി', 'Puramboke / Government Land', 3),
('HOUSE_OWNERSHIP', 'RELATIVE',    'ബന്ധുവിന്റെ വീട്',    'Relative''s House', 4),
('HOUSE_OWNERSHIP', 'OTHER',       'മറ്റുള്ളവ',          'Other', 5)
ON CONFLICT (codelist_name, code) DO NOTHING;

-- Roof Types (Section A 8)
INSERT INTO core.codelist_choice (codelist_name, code, label_ml, label_en, sort_order) VALUES
('ROOF_TYPE', 'CONCRETE',  'കോൺക്രീറ്റ് മേൽക്കൂര', 'Concrete Roof', 1),
('ROOF_TYPE', 'TILED',     'ഓട് മേഞ്ഞ മേൽക്കൂര',    'Tiled Roof', 2),
('ROOF_TYPE', 'SHEET',     'ഷീറ്റ് / ആസ്ബറ്റോസ്',   'Sheet / Asbestos Roof', 3),
('ROOF_TYPE', 'THATCHED',  'ഓല / പുല്ല് മേഞ്ഞത്',  'Thatched Roof (Kutcha)', 4)
ON CONFLICT (codelist_name, code) DO NOTHING;

-- Relationship to Head of Household (Section B 1)
INSERT INTO core.codelist_choice (codelist_name, code, label_ml, label_en, sort_order) VALUES
('RELATIONSHIP_TO_HEAD', 'HEAD',         'കുടുംബനാഥൻ / കുടുംബനാഥ', 'Head of Household', 1),
('RELATIONSHIP_TO_HEAD', 'SPOUSE',       'ഭാര്യ / ഭർത്താവ്',         'Spouse', 2),
('RELATIONSHIP_TO_HEAD', 'SON',          'മകൻ',                     'Son', 3),
('RELATIONSHIP_TO_HEAD', 'DAUGHTER',     'മകൾ',                     'Daughter', 4),
('RELATIONSHIP_TO_HEAD', 'PARENT',       'അച്ഛൻ / അമ്മ',             'Parent', 5),
('RELATIONSHIP_TO_HEAD', 'SIBLING',      'സഹോദരൻ / സഹോദരി',        'Brother / Sister', 6),
('RELATIONSHIP_TO_HEAD', 'DAUGHTER_IN_LAW','മരുമകൾ',                 'Daughter-in-Law', 7),
('RELATIONSHIP_TO_HEAD', 'SON_IN_LAW',   'മരുമകൻ',                 'Son-in-Law', 8),
('RELATIONSHIP_TO_HEAD', 'GRANDCHILD',   'പേരക്കുട്ടി',              'Grandchild', 9),
('RELATIONSHIP_TO_HEAD', 'OTHER',        'മറ്റുള്ളവർ',              'Other Relative', 10)
ON CONFLICT (codelist_name, code) DO NOTHING;

-- Gender (Section B 2)
INSERT INTO core.codelist_choice (codelist_name, code, label_ml, label_en, sort_order) VALUES
('GENDER', 'MALE',        'പുരുഷൻ',        'Male', 1),
('GENDER', 'FEMALE',      'സ്ത്രീ',          'Female', 2),
('GENDER', 'TRANSGENDER', 'ട്രാൻസ്ജെൻഡർ',  'Transgender', 3)
ON CONFLICT (codelist_name, code) DO NOTHING;

-- Social Category (Section B 5)
INSERT INTO core.codelist_choice (codelist_name, code, label_ml, label_en, sort_order) VALUES
('SOCIAL_CATEGORY', 'GENERAL', 'ജനറൽ (General)', 'General Category', 1),
('SOCIAL_CATEGORY', 'OBC',     'ഒ.ബി.സി (OBC)',   'Other Backward Classes', 2),
('SOCIAL_CATEGORY', 'SC',      'പട്ടികജാതി (SC)',  'Scheduled Caste', 3),
('SOCIAL_CATEGORY', 'ST',      'പട്ടികവർഗ്ഗം (ST)', 'Scheduled Tribe', 4),
('SOCIAL_CATEGORY', 'OEC',     'ഒ.ഇ.സി (OEC)',   'Other Eligible Communities', 5)
ON CONFLICT (codelist_name, code) DO NOTHING;

-- Health Conditions (11 Repeat Sheets)
INSERT INTO core.codelist_choice (codelist_name, code, label_ml, label_en, sort_order) VALUES
('HEALTH_CONDITION', 'HYPERTENSION', 'രക്താതിമർദ്ദം (High Blood Pressure)', 'Hypertension', 1),
('HEALTH_CONDITION', 'DIABETES',     'പ്രമേഹം (Diabetes)',                 'Diabetes Mellitus', 2),
('HEALTH_CONDITION', 'CHOLESTEROL',  'കൊളസ്ട്രോൾ (Dyslipidemia)',          'Cholesterol', 3),
('HEALTH_CONDITION', 'CARDIAC',      'ഹൃദ്രോഗം (Cardiac Disorders)',       'Heart Diseases', 4),
('HEALTH_CONDITION', 'RESPIRATORY',  'ശ്വാസകോശ രോഗങ്ങൾ (Asthma / COPD)',     'Respiratory Illnesses', 5),
('HEALTH_CONDITION', 'CANCER',       'കാൻസർ (Oncology Conditions)',        'Cancer', 6),
('HEALTH_CONDITION', 'ARTHRITIS',    'സന്ധിവാതം (Arthritis / Joint Pain)',  'Arthritis', 7),
('HEALTH_CONDITION', 'RENAL',        'വൃക്കരോഗങ്ങൾ (Chronic Kidney Disease)', 'Kidney Diseases', 8),
('HEALTH_CONDITION', 'HEPATIC',      'കരൾ രോഗങ്ങൾ (Liver Diseases)',        'Liver Diseases', 9),
('HEALTH_CONDITION', 'PARALYSIS',    'പക്ഷാഘാതം (Paralysis / Stroke)',      'Paralysis', 10),
('HEALTH_CONDITION', 'MENTAL_HEALTH','മാനസികാരോഗ്യ വെല്ലുവിളികൾ',          'Mental Health Challenges', 11)
ON CONFLICT (codelist_name, code) DO NOTHING;

-- 4. Initial Indicator Catalogue Seeds (Key Planning Benchmarks)
INSERT INTO analytics.indicator_catalogue 
(indicator_code, sector, name_en, name_ml, definition_formula, target_direction, critical_threshold, threshold_source, denominator_description)
VALUES
('IND-WATER-01', 'WATER', 
 'Drinking Water Scarcity Ratio', 
 'വേനൽക്കാല കുടിവെള്ള ക്ഷാമമുള്ള കുടുംബങ്ങളുടെ നിരക്ക്', 
 '(households_with_summer_scarcity / total_households) * 100', 
 'LOWER_IS_BETTER', 25.00, 'LSGD_BENCHMARK', 'Total surveyed households in ward'),

('IND-HOUSING-01', 'HOUSING', 
 'Dilapidated / Kutcha Housing Ratio', 
 'വാസയോഗ്യമല്ലാത്തതോ ഷീറ്റ്/ഓല മേഞ്ഞതോ ആയ വീടുകളുടെ നിരക്ക്', 
 '(households_kutcha_or_sheet / total_households) * 100', 
 'LOWER_IS_BETTER', 15.00, 'LIFE_MISSION_TARGET', 'Total surveyed households in ward'),

('IND-EMPLOY-01', 'EMPLOYMENT', 
 'Educated Youth Unemployment Ratio', 
 'ഉന്നത വിദ്യാഭ്യാസം നേടിയിട്ടും തൊഴിൽരഹിതരായ യുവാക്കളുടെ നിരക്ക്', 
 '(unemployed_graduates_age_18_35 / total_youth_graduates) * 100', 
 'LOWER_IS_BETTER', 20.00, 'KDISC_YIP_BENCHMARK', 'Total population aged 18-35 with degree/diploma in ward'),

('IND-HEALTH-01', 'HEALTH', 
 'Non-Communicable Disease Prevalence', 
 'ജീവിതശൈലീ രോഗ ബാധിതരുടെ നിരക്ക്', 
 '(total_ncd_diagnosed_cases / total_population) * 100', 
 'LOWER_IS_BETTER', 30.00, 'ARDRAM_MISSION_BENCHMARK', 'Total enumerated individuals in ward'),

('IND-HEALTH-02', 'HEALTH', 
 'Cancer Case Ward Concentration', 
 'കാൻസർ രോഗ ബാധിതരുടെ സാന്ദ്രത', 
 '(total_cancer_cases / total_population) * 1000', 
 'LOWER_IS_BETTER', 5.00, 'DISTRICT_HEALTH_AVERAGE', 'Cases per 1,000 population in ward'),

('IND-AGRI-01', 'AGRI', 
 'Fallow / Uncultivated Arable Land Ratio', 
 'തരിശിട്ടിരിക്കുന്ന കൃഷിഭൂമിയുടെ നിരക്ക്', 
 '(uncultivated_land_cents / total_owned_land_cents) * 100', 
 'LOWER_IS_BETTER', 30.00, 'SUBHIKSHA_KERALAM_TARGET', 'Total agricultural land area in ward')
ON CONFLICT (indicator_code) DO NOTHING;
