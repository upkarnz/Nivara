# Nivara — AI Companion & Voice Assistant App
**Design Spec**

**Created:** 2026-04-27
**Status:** Approved — Ready for Implementation
**Author:** Upkar Singh

---

## Overview

Nivara is a personal AI companion mobile app (iOS + Android) built in Flutter. It combines emotional support, voice assistance, daily planning, mood tracking, and music — all powered by a customisable AI assistant the user can name anything they want (Rocky, Billi, Jarvis, or any name). The app is designed for all users — not only introverts — who want a caring, intelligent daily companion they can trust.

---

## Requirements Summary

| Requirement | Decision |
|---|---|
| Platform | iOS + Android (Flutter) |
| Framework | Flutter 3.x |
| AI Primary | Claude (Anthropic) |
| AI Orchestration | Hermes Agent (FastAPI, Python) on Railway.app |
| AI Switching | GPT-4o + Gemini available on Premium tier |
| Backend | Firebase (Auth, Firestore, Storage, FCM) |
| Subscription | RevenueCat — Free / Pro ($9.99/mo) / Premium ($19.99/mo) |
| Wake Word | Porcupine SDK (on-device, 100% private) |
| Voice STT | `speech_to_text` Flutter package |
| Voice TTS | `flutter_tts` + ElevenLabs (natural voice) |
| Music | Built-in curated royalty-free library + optional Spotify |
| Memory | 3-layer: Hot (Firestore) + Warm (vector embeddings) + Cold (Obsidian graph) |
| Planner | AI-powered natural language scheduling, voice + text |
| Calendar Sync | Google Calendar + Apple Calendar (v1.1) |
| Mood Detection | Text sentiment + manual check-in (v1.0); voice tone (v1.2) |
| Knowledge Graph | Obsidian-compatible in-app graph view (v1.1) |
| Auth | Firebase Auth — Google Sign-In + Email + TOTP 2FA + Biometric |
| Security | AES-256 at rest, TLS 1.3 in transit, JWT, Firestore security rules |
| Deployment | Railway.app for Hermes agent ($5–20/mo MVP scale) |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        FLUTTER APP                              │
│  iOS + Android · Wake Word · Chat · Voice · Planner             │
│  Mood · Music · Memory Graph · Settings · Subscriptions         │
└──────────────────────┬──────────────────────────────────────────┘
                       │ HTTPS / WebSocket
         ┌─────────────┴─────────────────┐
         ▼                               ▼
┌────────────────┐           ┌──────────────────────────────────┐
│   FIREBASE     │           │       HERMES AGENT SERVICE       │
│  Auth          │◄──────────│  FastAPI · Python                │
│  Firestore     │  JWT auth │  Claude API · OpenAI · Gemini    │
│  Storage       │  read/write│  Memory extraction               │
│  FCM (push)    │           │  Mood analysis                   │
│  Analytics     │           │  Planner NLP                     │
└────────────────┘           │  Vector embeddings (ChromaDB)    │
                             │  Obsidian graph generation       │
                             └──────────────────────────────────┘
                                          │
                    ┌─────────────────────┼──────────────────┐
                    ▼                     ▼                   ▼
             Claude API            GPT-4o API          Gemini API
            (Free + Pro)          (Premium only)      (Premium only)
```

---

## Screens (12 Total)

| # | Screen | Key Elements |
|---|--------|-------------|
| 1 | Welcome | App name, tagline, animated logo, Get Started button |
| 2 | Sign In | Google Sign-In, Email + Password, 2FA setup |
| 3 | Profile Setup | Name, nickname, gender, DOB, language, timezone |
| 4 | Assistant Setup | Custom name, voice (M/F/neutral), speaking speed, style |
| 5 | Home / Chat | Greeting by name, chat thread, mood pill, music mini-player |
| 6 | Voice Mode | Full-screen waveform, real-time transcription, haptic feedback |
| 7 | AI Planner | Calendar views (day/week/month/agenda), event list, voice scheduling |
| 8 | Mood Board | Daily mood entry, weekly bar chart, Rocky's insights, mood history |
| 9 | Music Player | Mood playlists, track controls, curated library, Spotify toggle |
| 10 | Memory Graph | Interactive Obsidian-style graph, topic clusters, timeline |
| 11 | Settings | 6 sections (see Settings Structure below) |
| 12 | Upgrade / Paywall | Tier comparison, in-app purchase, restore, annual toggle |

---

## User Flows

### First Launch
```
Welcome → Sign Up (Google or Email) → 2FA Setup → Profile Setup →
Name Your Assistant → First Greeting → Home
```

### Returning User
```
App Open → Biometric / PIN → Personalized Greeting → Home
```

### Wake Word (Background)
```
User says "Hey [Name]" → Porcupine detects on-device →
App wakes / opens → Voice mode activates → Assistant greets by name
```

### Voice Scheduling
```
"Hey Rocky, schedule dentist next Friday at 10am, remind me the day before" →
Hermes NLP extracts intent → Planner event created → Push notification scheduled →
Rocky confirms verbally
```

---

## Core Features Design

### Wake Word System (Porcupine SDK)
- 100% on-device detection — no audio leaves device until wake word confirmed
- Supports custom names via Picovoice Console API (wake word `.ppn` file generated server-side from user's chosen name, downloaded to device on first setup or name change; top 100 popular names pre-bundled)
- Phrases: "Hey [Name]" and "Hi [Name]" both work
- Works with screen locked via background service
- Visual pulsing ring indicator when listening
- Haptic feedback on successful detection
- Noise threshold to suppress false positives

### AI Personality & Greeting Logic
- Greets user by their preferred name on every app open
- Greeting varies by time of day: morning / afternoon / evening
- Mood-aware tone adjustment — softer on anxious/sad days, upbeat on happy/excited days
- References recent context: *"How did that meeting go?"* / *"Happy birthday, Upkar!"*
- Remembers birthdays and anniversaries from profile DOB + events
- Never repeats the same greeting phrasing twice in a row
- Voice: male, female, or neutral (selectable in settings)

### Chat Interface
- Streaming responses from Claude (tokens appear in real time)
- Voice button inline in chat bar — tap to speak, release to send
- Mood pill auto-detected from conversation and displayed below messages
- Music suggestion pill triggered when mood is detected (e.g., *"🎵 Calm playlist"*)
- Conversation history loaded from Firestore on open
- Markdown rendering in AI responses (bold, lists, code)

### Voice Mode
- Full-screen activated via voice button or wake word
- Animated waveform visualiser during listening
- Real-time transcription displayed on screen
- Rocky's response shown as text + spoken via TTS simultaneously
- Tap anywhere to dismiss / return to chat view

---

## AI Planner & Scheduler

### Scheduling Capabilities
| Input | Example |
|---|---|
| Voice | "Hey Rocky, remind me to call mum at 7pm" |
| Text | "Schedule gym every Monday and Thursday at 6pm" |
| Natural query | "What do I have tomorrow?" |
| Reschedule | "Move my 2pm to 4pm and notify me 30 minutes before" |
| Recurring | "Add a weekly team meeting every Friday at 9am" |

### Calendar Views
- Day view — hourly timeline
- Week view — 7-column grid
- Month view — calendar grid with dot indicators
- Agenda view — upcoming list

### Smart Features
- Natural language parsing via Hermes agent (Claude-powered intent extraction)
- Recurring event support (daily, weekly, monthly, custom)
- Smart conflict detection — warns when events overlap
- AI time slot suggestions — *"You're usually free 3–4pm on Thursdays"*
- Mood-aware scheduling (Premium) — suggests lighter tasks on low-mood days

### Calendar Integrations (v1.1)
- Google Calendar — two-way sync
- Apple Calendar — two-way sync
- Push notification reminders (FCM)

### Subscription Gating
| Feature | Free | Pro | Premium |
|---|---|---|---|
| Events/month | 10 | Unlimited | Unlimited |
| Recurring events | ✗ | ✓ | ✓ |
| Calendar sync | ✗ | ✓ | ✓ |
| All calendar views | ✗ | ✓ | ✓ |
| AI time suggestions | ✗ | ✗ | ✓ |
| Mood-aware scheduling | ✗ | ✗ | ✓ |
| Smart conflict resolve | ✗ | ✗ | ✓ |

---

## AI Memory System

### 3-Layer Architecture

**Layer 1 — Hot Memory (Firestore, real-time)**
- Current session context
- Today's mood and planner items
- Active conversation thread
- Retention: 7 days (Free) / 90 days (Pro) / Forever (Premium)

**Layer 2 — Warm Memory (Firestore + vector embeddings)**
- Recurring topics and user interests
- Relationship mentions (family, friends, colleagues)
- Emotional patterns by day and week
- Habits and preferences
- Life events and milestones
- Retention: 3 months

**Layer 3 — Cold Memory (Firestore + Obsidian export)**
- Core personality insights distilled by Hermes
- Long-term goals
- Archived conversation summaries
- Obsidian knowledge graph nodes and edges
- Exportable as JSON or .md files (Premium)

### Memory Pipeline
```
Conversation message →
Hermes agent extracts facts and entities →
Stores structured data in Firestore →
Builds sentence-transformers vector embeddings →
Indexes in ChromaDB →
Updates Obsidian graph nodes
```

### Memory Retrieval
- On each conversation turn, Hermes performs semantic search over ChromaDB
- Top-k relevant memories injected into Claude's system prompt
- User can view, edit, and delete any stored memory node from the Memory Graph screen

---

## Mood Detection Engine

### Detection Signals (v1.0)
1. **Text sentiment analysis** — Claude analyses word choice, punctuation patterns, and message pacing
2. **Manual check-in** — Rocky asks *"How are you feeling today?"* and user responds naturally or selects from mood picker

### Detection Signals (v1.2 addition)
3. **Voice tone analysis** — pitch, speed, and pause patterns processed locally
4. **Behavioural signals** — app open time, message frequency, response latency patterns

### Mood States
`Happy` · `Anxious` · `Sad` · `Frustrated` · `Tired` · `Excited` · `Neutral`

### Mood-Triggered Actions
- Music playlist swap to match detected mood
- Greeting tone adjustment
- Breathing exercise suggestion on Anxious / Frustrated
- Journal prompt on Sad
- Planner task reordering on Tired (Premium, v1.2)

### Mood Board Screen
- Daily mood entry with emoji picker
- Weekly bar chart (colour-coded by mood state)
- Rocky's weekly insight (*"You feel best on Fridays — want to schedule something fun on Wednesdays?"*)
- Mood history: 7 days (Free) / 90 days (Pro) / All time (Premium)

---

## Music System

### Sources
- **Built-in curated library** (all tiers) — royalty-free tracks organised by mood: Calm, Focus, Energetic, Happy, Sleep, Reflective
- **Spotify integration** (optional, all tiers) — user connects own Spotify account; app controls playback and creates mood-based playlists

### Features
- Mini-player always visible in chat and planner screens
- Mood-triggered auto-play when mood detected
- Manual playlist browse by mood category
- Sleep timer (30 / 60 / 90 min)
- Background playback

---

## Obsidian Knowledge Graph

### In-App View
- Interactive force-directed graph using `graphview` Flutter package
- Nodes: topics (family, work, health, goals), people, emotions, events
- Edges: co-occurrence and semantic relationship
- Edge thickness: frequency (talked about more = thicker)
- Tap any node to see related conversations and timeline entries
- Cluster view — groups related topics automatically

### Export (Premium)
- Download as `.md` files compatible with Obsidian desktop app
- Share as image (PNG)
- Full JSON export of all memory nodes and edges

---

## Profile & Personalization System

### Basic Profile
- Full name + preferred name / nickname
- Gender (optional)
- Date of birth (used for birthday greetings)
- Profile photo
- Timezone

### Assistant Settings
- Assistant name (fully editable — any custom name)
- Voice: male / female / neutral
- Speaking speed: slow / normal / fast
- Conversation style: formal / casual / friendly
- Language (20+ languages via TTS + Claude system prompt)
- AI model (Free/Pro: Claude only; Premium: Claude / GPT-4o / Gemini)

### Settings Page Structure
```
MY PROFILE         — Name · Gender · DOB · Photo · Language · Timezone
MY ASSISTANT       — Name · Voice · Speed · Style · AI Model · Wake Word
PLANNER            — Google Cal sync · Apple Cal sync · Default reminder time
MUSIC              — Source (built-in / Spotify) · Spotify connect · Volume default
PRIVACY & SECURITY — 2FA · Biometric · Data export · Delete history · Delete account
SUBSCRIPTION       — Current plan · Upgrade · Restore purchase · Billing info
```

---

## Subscription Model

### Tiers

| Feature | Free | Pro $9.99/mo | Premium $19.99/mo |
|---|---|---|---|
| Messages/day | 20 | Unlimited | Unlimited |
| Voice chat/day | 5 min | Unlimited | Unlimited |
| Memory retention | 7 days | 90 days | Forever |
| Planner events | 10/month | Unlimited | Unlimited |
| Calendar sync | ✗ | Google + Apple | Google + Apple |
| All calendar views | ✗ | ✓ | ✓ |
| AI model | Claude | Claude | Claude + GPT-4o + Gemini |
| Mood history | Today | 90 days | All time |
| Mood-aware scheduling | ✗ | ✗ | ✓ |
| AI time suggestions | ✗ | ✗ | ✓ |
| Memory export | ✗ | ✗ | JSON + Obsidian .md |
| Obsidian graph view | ✗ | ✓ (v1.1) | ✓ (v1.1) |
| Spotify connect | ✓ (v1.1) | ✓ (v1.1) | ✓ (v1.1) |
| Annual discount | — | $7.99/mo | $15.99/mo |
| Free trial | — | 7 days | 7 days |

### Billing — RevenueCat SDK
- Single SDK — works on iOS (App Store) and Android (Google Play)
- Monthly and annual plans per tier
- 7-day free trial on Pro and Premium
- One-tap restore purchase
- RevenueCat webhook fires to Firebase on subscription change → updates `users/{uid}/subscription`
- Entitlement checks enforced at app level AND Hermes API level (JWT claims)

### Smart Paywall Triggers
- Daily message limit hit → upgrade nudge inline in chat
- Try to sync calendar → Pro upsell sheet
- Try to switch AI model → Premium upsell sheet
- 7-day memory warning (3 days before expiry) → upgrade reminder
- Mood history older than 7 days accessed → Pro prompt
- Soft paywall first (3 dismissals) → hard block thereafter

---

## Security & Authentication

### Authentication Flow
```
App open →
Google Sign-In OR Email + Password →
TOTP 2FA (optional, strongly encouraged) →
Firebase token issued →
JWT sent to Hermes agent on every API call →
Hermes validates JWT before processing →
App home → Rocky greets by name
```

```
Returning user →
Biometric (Face ID / fingerprint) or PIN →
Session resumed → Rocky greets by name
```

### Encryption
- All data encrypted at rest — AES-256 (Firestore + Firebase Storage default)
- All API calls over TLS 1.3
- Voice recordings encrypted in Cloud Storage
- Client tokens stored in `flutter_secure_storage` (iOS Keychain / Android Keystore)
- API keys for Claude/OpenAI/Gemini stored only on Hermes backend — never sent to client

### Firestore Security Rules
- Every document path scoped to `users/{uid}` — users can only read/write their own data
- Hermes agent accesses Firestore via `firebase-admin` SDK with service account
- No cross-user data access possible at rule level

### Privacy Controls
- Delete individual conversation messages
- Delete full conversation history
- Delete all mood data
- Delete full account and all associated data (GDPR Article 17)
- Pause memory collection (Rocky stops learning, still converses)
- Export all data as JSON (GDPR Article 20)
- Clear privacy policy surfaced in settings — plain language
- No user data sold or shared with third parties

---

## Full Technical Stack

### Flutter App Packages
```yaml
dependencies:
  flutter_riverpod: ^2.x        # State management
  go_router: ^13.x              # Navigation
  porcupine_flutter: ^3.x       # Wake word (Picovoice)
  speech_to_text: ^6.x          # STT
  flutter_tts: ^3.x             # TTS (fallback / offline)
  # ElevenLabs: called via REST from Hermes; audio streamed back as bytes and played via just_audio
  just_audio: ^0.9.x            # Music playback
  purchases_flutter: ^7.x       # RevenueCat subscriptions
  fl_chart: ^0.67.x             # Mood charts
  graphview: ^1.2.x             # Obsidian knowledge graph
  local_auth: ^2.x              # Biometric unlock
  flutter_secure_storage: ^9.x  # Token storage
  table_calendar: ^3.x          # Planner calendar view
  spotify_sdk: ^2.x             # Spotify integration
  firebase_auth: ^4.x
  cloud_firestore: ^4.x
  firebase_storage: ^11.x
  firebase_messaging: ^14.x
  firebase_analytics: ^10.x
  firebase_crashlytics: ^3.x
```

### Hermes Agent Service (FastAPI / Python)
```
hermes-agent/
├── main.py                 # FastAPI app entry
├── routers/
│   ├── chat.py             # /chat — main conversation endpoint
│   ├── planner.py          # /planner — NLP scheduling
│   ├── mood.py             # /mood — analysis + logging
│   └── memory.py           # /memory — graph + retrieval
├── services/
│   ├── claude_service.py   # Anthropic SDK calls
│   ├── openai_service.py   # OpenAI SDK (Premium)
│   ├── gemini_service.py   # Google Generative AI (Premium)
│   ├── memory_service.py   # ChromaDB + Firestore memory
│   ├── mood_service.py     # Sentiment analysis
│   └── planner_service.py  # Event extraction + scheduling
├── models/
│   ├── user.py             # User profile schema
│   ├── message.py          # Chat message schema
│   ├── event.py            # Planner event schema
│   └── memory_node.py      # Knowledge graph node schema
├── auth/
│   └── firebase_jwt.py     # JWT validation middleware
└── requirements.txt
```

**Key Python libraries:**
- `anthropic` — Claude API
- `openai` — GPT-4o (Premium)
- `google-generativeai` — Gemini (Premium)
- `firebase-admin` — Firestore read/write
- `sentence-transformers` — text embeddings
- `chromadb` — vector memory store
- `pydantic` — request/response validation
- `python-jose` — JWT validation

### Firestore Data Model
```
users/{uid}/
  profile: {
    name, nickname, gender, dob, language, timezone,
    photoUrl, createdAt, updatedAt
  }
  assistant: {
    name, voice, speed, style, wakePhrase, aiModel
  }
  subscription: {
    tier, expiresAt, revenueCatId, entitlements[]
  }
  conversations/{convId}: {
    messages: [{ role, content, timestamp, mood }],
    createdAt, updatedAt
  }
  mood_logs/{date}: {
    mood, score, note, detectedFrom, timestamp
  }
  planner_events/{eventId}: {
    title, startAt, endAt, recurring, reminder,
    source (voice|text|calendar), createdAt
  }
  memory_nodes/{nodeId}: {
    label, type (topic|person|emotion|event),
    content, embedding, connections[], weight, createdAt
  }
```

---

## Hermes Agent Integration

Hermes is installed as the orchestration backbone of the Nivara backend. It manages:

1. **Conversation routing** — decides which AI model to call based on user's subscription tier
2. **Memory extraction** — after each message, extracts facts, entities, and emotional signals
3. **Mood analysis** — runs sentiment scoring on conversation content
4. **Planner NLP** — extracts scheduling intent from natural language
5. **Context injection** — retrieves top-k relevant memories from ChromaDB and injects into AI system prompt
6. **Graph updates** — incrementally updates Obsidian-format knowledge graph in Firestore
7. **Tool routing** — calls music, calendar, and reminder APIs based on user intent

The Flutter app communicates with Hermes via authenticated REST endpoints. All AI model calls are proxied through Hermes — the app never calls AI APIs directly.

---

## MVP Feature List (v1.0 — Weeks 1–14)

- [ ] Flutter app scaffold — iOS + Android
- [ ] Firebase project setup (Auth, Firestore, Storage, FCM)
- [ ] Google Sign-In + Email auth + TOTP 2FA
- [ ] Biometric unlock (Face ID / fingerprint)
- [ ] Profile setup screen (name, gender, DOB, language, timezone)
- [ ] Custom assistant name + voice settings
- [ ] Wake word detection via Porcupine SDK
- [ ] Text chat with Claude (streaming)
- [ ] Voice chat (STT → Claude → TTS)
- [ ] Personalised greeting by name + time of day
- [ ] Mood check-in (manual) + 7-day mood chart
- [ ] Mood-triggered music suggestions
- [ ] Built-in curated music player (by mood)
- [ ] AI Planner — voice + text natural language scheduling
- [ ] Planner calendar view (day + agenda for MVP)
- [ ] Push notification reminders (FCM)
- [ ] Conversation memory via Hermes agent (hot layer)
- [ ] RevenueCat subscription (Free / Pro / Premium)
- [ ] Smart paywall triggers
- [ ] Settings page (all 6 sections)
- [ ] Privacy controls (delete history, delete account)
- [ ] Hermes agent deployed on Railway.app
- [ ] Crashlytics + Analytics instrumented

---

## Post-MVP Roadmap

### v1.1 — Connections (Weeks 15–22)
- Obsidian knowledge graph in-app view
- Google Calendar two-way sync
- Apple Calendar two-way sync
- Spotify account connect + playback control
- 90-day mood history chart
- Memory graph export (image + .md files)
- Week + month calendar views

### v1.2 — Intelligence (Weeks 23–32)
- GPT-4o and Gemini model switching (Premium)
- Voice tone mood detection (on-device)
- Mood-aware planner scheduling (Premium)
- Memory export as JSON (Premium)
- AI time slot suggestions
- Smart conflict detection and resolution
- Obsidian .md export

### v2.0 — Expansion (Weeks 33–48)
- Breathing exercises + guided meditation
- AI journal prompts engine
- iOS home screen widget
- Apple Watch companion app
- Wear OS companion app
- Web companion (browser app)
- Multiple user profiles (family plan)

---

## Non-Goals for v1.0

- On-device AI model (Ollama / offline mode) — v3.0
- Group / shared conversations — not planned
- Android TV or desktop app — not planned
- Social features or friend connections — not planned
- Third-party therapy / mental health professional integration — future consideration

---

## Success Metrics (MVP)

| Metric | Target |
|---|---|
| App store rating | ≥ 4.4 stars |
| Day-1 retention | ≥ 50% |
| Day-7 retention | ≥ 30% |
| Free → Pro conversion | ≥ 5% |
| Pro → Premium conversion | ≥ 20% of Pro |
| Wake word daily active use | ≥ 40% of DAU |
| Planner event created in first week | ≥ 60% of users |
| Avg daily messages per user | ≥ 8 |
| Crash-free rate | ≥ 99.5% |
