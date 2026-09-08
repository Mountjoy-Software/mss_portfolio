import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/preferences.dart';
import 'core/router.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: PortfolioApp()));
}

class PortfolioApp extends ConsumerWidget {
  const PortfolioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
