# Lead Generation Multi-Agent System Design

**Created:** 2026-04-09
**Status:** Draft - Pending User Review

## Overview

A fully autonomous multi-agent system for lead generation via web scraping. Uses LangGraph orchestration with Python to discover, scrape, enrich, and export leads.

## Requirements Summary

| Requirement | Decision |
|-------------|----------|
| Domain | Marketing/Sales |
| Workflow | Lead Generation |
| Data Source | Web Scraping |
| Output | Export to File/Database |
| Tech Stack | Python |
| Coordination | Orchestrator Pattern |
| Autonomy | Fully Autonomous |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        ORCHESTRATOR AGENT                       │
│  (Manages workflow state, routes tasks, handles failures)       │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│  DISCOVERY    │    │   SCRAPER     │    │  ENRICHER     │
│   AGENT       │───▶│   AGENT       │───▶│   AGENT       │
│               │    │               │    │               │
│ Finds target  │    │ Extracts lead │    │ Adds company  │
│ websites/pages│    │ data from HTML│    │ metadata      │
└───────────────┘    └───────────────┘    └───────────────┘
                              │
                              ▼
                      ┌───────────────┐
                      │   EXPORT      │
                      │   AGENT       │
                      │               │
                      │ Writes to CSV │
                      │ /database     │
                      └───────────────┘
```

**Key Principle:** Each agent has a single responsibility and communicates through a shared state object (the "lead graph"). The orchestrator runs the LangGraph workflow, passing state between agents.

## Agent Components

### Orchestrator Agent

**Role:** Workflow coordinator

**Responsibilities:**
- Initialize the lead generation state
- Route tasks to appropriate specialist agents
- Handle retries and failure recovery
- Track progress and report status

**Tools:** Graph state management, error handlers

### Discovery Agent

**Role:** Target finder

**Responsibilities:**
- Accept search queries or seed URLs
- Use search APIs (Google/Bing) or crawl directories
- Identify and queue candidate pages for scraping
- Filter out irrelevant targets early

**Tools:** Search API clients, URL validators, robots.txt parser

### Scraper Agent

**Role:** Data extractor

**Responsibilities:**
- Fetch HTML from target URLs
- Extract structured lead data (name, email, company, title)
- Handle dynamic content (Playwright for JS sites)
- Respect rate limits and avoid detection

**Tools:** BeautifulSoup, Playwright, proxy rotator

### Enricher Agent

**Role:** Data enhancer

**Responsibilities:**
- Lookup company info (size, industry, tech stack)
- Verify email addresses
- Score lead quality based on criteria
- Flag duplicates

**Tools:** Clearbit/PeopleDataLabs API, email verifier

### Export Agent

**Role:** Output handler

**Responsibilities:**
- Format leads for output (CSV, JSON, SQL)
- Write to destination (file, SQLite, PostgreSQL)
- Generate summary reports
- Handle write failures gracefully

**Tools:** pandas, SQLAlchemy, CSV writer

## Data Flow

### State Schema

```python
from typing import TypedDict

class LeadGraphState(TypedDict):
    # Input
    search_queries: list[str]
    seed_urls: list[str]
    
    # Accumulated by agents
    discovered_urls: list[dict]  # [{url, source, priority}]
    raw_leads: list[dict]        # [{name, email, company, ...}]
    enriched_leads: list[dict]   # [{... + company_size, industry, score}]
    
    # Output
    export_path: str | None
    export_format: str          # "csv", "json", "sql"
    
    # Control flow
    errors: list[dict]          # [{agent, url, error, retry_count}]
    current_stage: str          # "discovery", "scraping", "enrichment", "export"
    processed_count: int
    total_count: int
```

### Flow Sequence

1. **Input** → Orchestrator receives `search_queries` and/or `seed_urls`

2. **Discovery** → Discovery agent populates `discovered_urls`, transitions state to `"scraping"`

3. **Scraping** → Scraper agent processes URLs, appends to `raw_leads`

4. **Enrichment** → Enricher agent processes `raw_leads`, outputs to `enriched_leads`

5. **Export** → Export agent writes `enriched_leads` to file/database, sets `export_path`

6. **Complete** → Orchestrator returns final state with results

### State Transitions (LangGraph Edges)

```
START → discovery → (has URLs?) → scraping
                    ↓ (no URLs)
                  END

scraping → (has leads?) → enrichment
           ↓ (no leads)
         END

enrichment → export → END
```

## Error Handling

### Failure Modes and Recovery

| Failure | Detection | Recovery |
|---------|-----------|----------|
| URL unreachable | HTTP timeout/error | Retry with exponential backoff (3 attempts), log to `errors`, skip |
| Rate limited | HTTP 429 | Wait, rotate proxy/user-agent, retry |
| Invalid HTML | Parse exception | Log warning, skip URL, continue |
| Missing lead data | Required fields empty | Mark lead as incomplete, still process |
| Enrichment API down | API timeout/error | Continue without enrichment, flag lead |
| Export write failure | File/DB exception | Retry once, fallback to temp file, alert |

### Retry Strategy

```python
from tenacity import retry, stop_after_attempt, wait_exponential

class RetryConfig:
    max_attempts: int = 3
    base_delay: float = 1.0  # seconds
    max_delay: float = 30.0
    exponential_base: float = 2.0

# Retry decorator applied to all agent operations
@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=30),
    before_sleep=log_retry_attempt
)
async def agent_operation(state: LeadGraphState) -> LeadGraphState:
    ...
```

### Graceful Degradation

- Scraping failures → Skip URL, continue with others
- Enrichment failures → Return leads without enrichment data
- Export failures → Write to fallback location, preserve state for resume

### State Persistence for Recovery

```python
import json

# Checkpoint state after each agent completes
def checkpoint_state(state: LeadGraphState, stage: str):
    with open(f".lead_gen_checkpoint_{stage}.json", "w") as f:
        json.dump(state, f)

# On restart, resume from last checkpoint
def load_checkpoint() -> LeadGraphState | None:
    # Find most recent checkpoint file
    # Return state if found, else None
```

## Testing Strategy

### Test Levels

| Level | Scope | Tools |
|-------|-------|-------|
| **Unit** | Individual agent functions | pytest, pytest-asyncio |
| **Integration** | Agent-to-agent handoffs | pytest with mocked state |
| **End-to-end** | Full pipeline run | pytest + real APIs (staged) |
| **Performance** | Throughput, memory, latency | pytest-benchmark, memory_profiler |

### Unit Tests

```python
# tests/test_discovery_agent.py
def test_discovery_finds_urls_from_query():
    state = LeadGraphState(search_queries=["AI startups"], seed_urls=[])
    result = discovery_agent(state)
    assert len(result["discovered_urls"]) > 0
    
def test_discovery_respects_robots_txt():
    # Mock robots.txt disallowing certain paths
    state = LeadGraphState(seed_urls=["https://example.com/private/"])
    result = discovery_agent(state)
    assert all(url["url"] != "https://example.com/private/" for url in result["discovered_urls"])

# tests/test_scraper_agent.py
def test_scraper_extracts_lead_data():
    # Mock HTML response
    state = LeadGraphState(discovered_urls=[{"url": "https://example.com/contact"}])
    result = scraper_agent(state)
    assert "email" in result["raw_leads"][0]
```

### Integration Tests

```python
def test_discovery_to_scraper_handoff():
    state = LeadGraphState(search_queries=["test query"])
    
    # Run discovery
    state = discovery_agent(state)
    assert state["current_stage"] == "scraping"
    
    # Run scraper with discovery output
    state = scraper_agent(state)
    assert len(state["raw_leads"]) > 0
```

### End-to-End Test

```python
import os
import pytest

@pytest.mark.e2e
def test_full_lead_generation_pipeline():
    """Run full pipeline with mock APIs enabled."""
    state = LeadGraphState(
        search_queries=["Python consultants"],
        export_format="csv"
    )
    
    # Run through LangGraph
    result = orchestrator.run(state)
    
    assert result["export_path"] is not None
    assert os.path.exists(result["export_path"])
    assert result["processed_count"] > 0
```

### Test Fixtures

```python
# tests/conftest.py
import pytest

@pytest.fixture
def mock_search_api():
    """Mock Google/Bing search responses."""
    pass
    
@pytest.fixture
def sample_html():
    """Sample HTML pages for scraping tests."""
    pass
    
@pytest.fixture  
def mock_enrichment_api():
    """Mock Clearbit/PeopleDataLabs responses."""
    pass
```

### Coverage Targets

- Unit tests: 80% coverage minimum
- Integration tests: All agent handoffs covered
- E2E: At least one full pipeline test

## Project Structure

```
lead_gen_agents/
├── src/
│   ├── __init__.py
│   ├── orchestrator/
│   │   ├── __init__.py
│   │   ├── graph.py          # LangGraph workflow definition
│   │   └── state.py          # LeadGraphState definition
│   ├── agents/
│   │   ├── __init__.py
│   │   ├── discovery.py      # Discovery agent implementation
│   │   ├── scraper.py        # Scraper agent implementation
│   │   ├── enricher.py       # Enricher agent implementation
│   │   └── export.py         # Export agent implementation
│   ├── tools/
│   │   ├── __init__.py
│   │   ├── search_api.py     # Search API client
│   │   ├── web_fetcher.py    # HTTP/Playwright fetcher
│   │   ├── enrichment_api.py # Company data API client
│   │   └── storage.py        # File/DB writer
│   └── config/
│       ├── __init__.py
│       └── settings.py       # API keys, retry config, etc.
├── tests/
│   ├── __init__.py
│   ├── conftest.py           # Fixtures
│   ├── test_discovery.py
│   ├── test_scraper.py
│   ├── test_enricher.py
│   ├── test_export.py
│   └── test_integration.py
├── pyproject.toml            # Dependencies (langgraph, beautifulsoup4, etc.)
└── README.md
```

## Dependencies

```toml
# pyproject.toml
[project]
dependencies = [
    "langgraph>=0.2.0",
    "langchain>=0.3.0",
    "beautifulsoup4>=4.12.0",
    "playwright>=1.40.0",
    "httpx>=0.25.0",
    "tenacity>=8.2.0",
    "pandas>=2.0.0",
    "sqlalchemy>=2.0.0",
    "pydantic>=2.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "pytest-asyncio>=0.21.0",
    "pytest-benchmark>=4.0.0",
    "memory-profiler>=0.61.0",
]
```

## Success Criteria

1. **Functional:** System discovers, scrapes, enriches, and exports leads end-to-end without human intervention
2. **Reliable:** Handles failures gracefully, resumes from checkpoints
3. **Performant:** Processes at least 100 leads per hour on standard hardware
4. **Maintainable:** Each agent is independently testable and replaceable
5. **Extensible:** Easy to add new data sources, enrichment APIs, or export formats

## Next Steps

1. Implement `LeadGraphState` and LangGraph workflow skeleton
2. Build Discovery agent with search API integration
3. Build Scraper agent with BeautifulSoup/Playwright
4. Build Enricher agent with API integration
5. Build Export agent with CSV/JSON/SQL support
6. Add error handling and retry logic
7. Write unit and integration tests
8. Add checkpoint/recovery system