import hashlib
import json
import uuid
from dataclasses import dataclass, field

_NAMESPACE = uuid.UUID("6f3d9a4e-7c21-4f0b-9b1e-2a5d8c7f4e10")

CATEGORIES = {
    "about": "Who Ross Mountjoy is, where he is from and how he trained.",
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


def _usage(profile: dict) -> dict[str, list[str]]:
    used: dict[str, list[str]] = {}
    for project in profile.get("projects") or []:
        for item in project.get("stack") or []:
            used.setdefault(item, []).append(project["name"])
    for role in profile.get("experience") or []:
        for item in role.get("stack") or []:
            where = f"{role.get('role', '')} at {role.get('company', '')}"
            used.setdefault(item, []).append(where)
    return used


def _skill_docs(profile: dict) -> list[Doc]:
    docs = []
    used = _usage(profile)
    for group, items in (profile.get("skills") or {}).items():
        label = group.replace("_", " ")
        docs.append(
            Doc(
                key=f"skill_group:{group}",
                kind="skill_group",
                title=label,
                text=f"Skills Ross Mountjoy works with in {label}: "
                + ", ".join(items)
                + ".",
                payload={"group": group, "skills": items},
            )
        )
        for item in items:
            docs.append(
                Doc(
                    key=f"skill:{group}:{item}",
                    kind="skill",
                    title=item,
                    text=" ".join(
                        part
                        for part in (
                            f"{item}. A skill Ross Mountjoy works with, in "
                            f"{label}.",
                            f"He has used it on {_and(used[item])}."
                            if used.get(item)
                            else None,
                        )
                        if part
                    ),
                    payload={"group": group, "used_on": used.get(item) or []},
                )
            )
    return docs


def _and(names: list[str]) -> str:
    unique = list(dict.fromkeys(names))
    if len(unique) == 1:
        return unique[0]
    return ", ".join(unique[:-1]) + f" and {unique[-1]}"


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
                        f"{project['name']}, started {project['year']}."
                        if project.get("year")
                        else project["name"],
                        project.get("blurb"),
                        project.get("details"),
                        f"Built with {stack}." if stack else None,
                    )
                    if part
                ),
                payload={
                    "slug": project["slug"],
                    "year": project.get("year"),
                    "blurb": project.get("blurb", ""),
                    "stack": project.get("stack") or [],
                    "repo": project.get("repo"),
                    "url": project.get("url"),
                    "deck": f"/deck/{project['slug']}",
                    "media": [m["src"] for m in project.get("media") or []],
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
                        f"{company} is at {role['url']}."
                        if role.get("url")
                        else None,
                        *(role.get("highlights") or []),
                        f"Worked with {stack}." if stack else None,
                    )
                    if part
                ),
                payload={
                    "company": company,
                    "url": role.get("url"),
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


def _about_docs(profile: dict) -> list[Doc]:
    about = profile.get("about") or {}
    docs = []
    facts = [
        f"{profile['name']} is based in {profile.get('location', '')}." if profile.get("location") else None,
        f"He is a {about['citizenship']}." if about.get("citizenship") else None,
        f"He was born in {about['birthplace']}." if about.get("birthplace") else None,
    ]
    biography = " ".join(f for f in facts if f)
    if biography or profile.get("summary"):
        docs.append(
            Doc(
                key="about:bio",
                kind="bio",
                title=f"About {profile['name']}",
                text=f"{biography}\n\n{profile.get('summary', '')}".strip(),
                payload={
                    "location": profile.get("location"),
                    "citizenship": about.get("citizenship"),
                    "birthplace": about.get("birthplace"),
                    "media": [profile["photo"]] if profile.get("photo") else [],
                    **{k: v for k, v in (profile.get("links") or {}).items()},
                },
            )
        )
    for school in profile.get("education") or []:
        docs.append(
            Doc(
                key=f"education:{school['school']}",
                kind="education",
                title=f"{school['school']}",
                text=f"{profile['name']} studied {school.get('field', '')} at {school['school']}.",
                payload={"field": school.get("field")},
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
    docs += _about_docs(profile)
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
