# Automated Test Suite (`tests/`)

## Test Organization
- `unit/`: Unit tests for indicator calculation formulas, Z-score/IQR outlier functions, and data validation routines.
- `integration/`: End-to-end API tests, database transaction rollbacks, and ingestion pipeline verification.
- `security/`: DPDP Act privacy tests, verifying:
  - That no raw citizen identifiers leak into `core` or `analytics`.
  - That sensitive health condition queries strictly enforce $k \ge 5$ cell suppression.
  - That PostgreSQL Row-Level Security (RLS) prevents cross-household data access.
