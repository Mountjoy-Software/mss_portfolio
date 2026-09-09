from pydantic import BaseModel, Field


class Credentials(BaseModel):
    username: str = Field(min_length=1, max_length=64)
    password: str = Field(min_length=1, max_length=200)


class Target(BaseModel):
    ip: str = Field(min_length=3, max_length=45)
