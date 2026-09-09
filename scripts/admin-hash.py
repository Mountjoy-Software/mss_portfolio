#!/usr/bin/env python3
import getpass
import secrets
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "backend"))

from src.services.admin import hash_password

password = getpass.getpass("admin password: ")
if password != getpass.getpass("again: "):
    raise SystemExit("they do not match")

print()
print(f"ADMIN_PASSWORD_HASH={hash_password(password)}")
print(f"ADMIN_SESSION_SECRET={secrets.token_urlsafe(32)}")
