"""
Weekly digest + reminder checker — adapted from Cura's scheduler/digest.py.
OpenAI gpt-4o generates the weekly digest.
"""
import logging
import os
from datetime import datetime, timezone, timedelta

from apscheduler.schedulers.background import BackgroundScheduler
from services.langfuse_compat import observe
from supabase import create_client

logger = logging.getLogger(__name__)

_openai_client = None

def _get_client():
    global _openai_client
    if _openai_client is None:
        from openai import OpenAI
        _openai_client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
    return _openai_client


_pending_digest: list[dict] = []

DIGEST_PROMPT = """You are LexBot, a DPDP learning assistant sending a weekly digest.
Here are 3 DPDP resources the user saved but hasn't read yet:

{items}

Write a short, friendly digest message (max 200 words) that:
1. Surfaces these items with their key insight about India's DPDP Act
2. Reminds the user why each might be worth reading this week
3. Notes the difficulty level for each
4. Ends with "Tap any item to go deeper."

Be warm and encouraging, not robotic."""


def get_digest_items() -> list[dict]:
    supabase = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])
    cutoff = (datetime.now(timezone.utc) - timedelta(days=7)).isoformat()
    result = (
        supabase.table("items")
        .select("id, url, title, summary, content_type, difficulty, created_at")
        .eq("is_read", False)
        .lt("created_at", cutoff)
        .order("created_at", desc=False)
        .limit(3)
        .execute()
    )
    return result.data or []


@observe(name="digest")
def generate_digest():
    global _pending_digest
    items = get_digest_items()
    if not items:
        logger.info("No unread items for digest, skipping.")
        return

    formatted = "\n\n".join(
        f"{i+1}. {item.get('title') or item['url']} [{item.get('content_type', '')} · {item.get('difficulty', '')}]\n   {item.get('summary', '')}"
        for i, item in enumerate(items)
    )

    resp = _get_client().chat.completions.create(
        model="gpt-4o",
        max_tokens=400,
        messages=[
            {"role": "user", "content": DIGEST_PROMPT.format(items=formatted)},
        ],
    )
    message = resp.choices[0].message.content
    _pending_digest = [{"message": message, "items": items, "created_at": datetime.now(timezone.utc).isoformat()}]
    logger.info("Weekly digest generated with %d items.", len(items))

    try:
        from scheduler.email_templates import weekly_briefing_email
        from services.email_service import send_email
        subject, html = weekly_briefing_email(message, items)
        if subject and html:
            send_email(subject, html)
    except Exception as e:
        logger.error("Weekly briefing email failed: %s", e)


def get_pending_digest() -> dict | None:
    return _pending_digest[0] if _pending_digest else None


def clear_pending_digest():
    global _pending_digest
    _pending_digest = []


def check_reminders():
    """Fire push notifications for any due reminders."""
    try:
        from notifications.fcm import send_to_all_devices
        supabase = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])
        now = datetime.now(timezone.utc).isoformat()

        result = (
            supabase.table("items")
            .select("id, title, url, summary")
            .lte("remind_at", now)
            .eq("reminder_sent", False)
            .not_.is_("remind_at", "null")
            .execute()
        )
        due = result.data or []

        for item in due:
            title = item.get("title") or item.get("url", "Saved content")
            note  = item.get("summary") or "Time to revisit this."
            send_to_all_devices(
                title=f"📌 Reminder: {title[:60]}",
                body=note[:120],
                item_id=item["id"],
            )
            supabase.table("items").update({"reminder_sent": True}).eq("id", item["id"]).execute()
            logger.info("Reminder sent for item %s", item["id"])

    except Exception as e:
        logger.error("Reminder check failed: %s", e)


def start_background_digest() -> BackgroundScheduler:
    scheduler = BackgroundScheduler()
    scheduler.add_job(generate_digest, "cron", day_of_week="sun", hour=9, minute=0, id="weekly_digest")
    scheduler.add_job(check_reminders, "interval", minutes=15, id="reminder_check")
    scheduler.start()
    logger.info("Schedulers started: weekly digest (Sun 9am IST) + reminder check (every 15min).")
    return scheduler
