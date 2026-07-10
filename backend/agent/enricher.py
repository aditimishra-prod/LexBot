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

Key DPDP topics to recognise as highly relevant:
- Data Fiduciary (S.2j) vs Data Processor distinction and liability
- Data Principal rights: access (S.11), correction/erasure (S.12), grievance redressal (S.13), nomination (S.14)
- Data Protection Board — structure, independence concerns, Sections 18-19
- DPDP Rules 2025 — compliance timelines, notices, consent frameworks
- Consent Managers and the DEPA framework
- Data localisation provisions
- Significant Data Fiduciary obligations
- GDPR vs DPDP comparison

Key authoritative speakers/sources — content from these is automatically high-value:
- Apar Gupta (IFF) — civil society critique of DPB independence
- Smriti Parsheera — peer-reviewed research on consent and governance
- Justice B.N. Srikrishna — chaired the original MeitY expert committee
- Dr. Prashant Mali — Bombay HC cyber law practitioner
- K&L Gates, AMS Shardul, Priti Suri & Associates — top DPDP law firms

Difficulty guide:
- beginner: what is DPDP, who it applies to, basic rights
- intermediate: compliance checklists, Rules 2025 provisions, Fiduciary obligations
- advanced: constitutional critique, DPB independence, comparative analysis, enforcement gaps

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
