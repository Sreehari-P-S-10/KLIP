"""
KLIP ETL Declarative Survey Mappings
Contains bilingual dictionary mappings for:
1. Sheet names -> target relational entities
2. Question text -> English column names
3. Malayalam choices -> standardized enum codes
"""

SHEET_TARGETS = {
    "MAIN": "Kanjikuzhi Block Household  ...",
    "FAMILY": "family_member_details",
    "OUTSIDE": "outside_members_repeat",
    "DISABILITY": "disability_name_type",
    "PENSION": "pension_specify",
    "INSURANCE_DETAILS": "insurance_details",
    "INSURANCE_SCHEMES": "insurance_schemes",
    "AGRI": "other_agri",
    "FISHERIES": "sea_fisher_details",
    "ENTERPRISE": "begin_repeat_U43y2Rngg",
    "CIVIC_PARTICIPATION": "dev_participation",
    "ARTS_SPORTS": "arts_and_sports",
    # 11 Health sheets
    "HEALTH_BP": "bp_names",
    "HEALTH_DIABETES": "diabetes_names",
    "HEALTH_CHOLESTEROL": "cholesterol_names",
    "HEALTH_HEART": "heart_diseases_names",
    "HEALTH_LUNGS": "lungs_related_names",
    "HEALTH_CANCER": "cancer_names",
    "HEALTH_ARTHRITIS": "arthritis_names",
    "HEALTH_KIDNEY": "kidney_disease_names",
    "HEALTH_LIVER": "liver_disease_names",
    "HEALTH_PARALYSIS": "paralysis_names",
    "HEALTH_MENTAL": "mental_challenges_names"
}

HEALTH_SHEET_TO_CATEGORY = {
    "bp_names": "HYPERTENSION",
    "diabetes_names": "DIABETES",
    "cholesterol_names": "CHOLESTEROL",
    "heart_diseases_names": "CARDIAC",
    "lungs_related_names": "RESPIRATORY",
    "cancer_names": "CANCER",
    "arthritis_names": "ARTHRITIS",
    "kidney_disease_names": "RENAL",
    "liver_disease_names": "HEPATIC",
    "paralysis_names": "PARALYSIS",
    "mental_challenges_names": "MENTAL_HEALTH"
}

# ------------------------------------------------------------------------------
# Choice / Option Normalizers
# ------------------------------------------------------------------------------

def normalize_text(text: str) -> str:
    if not text:
        return ""
    return str(text).strip()

def map_boolean(val) -> bool:
    if val is None:
        return False
    s = str(val).strip().lower()
    return s in ['അതെ', 'yes', 'y', '1', 'true', 'ഉണ്ട്', 'ഉണ്ടായിരുന്നു']

def map_house_ownership(val: str) -> str:
    s = str(val).strip().lower() if val else ""
    if 'സ്വന്തം' in s or 'owned' in s:
        return 'OWNED'
    elif 'വാടക' in s or 'rent' in s:
        return 'RENTED'
    elif 'പുറമ്പോക്ക്' in s or 'puramboke' in s or 'കോളനി' in s:
        return 'PURAMBOKE'
    elif 'ബന്ധു' in s or 'relative' in s:
        return 'RELATIVE'
    return 'OTHER'

def map_roof_type(val: str) -> str:
    s = str(val).strip().lower() if val else ""
    if 'കോൺക്രീറ്റ്' in s or 'concrete' in s:
        return 'CONCRETE'
    elif 'ഓട്' in s or 'tiled' in s:
        return 'TILED'
    elif 'ഷീറ്റ്' in s or 'ആസ്ബറ്റോസ്' in s or 'sheet' in s:
        return 'SHEET'
    elif 'ഓല' in s or 'പുല്ല്' in s or 'thatched' in s:
        return 'THATCHED'
    return 'OTHER'

def map_ration_card(val: str) -> str:
    s = str(val).strip().lower() if val else ""
    if 'മഞ്ഞ' in s or 'aay' in s or 'അന്ത്യോദയ' in s:
        return 'AAY_YELLOW'
    elif 'പിങ്ക്' in s or 'phh' in s or 'മുൻഗണന' in s:
        return 'PHH_PINK'
    elif 'നീല' in s or 'nphh' in s:
        return 'NPHH_BLUE'
    elif 'വെള്ള' in s or 'nps' in s:
        return 'NPS_WHITE'
    return 'NONE'

def map_gender(val: str) -> str:
    s = str(val).strip().lower() if val else ""
    if 'സ്ത്രീ' in s or 'female' in s or 'f' == s:
        return 'FEMALE'
    elif 'പുരുഷൻ' in s or 'male' in s or 'm' == s:
        return 'MALE'
    elif 'ട്രാൻസ്' in s or 'trans' in s:
        return 'TRANSGENDER'
    return 'MALE'

def map_relationship(val: str) -> str:
    s = str(val).strip().lower() if val else ""
    if 'കുടുംബനാഥ' in s or 'head' in s:
        return 'HEAD'
    elif 'ഭാര്യ' in s or 'wife' in s:
        return 'SPOUSE'
    elif 'ഭർത്താവ്' in s or 'husband' in s:
        return 'SPOUSE'
    elif 'മകൻ' in s or 'son' in s:
        return 'SON'
    elif 'മകൾ' in s or 'daughter' in s:
        return 'DAUGHTER'
    elif 'അച്ഛൻ' in s or 'father' in s or 'അമ്മ' in s or 'mother' in s:
        return 'PARENT'
    elif 'സഹോദര' in s or 'brother' in s or 'sister' in s:
        return 'SIBLING'
    elif 'മരുമകൾ' in s:
        return 'DAUGHTER_IN_LAW'
    elif 'മരുമകൻ' in s:
        return 'SON_IN_LAW'
    elif 'പേരക്കുട്ടി' in s:
        return 'GRANDCHILD'
    return 'OTHER'

def map_social_category(val: str) -> str:
    s = str(val).strip().lower() if val else ""
    if 'പട്ടികജാതി' in s or 'sc' in s:
        return 'SC'
    elif 'പട്ടികവർഗ്ഗം' in s or 'st' in s:
        return 'ST'
    elif 'ഒ.ബി.സി' in s or 'obc' in s:
        return 'OBC'
    elif 'ഒ.ഇ.സി' in s or 'oec' in s:
        return 'OEC'
    return 'GENERAL'

def map_education(val: str) -> str:
    s = str(val).strip().lower() if val else ""
    if 'എസ്.എസ്.എൽ.സി' in s or 'sslc' in s or '10' in s:
        return 'SSLC'
    elif 'പ്ലസ് ടു' in s or 'plus two' in s or '+2' in s or '12' in s:
        return 'PLUS_TWO'
    elif 'ഡിപ്ലോമ' in s or 'diploma' in s or 'iti' in s:
        return 'DIPLOMA'
    elif 'ബിരുദം' in s or 'degree' in s or 'graduation' in s:
        return 'DEGREE'
    elif 'ബിരുദാനന്തര' in s or 'pg' in s or 'post graduate' in s:
        return 'POST_GRADUATE'
    elif 'പ്രൊഫഷണൽ' in s or 'engg' in s or 'medical' in s:
        return 'PROFESSIONAL'
    elif 'പ്രൈമറി' in s or 'primary' in s:
        return 'LOWER_PRIMARY'
    return 'OTHER'

def map_employment(val: str) -> str:
    s = str(val).strip().lower() if val else ""
    if 'സ്ഥിര' in s or 'regular' in s or 'salaried' in s:
        return 'REGULAR_SALARIED'
    elif 'സ്വയം' in s or 'self' in s or 'കച്ചവടം' in s:
        return 'SELF_EMPLOYED'
    elif 'കൂലി' in s or 'casual' in s or 'താൽക്കാലിക' in s:
        return 'CASUAL_LABOUR'
    elif 'തൊഴിലുറപ്പ്' in s or 'mgnregs' in s:
        return 'MGNREGS'
    elif 'തൊഴിൽരഹിത' in s or 'unemployed' in s:
        return 'UNEMPLOYED'
    elif 'വീട്ടമ്മ' in s or 'ഗൃഹനാഥ' in s or 'homemaker' in s:
        return 'HOMEMAKER'
    elif 'വിദ്യാർത്ഥി' in s or 'student' in s:
        return 'STUDENT'
    elif 'വിരമിച്ച' in s or 'retired' in s or 'പെൻഷൻ' in s:
        return 'RETIRED'
    return 'OTHER'

def map_age_band(age: int) -> str:
    if age is None:
        return 'UNKNOWN'
    try:
        a = int(age)
        if a <= 18:
            return '0-18'
        elif a <= 35:
            return '19-35'
        elif a <= 60:
            return '36-60'
        else:
            return '60+'
    except:
        return 'UNKNOWN'
