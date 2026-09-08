from fastapi import APIRouter, HTTPException

from src.content import profile

router = APIRouter()


@router.get("/profile")
async def get_profile() -> dict:
    return profile()


@router.get("/projects/{slug}")
async def get_project(slug: str) -> dict:
    for x in profile()["projects"]:
        if x["slug"] == slug:
            return x
    raise HTTPException(404, "No such project")
