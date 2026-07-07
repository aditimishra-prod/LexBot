"""
Daily 8am: look up today's plan items and push a reminder to all devices.
"""
import asyncio
from datetime import date
from notifications.fcm import broadcast_push
from db.client import supabase


async def run_daily_reminder():
    today = date.today()
    day_key = today.strftime("%a").lower()  # mon, tue, ...

    # Find this week's plan
    result = (
        supabase.table("plans")
        .select("plan_json")
        .lte("week_start", str(today))
        .order("week_start", desc=True)
        .limit(1)
        .execute()
    )

    if not result.data:
        print("[reminder] No plan found for today")
        return

    plan = result.data[0]["plan_json"]
    day_items = plan.get("days", {}).get(day_key, [])

    if not day_items or day_key == "sun":
        print(f"[reminder] No items for {day_key}")
        return

    first = day_items[0]
    title_text = first.get("title", "Today's DPDP content is ready")

    devices = supabase.table("devices").select("fcm_token").execute()
    tokens = [d["fcm_token"] for d in (devices.data or [])]

    broadcast_push(
        tokens,
        title="LexBot Daily",
        body=f"Today: {title_text}",
        data={"type": "daily_reminder", "day": day_key},
    )
    print(f"[reminder] Daily reminder sent for {day_key}")
