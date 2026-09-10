import '../../core/models.dart';

class SlashCommand {
  const SlashCommand(this.name, this.description, {this.argHint});

  final String name;
  final String description;
  final String? argHint;

  String get prefill => argHint == null ? name : '$name ';
}

const slashCommands = [
  SlashCommand('/help', 'List everything you can ask or run here'),
  SlashCommand('/about', 'Who he is, where he is from, how he trained'),
  SlashCommand('/projects', 'What Ross has built, and the stack behind each'),
  SlashCommand('/experience', 'Where he has worked and what shipped'),
  SlashCommand('/skills', 'Languages, frameworks and infrastructure'),
  SlashCommand('/architecture', 'The AWS diagram behind this site'),
  SlashCommand('/mcp', 'Connect your own agent to this site over MCP'),
  SlashCommand('/contact', 'How to get in touch'),
  SlashCommand(
    '/synthesize-resume',
    'A one-page PDF resume, written for one reader',
    argHint: 'who is this for',
  ),
  SlashCommand('/clear', 'Clear the transcript and start over'),
  SlashCommand(
    '/set-theme',
    'Switch between dark, light and system',
    argHint: 'dark | light | system',
  ),
];

String commandToken(String input) =>
    input.trimLeft().split(RegExp(r'\s')).first.toLowerCase();

List<SlashCommand> matchingCommands(String input) {
  if (!input.trimLeft().startsWith('/')) return const [];
  final typed = commandToken(input);
  return slashCommands.where((c) => c.name.startsWith(typed)).toList();
}

String commandRest(String input) {
  final parts = input.trim().split(RegExp(r'\s+'));
  return parts.length > 1 ? parts.sublist(1).join(' ') : '';
}

String commandArgument(String input) => commandRest(input).toLowerCase();

String helpReply() {
  final rows = slashCommands
      .map(
        (c) => c.argHint == null
            ? '`${c.name}` — ${c.description}'
            : '`${c.name} <${c.argHint}>` — ${c.description}',
      )
      .join('\n\n');
  return '''
**Commands**

$rows

**Or just ask**

Questions go to Claude, grounded in Ross's actual work history. If the record
does not cover something it will say so rather than guess.
''';
}

String resumeUsage() {
  return '''
Usage: `/synthesize-resume <who is this for>`

Say who is going to read it and the resume gets written for them. For example:

- `/synthesize-resume a fintech CTO hiring a backend contractor`
- `/synthesize-resume a recruiter filling a senior Flutter role`
- `/synthesize-resume the founder of a two person startup`
''';
}

String resumeReply(Resume resume) {
  return '''
### ${resume.headline}

Synthesized for **${resume.reader}**.

${resume.positioning}

[Download the PDF](${resume.url}) — one page, written just now from the same indexed
record this assistant answers from. Name a different reader and you get a different
resume.
''';
}

String architectureReply() {
  return '''
![Production architecture for mountjoy.io](/media/mss-portfolio/architecture.png)

One CloudFront distribution fronts both origins: `/*` goes to a private S3 bucket
holding the Flutter bundle, `/api/*` goes to an ALB in front of a FastAPI task on
ECS Fargate. Same-origin, so no CORS. The load balancer's security group only
admits CloudFront's origin-facing prefix list, so the API cannot be reached
directly.

Everything is CDK in Python across four stacks, deployed by GitHub Actions through
OIDC with no stored AWS keys. Portfolio content is embedded with Bedrock Titan and
indexed in Qdrant, which grounds this assistant and drives the graph you get from
`/projects`.

Full write-up in [this site's deck](/deck/mss-portfolio).
''';
}

String mcpReply(String origin) {
  return """
This site runs an MCP server, so you can point your own agent at Ross's portfolio
instead of reading it here. One tool, `search_ross_mountjoy`, embeds your
question and matches it against the same Qdrant collection the assistant on this
page uses. No key, no account, no auth.

**Claude Code**

```bash
claude mcp add --transport http mountjoy $origin/mcp
```

**Anything else**

Streamable HTTP transport, endpoint `$origin/mcp`. Most clients take a JSON
config shaped like this:

```json
{
  "mcpServers": {
    "mountjoy": {
      "type": "http",
      "url": "$origin/mcp"
    }
  }
}
```

Then ask it something like *what has Ross done with ECS* and it will call the
tool. Passages come back with the repository, live URL and write-up links where
the record has them, so the agent can cite and follow them.

The server speaks the current spec revision and falls back for clients that
still open with `initialize`. Source is in `backend/src/api/mcp.py`.
""";
}

String contactReply(Profile profile) {
  final links = profile.links.entries
      .map((e) => '- ${e.key}: <${e.value}>')
      .join('\n');
  return '''
![${profile.name}](/media/profile.jpg)

**${profile.name}** — ${profile.business}

${profile.location}${profile.relocation == null ? '' : '\n\n${profile.relocation}'}

Email: <${profile.email}>

$links

Happy to talk about a project, a contract, or a role.
''';
}
