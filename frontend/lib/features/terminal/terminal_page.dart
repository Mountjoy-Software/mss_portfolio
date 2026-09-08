import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import 'chat_controller.dart';
import 'prompt_bar.dart';
import 'transcript.dart';

const _suggestions = [
  'what has ross built with aws?',
  'tell me about gem',
  'does he have experience with llm applications?',
  'how is this site deployed?',
];

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
    ref.read(chatControllerProvider.notifier).send(text);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    if (state.streaming) _scrollToEnd();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const _Header(),
                  Expanded(
                    child: state.turns.isEmpty
                        ? _Banner(onPick: _send)
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.only(top: 20, bottom: 8),
                            itemCount: state.turns.length,
                            itemBuilder: (context, i) => TranscriptEntry(
                              turn: state.turns[i],
                              isStreaming:
                                  state.streaming &&
                                  i == state.turns.length - 1,
                              toolActivity: state.toolActivity,
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PromptBar(
                      controller: _input,
                      focusNode: _focus,
                      streaming: state.streaming,
                      onSubmit: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final usage = ref.watch(chatControllerProvider).usage;

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Image.asset('assets/logo/mss_logo.png', height: 26),
              const SizedBox(width: 10),
              Text(
                'mountjoy.io',
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (usage != null)
                Text(
                  '${usage['cache_read']} cached / ${usage['output_tokens']} out',
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: colorScheme.outlineVariant),
        ],
      ),
    );
  }
}

class _Banner extends ConsumerWidget {
  const _Banner({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profile = ref.watch(profileProvider);

    final mono = textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.65);
    final muted = mono?.copyWith(color: colorScheme.onSurfaceVariant);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 28, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          profile.when(
            loading: () => Text('connecting...', style: muted),
            error: (_, _) => Text(
              'the api is unreachable. the assistant will not answer.',
              style: mono?.copyWith(color: colorScheme.error),
            ),
            data: (Profile data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.business,
                  style: mono?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(data.tagline, style: muted),
                const SizedBox(height: 14),
                Text(data.email, style: muted),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text('try:', style: muted),
          const SizedBox(height: 8),
          for (final suggestion in _suggestions)
            _SuggestionLine(text: suggestion, onTap: () => onPick(suggestion)),
        ],
      ),
    );
  }
}

class _SuggestionLine extends StatefulWidget {
  const _SuggestionLine({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  State<_SuggestionLine> createState() => _SuggestionLineState();
}

class _SuggestionLineState extends State<_SuggestionLine> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Text(
                '  ${_hovered ? '>' : ' '} ',
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  height: 1.65,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                child: Text(
                  widget.text,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 15,
                    height: 1.65,
                    color: _hovered
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
