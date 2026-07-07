from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.routes import router


def build_app() -> FastAPI:
    app = FastAPI(title="LexBot — DPDP Learning Agent", version="1.0.0")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(router)

    @app.get("/")
    async def root():
        return {"status": "ok", "service": "LexBot DPDP Agent"}

    return app
