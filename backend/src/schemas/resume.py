from pydantic import BaseModel, Field


class ResumeRequest(BaseModel):
    audience: str = Field(min_length=2, max_length=120)
