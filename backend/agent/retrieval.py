"""
Intent-aware RAG for LexBot — adapted from Cura's retrieval/chain.py.
Uses OpenAI gpt-4o for RAG. DPDP-tuned prompts.
"""
import os
from openai import OpenAI
from services.langfuse_compat import observe
from ingest.embedder import embed_text, get_supabase

_client = None


def _get_client():
    global _client
    if _client is None:
        _client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
    return _client


def detect_mode(query: str) -> str:
    q = query.lower()
    if any(p in q for p in ["all my saves", "show all", "list all", "everything saved", "all items"]):
        return "list_all"
    if any(w in q for w in ["teach me", "explain", "what is", "how does", "learn about"]):
        return "learn"
    if any(w in q for w in ["today's", "today", "plan", "this week", "what should i"]):
        return "plan"
    if any(w in q for w in ["haven't read", "unread", "not read yet", "review"]):
        return "review"
    return "browse"


@observe(name="embed_query")
def embed_query(query: str) -> list[float]:
    return embed_text(query)


def search_items(query_embedding: list[float], threshold: float = 0.4, count: int = 8) -> list[dict]:
    supabase = get_supabase()
    result = supabase.rpc("match_items", {
        "query_embedding": query_embedding,
        "match_threshold": threshold,
        "match_count": count,
    }).execute()
    return result.data or []


def get_unread_items(count: int = 5) -> list[dict]:
    supabase = get_supabase()
    result = (
        supabase.table("items")
        .select("id, url, title, summary, content_type, difficulty, tags, created_at")
        .eq("is_read", False)
        .order("created_at", desc=False)
        .limit(count)
        .execute()
    )
    return result.data or []


def get_all_items(limit: int = 50) -> list[dict]:
    supabase = get_supabase()
    result = (
        supabase.table("items")
        .select("id, url, title, summary, content_type, difficulty, tags, created_at")
        .order("created_at", desc=True)
        .limit(limit)
        .execute()
    )
    return result.data or []


def mark_read(item_ids: list[str]):
    from datetime import datetime, timezone
    supabase = get_supabase()
    supabase.table("items").update(
        {"is_read": True, "last_accessed": datetime.now(timezone.utc).isoformat()}
    ).in_("id", item_ids).execute()


def format_items(items: list[dict]) -> str:
    lines = []
    for i, item in enumerate(items, 1):
        title = item.get("title") or item.get("url", "")
        summary = item.get("summary", "")
        ctype = item.get("content_type", "")
        diff = item.get("difficulty", "")
        tags = ", ".join(item.get("tags") or [])
        lines.append(f"{i}. **{title}**\n   {summary}\n   type: {ctype} | level: {diff} | tags: {tags}")
    return "\n\n".join(lines)


BROWSE_PROMPT = """You are LexBot, a DPDP Act 2023 learning assistant. The user is searching their saved content.
Here are the relevant saved items:

{items}

Respond with a concise list. For each item: title/URL, one-line summary, and difficulty level.
Always offer to explain any item in more depth."""

LEARN_PROMPT = """You are LexBot, a DPDP Act 2023 expert. The user wants to learn about: "{query}"
Here are relevant saved resources from their library:

{items}

Synthesise these into a structured explanation with:
1. Core concept (plain English, cite specific DPDP Act sections where relevant)
2. Key insights (drawn from the saved content)
3. What to explore next

Be concise, practical, and cite section numbers (e.g. Section 8, Chapter III)."""

REVIEW_PROMPT = """You are LexBot. The user wants to review unread DPDP content.
Here are items they saved but haven't read yet (oldest first):

{items}

Present each as:
• [Title or URL] — summary [type: X | level: Y]

End with: "Reply with a number to go deeper on any of these." """

PLAN_PROMPT = """You are LexBot. The user is asking about their DPDP learning plan.
Here is today's context:

{items}

Help them understand what they should focus on today, referencing today's plan items if available."""


@observe(name="rag_query")
def rag_query(user_message: str, history: list[dict] | None = None) -> str:
    mode = detect_mode(user_message)
    history_ctx = (history or [])[-6:]

    if mode == "list_all":
        items = get_all_items(50)
        if not items:
            return "You haven't saved anything yet! I'll scrape DPDP content and build your library automatically."
        lines = [f"Here are all **{len(items)}** items in your DPDP library:\n"]
        for i, item in enumerate(items, 1):
            title = item.get("title") or item.get("url", "")
            summary = (item.get("summary", "") or "")[:80]
            ctype = item.get("content_type", "")
            lines.append(f"{i}. **{title}**\n   {summary}…\n   _{ctype}_\n")
        return "\n".join(lines)

    if mode == "review":
        items = get_unread_items(5)
        if not items:
            return "You're all caught up — no unread saves!"
        mark_read([item["id"] for item in items])
        formatted = format_items(items)
        messages = (
            history_ctx
            + [{"role": "user", "content": user_message}]
        )
        messages_with_system = [
            {"role": "system", "content": REVIEW_PROMPT.format(items=formatted)},
            *messages,
        ]
        resp = _get_client().chat.completions.create(
            model="gpt-4o",
            max_tokens=800,
            messages=messages_with_system,
        )
        return resp.choices[0].message.content

    embedding = embed_query(user_message)
    items = search_items(embedding, threshold=0.4, count=8)

    if not items:
        items = search_items(embedding, threshold=0.2, count=5)

    if not items:
        return (
            "I couldn't find anything relevant in your library yet. "
            "The daily scraper runs at 7am IST and will populate your DPDP library. "
            "You can also paste any URL here and I'll save it immediately."
        )

    mark_read([item["id"] for item in items])
    formatted = format_items(items)

    if mode == "learn":
        system = LEARN_PROMPT.format(query=user_message, items=formatted)
    elif mode == "plan":
        system = PLAN_PROMPT.format(items=formatted)
    else:
        system = BROWSE_PROMPT.format(items=formatted)

    resp = _get_client().chat.completions.create(
        model="gpt-4o",
        max_tokens=1024,
        messages=[
            {"role": "system", "content": system},
            *history_ctx,
            {"role": "user", "content": user_message},
        ],
    )
    return resp.choices[0].message.content
