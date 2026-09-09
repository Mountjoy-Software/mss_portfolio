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




String contactReply(Profile profile) {
  final links = profile.links.entries
      .map((e) => '- ${e.key}: <${e.value}>')
      .join('\n');
  return '''
**Contact**

${profile.name}, ${profile.business}
${profile.location}

Email: <${profile.email}>

$links

Happy to talk about a project, a contract, or a role.
''';
}
