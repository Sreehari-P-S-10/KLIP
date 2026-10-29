# Backend API & Application Layer (`backend/`)

## Architecture Overview
The backend is built with **FastAPI** (Python 3.12+), utilizing asynchronous database sessions via **SQLAlchemy 2.0** and **asyncpg**.

## Directory Layout
```text
backend/
├── app/
│   ├── api/               # API versioned route handlers (v1)
│   │   ├── citizen/       # Citizen login, profile updates, voice grievance
│   │   ├── admin/         # Planning dashboard, candidate verification queue
│   │   └── spatial/       # PostGIS GeoJSON endpoints (ward polygons, hotspots)
│   ├── core/              # Global configuration, security, JWT/OTP, database session
│   ├── models/            # SQLAlchemy 2.0 ORM models (core, pii, health, analytics)
│   ├── schemas/           # Pydantic v2 validation models
│   └── services/          # Business logic (indicator calculator, RAG orchestrator)
├── tests/                 # Backend API integration and unit tests
└── requirements.txt       # Python package dependencies
```

## Key Technical Responsibilities
- **Row-Level Security (RLS):** Authenticated citizens can only read/update their own household records.
- **OTP Authentication:** Passwordless phone authentication for rural household heads.
- **Privacy Gateway:** Mediates access between the protected `pii_vault` and the open `analytics` core.
