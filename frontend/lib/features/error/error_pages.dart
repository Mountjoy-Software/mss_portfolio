import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({required this.path, this.reason, super.key});

  final String path;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    return _Frame(
      command: path,
      headline: 'command not found',
      detail:
          reason ??
          'Nothing lives at that address. The terminal is the whole site; '
              'everything else is reachable from there.',
    );
  }
}

class FatalErrorPage extends StatelessWidget {
  const FatalErrorPage({required this.detail, super.key});

  final String detail;

  @override
  Widget build(BuildContext context) {
    return _Frame(
      command: 'signal caught',
      headline: 'something broke',
      detail: detail,
    );
  }
}

class BannedPage extends StatelessWidget {
  const BannedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Frame(
      command: 'connection refused',
      headline: 'Ross banned you. Sorry',
      detail: '',
      showHome: false,
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({
    required this.command,
    required this.headline,
    required this.detail,
    this.showHome = true,
  });

  final String command;
  final String headline;
  final String detail;
  final bool showHome;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/logo/mss_logo.png', height: 44),
                  const SizedBox(height: 26),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '> ',
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          height: 1.6,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          command,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: 15,
                            height: 1.6,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    headline,
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      height: 1.6,
                      color: colorScheme.error,
                    ),
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      detail,
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        height: 1.65,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (showHome) ...[
                    const SizedBox(height: 26),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => context.go('/'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '< ',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'back to the terminal',
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: 13,
                                color: colorScheme.primary,
                                decoration: TextDecoration.underline,
                                decorationColor: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
