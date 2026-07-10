from __future__ import annotations

import re
import os
from datetime import timezone, timedelta
from typing import Optional

IST = timezone(timedelta(hours=5, minutes=30))
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
import logging

logger = logging.getLogger(__name__)
router = APIRouter()

URL_RE = re.compile(r"https?://\S+")
BARE_DOMAIN_RE = re.compile(
    r'(?<![/\w])'
    r'((?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)'
    r'+(?:com|org|net|io|in|ai|co|dev|app|gov|edu|me|tech))'
    r'(?:/\S*)?'
    r'(?!\w)',
    re.IGNORECASE,
)


# ── Models ────────────────────────────────────────────────────────────────────

class MessageRequest(BaseModel):
    message: str
    history: list[dict] = []
    user_email: Optional[str] = None


class IngestRequest(BaseModel):
    url: str
    user_note: Optional[str] = None


class UpdateItemRequest(BaseModel):
    user_note: Optional[str] = None
    remind_at: Optional[str] = None
    is_read: Optional[bool] = None


class DeviceRequest(BaseModel):
    fcm_token: str
    user_email: Optional[str] = None


# ── Helpers ───────────────────────────────────────────────────────────────────

def _get_supabase():
    from supabase import create_client
    return create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])


# ── Chat / message ────────────────────────────────────────────────────────────

@router.post("/message")
async def message(req: MessageRequest):
    from scraper.extractor import extract_content
    from agent.enricher import enrich
    from ingest.embedder import store_item
    from ingest.reminder_parser import parse_reminder, strip_reminder
    from agent.retrieval import rag_query, detect_mode

    text = req.message.strip()

    # Detect URL
    explicit_urls = URL_RE.findall(text)
    if explicit_urls:
        url = explicit_urls[0]
        surrounding = URL_RE.sub("", text, count=1).strip()
    else:
        bare = BARE_DOMAIN_RE.search(text)
        if bare:
            url = "https://" + bare.group(0)
            surrounding = BARE_DOMAIN_RE.sub("", text, count=1).strip()
        else:
            url = None
            surrounding = None

    if url:
        note = surrounding if surrounding and len(surrounding) >= 5 else None

        try:
            extracted = extract_content(url)
            # Accept minimal text (some paywalled sites return just a few lines)
            if not extracted.get("text") or len(extracted.get("text", "")) < 40:
                # Last-resort: use URL + title as synthetic text for GPT enrichment
                title_guess = extracted.get("title") or url
                extracted["text"] = f"Title: {title_guess}\nURL: {url}"
                if len(extracted["text"]) < 40:
                    raise ValueError("Could not extract content")

            enriched = enrich(url, extracted.get("title"), extracted.get("text"))
            stored = store_item(
                url=url,
                title=extracted.get("title"),
                raw_text=extracted.get("text"),
                summary=enriched.get("summary", ""),
                content_type=enriched.get("content_type", "article"),
                difficulty=enriched.get("difficulty", "beginner"),
                tags=enriched.get("tags", []),
                source=extracted.get("source", "web"),
            )
        except Exception as e:
            logger.error("Ingestion failed for %s: %s", url, e)
            raise HTTPException(status_code=422, detail=f"Could not extract content: {str(e)}")

        # Handle reminder in note
        remind_at = parse_reminder(note) if note else None
        clean_note = strip_reminder(note) if (note and remind_at) else note

        response_parts = [
            f"✅ **Saved!**\n\n**Summary:** {enriched.get('summary', '')}\n\n"
            f"**Type:** {enriched.get('content_type', '')}  |  "
            f"**Level:** {enriched.get('difficulty', '')}  |  "
            f"**Tags:** {', '.join(enriched.get('tags', []))}"
        ]

        if remind_at and stored.get("id"):
            supabase = _get_supabase()
            supabase.table("items").update({
                "remind_at": remind_at.isoformat(),
                "user_note": clean_note,
            }).eq("id", stored["id"]).execute()
            ist_time = remind_at.astimezone(IST)
            response_parts.append(
                f"\n\n⏰ **Reminder set for {ist_time.strftime('%A, %b %d at %I:%M %p IST')}**"
            )
        elif clean_note:
            response_parts.append(f"\n\n📝 **Note:** \"{clean_note}\"")

        return {
            "response": "".join(response_parts),
            "mode": "ingest",
            "content_type": enriched.get("content_type"),
            "tags": enriched.get("tags", []),
        }

    # ── Reminder-only message (no URL) → apply to most recent saved item ────────
    try:
        remind_at = parse_reminder(text)
    except Exception:
        remind_at = None

    if remind_at:
        try:
            supabase = _get_supabase()
            # Find the most recently saved item
            result = (
                supabase.table("items")
                .select("id, title, url")
                .order("created_at", desc=True)
                .limit(1)
                .execute()
            )
            if result.data:
                item = result.data[0]
                supabase.table("items").update({
                    "remind_at":     remind_at.isoformat(),
                    "reminder_sent": False,
                }).eq("id", item["id"]).execute()

                from urllib.parse import urlparse
                ist_time   = remind_at.astimezone(IST)
                item_title = item.get("title") or (
                    urlparse(item["url"]).netloc.replace("www.", "")
                    if item.get("url") else "your last saved item"
                )
                return {
                    "response": (
                        f"⏰ **Reminder set!**\n\n"
                        f"I'll remind you about **{item_title}** "
                        f"on **{ist_time.strftime('%A, %b %d at %I:%M %p IST')}**.\n\n"
                        f"You'll see it in the Reminders tab."
                    ),
                    "mode": "reminder",
                }
        except Exception as e:
            logger.error("Follow-up reminder failed: %s", e)
            # Fall through to RAG if reminder setting fails

    # Pure text query → RAG
    try:
        mode = detect_mode(text)
        response = rag_query(text, history=req.history)
        return {"response": response, "mode": mode}
    except Exception as e:
        logger.error("RAG query failed: %s", e)
        raise HTTPException(status_code=500, detail=str(e))


# ── Ingest ────────────────────────────────────────────────────────────────────

@router.post("/ingest")
async def ingest(req: IngestRequest):
    from scraper.extractor import extract_content
    from agent.enricher import enrich
    from ingest.embedder import store_item

    extracted = extract_content(req.url)
    if not extracted.get("text"):
        raise HTTPException(status_code=422, detail="Could not extract content from URL")

    enriched = enrich(req.url, extracted.get("title"), extracted.get("text"))
    stored = store_item(
        url=req.url,
        title=extracted.get("title"),
        raw_text=extracted.get("text"),
        summary=enriched.get("summary", ""),
        content_type=enriched.get("content_type", "article"),
        difficulty=enriched.get("difficulty", "beginner"),
        tags=enriched.get("tags", []),
        source=extracted.get("source", "web"),
    )
    if req.user_note:
        _get_supabase().table("items").update(
            {"user_note": req.user_note}
        ).eq("id", stored.get("id", "")).execute()

    return {"id": stored.get("id"), **enriched}


# ── Library ───────────────────────────────────────────────────────────────────

@router.get("/items")
async def list_items(
    limit:        int           = Query(default=20, ge=1, le=100),
    offset:       int           = Query(default=0, ge=0),
    content_type: Optional[str] = None,
    difficulty:   Optional[str] = None,
):
    supabase = _get_supabase()
    q = supabase.table("items").select(
        "id, url, title, summary, content_type, difficulty, source, tags, is_read, remind_at, user_note, created_at"
    )
    if content_type:
        q = q.eq("content_type", content_type)
    if difficulty:
        q = q.eq("difficulty", difficulty)
    result = q.order("created_at", desc=True).range(offset, offset + limit - 1).execute()
    items = result.data or []
    return {"items": items, "offset": offset, "limit": limit, "count": len(items)}


@router.get("/items/{item_id}")
async def get_item(item_id: str):
    supabase = _get_supabase()
    result = supabase.table("items").select("*").eq("id", item_id).limit(1).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Item not found")
    return result.data[0]


@router.patch("/items/{item_id}")
async def update_item(item_id: str, req: UpdateItemRequest):
    updates: dict = {}
    if req.user_note is not None:
        updates["user_note"] = req.user_note
    if req.remind_at is not None:
        updates["remind_at"] = req.remind_at
        updates["reminder_sent"] = False
    if req.is_read is not None:
        updates["is_read"] = req.is_read
    if not updates:
        raise HTTPException(status_code=400, detail="Nothing to update")
    supabase = _get_supabase()
    result = supabase.table("items").update(updates).eq("id", item_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Item not found")
    return result.data[0]


# ── Plan ──────────────────────────────────────────────────────────────────────

@router.get("/plan/current")
async def get_current_plan():
    from datetime import date
    today = str(date.today())
    supabase = _get_supabase()
    result = (
        supabase.table("plans")
        .select("*")
        .lte("week_start", today)
        .order("week_start", desc=True)
        .limit(1)
        .execute()
    )
    if not result.data:
        return {"message": "No plan yet. Generating one now…"}
    return result.data[0]


@router.post("/plan/generate")
async def trigger_plan():
    from datetime import date
    from agent.planner import generate_weekly_plan
    plan = await generate_weekly_plan(str(date.today()))
    return plan


class UpdatePlanRequest(BaseModel):
    plan_json: dict


@router.patch("/plan/current")
async def update_current_plan(req: UpdatePlanRequest):
    """Save edited plan_json back to the latest plan row."""
    from datetime import date
    today = str(date.today())
    supabase = _get_supabase()
    result = (
        supabase.table("plans")
        .select("id")
        .lte("week_start", today)
        .order("week_start", desc=True)
        .limit(1)
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=404, detail="No plan found")
    plan_id = result.data[0]["id"]
    updated = (
        supabase.table("plans")
        .update({"plan_json": req.plan_json})
        .eq("id", plan_id)
        .execute()
    )
    return updated.data[0] if updated.data else {"status": "ok"}


# ── Reminders ─────────────────────────────────────────────────────────────────

@router.get("/reminders")
async def reminders():
    supabase = _get_supabase()
    result = (
        supabase.table("items")
        .select("id, url, title, summary, content_type, remind_at, reminder_sent, user_note")
        .not_.is_("remind_at", "null")
        .order("remind_at", desc=False)
        .execute()
    )
    return {"reminders": result.data or []}


# ── Digest ────────────────────────────────────────────────────────────────────

@router.get("/digest")
async def digest():
    from scheduler.digest import get_pending_digest, clear_pending_digest
    data = get_pending_digest()
    if not data:
        return {"available": False}
    clear_pending_digest()
    return {"available": True, **data}


# ── Status ────────────────────────────────────────────────────────────────────

@router.get("/status")
async def status():
    supabase = _get_supabase()
    result = supabase.table("items").select("content_type").execute()
    items = result.data or []
    counts: dict[str, int] = {}
    for item in items:
        ct = item.get("content_type", "unknown")
        counts[ct] = counts.get(ct, 0) + 1
    return {"total": len(items), "by_type": counts}


# ── Device registration ───────────────────────────────────────────────────────

@router.post("/register-device")
async def register_device(req: DeviceRequest):
    supabase = _get_supabase()
    row = {"fcm_token": req.fcm_token}
    if req.user_email:
        row["user_email"] = req.user_email
    supabase.table("devices").upsert(row, on_conflict="fcm_token").execute()
    return {"status": "registered"}


# ── Daily content fetch (external cron trigger) ───────────────────────────────

@router.get("/fetch-content")
async def trigger_fetch():
    try:
        from scheduler.daily_scrape import run_daily_scrape
        result = run_daily_scrape()
        return result
    except Exception as e:
        logger.error("Daily scrape failed: %s", e)
        return {"status": "error", "detail": str(e)}


@router.get("/check-reminders")
async def trigger_reminder_check():
    try:
        from scheduler.digest import check_reminders
        check_reminders()
        return {"status": "ok"}
    except Exception as e:
        return {"status": "error", "detail": str(e)}
