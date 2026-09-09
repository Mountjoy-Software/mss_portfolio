import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BackLink extends StatelessWidget {
  const BackLink({this.emphasised = false, super.key});

  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colour = emphasised
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    return MouseRegion(
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
            Flexible(
              child: Text(
                'back to the terminal',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: colour,
                  decoration: emphasised ? TextDecoration.underline : null,
                  decorationColor: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
