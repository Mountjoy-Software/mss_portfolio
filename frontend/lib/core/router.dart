import 'package:go_router/go_router.dart';

import '../features/deck/deck_page.dart';
import '../features/terminal/terminal_page.dart';

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const TerminalPage()),
    GoRoute(
      path: '/deck/:slug',
      builder: (_, state) => DeckPage(slug: state.pathParameters['slug']!),
    ),
  ],
);
