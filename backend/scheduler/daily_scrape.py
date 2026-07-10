"""
Daily DPDP content pipeline.
Fetches DPDP-specific RSS feeds, filters by relevance, and ingests to Supabase.
Pipeline: fetch RSS + seed URLs → dedup → GPT-4o-mini relevance filter → ingest → push notification.

Triggered by: GET /fetch-content  (external cron at 7 AM IST daily)
"""
from __future__ import annotations

import logging
import os
from datetime import datetime, timezone, timedelta

import feedparser

from services.langfuse_compat import observe

logger = logging.getLogger(__name__)


# ── DPDP-specific RSS feeds ───────────────────────────────────────────────────
DPDP_RSS_FEEDS = [
    {
        "url":      "https://www.mondaq.com/rss/india/data-protection",
        "source":   "Mondaq India",
        "category": "legal-analysis",
    },
    {
        "url":      "https://internetfreedom.in/rss/",
        "source":   "Internet Freedom Foundation",
        "category": "civil-society",
    },
    {
        "url":      "https://sflc.in/feed/",
        "source":   "SFLC India",
        "category": "civil-society",
    },
    {
        "url":      "https://blog.ipleaders.in/feed/",
        "source":   "iPleaders",
        "category": "education",
    },
    {
        "url":      "https://exmachina.in/feed/",
        "source":   "Ex Machina",
        "category": "practitioner",
    },
    {
        "url":      "https://www.dpdpa.com/rss.xml",
        "source":   "DPDPA.com",
        "category": "education",
    },
    # YouTube channels — RSS feeds for DPDP video content
    {
        "url":      "https://www.youtube.com/feeds/videos.xml?channel_id=UCmLGJ3VYBcfRaWbP6JLo_Zg",
        "source":   "IAPP YouTube",
        "category": "video",
    },
    {
        "url":      "https://www.youtube.com/feeds/videos.xml?channel_id=UCSpVHeDGr9UbHJSoMdTYqZQ",
        "source":   "MeitY YouTube",
        "category": "video",
    },
    {
        "url":      "https://www.youtube.com/feeds/videos.xml?channel_id=UCFHhBsGtXGFbfLBJnU6Fxwg",
        "source":   "NASSCOM YouTube",
        "category": "video",
    },
]

# Seed URLs checked daily even if no RSS feed exists
SEED_URLS = [
    {"url": "https://www.amsshardul.com/insights/?category=data-protection", "source": "AMS Shardul", "category": "legal-analysis"},
    {"url": "https://www.dlapiperdataprotection.com/?t=law&c=IN",           "source": "DLA Piper",   "category": "legal-analysis"},
    {"url": "https://iapp.org/resources/topics/india-2/",                   "source": "IAPP",        "category": "professional"},
    {"url": "https://www.smritiparsheera.com/research/privacy-surveillance", "source": "Parsheera",  "category": "research"},
    {"url": "https://www.ey.com/en_in/media/podcasts/gateway-to-data-privacy-and-protection", "source": "EY India", "category": "podcast"},
    # Curated YouTube video playlists
    {"url": "https://www.youtube.com/playlist?list=PLdo5W4Nhv31b2RoqaUl4EPWjaTtMXj9-G", "source": "DPDP Explainers", "category": "video"},
]

RELEVANCE_PROMPT = """\
You are a filter for a DPDP (Digital Personal Data Protection Act 2023) learning feed.

Score each item 1-10 for relevance to someone learning about India's DPDP Act 2023 who tracks:
- DPDP Act 2023 and DPDP Rules 2025 provisions
- Data Principal rights and Data Fiduciary obligations
- Data Protection Board developments
- Compliance timelines and enforcement
- Privacy law comparisons (GDPR vs DPDP)
- Legal practitioner analysis

Respond with ONLY a JSON array in this exact format:
[
  {{"index": 0, "score": 9, "category": "legal-analysis"}},
  {{"index": 1, "score": 3, "category": "education"}},
  ...
]

Categories must be one of: legal-analysis, compliance, research, education, civil-society, practitioner, policy, podcast

Items to score:
{items}
"""


def _get_supabase():
    from supabase import create_client
    return create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])


def _get_openai():
    from openai import OpenAI
    return OpenAI(api_key=os.environ["OPENAI_API_KEY"])


# ── Step 1: Fetch RSS items ───────────────────────────────────────────────────

def fetch_rss_items() -> list[dict]:
    """Fetch last 24h items from all DPDP RSS feeds."""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
    items = []

    for feed_cfg in DPDP_RSS_FEEDS:
        try:
            feed = feedparser.parse(feed_cfg["url"])
            for entry in feed.entries:
                published = None
                if hasattr(entry, "published_parsed") and entry.published_parsed:
                    import time
                    published = datetime.fromtimestamp(
                        time.mktime(entry.published_parsed), tz=timezone.utc
                    )

                if published and published < cutoff:
                    continue

                link = getattr(entry, "link", None)
                title = getattr(entry, "title", None)
                if not link or not title:
                    continue

                items.append({
                    "url":      link,
                    "title":    title,
                    "source":   feed_cfg["source"],
                    "category": feed_cfg["category"],
                })
        except Exception as e:
            logger.warning("RSS fetch failed for %s: %s", feed_cfg["source"], e)

    logger.info("Fetched %d raw RSS items", len(items))
    return items


# ── Step 2: Deduplicate ────────────────────────────────────────────────────────

def filter_already_saved(items: list[dict]) -> list[dict]:
    if not items:
        return []
    supabase = _get_supabase()
    urls = [i["url"] for i in items]
    result = supabase.table("items").select("url").in_("url", urls).execute()
    saved_urls = {r["url"] for r in (result.data or [])}
    fresh = [i for i in items if i["url"] not in saved_urls]
    logger.info("%d items after dedup (%d already saved)", len(fresh), len(saved_urls))
    return fresh


# ── Step 3: Relevance filter using GPT-4o-mini ───────────────────────────────

@observe(name="filter_by_relevance")
def filter_by_relevance(items: list[dict], min_score: int = 6) -> list[dict]:
    """Use GPT-4o-mini to score items for DPDP relevance."""
    if not items:
        return []

    import json
    formatted = "\n".join(
        f"{i}. [{item['source']}] {item['title']}"
        for i, item in enumerate(items)
    )

    try:
        client = _get_openai()
        resp = client.chat.completions.create(
            model="gpt-4o-mini",
            max_tokens=1000,
            messages=[{"role": "user", "content": RELEVANCE_PROMPT.format(items=formatted)}],
        )
        raw = resp.choices[0].message.content.strip()
        scores = json.loads(raw)

        for s in scores:
            idx = s["index"]
            if idx < len(items):
                items[idx]["relevance_score"] = s["score"]
                items[idx]["category"] = s.get("category", items[idx]["category"])

        filtered = [i for i in items if i.get("relevance_score", 0) >= min_score]
        logger.info("%d items passed relevance filter (score >= %d)", len(filtered), min_score)
        return filtered

    except Exception as e:
        logger.error("Relevance filter failed: %s", e)
        return items


# ── Step 4: Ingest ─────────────────────────────────────────────────────────────

def ingest_content_items(items: list[dict]) -> list[dict]:
    """Extract, enrich with GPT-4o-mini, embed, and store each item."""
    from scraper.extractor import extract_content
    from agent.enricher import enrich
    from ingest.embedder import store_item

    supabase = _get_supabase()
    ingested = []

    for item in items:
        try:
            extracted = extract_content(item["url"])
            if not extracted.get("text") or len(extracted["text"]) < 150:
                continue

            enriched = enrich(
                url=item["url"],
                title=extracted.get("title") or item.get("title"),
                text=extracted.get("text"),
            )
            if not enriched.get("is_dpdp_relevant", False):
                continue

            stored = store_item(
                url=item["url"],
                title=extracted.get("title") or item.get("title"),
                raw_text=extracted.get("text"),
                summary=enriched.get("summary", ""),
                content_type=enriched.get("content_type", "article"),
                difficulty=enriched.get("difficulty", "beginner"),
                tags=enriched.get("tags", []),
                source=item.get("source", extracted.get("source", "web")),
            )

            # Patch category metadata
            if stored.get("id"):
                supabase.table("items").update({
                    "news_category": item.get("category"),
                }).eq("id", stored["id"]).execute()

            ingested.append({**item, "summary": enriched.get("summary", "")})
            logger.info("Ingested: %s", (item.get("title") or item["url"])[:80])

        except Exception as e:
            logger.warning("Ingest failed for %s: %s", item["url"], e)

    logger.info("Successfully ingested %d DPDP items", len(ingested))
    return ingested


# ── Step 5: Send daily push ────────────────────────────────────────────────────

def send_content_digest(items: list[dict]):
    if not items:
        return
    try:
        from notifications.fcm import send_to_all_devices
        total = len(items)
        title = f"📚 {total} new DPDP resource{'s' if total > 1 else ''} added to your library"
        body  = items[0].get("title", "Open LexBot to explore today's content")[:120]
        send_to_all_devices(title=title, body=body, item_id=None)
        logger.info("Daily content digest push sent: %d items", total)
    except Exception as e:
        logger.error("Content digest push failed: %s", e)


# ── Main entry point ───────────────────────────────────────────────────────────

def run_daily_scrape() -> dict:
    logger.info("=== LexBot Daily DPDP Scrape starting ===")

    raw = fetch_rss_items()
    # Also add seed URLs as items to check
    raw += [{"url": s["url"], "title": s["source"], "source": s["source"], "category": s["category"]}
            for s in SEED_URLS]

    if not raw:
        return {"status": "ok", "fetched": 0, "ingested": 0}

    fresh = filter_already_saved(raw)
    if not fresh:
        logger.info("All items already saved.")
        return {"status": "ok", "fetched": len(raw), "ingested": 0}

    relevant = filter_by_relevance(fresh, min_score=6)
    if not relevant:
        return {"status": "ok", "fetched": len(raw), "ingested": 0}

    ingested = ingest_content_items(relevant)
    send_content_digest(ingested)

    logger.info("=== Daily scrape done: %d ingested ===", len(ingested))
    return {
        "status":   "ok",
        "fetched":  len(raw),
        "relevant": len(relevant),
        "ingested": len(ingested),
    }
