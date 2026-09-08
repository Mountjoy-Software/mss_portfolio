import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PromptBar extends StatelessWidget {
  const PromptBar({
    required this.controller,
    required this.focusNode,
    required this.streaming,
    required this.onSubmit,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool streaming;
  final ValueChanged<String> onSubmit;

  void _submit() {
    if (streaming) return;
    final text = controller.text;
    if (text.trim().isEmpty) return;
    onSubmit(text);
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

    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 2),
          child: Text(
            streaming
                ? 'working...'
                : 'enter to send    shift+enter for newline',
            style: textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
      ),
    );
  }
}
