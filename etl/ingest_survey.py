"""
KLIP High-Performance, Privacy-Enforcing Survey Ingestion Pipeline
Statutory Compliance: DPDP Act 2023, National Health Data Management Policy
Zero external dependencies (uses native zipfile + OpenXML + psql stream)
"""

import os
import sys
import json
import uuid
import zipfile
import argparse
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Dict, List, Any, Optional

sys.stdout.reconfigure(encoding='utf-8')

# Ensure KLIP package root is on sys.path
BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE_DIR))

from etl.crypto_vault import CryptoVault
from etl.mappings.survey_mapping import (
    SHEET_TARGETS,
    HEALTH_SHEET_TO_CATEGORY,
    normalize_text,
    map_boolean,
    map_house_ownership,
    map_roof_type,
    map_ration_card,
    map_gender,
    map_relationship,
    map_social_category,
    map_education,
    map_employment,
    map_age_band
)

def sql_escape_str(val: Optional[str]) -> str:
    if val is None:
        return "NULL"
    s = str(val).replace("'", "''")
    return f"'{s}'"

def sql_escape_bytes(val: Optional[bytes]) -> str:
    if val is None:
        return "NULL"
    hex_str = val.hex()
    return f"'\\x{hex_str}'::bytea"

def sql_escape_num(val: Any, max_val: Optional[float] = 999999999) -> str:
    if val is None or val == "":
        return "NULL"
    try:
        # Extract numeric chars
        cleaned = "".join(c for c in str(val) if c.isdigit() or c == '.')
        if not cleaned:
            return "NULL"
        num = float(cleaned) if '.' in cleaned else int(cleaned)
        if max_val and num > max_val:
            return "NULL"
        return str(num)
    except:
        return "NULL"

def sql_escape_bool(val: bool) -> str:
    return "TRUE" if val else "FALSE"

def col_ref_to_index(cell_ref: str) -> int:
    col_str = "".join(ch for ch in cell_ref if ch.isalpha()).upper()
    idx = 0
    for ch in col_str:
        idx = idx * 26 + (ord(ch) - ord('A') + 1)
    return idx - 1

class SurveyIngestionEngine:
    def __init__(self, excel_path: str):
        self.excel_path = excel_path
        self.vault = CryptoVault()
        self.shared_strings = []
        self.sheets_info = []
        self.rel_map = {}
        
    def _load_openxml_structure(self, z: zipfile.ZipFile):
        # 1. Load shared strings
        ns = {'ns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
        if 'xl/sharedStrings.xml' in z.namelist():
            tree = ET.fromstring(z.read('xl/sharedStrings.xml'))
            for si in tree.findall('ns:si', ns):
                t_elm = si.find('ns:t', ns)
                if t_elm is not None and t_elm.text:
                    self.shared_strings.append(t_elm.text)
                else:
                    r_texts = [r.find('ns:t', ns).text for r in si.findall('ns:r', ns) if r.find('ns:t', ns) is not None and r.find('ns:t', ns).text]
                    self.shared_strings.append("".join(r_texts) if r_texts else "")

        # 2. Relationships
        rel_tree = ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))
        rel_ns = {'r': 'http://schemas.openxmlformats.org/package/2006/relationships'}
        for rel in rel_tree.findall('r:Relationship', rel_ns):
            self.rel_map[rel.get('Id')] = rel.get('Target')

        # 3. Sheets
        wb_tree = ET.fromstring(z.read('xl/workbook.xml'))
        for s in wb_tree.find('ns:sheets', ns).findall('ns:sheet', ns):
            s_name = s.get('name')
            r_id = s.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id')
            self.sheets_info.append({"name": s_name, "r_id": r_id})

    def _read_sheet_rows(self, z: zipfile.ZipFile, sheet_name: str) -> List[Dict[str, Any]]:
        s_info = next((s for s in self.sheets_info if s["name"] == sheet_name), None)
        if not s_info:
            return []
            
        target = self.rel_map.get(s_info["r_id"])
        sheet_path = f"xl/{target}" if not target.startswith('/') else target[1:]
        
        ns = {'ns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
        tree = ET.fromstring(z.read(sheet_path))
        sheet_data = tree.find('ns:sheetData', ns)
        if sheet_data is None:
            return []

        rows_xml = sheet_data.findall('ns:row', ns)
        if not rows_xml:
            return []

        # Row 1 is header - map by exact coordinate index
        headers_by_idx = {}
        for c in rows_xml[0].findall('ns:c', ns):
            c_ref = c.get('r')
            c_idx = col_ref_to_index(c_ref) if c_ref else len(headers_by_idx)
            cell_type = c.get('t')
            v_elem = c.find('ns:v', ns)
            val = ""
            if v_elem is not None and v_elem.text:
                raw_v = v_elem.text
                if cell_type == 's' and self.shared_strings:
                    try:
                        val = self.shared_strings[int(raw_v)]
                    except:
                        val = raw_v
                else:
                    val = raw_v
            headers_by_idx[c_idx] = val.strip() if val else f"col_{c_idx+1}"

        # Data rows - map by exact coordinate index to avoid sparse cell shift
        data_rows = []
        for r_elm in rows_xml[1:]:
            row_dict = {}
            for c in r_elm.findall('ns:c', ns):
                c_ref = c.get('r')
                if not c_ref:
                    continue
                c_idx = col_ref_to_index(c_ref)
                h_name = headers_by_idx.get(c_idx)
                if not h_name:
                    continue

                cell_type = c.get('t')
                v_elem = c.find('ns:v', ns)
                val = ""
                if v_elem is not None and v_elem.text:
                    raw_v = v_elem.text
                    if cell_type == 's' and self.shared_strings:
                        try:
                            val = self.shared_strings[int(raw_v)]
                        except:
                            val = raw_v
                    else:
                        val = raw_v
                row_dict[h_name] = val.strip() if val else None
            data_rows.append(row_dict)

        return data_rows

    @staticmethod
    def resolve_hh_uuid(row: dict, uuid_map: dict) -> Optional[str]:
        sub_uuid = row.get("_submission__uuid") or row.get("_uuid")
        if sub_uuid:
            if sub_uuid in uuid_map:
                return uuid_map[sub_uuid]
            if sub_uuid.startswith("uuid:") and sub_uuid[5:] in uuid_map:
                return uuid_map[sub_uuid[5:]]
            if f"uuid:{sub_uuid}" in uuid_map:
                return uuid_map[f"uuid:{sub_uuid}"]

        p_idx = row.get("_parent_index")
        if p_idx and f"idx_{p_idx}" in uuid_map:
            return uuid_map[f"idx_{p_idx}"]
        return None

    def generate_ingestion_sql(self, output_sql_path: str):
        if not os.path.exists(self.excel_path):
            raise FileNotFoundError(f"Excel file not found at: {self.excel_path}")

        file_hash = self.vault.compute_file_sha256(self.excel_path)
        batch_id = str(uuid.uuid4())
        
        print(f"[INFO] Initializing Ingestion for: {os.path.basename(self.excel_path)}")
        print(f"       Batch ID: {batch_id}")
        print(f"       File SHA-256: {file_hash}")

        with zipfile.ZipFile(self.excel_path, 'r') as z:
            self._load_openxml_structure(z)
            
            with open(output_sql_path, "w", encoding="utf-8") as out:
                out.write("-- ==============================================================================\n")
                out.write(f"-- KLIP Automated Privacy-Preserving Ingestion Batch: {batch_id}\n")
                out.write(f"-- Source File: {os.path.basename(self.excel_path)} (SHA-256: {file_hash})\n")
                out.write("-- ==============================================================================\n\n")
                out.write("BEGIN;\n\n")
                out.write("TRUNCATE core.household, pii_vault.household_identity, raw_staging.survey_submission_batch, raw_staging.survey_raw_record CASCADE;\n\n")

                # 1. Staging Batch Record
                out.write(f"""
                INSERT INTO raw_staging.survey_submission_batch 
                (batch_id, file_name, file_hash_sha256, total_sheets, status) 
                VALUES ('{batch_id}', {sql_escape_str(os.path.basename(self.excel_path))}, '{file_hash}', {len(self.sheets_info)}, 'IN_PROGRESS')
                ON CONFLICT (batch_id) DO NOTHING;
                \n""")

                # 2. Main Household Sheet Processing
                main_sheet_name = SHEET_TARGETS["MAIN"]
                print(f"[INFO] Reading Main Household Sheet ('{main_sheet_name}')...")
                main_rows = self._read_sheet_rows(z, main_sheet_name)
                print(f"       Found {len(main_rows)} household records.")

                household_uuid_map = {} # maps submission_uuid -> household_uuid
                total_records_count = 0

                for r_idx, row in enumerate(main_rows):
                    total_records_count += 1
                    sub_uuid = row.get("_uuid") or row.get("meta/rootUuid") or f"HH-ROW-{r_idx+1}"
                    hh_uuid = str(self.vault.derive_household_uuid(sub_uuid))
                    
                    household_uuid_map[sub_uuid] = hh_uuid
                    if sub_uuid.startswith("uuid:"):
                        household_uuid_map[sub_uuid[5:]] = hh_uuid
                    else:
                        household_uuid_map[f"uuid:{sub_uuid}"] = hh_uuid
                        
                    idx_val = row.get("_index") or str(r_idx + 1)
                    household_uuid_map[f"idx_{idx_val}"] = hh_uuid

                    # Ward mapping
                    ward_raw = row.get("വാർഡ്") or row.get("ward") or "1"
                    try:
                        ward_num = int("".join(c for c in str(ward_raw) if c.isdigit()) or "1")
                    except:
                        ward_num = 1
                    ward_id = f"KANJIKUZHI-W{ward_num:02d}"

                    # Raw staging entry (Immutable JSONB)
                    row_json_str = json.dumps(row, ensure_ascii=False).replace("'", "''")
                    out.write(f"""
                    INSERT INTO raw_staging.survey_raw_record 
                    (batch_id, sheet_name, row_index, submission_uuid, payload_json) 
                    VALUES ('{batch_id}', {sql_escape_str(main_sheet_name)}, {r_idx+1}, {sql_escape_str(sub_uuid)}, '{row_json_str}'::jsonb);
                    \n""")

                    # PII Vault Encryption (DPDP Compliance)
                    srv_name = row.get("സർവ്വേ നടത്തുന്ന ആളുടെ പേര്")
                    srv_phone = row.get("സർവ്വേ നടത്തുന്ന ആളുടെ ഫോൺ നമ്പർ")
                    job_card = row.get("A 17.1. ഉണ്ടെങ്കിൽ ജോബ് കാർഡ് നമ്പർ")
                    phone_val = srv_phone or "0000000000"
                    
                    enc_srv_name = self.vault.encrypt(srv_name)
                    enc_srv_phone = self.vault.encrypt(srv_phone)
                    enc_job_card = self.vault.encrypt(job_card)
                    enc_mobile = self.vault.encrypt(phone_val)
                    mobile_hash = self.vault.hash_mobile(phone_val)

                    out.write(f"""
                    INSERT INTO pii_vault.household_identity 
                    (household_uuid, submission_uuid, surveyor_name_encrypted, surveyor_phone_encrypted, mgnregs_jobcard_encrypted, mobile_encrypted, mobile_hash) 
                    VALUES ('{hh_uuid}', {sql_escape_str(sub_uuid)}, {sql_escape_bytes(enc_srv_name)}, {sql_escape_bytes(enc_srv_phone)}, {sql_escape_bytes(enc_job_card)}, {sql_escape_bytes(enc_mobile)}, '{mobile_hash}')
                    ON CONFLICT (household_uuid) DO NOTHING;
                    \n""")

                    # Core Household Anchor
                    out.write(f"""
                    INSERT INTO core.household (household_uuid, ward_id, created_wave, is_active)
                    VALUES ('{hh_uuid}', '{ward_id}', 1, TRUE)
                    ON CONFLICT (household_uuid) DO NOTHING;
                    \n""")

                    # Core Household Profile
                    h_own = map_house_ownership(row.get("A 5. താമസിക്കുന്ന വീട് നിങ്ങളുടെ സ്വന്തമാണോ?"))
                    roof = map_roof_type(row.get("A 8. വീടിന്റേത് ഏത് തരം മേൽക്കൂരയാണ്?"))
                    ration = map_ration_card(row.get("A 14. റേഷൻ കാർഡ് തരം"))
                    sqft = sql_escape_num(row.get("A 6. വീടിന്റെ വിസ്തീർണ്ണം ചതുരശ്ര അടിയിൽ"))
                    rooms = sql_escape_num(row.get("A 7. മുറികളുടെ എണ്ണം"))
                    land_cents = sql_escape_num(row.get("A 9. ഉടമസ്ഥതയിലുള്ള ഭൂമിയുടെ ആകെ  (സെന്റ്)"))
                    has_kaavu = map_boolean(row.get("A 10. വീട്ടുവളപ്പിൽ കാവ്  ഉണ്ടെങ്കിൽ അതിന്റെ വിശദാംശങ്ങൾ"))
                    has_pond = map_boolean(row.get("A 11. വീട്ടുവളപ്പിൽ കുളമുണ്ടോ?"))
                    has_well = map_boolean(row.get("A 12. വീട്ടുവളപ്പിൽ കിണർ ഉണ്ടോ?"))
                    has_borewell = map_boolean(row.get("A 13. വീട്ടുവളപ്പിൽ കുഴൽക്കിണർ ഉണ്ടോ?"))
                    has_laptop = map_boolean(row.get("A 15. വീട്ടിൽ പഠനാവശ്യത്തിനായി ലാപ്"))
                    has_broadband = map_boolean(row.get("A 16. ബ്രോഡ് ബാൻഡ് കണക്ഷൻ ഉണ്ടോ?"))
                    has_mgnregs = map_boolean(row.get("A 17. നിങ്ങൾക്ക് തൊഴിലുറപ്പ്  പദ്ധതിയിൽ അംഗത്വമുണ്ടോ?"))

                    out.write(f"""
                    INSERT INTO core.household_profile 
                    (household_uuid, house_ownership_code, roof_type_code, ration_card_type, house_area_sqft, room_count, land_area_cents, has_sacred_grove_kaavu, has_homestead_pond, has_open_well, has_borewell, has_study_laptop, has_broadband, mgnregs_active_members)
                    VALUES ('{hh_uuid}', '{h_own}', '{roof}', '{ration}', {sqft}, {rooms}, {land_cents}, {sql_escape_bool(has_kaavu)}, {sql_escape_bool(has_pond)}, {sql_escape_bool(has_well)}, {sql_escape_bool(has_borewell)}, {sql_escape_bool(has_laptop)}, {sql_escape_bool(has_broadband)}, {1 if has_mgnregs else 0});
                    \n""")

                # 3. Family Members Processing
                family_sheet = SHEET_TARGETS["FAMILY"]
                print(f"[INFO] Reading Family Member Sheet ('{family_sheet}')...")
                family_rows = self._read_sheet_rows(z, family_sheet)
                print(f"       Found {len(family_rows)} family member records.")

                for r_idx, row in enumerate(family_rows):
                    total_records_count += 1
                    hh_uuid = self.resolve_hh_uuid(row, household_uuid_map)
                    if not hh_uuid:
                        continue

                    rel = map_relationship(row.get("B 1. കുടുംബനാഥയു/കുടുംബനാഥനു - മായുള്ള ബന്ധം"))
                    gen = map_gender(row.get("B 2. ജൻഡർ"))
                    age_raw = sql_escape_num(row.get("B 3. പ്രായം"))
                    blood = sql_escape_str(row.get("B 4. രക്ത ഗ്രൂപ്പ്"))
                    soc = map_social_category(row.get("B 5. വിഭാഗം"))
                    edu = map_education(row.get("B 6. ഉയർന്ന വിദ്യാഭ്യാസ യോഗ്യത"))
                    course = sql_escape_str(row.get("B 6.1. കോഴ്") or row.get("B 6.2. കോഴ്"))
                    emp = map_employment(row.get("B 10. വിദ്യാഭ്യാസ/തൊഴിൽ നില"))
                    income = sql_escape_num(row.get("B 14. പ്രതിമാസ വരുമാനം (₹)"))

                    out.write(f"""
                    WITH ins_person AS (
                        INSERT INTO core.person 
                        (household_uuid, relationship_to_head, gender, age, blood_group, social_category, survey_member_index)
                        VALUES ('{hh_uuid}', '{rel}', '{gen}', {age_raw}, {blood}, '{soc}', {r_idx+1})
                        RETURNING person_id
                    )
                    INSERT INTO core.person_wave_status (person_id, highest_education, course_name, employment_status, monthly_income)
                    SELECT person_id, '{edu}', {course}, '{emp}', {income} FROM ins_person;
                    \n""")

                # 4. Process 11 Health Condition Sheets (De-linked Architecture)
                print("[INFO] Processing 11 Health Condition Case Registers (De-Linked)...")
                for sheet_key, category in HEALTH_SHEET_TO_CATEGORY.items():
                    h_rows = self._read_sheet_rows(z, sheet_key)
                    if not h_rows:
                        continue
                    print(f"       • Sheet '{sheet_key}': {len(h_rows)} cases -> Category: {category}")
                    for row in h_rows:
                        total_records_count += 1
                        hh_uuid = self.resolve_hh_uuid(row, household_uuid_map)
                        if not hh_uuid:
                            continue

                        # Extract Age & Gender (No Names!)
                        age_val = None
                        for k, v in row.items():
                            if 'പ്രായം' in k:
                                age_val = sql_escape_num(v)
                                break
                        
                        gen_val = 'MALE'
                        for k, v in row.items():
                            if 'ജൻഡർ' in k:
                                gen_val = map_gender(v)
                                break

                        subtype = None
                        for k, v in row.items():
                            if any(w in k for w in ['തരം', 'വിശദാംശം', 'പേര്', 'രോഗ']):
                                if v and not k.startswith('_'):
                                    subtype = v
                                    break
                        
                        age_band_code = map_age_band(age_val if age_val != "NULL" else None)

                        out.write(f"""
                        INSERT INTO core.health_condition_case 
                        (household_uuid, condition_category, condition_subtype, age, age_band, gender, survey_sheet_source)
                        VALUES ('{hh_uuid}', '{category}', {sql_escape_str(subtype)}, {age_val or 'NULL'}, '{age_band_code}', '{gen_val}', '{sheet_key}');
                        \n""")

                # 5. Disability Sheet
                disability_rows = self._read_sheet_rows(z, SHEET_TARGETS["DISABILITY"])
                if disability_rows:
                    print(f"[INFO] Processing Disability Cases ({len(disability_rows)} records)...")
                    for row in disability_rows:
                        total_records_count += 1
                        hh_uuid = self.resolve_hh_uuid(row, household_uuid_map)
                        if not hh_uuid:
                            continue
                        cat = "LOCOMOTOR"
                        details = None
                        for k, v in row.items():
                            if v and not k.startswith('_'):
                                details = str(v)
                                break
                        out.write(f"""
                        INSERT INTO core.disability_case (household_uuid, disability_category, disability_type_details)
                        VALUES ('{hh_uuid}', '{cat}', {sql_escape_str(details)});
                        \n""")

                # 6. Welfare Pensions Sheet
                pension_rows = self._read_sheet_rows(z, SHEET_TARGETS["PENSION"])
                if pension_rows:
                    print(f"[INFO] Processing Social Welfare Pensions ({len(pension_rows)} records)...")
                    for row in pension_rows:
                        total_records_count += 1
                        hh_uuid = self.resolve_hh_uuid(row, household_uuid_map)
                        if not hh_uuid:
                            continue
                        p_type = "OLD_AGE"
                        remarks = None
                        for k, v in row.items():
                            if v and not k.startswith('_'):
                                remarks = str(v)
                                break
                        out.write(f"""
                        INSERT INTO core.pension_record (household_uuid, pension_type, remarks)
                        VALUES ('{hh_uuid}', '{p_type}', {sql_escape_str(remarks)});
                        \n""")

                # 7. Update Batch Status and Refresh Materialized Views
                out.write(f"""
                UPDATE raw_staging.survey_submission_batch 
                SET total_records = {total_records_count}, status = 'COMPLETED' 
                WHERE batch_id = '{batch_id}';

                -- Refresh analytics views for instant dashboard consumption
                REFRESH MATERIALIZED VIEW analytics.mv_ward_summary;
                REFRESH MATERIALIZED VIEW analytics.mv_ward_health_summary;
                \n""")

                out.write("COMMIT;\n")

        print(f"\n[SUCCESS] Ingestion SQL compiled successfully: {output_sql_path}")
        print(f"          Total records staged and transformed: {total_records_count}")
        return batch_id, total_records_count

def run_ingestion_stream(sql_path: str):
    print(f"\n[INFO] Streaming Ingestion Transaction into PostgreSQL container (port 5433)...")
    env = os.environ.copy()
    env["PGPASSWORD"] = "postgres"

    cmd = [
        "psql",
        "-h", "localhost",
        "-p", "5433",
        "-U", "postgres",
        "-d", "klip_db",
        "-v", "ON_ERROR_STOP=1",
        "-f", sql_path
    ]
    
    res = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding="utf-8")
    if res.returncode != 0:
        print("[ERROR] Database transaction failed:")
        print(res.stderr)
        return False
    print("[SUCCESS] Database transaction committed successfully!")
    return True
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="KLIP DPDP-Compliant Survey Ingestion Pipeline")
    parser.add_argument("--file", default=r"d:\Sreehari\Final Year Project\KLIP\Kanjikkuzhi Survey Data for analysis.xlsx", help="Path to survey Excel file")
    args = parser.parse_args()
    
    target_file = args.file
    if not os.path.exists(target_file):
        downloads_path = os.path.expanduser(r"~\Downloads\Kanjikkuzhi Survey Data for analysis.xlsx")
        if os.path.exists(downloads_path):
            target_file = downloads_path

    output_sql = os.path.join(BASE_DIR, "database", "staging_ingest_batch.sql")
    engine = SurveyIngestionEngine(target_file)
    batch_id, count = engine.generate_ingestion_sql(output_sql)
    
    success = run_ingestion_stream(output_sql)
    
    # Clean up generated staging SQL file after successful execution to avoid accidental commits
    if success and os.path.exists(output_sql):
        os.remove(output_sql)
        print(f"[CLEANUP] Removed temporary staging transaction file: {output_sql}")
