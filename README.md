# LexBot — DPDP Personal Learning Agent

A smart AI agent that scrapes DPDP learning resources daily, builds a personalised weekly plan, and delivers it via a Flutter Android app with push notifications and email digests.

---

## Architecture

```
Flutter App (Android)
    │  chat / paste URLs
    ▼
FastAPI Backend  (Python 3.11)
    ├─ trafilatura       → scrape DPDP content from seed URLs
    ├─ Brave Search API  → discover new DPDP content weekly
    ├─ Claude Sonnet     → enrich, summarise, generate weekly plan
    ├─ text-embedding-3-small → vector embeddings
    ├─ APScheduler       → daily scrape (7am) + reminder (8am) + weekly plan (Sun 9am)
    ├─ firebase-admin    → FCM push notifications
    └─ SendGrid          → weekly email digest
    │
    ▼
Supabase (Postgres + pgvector)
    items · plans · devices
```

---

## Backend Setup

### 1. Install dependencies

```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
```

### 2. Supabase

1. Create a project at [supabase.com](https://supabase.com)
2. SQL Editor → run `db/schema.sql`
3. Copy your project URL and service role key from Settings → API

### 3. Firebase

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com)
2. Project Settings → Service Accounts → Generate new private key
3. Paste the JSON as a single line in `FIREBASE_CREDENTIALS_JSON`
4. Add `google-services.json` to `flutter_app/android/app/`

### 4. Environment variables

```bash
cp .env.example .env
# Fill in all values
```

| Variable | Required | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | ✅ | Claude API key |
| `OPENAI_API_KEY` | ✅ | For text-embedding-3-small |
| `SUPABASE_URL` | ✅ | Supabase project URL |
| `SUPABASE_KEY` | ✅ | Supabase anon/service key |
| `FIREBASE_CREDENTIALS_JSON` | ✅ | Firebase service account JSON |
| `BRAVE_API_KEY` | ✅ | Brave Search API key (free tier available) |
| `SENDGRID_API_KEY` | optional | For weekly email digest |
| `FROM_EMAIL` | optional | Sender email address |
| `TO_EMAIL` | optional | Your email for digests |
| `LANGFUSE_PUBLIC_KEY` | optional | LLM observability |
| `LANGFUSE_SECRET_KEY` | optional | LLM observability |

### 5. Run locally

```bash
cd backend
python main.py
# API at http://localhost:8000
# Docs at http://localhost:8000/docs
```

### 6. Deploy to Render

1. Push to GitHub
2. Connect Render to this repo, set root to `backend/`
3. Set all env vars in the Render dashboard
4. Build command: `pip install -r requirements.txt`
5. Start command: `python main.py`

---

## Flutter App Setup

### Prerequisites

- Flutter SDK ≥ 3.22
- Android Studio / VS Code with Flutter extension
- JDK 17
- `google-services.json` in `flutter_app/android/app/`

### Run

```bash
cd flutter_app
flutter pub get
flutter run
```

### Configure API URL

On first launch → Chat tab → Settings (top-right) → enter your backend URL:

- Local emulator: `http://10.0.2.2:8000`
- Render: `https://your-service.onrender.com`

### Build APK

```bash
flutter build apk --release
# → flutter_app/build/app/outputs/flutter-apk/app-release.apk
```

---

## How it works

| When | What happens |
|---|---|
| Daily 7am IST | Backend scrapes 15+ seed DPDP URLs + Brave Search for new content |
| Daily 8am IST | Claude enriches new content (summary, difficulty, tags) + push notification for today's item |
| Sunday 9am IST | Claude generates a 7-day learning plan → push notification + email digest |
| Anytime | Paste any URL in Chat → agent saves and slots it into your plan |

## App tabs

| Tab | Description |
|---|---|
| **Chat** | Ask LexBot anything about DPDP. Paste a URL to save it. Quick chips for common queries. |
| **Plan** | Mon–Sun learning plan. Today's day auto-expanded. Tap any item to open URL. |
| **Library** | All scraped + saved content. 2-column grid, filter by type, live search. |
| **Reminders** | Items with remind_at set, grouped: Overdue / Today / This Week / Later. |

---

## DPDP Seed Sources

The agent monitors these sources daily:

- MeitY — official regulatory page
- Mondaq India — Data Protection section
- AMS Shardul — law firm insights
- DLA Piper Data Protection tracker
- DPDPA.com — Adv. Dr. Prashant Mali
- Ex Machina — podcast + blog
- Internet Freedom Foundation
- SFLC India
- EY India — Gateway to Data Privacy podcast
- iPleaders Blog
- IAPP India resources
