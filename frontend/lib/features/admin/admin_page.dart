import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';

final _sessionProvider = NotifierProvider<AdminSessionHolder, String?>(
  AdminSessionHolder.new,
);

class AdminSessionHolder extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? token) => state = token;
}

class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(_sessionProvider);
    return Scaffold(
      body: SafeArea(
        child: token == null ? const _SignIn() : _Console(token: token),
      ),
    );
  }
}

class _SignIn extends ConsumerStatefulWidget {
  const _SignIn();

  @override
  ConsumerState<_SignIn> createState() => _SignInState();
}

class _SignInState extends ConsumerState<_SignIn> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await ref
          .read(apiClientProvider)
          .adminLogin(_username.text.trim(), _password.text);
      if (!mounted) return;
      ref.read(_sessionProvider.notifier).set(session.token);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is ApiException ? error.message : 'Could not sign in.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'admin',
                style: textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              _Field(
                controller: _username,
                label: 'username',
                onSubmit: _submit,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _password,
                label: 'password',
                obscure: true,
                onSubmit: _submit,
              ),
              const SizedBox(height: 18),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _submit,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.14),
                      border: Border.all(color: colorScheme.primary),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _busy ? 'checking...' : 'sign in',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    _error!,
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: colorScheme.error,
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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.onSubmit,
    this.obscure = false,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onSubmit;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return TextField(
      controller: controller,
      obscureText: obscure,
      autofillHints: const [],
      onSubmitted: (_) => onSubmit(),
      style: textTheme.bodyMedium?.copyWith(fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        labelStyle: textTheme.bodySmall?.copyWith(
          fontSize: 12,
          color: colorScheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}

class _Console extends ConsumerStatefulWidget {
  const _Console({required this.token});

  final String token;

  @override
  ConsumerState<_Console> createState() => _ConsoleState();
}

class _ConsoleState extends ConsumerState<_Console> {
  AdminView? _view;
  String? _error;
  String? _open;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final view = await ref.read(apiClientProvider).adminThreads(widget.token);
      if (!mounted) return;
      setState(() {
        _view = view;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      final expired = error is ApiException && error.statusCode == 401;
      if (expired) {
        ref.read(_sessionProvider.notifier).set(null);
        return;
      }
      setState(() {
        _busy = false;
        _error = error is ApiException ? error.message : '$error';
      });
    }
  }

  Future<void> _toggle(String ip, bool blocked) async {
    try {
      final updated = await ref
          .read(apiClientProvider)
          .setBlocked(widget.token, ip, blocked);
      if (!mounted) return;
      setState(() {
        final current = _view;
        if (current != null) {
          _view = AdminView(threads: current.threads, blocked: updated.toSet());
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error is ApiException ? error.message : '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final view = _view;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'admin',
                    style: textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                _Action(label: _busy ? 'loading...' : 'refresh', onTap: _load),
                const SizedBox(width: 16),
                _Action(
                  label: 'sign out',
                  onTap: () => ref.read(_sessionProvider.notifier).set(null),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: colorScheme.error,
                  ),
                ),
              ),
            if (view != null) ...[
              const SizedBox(height: 6),
              Text(
                '${view.threads.length} threads  ·  '
                '${view.blocked.length} blocked',
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (view.blocked.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'blocked addresses',
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final ip in view.blocked.toList()..sort())
                      _Chip(
                        label: ip,
                        action: 'unblock',
                        onTap: () => _toggle(ip, false),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              for (final thread in view.threads)
                _ThreadTile(
                  thread: thread,
                  blocked: view.blocked.contains(thread.ip),
                  expanded: _open == thread.id,
                  onToggleOpen: () => setState(
                    () => _open = _open == thread.id ? null : thread.id,
                  ),
                  onToggleBlock: () =>
                      _toggle(thread.ip, !view.blocked.contains(thread.ip)),
                ),
              if (view.threads.isEmpty)
                Text(
                  'Nobody has talked to the assistant yet.',
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.thread,
    required this.blocked,
    required this.expanded,
    required this.onToggleOpen,
    required this.onToggleBlock,
  });

  final AdminThread thread;
  final bool blocked;
  final bool expanded;
  final VoidCallback onToggleOpen;
  final VoidCallback onToggleBlock;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(
      fontSize: 12,
      color: colorScheme.onSurfaceVariant,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: blocked
              ? colorScheme.error.withValues(alpha: 0.6)
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onToggleOpen,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          thread.ip,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: blocked
                                ? colorScheme.error
                                : colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${thread.turns} messages  ·  '
                          '${_when(thread.updated)}  ·  ${thread.id}',
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _Action(
                label: blocked ? 'unblock' : 'block',
                danger: !blocked,
                onTap: onToggleBlock,
              ),
              const SizedBox(width: 14),
              _Action(label: expanded ? 'hide' : 'read', onTap: onToggleOpen),
            ],
          ),
          if (thread.agent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(thread.agent, style: muted, maxLines: 2),
            ),
          if (expanded) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            for (final turn in thread.messages)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text(
                        turn.role == 'user' ? '>' : '<',
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: turn.role == 'user'
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        turn.content.isEmpty ? '(no reply)' : turn.content,
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          height: 1.5,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

String _when(DateTime moment) {
  final gap = DateTime.now().difference(moment);
  if (gap.inMinutes < 1) return 'just now';
  if (gap.inHours < 1) return '${gap.inMinutes}m ago';
  if (gap.inDays < 1) return '${gap.inHours}h ago';
  return '${gap.inDays}d ago';
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: danger ? colorScheme.error : colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.action, required this.onTap});

  final String label;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: colorScheme.error,
            ),
          ),
          const SizedBox(width: 8),
          _Action(label: action, onTap: onTap),
        ],
      ),
    );
  }
}
