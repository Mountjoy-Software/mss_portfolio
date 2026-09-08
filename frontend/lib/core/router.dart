import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/architecture/architecture_page.dart';
import '../features/assistant/assistant_page.dart';
import '../features/experience/experience_page.dart';
import '../features/home/home_page.dart';
import '../features/projects/projects_page.dart';
import 'shell.dart';

final router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => SiteShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomePage()),
        GoRoute(path: '/experience', builder: (_, _) => const ExperiencePage()),
        GoRoute(path: '/projects', builder: (_, _) => const ProjectsPage()),
        GoRoute(
          path: '/architecture',
          builder: (_, _) => const ArchitecturePage(),
        ),
        GoRoute(path: '/assistant', builder: (_, _) => const AssistantPage()),
      ],
    ),
  ],
  errorBuilder: (context, state) => SiteShell(
    child: Center(child: Text('Nothing at ${state.uri.path}')),
  ),
);
