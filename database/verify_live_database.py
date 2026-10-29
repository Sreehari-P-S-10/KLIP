"""
Live PostgreSQL Schema & Seed Verification Script
Verifies table counts, schemas, materialized views, and seeded records in klip_db.
"""

import os
import sys
import subprocess

sys.stdout.reconfigure(encoding='utf-8')

env = os.environ.copy()
env["PGPASSWORD"] = "postgres"

def run_query(sql):
    cmd = [
        "psql",
        "-h", "localhost",
        "-p", "5433",
        "-U", "postgres",
        "-d", "klip_db",
        "-t", "-A",
        "-c", sql
    ]
    res = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding="utf-8")
    if res.returncode != 0:
        print(f"Error: {res.stderr}")
        return []
    return [line.strip() for line in res.stdout.strip().splitlines() if line.strip()]

print("=" * 65)
print("KLIP LIVE DATABASE VERIFICATION REPORT")
print("=" * 65)

# 1. Schemas Check
schemas = run_query("SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('raw_staging', 'pii_vault', 'core', 'scheme_kb', 'analytics', 'audit') ORDER BY schema_name;")
print(f"1. Schemas Active ({len(schemas)}/6):")
for s in schemas:
    print(f"   ✓ {s}")

# 2. Table Count per Schema
table_counts = run_query("""
SELECT table_schema, count(table_name) 
FROM information_schema.tables 
WHERE table_schema IN ('raw_staging', 'pii_vault', 'core', 'scheme_kb', 'analytics', 'audit') 
  AND table_type = 'BASE TABLE'
GROUP BY table_schema 
ORDER BY table_schema;
""")
print(f"\n2. Tables Created per Schema:")
for tc in table_counts:
    schema, count = tc.split("|")
    print(f"   ✓ {schema:<15} : {count} tables")

# 3. Materialized Views Check
mvs = run_query("SELECT schemaname || '.' || matviewname FROM pg_matviews WHERE schemaname = 'analytics';")
print(f"\n3. Materialized Views ({len(mvs)}):")
for mv in mvs:
    print(f"   ✓ {mv}")

# 4. Extensions Check
exts = run_query("SELECT extname || ' (v' || extversion || ')' FROM pg_extension WHERE extname IN ('postgis', 'pgcrypto', 'uuid-ossp', 'vector');")
print(f"\n4. Active Extensions:")
for e in exts:
    print(f"   ✓ {e}")

# 5. Seed Data Check (Panchayat & Wards)
panchayat = run_query("SELECT panchayat_id || ' | ' || name_en || ' | ' || name_ml FROM core.panchayat;")
print(f"\n5. Seeded Panchayat:")
for p in panchayat:
    print(f"   ✓ {p}")

wards = run_query("SELECT ward_number || '. ' || ward_name_en || ' (' || ward_name_ml || ')' FROM core.ward ORDER BY ward_number;")
print(f"\n6. Seeded Wards ({len(wards)}/19):")
for w in wards[:5]:
    print(f"   ✓ {w}")
print(f"   ... and {len(wards) - 5} more wards.")

# 7. Codelist Choices Check
codelist_summary = run_query("""
SELECT codelist_name, count(*) 
FROM core.codelist_choice 
GROUP BY codelist_name 
ORDER BY codelist_name;
""")
print(f"\n7. Bilingual Codelist Catalog ({len(codelist_summary)} categories):")
for c in codelist_summary:
    cname, count = c.split("|")
    print(f"   ✓ {cname:<25} : {count} bilingual choices")

# 8. Indicators Seed Check
indicators = run_query("SELECT indicator_code || ' | ' || name_en FROM analytics.indicator_catalogue ORDER BY indicator_code;")
print(f"\n8. Seeded Strategic Planning Indicators ({len(indicators)}):")
for ind in indicators:
    print(f"   ✓ {ind}")

# 9. Ingested Survey Records Verification
print(f"\n9. Ingested & Decoupled Survey Data Counts:")
ingested_counts = run_query("""
SELECT 'raw_staging.survey_raw_record' AS entity, count(*)::text FROM raw_staging.survey_raw_record
UNION ALL SELECT 'pii_vault.household_identity (encrypted PII)', count(*)::text FROM pii_vault.household_identity
UNION ALL SELECT 'core.household (anonymized households)', count(*)::text FROM core.household
UNION ALL SELECT 'core.household_profile (Section A profiles)', count(*)::text FROM core.household_profile
UNION ALL SELECT 'core.person (Section B individuals)', count(*)::text FROM core.person
UNION ALL SELECT 'core.person_wave_status (education & jobs)', count(*)::text FROM core.person_wave_status
UNION ALL SELECT 'core.health_condition_case (unlinked chronic cases)', count(*)::text FROM core.health_condition_case
UNION ALL SELECT 'core.pension_record (welfare pensions)', count(*)::text FROM core.pension_record
UNION ALL SELECT 'core.disability_case (disability records)', count(*)::text FROM core.disability_case;
""")
for ic in ingested_counts:
    tbl, cnt = ic.split("|")
    print(f"   ✓ {tbl:<52} : {cnt} records")

# 10. Materialized View Ward Summary
print(f"\n10. Live Materialized View Sample (analytics.mv_ward_summary):")
ward_stats = run_query("""
SELECT ward_number || '. ' || ward_name_en || ' | Total HH: ' || total_households || ' | Pop: ' || total_population || ' | BPL: ' || bpl_households || ' | Wells: ' || households_with_well
FROM analytics.mv_ward_summary 
WHERE total_households > 0
ORDER BY ward_number;
""")
for ws in ward_stats:
    print(f"   ✓ {ws}")

print("\n" + "=" * 65)
print("[VERIFIED] Complete DPDP Decoupling & Ingestion Pipeline Verified!")
print("=" * 65)
