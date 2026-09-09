import 'package:go_router/go_router.dart';

import '../features/admin/admin_page.dart';
import '../features/deck/deck_page.dart';
import '../features/error/error_pages.dart';
import '../features/terminal/terminal_page.dart';

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const TerminalPage()),
    GoRoute(path: '/admin', builder: (_, _) => const AdminPage()),
    GoRoute(
      path: '/deck/:slug',
      builder: (_, state) => DeckPage(slug: state.pathParameters['slug']!),
    ),
  ],
  errorBuilder: (context, state) => NotFoundPage(path: state.uri.path),
);
