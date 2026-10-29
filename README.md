# Kanjikuzhi Local Development Intelligence Platform (KLIP)

> **Evidence-Driven Decentralized Governance, Spatial Analytics & Grounded Decision Intelligence**

---

## 🏛️ Project Overview
KLIP is a localized decision-support platform designed for **Local Self-Government Institutions (Grama Panchayats)** in Kerala. It transforms dormant, complex multi-domain household baseline surveys into living, spatially-grounded, and welfare-scheme-linked administrative intelligence.

### Core Architectural Pillars
1. **Dual-Synchronized Intelligence:** Combines an immutable baseline survey with ongoing citizen living updates (mobile OTP login & Malayalam voice grievance via Whisper).
2. **Privacy by Design (DPDP Act 2023 Compliant):** Cryptographically isolates direct citizen identifiers in an AES-256 `pii_vault` and permanently decouples sensitive health records (cancer, HIV, psychiatric illnesses) with $k \ge 5$ suppression.
3. **Anti-Hallucination Framework:** Factual problem discovery is handled deterministically via a 42-indicator SQL engine and statistical Z-score/IQR outlier scans. Private local LLMs (Qwen3-8B via vLLM) strictly act as grounded synthesizers constrained to retrieved government scheme guidelines.
4. **Democratic 4-Stage Governance State Machine:** Enforces transparent lifecycle progression:
   $$\text{Detected Pattern} \longrightarrow \text{Issue Candidate} \longrightarrow \text{Verified Problem} \longrightarrow \text{Official Recommendation}$$

---

## 📂 Repository Structure

```text
KLIP/
├── backend/               # FastAPI async application (REST APIs, Auth, Services)
├── database/              # PostgreSQL 16 DDL migrations, schemas & seed data
│   ├── migrations/        # Numbered SQL DDL scripts across all 5 schemas
│   └── seeds/             # Lookup codelists, baseline ward geo-boundaries
├── etl/                   # Lossless ingestion pipeline & synthetic data generators
│   ├── parsers/           # Multi-sheet KoboToolbox baseline parsers
│   ├── validators/        # Schema validators & checksum verifiers
│   └── synthetic/         # Synthetic household microdata generator
├── frontend/              # User interfaces (Citizen Portal & Admin GIS Dashboard)
├── docs/                  # Architecture specs, indicator catalogue & API specs
└── tests/                 # Unit, integration, and security test suites
```

---

## 👥 Academic & Project Group Metadata
- **Institution:** Department of Computer Science & Engineering, Government Engineering College Thrissur
- **Academic Context:** APJ Abdul Kalam Technological University (KTU) B.Tech CSE (2019 Scheme)
- **Course Codes:** CSD415 (Project Phase 1) & CSD416 (Project Phase 2)
- **Project Guide:** Dr. Gilesh M P, Professor, Dept. of CSE
- **Team (Group 12):**
  - **Sreehari P S (Project Lead · TCR23CS067):** System Architecture, Indicator Engine, Hybrid Retrieval & AI Grounding
  - **Neeraj Krishnan (TCR23CS053):** PostgreSQL DDL, `pii_vault` Security, Ingestion Pipeline & RLS
  - **Jestin Jose (TCR23CS046):** Citizen Living Portal, Mobile OTP, Unicode Malayalam UI & Whisper Voice UI
  - **Adith K A (TCR23CS006):** Administrative Dashboard, Leaflet GIS Hotspot Mapping & PDF Export
