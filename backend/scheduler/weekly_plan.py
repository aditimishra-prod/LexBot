"""
Sunday 9am: generate weekly plan, send push to all devices, send email digest.
"""
import asyncio
from datetime import date, timedelta
from agent.planner import generate_weekly_plan
from notifications.fcm import broadcast_push
from notifications.email import send_weekly_digest
from db.client import supabase


async def run_weekly_plan():
    print("[plan] Generating weekly plan...")

    # Next Monday as week_start
    today = date.today()
    days_until_monday = (7 - today.weekday()) % 7 or 7
    week_start = str(today + timedelta(days=days_until_monday))

    plan = await generate_weekly_plan(week_start)

    if "error" in plan:
        print(f"[plan] Failed: {plan}")
        return

    # Push notification to all registered devices
    devices = supabase.table("devices").select("fcm_token").execute()
    tokens = [d["fcm_token"] for d in (devices.data or [])]
    theme = plan.get("week_theme", "Your DPDP learning plan is ready")
    broadcast_push(
        tokens,
        title="LexBot — Weekly Plan Ready",
        body=theme,
        data={"type": "weekly_plan", "week_start": week_start},
    )

    # Email digest
    send_weekly_digest(plan, week_start)
    print(f"[plan] Weekly plan for {week_start} done.")
