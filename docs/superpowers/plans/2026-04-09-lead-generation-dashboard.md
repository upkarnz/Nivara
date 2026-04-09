# Lead Generation Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a FastAPI + React web dashboard for lead generation using LangGraph multi-agent architecture.

**Architecture:** FastAPI backend with REST API and WebSocket for real-time updates. React frontend with search form, progress indicator, and leads table. LangGraph orchestrates Discovery, Scraper, and Export agents.

**Tech Stack:** Python (FastAPI, LangGraph, BeautifulSoup, Playwright), React (TypeScript, Vite, TanStack Table)

---

## Phase 1: Project Setup & Configuration

### Task 1: Create Project Structure

**Files:**
- Create: `lead_gen_agents/`
- Create: `lead_gen_agents/backend/`
- Create: `lead_gen_agents/frontend/`
- Create: `lead_gen_agents/tests/`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p lead_gen_agents/backend/{api/routes,agents/orchestrator,tools,jobs,config}
mkdir -p lead_gen_agents/frontend/src/{components,hooks,api,types}
mkdir -p lead_gen_agents/tests
touch lead_gen_agents/backend/__init__.py
touch lead_gen_agents/backend/api/__init__.py
touch lead_gen_agents/backend/api/routes/__init__.py
touch lead_gen_agents/backend/agents/__init__.py
touch lead_gen_agents/backend/agents/orchestrator/__init__.py
touch lead_gen_agents/backend/tools/__init__.py
touch lead_gen_agents/backend/jobs/__init__.py
touch lead_gen_agents/backend/config/__init__.py
touch lead_gen_agents/tests/__init__.py
```

- [ ] **Step 2: Verify structure created**

Run: `ls -la lead_gen_agents/`
Expected: Directory structure visible

- [ ] **Step 3: Commit**

```bash
git add lead_gen_agents/
git commit -m "chore: create project directory structure"
```

---

### Task 2: Create pyproject.toml

**Files:**
- Create: `lead_gen_agents/pyproject.toml`
- Create: `lead_gen_agents/requirements.txt`

- [ ] **Step 1: Write pyproject.toml**

```toml
[project]
name = "lead_gen_agents"
version = "0.1.0"
description = "Lead Generation Dashboard with LangGraph Multi-Agent System"
requires-python = ">=3.10"
dependencies = [
    "fastapi>=0.109.0",
    "uvicorn[standard]>=0.27.0",
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
    "python-multipart>=0.0.6",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "pytest-asyncio>=0.21.0",
    "pytest-cov>=4.0.0",
    "httpx>=0.25.0",
]

[build-system]
requires = ["setuptools>=61.0"]
build-backend = "setuptools.build_meta"

[tool.setuptools.packages.find]
where = ["."]
```

- [ ] **Step 2: Create requirements.txt for convenience**

```
fastapi>=0.109.0
uvicorn[standard]>=0.27.0
websockets>=12.0
langgraph>=0.2.0
langchain>=0.3.0
beautifulsoup4>=4.12.0
playwright>=1.40.0
httpx>=0.25.0
tenacity>=8.2.0
pandas>=2.0.0
pydantic>=2.0.0
google-api-python-client>=2.0.0
python-multipart>=0.0.6
```

- [ ] **Step 3: Commit**

```bash
git add lead_gen_agents/pyproject.toml lead_gen_agents/requirements.txt
git commit -m "chore: add Python dependencies"
```

---

### Task 3: Create Configuration Module

**Files:**
- Create: `lead_gen_agents/backend/config/settings.py`
- Test: `lead_gen_agents/tests/test_config.py`

- [ ] **Step 1: Write the failing test**

```python
# lead_gen_agents/tests/test_config.py
import os
from backend.config.settings import Settings

def test_settings_defaults():
    """Test that settings has required default values."""
    settings = Settings()
    assert settings.scraper_mode == "hybrid"
    assert settings.max_discovery_results == 10
    assert settings.scraping_timeout == 30

def test_settings_from_env():
    """Test that settings reads from environment variables."""
    os.environ["GOOGLE_API_KEY"] = "test_key"
    os.environ["GOOGLE_CX"] = "test_cx"
    settings = Settings()
    assert settings.google_api_key == "test_key"
    assert settings.google_cx == "test_cx"
    # Cleanup
    del os.environ["GOOGLE_API_KEY"]
    del os.environ["GOOGLE_CX"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd lead_gen_agents && python -m pytest tests/test_config.py -v`
Expected: FAIL with "ModuleNotFoundError: No module named 'backend'"

- [ ] **Step 3: Write the implementation**

```python
# lead_gen_agents/backend/config/settings.py
from pydantic_settings import BaseSettings
from typing import Literal

class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # Google Custom Search API
    google_api_key: str = ""
    google_cx: str = ""
    
    # Scraper configuration
    scraper_mode: Literal["beautifulsoup", "playwright", "hybrid"] = "hybrid"
    scraping_timeout: int = 30
    max_discovery_results: int = 10
    
    # Rate limiting
    request_delay: float = 1.0
    max_retries: int = 3
    
    # Storage
    export_dir: str = "exports"
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

# Global settings instance
settings = Settings()
```

- [ ] **Step 4: Update pyproject.toml with pydantic-settings**

Add to dependencies in pyproject.toml:
```toml
"pydantic-settings>=2.0.0",
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd lead_gen_agents && python -m pytest tests/test_config.py -v`
Expected: PASS (2 tests)

- [ ] **Step 6: Commit**

```bash
git add lead_gen_agents/backend/config/settings.py lead_gen_agents/tests/test_config.py lead_gen_agents/pyproject.toml
git commit -m "feat: add configuration module with Pydantic settings"
```

---

## Phase 2: API Models & State

### Task 4: Create API Models

**Files:**
- Create: `lead_gen_agents/backend/api/models.py`
- Test: `lead_gen_agents/tests/test_models.py`

- [ ] **Step 1: Write the failing test**

```python
# lead_gen_agents/tests/test_models.py
from backend.api.models import ScraperMode, SearchRequest, Lead, JobStatus

def test_scraper_mode_enum():
    """Test ScraperMode enum values."""
    assert ScraperMode.BEAUTIFULSOUP == "beautifulsoup"
    assert ScraperMode.PLAYWRIGHT == "playwright"
    assert ScraperMode.HYBRID == "hybrid"

def test_search_request_defaults():
    """Test SearchRequest default values."""
    request = SearchRequest(query="test query")
    assert request.query == "test query"
    assert request.filters is None
    assert request.seed_urls is None
    assert request.scraper_mode == ScraperMode.HYBRID

def test_lead_model():
    """Test Lead model creation."""
    lead = Lead(
        name="John Doe",
        email="john@example.com",
        company="Acme Inc",
        title="CEO",
        source_url="https://example.com"
    )
    assert lead.name == "John Doe"
    assert lead.email == "john@example.com"

def test_job_status():
    """Test JobStatus model."""
    status = JobStatus(
        job_id="test-123",
        status="pending",
        progress=0.0,
        leads_found=0,
        current_stage="init"
    )
    assert status.job_id == "test-123"
    assert status.error is None
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd lead_gen_agents && python -m pytest tests/test_models.py -v`
Expected: FAIL with "ModuleNotFoundError"

- [ ] **Step 3: Write the implementation**

```python
# lead_gen_agents/backend/api/models.py
from pydantic import BaseModel
from typing import Optional
from enum import Enum

class ScraperMode(str, Enum):
    """Scraper mode options."""
    BEAUTIFULSOUP = "beautifulsoup"
    PLAYWRIGHT = "playwright"
    HYBRID = "hybrid"

class SearchRequest(BaseModel):
    """Request model for starting a lead search."""
    query: str
    filters: Optional[dict] = None
    seed_urls: Optional[list[str]] = None
    scraper_mode: ScraperMode = ScraperMode.HYBRID

class SearchResponse(BaseModel):
    """Response model for search endpoint."""
    job_id: str
    status: str
    message: str

class Lead(BaseModel):
    """Model for a single lead."""
    name: str
    email: str
    company: str
    title: str
    source_url: str

class JobStatus(BaseModel):
    """Model for job status."""
    job_id: str
    status: str  # "pending", "discovering", "scraping", "exporting", "completed", "failed"
    progress: float  # 0.0 - 1.0
    leads_found: int
    current_stage: str
    error: Optional[str] = None

class LeadsResponse(BaseModel):
    """Response model for leads endpoint."""
    job_id: str
    leads: list[Lead]
    total: int
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd lead_gen_agents && python -m pytest tests/test_models.py -v`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lead_gen_agents/backend/api/models.py lead_gen_agents/tests/test_models.py
git commit -m "feat: add Pydantic models for API"
```

---

### Task 5: Create Agent State Schema

**Files:**
- Create: `lead_gen_agents/backend/agents/state.py`
- Test: `lead_gen_agents/tests/test_state.py`

- [ ] **Step 1: Write the failing test**

```python
# lead_gen_agents/tests/test_state.py
from backend.agents.state import LeadGraphState, create_initial_state

def test_create_initial_state():
    """Test creating initial state."""
    state = create_initial_state(
        job_id="test-123",
        query="find SaaS founders"
    )
    assert state["job_id"] == "test-123"
    assert state["query"] == "find SaaS founders"
    assert state["discovered_urls"] == []
    assert state["raw_leads"] == []
    assert state["errors"] == []
    assert state["current_stage"] == "init"

def test_state_has_required_fields():
    """Test that LeadGraphState has all required fields."""
    # This is a type check - TypedDict fields should exist
    state: LeadGraphState = {
        "job_id": "test",
        "query": "test",
        "filters": None,
        "seed_urls": [],
        "scraper_mode": "hybrid",
        "discovered_urls": [],
        "raw_leads": [],
        "export_path": None,
        "export_format": "csv",
        "errors": [],
        "current_stage": "init"
    }
    assert "job_id" in state
    assert "query" in state
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd lead_gen_agents && python -m pytest tests/test_state.py -v`
Expected: FAIL with "ModuleNotFoundError"

- [ ] **Step 3: Write the implementation**

```python
# lead_gen_agents/backend/agents/state.py
from typing import TypedDict, Optional
import uuid

class LeadGraphState(TypedDict):
    """State schema for the lead generation graph."""
    # Input
    job_id: str
    query: str
    filters: Optional[dict]
    seed_urls: list[str]
    scraper_mode: str  # "beautifulsoup", "playwright", "hybrid"
    
    # Accumulated by agents
    discovered_urls: list[dict]  # [{url, source, priority}]
    raw_leads: list[dict]       # [{name, email, company, title, source_url}]
    
    # Output
    export_path: Optional[str]
    export_format: str          # "csv" or "json"
    
    # Control flow
    errors: list[dict]          # [{agent, url, error}]
    current_stage: str          # "init", "discovery", "scraping", "export", "complete"

def create_initial_state(
    job_id: str,
    query: str,
    filters: Optional[dict] = None,
    seed_urls: Optional[list[str]] = None,
    scraper_mode: str = "hybrid",
    export_format: str = "csv"
) -> LeadGraphState:
    """Create an initial state for a new job."""
    return LeadGraphState(
        job_id=job_id,
        query=query,
        filters=filters or {},
        seed_urls=seed_urls or [],
        scraper_mode=scraper_mode,
        discovered_urls=[],
        raw_leads=[],
        export_path=None,
        export_format=export_format,
        errors=[],
        current_stage="init"
    )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd lead_gen_agents && python -m pytest tests/test_state.py -v`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lead_gen_agents/backend/agents/state.py lead_gen_agents/tests/test_state.py
git commit -m "feat: add LangGraph state schema"
```

---

## Phase 3: Tools

### Task 6: Create Google Search API Tool

**Files:**
- Create: `lead_gen_agents/backend/tools/search_api.py`
- Test: `lead_gen_agents/tests/test_search_api.py`

- [ ] **Step 1: Write the failing test**

```python
# lead_gen_agents/tests/test_search_api.py
import pytest
from unittest.mock import Mock, patch
from backend.tools.search_api import GoogleSearchClient

def test_google_search_client_initialization():
    """Test client initializes with API credentials."""
    client = GoogleSearchClient(api_key="test_key", cx="test_cx")
    assert client.api_key == "test_key"
    assert client.cx == "test_cx"

@pytest.mark.asyncio
async def test_search_returns_urls():
    """Test search returns list of URLs."""
    client = GoogleSearchClient(api_key="test_key", cx="test_cx")
    
    with patch("backend.tools.search_api.build") as mock_build:
        mock_service = Mock()
        mock_build.return_value = mock_service
        mock_cse = Mock()
        mock_service.cse.return_value = mock_cse
        mock_list = Mock()
        mock_cse.list.return_value = mock_list
        mock_list.execute.return_value = {
            "items": [
                {"link": "https://example1.com", "title": "Example 1"},
                {"link": "https://example2.com", "title": "Example 2"},
            ]
        }
        
        results = await client.search("test query", num_results=10)
        
        assert len(results) == 2
        assert results[0]["url"] == "https://example1.com"
        assert results[0]["title"] == "Example 1"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd lead_gen_agents && python -m pytest tests/test_search_api.py -v`
Expected: FAIL with "ModuleNotFoundError"

- [ ] **Step 3: Write the implementation**

```python
# lead_gen_agents/backend/tools/search_api.py
from googleapiclient.discovery import build
from typing import Optional
import asyncio
from concurrent.futures import ThreadPoolExecutor

class GoogleSearchClient:
    """Client for Google Custom Search API."""
    
    def __init__(self, api_key: str, cx: str):
        """
        Initialize the Google Search client.
        
        Args:
            api_key: Google API key
            cx: Custom Search Engine ID
        """
        self.api_key = api_key
        self.cx = cx
        self._executor = ThreadPoolExecutor(max_workers=3)
    
    async def search(
        self, 
        query: str, 
        num_results: int = 10,
        start: int = 1
    ) -> list[dict]:
        """
        Search for URLs matching the query.
        
        Args:
            query: Search query string
            num_results: Number of results to return (max 10 per request)
            start: Starting index for pagination
            
        Returns:
            List of dicts with 'url', 'title', 'snippet' keys
        """
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(
            self._executor,
            self._search_sync,
            query,
            num_results,
            start
        )
    
    def _search_sync(self, query: str, num_results: int, start: int) -> list[dict]:
        """Synchronous search implementation."""
        service = build("customsearch", "v1", developerKey=self.api_key)
        
        response = service.cse().list(
            q=query,
            cx=self.cx,
            num=min(num_results, 10),
            start=start
        ).execute()
        
        items = response.get("items", [])
        
        return [
            {
                "url": item.get("link", ""),
                "title": item.get("title", ""),
                "snippet": item.get("snippet", "")
            }
            for item in items
        ]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd lead_gen_agents && python -m pytest tests/test_search_api.py -v`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lead_gen_agents/backend/tools/search_api.py lead_gen_agents/tests/test_search_api.py
git commit -m "feat: add Google Custom Search API client"
```

---

### Task 7: Create Web Fetcher Tool

**Files:**
- Create: `lead_gen_agents/backend/tools/web_fetcher.py`
- Test: `lead_gen_agents/tests/test_web_fetcher.py`

- [ ] **Step 1: Write the failing test**

```python
# lead_gen_agents/tests/test_web_fetcher.py
import pytest
from backend.tools.web_fetcher import WebFetcher, ScraperMode

@pytest.fixture
def sample_html():
    """Sample HTML for testing."""
    return """
    <html>
        <body>
            <div class="contact">
                <h1>John Doe</h1>
                <p class="title">CEO</p>
                <a href="mailto:john@example.com">john@example.com</a>
                <span class="company">Acme Inc</span>
            </div>
        </body>
    </html>
    """

def test_web_fetcher_initialization():
    """Test WebFetcher initializes correctly."""
    fetcher = WebFetcher(mode=ScraperMode.BEAUTIFULSOUP)
    assert fetcher.mode == ScraperMode.BEAUTIFULSOUP

def test_extract_emails():
    """Test email extraction from HTML."""
    fetcher = WebFetcher(mode=ScraperMode.BEAUTIFULSOUP)
    html = '<a href="mailto:test@example.com">Email</a>'
    emails = fetcher._extract_emails(html)
    assert "test@example.com" in emails

def test_extract_names_titles(sample_html):
    """Test name and title extraction."""
    fetcher = WebFetcher(mode=ScraperMode.BEAUTIFULSOUP)
    from bs4 import BeautifulSoup
    soup = BeautifulSoup(sample_html, "html.parser")
    
    # Find contact sections
    contacts = soup.find_all(class_="contact")
    assert len(contacts) > 0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd lead_gen_agents && python -m pytest tests/test_web_fetcher.py -v`
Expected: FAIL with "ModuleNotFoundError"

- [ ] **Step 3: Write the implementation**

```python
# lead_gen_agents/backend/tools/web_fetcher.py
from bs4 import BeautifulSoup
from playwright.async_api import async_playwright
import httpx
import asyncio
import re
from typing import Optional
from enum import Enum
from dataclasses import dataclass

class ScraperMode(Enum):
    BEAUTIFULSOUP = "beautifulsoup"
    PLAYWRIGHT = "playwright"
    HYBRID = "hybrid"

@dataclass
class ScrapedLead:
    """A scraped lead with extracted data."""
    name: Optional[str] = None
    email: Optional[str] = None
    company: Optional[str] = None
    title: Optional[str] = None
    source_url: str = ""

class WebFetcher:
    """Fetch and scrape lead data from web pages."""
    
    EMAIL_PATTERN = re.compile(r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}")
    
    def __init__(
        self, 
        mode: ScraperMode = ScraperMode.HYBRID,
        timeout: int = 30,
        user_agent: str = "Mozilla/5.0 (compatible; LeadGenBot/1.0)"
    ):
        self.mode = mode
        self.timeout = timeout
        self.user_agent = user_agent
    
    async def fetch_and_scrape(self, url: str) -> list[ScrapedLead]:
        """
        Fetch a URL and extract lead data.
        
        Args:
            url: URL to scrape
            
        Returns:
            List of ScrapedLead objects found on the page
        """
        if self.mode == ScraperMode.PLAYWRIGHT:
            return await self._scrape_with_playwright(url)
        elif self.mode == ScraperMode.BEAUTIFULSOUP:
            return await self._scrape_with_beautifulsoup(url)
        else:  # HYBRID
            leads = await self._scrape_with_beautifulsoup(url)
            if not leads:
                leads = await self._scrape_with_playwright(url)
            return leads
    
    async def _scrape_with_beautifulsoup(self, url: str) -> list[ScrapedLead]:
        """Scrape using BeautifulSoup (static HTML only)."""
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.get(
                    url, 
                    headers={"User-Agent": self.user_agent}
                )
                response.raise_for_status()
            
            return self._parse_html(response.text, url)
        except Exception:
            return []
    
    async def _scrape_with_playwright(self, url: str) -> list[ScrapedLead]:
        """Scrape using Playwright (handles JS)."""
        try:
            async with async_playwright() as p:
                browser = await p.chromium.launch(headless=True)
                page = await browser.new_page()
                await page.goto(url, timeout=self.timeout * 1000)
                html = await page.content()
                await browser.close()
            
            return self._parse_html(html, url)
        except Exception:
            return []
    
    def _parse_html(self, html: str, source_url: str) -> list[ScrapedLead]:
        """Parse HTML and extract leads."""
        soup = BeautifulSoup(html, "html.parser")
        leads = []
        
        # Extract emails first
        emails = self._extract_emails(html)
        
        # Look for contact sections
        contact_sections = soup.find_all(
            class_=re.compile(r"contact|team|about|staff|people", re.I)
        )
        
        if not contact_sections:
            # Try to find any structured content
            contact_sections = soup.find_all(["div", "section", "article"])
        
        for section in contact_sections:
            lead = self._extract_lead_from_section(section, emails, source_url)
            if lead and lead.email:
                leads.append(lead)
        
        # If no structured leads found, create leads from emails
        if not leads and emails:
            for email in emails[:5]:  # Limit to 5 emails per page
                leads.append(ScrapedLead(
                    email=email,
                    source_url=source_url
                ))
        
        return leads
    
    def _extract_emails(self, html: str) -> list[str]:
        """Extract email addresses from HTML."""
        return list(set(self.EMAIL_PATTERN.findall(html)))
    
    def _extract_lead_from_section(
        self, 
        section, 
        emails: list[str],
        source_url: str
    ) -> Optional[ScrapedLead]:
        """Extract a single lead from a section."""
        text = section.get_text(" ", strip=True)
        
        # Find name (usually in h1, h2, h3, or strong)
        name_elem = section.find(["h1", "h2", "h3", "strong", "b"])
        name = name_elem.get_text(strip=True) if name_elem else None
        
        # Find title (look for common patterns)
        title = None
        title_patterns = ["title", "position", "role"]
        for pattern in title_patterns:
            elem = section.find(class_=re.compile(pattern, re.I))
            if elem:
                title = elem.get_text(strip=True)
                break
        
        # Find company
        company = None
        company_elem = section.find(class_=re.compile(r"company|organization", re.I))
        if company_elem:
            company = company_elem.get_text(strip=True)
        
        # Find email in this section
        email = None
        section_emails = self._extract_emails(str(section))
        if section_emails:
            email = section_emails[0]
        
        # Only return if we have at least an email
        if not any([name, email, company, title]):
            return None
        
        return ScrapedLead(
            name=name,
            email=email,
            company=company,
            title=title,
            source_url=source_url
        )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd lead_gen_agents && python -m pytest tests/test_web_fetcher.py -v`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lead_gen_agents/backend/tools/web_fetcher.py lead_gen_agents/tests/test_web_fetcher.py
git commit -m "feat: add web fetcher with BeautifulSoup and Playwright"
```

---

### Task 8: Create Storage/Export Tool

**Files:**
- Create: `lead_gen_agents/backend/tools/storage.py`
- Test: `lead_gen_agents/tests/test_storage.py`

- [ ] **Step 1: Write the failing test**

```python
# lead_gen_agents/tests/test_storage.py
import pytest
import os
import tempfile
from backend.tools.storage import Storage

@pytest.fixture
def temp_dir():
    """Create a temporary directory for testing."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield tmpdir

def test_storage_initialization(temp_dir):
    """Test Storage initializes correctly."""
    storage = Storage(export_dir=temp_dir)
    assert storage.export_dir == temp_dir

def test_export_to_csv(temp_dir):
    """Test exporting leads to CSV."""
    storage = Storage(export_dir=temp_dir)
    leads = [
        {"name": "John Doe", "email": "john@example.com", "company": "Acme", "title": "CEO", "source_url": "https://example.com"},
        {"name": "Jane Smith", "email": "jane@example.com", "company": "Beta", "title": "CTO", "source_url": "https://example.com"},
    ]
    
    filepath = storage.export_to_csv(leads, "test-job")
    
    assert os.path.exists(filepath)
    assert filepath.endswith(".csv")
    
    # Verify content
    with open(filepath, "r") as f:
        content = f.read()
        assert "John Doe" in content
        assert "john@example.com" in content

def test_export_to_json(temp_dir):
    """Test exporting leads to JSON."""
    storage = Storage(export_dir=temp_dir)
    leads = [
        {"name": "John Doe", "email": "john@example.com", "company": "Acme", "title": "CEO", "source_url": "https://example.com"},
    ]
    
    filepath = storage.export_to_json(leads, "test-job")
    
    assert os.path.exists(filepath)
    assert filepath.endswith(".json")
    
    import json
    with open(filepath, "r") as f:
        data = json.load(f)
        assert len(data) == 1
        assert data[0]["name"] == "John Doe"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd lead_gen_agents && python -m pytest tests/test_storage.py -v`
Expected: FAIL with "ModuleNotFoundError"

- [ ] **Step 3: Write the implementation**

```python
# lead_gen_agents/backend/tools/storage.py
import os
import csv
import json
from typing import Optional

class Storage:
    """Handle export and storage of lead data."""
    
    def __init__(self, export_dir: str = "exports"):
        """
        Initialize storage.
        
        Args:
            export_dir: Directory to store exported files
        """
        self.export_dir = export_dir
        os.makedirs(export_dir, exist_ok=True)
    
    def export_to_csv(self, leads: list[dict], job_id: str) -> str:
        """
        Export leads to a CSV file.
        
        Args:
            leads: List of lead dictionaries
            job_id: Job identifier for filename
            
        Returns:
            Path to the created CSV file
        """
        filename = f"{job_id}_leads.csv"
        filepath = os.path.join(self.export_dir, filename)
        
        if not leads:
            # Create empty file with headers
            with open(filepath, "w", newline="") as f:
                writer = csv.writer(f)
                writer.writerow(["name", "email", "company", "title", "source_url"])
            return filepath
        
        fieldnames = ["name", "email", "company", "title", "source_url"]
        
        with open(filepath, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(leads)
        
        return filepath
    
    def export_to_json(self, leads: list[dict], job_id: str) -> str:
        """
        Export leads to a JSON file.
        
        Args:
            leads: List of lead dictionaries
            job_id: Job identifier for filename
            
        Returns:
            Path to the created JSON file
        """
        filename = f"{job_id}_leads.json"
        filepath = os.path.join(self.export_dir, filename)
        
        with open(filepath, "w") as f:
            json.dump(leads, f, indent=2)
        
        return filepath
    
    def get_export_path(self, job_id: str, format: str) -> str:
        """
        Get the path for an export file.
        
        Args:
            job_id: Job identifier
            format: Export format ("csv" or "json")
            
        Returns:
            Full path to the export file
        """
        extension = "csv" if format == "csv" else "json"
        filename = f"{job_id}_leads.{extension}"
        return os.path.join(self.export_dir, filename)
    
    def file_exists(self, job_id: str, format: str) -> bool:
        """Check if an export file exists."""
        return os.path.exists(self.get_export_path(job_id, format))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd lead_gen_agents && python -m pytest tests/test_storage.py -v`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lead_gen_agents/backend/tools/storage.py lead_gen_agents/tests/test_storage.py
git commit -m "feat: add storage module for CSV/JSON export"
```

---

## Phase 4: Agents

### Task 9: Create Discovery Agent

**Files:**
- Create: `lead_gen_agents/backend/agents/discovery.py`
- Test: `lead_gen_agents/tests/test_discovery.py`

- [ ] **Step 1: Write the failing test**

```python
# lead_gen_agents/tests/test_discovery.py
import pytest
from unittest.mock import AsyncMock, patch
from backend.agents.discovery import DiscoveryAgent
from backend.agents.state import create_initial_state

@pytest.fixture
def mock_search_client():
    """Mock Google Search client."""
    client = AsyncMock()
    client.search.return_value = [
        {"url": "https://example1.com", "title": "Example 1"},
        {"url": "https://example2.com", "title": "Example 2"},
    ]
    return client

def test_discovery_agent_initialization():
    """Test DiscoveryAgent initializes correctly."""
    agent = DiscoveryAgent(api_key="test", cx="test")
    assert agent.api_key == "test"

@pytest.mark.asyncio
async def test_discovery_agent_finds_urls(mock_search_client):
    """Test discovery agent finds URLs from query."""
    agent = DiscoveryAgent(api_key="test", cx="test")
    agent.search_client = mock_search_client
    
    state = create_initial_state(
        job_id="test-job",
        query="find SaaS founders"
    )
    
    result = await agent.run(state)
    
    assert len(result["discovered_urls"]) == 2
    assert result["current_stage"] == "discovery"
    assert result["discovered_urls"][0]["url"] == "https://example1.com"

@pytest.mark.asyncio
async def test_discovery_agent_uses_seed_urls():
    """Test discovery agent uses provided seed URLs."""
    agent = DiscoveryAgent(api_key="test", cx="test")
    
    state = create_initial_state(
        job_id="test-job",
        query="test",
        seed_urls=["https://provided.com"]
    )
    
    result = await agent.run(state)
    
    # Should include provided seed URLs
    assert len(result["discovered_urls"]) >= 1
    assert any(u["url"] == "https://provided.com" for u in result["discovered_urls"])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd lead_gen_agents && python -m pytest tests/test_discovery.py -v`
Expected: FAIL with "ModuleNotFoundError"

- [ ] **Step 3: Write the implementation**

```python
# lead_gen_agents/backend/agents/discovery.py
from typing import Optional
from backend.tools.search_api import GoogleSearchClient
from backend.agents.state import LeadGraphState
from backend.config.settings import settings
import asyncio

class DiscoveryAgent:
    """Agent that discovers target URLs for lead scraping."""
    
    def __init__(
        self, 
        api_key: Optional[str] = None,
        cx: Optional[str] = None,
        max_results: int = 10
    ):
        """
        Initialize Discovery Agent.
        
        Args:
            api_key: Google API key (defaults to settings)
            cx: Google Custom Search CX (defaults to settings)
            max_results: Maximum number of URLs to discover
        """
        self.api_key = api_key or settings.google_api_key
        self.cx = cx or settings.google_cx
        self.max_results = max_results
        self.search_client = GoogleSearchClient(self.api_key, self.cx)
    
    async def run(self, state: LeadGraphState) -> LeadGraphState:
        """
        Run the discovery process.
        
        Args:
            state: Current graph state
            
        Returns:
            Updated state with discovered_urls populated
        """
        state["current_stage"] = "discovery"
        discovered_urls = []
        
        # Use seed URLs if provided
        for url in state.get("seed_urls", []):
            discovered_urls.append({
                "url": url,
                "source": "seed",
                "priority": 1
            })
        
        # Search if query is provided and we have API credentials
        if state["query"] and self.api_key and self.cx:
            try:
                results = await self.search_client.search(
                    state["query"],
                    num_results=self.max_results
                )
                for i, result in enumerate(results):
                    discovered_urls.append({
                        "url": result["url"],
                        "source": "search",
                        "priority": i + 1,
                        "title": result.get("title", "")
                    })
            except Exception as e:
                state["errors"].append({
                    "agent": "discovery",
                    "url": "search",
                    "error": str(e)
                })
        
        state["discovered_urls"] = discovered_urls
        return state
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd lead_gen_agents && python -m pytest tests/test_discovery.py -v`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lead_gen_agents/backend/agents/discovery.py lead_gen_agents/tests/test_discovery.py
git commit -m "feat: add Discovery agent for URL discovery"
```

---

### Task 10: Create Scraper Agent

**Files:**
- Create: `lead_gen_agents/backend/agents/scraper.py`
- Test: `lead_gen_agents/tests/test_scraper.py`

- [ ] **Step 1: Write the failing test**

```python
# lead_gen_agents/tests/test_scraper.py
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from backend.agents.scraper import ScraperAgent
from backend.agents.state import create_initial_state

def test_scraper_agent_initialization():
    """Test ScraperAgent initializes correctly."""
    agent = ScraperAgent(mode="hybrid")
    assert agent.mode == "hybrid"

@pytest.mark.asyncio
async def test_scraper_agent_extracts_leads():
    """Test scraper agent extracts leads from URLs."""
    agent = ScraperAgent(mode="beautifulsoup")
    
    state = create_initial_state(
        job_id="test-job",
        query="test"
    )
    state["discovered_urls"] = [
        {"url": "https://example.com", "source": "search", "priority": 1}
    ]
    
    # Mock the web fetcher
    with patch("backend.agents.scraper.WebFetcher") as MockFetcher:
        mock_fetcher = MagicMock()
        MockFetcher.return_value = mock_fetcher
        
        # Create a mock lead
        mock_lead = MagicMock()
        mock_lead.name = "John Doe"
        mock_lead.email = "john@example.com"
        mock_lead.company = "Acme Inc"
        mock_lead.title = "CEO"
        mock_lead.source_url = "https://example.com"
        
        mock_fetcher.fetch_and_scrape = AsyncMock(return_value=[mock_lead])
        
        result = await agent.run(state)
        
        assert len(result["raw_leads"]) >= 1
        assert result["current_stage"] == "scraping"

@pytest.mark.asyncio
async def test_scraper_agent_handles_errors():
    """Test scraper agent handles scraping errors gracefully."""
    agent = ScraperAgent(mode="beautifulsoup")
    
    state = create_initial_state(
        job_id="test-job",
        query="test"
    )
    state["discovered_urls"] = [
        {"url": "https://bad-url.com", "source": "search", "priority": 1}
    ]
    
    with patch("backend.agents.scraper.WebFetcher") as MockFetcher:
        mock_fetcher = MagicMock()
        MockFetcher.return_value = mock_fetcher
        mock_fetcher.fetch_and_scrape = AsyncMock(side_effect=Exception("Network error"))
        
        result = await agent.run(state)
        
        # Should not crash, should log error
        assert result["current_stage"] == "scraping"
        assert len(result["errors"]) >= 1
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd lead_gen_agents && python -m pytest tests/test_scraper.py -v`
Expected: FAIL with "ModuleNotFoundError"

- [ ] **Step 3: Write the implementation**

```python
# lead_gen_agents/backend/agents/scraper.py
from typing import Literal
from backend.tools.web_fetcher import WebFetcher, ScraperMode
from backend.agents.state import LeadGraphState
from backend.config.settings import settings
import asyncio
from dataclasses import asdict

class ScraperAgent:
    """Agent that scrapes lead data from discovered URLs."""
    
    def __init__(
        self,
        mode: Literal["beautifulsoup", "playwright", "hybrid"] = "hybrid",
        timeout: int = 30,
        request_delay: float = 1.0
    ):
        """
        Initialize Scraper Agent.
        
        Args:
            mode: Scraping mode (beautifulsoup, playwright, hybrid)
            timeout: Request timeout in seconds
            request_delay: Delay between requests in seconds
        """
        self.mode = mode
        self.timeout = timeout
        self.request_delay = request_delay
        
        # Map mode string to enum
        mode_map = {
            "beautifulsoup": ScraperMode.BEAUTIFULSOUP,
            "playwright": ScraperMode.PLAYWRIGHT,
            "hybrid": ScraperMode.HYBRID
        }
        self.fetcher = WebFetcher(
            mode=mode_map.get(mode, ScraperMode.HYBRID),
            timeout=timeout
        )
    
    async def run(self, state: LeadGraphState) -> LeadGraphState:
        """
        Run the scraping process.
        
        Args:
            state: Current graph state with discovered_urls
            
        Returns:
            Updated state with raw_leads populated
        """
        state["current_stage"] = "scraping"
        raw_leads = []
        
        urls_to_scrape = state.get("discovered_urls", [])
        
        for url_info in urls_to_scrape:
            url = url_info["url"]
            
            try:
                leads = await self.fetcher.fetch_and_scrape(url)
                
                for lead in leads:
                    lead_dict = asdict(lead)
                    lead_dict["source_url"] = url
                    raw_leads.append(lead_dict)
                
                # Rate limiting
                await asyncio.sleep(self.request_delay)
                
            except Exception as e:
                state["errors"].append({
                    "agent": "scraper",
                    "url": url,
                    "error": str(e)
                })
        
        state["raw_leads"] = raw_leads
        return state
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd lead_gen_agents && python -m pytest tests/test_scraper.py -v`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lead_gen_agents/backend/agents/scraper.py lead_gen_agents/tests/test_scraper.py
git commit -m "feat: add Scraper agent for lead extraction"
```

---

### Task 11: Create Export Agent

**Files:**
- Create: `lead_gen_agents/backend/agents/export.py`
- Test: `lead_gen_agents/tests/test_export.py`

- [ ] **Step 1: Write the failing test**

```python
# lead_gen_agents/tests/test_export.py
import pytest
import os
import tempfile
from backend.agents.export import ExportAgent
from backend.agents.state import create_initial_state

@pytest.fixture
def temp_dir():
    """Create a temporary directory for testing."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield tmpdir

def test_export_agent_initialization(temp_dir):
    """Test ExportAgent initializes correctly."""
    agent = ExportAgent(export_dir=temp_dir)
    assert agent.export_dir == temp_dir

@pytest.mark.asyncio
async def test_export_agent_creates_csv(temp_dir):
    """Test export agent creates CSV file."""
    agent = ExportAgent(export_dir=temp_dir)
    
    state = create_initial_state(
        job_id="test-job",
        query="test",
        export_format="csv"
    )
    state["raw_leads"] = [
        {"name": "John Doe", "email": "john@example.com", "company": "Acme", "title": "CEO", "source_url": "https://example.com"}
    ]
    
    result = await agent.run(state)
    
    assert result["export_path"] is not None
    assert os.path.exists(result["export_path"])
    assert result["current_stage"] == "complete"

@pytest.mark.asyncio
async def test_export_agent_creates_json(temp_dir):
    """Test export agent creates JSON file."""
    agent = ExportAgent(export_dir=temp_dir)
    
    state = create_initial_state(
        job_id="test-job",
        query="test",
        export_format="json"
    )
    state["raw_leads"] = [
        {"name": "John Doe", "email": "john@example.com", "company": "Acme", "title": "CEO", "source_url": "https://example.com"}
    ]
    
    result = await agent.run(state)
    
    assert result["export_path"] is not None
    assert result["export_path"].endswith(".json")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd lead_gen_agents && python -m pytest tests/test_export.py -v`
Expected: FAIL with "ModuleNotFoundError"

- [ ] **Step 3: Write the implementation**

```python
# lead_gen_agents/backend/agents/export.py
from backend.tools.storage import Storage
from backend.agents.state import LeadGraphState
from backend.config.settings import settings
from typing import Literal

class ExportAgent:
    """Agent that exports leads to files."""
    
    def __init__(
        self,
        export_dir: str = "exports",
        default_format: Literal["csv", "json"] = "csv"
    ):
        """
        Initialize Export Agent.
        
        Args:
            export_dir: Directory for export files
            default_format: Default export format
        """
        self.export_dir = export_dir
        self.default_format = default_format
        self.storage = Storage(export_dir)
    
    async def run(self, state: LeadGraphState) -> LeadGraphState:
        """
        Run the export process.
        
        Args:
            state: Current graph state with raw_leads
            
        Returns:
            Updated state with export_path set
        """
        state["current_stage"] = "export"
        
        format_type = state.get("export_format", self.default_format)
        leads = state.get("raw_leads", [])
        job_id = state["job_id"]
        
        if format_type == "json":
            filepath = self.storage.export_to_json(leads, job_id)
        else:
            filepath = self.storage.export_to_csv(leads, job_id)
        
        state["export_path"] = filepath
        state["current_stage"] = "complete"
        
        return state
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd lead_gen_agents && python -m pytest tests/test_export.py -v`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lead_gen_agents/backend/agents/export.py lead_gen_agents/tests/test_export.py
git commit -m "feat: add Export agent for CSV/JSON output"
```

---

### Task 12: Create LangGraph Orchestrator

**Files:**
- Create: `lead_gen_agents/backend/agents/orchestrator/graph.py`
- Test: `lead_gen_agents/tests/test_orchestrator.py`

- [ ] **Step 1: Write the failing test**

```python
# lead_gen_agents/tests/test_orchestrator.py
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from backend.agents.orchestrator.graph import create_lead_graph, run_lead_generation
from backend.agents.state import create_initial_state

def test_create_lead_graph():
    """Test that the graph is created with correct nodes."""
    graph = create_lead_graph()
    
    # Graph should have nodes
    assert graph is not None

@pytest.mark.asyncio
async def test_graph_executes_full_workflow():
    """Test that the graph executes discovery -> scraper -> export."""
    state = create_initial_state(
        job_id="test-job",
        query="test query"
    )
    
    with patch("backend.agents.orchestrator.graph.DiscoveryAgent") as MockDiscovery, \
         patch("backend.agents.orchestrator.graph.ScraperAgent") as MockScraper, \
         patch("backend.agents.orchestrator.graph.ExportAgent") as MockExport:
        
        # Mock the agents
        mock_discovery = MagicMock()
        mock_discovery.run = AsyncMock(return_value=state)
        MockDiscovery.return_value = mock_discovery
        
        mock_scraper = MagicMock()
        mock_scraper.run = AsyncMock(return_value=state)
        MockScraper.return_value = mock_scraper
        
        mock_export = MagicMock()
        mock_export.run = AsyncMock(return_value=state)
        MockExport.return_value = mock_export
        
        result = await run_lead_generation(state)
        
        # All agents should have been called
        mock_discovery.run.assert_called_once()
        mock_scraper.run.assert_called_once()
        mock_export.run.assert_called_once()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd lead_gen_agents && python -m pytest tests/test_orchestrator.py -v`
Expected: FAIL with "ModuleNotFoundError"

- [ ] **Step 3: Write the implementation**

```python
# lead_gen_agents/backend/agents/orchestrator/graph.py
from langgraph.graph import StateGraph, END
from backend.agents.state import LeadGraphState
from backend.agents.discovery import DiscoveryAgent
from backend.agents.scraper import ScraperAgent
from backend.agents.export import ExportAgent
from backend.config.settings import settings
import asyncio
from typing import Literal

# Global agent instances
_discovery_agent = None
_scraper_agent = None
_export_agent = None

def get_agents():
    """Get or create agent instances."""
    global _discovery_agent, _scraper_agent, _export_agent
    
    if _discovery_agent is None:
        _discovery_agent = DiscoveryAgent()
    if _scraper_agent is None:
        _scraper_agent = ScraperAgent(mode=settings.scraper_mode)
    if _export_agent is None:
        _export_agent = ExportAgent(export_dir=settings.export_dir)
    
    return _discovery_agent, _scraper_agent, _export_agent

async def discovery_node(state: LeadGraphState) -> LeadGraphState:
    """Discovery node in the graph."""
    discovery, _, _ = get_agents()
    return await discovery.run(state)

async def scraper_node(state: LeadGraphState) -> LeadGraphState:
    """Scraper node in the graph."""
    _, scraper, _ = get_agents()
    return await scraper.run(state)

async def export_node(state: LeadGraphState) -> LeadGraphState:
    """Export node in the graph."""
    _, _, export = get_agents()
    return await export.run(state)

def should_continue(state: LeadGraphState) -> Literal["continue", "end"]:
    """Determine if we should continue or end."""
    if state.get("current_stage") == "discovery":
        if not state.get("discovered_urls"):
            return "end"
    return "continue"

def create_lead_graph():
    """Create the LangGraph workflow."""
    graph = StateGraph(LeadGraphState)
    
    # Add nodes
    graph.add_node("discovery", discovery_node)
    graph.add_node("scraper", scraper_node)
    graph.add_node("export", export_node)
    
    # Set entry point
    graph.set_entry_point("discovery")
    
    # Add conditional edge from discovery
    graph.add_conditional_edges(
        "discovery",
        should_continue,
        {
            "continue": "scraper",
            "end": END
        }
    )
    
    # Add edge from scraper to export
    graph.add_edge("scraper", "export")
    
    # Set finish point
    graph.set_finish_point("export")
    
    return graph.compile()

async def run_lead_generation(state: LeadGraphState) -> LeadGraphState:
    """
    Run the full lead generation workflow.
    
    Args:
        state: Initial state with query and config
        
    Returns:
        Final state with results
    """
    graph = create_lead_graph()
    result = await graph.ainvoke(state)
    return result
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd lead_gen_agents && python -m pytest tests/test_orchestrator.py -v`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lead_gen_agents/backend/agents/orchestrator/graph.py lead_gen_agents/tests/test_orchestrator.py
git commit -m "feat: add LangGraph orchestrator for workflow coordination"
```

---

## Phase 5: Job Manager & WebSocket

### Task 13: Create Job Manager

**Files:**
- Create: `lead_gen_agents/backend/jobs/manager.py`
- Test: `lead_gen_agents/tests/test_jobs.py`

- [ ] **Step 1: Write the failing test**

```python
# lead_gen_agents/tests/test_jobs.py
import pytest
from backend.jobs.manager import JobManager, JobStatus as InternalJobStatus

def test_job_manager_initialization():
    """Test JobManager initializes correctly."""
    manager = JobManager()
    assert manager is not None

def test_create_job():
    """Test creating a new job."""
    manager = JobManager()
    job_id = manager.create_job(
        query="test query",
        filters={"industry": "tech"},
        seed_urls=["https://example.com"],
        scraper_mode="hybrid"
    )
    
    assert job_id is not None
    status = manager.get_status(job_id)
    assert status.status == "pending"

def test_update_status():
    """Test updating job status."""
    manager = JobManager()
    job_id = manager.create_job(query="test")
    
    manager.update_status(job_id, "discovering", progress=0.3, leads_found=5)
    status = manager.get_status(job_id)
    
    assert status.status == "discovering"
    assert status.progress == 0.3
    assert status.leads_found == 5

def test_store_leads():
    """Test storing leads for a job."""
    manager = JobManager()
    job_id = manager.create_job(query="test")
    
    leads = [
        {"name": "John Doe", "email": "john@example.com", "company": "Acme", "title": "CEO", "source_url": "https://example.com"}
    ]
    manager.store_leads(job_id, leads)
    
    stored = manager.get_leads(job_id)
    assert len(stored) == 1
    assert stored[0]["name"] == "John Doe"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd lead_gen_agents && python -m pytest tests/test_jobs.py -v`
Expected: FAIL with "ModuleNotFoundError"

- [ ] **Step 3: Write the implementation**

```python
# lead_gen_agents/backend/jobs/manager.py
import uuid
from dataclasses import dataclass, field
from typing import Optional
from datetime import datetime
from enum import Enum
import asyncio

class JobStatusEnum(str, Enum):
    PENDING = "pending"
    DISCOVERING = "discovering"
    SCRAPING = "scraping"
    EXPORTING = "exporting"
    COMPLETED = "completed"
    FAILED = "failed"

@dataclass
class JobStatus:
    """Status of a job."""
    job_id: str
    status: str = "pending"
    progress: float = 0.0
    leads_found: int = 0
    current_stage: str = "init"
    error: Optional[str] = None
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)

@dataclass
class Job:
    """A lead generation job."""
    job_id: str
    query: str
    filters: dict
    seed_urls: list[str]
    scraper_mode: str
    export_format: str
    status: JobStatus
    leads: list[dict] = field(default_factory=list)
    export_path: Optional[str] = None
    task: Optional[asyncio.Task] = None

class JobManager:
    """Manages lead generation jobs."""
    
    def __init__(self):
        self.jobs: dict[str, Job] = {}
        self._lock = asyncio.Lock()
    
    def create_job(
        self,
        query: str,
        filters: Optional[dict] = None,
        seed_urls: Optional[list[str]] = None,
        scraper_mode: str = "hybrid",
        export_format: str = "csv"
    ) -> str:
        """
        Create a new job.
        
        Returns:
            Job ID
        """
        job_id = str(uuid.uuid4())[:8]
        
        job = Job(
            job_id=job_id,
            query=query,
            filters=filters or {},
            seed_urls=seed_urls or [],
            scraper_mode=scraper_mode,
            export_format=export_format,
            status=JobStatus(job_id=job_id)
        )
        
        self.jobs[job_id] = job
        return job_id
    
    def get_status(self, job_id: str) -> Optional[JobStatus]:
        """Get the status of a job."""
        job = self.jobs.get(job_id)
        return job.status if job else None
    
    def update_status(
        self,
        job_id: str,
        status: Optional[str] = None,
        progress: Optional[float] = None,
        leads_found: Optional[int] = None,
        current_stage: Optional[str] = None,
        error: Optional[str] = None
    ):
        """Update job status."""
        job = self.jobs.get(job_id)
        if not job:
            return
        
        if status:
            job.status.status = status
        if progress is not None:
            job.status.progress = progress
        if leads_found is not None:
            job.status.leads_found = leads_found
        if current_stage:
            job.status.current_stage = current_stage
        if error:
            job.status.error = error
        
        job.status.updated_at = datetime.now()
    
    def store_leads(self, job_id: str, leads: list[dict]):
        """Store leads for a job."""
        job = self.jobs.get(job_id)
        if job:
            job.leads = leads
            job.status.leads_found = len(leads)
    
    def get_leads(self, job_id: str) -> list[dict]:
        """Get leads for a job."""
        job = self.jobs.get(job_id)
        return job.leads if job else []
    
    def set_export_path(self, job_id: str, path: str):
        """Set the export path for a job."""
        job = self.jobs.get(job_id)
        if job:
            job.export_path = path
    
    def get_export_path(self, job_id: str) -> Optional[str]:
        """Get the export path for a job."""
        job = self.jobs.get(job_id)
        return job.export_path if job else None
    
    def set_task(self, job_id: str, task: asyncio.Task):
        """Set the asyncio task for a job."""
        job = self.jobs.get(job_id)
        if job:
            job.task = task

# Global job manager instance
job_manager = JobManager()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd lead_gen_agents && python -m pytest tests/test_jobs.py -v`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lead_gen_agents/backend/jobs/manager.py lead_gen_agents/tests/test_jobs.py
git commit -m "feat: add job manager for tracking lead generation jobs"
```

---

### Task 14: Create WebSocket Handler

**Files:**
- Create: `lead_gen_agents/backend/api/websocket.py`
- Test: `lead_gen_agents/tests/test_websocket.py`

- [ ] **Step 1: Write the failing test**

```python
# lead_gen_agents/tests/test_websocket.py
import pytest
from backend.api.websocket import ConnectionManager

def test_connection_manager_initialization():
    """Test ConnectionManager initializes correctly."""
    manager = ConnectionManager()
    assert manager.active_connections == {}

@pytest.mark.asyncio
async def test_connect_disconnect():
    """Test connecting and disconnecting a client."""
    manager = ConnectionManager()
    
    # Mock websocket
    class MockWebsocket:
        async def accept(self):
            pass
    
    ws = MockWebsocket()
    await manager.connect("job-123", ws)
    
    assert "job-123" in manager.active_connections
    assert ws in manager.active_connections["job-123"]
    
    manager.disconnect("job-123", ws)
    assert "job-123" not in manager.active_connections

@pytest.mark.asyncio
async def test_broadcast():
    """Test broadcasting to all connections for a job."""
    manager = ConnectionManager()
    
    messages = []
    
    class MockWebsocket:
        async def accept(self):
            pass
        async def send_json(self, data):
            messages.append(data)
    
    ws = MockWebsocket()
    await manager.connect("job-123", ws)
    
    await manager.broadcast("job-123", {"status": "scraping", "progress": 0.5})
    
    assert len(messages) == 1
    assert messages[0]["status"] == "scraping"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd lead_gen_agents && python -m pytest tests/test_websocket.py -v`
Expected: FAIL with "ModuleNotFoundError"

- [ ] **Step 3: Write the implementation**

```python
# lead_gen_agents/backend/api/websocket.py
from fastapi import WebSocket
from typing import Dict, List
import asyncio
import json

class ConnectionManager:
    """Manages WebSocket connections for real-time updates."""
    
    def __init__(self):
        # Map of job_id -> list of websocket connections
        self.active_connections: Dict[str, List[WebSocket]] = {}
        self._lock = asyncio.Lock()
    
    async def connect(self, job_id: str, websocket: WebSocket):
        """
        Accept and store a new WebSocket connection.
        
        Args:
            job_id: Job to subscribe to
            websocket: WebSocket connection
        """
        await websocket.accept()
        
        async with self._lock:
            if job_id not in self.active_connections:
                self.active_connections[job_id] = []
            self.active_connections[job_id].append(websocket)
    
    def disconnect(self, job_id: str, websocket: WebSocket):
        """
        Remove a WebSocket connection.
        
        Args:
            job_id: Job the connection was subscribed to
            websocket: WebSocket connection to remove
        """
        if job_id in self.active_connections:
            if websocket in self.active_connections[job_id]:
                self.active_connections[job_id].remove(websocket)
            if not self.active_connections[job_id]:
                del self.active_connections[job_id]
    
    async def broadcast(self, job_id: str, message: dict):
        """
        Broadcast a message to all connections for a job.
        
        Args:
            job_id: Job to broadcast to
            message: Message to send
        """
        if job_id not in self.active_connections:
            return
        
        dead_connections = []
        
        for connection in self.active_connections[job_id]:
            try:
                await connection.send_json(message)
            except Exception:
                # Connection is dead, mark for removal
                dead_connections.append(connection)
        
        # Clean up dead connections
        for conn in dead_connections:
            self.disconnect(job_id, conn)
    
    async def send_personal(self, websocket: WebSocket, message: dict):
        """
        Send a message to a single connection.
        
        Args:
            websocket: Target connection
            message: Message to send
        """
        try:
            await websocket.send_json(message)
        except Exception:
            pass

# Global connection manager
manager = ConnectionManager()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd lead_gen_agents && python -m pytest tests/test_websocket.py -v`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lead_gen_agents/backend/api/websocket.py lead_gen_agents/tests/test_websocket.py
git commit -m "feat: add WebSocket connection manager for real-time updates"
```

---

## Phase 6: API Routes

### Task 15: Create Search Route

**Files:**
- Create: `lead_gen_agents/backend/api/routes/search.py`

- [ ] **Step 1: Write the implementation**

```python
# lead_gen_agents/backend/api/routes/search.py
from fastapi import APIRouter, BackgroundTasks
from backend.api.models import SearchRequest, SearchResponse
from backend.jobs.manager import job_manager
from backend.agents.orchestrator.graph import run_lead_generation
from backend.agents.state import create_initial_state
from backend.api.websocket import manager as ws_manager
import asyncio

router = APIRouter()

async def run_job(job_id: str, request: SearchRequest):
    """Run the lead generation job in background."""
    try:
        # Update status
        job_manager.update_status(job_id, "discovering", current_stage="discovery")
        await ws_manager.broadcast(job_id, {
            "type": "status",
            "status": "discovering",
            "progress": 0.1
        })
        
        # Create initial state
        state = create_initial_state(
            job_id=job_id,
            query=request.query,
            filters=request.filters,
            seed_urls=request.seed_urls,
            scraper_mode=request.scraper_mode.value
        )
        
        # Run discovery
        job_manager.update_status(job_id, "discovering", progress=0.2)
        await ws_manager.broadcast(job_id, {
            "type": "status",
            "status": "discovering",
            "progress": 0.2
        })
        
        # Run the full workflow
        result = await run_lead_generation(state)
        
        # Store leads
        leads = result.get("raw_leads", [])
        job_manager.store_leads(job_id, leads)
        job_manager.set_export_path(job_id, result.get("export_path"))
        
        # Update status to completed
        job_manager.update_status(
            job_id, 
            "completed", 
            progress=1.0,
            current_stage="complete",
            leads_found=len(leads)
        )
        
        await ws_manager.broadcast(job_id, {
            "type": "status",
            "status": "completed",
            "progress": 1.0,
            "leads_found": len(leads)
        })
        
    except Exception as e:
        job_manager.update_status(job_id, "failed", error=str(e))
        await ws_manager.broadcast(job_id, {
            "type": "error",
            "error": str(e)
        })

@router.post("/search", response_model=SearchResponse)
async def search(request: SearchRequest, background_tasks: BackgroundTasks):
    """
    Start a new lead generation search.
    
    Returns immediately with a job ID. Use the job ID to check status
    via /status/{job_id} or connect to /ws/status/{job_id} for real-time updates.
    """
    # Create job
    job_id = job_manager.create_job(
        query=request.query,
        filters=request.filters,
        seed_urls=request.seed_urls,
        scraper_mode=request.scraper_mode.value
    )
    
    # Start background task
    task = asyncio.create_task(run_job(job_id, request))
    job_manager.set_task(job_id, task)
    
    return SearchResponse(
        job_id=job_id,
        status="pending",
        message="Job started. Use /status/{job_id} to check progress."
    )
```

- [ ] **Step 2: Commit**

```bash
git add lead_gen_agents/backend/api/routes/search.py
git commit -m "feat: add search API route"
```

---

### Task 16: Create Status Route

**Files:**
- Create: `lead_gen_agents/backend/api/routes/status.py`

- [ ] **Step 1: Write the implementation**

```python
# lead_gen_agents/backend/api/routes/status.py
from fastapi import APIRouter, HTTPException
from backend.api.models import JobStatus
from backend.jobs.manager import job_manager

router = APIRouter()

@router.get("/status/{job_id}", response_model=JobStatus)
async def get_status(job_id: str):
    """
    Get the current status of a lead generation job.
    
    Returns the job status including progress, leads found, and any errors.
    """
    status = job_manager.get_status(job_id)
    
    if not status:
        raise HTTPException(status_code=404, detail="Job not found")
    
    return JobStatus(
        job_id=status.job_id,
        status=status.status,
        progress=status.progress,
        leads_found=status.leads_found,
        current_stage=status.current_stage,
        error=status.error
    )
```

- [ ] **Step 2: Commit**

```bash
git add lead_gen_agents/backend/api/routes/status.py
git commit -m "feat: add status API route"
```

---

### Task 17: Create Leads Route

**Files:**
- Create: `lead_gen_agents/backend/api/routes/leads.py`

- [ ] **Step 1: Write the implementation**

```python
# lead_gen_agents/backend/api/routes/leads.py
from fastapi import APIRouter, HTTPException
from backend.api.models import LeadsResponse, Lead
from backend.jobs.manager import job_manager

router = APIRouter()

@router.get("/leads/{job_id}", response_model=LeadsResponse)
async def get_leads(job_id: str):
    """
    Get the leads found by a job.
    
    Returns all leads discovered and scraped by the job.
    """
    status = job_manager.get_status(job_id)
    
    if not status:
        raise HTTPException(status_code=404, detail="Job not found")
    
    leads = job_manager.get_leads(job_id)
    
    return LeadsResponse(
        job_id=job_id,
        leads=[Lead(**lead) for lead in leads],
        total=len(leads)
    )
```

- [ ] **Step 2: Commit**

```bash
git add lead_gen_agents/backend/api/routes/leads.py
git commit -m "feat: add leads API route"
```

---

### Task 18: Create Export Route

**Files:**
- Create: `lead_gen_agents/backend/api/routes/export.py`

- [ ] **Step 1: Write the implementation**

```python
# lead_gen_agents/backend/api/routes/export.py
from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse
from backend.jobs.manager import job_manager

router = APIRouter()

@router.get("/export/{job_id}")
async def export_leads(job_id: str, format: str = "csv"):
    """
    Download leads as CSV or JSON file.
    
    Args:
        job_id: Job ID to export
        format: Export format ("csv" or "json")
        
    Returns:
        File download
    """
    status = job_manager.get_status(job_id)
    
    if not status:
        raise HTTPException(status_code=404, detail="Job not found")
    
    if status.status != "completed":
        raise HTTPException(
            status_code=400, 
            detail=f"Job is not completed. Current status: {status.status}"
        )
    
    export_path = job_manager.get_export_path(job_id)
    
    if not export_path:
        raise HTTPException(status_code=404, detail="Export file not found")
    
    filename = f"{job_id}_leads.{format}"
    
    return FileResponse(
        path=export_path,
        filename=filename,
        media_type="text/csv" if format == "csv" else "application/json"
    )
```

- [ ] **Step 2: Commit**

```bash
git add lead_gen_agents/backend/api/routes/export.py
git commit -m "feat: add export API route for file downloads"
```

---

### Task 19: Create Main FastAPI App

**Files:**
- Create: `lead_gen_agents/backend/api/main.py`
- Create: `lead_gen_agents/backend/main.py`

- [ ] **Step 1: Write the main.py (FastAPI app)**

```python
# lead_gen_agents/backend/api/main.py
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from backend.api.routes import search, status, leads, export
from backend.api.websocket import manager as ws_manager

# Create FastAPI app
app = FastAPI(
    title="Lead Generation Dashboard",
    description="API for lead generation using multi-agent system",
    version="0.1.0"
)

# Configure CORS for React frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(search.router, prefix="/api", tags=["search"])
app.include_router(status.router, prefix="/api", tags=["status"])
app.include_router(leads.router, prefix="/api", tags=["leads"])
app.include_router(export.router, prefix="/api", tags=["export"])

@app.get("/")
async def root():
    """Root endpoint."""
    return {"message": "Lead Generation Dashboard API", "docs": "/docs"}

@app.get("/health")
async def health():
    """Health check endpoint."""
    return {"status": "healthy"}

@app.websocket("/ws/status/{job_id}")
async def websocket_status(websocket: WebSocket, job_id: str):
    """
    WebSocket endpoint for real-time job status updates.
    
    Connect to receive status updates as they happen.
    """
    await ws_manager.connect(job_id, websocket)
    
    try:
        # Send initial status
        from backend.jobs.manager import job_manager
        status = job_manager.get_status(job_id)
        if status:
            await websocket.send_json({
                "type": "status",
                "status": status.status,
                "progress": status.progress,
                "leads_found": status.leads_found
            })
        
        # Keep connection alive and handle incoming messages
        while True:
            data = await websocket.receive_text()
            # Client can request status update
            if data == "status":
                status = job_manager.get_status(job_id)
                if status:
                    await websocket.send_json({
                        "type": "status",
                        "status": status.status,
                        "progress": status.progress,
                        "leads_found": status.leads_found
                    })
                    
    except WebSocketDisconnect:
        ws_manager.disconnect(job_id, websocket)
    except Exception:
        ws_manager.disconnect(job_id, websocket)
```

- [ ] **Step 2: Write entry point**

```python
# lead_gen_agents/backend/main.py
"""
Entry point for running the FastAPI server.
"""
import uvicorn
from backend.config.settings import settings

def main():
    """Run the FastAPI server."""
    uvicorn.run(
        "backend.api.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )

if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Commit**

```bash
git add lead_gen_agents/backend/api/main.py lead_gen_agents/backend/main.py
git commit -m "feat: add FastAPI application with all routes and WebSocket"
```

---

## Phase 7: Frontend

### Task 20: Create Frontend Package

**Files:**
- Create: `lead_gen_agents/frontend/package.json`
- Create: `lead_gen_agents/frontend/tsconfig.json`
- Create: `lead_gen_agents/frontend/vite.config.ts`
- Create: `lead_gen_agents/frontend/index.html`

- [ ] **Step 1: Create package.json**

```json
{
  "name": "lead-gen-dashboard",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "@tanstack/react-table": "^8.11.0",
    "axios": "^1.6.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "@vitejs/plugin-react": "^4.2.0",
    "typescript": "^5.3.0",
    "vite": "^5.0.0"
  }
}
```

- [ ] **Step 2: Create tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
```

- [ ] **Step 3: Create tsconfig.node.json**

```json
{
  "compilerOptions": {
    "composite": true,
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true
  },
  "include": ["vite.config.ts"]
}
```

- [ ] **Step 4: Create vite.config.ts**

```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true
      },
      '/ws': {
        target: 'ws://localhost:8000',
        ws: true
      }
    }
  }
})
```

- [ ] **Step 5: Create index.html**

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Lead Generation Dashboard</title>
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
    </style>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

- [ ] **Step 6: Commit**

```bash
git add lead_gen_agents/frontend/
git commit -m "chore: add frontend package configuration"
```

---

### Task 21: Create TypeScript Types

**Files:**
- Create: `lead_gen_agents/frontend/src/types/index.ts`

- [ ] **Step 1: Write types**

```typescript
// lead_gen_agents/frontend/src/types/index.ts

export type ScraperMode = 'beautifulsoup' | 'playwright' | 'hybrid';

export interface SearchRequest {
  query: string;
  filters?: Record<string, string>;
  seed_urls?: string[];
  scraper_mode?: ScraperMode;
}

export interface SearchResponse {
  job_id: string;
  status: string;
  message: string;
}

export interface Lead {
  name: string;
  email: string;
  company: string;
  title: string;
  source_url: string;
}

export interface JobStatus {
  job_id: string;
  status: 'pending' | 'discovering' | 'scraping' | 'exporting' | 'completed' | 'failed';
  progress: number;
  leads_found: number;
  current_stage: string;
  error?: string;
}

export interface LeadsResponse {
  job_id: string;
  leads: Lead[];
  total: number;
}

export interface WebSocketMessage {
  type: 'status' | 'error' | 'leads';
  status?: string;
  progress?: number;
  leads_found?: number;
  error?: string;
  leads?: Lead[];
}
```

- [ ] **Step 2: Commit**

```bash
git add lead_gen_agents/frontend/src/types/index.ts
git commit -m "feat: add TypeScript types for frontend"
```

---

### Task 22: Create API Client

**Files:**
- Create: `lead_gen_agents/frontend/src/api/client.ts`

- [ ] **Step 1: Write API client**

```typescript
// lead_gen_agents/frontend/src/api/client.ts
import axios from 'axios';
import type { SearchRequest, SearchResponse, JobStatus, LeadsResponse } from '../types';

const API_BASE = '/api';

export const api = {
  async search(request: SearchRequest): Promise<SearchResponse> {
    const response = await axios.post<SearchResponse>(`${API_BASE}/search`, request);
    return response.data;
  },

  async getStatus(jobId: string): Promise<JobStatus> {
    const response = await axios.get<JobStatus>(`${API_BASE}/status/${jobId}`);
    return response.data;
  },

  async getLeads(jobId: string): Promise<LeadsResponse> {
    const response = await axios.get<LeadsResponse>(`${API_BASE}/leads/${jobId}`);
    return response.data;
  },

  getExportUrl(jobId: string, format: 'csv' | 'json' = 'csv'): string {
    return `${API_BASE}/export/${jobId}?format=${format}`;
  }
};
```

- [ ] **Step 2: Commit**

```bash
git add lead_gen_agents/frontend/src/api/client.ts
git commit -m "feat: add API client for frontend"
```

---

### Task 23: Create WebSocket Hook

**Files:**
- Create: `lead_gen_agents/frontend/src/hooks/useWebSocket.ts`

- [ ] **Step 1: Write WebSocket hook**

```typescript
// lead_gen_agents/frontend/src/hooks/useWebSocket.ts
import { useEffect, useState, useCallback, useRef } from 'react';
import type { WebSocketMessage, JobStatus } from '../types';

export function useWebSocket(jobId: string | null) {
  const [status, setStatus] = useState<JobStatus | null>(null);
  const [connected, setConnected] = useState(false);
  const wsRef = useRef<WebSocket | null>(null);

  const connect = useCallback(() => {
    if (!jobId) return;

    const ws = new WebSocket(`ws://localhost:8000/ws/status/${jobId}`);
    
    ws.onopen = () => {
      setConnected(true);
    };
    
    ws.onmessage = (event) => {
      const message: WebSocketMessage = JSON.parse(event.data);
      
      if (message.type === 'status' && message.status) {
        setStatus({
          job_id: jobId,
          status: message.status as JobStatus['status'],
          progress: message.progress || 0,
          leads_found: message.leads_found || 0,
          current_stage: message.status,
          error: message.error
        });
      }
    };
    
    ws.onclose = () => {
      setConnected(false);
      // Reconnect after 3 seconds
      setTimeout(connect, 3000);
    };
    
    ws.onerror = () => {
      ws.close();
    };
    
    wsRef.current = ws;
  }, [jobId]);

  useEffect(() => {
    connect();
    
    return () => {
      if (wsRef.current) {
        wsRef.current.close();
      }
    };
  }, [connect]);

  const requestStatus = useCallback(() => {
    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
      wsRef.current.send('status');
    }
  }, []);

  return { status, connected, requestStatus };
}
```

- [ ] **Step 2: Commit**

```bash
git add lead_gen_agents/frontend/src/hooks/useWebSocket.ts
git commit -m "feat: add WebSocket hook for real-time updates"
```

---

### Task 24: Create React Components

**Files:**
- Create: `lead_gen_agents/frontend/src/components/SearchForm.tsx`
- Create: `lead_gen_agents/frontend/src/components/LeadsTable.tsx`
- Create: `lead_gen_agents/frontend/src/components/ProgressIndicator.tsx`
- Create: `lead_gen_agents/frontend/src/components/ExportButton.tsx`

- [ ] **Step 1: Create SearchForm component**

```typescript
// lead_gen_agents/frontend/src/components/SearchForm.tsx
import React, { useState } from 'react';
import type { SearchRequest, ScraperMode } from '../types';

interface Props {
  onSubmit: (request: SearchRequest) => void;
  isLoading: boolean;
}

export function SearchForm({ onSubmit, isLoading }: Props) {
  const [query, setQuery] = useState('');
  const [seedUrls, setSeedUrls] = useState('');
  const [scraperMode, setScraperMode] = useState<ScraperMode>('hybrid');
  const [showAdvanced, setShowAdvanced] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!query.trim()) return;

    onSubmit({
      query: query.trim(),
      seed_urls: seedUrls ? seedUrls.split('\n').map(u => u.trim()).filter(Boolean) : undefined,
      scraper_mode: scraperMode
    });
  };

  return (
    <form onSubmit={handleSubmit} style={styles.form}>
      <div style={styles.mainRow}>
        <input
          type="text"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Find leads for... (e.g., 'SaaS founders in New Zealand')"
          style={styles.input}
          disabled={isLoading}
        />
        <button type="submit" style={styles.button} disabled={isLoading || !query.trim()}>
          {isLoading ? 'Searching...' : 'Search'}
        </button>
      </div>

      <button
        type="button"
        onClick={() => setShowAdvanced(!showAdvanced)}
        style={styles.advancedToggle}
      >
        {showAdvanced ? '▼' : '▶'} Advanced Options
      </button>

      {showAdvanced && (
        <div style={styles.advanced}>
          <label style={styles.label}>
            Scraper Mode:
            <select
              value={scraperMode}
              onChange={(e) => setScraperMode(e.target.value as ScraperMode)}
              style={styles.select}
            >
              <option value="hybrid">Hybrid (Recommended)</option>
              <option value="beautifulsoup">BeautifulSoup (Fast)</option>
              <option value="playwright">Playwright (JS Support)</option>
            </select>
          </label>

          <label style={styles.label}>
            Seed URLs (one per line):
            <textarea
              value={seedUrls}
              onChange={(e) => setSeedUrls(e.target.value)}
              placeholder="https://example1.com&#10;https://example2.com"
              style={styles.textarea}
              rows={3}
            />
          </label>
        </div>
      )}
    </form>
  );
}

const styles: Record<string, React.CSSProperties> = {
  form: {
    marginBottom: '24px',
  },
  mainRow: {
    display: 'flex',
    gap: '12px',
    marginBottom: '12px',
  },
  input: {
    flex: 1,
    padding: '12px 16px',
    fontSize: '16px',
    borderRadius: '8px',
    border: '1px solid #ddd',
  },
  button: {
    padding: '12px 24px',
    fontSize: '16px',
    fontWeight: 'bold',
    backgroundColor: '#0066cc',
    color: 'white',
    border: 'none',
    borderRadius: '8px',
    cursor: 'pointer',
  },
  advancedToggle: {
    background: 'none',
    border: 'none',
    color: '#666',
    cursor: 'pointer',
    fontSize: '14px',
    padding: '4px 0',
  },
  advanced: {
    marginTop: '16px',
    padding: '16px',
    backgroundColor: '#f5f5f5',
    borderRadius: '8px',
    display: 'flex',
    flexDirection: 'column',
    gap: '16px',
  },
  label: {
    display: 'flex',
    flexDirection: 'column',
    gap: '8px',
    fontSize: '14px',
    fontWeight: '500',
  },
  select: {
    padding: '8px',
    fontSize: '14px',
    borderRadius: '4px',
    border: '1px solid #ddd',
  },
  textarea: {
    padding: '8px',
    fontSize: '14px',
    borderRadius: '4px',
    border: '1px solid #ddd',
    fontFamily: 'monospace',
  },
};
```

- [ ] **Step 2: Create LeadsTable component**

```typescript
// lead_gen_agents/frontend/src/components/LeadsTable.tsx
import React from 'react';
import type { Lead } from '../types';

interface Props {
  leads: Lead[];
  isLoading: boolean;
}

export function LeadsTable({ leads, isLoading }: Props) {
  if (isLoading && leads.length === 0) {
    return <div style={styles.empty}>Searching for leads...</div>;
  }

  if (leads.length === 0) {
    return <div style={styles.empty}>No leads found yet. Start a search above.</div>;
  }

  return (
    <table style={styles.table}>
      <thead>
        <tr>
          <th style={styles.th}>Name</th>
          <th style={styles.th}>Email</th>
          <th style={styles.th}>Company</th>
          <th style={styles.th}>Title</th>
          <th style={styles.th}>Source</th>
        </tr>
      </thead>
      <tbody>
        {leads.map((lead, index) => (
          <tr key={index} style={styles.tr}>
            <td style={styles.td}>{lead.name || '-'}</td>
            <td style={styles.td}>
              <a href={`mailto:${lead.email}`} style={styles.link}>
                {lead.email}
              </a>
            </td>
            <td style={styles.td}>{lead.company || '-'}</td>
            <td style={styles.td}>{lead.title || '-'}</td>
            <td style={styles.td}>
              <a href={lead.source_url} target="_blank" rel="noopener" style={styles.link}>
                {lead.source_url}
              </a>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

const styles: Record<string, React.CSSProperties> = {
  table: {
    width: '100%',
    borderCollapse: 'collapse',
    backgroundColor: 'white',
    borderRadius: '8px',
    overflow: 'hidden',
    boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
  },
  th: {
    padding: '12px 16px',
    textAlign: 'left',
    backgroundColor: '#f5f5f5',
    fontWeight: '600',
    borderBottom: '2px solid #ddd',
  },
  td: {
    padding: '12px 16px',
    borderBottom: '1px solid #eee',
  },
  tr: {
    cursor: 'pointer',
  },
  link: {
    color: '#0066cc',
    textDecoration: 'none',
  },
  empty: {
    padding: '48px',
    textAlign: 'center',
    color: '#666',
    backgroundColor: 'white',
    borderRadius: '8px',
  },
};
```

- [ ] **Step 3: Create ProgressIndicator component**

```typescript
// lead_gen_agents/frontend/src/components/ProgressIndicator.tsx
import React from 'react';
import type { JobStatus } from '../types';

interface Props {
  status: JobStatus | null;
  connected: boolean;
}

export function ProgressIndicator({ status, connected }: Props) {
  if (!status) return null;

  const getStatusColor = () => {
    switch (status.status) {
      case 'completed': return '#22c55e';
      case 'failed': return '#ef4444';
      case 'scraping': return '#3b82f6';
      case 'discovering': return '#f59e0b';
      default: return '#6b7280';
    }
  };

  const getStatusText = () => {
    switch (status.status) {
      case 'pending': return 'Starting...';
      case 'discovering': return 'Discovering URLs...';
      case 'scraping': return 'Scraping leads...';
      case 'exporting': return 'Exporting...';
      case 'completed': return 'Complete!';
      case 'failed': return `Failed: ${status.error}`;
      default: return status.status;
    }
  };

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <span style={{ ...styles.status, color: getStatusColor() }}>
          {getStatusText()}
        </span>
        <span style={styles.connected}>
          {connected ? '🟢 Connected' : '🔴 Disconnected'}
        </span>
      </div>
      
      <div style={styles.progressBar}>
        <div
          style={{
            ...styles.progressFill,
            width: `${status.progress * 100}%`,
            backgroundColor: getStatusColor(),
          }}
        />
      </div>
      
      <div style={styles.stats}>
        <span>Progress: {Math.round(status.progress * 100)}%</span>
        <span>Leads found: {status.leads_found}</span>
      </div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    marginBottom: '24px',
    padding: '16px',
    backgroundColor: 'white',
    borderRadius: '8px',
    boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    marginBottom: '12px',
  },
  status: {
    fontWeight: '600',
    fontSize: '16px',
  },
  connected: {
    fontSize: '12px',
    color: '#666',
  },
  progressBar: {
    height: '8px',
    backgroundColor: '#e5e7eb',
    borderRadius: '4px',
    overflow: 'hidden',
    marginBottom: '12px',
  },
  progressFill: {
    height: '100%',
    transition: 'width 0.3s ease',
  },
  stats: {
    display: 'flex',
    justifyContent: 'space-between',
    fontSize: '14px',
    color: '#666',
  },
};
```

- [ ] **Step 4: Create ExportButton component**

```typescript
// lead_gen_agents/frontend/src/components/ExportButton.tsx
import React from 'react';
import { api } from '../api/client';

interface Props {
  jobId: string | null;
  disabled: boolean;
}

export function ExportButton({ jobId, disabled }: Props) {
  const handleExport = (format: 'csv' | 'json') => {
    if (!jobId) return;
    window.open(api.getExportUrl(jobId, format), '_blank');
  };

  return (
    <div style={styles.container}>
      <button
        onClick={() => handleExport('csv')}
        disabled={disabled}
        style={styles.button}
      >
        📥 Export CSV
      </button>
      <button
        onClick={() => handleExport('json')}
        disabled={disabled}
        style={styles.button}
      >
        📥 Export JSON
      </button>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    display: 'flex',
    gap: '12px',
    marginBottom: '24px',
  },
  button: {
    padding: '10px 20px',
    fontSize: '14px',
    fontWeight: '500',
    backgroundColor: '#22c55e',
    color: 'white',
    border: 'none',
    borderRadius: '6px',
    cursor: 'pointer',
    opacity: 1,
  },
};
```

- [ ] **Step 5: Commit**

```bash
git add lead_gen_agents/frontend/src/components/
git commit -m "feat: add React components for dashboard UI"
```

---

### Task 25: Create App and Entry Point

**Files:**
- Create: `lead_gen_agents/frontend/src/App.tsx`
- Create: `lead_gen_agents/frontend/src/main.tsx`

- [ ] **Step 1: Create App.tsx**

```typescript
// lead_gen_agents/frontend/src/App.tsx
import React, { useState, useCallback } from 'react';
import { SearchForm } from './components/SearchForm';
import { LeadsTable } from './components/LeadsTable';
import { ProgressIndicator } from './components/ProgressIndicator';
import { ExportButton } from './components/ExportButton';
import { useWebSocket } from './hooks/useWebSocket';
import { api } from './api/client';
import type { SearchRequest, Lead, JobStatus } from './types';

export function App() {
  const [jobId, setJobId] = useState<string | null>(null);
  const [leads, setLeads] = useState<Lead[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [manualStatus, setManualStatus] = useState<JobStatus | null>(null);
  
  const { status: wsStatus, connected } = useWebSocket(jobId);
  
  // Use WebSocket status if available, otherwise manual status
  const status = wsStatus || manualStatus;

  const handleSearch = useCallback(async (request: SearchRequest) => {
    setIsLoading(true);
    setLeads([]);
    
    try {
      const response = await api.search(request);
      setJobId(response.job_id);
      setManualStatus({
        job_id: response.job_id,
        status: 'pending',
        progress: 0,
        leads_found: 0,
        current_stage: 'init'
      });
      
      // Poll for leads periodically
      const pollInterval = setInterval(async () => {
        try {
          const leadsResponse = await api.getLeads(response.job_id);
          setLeads(leadsResponse.leads);
          
          // Also get status
          const statusResponse = await api.getStatus(response.job_id);
          setManualStatus(statusResponse);
          
          if (statusResponse.status === 'completed' || statusResponse.status === 'failed') {
            clearInterval(pollInterval);
            setIsLoading(false);
          }
        } catch (error) {
          console.error('Polling error:', error);
        }
      }, 2000);
      
    } catch (error) {
      console.error('Search error:', error);
      setIsLoading(false);
    }
  }, []);

  // Update leads when status changes
  React.useEffect(() => {
    if (jobId && status?.status === 'completed') {
      api.getLeads(jobId).then(response => {
        setLeads(response.leads);
        setIsLoading(false);
      });
    }
  }, [jobId, status?.status]);

  return (
    <div style={styles.container}>
      <header style={styles.header}>
        <h1 style={styles.title}>Lead Generation Dashboard</h1>
        <p style={styles.subtitle}>Find leads for any purpose</p>
      </header>

      <main style={styles.main}>
        <SearchForm onSubmit={handleSearch} isLoading={isLoading} />
        
        {jobId && (
          <>
            <ProgressIndicator status={status} connected={connected} />
            <ExportButton jobId={jobId} disabled={status?.status !== 'completed'} />
          </>
        )}
        
        <LeadsTable leads={leads} isLoading={isLoading} />
      </main>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    minHeight: '100vh',
    backgroundColor: '#f0f2f5',
  },
  header: {
    backgroundColor: '#1a1a2e',
    color: 'white',
    padding: '24px',
    textAlign: 'center',
  },
  title: {
    fontSize: '28px',
    fontWeight: 'bold',
    marginBottom: '8px',
  },
  subtitle: {
    fontSize: '16px',
    opacity: 0.8,
  },
  main: {
    maxWidth: '1200px',
    margin: '0 auto',
    padding: '24px',
  },
};
```

- [ ] **Step 2: Create main.tsx**

```typescript
// lead_gen_agents/frontend/src/main.tsx
import React from 'react';
import ReactDOM from 'react-dom/client';
import { App } from './App';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

- [ ] **Step 3: Commit**

```bash
git add lead_gen_agents/frontend/src/App.tsx lead_gen_agents/frontend/src/main.tsx
git commit -m "feat: add React App and entry point"
```

---

## Phase 8: Integration

### Task 26: Create README

**Files:**
- Create: `lead_gen_agents/README.md`

- [ ] **Step 1: Write README**

```markdown
# Lead Generation Dashboard

A FastAPI + React web dashboard for lead generation using LangGraph multi-agent architecture.

## Features

- **Natural language queries**: Type "find SaaS founders in New Zealand" and get leads
- **Real-time progress**: WebSocket updates as leads are discovered
- **Configurable scraping**: Choose BeautifulSoup (fast) or Playwright (JS support)
- **Export options**: Download leads as CSV or JSON

## Quick Start

### Prerequisites

- Python 3.10+
- Node.js 18+
- Google Custom Search API key (optional, for web search)

### Backend Setup

```bash
cd lead_gen_agents

# Create virtual environment
python -m venv venv
source venv/bin/activate  # or `venv\Scripts\activate` on Windows

# Install dependencies
pip install -r requirements.txt

# Install Playwright browsers (for JS rendering)
playwright install chromium

# Set environment variables
export GOOGLE_API_KEY="your-api-key"
export GOOGLE_CX="your-custom-search-id"

# Run server
python -m backend.main
```

### Frontend Setup

```bash
cd lead_gen_agents/frontend

# Install dependencies
npm install

# Run dev server
npm run dev
```

### Access

- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- API Docs: http://localhost:8000/docs

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/search` | POST | Start lead generation job |
| `/api/status/{job_id}` | GET | Get job status |
| `/api/leads/{job_id}` | GET | Get leads for a job |
| `/api/export/{job_id}` | GET | Download leads file |
| `/ws/status/{job_id}` | WebSocket | Real-time status updates |

## Configuration

Environment variables (set in `.env` file):

| Variable | Description | Default |
|----------|-------------|---------|
| `GOOGLE_API_KEY` | Google API key | "" |
| `GOOGLE_CX` | Custom Search Engine ID | "" |
| `SCRAPER_MODE` | Scraper mode | "hybrid" |
| `SCRAPING_TIMEOUT` | Request timeout (seconds) | 30 |
| `MAX_DISCOVERY_RESULTS` | Max URLs to discover | 10 |
| `EXPORT_DIR` | Export directory | "exports" |

## Testing

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=backend tests/
```

## License

MIT
```

- [ ] **Step 2: Commit**

```bash
git add lead_gen_agents/README.md
git commit -m "docs: add README with setup instructions"
```

---

### Task 27: Final Integration Test

**Files:**
- Create: `lead_gen_agents/tests/test_integration.py`

- [ ] **Step 1: Write integration test**

```python
# lead_gen_agents/tests/test_integration.py
"""
Integration tests for the full pipeline.
Run with: pytest tests/test_integration.py -v --run-e2e
"""
import pytest
import asyncio
import os

# Mark tests that require real API calls
pytestmark = pytest.mark.skipif(
    not os.environ.get("RUN_E2E"),
    reason="Set RUN_E2E=1 to run end-to-end tests"
)

@pytest.mark.asyncio
async def test_full_pipeline_with_seed_urls():
    """Test full pipeline with provided seed URLs (no API key needed)."""
    from backend.agents.orchestrator.graph import run_lead_generation
    from backend.agents.state import create_initial_state
    
    state = create_initial_state(
        job_id="integration-test",
        query="test",
        seed_urls=["https://example.com"],
        scraper_mode="beautifulsoup"
    )
    
    result = await run_lead_generation(state)
    
    assert result["job_id"] == "integration-test"
    assert result["current_stage"] == "complete"
    assert result["export_path"] is not None

@pytest.mark.asyncio
async def test_api_search_endpoint():
    """Test the search API endpoint."""
    from fastapi.testclient import TestClient
    from backend.api.main import app
    
    client = TestClient(app)
    
    response = client.post("/api/search", json={
        "query": "test query",
        "seed_urls": ["https://example.com"],
        "scraper_mode": "beautifulsoup"
    })
    
    assert response.status_code == 200
    data = response.json()
    assert "job_id" in data
    assert data["status"] == "pending"
```

- [ ] **Step 2: Run integration test**

Run: `cd lead_gen_agents && RUN_E2E=1 python -m pytest tests/test_integration.py -v`
Expected: Tests pass (may take a few seconds)

- [ ] **Step 3: Commit**

```bash
git add lead_gen_agents/tests/test_integration.py
git commit -m "test: add integration tests for full pipeline"
```

---

## Summary

This plan covers:

- **Phase 1**: Project setup (directory structure, dependencies, config)
- **Phase 2**: API models and LangGraph state schema
- **Phase 3**: Tools (Google Search, Web Fetcher, Storage)
- **Phase 4**: Agents (Discovery, Scraper, Export, Orchestrator)
- **Phase 5**: Job Manager and WebSocket handler
- **Phase 6**: API routes (search, status, leads, export)
- **Phase 7**: React frontend (components, hooks, types)
- **Phase 8**: Integration and documentation

Total: **27 tasks** with bite-sized steps.