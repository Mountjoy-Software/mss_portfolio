import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const destinations = <({String path, String label, IconData icon})>[
  (path: '/', label: 'Home', icon: Icons.home_outlined),
  (path: '/experience', label: 'Experience', icon: Icons.work_outline),
  (path: '/projects', label: 'Projects', icon: Icons.folder_outlined),
  (path: '/architecture', label: 'Architecture', icon: Icons.hub_outlined),
  (path: '/assistant', label: 'Assistant', icon: Icons.forum_outlined),
];

class SiteShell extends StatelessWidget {
  const SiteShell({required this.child, super.key});

  final Widget child;

  int _index(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final match = destinations.lastIndexWhere(
      (d) => d.path == '/' ? location == '/' : location.startsWith(d.path),
    );
    return match < 0 ? 0 : match;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final index = _index(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Mountjoy Software',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            if (wide) ...[
              const SizedBox(width: 32),
              for (final (i, d) in destinations.indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: TextButton(
                    onPressed: () => context.go(d.path),
                    style: TextButton.styleFrom(
                      foregroundColor: i == index
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    child: Text(d.label),
                  ),
                ),
            ],
          ],
        ),
      ),
      body: child,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => context.go(destinations[i].path),
              destinations: [
                for (final d in destinations)
                  NavigationDestination(icon: Icon(d.icon), label: d.label),
              ],
            ),
    );
  }
}
