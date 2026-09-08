class SlashCommand {
  const SlashCommand(this.name, this.description);

  final String name;
  final String description;
}

const slashCommands = [
  SlashCommand('/help', 'List everything you can ask or run here'),
];

List<SlashCommand> matchingCommands(String input) {
  final trimmed = input.trimLeft();
  if (!trimmed.startsWith('/')) return const [];
  final typed = trimmed.split(RegExp(r'\s')).first.toLowerCase();
  return slashCommands
      .where((command) => command.name.startsWith(typed))
      .toList();
}

String runSlashCommand(String input) {
  final name = input.trim().split(RegExp(r'\s')).first.toLowerCase();
  if (name == '/help') return _help;
  return 'Unknown command `$name`. Type `/help` to see what is available.';
}

final _help =
    '''
**Commands**

${slashCommands.map((c) => '`${c.name}` — ${c.description}').join('\n\n')}

**Things worth asking**

- What has Ross built with AWS?
- Tell me about Gem.
- Does he have experience with LLM applications?
- How is this site deployed?

Answers come from Claude, grounded in Ross's actual work history. If the
record does not cover something, it will say so rather than guess.
''';
