import 'dart:async';
import 'dart:convert';

import 'package:fetch_client/fetch_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

const _apiBaseOverride = String.fromEnvironment('API_BASE');

class ApiClient {
  http.Client? _cached;

  http.Client get _client => _cached ??= FetchClient(mode: RequestMode.cors);

  static String get baseUrl =>
      _apiBaseOverride.isNotEmpty ? _apiBaseOverride : Uri.base.origin;

  Uri _uri(String path) => Uri.parse('$baseUrl/api/v1$path');

  Future<Profile> fetchProfile() async {
    final response = await _client.get(_uri('/profile'));
    if (response.statusCode != 200) {
      throw ApiException('Could not load profile', response.statusCode);
    }
    return Profile.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<List<GraphNode>> graphSeed() => _nodes(_uri('/graph/seed'));

  Future<List<GraphNode>> expandNode(String id) =>
      _nodes(_uri('/graph/expand/$id'));

  Future<List<GraphNode>> _nodes(Uri uri) async {
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      var message = 'The graph is unavailable.';
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map && decoded['detail'] is String) {
          message = decoded['detail'] as String;
        }
      } catch (_) {}
      throw ApiException(message, response.statusCode);
    }
    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (decoded['nodes'] as List<dynamic>)
        .map((e) => GraphNode.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Stream<ChatEvent> streamChat(List<ChatTurn> history) async* {
    final request = http.Request('POST', _uri('/chat'))
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode({
        'messages': history.map((t) => t.toJson()).toList(),
      });

    final response = await _client.send(request);

    if (response.statusCode != 200) {
      yield ChatEvent(ChatEventKind.error, text: await _detail(response));
      return;
    }

    var buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      while (true) {
        final split = buffer.indexOf('\n\n');
        if (split == -1) break;
        final frame = buffer.substring(0, split);
        buffer = buffer.substring(split + 2);
        final payload = frame
            .split('\n')
            .where((line) => line.startsWith('data:'))
            .map((line) => line.substring(5).trim())
            .join();
        if (payload.isEmpty) continue;
        yield ChatEvent.fromJson(jsonDecode(payload) as Map<String, dynamic>);
      }
    }
  }
}

Future<String> _detail(http.StreamedResponse response) async {
  try {
    final body = await response.stream.bytesToString();
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['detail'] is String) {
      return decoded['detail'] as String;
    }
  } catch (_) {}
  return 'The assistant is unavailable right now (${response.statusCode}).';
}

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => '$message ($statusCode)';
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final profileProvider = FutureProvider<Profile>(
  (ref) => ref.watch(apiClientProvider).fetchProfile(),
);
