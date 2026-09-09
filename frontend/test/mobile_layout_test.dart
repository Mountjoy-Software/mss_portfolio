import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mss_portfolio/core/api_client.dart';
import 'package:mss_portfolio/core/models.dart';
import 'package:mss_portfolio/features/deck/deck_page.dart';
import 'package:mss_portfolio/features/error/error_pages.dart';
import 'package:mss_portfolio/features/terminal/chat_controller.dart';
import 'package:mss_portfolio/features/terminal/commands.dart';
import 'package:mss_portfolio/features/terminal/terminal_page.dart';
import 'package:mss_portfolio/theme/app_theme.dart';

const phones = [
  Size(320, 568),
  Size(360, 640),
  Size(390, 844),
  Size(1280, 800),
];

final project = Project(
  slug: 'long-name',
  name: 'A Project With A Deliberately Long Name For Wrapping',
  year: 2024,
  blurb: 'A blurb that runs on for a while so that it has to wrap on a phone.',
  details: '''
## Heading

Some prose with a `code span` and a [link](https://example.com).

```bash
claude mcp add --transport http mountjoy https://mountjoy.io/mcp --some-very-long-flag
```

- one bullet
- another bullet that is long enough to wrap around on a narrow phone screen
''',
  stack: const ['Flutter', 'FastAPI', 'CDK', 'Qdrant', 'Amazon Bedrock Titan'],
  repo: 'https://github.com/example/repo',
  url: 'https://example.com',
  media: const [],
);

final profile = Profile(
  name: 'Ross Mountjoy',
  business: 'Mountjoy Software Solutions',
  tagline: 'Software development consulting',
  summary: '',
  email: 'ross.mountjoy.carr@pm.me',
  location: 'Somewhere',
  skills: const {},
  experience: const [],
  projects: [project],
  links: const {'github': 'https://github.com/example'},
);

GraphNode node(String id, String kind, String title, {String expands = ''}) =>
    GraphNode(
      id: id,
      kind: kind,
      title: title,
      payload: {'blurb': 'A payload value long enough to need wrapping.'},
      expands: expands,
      relation: 'uses',
      score: 0.8123,
    );

class FakeApi extends ApiClient {
  @override
  Future<Profile> fetchProfile() async => profile;

  @override
  Future<List<GraphNode>> graphSeed() async => [
    node('projects', 'category', 'projects', expands: 'project'),
  ];

  @override
  Future<List<GraphNode>> expandNode(String id) async => [
    for (var i = 0; i < 6; i++)
      node('p$i', 'project', 'Project number $i with a long title'),
  ];
}

Future<void> pumpApp(
  WidgetTester tester,
  Size size,
  Widget home, {
  ProviderContainer? container,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final scope = container == null
      ? ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(FakeApi())],
          child: MaterialApp(theme: lightTheme, home: home),
        )
      : UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: lightTheme, home: home),
        );
  await tester.pumpWidget(scope);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final size in phones) {
    group('${size.width.toInt()}px', () {
      testWidgets('terminal hero', (tester) async {
        await pumpApp(tester, size, const TerminalPage());
        expect(find.text('Mountjoy Software Solutions'), findsOneWidget);
      });

      testWidgets('command menu', (tester) async {
        await pumpApp(tester, size, const TerminalPage());
        await tester.enterText(find.byType(TextField), '/');
        await tester.pump();
        for (final command in slashCommands) {
          expect(find.textContaining(command.description), findsOneWidget);
        }
      });

      testWidgets('transcript with replies and graph', (tester) async {
        final container = ProviderContainer(
          overrides: [apiClientProvider.overrideWithValue(FakeApi())],
        );
        addTearDown(container.dispose);
        final chat = container.read(chatControllerProvider.notifier);
        chat.runCommand('/help', helpReply());
        chat.runCommand('/mcp', mcpReply('https://mountjoy.io'));
        chat.runCommand('/architecture', architectureReply());
        chat.runGraph('/projects', 'projects');
        await pumpApp(tester, size, const TerminalPage(), container: container);
        expect(find.textContaining('Tap a point'), findsNothing);
      });

      testWidgets('deck', (tester) async {
        await pumpApp(tester, size, const DeckPage(slug: 'long-name'));
        expect(find.text('2024'), findsOneWidget);
      });

      testWidgets('error pages', (tester) async {
        await pumpApp(tester, size, const NotFoundPage(path: '/nowhere'));
        await pumpApp(
          tester,
          size,
          const FatalErrorPage(detail: 'Part of the page failed to render.'),
        );
      });
    });
  }
}
