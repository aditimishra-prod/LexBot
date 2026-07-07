import os
from supabase import create_client, Client

_url = os.getenv("SUPABASE_URL", "")
_key = os.getenv("SUPABASE_KEY", "")

supabase: Client = create_client(_url, _key)
