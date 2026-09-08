import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/backdrop.dart';
import '../../core/preferences.dart';
import 'chat_controller.dart';
import 'commands.dart';
import 'prompt_bar.dart';
import 'transcript.dart';

const _business = 'Mountjoy Software Solutions';
const _name = 'Ross Mountjoy';
const _tagline = 'Software development consulting';
const _columnWidth = 880.0;

class TerminalPage extends ConsumerStatefulWidget {
  const TerminalPage({super.key});

  @override
  ConsumerState<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends ConsumerState<TerminalPage> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  int _selected = 0;
  bool _dismissed = false;
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _input.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _input.removeListener(_onTextChanged);
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_input.text == _lastText) return;
    _lastText = _input.text;
    setState(() {
      _selected = 0;
      _dismissed = false;
    });
  }

  List<SlashCommand> get _matches =>
      _dismissed ? const [] : matchingCommands(_input.text);

  void _prefill(SlashCommand command) {
    _input.value = TextEditingValue(
      text: command.prefill,
      selection: TextSelection.collapsed(offset: command.prefill.length),
    );
    _focus.requestFocus();
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
        if (commandToken(_input.text) != chosen.name) {
          _prefill(chosen);
          return KeyEventResult.handled;
        }
      }
      _send(_input.text);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (ref.read(chatControllerProvider).streaming) return;
    _input.clear();
    _focus.requestFocus();
    if (trimmed.startsWith('/')) {
      final controller = ref.read(chatControllerProvider.notifier);
      if (commandToken(trimmed) == '/clear') {
        controller.reset();
        return;
      }
      controller.runCommand(trimmed, _replyFor(trimmed));
      return;
    }
    ref.read(chatControllerProvider.notifier).send(text);
  }

  String _replyFor(String input) {
    final token = commandToken(input);
    if (token == '/help') return helpReply();
    if (token == '/set-theme') return _applyTheme(commandArgument(input));

    final profile = ref.read(profileProvider).value;
    if (profile == null) {
      return 'Still loading that data. Try again in a moment.';
    }
    return switch (token) {
      '/projects' => projectsReply(profile),
      '/experience' => experienceReply(profile),
      '/skills' => skillsReply(profile),
      '/contact' => contactReply(profile),
      _ => 'Unknown command `$token`. Type `/help` to see what is available.',
    };
  }

  String _applyTheme(String argument) {
    final mode = switch (argument) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => null,
    };
    if (mode == null) {
      return 'Usage: `/set-theme dark | light | system`';
    }
    final saved = ref.read(themeModeProvider.notifier).set(mode);
    final what = mode == ThemeMode.system
        ? 'Theme now follows your system setting'
        : 'Theme set to $argument';
    return saved
        ? '$what, and it will stay that way across reloads.'
        : '$what for this visit only. Your browser is blocking local storage, so it will reset on reload.';
  }

  void _stickToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatControllerProvider, (previous, next) {
      final grew = next.turns.length != (previous?.turns.length ?? 0);
      final tokenArrived =
          next.turns.isNotEmpty &&
          previous?.turns.isNotEmpty == true &&
          next.turns.last.content.length != previous!.turns.last.content.length;
      if (grew || tokenArrived) _stickToEnd();
    });
    final state = ref.watch(chatControllerProvider);
    final awaiting =
        state.streaming &&
        state.turns.isNotEmpty &&
        state.turns.last.content.isEmpty;
    final showBackdrop = state.turns.isEmpty || awaiting;
    final matches = _matches;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (showBackdrop)
                    const Positioned.fill(
                      child: IgnorePointer(child: GlowVignette()),
                    ),
                  if (showBackdrop)
                    const Positioned.fill(
                      child: IgnorePointer(child: ConstellationField()),
                    ),
                  Positioned.fill(
                    child: _Column(
                      child: state.turns.isEmpty
                          ? const _Hero()
                          : _Transcript(scroll: _scroll, state: state),
                    ),
                  ),
                  if (matches.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: _Column(
                        child: CommandMenu(
                          rows: [
                            for (final c in matches)
                              (
                                name: c.name,
                                argHint: c.argHint,
                                description: c.description,
                              ),
                          ],
                          selected: _selected.clamp(0, matches.length - 1),
                          onHover: (i) => setState(() => _selected = i),
                          onPick: (i) => _prefill(matches[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _Column(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PromptBar(
                  controller: _input,
                  focusNode: _focus,
                  streaming: state.streaming,
                  menuOpen: matches.isNotEmpty,
                  onKey: _onKey,
                  usage: state.usage,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _columnWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: child,
        ),
      ),
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profile = ref.watch(profileProvider).value;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/logo/mss_logo.png', height: 96),
          const SizedBox(height: 24),
          Text(
            profile?.business ?? _business,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            profile?.name ?? _name,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 15,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            profile?.tagline ?? _tagline,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Transcript extends StatelessWidget {
  const _Transcript({required this.scroll, required this.state});

  final ScrollController scroll;
  final ChatState state;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.only(top: 28, bottom: 8),
      itemCount: state.turns.length,
      itemBuilder: (context, i) => TranscriptEntry(
        turn: state.turns[i],
        isStreaming: state.streaming && i == state.turns.length - 1,
        toolActivity: state.toolActivity,
      ),
    );
  }
}
