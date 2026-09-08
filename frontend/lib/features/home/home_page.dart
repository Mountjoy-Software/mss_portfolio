import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return profile.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => LoadFailure(
        error: error,
        onRetry: () => ref.invalidate(profileProvider),
      ),
      data: (data) => _Body(profile: data),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ContentColumn(
      children: [
        Text(profile.business, style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.2,
        )),
        const SizedBox(height: 8),
        Text(profile.name, style: theme.textTheme.displaySmall),
        const SizedBox(height: 8),
        Text(
          profile.tagline,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Text(profile.summary, style: theme.textTheme.bodyLarge),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => context.go('/assistant'),
              icon: const Icon(Icons.forum_outlined),
              label: const Text('Ask about my work'),
            ),
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse('mailto:${profile.email}')),
              icon: const Icon(Icons.mail_outline),
              label: Text(profile.email),
            ),
          ],
        ),
        const SizedBox(height: 48),
        const SectionHeading('What I work with'),
        for (final entry in profile.skills.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                TagRow(entry.value),
              ],
            ),
          ),
      ],
    );
  }
}
