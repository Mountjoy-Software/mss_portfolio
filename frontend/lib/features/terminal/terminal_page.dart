import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/backdrop.dart';
import 'chat_controller.dart';
import 'commands.dart';
import 'prompt_bar.dart';
import 'transcript.dart';

const _business = 'Mountjoy Software Solutions';
const _tagline = 'Software development consulting';

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
    _input.clear();
    _focus.requestFocus();
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.startsWith('/')) {
      ref
          .read(chatControllerProvider.notifier)
          .runCommand(trimmed, runSlashCommand(trimmed));
      return;
    }
    ref.read(chatControllerProvider.notifier).send(text);
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (state.turns.isEmpty || awaiting)
                    const Positioned.fill(
                      child: IgnorePointer(child: GlowVignette()),
                    ),
                  if (state.turns.isEmpty || awaiting)
                    const Positioned.fill(
                      child: IgnorePointer(child: ConstellationField()),
                    ),
                  Positioned.fill(
                    child: state.turns.isEmpty
                        ? const _Hero()
                        : _Body(scroll: _scroll, state: state),
                  ),
                ],
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: PromptBar(
                    controller: _input,
                    focusNode: _focus,
                    streaming: state.streaming,
                    usage: state.usage,
                    onSubmit: _send,
                  ),
                ),
              ),
            ),
          ],
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
      child: Padding(
        padding: const EdgeInsets.all(32),
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
            const SizedBox(height: 8),
            Text(
              profile?.tagline ?? _tagline,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.scroll, required this.state});

  final ScrollController scroll;
  final ChatState state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: ListView.builder(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
          itemCount: state.turns.length,
          itemBuilder: (context, i) => TranscriptEntry(
            turn: state.turns[i],
            isStreaming: state.streaming && i == state.turns.length - 1,
            toolActivity: state.toolActivity,
          ),
        ),
      ),
    );
  }
}
