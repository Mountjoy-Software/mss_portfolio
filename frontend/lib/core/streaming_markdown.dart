import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
      onTapLink: (_, href, _) {
        if (href != null) launchUrl(Uri.parse(href));
      },
    );
    if (!isStreaming) return markdown;
    return ShaderMask(
      shaderCallback: (bounds) {
        final fadeStart = (1 - _fadeHeight / bounds.height).clamp(0.0, 1.0);
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
