import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

MarkdownStyleSheet terminalMarkdownStyleSheet(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final body = theme.textTheme.bodyMedium;

  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    blockSpacing: 10,
    listIndent: 22,
    p: body?.copyWith(
      color: colorScheme.onSurface,
      fontSize: 15,
      height: 1.65,
    ),
    h1: body?.copyWith(
      color: colorScheme.onSurface,
      fontSize: 21,
      fontWeight: FontWeight.w700,
      height: 1.4,
    ),
    h2: body?.copyWith(
      color: colorScheme.onSurface,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1.4,
    ),
    h3: body?.copyWith(
      color: colorScheme.onSurface,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    strong: body?.copyWith(
      color: colorScheme.onSurface,
      fontSize: 15,
      fontWeight: FontWeight.w700,
    ),
    em: body?.copyWith(
      color: colorScheme.onSurface,
      fontSize: 15,
      fontStyle: FontStyle.italic,
    ),
    a: body?.copyWith(
      color: colorScheme.primary,
      fontSize: 15,
      decoration: TextDecoration.underline,
      decorationColor: colorScheme.primary,
    ),
    listBullet: body?.copyWith(
      color: colorScheme.primary,
      fontSize: 15,
      height: 1.65,
    ),
    code: body?.copyWith(
      color: colorScheme.secondary,
      fontSize: 14,
      backgroundColor: Colors.transparent,
    ),
    codeblockDecoration: BoxDecoration(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: colorScheme.outlineVariant),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: colorScheme.primary, width: 2)),
    ),
    blockquotePadding: const EdgeInsets.only(left: 12),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
    ),
  );
}
