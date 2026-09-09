from fastapi import APIRouter

from src.api.v1 import chat, graph, health, profile, resume

api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(profile.router, tags=["profile"])
api_router.include_router(graph.router, tags=["graph"])
api_router.include_router(chat.router, tags=["chat"])
api_router.include_router(resume.router, tags=["resume"])
