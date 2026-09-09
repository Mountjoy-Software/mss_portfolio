---
name: profile-content
description: Edit the resume, work history, skills or project write-ups shown on the site. Use when asked to add a job, update experience, add or change a project, adjust skills, or fix anything the assistant says about Ross's background.
---

# Editing site content

Everything the site says about Ross lives in `backend/src/content/profile.json`. It is
the only source. The API serves it at `/api/v1/profile`, the Flutter pages render it, the
assistant's system prompt is built from it in `src/services/claude.py`, and the
synthesized PDF resume in `src/services/resume.py` selects from it.

Do not add a second copy anywhere. If a page needs a new field, add it to the JSON, to
the matching model in `frontend/lib/core/models.dart`, and to the page that renders it.

## Shape

```
name, business, tagline, location, email, summary
skills:     { category: [string] }
experience: [ { company, role, start, end, highlights[], stack[] } ]
projects:   [ { slug, name, blurb, details, stack[], public, repo? } ]
```

`start` and `end` are `YYYY-MM`, or `present` for a current role. `slug` must be unique;
the assistant's `get_project_detail` tool looks projects up by it.

`blurb` is one line and goes in the system prompt for every request. `details` is the
long version and is only fetched when a visitor asks, which keeps the cached prefix small.
Put depth in `details`, not `blurb`.

## Rules

The email is `ross.mountjoy.carr@pm.me`. Never `ross@bysavi.com`, which belongs to a
different company.

Never invent an employer, a date, a metric, or a technology. If Ross has not supplied a
detail, leave the `TODO` in place and ask him. The assistant is instructed to say the
record does not cover a question rather than guess, so a gap is honest but a fabrication
gets shown to prospective clients as fact.

Write highlights as outcomes, not duties. Include a number where one exists.

## After editing

Changing this file changes the system prompt, which invalidates the prompt cache. That is
expected and self-corrects on the next request.

```bash
cd backend && .venv/bin/python -c "from src.services.claude import SYSTEM_PROMPT; print(SYSTEM_PROMPT)"
```

Read it back and check it reads as intended. Then check the frontend still parses it:

```bash
cd frontend && flutter test
```

The change is live once the backend image is rebuilt and deployed, since the JSON is
baked into the image. A content-only edit still needs a full deploy.
