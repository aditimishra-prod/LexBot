import logging
import os
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

# Build the FastAPI app at module level so `uvicorn main:app` works on Render
from api import build_app
from scheduler.digest import start_background_digest

app = build_app()
start_background_digest()

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    logger.info(f"Starting LexBot on port {port}…")
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
