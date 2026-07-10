"""
OpenAI-powered weekly learning plan generator.
Fetches unread items from Supabase and builds a Mon-Sun plan.
"""
import os
import json
from openai import AsyncOpenAI
from db.client import supabase

client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))

PLAN_SYSTEM = """You are a DPDP (Digital Personal Data Protection Act 2023) learning coach.

Given a list of available learning resources (articles, podcasts, videos) with their titles, summaries, types and difficulty levels, create a structured 7-day weekly learning plan.

Rules:
- Each day should have 1-2 items max (don't overwhelm the learner)
- Start the week with beginner/foundational content, progress to intermediate and advanced by end of week
- Mix content types across days (don't put two podcasts on the same day)
- Monday: foundational concept
- Tuesday: statutory deep-dive
- Wednesday: podcast or video (lighter)
- Thursday: practitioner/compliance angle
- Friday: recent news or regulatory update
- Saturday: advanced / critical analysis
- Sunday: reflection — summarise the week's themes in 3 bullet points (no new content)

Return ONLY valid JSON in this exact shape:
{
  "week_theme": "one-line theme for the week",
  "days": {
    "mon": [{"item_id": "uuid", "title": "...", "content_type": "...", "url": "...", "why": "one sentence on why this is today's pick"}],
    "tue": [...],
    "wed": [...],
    "thu": [...],
    "fri": [...],
    "sat": [...],
    "sun": {"reflection": "3-bullet summary of the week"}
  }
}
"""


async def generate_weekly_plan(week_start: str) -> dict:
    """Generate a 7-day plan from unread items in DB."""
    result = (
        supabase.table("items")
        .select("id, url, title, summary, content_type, difficulty, tags")
        .eq("is_read", False)
        .order("created_at", desc=False)
        .limit(30)
        .execute()
    )
    items = result.data

    if not items:
        return {"error": "No unread items available to build a plan"}

    items_text = json.dumps(items, indent=2)
    prompt = (
        f"Week starting: {week_start}\n\n"
        f"Available resources:\n{items_text}"
    )

    msg = await client.chat.completions.create(
        model="gpt-4o",
        max_tokens=2048,
        messages=[
            {"role": "system", "content": PLAN_SYSTEM},
            {"role": "user", "content": prompt},
        ],
    )

    raw = msg.choices[0].message.content.strip()
    # Strip markdown fences if GPT wraps response in ```json ... ```
    if raw.startswith("```"):
        raw = raw.split("```", 2)[1]
        if raw.startswith("json"):
            raw = raw[4:]
        raw = raw.rsplit("```", 1)[0].strip()
    try:
        plan = json.loads(raw)
    except Exception:
        plan = {"error": "Failed to parse plan", "raw": raw}

    # Persist to DB
    supabase.table("plans").upsert(
        {"week_start": week_start, "plan_json": plan}, on_conflict="week_start"
    ).execute()

    return plan


async def chat_with_agent(messages: list[dict], history: list[dict]) -> str:
    """Answer a user question using RAG over saved items."""
    from ingest.embedder import embed_text

    user_query = messages[-1]["content"]
    embedding = embed_text(user_query)  # sync function

    # Vector similarity search
    hits = supabase.rpc(
        "match_items",
        {"query_embedding": embedding, "match_threshold": 0.4, "match_count": 6},
    ).execute()

    context = ""
    if hits.data:
        context = "Relevant resources from your library:\n" + "\n".join(
            f"- [{h['title']}]({h['url']}): {h['summary']}" for h in hits.data
        )

    system = (
        "You are LexBot, a personal DPDP Act 2023 learning assistant. "
        "Help the user understand India's Digital Personal Data Protection Act and Rules 2025. "
        "Be concise, cite specific sections when relevant, and suggest resources from the library when available.\n\n"
        + context
    )

    all_messages = [{"role": "system", "content": system}] + history[-6:] + messages
    msg = await client.chat.completions.create(
        model="gpt-4o",
        max_tokens=1024,
        messages=all_messages,
    )
    return msg.choices[0].message.content
