# ETL & Ingestion Pipeline (`etl/`)

## Purpose
Handles lossless ingestion of the K-DISC Kanjikuzhi Block 40-page household baseline survey (multi-sheet KoboToolbox Excel/CSV export) and generates DPDP Act-compliant synthetic datasets for development.

## Directory Layout
```text
etl/
├── parsers/               # Multi-sheet Kobo Excel parser routines
├── validators/            # Checksum verification (SHA-256) & schema validation
├── synthetic/             # Synthetic survey dataset generator (zero PII exposure)
└── scripts/               # CLI runners (ingest_raw.py, raw_to_core.py)
```

## Key Ingestion Rules
1. **Zero Data Loss:** Original raw submissions are written byte-for-byte to `raw_staging` JSONB before transformation.
2. **Cryptographic Checksum:** Every ingested file batch records an SHA-256 hash.
3. **Quarantine:** Structural anomalies (unit mismatches, unlinked repeats) are logged to `validation_issue` rather than silently dropped.
