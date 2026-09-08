import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _input.clear();
    _focus.requestFocus();
    if (trimmed.startsWith('/')) {
      ref
          .read(chatControllerProvider.notifier)
          .runCommand(trimmed, _replyFor(trimmed));
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
      _ =>
        'Unknown command `$token`. Type `/help` to see what is available.',
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
    ref.read(themeModeProvider.notifier).set(mode);
    return mode == ThemeMode.system
        ? 'Theme now follows your system setting, and will keep doing so on reload.'
        : 'Theme set to $argument. It will stay that way across reloads.';
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
                  usage: state.usage,
                  onSubmit: _send,
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
