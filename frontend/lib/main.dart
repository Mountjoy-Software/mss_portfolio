import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/api_client.dart';
import 'core/preferences.dart';
import 'features/error/error_pages.dart';
import 'core/router.dart';
import 'theme/app_theme.dart';

void main() {
  usePathUrlStrategy();
  ErrorWidget.builder = (details) => const FatalErrorPage(
    detail: 'Part of the page failed to render. Reloading usually clears it.',
  );
  runApp(const ProviderScope(child: PortfolioApp()));
}

final visitorBlockedProvider = FutureProvider<bool>(
  (ref) => ref.read(apiClientProvider).visitorBlocked(),
);

class PortfolioApp extends ConsumerWidget {
  const PortfolioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banned = ref.watch(visitorBlockedProvider).value == true;
    if (banned) {
      return MaterialApp(
        title: 'Mountjoy Software Solutions',
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ref.watch(themeModeProvider),
        home: const BannedPage(),
        debugShowCheckedModeBanner: false,
      );
    }
    return MaterialApp.router(
      title: 'Mountjoy Software Solutions',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
