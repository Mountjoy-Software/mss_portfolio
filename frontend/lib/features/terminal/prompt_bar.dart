import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'commands.dart';

class PromptBar extends StatefulWidget {
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

  @override
  State<PromptBar> createState() => _PromptBarState();
}

class _PromptBarState extends State<PromptBar> {
  int _selected = 0;
  bool _dismissed = false;
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (widget.controller.text == _lastText) return;
    _lastText = widget.controller.text;
    setState(() {
      _selected = 0;
      _dismissed = false;
    });
  }

  List<SlashCommand> get _matches =>
      _dismissed ? const [] : matchingCommands(widget.controller.text);

  void _prefill(SlashCommand command) {
    widget.controller.value = TextEditingValue(
      text: command.prefill,
      selection: TextSelection.collapsed(offset: command.prefill.length),
    );
  }

  void _submit() {
    if (widget.streaming) return;
    if (widget.controller.text.trim().isEmpty) return;
    widget.onSubmit(widget.controller.text);
    setState(() => _dismissed = false);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final matches = _matches;
    final key = event.logicalKey;

    if (matches.isNotEmpty) {
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() => _selected = (_selected + 1) % matches.length);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(
          () => _selected = (_selected - 1 + matches.length) % matches.length,
        );
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        setState(() => _dismissed = true);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.tab) {
        _prefill(matches[_selected.clamp(0, matches.length - 1)]);
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      if (matches.isNotEmpty) {
        final chosen = matches[_selected.clamp(0, matches.length - 1)];
        if (commandToken(widget.controller.text) != chosen.name) {
          _prefill(chosen);
          return KeyEventResult.handled;
        }
      }
      _submit();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
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
    final matches = _matches;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (matches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CommandMenu(
              commands: matches,
              selected: _selected.clamp(0, matches.length - 1),
              onHover: (i) => setState(() => _selected = i),
              onPick: (command) {
                _prefill(command);
                widget.focusNode.requestFocus();
              },
            ),
          ),
        AnimatedBuilder(
          animation: widget.focusNode,
          builder: (context, _) => Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: widget.focusNode.hasFocus
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
                    onKeyEvent: _onKey,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
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
                  widget.streaming
                      ? 'working...'
                      : matches.isNotEmpty
                      ? 'up/down to choose    enter or tab to fill    esc to dismiss'
                      : "Type '/help' for a list of commands.",
                  style: hintStyle,
                ),
              ),
              if (widget.usage != null)
                Text(
                  '${widget.usage!['cache_read']} cached / ${widget.usage!['output_tokens']} out',
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
  const _CommandMenu({
    required this.commands,
    required this.selected,
    required this.onHover,
    required this.onPick,
  });

  final List<SlashCommand> commands;
  final int selected;
  final ValueChanged<int> onHover;
  final ValueChanged<SlashCommand> onPick;

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
          for (final (i, command) in commands.indexed)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => onHover(i),
              child: GestureDetector(
                onTap: () => onPick(command),
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
                        command.name,
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (command.argHint != null)
                        Text(
                          ' <${command.argHint}>',
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
                          command.description,
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
