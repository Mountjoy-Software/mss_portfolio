import hashlib
import json
import uuid
from dataclasses import dataclass, field

_NAMESPACE = uuid.UUID("6f3d9a4e-7c21-4f0b-9b1e-2a5d8c7f4e10")

CATEGORIES = {
    "projects": "Software Ross Mountjoy has designed and built end to end.",
    "experience": "Roles Ross Mountjoy has held and what shipped in them.",
    "skills": "Languages, frameworks and infrastructure Ross Mountjoy works with.",
}


@dataclass
class Doc:
    key: str
    kind: str
    title: str
    text: str
    payload: dict = field(default_factory=dict)

    @property
    def point_id(self) -> str:
        return str(uuid.uuid5(_NAMESPACE, self.key))


def _skill_docs(profile: dict) -> list[Doc]:
    docs = []
    for group, items in (profile.get("skills") or {}).items():
        for item in items:
            docs.append(
                Doc(
                    key=f"skill:{group}:{item}",
                    kind="skill",
                    title=item,
                    text=f"{item}. A {group.replace('_', ' ')} skill used by Ross Mountjoy.",
                    payload={"group": group},
                )
            )
    return docs


def _project_docs(profile: dict) -> list[Doc]:
    docs = []
    for project in profile.get("projects") or []:
        stack = ", ".join(project.get("stack") or [])
        docs.append(
            Doc(
                key=f"project:{project['slug']}",
                kind="project",
                title=project["name"],
                text="\n".join(
                    part
                    for part in (
                        project["name"],
                        project.get("blurb"),
                        project.get("details"),
                        f"Built with {stack}." if stack else None,
                    )
                    if part
                ),
                payload={
                    "slug": project["slug"],
                    "blurb": project.get("blurb", ""),
                    "stack": project.get("stack") or [],
                    "repo": project.get("repo"),
                    "url": project.get("url"),
                },
            )
        )
    return docs


def _experience_docs(profile: dict) -> list[Doc]:
    docs = []
    for role in profile.get("experience") or []:
        company = role.get("company", "")
        title = role.get("role", "")
        if title.upper() == "TODO" or company.upper() == "TODO":
            continue
        stack = ", ".join(role.get("stack") or [])
        period = f"{role.get('start', '')} to {role.get('end', '')}"
        docs.append(
            Doc(
                key=f"role:{company}:{title}",
                kind="role",
                title=f"{title} at {company}",
                text="\n".join(
                    part
                    for part in (
                        f"{title} at {company}, {period}.",
                        *(role.get("highlights") or []),
                        f"Worked with {stack}." if stack else None,
                    )
                    if part
                ),
                payload={
                    "company": company,
                    "role": title,
                    "period": period,
                    "highlights": role.get("highlights") or [],
                    "stack": role.get("stack") or [],
                },
            )
        )
        for index, highlight in enumerate(role.get("highlights") or []):
            if highlight.upper() == "TODO":
                continue
            docs.append(
                Doc(
                    key=f"highlight:{company}:{title}:{index}",
                    kind="highlight",
                    title=highlight,
                    text=f"{highlight} ({title} at {company}, {period}.)",
                    payload={"company": company, "role": title},
                )
            )
    return docs


def build(profile: dict) -> list[Doc]:
    docs = [
        Doc(
            key=f"category:{name}",
            kind="category",
            title=name,
            text=description,
            payload={"category": name},
        )
        for name, description in CATEGORIES.items()
    ]
    docs += _project_docs(profile)
    docs += _experience_docs(profile)
    docs += _skill_docs(profile)
    return docs


def fingerprint(docs: list[Doc]) -> str:
    payload = json.dumps(
        [[d.key, d.kind, d.title, d.text, d.payload] for d in docs],
        sort_keys=True,
        default=str,
    )
    return hashlib.sha256(payload.encode()).hexdigest()[:16]
