"""
Embedder — generates text-embedding-3-small vectors and stores items in Supabase.
Repurposed from Cura's ingest/embedder.py — keeps raw_text for future retrieval.
"""
import os
from services.langfuse_compat import OpenAI, observe
from supabase import create_client, Client

_openai_instance = None


def _openai():
    global _openai_instance
    if _openai_instance is None:
        _openai_instance = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
    return _openai_instance


def get_supabase() -> Client:
    return create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])


@observe(name="embed")
def embed_text(text: str) -> list[float]:
    response = _openai().embeddings.create(
        model="text-embedding-3-small",
        input=text[:8000],
    )
    return response.data[0].embedding


def store_item(
    url: str,
    title: str | None,
    raw_text: str | None,
    summary: str,
    content_type: str,
    difficulty: str,
    tags: list[str],
    source: str,
) -> dict:
    embed_input = f"{title or ''} {summary} {' '.join(tags)}"
    embedding = embed_text(embed_input)

    supabase = get_supabase()
    result = supabase.table("items").upsert({
        "url": url,
        "title": title,
        "raw_text": raw_text,
        "summary": summary,
        "content_type": content_type,
        "difficulty": difficulty,
        "tags": tags,
        "source": source,
        "embedding": embedding,
    }, on_conflict="url").execute()

    return result.data[0] if result.data else {}
