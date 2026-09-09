import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';
import 'image_viewer.dart';

String resolveMedia(String path) =>
    Uri.parse(path).hasScheme ? path : '${ApiClient.baseUrl}$path';

class MarkdownImage extends StatelessWidget {
  const MarkdownImage({required this.src, this.caption, super.key});

  final String src;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.zoomIn,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showImageViewer(
                context,
                src: resolveMedia(src),
                caption: caption,
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      resolveMedia(src),
                      fit: BoxFit.contain,
                      errorBuilder: (context, _, _) => Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'image unavailable',
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : SizedBox(
                              height: 120,
                              width: double.infinity,
                              child: Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const Positioned(right: 6, bottom: 6, child: ZoomBadge()),
                ],
              ),
            ),
          ),
          if (caption != null && caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                caption!,
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StreamingMarkdown extends StatelessWidget {
  const StreamingMarkdown({
    required this.content,
    required this.isStreaming,
    required this.styleSheet,
    this.selectable = true,
    super.key,
  });

  final String content;
  final bool isStreaming;
  final MarkdownStyleSheet styleSheet;
  final bool selectable;

  static const _fadeHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final markdown = MarkdownBody(
      data: content,
      selectable: selectable,
      styleSheet: styleSheet,
      imageBuilder: (uri, title, alt) =>
          MarkdownImage(src: uri.toString(), caption: alt ?? title),
      onTapLink: (_, href, _) {
        if (href == null) return;
        if (href.startsWith('/api/') || href.startsWith('/media/')) {
          launchUrl(Uri.parse(resolveMedia(href)));
          return;
        }
        if (href.startsWith('/')) {
          context.go(href);
          return;
        }
        launchUrl(Uri.parse(href));
      },
    );
    return ShaderMask(
      shaderCallback: (bounds) {
        final fadeStart = isStreaming
            ? (1 - _fadeHeight / bounds.height).clamp(0.0, 1.0)
            : 1.0;
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Colors.black, Colors.black, Colors.transparent],
          stops: [0.0, fadeStart, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: markdown,
    );
  }
}
