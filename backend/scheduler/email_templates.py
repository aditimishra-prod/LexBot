"""
HTML email templates for LexBot digests.
Dark theme matching the app palette.
"""

from __future__ import annotations

from datetime import datetime

# ── Palette (inline CSS — email clients don't support external CSS) ───────────
BG      = "#0F0E17"
SURF    = "#1E1D2C"
SURF3   = "#262537"
BORDER  = "#2C2B3D"
ACCENT  = "#A78BFA"
TEXT1   = "#EDECF4"
TEXT2   = "#9B9AAE"
TEXT3   = "#5C5B72"
GREEN   = "#34D399"
AMBER   = "#FBBF24"
RED     = "#F87171"
BLUE    = "#60A5FA"

_BASE = """\
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
</head>
<body style="margin:0;padding:0;background:{bg};font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:{bg};min-height:100vh;">
<tr><td align="center" style="padding:32px 16px;">

  <!-- Card -->
  <table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:{surf};border-radius:16px;border:1px solid {border};">

    <!-- Header -->
    <tr>
      <td style="padding:28px 32px 20px;border-bottom:1px solid {border};">
        <table width="100%" cellpadding="0" cellspacing="0">
          <tr>
            <td>
              <span style="color:{accent};font-size:18px;font-weight:700;letter-spacing:-0.3px;">LexBot</span>
              <span style="color:{text3};font-size:12px;margin-left:6px;">DPDP Learning Assistant</span>
            </td>
            <td align="right">
              <span style="color:{text3};font-size:12px;">{date_str}</span>
            </td>
          </tr>
        </table>
        <h1 style="margin:16px 0 4px;color:{text1};font-size:22px;font-weight:700;letter-spacing:-0.3px;">
          {heading}
        </h1>
        <p style="margin:0;color:{text2};font-size:14px;">{subheading}</p>
      </td>
    </tr>

    <!-- Body -->
    <tr>
      <td style="padding:24px 32px;">
        {body}
      </td>
    </tr>

    <!-- Footer -->
    <tr>
      <td style="padding:20px 32px;border-top:1px solid {border};">
        <p style="margin:0;color:{text3};font-size:11px;text-align:center;">
          LexBot · Your DPDP Act 2023 learning assistant
        </p>
      </td>
    </tr>

  </table>
</td></tr>
</table>
</body>
</html>
"""


def _base(title, heading, subheading, body, date_str=None):
    if date_str is None:
        date_str = datetime.now().strftime("%A, %B %d")
    return _BASE.format(
        title=title, heading=heading, subheading=subheading,
        body=body, date_str=date_str,
        bg=BG, surf=SURF, surf3=SURF3, border=BORDER,
        accent=ACCENT, text1=TEXT1, text2=TEXT2, text3=TEXT3,
    )


def _item_card(title, url, summary, source, category, intent):
    """Single article card."""
    cat_color = {
        "legal-analysis": ACCENT,
        "compliance":     GREEN,
        "research":       BLUE,
        "education":      AMBER,
        "practitioner":   TEXT2,
        "civil-society":  TEXT3,
        "podcast":        GREEN,
        "policy":         BLUE,
    }.get(category or "", TEXT3)

    return f"""
    <table width="100%" cellpadding="0" cellspacing="0"
           style="background:{BG};border-radius:10px;border:1px solid {BORDER};
                  margin-bottom:12px;overflow:hidden;">
      <tr>
        <!-- Accent bar -->
        <td width="4" style="background:{cat_color};border-radius:10px 0 0 10px;">&nbsp;</td>
        <td style="padding:14px 16px;">
          <p style="margin:0 0 4px;font-size:13px;font-weight:700;color:{TEXT1};">
            <a href="{url}" style="color:{TEXT1};text-decoration:none;">{title}</a>
          </p>
          <p style="margin:0 0 8px;font-size:11px;color:{TEXT3};">
            {source}
            {f'&nbsp;·&nbsp;<span style="color:{cat_color}">{category}</span>' if category else ''}
          </p>
          <p style="margin:0;font-size:12px;color:{TEXT2};line-height:1.5;">{summary or ''}</p>
        </td>
      </tr>
    </table>
    """


def _section_label(label, color):
    return f"""
    <p style="margin:20px 0 8px;font-size:10px;font-weight:700;color:{color};
              letter-spacing:1px;text-transform:uppercase;">{label}</p>
    """


# ── Template 1: Daily Digest ──────────────────────────────────────────────────

def news_digest_email(items: list[dict]) -> tuple[str, str]:
    """Returns (subject, html) for the daily content digest email."""
    if not items:
        return "", ""

    by_cat: dict[str, list] = {}
    for item in items:
        cat = item.get("news_category") or item.get("category") or "general"
        by_cat.setdefault(cat, []).append(item)

    cat_order  = ["legal-analysis", "compliance", "research", "education", "practitioner", "civil-society", "podcast", "policy", "general"]
    cat_labels = {
        "legal-analysis": ("⚖️ Legal Analysis",   ACCENT),
        "compliance":     ("✅ Compliance",        GREEN),
        "research":       ("📄 Research",          BLUE),
        "education":      ("📚 Education",         AMBER),
        "practitioner":   ("👔 Practitioner",      TEXT2),
        "civil-society":  ("🏛️ Civil Society",    TEXT3),
        "podcast":        ("🎙️ Podcast",           GREEN),
        "policy":         ("📋 Policy",            BLUE),
        "general":        ("📌 General",           TEXT3),
    }

    body_parts = []
    total = len(items)

    body_parts.append(f"""
    <table width="100%" cellpadding="0" cellspacing="0"
           style="background:{SURF3};border-radius:8px;margin-bottom:20px;">
      <tr>
        <td style="padding:12px 16px;">
          <p style="margin:0;font-size:13px;color:{GREEN};font-weight:700;">
            {total} DPDP resource{'s' if total > 1 else ''} added to your library today
          </p>
          <p style="margin:4px 0 0;font-size:11px;color:{TEXT3};">
            Topics: {", ".join(by_cat.keys())}
          </p>
        </td>
      </tr>
    </table>
    """)

    for cat in cat_order:
        if cat not in by_cat:
            continue
        label, color = cat_labels.get(cat, (cat.title(), TEXT3))
        body_parts.append(_section_label(label, color))
        for item in by_cat[cat]:
            body_parts.append(_item_card(
                title    = item.get("title") or item.get("url", ""),
                url      = item.get("url", ""),
                summary  = item.get("summary", ""),
                source   = item.get("source", ""),
                category = cat,
                intent   = "",
            ))

    date_str = datetime.now().strftime("%A, %B %d")
    subject  = f"📚 LexBot Daily: {total} DPDP updates · {date_str}"
    html     = _base(
        title      = subject,
        heading    = f"{total} DPDP Updates Today",
        subheading = f"Auto-curated for your DPDP learning · {date_str}",
        body       = "".join(body_parts),
    )
    return subject, html


# ── Template 2: Weekly Briefing ───────────────────────────────────────────────

def weekly_briefing_email(digest_message: str, items: list[dict]) -> tuple[str, str]:
    """Returns (subject, html) for the weekly briefing email."""
    paragraphs = digest_message.strip().split("\n\n")
    message_html = "".join(
        f'<p style="margin:0 0 12px;font-size:13px;color:{TEXT2};line-height:1.6;">{p}</p>'
        for p in paragraphs if p.strip()
    )

    item_cards = "".join(
        _item_card(
            title    = item.get("title") or item.get("url", ""),
            url      = item.get("url", ""),
            summary  = item.get("summary", ""),
            source   = item.get("source", ""),
            category = item.get("content_type", ""),
            intent   = item.get("difficulty", ""),
        )
        for item in items
    )

    body = f"""
    <!-- Digest message -->
    <table width="100%" cellpadding="0" cellspacing="0"
           style="background:{BG};border-radius:10px;border:1px solid {BORDER};
                  margin-bottom:20px;">
      <tr>
        <td style="padding:16px 18px;">
          {message_html}
        </td>
      </tr>
    </table>

    <!-- Items -->
    {_section_label("THIS WEEK'S PICKS", ACCENT)}
    {item_cards}
    """

    date_str = datetime.now().strftime("%B %d, %Y")
    subject  = f"📚 LexBot Weekly Digest · {date_str}"
    html     = _base(
        title      = subject,
        heading    = "Your Weekly DPDP Digest",
        subheading = f"3 resources worth revisiting this week · {date_str}",
        body       = body,
    )
    return subject, html
