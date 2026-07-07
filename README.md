# LexBot — DPDP Personal Learning Agent

A smart AI agent that scrapes DPDP (Digital Personal Data Protection Act 2023) learning resources daily, builds a personalised Mon–Sun weekly plan, and delivers it via a Flutter Android app with push notifications and weekly email digests.

---

## Architecture

```
Flutter App (Android)
    │  chat / paste URLs
    ▼
FastAPI Backend  (Python 3.11)
    ├─ feedparser + trafilatura  → scrape DPDP RSS feeds + seed URLs daily
    ├─ gpt-4o-mini               → classify, enrich, score relevance
    ├─ gpt-4o                    → RAG chat, weekly plan, weekly digest
    ├─ text-embedding-3-small    → vector embeddings (1536-dim)
    ├─ APScheduler               → daily scrape (7am IST) + reminder check (every 15min) + weekly digest (Sun 9am IST)
    ├─ firebase-admin            → FCM push notifications (Android)
    └─ Resend API                → weekly email digest
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

### 3. Firebase (FCM push notifications)

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add Android app → package name `com.certinal.lexbot` → download `google-services.json`
3. Place `google-services.json` in `flutter_app/android/app/`
4. Project Settings → Service Accounts → **Generate new private key** → download JSON
5. Paste the entire JSON as a single line into `FIREBASE_CREDENTIALS_JSON` in `.env`

### 4. Environment variables

```bash
cp .env.example .env
# Fill in all values
```

| Variable | Required | Description |
|---|---|---|
| `OPENAI_API_KEY` | ✅ | OpenAI key — used for GPT-4o (chat/plan/digest) + GPT-4o-mini (classify) + embeddings |
| `SUPABASE_URL` | ✅ | Supabase project URL |
| `SUPABASE_KEY` | ✅ | Supabase service role key |
| `FIREBASE_CREDENTIALS_JSON` | ✅ | Firebase service account JSON (single line) |
| `RESEND_API_KEY` | ✅ | Resend API key for weekly digest email |
| `RESEND_FROM` | ✅ | Sender address e.g. `LexBot <onboarding@resend.dev>` |
| `DIGEST_EMAIL_RECIPIENTS` | ✅ | Comma-separated recipient emails |
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

1. Push code to GitHub
2. New Web Service → connect repo → set **Root Directory** to `backend`
3. Build command: `pip install -r requirements.txt`
4. Start command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
5. Add all env vars in Render dashboard → **Environment** tab
6. After deploy, update `_defaultUrl` in `flutter_app/lib/services/api_service.dart` to your Render URL

---

## Flutter App Setup

### Prerequisites

- Flutter SDK ≥ 3.22
- Android Studio / VS Code with Flutter extension
- JDK 17
- `google-services.json` in `flutter_app/android/app/`

### Configure Firebase for Flutter

```bash
cd flutter_app
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
```

This generates `lib/firebase_options.dart`.

### Run

```bash
cd flutter_app
flutter pub get
flutter run
```

### Build APK

```bash
flutter build apk --release
# → flutter_app/build/app/outputs/flutter-apk/app-release.apk
```

---

## How it works

| When | What happens |
|---|---|
| Daily 7am IST | Scrapes 6 DPDP RSS feeds + seed URLs, filters by relevance (GPT-4o-mini score ≥ 6), embeds and stores new content |
| Every 15 min | Checks for due reminders → sends FCM push notification |
| Sunday 9am IST | GPT-4o generates a 7-day learning plan + weekly email digest via Resend |
| Anytime | Paste any URL in Chat → agent extracts, classifies, embeds and saves it |

---

## App Tabs

| Tab | Description |
|---|---|
| **Chat** | Ask LexBot anything about DPDP Act 2023. Paste a URL to save it instantly. Intent-aware RAG: learn / browse / plan / review modes. |
| **Plan** | Mon–Sun learning plan. Today auto-expanded. Tap any item to open. Sunday shows a reflection card. |
| **Library** | All saved content. Filter by type (article / video / podcast). Infinite scroll. Tap for full detail. |
| **Reminders** | Items with reminders set, grouped: Overdue / Today / This Week / Later. |

---

## DPDP Content Sources

The agent monitors these sources daily:

| Source | Type |
|---|---|
| Mondaq India — Data Protection | Legal analysis |
| Internet Freedom Foundation | Civil society |
| SFLC India | Civil society |
| iPleaders Blog | Education |
| Ex Machina | Practitioner / Podcast |
| DPDPA.com | Education |
| AMS Shardul | Legal analysis |
| DLA Piper Data Protection tracker | Legal analysis |
| IAPP India resources | Professional |
| EY India — Gateway to Data Privacy podcast | Podcast |
