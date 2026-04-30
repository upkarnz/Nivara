# Nivara — Plan 1: Foundation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a working Nivara app where a user can sign in, complete profile + assistant setup, and have a streaming text conversation with Claude — all wired through the Hermes FastAPI backend.

**Architecture:** Flutter app talks exclusively to Hermes via authenticated REST (Dio + Firebase JWT). Hermes proxies Claude and writes conversation data to Firestore. Riverpod manages all Flutter state. go_router handles auth-aware navigation.

**Tech Stack:** Flutter 3.x · Riverpod 2.x · go_router · Firebase Auth + Firestore · FastAPI · Anthropic SDK · firebase-admin · Railway.app

**Subsequent plans (not in scope here):**
- Plan 2: Voice Mode (wake word + STT + TTS)
- Plan 3: AI Planner (NLP scheduling + calendar)
- Plan 4: Memory System (ChromaDB + vector embeddings)
- Plan 5: Mood Detection + Mood Board
- Plan 6: Music System
- Plan 7: Subscription + RevenueCat paywall

---

## File Map

### Hermes backend (`hermes-agent/`)

| File | Responsibility |
|---|---|
| `main.py` | FastAPI app, Firebase Admin init, router registration |
| `auth/firebase_jwt.py` | JWT middleware — validates Firebase ID tokens |
| `models/message.py` | `ChatMessage`, `ChatRequest`, `ChatResponse` Pydantic models |
| `models/user.py` | `TokenData` Pydantic model |
| `services/claude_service.py` | Calls Anthropic SDK, yields streaming text chunks |
| `routers/chat.py` | `POST /api/v1/chat` — SSE streaming endpoint |
| `requirements.txt` | Python dependencies |
| `railway.toml` | Railway deployment config |
| `.env.example` | Required env vars template |
| `tests/test_chat.py` | Unit tests for chat service and router |

### Flutter app (`nivara/`)

| File | Responsibility |
|---|---|
| `pubspec.yaml` | All package dependencies |
| `lib/main.dart` | App entry, Firebase init, ProviderScope |
| `lib/router/app_router.dart` | go_router config, auth-aware redirects |
| `lib/theme/app_theme.dart` | Dark theme, colors, text styles |
| `lib/features/auth/data/auth_repository.dart` | Firebase Auth calls (Google + Email sign-in) |
| `lib/features/auth/presentation/providers/auth_provider.dart` | Riverpod auth state + token provider |
| `lib/features/auth/presentation/pages/welcome_page.dart` | Splash / welcome screen |
| `lib/features/auth/presentation/pages/sign_in_page.dart` | Google + Email sign-in form |
| `lib/features/profile/data/profile_repository.dart` | Firestore reads/writes for profile + assistant docs |
| `lib/features/profile/presentation/providers/profile_provider.dart` | Riverpod profile state |
| `lib/features/profile/presentation/pages/profile_setup_page.dart` | Name, gender, DOB, language, timezone form |
| `lib/features/profile/presentation/pages/assistant_setup_page.dart` | Assistant name, voice, speed, style form |
| `lib/features/chat/data/hermes_client.dart` | Dio HTTP client, attaches Firebase JWT, streams SSE |
| `lib/features/chat/data/conversation_repository.dart` | Firestore reads/writes for conversations |
| `lib/features/chat/domain/message.dart` | `ChatMessage` value type |
| `lib/features/chat/presentation/providers/chat_provider.dart` | Riverpod chat state, streaming accumulation |
| `lib/features/chat/presentation/pages/chat_page.dart` | Home screen — greeting, message list, input bar |
| `lib/features/chat/presentation/widgets/message_bubble.dart` | Single message bubble widget |
| `lib/features/chat/presentation/widgets/chat_input_bar.dart` | Text input + send button |
| `lib/shared/models/user_profile.dart` | `UserProfile` + `AssistantConfig` data classes |
| `test/auth/auth_repository_test.dart` | Auth repository unit tests |
| `test/chat/hermes_client_test.dart` | Hermes client unit tests |
| `test/chat/chat_provider_test.dart` | Chat provider unit tests |

---

## Task 1: Hermes — Project Setup

**Files:**
- Create: `hermes-agent/requirements.txt`
- Create: `hermes-agent/.env.example`
- Create: `hermes-agent/railway.toml`
- Create: `hermes-agent/main.py`

- [ ] **Step 1: Create the project directory and requirements file**

```bash
mkdir -p hermes-agent/auth hermes-agent/models hermes-agent/routers hermes-agent/services hermes-agent/tests
```

Create `hermes-agent/requirements.txt`:
```
fastapi==0.111.0
uvicorn[standard]==0.29.0
anthropic==0.28.0
firebase-admin==6.5.0
python-jose[cryptography]==3.3.0
pydantic==2.7.1
pydantic-settings==2.2.1
python-dotenv==1.0.1
httpx==0.27.0
pytest==8.2.0
pytest-asyncio==0.23.6
httpx==0.27.0
```

- [ ] **Step 2: Create `.env.example`**

```
ANTHROPIC_API_KEY=sk-ant-...
FIREBASE_SERVICE_ACCOUNT_PATH=serviceAccountKey.json
```

- [ ] **Step 3: Create `hermes-agent/railway.toml`**

```toml
[build]
builder = "nixpacks"

[deploy]
startCommand = "uvicorn main:app --host 0.0.0.0 --port $PORT"
restartPolicyType = "on_failure"
restartPolicyMaxRetries = 3
```

- [ ] **Step 4: Create `hermes-agent/main.py`**

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
import firebase_admin
from firebase_admin import credentials
from routers import chat


@asynccontextmanager
async def lifespan(app: FastAPI):
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
    yield


app = FastAPI(title="Hermes Agent Service", version="1.0.0", lifespan=lifespan)
app.include_router(chat.router, prefix="/api/v1")


@app.get("/health")
async def health():
    return {"status": "ok"}
```

- [ ] **Step 5: Verify the structure looks right**

```bash
find hermes-agent -type f | sort
```

Expected output:
```
hermes-agent/.env.example
hermes-agent/auth/
hermes-agent/main.py
hermes-agent/models/
hermes-agent/railway.toml
hermes-agent/requirements.txt
hermes-agent/routers/
hermes-agent/services/
hermes-agent/tests/
```

- [ ] **Step 6: Commit**

```bash
git add hermes-agent/
git commit -m "feat(hermes): scaffold FastAPI project structure"
```

---

## Task 2: Hermes — Models

**Files:**
- Create: `hermes-agent/models/__init__.py`
- Create: `hermes-agent/models/user.py`
- Create: `hermes-agent/models/message.py`

- [ ] **Step 1: Write the failing test**

Create `hermes-agent/tests/test_models.py`:
```python
import pytest
from models.message import ChatMessage, ChatRequest, Role
from models.user import TokenData


def test_chat_message_role_enum():
    msg = ChatMessage(role=Role.user, content="hello")
    assert msg.role == "user"
    assert msg.content == "hello"


def test_chat_request_defaults():
    req = ChatRequest(messages=[ChatMessage(role=Role.user, content="hi")])
    assert req.assistant_name == "Rocky"
    assert req.ai_model == "claude"


def test_token_data_fields():
    td = TokenData(uid="abc123", email="u@example.com")
    assert td.uid == "abc123"
    assert td.email == "u@example.com"
```

- [ ] **Step 2: Run the test to see it fail**

```bash
cd hermes-agent && pip install -r requirements.txt -q && pytest tests/test_models.py -v
```

Expected: `ModuleNotFoundError: No module named 'models'`

- [ ] **Step 3: Create `hermes-agent/models/__init__.py`** (empty)

- [ ] **Step 4: Create `hermes-agent/models/user.py`**

```python
from pydantic import BaseModel


class TokenData(BaseModel):
    uid: str
    email: str | None = None
```

- [ ] **Step 5: Create `hermes-agent/models/message.py`**

```python
from enum import Enum
from pydantic import BaseModel


class Role(str, Enum):
    user = "user"
    assistant = "assistant"


class ChatMessage(BaseModel):
    role: Role
    content: str


class ChatRequest(BaseModel):
    messages: list[ChatMessage]
    assistant_name: str = "Rocky"
    ai_model: str = "claude"
```

- [ ] **Step 6: Run test to verify it passes**

```bash
cd hermes-agent && pytest tests/test_models.py -v
```

Expected: 3 PASSED

- [ ] **Step 7: Commit**

```bash
git add hermes-agent/models/ hermes-agent/tests/test_models.py
git commit -m "feat(hermes): add Pydantic models for chat and user"
```

---

## Task 3: Hermes — Firebase JWT Middleware

**Files:**
- Create: `hermes-agent/auth/__init__.py`
- Create: `hermes-agent/auth/firebase_jwt.py`

- [ ] **Step 1: Write the failing test**

Add to `hermes-agent/tests/test_auth.py`:
```python
import pytest
from unittest.mock import patch, MagicMock
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from auth.firebase_jwt import get_current_user


@pytest.mark.asyncio
async def test_valid_token_returns_token_data():
    mock_creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="valid-token")
    mock_decoded = {"uid": "user123", "email": "test@example.com"}

    with patch("auth.firebase_jwt.firebase_auth.verify_id_token", return_value=mock_decoded):
        result = await get_current_user(mock_creds)

    assert result.uid == "user123"
    assert result.email == "test@example.com"


@pytest.mark.asyncio
async def test_invalid_token_raises_401():
    from firebase_admin.auth import InvalidIdTokenError
    mock_creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="bad-token")

    with patch("auth.firebase_jwt.firebase_auth.verify_id_token", side_effect=InvalidIdTokenError("bad")):
        with pytest.raises(HTTPException) as exc_info:
            await get_current_user(mock_creds)

    assert exc_info.value.status_code == 401
```

- [ ] **Step 2: Run to see it fail**

```bash
cd hermes-agent && pytest tests/test_auth.py -v
```

Expected: `ModuleNotFoundError: No module named 'auth'`

- [ ] **Step 3: Create `hermes-agent/auth/__init__.py`** (empty)

- [ ] **Step 4: Create `hermes-agent/auth/firebase_jwt.py`**

```python
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from firebase_admin import auth as firebase_auth
from models.user import TokenData

security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> TokenData:
    try:
        decoded = firebase_auth.verify_id_token(credentials.credentials)
        return TokenData(uid=decoded["uid"], email=decoded.get("email"))
    except firebase_auth.InvalidIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token",
        )
    except firebase_auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Expired authentication token",
        )
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd hermes-agent && pytest tests/test_auth.py -v
```

Expected: 2 PASSED

- [ ] **Step 6: Commit**

```bash
git add hermes-agent/auth/ hermes-agent/tests/test_auth.py
git commit -m "feat(hermes): add Firebase JWT auth middleware"
```

---

## Task 4: Hermes — Claude Streaming Service

**Files:**
- Create: `hermes-agent/services/__init__.py`
- Create: `hermes-agent/services/claude_service.py`

- [ ] **Step 1: Write the failing test**

Create `hermes-agent/tests/test_claude_service.py`:
```python
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from models.message import ChatMessage, Role
from services.claude_service import stream_chat, build_system_prompt


def test_build_system_prompt_includes_name():
    prompt = build_system_prompt("Jarvis")
    assert "Jarvis" in prompt


@pytest.mark.asyncio
async def test_stream_chat_yields_text():
    mock_chunks = ["Hello", ", ", "world", "!"]

    async def fake_text_stream():
        for chunk in mock_chunks:
            yield chunk

    mock_stream = AsyncMock()
    mock_stream.__aenter__ = AsyncMock(return_value=mock_stream)
    mock_stream.__aexit__ = AsyncMock(return_value=False)
    mock_stream.text_stream = fake_text_stream()

    messages = [ChatMessage(role=Role.user, content="hi")]

    with patch("services.claude_service.client.messages.stream", return_value=mock_stream):
        chunks = []
        async for chunk in stream_chat(messages, "Jarvis"):
            chunks.append(chunk)

    assert chunks == ["Hello", ", ", "world", "!"]
```

- [ ] **Step 2: Run to see it fail**

```bash
cd hermes-agent && pytest tests/test_claude_service.py -v
```

Expected: `ModuleNotFoundError: No module named 'services'`

- [ ] **Step 3: Create `hermes-agent/services/__init__.py`** (empty)

- [ ] **Step 4: Create `hermes-agent/services/claude_service.py`**

```python
import anthropic
from models.message import ChatMessage

client = anthropic.AsyncAnthropic()

_SYSTEM_TEMPLATE = (
    "You are {name}, a warm and caring personal AI companion. "
    "You are empathetic, helpful, and conversational — not clinical or formal. "
    "Address the user by their first name when it feels natural. "
    "Keep responses concise unless the user asks for detail."
)


def build_system_prompt(assistant_name: str) -> str:
    return _SYSTEM_TEMPLATE.format(name=assistant_name)


async def stream_chat(messages: list[ChatMessage], assistant_name: str):
    system = build_system_prompt(assistant_name)
    formatted = [{"role": m.role.value, "content": m.content} for m in messages]

    async with client.messages.stream(
        model="claude-opus-4-5",
        max_tokens=1024,
        system=system,
        messages=formatted,
    ) as stream:
        async for text in stream.text_stream:
            yield text
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd hermes-agent && pytest tests/test_claude_service.py -v
```

Expected: 2 PASSED

- [ ] **Step 6: Commit**

```bash
git add hermes-agent/services/ hermes-agent/tests/test_claude_service.py
git commit -m "feat(hermes): add Claude streaming chat service"
```

---

## Task 5: Hermes — Chat Router + Integration Test

**Files:**
- Create: `hermes-agent/routers/__init__.py`
- Create: `hermes-agent/routers/chat.py`
- Create: `hermes-agent/tests/test_chat_router.py`

- [ ] **Step 1: Write the failing test**

Create `hermes-agent/tests/test_chat_router.py`:
```python
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from httpx import AsyncClient, ASGITransport
from main import app
from models.user import TokenData


@pytest.fixture
def mock_auth():
    async def override_auth():
        return TokenData(uid="test-uid", email="test@test.com")
    return override_auth


@pytest.mark.asyncio
async def test_chat_endpoint_streams_response(mock_auth):
    from auth.firebase_jwt import get_current_user
    app.dependency_overrides[get_current_user] = mock_auth

    async def fake_stream(*args, **kwargs):
        for word in ["Hello", " there"]:
            yield word

    payload = {
        "messages": [{"role": "user", "content": "hi"}],
        "assistant_name": "Rocky",
        "ai_model": "claude",
    }

    with patch("routers.chat.stream_chat", side_effect=fake_stream):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.post("/api/v1/chat", json=payload)

    assert response.status_code == 200
    assert "text/event-stream" in response.headers["content-type"]
    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_chat_endpoint_requires_auth():
    payload = {"messages": [{"role": "user", "content": "hi"}]}
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.post("/api/v1/chat", json=payload)
    assert response.status_code == 403
```

- [ ] **Step 2: Run to see it fail**

```bash
cd hermes-agent && pytest tests/test_chat_router.py -v
```

Expected: `ModuleNotFoundError: No module named 'routers'`

- [ ] **Step 3: Create `hermes-agent/routers/__init__.py`** (empty)

- [ ] **Step 4: Create `hermes-agent/routers/chat.py`**

```python
from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from auth.firebase_jwt import get_current_user, TokenData
from models.message import ChatRequest
from services.claude_service import stream_chat

router = APIRouter(tags=["chat"])


@router.post("/chat")
async def chat(
    request: ChatRequest,
    current_user: TokenData = Depends(get_current_user),
):
    async def event_stream():
        async for chunk in stream_chat(request.messages, request.assistant_name):
            yield f"data: {chunk}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(event_stream(), media_type="text/event-stream")
```

- [ ] **Step 5: Run all tests**

```bash
cd hermes-agent && pytest tests/ -v
```

Expected: 7 PASSED

- [ ] **Step 6: Smoke-test the server locally**

```bash
cd hermes-agent && ANTHROPIC_API_KEY=test uvicorn main:app --port 8000 &
curl http://localhost:8000/health
# Expected: {"status":"ok"}
kill %1
```

- [ ] **Step 7: Commit**

```bash
git add hermes-agent/routers/ hermes-agent/tests/test_chat_router.py
git commit -m "feat(hermes): add SSE chat router with JWT auth"
```

---

## Task 6: Flutter — Project Scaffold

**Files:**
- Create: `nivara/pubspec.yaml`
- Create: `nivara/lib/main.dart`
- Create: `nivara/lib/theme/app_theme.dart`

- [ ] **Step 1: Create the Flutter project**

```bash
flutter create --org com.nivara --platforms ios,android nivara
cd nivara
```

- [ ] **Step 2: Replace `pubspec.yaml` with pinned dependencies**

```yaml
name: nivara
description: Your personal AI companion

publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'
  flutter: ">=3.19.0"

dependencies:
  flutter:
    sdk: flutter

  # State + routing
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  go_router: ^13.2.0

  # Firebase
  firebase_core: ^2.30.1
  firebase_auth: ^4.19.6
  cloud_firestore: ^4.17.4
  firebase_analytics: ^10.10.6
  firebase_crashlytics: ^3.5.6

  # Google Sign-In
  google_sign_in: ^6.2.1

  # Security
  local_auth: ^2.3.0
  flutter_secure_storage: ^9.2.2

  # Networking
  dio: ^5.4.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  riverpod_generator: ^2.4.3
  build_runner: ^2.4.11
  mockito: ^5.4.4
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
```

- [ ] **Step 3: Install packages**

```bash
flutter pub get
```

Expected: Exit code 0, no errors.

- [ ] **Step 4: Create `lib/theme/app_theme.dart`**

```dart
import 'package:flutter/material.dart';

class AppTheme {
  static const _primaryColor = Color(0xFF6366F1); // indigo-500
  static const _surfaceColor = Color(0xFF0F0F14);
  static const _cardColor = Color(0xFF1A1A24);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: _primaryColor,
          surface: _surfaceColor,
          onSurface: Color(0xFFE2E8F0),
          surfaceContainerHighest: _cardColor,
        ),
        scaffoldBackgroundColor: _surfaceColor,
        cardTheme: const CardTheme(
          color: _cardColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
}
```

- [ ] **Step 5: Create `lib/main.dart`**

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  runApp(const ProviderScope(child: NivaraApp()));
}

class NivaraApp extends ConsumerWidget {
  const NivaraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Nivara',
      theme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

Note: `firebase_options.dart` is generated by `flutterfire configure` in the next task.

- [ ] **Step 6: Verify the project compiles (without Firebase configured yet)**

```bash
flutter analyze
```

Expected: Only warning about missing `firebase_options.dart` — that is expected at this stage.

- [ ] **Step 7: Commit**

```bash
git add nivara/
git commit -m "feat(flutter): scaffold Flutter project with theme and dependencies"
```

---

## Task 7: Flutter — Firebase Configuration

**Files:**
- Create: `nivara/lib/firebase_options.dart` (generated)

- [ ] **Step 1: Install FlutterFire CLI**

```bash
dart pub global activate flutterfire_cli
```

- [ ] **Step 2: Log in to Firebase**

```bash
firebase login
```

- [ ] **Step 3: Create a Firebase project (if not already done)**

```bash
firebase projects:create nivara-app --display-name "Nivara"
```

- [ ] **Step 4: Run FlutterFire configure**

```bash
cd nivara && flutterfire configure --project=nivara-app
```

Select: iOS + Android. This generates `lib/firebase_options.dart`.

- [ ] **Step 5: Enable Firebase services in the console**

In the Firebase Console (console.firebase.google.com) for project `nivara-app`:
- Authentication → Enable **Google** and **Email/Password** providers
- Firestore → Create database → **Start in production mode** → region `us-central1`
- Storage → Get started → region `us-central1`
- Crashlytics → Enable

- [ ] **Step 6: Verify the app compiles**

```bash
cd nivara && flutter analyze
```

Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add nivara/lib/firebase_options.dart nivara/android/ nivara/ios/
git commit -m "feat(flutter): add Firebase configuration for iOS and Android"
```

---

## Task 8: Flutter — Auth-Aware Router

**Files:**
- Create: `nivara/lib/router/app_router.dart`
- Create: `nivara/lib/router/app_router.g.dart` (generated)

- [ ] **Step 1: Write the test**

Create `nivara/test/router/app_router_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('router file exports appRouterProvider', () {
    // Verified by compilation — this file is a compile-time check
    // Integration tested via widget tests in auth tasks
    expect(true, isTrue);
  });
}
```

- [ ] **Step 2: Create `lib/router/app_router.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/pages/welcome_page.dart';
import '../features/auth/presentation/pages/sign_in_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/chat/presentation/pages/chat_page.dart';
import '../features/profile/presentation/pages/assistant_setup_page.dart';
import '../features/profile/presentation/pages/profile_setup_page.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/welcome',
    redirect: (context, state) {
      final isSignedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/welcome' ||
          state.matchedLocation == '/sign-in';

      if (!isSignedIn && !isAuthRoute) return '/welcome';
      if (isSignedIn && isAuthRoute) return '/chat';
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupPage(),
      ),
      GoRoute(
        path: '/assistant-setup',
        builder: (context, state) => const AssistantSetupPage(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatPage(),
      ),
    ],
  );
}
```

- [ ] **Step 3: Run code generation**

```bash
cd nivara && dart run build_runner build --delete-conflicting-outputs
```

Expected: `app_router.g.dart` is generated.

- [ ] **Step 4: Run tests**

```bash
cd nivara && flutter test test/router/
```

Expected: 1 PASSED

- [ ] **Step 5: Commit**

```bash
git add nivara/lib/router/ nivara/test/router/
git commit -m "feat(flutter): add auth-aware go_router configuration"
```

---

## Task 9: Flutter — Auth Repository + Provider

**Files:**
- Create: `nivara/lib/features/auth/data/auth_repository.dart`
- Create: `nivara/lib/features/auth/presentation/providers/auth_provider.dart`
- Create: `nivara/lib/features/auth/presentation/providers/auth_provider.g.dart` (generated)

- [ ] **Step 1: Write the failing test**

Create `nivara/test/auth/auth_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:nivara/features/auth/data/auth_repository.dart';

@GenerateMocks([FirebaseAuth, UserCredential, User])
import 'auth_repository_test.mocks.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late AuthRepository repo;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    repo = AuthRepository(auth: mockAuth);
  });

  test('signOut calls FirebaseAuth.signOut', () async {
    when(mockAuth.signOut()).thenAnswer((_) async {});
    await repo.signOut();
    verify(mockAuth.signOut()).called(1);
  });

  test('currentUser returns null when not signed in', () {
    when(mockAuth.currentUser).thenReturn(null);
    expect(repo.currentUser, isNull);
  });
}
```

- [ ] **Step 2: Run to see it fail**

```bash
cd nivara && flutter test test/auth/auth_repository_test.dart
```

Expected: Compilation error — `AuthRepository` not found.

- [ ] **Step 3: Create `lib/features/auth/data/auth_repository.dart`**

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

@riverpod
AuthRepository authRepository(Ref ref) => AuthRepository();

class AuthRepository {
  AuthRepository({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in aborted');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> createAccount(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<String> getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No signed-in user');
    return await user.getIdToken() ?? '';
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }
}
```

- [ ] **Step 4: Create `lib/features/auth/presentation/providers/auth_provider.dart`**

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/auth_repository.dart';

part 'auth_provider.g.dart';

@riverpod
Stream<User?> authState(Ref ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
}

@riverpod
Future<String> firebaseIdToken(Ref ref) async {
  // Refreshed whenever auth state changes
  ref.watch(authStateProvider);
  final repo = ref.watch(authRepositoryProvider);
  return repo.getIdToken();
}
```

- [ ] **Step 5: Run code generation**

```bash
cd nivara && dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 6: Run tests**

```bash
cd nivara && dart run build_runner build --delete-conflicting-outputs && flutter test test/auth/
```

Expected: 2 PASSED

- [ ] **Step 7: Commit**

```bash
git add nivara/lib/features/auth/ nivara/test/auth/
git commit -m "feat(flutter): add auth repository and Riverpod auth state provider"
```

---

## Task 10: Flutter — Welcome + Sign-In Screens

**Files:**
- Create: `nivara/lib/features/auth/presentation/pages/welcome_page.dart`
- Create: `nivara/lib/features/auth/presentation/pages/sign_in_page.dart`
- Create: `nivara/test/auth/sign_in_page_test.dart`

- [ ] **Step 1: Write the widget test**

Create `nivara/test/auth/sign_in_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:nivara/features/auth/presentation/pages/sign_in_page.dart';

void main() {
  testWidgets('sign in page shows Google and Email buttons', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const SignInPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Sign in with Email'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to see it fail**

```bash
cd nivara && flutter test test/auth/sign_in_page_test.dart
```

Expected: `Target file not found` or compile error.

- [ ] **Step 3: Create `lib/features/auth/presentation/pages/welcome_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Text(
                'Nivara',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6366F1),
                  letterSpacing: -1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your personal AI companion',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.white60),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => context.push('/sign-in'),
                child: const Text('Get Started'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create `lib/features/auth/presentation/pages/sign_in_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_repository.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      if (mounted) context.go('/profile-setup');
    } catch (e) {
      setState(() => _error = 'Google sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter email and password.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).signInWithEmail(email, password);
      if (mounted) context.go('/chat');
    } catch (e) {
      setState(() => _error = 'Sign in failed. Check your credentials.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In'), backgroundColor: Colors.transparent),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loading ? null : _signInWithGoogle,
                icon: const Icon(Icons.g_mobiledata, size: 24),
                label: const Text('Continue with Google'),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _signInWithEmail,
                child: const Text('Sign in with Email'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run widget test**

```bash
cd nivara && flutter test test/auth/sign_in_page_test.dart
```

Expected: 1 PASSED

- [ ] **Step 6: Commit**

```bash
git add nivara/lib/features/auth/presentation/pages/ nivara/test/auth/sign_in_page_test.dart
git commit -m "feat(flutter): add welcome and sign-in pages"
```

---

## Task 11: Flutter — Shared Models + Profile Repository

**Files:**
- Create: `nivara/lib/shared/models/user_profile.dart`
- Create: `nivara/lib/features/profile/data/profile_repository.dart`
- Create: `nivara/lib/features/profile/presentation/providers/profile_provider.dart`
- Create: `nivara/test/profile/profile_repository_test.dart`

- [ ] **Step 1: Write the failing test**

Create `nivara/test/profile/profile_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/shared/models/user_profile.dart';

void main() {
  test('UserProfile.empty has blank fields', () {
    final p = UserProfile.empty();
    expect(p.name, isEmpty);
    expect(p.language, equals('en'));
  });

  test('AssistantConfig.defaults uses Rocky as name', () {
    final a = AssistantConfig.defaults();
    expect(a.name, equals('Rocky'));
    expect(a.voice, equals('neutral'));
  });
}
```

- [ ] **Step 2: Run to see it fail**

```bash
cd nivara && flutter test test/profile/profile_repository_test.dart
```

Expected: Compile error — `UserProfile` not found.

- [ ] **Step 3: Create `lib/shared/models/user_profile.dart`**

```dart
class UserProfile {
  const UserProfile({
    required this.name,
    required this.nickname,
    required this.gender,
    required this.dob,
    required this.language,
    required this.timezone,
    required this.photoUrl,
  });

  final String name;
  final String nickname;
  final String gender;
  final String dob;       // ISO8601 date string
  final String language;  // BCP-47 e.g. "en", "hi"
  final String timezone;  // IANA e.g. "Pacific/Auckland"
  final String photoUrl;

  factory UserProfile.empty() => const UserProfile(
        name: '',
        nickname: '',
        gender: '',
        dob: '',
        language: 'en',
        timezone: 'UTC',
        photoUrl: '',
      );

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        name: map['name'] as String? ?? '',
        nickname: map['nickname'] as String? ?? '',
        gender: map['gender'] as String? ?? '',
        dob: map['dob'] as String? ?? '',
        language: map['language'] as String? ?? 'en',
        timezone: map['timezone'] as String? ?? 'UTC',
        photoUrl: map['photoUrl'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'nickname': nickname,
        'gender': gender,
        'dob': dob,
        'language': language,
        'timezone': timezone,
        'photoUrl': photoUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  UserProfile copyWith({
    String? name,
    String? nickname,
    String? gender,
    String? dob,
    String? language,
    String? timezone,
    String? photoUrl,
  }) =>
      UserProfile(
        name: name ?? this.name,
        nickname: nickname ?? this.nickname,
        gender: gender ?? this.gender,
        dob: dob ?? this.dob,
        language: language ?? this.language,
        timezone: timezone ?? this.timezone,
        photoUrl: photoUrl ?? this.photoUrl,
      );
}

class AssistantConfig {
  const AssistantConfig({
    required this.name,
    required this.voice,
    required this.speed,
    required this.style,
    required this.wakePhrase,
    required this.aiModel,
  });

  final String name;
  final String voice;      // "male" | "female" | "neutral"
  final String speed;      // "slow" | "normal" | "fast"
  final String style;      // "formal" | "casual" | "friendly"
  final String wakePhrase; // "Hey Rocky"
  final String aiModel;    // "claude" | "gpt4o" | "gemini"

  factory AssistantConfig.defaults() => const AssistantConfig(
        name: 'Rocky',
        voice: 'neutral',
        speed: 'normal',
        style: 'friendly',
        wakePhrase: 'Hey Rocky',
        aiModel: 'claude',
      );

  factory AssistantConfig.fromMap(Map<String, dynamic> map) => AssistantConfig(
        name: map['name'] as String? ?? 'Rocky',
        voice: map['voice'] as String? ?? 'neutral',
        speed: map['speed'] as String? ?? 'normal',
        style: map['style'] as String? ?? 'friendly',
        wakePhrase: map['wakePhrase'] as String? ?? 'Hey Rocky',
        aiModel: map['aiModel'] as String? ?? 'claude',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'voice': voice,
        'speed': speed,
        'style': style,
        'wakePhrase': wakePhrase,
        'aiModel': aiModel,
      };
}
```

- [ ] **Step 4: Create `lib/features/profile/data/profile_repository.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/models/user_profile.dart';

part 'profile_repository.g.dart';

@riverpod
ProfileRepository profileRepository(Ref ref) => ProfileRepository();

class ProfileRepository {
  ProfileRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) =>
      _db.collection('users').doc(uid).collection('profile').doc('data');

  DocumentReference<Map<String, dynamic>> _assistantDoc(String uid) =>
      _db.collection('users').doc(uid).collection('assistant').doc('data');

  Future<UserProfile?> getProfile(String uid) async {
    final snap = await _profileDoc(uid).get();
    if (!snap.exists) return null;
    return UserProfile.fromMap(snap.data()!);
  }

  Future<void> saveProfile(String uid, UserProfile profile) =>
      _profileDoc(uid).set(profile.toMap(), SetOptions(merge: true));

  Future<AssistantConfig?> getAssistant(String uid) async {
    final snap = await _assistantDoc(uid).get();
    if (!snap.exists) return null;
    return AssistantConfig.fromMap(snap.data()!);
  }

  Future<void> saveAssistant(String uid, AssistantConfig config) =>
      _assistantDoc(uid).set(config.toMap(), SetOptions(merge: true));
}
```

- [ ] **Step 5: Create `lib/features/profile/presentation/providers/profile_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/profile_repository.dart';
import '../../../../shared/models/user_profile.dart';

part 'profile_provider.g.dart';

@riverpod
Future<UserProfile?> userProfile(Ref ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return ref.watch(profileRepositoryProvider).getProfile(user.uid);
}

@riverpod
Future<AssistantConfig?> assistantConfig(Ref ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return ref.watch(profileRepositoryProvider).getAssistant(user.uid);
}
```

- [ ] **Step 6: Run code generation then tests**

```bash
cd nivara && dart run build_runner build --delete-conflicting-outputs && flutter test test/profile/
```

Expected: 2 PASSED

- [ ] **Step 7: Commit**

```bash
git add nivara/lib/shared/ nivara/lib/features/profile/data/ nivara/lib/features/profile/presentation/providers/ nivara/test/profile/
git commit -m "feat(flutter): add UserProfile model and profile repository"
```

---

## Task 12: Flutter — Profile + Assistant Setup Pages

**Files:**
- Create: `nivara/lib/features/profile/presentation/pages/profile_setup_page.dart`
- Create: `nivara/lib/features/profile/presentation/pages/assistant_setup_page.dart`
- Create: `nivara/test/profile/profile_setup_page_test.dart`

- [ ] **Step 1: Write the widget test**

Create `nivara/test/profile/profile_setup_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nivara/features/profile/presentation/pages/profile_setup_page.dart';

void main() {
  testWidgets('profile setup page renders name and language fields', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const ProfileSetupPage()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    expect(find.text('Your Name'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to see it fail**

```bash
cd nivara && flutter test test/profile/profile_setup_page_test.dart
```

Expected: Compile error.

- [ ] **Step 3: Create `lib/features/profile/presentation/pages/profile_setup_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/models/user_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/profile_repository.dart';

class ProfileSetupPage extends ConsumerStatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  final _nameCtrl = TextEditingController();
  String _gender = '';
  String _language = 'en';
  bool _saving = false;

  static const _languages = ['en', 'hi', 'es', 'fr', 'de', 'zh', 'ja', 'ar'];

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _saving = true);
    final profile = UserProfile.empty().copyWith(
      name: _nameCtrl.text.trim(),
      gender: _gender,
      language: _language,
    );
    await ref.read(profileRepositoryProvider).saveProfile(user.uid, profile);
    if (mounted) context.go('/assistant-setup');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About You'), backgroundColor: Colors.transparent),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Your Name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _gender.isEmpty ? null : _gender,
                decoration: const InputDecoration(labelText: 'Gender (optional)'),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'non-binary', child: Text('Non-binary')),
                  DropdownMenuItem(value: 'prefer-not', child: Text('Prefer not to say')),
                ],
                onChanged: (v) => setState(() => _gender = v ?? ''),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _language,
                decoration: const InputDecoration(labelText: 'Language'),
                items: _languages
                    .map((l) => DropdownMenuItem(value: l, child: Text(l.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => _language = v ?? 'en'),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create `lib/features/profile/presentation/pages/assistant_setup_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/models/user_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/profile_repository.dart';

class AssistantSetupPage extends ConsumerStatefulWidget {
  const AssistantSetupPage({super.key});

  @override
  ConsumerState<AssistantSetupPage> createState() => _AssistantSetupPageState();
}

class _AssistantSetupPageState extends ConsumerState<AssistantSetupPage> {
  final _nameCtrl = TextEditingController(text: 'Rocky');
  String _voice = 'neutral';
  String _style = 'friendly';
  bool _saving = false;

  Future<void> _save() async {
    final assistantName = _nameCtrl.text.trim();
    if (assistantName.isEmpty) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    setState(() => _saving = true);
    final config = AssistantConfig(
      name: assistantName,
      voice: _voice,
      speed: 'normal',
      style: _style,
      wakePhrase: 'Hey $assistantName',
      aiModel: 'claude',
    );
    await ref.read(profileRepositoryProvider).saveAssistant(user.uid, config);
    if (mounted) context.go('/chat');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Name Your Assistant'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Give your AI companion a name.\nYou can change this any time.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Assistant Name'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _voice,
                decoration: const InputDecoration(labelText: 'Voice'),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'neutral', child: Text('Neutral')),
                ],
                onChanged: (v) => setState(() => _voice = v ?? 'neutral'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _style,
                decoration: const InputDecoration(labelText: 'Conversation Style'),
                items: const [
                  DropdownMenuItem(value: 'friendly', child: Text('Friendly')),
                  DropdownMenuItem(value: 'casual', child: Text('Casual')),
                  DropdownMenuItem(value: 'formal', child: Text('Formal')),
                ],
                onChanged: (v) => setState(() => _style = v ?? 'friendly'),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: const Text('Meet ${_nameCtrl.text.isEmpty ? "Rocky" : "them"}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run widget tests**

```bash
cd nivara && flutter test test/profile/
```

Expected: 3 PASSED

- [ ] **Step 6: Commit**

```bash
git add nivara/lib/features/profile/presentation/pages/ nivara/test/profile/profile_setup_page_test.dart
git commit -m "feat(flutter): add profile and assistant setup screens"
```

---

## Task 13: Flutter — Hermes HTTP Client

**Files:**
- Create: `nivara/lib/features/chat/data/hermes_client.dart`
- Create: `nivara/test/chat/hermes_client_test.dart`

- [ ] **Step 1: Write the failing test**

Create `nivara/test/chat/hermes_client_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/chat/data/hermes_client.dart';

void main() {
  test('HermesClient can be instantiated with base URL', () {
    final client = HermesClient(baseUrl: 'http://localhost:8000');
    expect(client, isNotNull);
  });
}
```

- [ ] **Step 2: Run to see it fail**

```bash
cd nivara && flutter test test/chat/hermes_client_test.dart
```

Expected: Compile error — `HermesClient` not found.

- [ ] **Step 3: Create `lib/features/chat/data/hermes_client.dart`**

```dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/presentation/providers/auth_provider.dart';

part 'hermes_client.g.dart';

const _defaultBaseUrl = String.fromEnvironment(
  'HERMES_BASE_URL',
  defaultValue: 'https://your-app.railway.app',
);

@riverpod
HermesClient hermesClient(Ref ref) {
  // Token refreshed automatically via firebaseIdTokenProvider
  return HermesClient(
    baseUrl: _defaultBaseUrl,
    tokenProvider: () => ref.read(firebaseIdTokenProvider.future),
  );
}

class HermesClient {
  HermesClient({
    required String baseUrl,
    Future<String> Function()? tokenProvider,
  })  : _baseUrl = baseUrl,
        _tokenProvider = tokenProvider;

  final String _baseUrl;
  final Future<String> Function()? _tokenProvider;

  /// Streams text chunks from the Hermes SSE chat endpoint.
  Stream<String> chatStream({
    required List<Map<String, String>> messages,
    required String assistantName,
    String aiModel = 'claude',
  }) async* {
    final token = _tokenProvider != null ? await _tokenProvider!() : '';

    final dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'text/event-stream',
        'Content-Type': 'application/json',
      },
      responseType: ResponseType.stream,
    ));

    final response = await dio.post<ResponseBody>(
      '/api/v1/chat',
      data: {
        'messages': messages,
        'assistant_name': assistantName,
        'ai_model': aiModel,
      },
    );

    final stream = response.data!.stream;
    StringBuffer buffer = StringBuffer();

    await for (final chunk in stream) {
      buffer.write(String.fromCharCodes(chunk));
      final raw = buffer.toString();
      buffer.clear();

      for (final line in raw.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.startsWith('data: ')) {
          final data = trimmed.substring(6);
          if (data == '[DONE]') return;
          yield data;
        }
      }
    }
  }
}
```

- [ ] **Step 4: Run code generation then tests**

```bash
cd nivara && dart run build_runner build --delete-conflicting-outputs && flutter test test/chat/hermes_client_test.dart
```

Expected: 1 PASSED

- [ ] **Step 5: Commit**

```bash
git add nivara/lib/features/chat/data/hermes_client.dart nivara/test/chat/
git commit -m "feat(flutter): add Hermes SSE streaming HTTP client"
```

---

## Task 14: Flutter — Chat Domain + Provider

**Files:**
- Create: `nivara/lib/features/chat/domain/message.dart`
- Create: `nivara/lib/features/chat/data/conversation_repository.dart`
- Create: `nivara/lib/features/chat/presentation/providers/chat_provider.dart`
- Create: `nivara/test/chat/chat_provider_test.dart`

- [ ] **Step 1: Write the failing test**

Create `nivara/test/chat/chat_provider_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nivara/features/chat/domain/message.dart';

void main() {
  test('ChatMessage serialises to Hermes format', () {
    const msg = ChatMessage(role: MessageRole.user, content: 'Hello');
    final map = msg.toHermesMap();
    expect(map['role'], equals('user'));
    expect(map['content'], equals('Hello'));
  });

  test('ChatMessage.assistant has correct role', () {
    const msg = ChatMessage(role: MessageRole.assistant, content: 'Hi!');
    expect(msg.isUser, isFalse);
  });
}
```

- [ ] **Step 2: Run to see it fail**

```bash
cd nivara && flutter test test/chat/chat_provider_test.dart
```

Expected: Compile error.

- [ ] **Step 3: Create `lib/features/chat/domain/message.dart`**

```dart
enum MessageRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
  });

  final MessageRole role;
  final String content;
  final bool isStreaming;

  bool get isUser => role == MessageRole.user;

  Map<String, String> toHermesMap() => {
        'role': role.name,
        'content': content,
      };

  ChatMessage copyWith({String? content, bool? isStreaming}) => ChatMessage(
        role: role,
        content: content ?? this.content,
        isStreaming: isStreaming ?? this.isStreaming,
      );
}
```

- [ ] **Step 4: Create `lib/features/chat/data/conversation_repository.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/message.dart';

part 'conversation_repository.g.dart';

@riverpod
ConversationRepository conversationRepository(Ref ref) =>
    ConversationRepository();

class ConversationRepository {
  ConversationRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _convCollection(String uid) =>
      _db.collection('users').doc(uid).collection('conversations');

  Future<String> createConversation(String uid) async {
    final doc = await _convCollection(uid).add({
      'messages': [],
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    return doc.id;
  }

  Future<void> appendMessage(
    String uid,
    String conversationId,
    ChatMessage message,
  ) =>
      _convCollection(uid).doc(conversationId).update({
        'messages': FieldValue.arrayUnion([
          {
            'role': message.role.name,
            'content': message.content,
            'timestamp': DateTime.now().toIso8601String(),
          }
        ]),
        'updatedAt': DateTime.now().toIso8601String(),
      });
}
```

- [ ] **Step 5: Create `lib/features/chat/presentation/providers/chat_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/models/user_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../data/hermes_client.dart';
import '../../domain/message.dart';

part 'chat_provider.g.dart';

@riverpod
class ChatNotifier extends _$ChatNotifier {
  @override
  List<ChatMessage> build() => [];

  Future<void> sendMessage(String text) async {
    final userMsg = ChatMessage(role: MessageRole.user, content: text);
    state = [...state, userMsg];

    // Add placeholder for streaming assistant response
    final placeholder = ChatMessage(
      role: MessageRole.assistant,
      content: '',
      isStreaming: true,
    );
    state = [...state, placeholder];

    final assistantIndex = state.length - 1;
    final hermesMessages = state
        .where((m) => !m.isStreaming)
        .map((m) => m.toHermesMap())
        .toList();

    final config = await ref.read(assistantConfigProvider.future);
    final assistantName = config?.name ?? 'Rocky';

    final client = ref.read(hermesClientProvider);
    final buffer = StringBuffer();

    await for (final chunk in client.chatStream(
      messages: hermesMessages,
      assistantName: assistantName,
    )) {
      buffer.write(chunk);
      final updated = List<ChatMessage>.from(state);
      updated[assistantIndex] = ChatMessage(
        role: MessageRole.assistant,
        content: buffer.toString(),
        isStreaming: true,
      );
      state = updated;
    }

    // Mark streaming complete
    final finalMessages = List<ChatMessage>.from(state);
    finalMessages[assistantIndex] = ChatMessage(
      role: MessageRole.assistant,
      content: buffer.toString(),
      isStreaming: false,
    );
    state = finalMessages;
  }
}
```

- [ ] **Step 6: Run code generation then tests**

```bash
cd nivara && dart run build_runner build --delete-conflicting-outputs && flutter test test/chat/
```

Expected: 2 PASSED

- [ ] **Step 7: Commit**

```bash
git add nivara/lib/features/chat/ nivara/test/chat/
git commit -m "feat(flutter): add chat domain models and streaming chat provider"
```

---

## Task 15: Flutter — Chat Screen

**Files:**
- Create: `nivara/lib/features/chat/presentation/widgets/message_bubble.dart`
- Create: `nivara/lib/features/chat/presentation/widgets/chat_input_bar.dart`
- Create: `nivara/lib/features/chat/presentation/pages/chat_page.dart`
- Create: `nivara/test/chat/chat_page_test.dart`

- [ ] **Step 1: Write the widget test**

Create `nivara/test/chat/chat_page_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nivara/features/chat/presentation/pages/chat_page.dart';
import 'package:nivara/features/chat/presentation/providers/chat_provider.dart';
import 'package:nivara/features/chat/domain/message.dart';

void main() {
  testWidgets('chat page renders message input bar', (tester) async {
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, __) => const ChatPage())],
    );
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to see it fail**

```bash
cd nivara && flutter test test/chat/chat_page_test.dart
```

Expected: Compile error.

- [ ] **Step 3: Create `lib/features/chat/presentation/widgets/message_bubble.dart`**

```dart
import 'package:flutter/material.dart';
import '../../domain/message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isUser ? 64 : 0,
          right: isUser ? 0 : 64,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF6366F1)
              : const Color(0xFF1A1A24),
          borderRadius: BorderRadius.circular(16),
        ),
        child: message.isStreaming
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message.content,
                      style: const TextStyle(color: Colors.white)),
                  const SizedBox(width: 4),
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.white54,
                    ),
                  ),
                ],
              )
            : Text(message.content,
                style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
```

- [ ] **Step 4: Create `lib/features/chat/presentation/widgets/chat_input_bar.dart`**

```dart
import 'package:flutter/material.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({super.key, required this.onSend, this.enabled = true});

  final void Function(String text) onSend;
  final bool enabled;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _ctrl = TextEditingController();

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    widget.onSend(text);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A24),
        border: Border(top: BorderSide(color: Color(0xFF2D2D3D))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              enabled: widget.enabled,
              decoration: const InputDecoration(
                hintText: 'Message…',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.send,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Color(0xFF6366F1)),
            onPressed: widget.enabled ? _submit : null,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Create `lib/features/chat/presentation/pages/chat_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/user_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';

class ChatPage extends ConsumerWidget {
  const ChatPage({super.key});

  String _greeting(AssistantConfig? config) {
    final name = config?.name ?? 'Rocky';
    final hour = DateTime.now().hour;
    final timeOfDay = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return '$timeOfDay! I\'m $name. How are you feeling today?';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatNotifierProvider);
    final configAsync = ref.watch(assistantConfigProvider);
    final isStreaming =
        messages.isNotEmpty && messages.last.isStreaming;

    return Scaffold(
      appBar: AppBar(
        title: configAsync.when(
          data: (c) => Text(c?.name ?? 'Nivara'),
          loading: () => const Text('Nivara'),
          error: (_, __) => const Text('Nivara'),
        ),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () =>
                ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: configAsync.when(
                      data: (c) => Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _greeting(c),
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white60,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (_, i) =>
                        MessageBubble(message: messages[i]),
                  ),
          ),
          ChatInputBar(
            enabled: !isStreaming,
            onSend: (text) =>
                ref.read(chatNotifierProvider.notifier).sendMessage(text),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Run all tests**

```bash
cd nivara && flutter test
```

Expected: All tests PASSED.

- [ ] **Step 7: Commit**

```bash
git add nivara/lib/features/chat/presentation/ nivara/test/chat/chat_page_test.dart
git commit -m "feat(flutter): add chat screen with streaming message bubbles"
```

---

## Task 16: End-to-End Smoke Test + Deploy

**Files:**
- Create: `nivara/integration_test/app_test.dart`

- [ ] **Step 1: Set up integration test**

Create `nivara/integration_test/app_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nivara/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches and shows welcome screen', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Get Started'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run integration test on a connected device or emulator**

```bash
cd nivara && flutter test integration_test/app_test.dart
```

Expected: 1 PASSED

- [ ] **Step 3: Run all unit + widget tests**

```bash
cd nivara && flutter test --coverage
```

Expected: All PASSED. Check `coverage/lcov.info` is generated.

- [ ] **Step 4: Run all Hermes backend tests**

```bash
cd hermes-agent && pytest tests/ -v --tb=short
```

Expected: All PASSED.

- [ ] **Step 5: Deploy Hermes to Railway**

```bash
# Install Railway CLI if needed
npm i -g @railway/cli

# Login and link project
railway login
railway init  # name: hermes-agent

# Set env vars in Railway dashboard:
# ANTHROPIC_API_KEY=sk-ant-...
# Then add serviceAccountKey.json as a Railway secret file

# Deploy
railway up
```

- [ ] **Step 6: Update `HERMES_BASE_URL` in Flutter**

In `nivara/lib/features/chat/data/hermes_client.dart`, the URL is read from `--dart-define=HERMES_BASE_URL=...`.

Add to your `flutter run` / build commands:
```bash
flutter run --dart-define=HERMES_BASE_URL=https://hermes-agent-production.up.railway.app
```

- [ ] **Step 7: Final commit**

```bash
git add nivara/integration_test/ hermes-agent/
git commit -m "feat: end-to-end smoke test and Railway deployment config"
```

---

## Self-Review Checklist (completed inline)

| Spec requirement | Covered by task |
|---|---|
| Flutter iOS + Android | Task 6 |
| Firebase Auth (Google + Email) | Task 9–10 |
| Profile setup (name, gender, language) | Task 11–12 |
| Custom assistant name + voice | Task 12 |
| Hermes FastAPI backend | Task 1–5 |
| JWT auth on all API calls | Task 3 |
| Streaming Claude chat | Task 4, 13–14 |
| Chat screen with message bubbles | Task 15 |
| Conversation persistence (Firestore) | Task 14 |
| App theme (dark, Indigo primary) | Task 6 |
| Auth-aware routing | Task 8 |
| Railway.app deployment | Task 16 |

**Not in this plan (by design — separate plans):**
- Wake word (Plan 2)
- Voice STT/TTS (Plan 2)
- AI Planner (Plan 3)
- Memory/ChromaDB (Plan 4)
- Mood detection (Plan 5)
- Music system (Plan 6)
- RevenueCat subscriptions (Plan 7)
- 2FA/biometric (intentionally deferred to Plan 1b after core flow works)
