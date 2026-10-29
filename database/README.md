# Database Architecture & Migrations (`database/`)

## PostgreSQL 16 5-Schema Architecture

The KLIP database enforces physical separation across 5 distinct schemas:

1. **`pii_vault`:** Houses direct citizen identifiers (Name, Mobile, House No., Cadastral Survey No., exact GPS points). Protected by AES-256 (`pgcrypto`) and strict DB role isolation.
2. **`core`:** Normalized 3NF tables capturing demographics, housing, infrastructure, assets, and land records.
3. **`health`:** Decoupled sensitive health microdata (cancer, HIV, psychiatric illnesses). Linked only by surrogate keys with permanent $k \ge 5$ small-cell suppression.
4. **`scheme_kb`:** Vector knowledge base indexing 150+ official Kerala welfare schemes with BGE-M3 (1024-dim) dense embeddings and PostgreSQL full-text search.
5. **`analytics`:** Precomputed Materialized Views for 42 PDI indicators, Z-score/IQR residual scans, and the 4-stage democratic decision state machine (`candidate_issue`).

## Subdirectories
- `migrations/`: Numbered SQL DDL files executed in sequence.
- `seeds/`: Initial lookup codelists, ward boundary GeoJSONs, and reference indicators.
