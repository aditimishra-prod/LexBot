"""
Weekly discovery of new DPDP content via Brave Search API.
"""
import os
import httpx
from typing import list as List

BRAVE_API_KEY = os.getenv("BRAVE_API_KEY", "")
BRAVE_SEARCH_URL = "https://api.search.brave.com/res/v1/web/search"


async def discover_new_urls(queries: List[str], max_per_query: int = 5) -> List[str]:
    """Run Brave search queries and return unique new URLs."""
    if not BRAVE_API_KEY:
        print("[discovery] BRAVE_API_KEY not set, skipping discovery")
        return []

    found: set[str] = set()
    async with httpx.AsyncClient(timeout=15) as client:
        for query in queries:
            try:
                resp = await client.get(
                    BRAVE_SEARCH_URL,
                    headers={
                        "Accept": "application/json",
                        "Accept-Encoding": "gzip",
                        "X-Subscription-Token": BRAVE_API_KEY,
                    },
                    params={"q": query, "count": max_per_query, "freshness": "pd"},
                )
                resp.raise_for_status()
                data = resp.json()
                for result in data.get("web", {}).get("results", []):
                    url = result.get("url", "")
                    if url:
                        found.add(url)
            except Exception as exc:
                print(f"[discovery] search failed for '{query}': {exc}")

    return list(found)
