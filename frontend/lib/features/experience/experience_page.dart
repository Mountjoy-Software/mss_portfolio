import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';

class ExperiencePage extends ConsumerWidget {
  const ExperiencePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(profileProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => LoadFailure(
        error: error,
        onRetry: () => ref.invalidate(profileProvider),
      ),
      data: (profile) => ContentColumn(
        children: [
          const SectionHeading(
            'Experience',
            subtitle: 'Where I have worked and what shipped.',
          ),
          for (final role in profile.experience) _RoleCard(role: role),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role});

  final Experience role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(role.role, style: theme.textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              '${role.company} · ${role.start} – ${role.end}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            for (final highlight in role.highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 10),
                      child: Icon(
                        Icons.circle,
                        size: 5,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Expanded(child: Text(highlight)),
                  ],
                ),
              ),
            if (role.stack.isNotEmpty) ...[
              const SizedBox(height: 10),
              TagRow(role.stack),
            ],
          ],
        ),
      ),
    );
  }
}
