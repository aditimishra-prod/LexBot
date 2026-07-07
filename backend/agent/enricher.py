"""
OpenAI-powered enrichment: summary, content_type, difficulty, tags.
Uses gpt-4o-mini (fast + cheap for classification).
"""
import json
import os
from openai import OpenAI
from services.langfuse_compat import observe

_client_instance = None


def _client():
    global _client_instance
    if _client_instance is None:
        _client_instance = OpenAI(api_key=os.environ["OPENAI_API_KEY"])
    return _client_instance


SYSTEM_PROMPT = """You are a legal content analyst specialising in India's Digital Personal Data Protection (DPDP) Act 2023 and DPDP Rules 2025.

Given a URL, title, and extracted text, return a JSON object with:
- summary: 2-sentence plain-English summary focused on what a DPDP learner gains
- content_type: one of [article, podcast, video, other]
- difficulty: one of [beginner, intermediate, advanced]
- tags: array of 5 specific DPDP topic tags (lowercase, no spaces)
- is_dpdp_relevant: true if the content is meaningfully about India's DPDP Act, data protection law, or related compliance topics; false otherwise

Examples:
- "DPDP Act Section 8 explained" → difficulty: beginner, content_type: article
- "DPDP Rules 2025 compliance checklist" → difficulty: intermediate
- "Data Protection Board independence critique" → difficulty: advanced
- "General tech news" → is_dpdp_relevant: false

Return ONLY valid JSON, no markdown fences."""

FEW_SHOT = [
    {
        "role": "user",
        "content": "URL: https://www.mondaq.com/india/data-protection/...\nTitle: Data Fiduciary vs Data Processor — What's the difference?\nText: Under the DPDP Act 2023, a Data Fiduciary determines the purpose and means of processing...",
    },
    {
        "role": "assistant",
        "content": '{"summary": "Explains the core DPDP Act distinction between Data Fiduciaries (who determine processing purpose) and Data Processors (who execute on their behalf), with compliance implications for each. Essential reading for any organisation mapping its data flows.", "content_type": "article", "difficulty": "beginner", "tags": ["data-fiduciary", "data-processor", "dpdp-act", "compliance", "section-8"], "is_dpdp_relevant": true}',
    },
]


@observe(name="enrich")
def enrich(url: str, title: str | None, text: str | None) -> dict:
    user_content = f"URL: {url}\nTitle: {title or 'Unknown'}\nText: {(text or '')[:4000]}"

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        *FEW_SHOT,
        {"role": "user", "content": user_content},
    ]

    response = _client().chat.completions.create(
        model="gpt-4o-mini",
        max_tokens=512,
        messages=messages,
    )

    try:
        return json.loads(response.choices[0].message.content)
    except Exception:
        return {"is_dpdp_relevant": False}
