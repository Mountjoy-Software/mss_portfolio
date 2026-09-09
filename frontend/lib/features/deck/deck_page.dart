import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/markdown_style.dart';
import '../../core/models.dart';
import '../../core/streaming_markdown.dart';
import '../error/error_pages.dart';

class DeckPage extends ConsumerWidget {
  const DeckPage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: profile.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (error, _) => const FatalErrorPage(
                detail:
                    'The API did not answer, so this write-up could not be '
                    'loaded. It may be a moment of downtime rather than '
                    'anything you did.',
              ),
              data: (data) {
                final matches = data.projects
                    .where((p) => p.slug == slug)
                    .toList();
                if (matches.isEmpty) {
                  return NotFoundPage(
                    path: '/deck/$slug',
                    reason:
                        'There is no write-up for that project. Type /projects '
                        'in the terminal to see the ones that exist.',
                  );
                }
                return _Body(project: matches.first);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BackLink(),
          const SizedBox(height: 28),
          Text(
            project.name,
            style: textTheme.titleLarge?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            project.blurb,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 15,
              height: 1.6,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in project.stack)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.35,
                      ),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item,
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          if (project.repo != null || project.url != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                if (project.url != null)
                  _Outbound(label: 'live', href: project.url!),
                if (project.url != null && project.repo != null)
                  const SizedBox(width: 16),
                if (project.repo != null)
                  _Outbound(label: 'source', href: project.repo!),
              ],
            ),
          ],
          const SizedBox(height: 26),
          Divider(height: 1, color: colorScheme.outlineVariant),
          const SizedBox(height: 26),
          if (project.details.isNotEmpty)
            StreamingMarkdown(
              content: project.details,
              isStreaming: false,
              styleSheet: terminalMarkdownStyleSheet(context),
            ),
          if (project.media.isNotEmpty) ...[
            const SizedBox(height: 26),
            for (final shot in project.media)
              MarkdownImage(src: shot.src, caption: shot.caption),
          ],
        ],
      ),
    );
  }
}

class _BackLink extends StatelessWidget {
  const _BackLink();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
            Text(
              'back to the terminal',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Outbound extends StatelessWidget {
  const _Outbound({required this.label, required this.href});

  final String label;
  final String href;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(href)),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            color: colorScheme.primary,
            decoration: TextDecoration.underline,
            decorationColor: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
