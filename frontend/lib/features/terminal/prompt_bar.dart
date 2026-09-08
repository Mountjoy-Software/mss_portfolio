import 'package:flutter/material.dart';

class PromptBar extends StatelessWidget {
  const PromptBar({
    required this.controller,
    required this.focusNode,
    required this.streaming,
    required this.menuOpen,
    required this.onKey,
    this.usage,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool streaming;
  final bool menuOpen;
  final KeyEventResult Function(FocusNode, KeyEvent) onKey;
  final Map<String, dynamic>? usage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final promptStyle = textTheme.bodyMedium?.copyWith(
      fontSize: 15,
      height: 1.5,
      color: colorScheme.onSurface,
    );
    final hintStyle = textTheme.bodySmall?.copyWith(
      fontSize: 11,
      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: focusNode,
          builder: (context, _) => Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border.all(
                color: focusNode.hasFocus
                    ? colorScheme.primary.withValues(alpha: 0.8)
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 10, top: 1),
                  child: Text(
                    '>',
                    style: promptStyle?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Focus(
                    onKeyEvent: onKey,
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: true,
                      minLines: 1,
                      maxLines: 8,
                      cursorColor: colorScheme.primary,
                      cursorWidth: 8,
                      cursorRadius: Radius.zero,
                      style: promptStyle,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        hintText: 'Ask about my work',
                        hintStyle: promptStyle?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  streaming
                      ? 'working...'
                      : menuOpen
                      ? 'up/down to choose    enter or tab to fill    esc to dismiss'
                      : "Type '/help' for a list of commands.",
                  style: hintStyle,
                ),
              ),
              if (usage != null)
                Text(
                  '${usage!['cache_read']} cached / ${usage!['output_tokens']} out',
                  style: hintStyle,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class CommandMenu extends StatelessWidget {
  const CommandMenu({
    required this.rows,
    required this.selected,
    required this.onHover,
    required this.onPick,
    super.key,
  });

  final List<({String name, String? argHint, String description})> rows;
  final int selected;
  final ValueChanged<int> onHover;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, row) in rows.indexed)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => onHover(i),
              child: GestureDetector(
                onTap: () => onPick(i),
                child: Container(
                  width: double.infinity,
                  color: i == selected
                      ? colorScheme.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      Text(
                        row.name,
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (row.argHint != null)
                        Text(
                          ' <${row.argHint}>',
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      Text(
                        '  -  ',
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.description,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
