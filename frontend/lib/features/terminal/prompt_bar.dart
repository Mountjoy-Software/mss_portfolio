import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'commands.dart';

class PromptBar extends StatelessWidget {
  const PromptBar({
    required this.controller,
    required this.focusNode,
    required this.streaming,
    required this.onSubmit,
    this.usage,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool streaming;
  final ValueChanged<String> onSubmit;
  final Map<String, dynamic>? usage;

  void _submit() {
    if (streaming) return;
    if (controller.text.trim().isEmpty) return;
    onSubmit(controller.text);
  }

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
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final matches = matchingCommands(value.text);
            if (matches.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CommandMenu(commands: matches, onPick: onSubmit),
            );
          },
        ),
        AnimatedBuilder(
          animation: focusNode,
          builder: (context, _) => Container(
            decoration: BoxDecoration(
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
                    onKeyEvent: (_, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        _submit();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
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

class _CommandMenu extends StatelessWidget {
  const _CommandMenu({required this.commands, required this.onPick});

  final List<SlashCommand> commands;
  final ValueChanged<String> onPick;

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
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final command in commands)
            _CommandRow(
              command: command,
              onTap: () => onPick(command.name),
              nameStyle: textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
              descriptionStyle: textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _CommandRow extends StatefulWidget {
  const _CommandRow({
    required this.command,
    required this.onTap,
    required this.nameStyle,
    required this.descriptionStyle,
  });

  final SlashCommand command;
  final VoidCallback onTap;
  final TextStyle? nameStyle;
  final TextStyle? descriptionStyle;

  @override
  State<_CommandRow> createState() => _CommandRowState();
}

class _CommandRowState extends State<_CommandRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          color: _hovered
              ? colorScheme.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              Text(widget.command.name, style: widget.nameStyle),
              Text('  -  ', style: widget.descriptionStyle),
              Expanded(
                child: Text(
                  widget.command.description,
                  style: widget.descriptionStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
