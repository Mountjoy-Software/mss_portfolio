import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/backdrop.dart';
import '../../core/preferences.dart';
import 'chat_controller.dart';
import 'commands.dart';
import 'prompt_bar.dart';
import 'suggestions.dart';
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
  final _input = GhostController();
  final _focus = FocusNode();
  late final ScrollController _scroll;

  int _selected = -1;
  bool _dismissed = false;
  List<String> _bubbles = const [];
  bool _suppressMenuReset = false;
  List<SlashCommand> _menu = const [];
  String _lastText = '';
  bool _pinned = true;
  int _turnCount = 0;
  int _tailLength = 0;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onTextChanged);
    _bubbles = randomPrompts(4);
    final state = ref.read(chatControllerProvider);
    _turnCount = state.turns.length;
    _tailLength = state.turns.isEmpty ? 0 : state.turns.last.content.length;
    _scroll = ScrollController(
      initialScrollOffset: ref.read(transcriptOffsetProvider),
    )..addListener(_onScroll);
  }

  @override
  void dispose() {
    _input.removeListener(_onTextChanged);
    _input.dispose();
    _focus.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    _pinned = position.pixels >= position.maxScrollExtent - 32;
    ref.read(transcriptOffsetProvider.notifier).save(position.pixels);
  }

  void _onTextChanged() {
    if (_input.text == _lastText) return;
    _lastText = _input.text;
    _input.ghost = suggestionFor(_input.text);
    setState(() {
      if (_suppressMenuReset) return;
      _menu = matchingCommands(_input.text);
      _selected = -1;
      _dismissed = false;
    });
  }

  List<SlashCommand> get _matches => _dismissed ? const [] : _menu;

  void _prefill(SlashCommand command) {
    _suppressMenuReset = true;
    _input.value = TextEditingValue(
      text: command.prefill,
      selection: TextSelection.collapsed(offset: command.prefill.length),
    );
    _suppressMenuReset = false;
    _focus.requestFocus();
  }

  void _move(int delta) {
    final matches = _matches;
    if (matches.isEmpty) return;
    final next = _selected < 0
        ? (delta > 0 ? 0 : matches.length - 1)
        : (_selected + delta + matches.length) % matches.length;
    setState(() => _selected = next);
    _prefill(matches[next]);
  }

  void _accept(String ghost) {
    final full = _input.text + ghost;
    _input.value = TextEditingValue(
      text: full,
      selection: TextSelection.collapsed(offset: full.length),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final matches = _matches;
    final key = event.logicalKey;

    if (matches.isNotEmpty) {
      if (key == LogicalKeyboardKey.arrowDown) {
        _move(1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _move(-1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        setState(() => _dismissed = true);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.tab) {
        _prefill(matches[_selected < 0 ? 0 : _selected]);
        return KeyEventResult.handled;
      }
    }

    if (_input.ghost.isNotEmpty) {
      final selection = _input.selection;
      final atEnd =
          selection.isCollapsed && selection.baseOffset == _input.text.length;
      if (key == LogicalKeyboardKey.tab ||
          (key == LogicalKeyboardKey.arrowRight && atEnd)) {
        _accept(_input.ghost);
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
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
      final token = commandToken(trimmed);
      if (token == '/clear') {
        controller.reset();
        setState(() => _bubbles = randomPrompts(4));
        return;
      }
      const graphs = {
        '/about': 'about',
        '/projects': 'projects',
        '/experience': 'experience',
        '/skills': 'skills',
      };
      final seed = graphs[token];
      if (seed != null) {
        controller.runGraph(trimmed, seed);
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
    if (token == '/architecture') return architectureReply();

    final profile = ref.read(profileProvider).value;
    if (token == '/contact') {
      return profile == null
          ? 'Still loading that data. Try again in a moment.'
          : contactReply(profile);
    }
    return 'Unknown command `$token`. Type `/help` to see what is available.';
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
    ref.listen(chatControllerProvider, (_, next) {
      final turnCount = next.turns.length;
      final tailLength = next.turns.isEmpty
          ? 0
          : next.turns.last.content.length;
      if (turnCount == _turnCount && tailLength == _tailLength) return;
      final submitted = turnCount != _turnCount;
      _turnCount = turnCount;
      _tailLength = tailLength;
      if (submitted) _pinned = true;
      if (_pinned) _stickToEnd();
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
                          selected: _selected,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.turns.isEmpty &&
                        matches.isEmpty &&
                        _input.text.isEmpty)
                      PromptSuggestions(prompts: _bubbles, onPick: _send),
                    PromptBar(
                      controller: _input,
                      focusNode: _focus,
                      streaming: state.streaming,
                      menuOpen: matches.isNotEmpty,
                      suggesting: _input.ghost.isNotEmpty,
                      onKey: _onKey,
                      usage: state.usage,
                    ),
                  ],
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
