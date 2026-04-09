# Lead Generation Dashboard Design

**Created:** 2026-04-09
**Status:** Approved - Ready for Implementation

## Overview

A FastAPI + React web dashboard for lead generation. Users type a purpose/query (e.g., "find SaaS founders in New Zealand"), and the system discovers, scrapes, and exports leads via a LangGraph multi-agent architecture.

## Requirements Summary

| Requirement | Decision |
|-------------|----------|
| **Interface** | Web Dashboard (React) |
| **Backend** | FastAPI (Python) |
| **Agent System** | LangGraph Multi-Agent (from existing design) |
| **Input Methods** | Text query, structured filters, seed URLs, CSV upload |
| **Lead Data** | Basic: Name, Email, Company, Title |
| **Discovery** | Google Custom Search API |
| **Scraping** | Configurable: BeautifulSoup / Playwright / Hybrid |
| **Enrichment** | None |
| **Export** | CSV/JSON download from dashboard |
| **Users** | Single user, no authentication |
| **Deployment** | Local machine (localhost) |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    REACT DASHBOARD                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ Text Query  │  │ Filters     │  │ Upload/Seed URLs    │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Scraper Config: [BeautifulSoup | Playwright | Hybrid]│   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ Progress    │  │ Lead Table  │  │ Export (CSV/JSON)   │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    FASTAPI BACKEND                          │
│  /api/search  /api/status  /api/leads  /api/export         │
│  WebSocket for real-time progress updates                    │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                 LANGGRAPH MULTI-AGENT SYSTEM                │
│  Orchestrator → Discovery → Scraper → Export                  │
│  (No Enricher - basic data only)                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
                    Google Custom Search API
```

## Backend Components

### FastAPI Application

```python
# backend/api/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Lead Generation Dashboard")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/search` | POST | Start new lead generation job |
| `/api/status/{job_id}` | GET | Get job progress/status |
| `/api/leads/{job_id}` | GET | Get leads for a job |
| `/api/export/{job_id}` | GET | Download leads as CSV/JSON |
| `/ws/status/{job_id}` | WebSocket | Real-time progress updates |

### Request/Response Models

```python
# backend/api/models.py
from pydantic import BaseModel
from typing import Optional
from enum import Enum

class ScraperMode(str, Enum):
    BEAUTIFULSOUP = "beautifulsoup"
    PLAYWRIGHT = "playwright"
    HYBRID = "hybrid"

class SearchRequest(BaseModel):
    query: str
    filters: Optional[dict] = None
    seed_urls: Optional[list[str]] = None
    scraper_mode: ScraperMode = ScraperMode.HYBRID

class SearchResponse(BaseModel):
    job_id: str
    status: str
    message: str

class Lead(BaseModel):
    name: str
    email: str
    company: str
    title: str
    source_url: str

class JobStatus(BaseModel):
    job_id: str
    status: str  # "pending", "discovering", "scraping", "completed", "failed"
    progress: float  # 0.0 - 1.0
    leads_found: int
    current_stage: str
    error: Optional[str] = None
```

## Frontend Components

### Search Form Component

```typescript
// frontend/src/components/SearchForm.tsx
interface SearchFormProps {
  onSubmit: (request: SearchRequest) => void;
  isLoading: boolean;
}

// Features:
// - Text query input
// - Optional filters panel (industry, location, company size)
// - Optional seed URLs textarea
// - Scraper mode selector dropdown
// - Submit button
```

### Leads Table Component

```typescript
// frontend/src/components/LeadsTable.tsx
interface LeadsTableProps {
  leads: Lead[];
  isLoading: boolean;
}

// Columns: Name, Email, Company, Title, Source URL
// Features:
// - Real-time updates via WebSocket
// - Sortable columns
// - Search/filter within results
// - Export button
```

### Progress Indicator

```typescript
// frontend/src/components/ProgressIndicator.tsx
interface ProgressIndicatorProps {
  status: JobStatus;
}

// Shows:
// - Current stage (discovering, scraping, etc.)
// - Progress bar
// - Leads found count
// - Estimated time remaining (optional)
```

## Agent System (LangGraph)

### Simplified State Schema

```python
# backend/agents/state.py
from typing import TypedDict

class LeadGraphState(TypedDict):
    # Input
    query: str
    filters: dict | None
    seed_urls: list[str]
    scraper_mode: str  # "beautifulsoup", "playwright", "hybrid"
    
    # Accumulated by agents
    discovered_urls: list[dict]  # [{url, source, priority}]
    raw_leads: list[dict]       # [{name, email, company, title, source_url}]
    
    # Output
    export_path: str | None
    export_format: str          # "csv" or "json"
    
    # Control flow
    errors: list[dict]          # [{agent, url, error}]
    current_stage: str           # "discovery", "scraping", "export"
    job_id: str
```

### Workflow Definition

```python
# backend/agents/orchestrator/graph.py
from langgraph.graph import StateGraph

def create_lead_graph():
    graph = StateGraph(LeadGraphState)
    
    # Add nodes
    graph.add_node("discovery", discovery_agent)
    graph.add_node("scraper", scraper_agent)
    graph.add_node("export", export_agent)
    
    # Add edges
    graph.set_entry_point("discovery")
    graph.add_edge("discovery", "scraper")
    graph.add_edge("scraper", "export")
    graph.set_finish_point("export")
    
    # Conditional edges for error handling
    graph.add_conditional_edges(
        "discovery",
        should_continue_after_discovery,
        {"continue": "scraper", "end": END}
    )
    
    return graph.compile()
```

## Project Structure

```
lead_gen_agents/
├── backend/
│   ├── api/
│   │   ├── __init__.py
│   │   ├── main.py              # FastAPI app entry point
│   │   ├── routes/
│   │   │   ├── __init__.py
│   │   │   ├── search.py        # POST /api/search
│   │   │   ├── status.py        # GET /api/status/{job_id}
│   │   │   ├── leads.py         # GET /api/leads/{job_id}
│   │   │   └── export.py        # GET /api/export/{job_id}
│   │   ├── models.py           # Pydantic models
│   │   └── websocket.py        # WebSocket handler
│   ├── agents/
│   │   ├── __init__.py
│   │   ├── orchestrator/
│   │   │   ├── __init__.py
│   │   │   ├── graph.py        # LangGraph workflow
│   │   │   └── state.py        # LeadGraphState
│   │   ├── discovery.py        # Discovery agent
│   │   ├── scraper.py          # Scraper agent
│   │   └── export.py           # Export agent
│   ├── tools/
│   │   ├── __init__.py
│   │   ├── search_api.py       # Google Custom Search client
│   │   ├── web_fetcher.py      # BeautifulSoup + Playwright
│   │   └── storage.py          # CSV/JSON export
│   ├── jobs/
│   │   ├── __init__.py
│   │   └── manager.py          # Job queue management
│   ├── config/
│   │   ├── __init__.py
│   │   └── settings.py         # API keys, config
│   └── main.py                 # Uvicorn entry point
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   │   ├── SearchForm.tsx
│   │   │   ├── FiltersPanel.tsx
│   │   │   ├── SeedUrlsInput.tsx
│   │   │   ├── ScraperConfig.tsx
│   │   │   ├── LeadsTable.tsx
│   │   │   ├── ProgressIndicator.tsx
│   │   │   └── ExportButton.tsx
│   │   ├── hooks/
│   │   │   ├── useWebSocket.ts
│   │   │   └── useJobStatus.ts
│   │   ├── api/
│   │   │   └── client.ts       # API client
│   │   ├── types/
│   │   │   └── index.ts        # TypeScript types
│   │   ├── App.tsx
│   │   └── main.tsx
│   ├── package.json
│   ├── vite.config.ts
│   └── tsconfig.json
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   ├── test_discovery.py
│   ├── test_scraper.py
│   ├── test_export.py
│   └── test_api.py
├── pyproject.toml
├── requirements.txt
└── README.md
```

## Dependencies

### Backend (Python)

```toml
# pyproject.toml
[project]
dependencies = [
    "fastapi>=0.109.0",
    "uvicorn>=0.27.0",
    "websockets>=12.0",
    "langgraph>=0.2.0",
    "langchain>=0.3.0",
    "beautifulsoup4>=4.12.0",
    "playwright>=1.40.0",
    "httpx>=0.25.0",
    "tenacity>=8.2.0",
    "pandas>=2.0.0",
    "pydantic>=2.0.0",
    "google-api-python-client>=2.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "pytest-asyncio>=0.21.0",
    "pytest-cov>=4.0.0",
]
```

### Frontend (Node.js)

```json
// frontend/package.json
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "@tanstack/react-table": "^8.0.0",
    "axios": "^1.6.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "vite": "^5.0.0",
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0"
  }
}
```

## User Flow

1. User opens `http://localhost:3000` in browser
2. User types query: "find SaaS founders in New Zealand"
3. (Optional) User adds filters (industry, location, company size)
4. (Optional) User pastes seed URLs or uploads CSV
5. (Optional) User configures scraper mode in settings
6. User clicks **Search**
7. Backend creates job, returns job_id
8. Frontend connects to WebSocket for real-time updates
9. User watches progress: "Discovering URLs..." → "Scraping leads..." → "Complete"
10. Leads populate in table as they're found
11. User clicks **Export** to download CSV or JSON file

## Error Handling

| Error | Handling |
|-------|----------|
| Google API quota exceeded | Display error, suggest waiting or using seed URLs |
| Scraping timeout | Skip URL, log error, continue |
| Invalid HTML | Skip URL, log warning |
| No leads found | Display "No leads found" message |
| WebSocket disconnect | Reconnect with exponential backoff |

## Success Criteria

1. **Functional:** User can type a query and receive leads via web dashboard
2. **Real-time:** Progress updates via WebSocket
3. **Configurable:** Scraper mode selectable in UI
4. **Exportable:** CSV/JSON download works
5. **Local:** Runs entirely on localhost with no external dependencies (except Google API)