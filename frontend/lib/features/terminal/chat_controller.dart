import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';

class ChatState {
  const ChatState({
    this.turns = const [],
    this.streaming = false,
    this.toolActivity,
    this.usage,
  });

  final List<ChatTurn> turns;
  final bool streaming;
  final String? toolActivity;
  final Map<String, dynamic>? usage;

  ChatState copyWith({
    List<ChatTurn>? turns,
    bool? streaming,
    String? toolActivity,
    Map<String, dynamic>? usage,
    bool clearTool = false,
  }) {
    return ChatState(
      turns: turns ?? this.turns,
      streaming: streaming ?? this.streaming,
      toolActivity: clearTool ? null : (toolActivity ?? this.toolActivity),
      usage: usage ?? this.usage,
    );
  }
}

class ChatController extends Notifier<ChatState> {
  @override
  ChatState build() => const ChatState();

  Future<void> send(String message) async {
    if (state.streaming || message.trim().isEmpty) return;

    final pending = ChatTurn(role: 'assistant', content: '');
    final turns = [
      ...state.turns,
      ChatTurn(role: 'user', content: message.trim()),
    ];
    final history = [...turns];

    state = state.copyWith(
      turns: [...turns, pending],
      streaming: true,
      clearTool: true,
    );

    try {
      await for (final event in ref.read(apiClientProvider).streamChat(history)) {
        switch (event.kind) {
          case ChatEventKind.token:
            pending.content += event.text;
            state = state.copyWith(turns: [...state.turns], clearTool: true);
          case ChatEventKind.tool:
            state = state.copyWith(toolActivity: event.toolName);
          case ChatEventKind.done:
            state = state.copyWith(usage: event.usage, clearTool: true);
          case ChatEventKind.error:
            pending.content = event.text;
            state = state.copyWith(turns: [...state.turns], clearTool: true);
        }
      }
    } catch (_) {
      pending.content = 'Could not reach the assistant.';
      state = state.copyWith(turns: [...state.turns]);
    } finally {
      state = state.copyWith(streaming: false, clearTool: true);
    }
  }

  void reset() => state = const ChatState();
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);
