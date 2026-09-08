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
  SlashCommand('/projects', 'What Ross has built, and the stack behind each'),
  SlashCommand('/experience', 'Where he has worked and what shipped'),
  SlashCommand('/skills', 'Languages, frameworks and infrastructure'),
  SlashCommand('/contact', 'How to get in touch'),
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

String commandArgument(String input) {
  final parts = input.trim().split(RegExp(r'\s+'));
  return parts.length > 1 ? parts.sublist(1).join(' ').toLowerCase() : '';
}

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

String projectsReply(Profile profile) {
  if (profile.projects.isEmpty) return 'No projects on record yet.';
  final rows = profile.projects
      .map(
        (p) => [
          '**${p.name}**',
          p.blurb,
          '`${p.stack.join('`  `')}`',
          if (p.repo != null) '[source](${p.repo})',
        ].join('\n\n'),
      )
      .join('\n\n---\n\n');
  return '**Projects**\n\n$rows';
}

String experienceReply(Profile profile) {
  if (profile.experience.isEmpty) {
    return 'The work history is not filled in yet. Ask about the projects instead, or email ${profile.email}.';
  }
  final rows = profile.experience
      .map(
        (e) => [
          '**${e.role}** — ${e.company}',
          '${e.start} to ${e.end}',
          ...e.highlights.map((h) => '- $h'),
          if (e.stack.isNotEmpty) '`${e.stack.join('`  `')}`',
        ].join('\n\n'),
      )
      .join('\n\n---\n\n');
  return '**Experience**\n\n$rows';
}

String skillsReply(Profile profile) {
  if (profile.skills.isEmpty) return 'No skills on record yet.';
  final rows = profile.skills.entries
      .map((e) => '**${e.key}**\n\n`${e.value.join('`  `')}`')
      .join('\n\n');
  return '**Skills**\n\n$rows';
}

String contactReply(Profile profile) => '''
**Contact**

${profile.name} — ${profile.business}

Email: <${profile.email}>

Happy to talk about a project, a contract, or a role.
''';
