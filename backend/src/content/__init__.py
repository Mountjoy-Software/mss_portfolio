import json
from functools import cache
from pathlib import Path

_PROFILE_PATH = Path(__file__).parent / "profile.json"


@cache
def profile() -> dict:
    return json.loads(_PROFILE_PATH.read_text())
