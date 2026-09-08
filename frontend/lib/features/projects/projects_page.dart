import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

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
            'Projects',
            subtitle: 'Things I built end to end.',
          ),
          for (final project in profile.projects)
            _ProjectCard(project: project),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final Project project;

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
            Row(
              children: [
                Expanded(
                  child: Text(project.name, style: theme.textTheme.titleLarge),
                ),
                if (project.repo != null)
                  IconButton(
                    tooltip: 'Source',
                    onPressed: () => launchUrl(Uri.parse(project.repo!)),
                    icon: const Icon(Icons.code),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(project.blurb, style: theme.textTheme.bodyLarge),
            if (project.details.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                project.details,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 14),
            TagRow(project.stack),
          ],
        ),
      ),
    );
  }
}
