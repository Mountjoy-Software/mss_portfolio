import 'package:go_router/go_router.dart';

import '../features/terminal/terminal_page.dart';

final router = GoRouter(
  routes: [GoRoute(path: '/', builder: (_, _) => const TerminalPage())],
);
