import 'package:flutter/material.dart';
import 'package:flutter_spinners/flutter_spinners.dart';

import '../../core/markdown_style.dart';
import '../graph/graph_panel.dart';
import '../../core/models.dart';
import '../../core/streaming_markdown.dart';

class WaitingIndicator extends StatelessWidget {
  const WaitingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return QuadDotSwapIndicator(
      size: 32,
      color: Theme.of(context).colorScheme.primary,
      duration: const Duration(milliseconds: 1300),
    );
  }
}

class TranscriptEntry extends StatelessWidget {
  const TranscriptEntry({
    required this.turn,
    required this.isStreaming,
    this.toolActivity,
    super.key,
  });

  final ChatTurn turn;
  final bool isStreaming;
  final String? toolActivity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (turn.role == 'user') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 10, top: 1),
              child: Text(
                '>',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.65,
                ),
              ),
            ),
            Expanded(
              child: SelectableText(
                turn.content,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontSize: 15,
                  height: 1.65,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (turn.isGraph) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 26),
        child: GraphPanel(seed: turn.graphSeed!),
      );
    }

    if (turn.content.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24, left: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WaitingIndicator(),
            if (toolActivity != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  toolActivity!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: StreamingMarkdown(
        content: turn.content,
        isStreaming: isStreaming,
        styleSheet: terminalMarkdownStyleSheet(context),
      ),
    );
  }
}
