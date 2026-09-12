import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mss_portfolio/core/api_client.dart';
import 'package:mss_portfolio/core/models.dart';
import 'package:mss_portfolio/features/graph/graph_panel.dart';

GraphNode _node(String id, String kind, String title, {String? category}) =>
    GraphNode.fromJson({
      'id': id,
      'kind': kind,
      'title': title,
      'expands': 'its members',
      if (category != null) 'category': category,
    });

class _FakeApi extends ApiClient {
  int expands = 0;
  @override
  Future<List<GraphNode>> graphSeed() async => [
    _node('c1', 'category', 'projects', category: 'projects'),
  ];
  @override
  Future<List<GraphNode>> expandNode(String id) async {
    expands++;
    return [_node('p1', 'project', 'Gem'), _node('p2', 'project', 'Pip')];
  }
}

Future<void> _pumpFrames(WidgetTester t, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('expand opens a fullscreen view over the same graph', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final api = _FakeApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: GraphPanel(seed: 'projects')),
          ),
        ),
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('3 points on screen · 2 edges'), findsOneWidget);
    expect(api.expands, 1);
    expect(find.text('expand'), findsOneWidget);
    expect(find.text('close'), findsNothing);

    await tester.tap(find.text('expand'));
    await _pumpFrames(tester, 30);

    expect(find.text('close'), findsOneWidget, reason: 'fullscreen open');
    expect(
      find.text('open in the expanded view'),
      findsOneWidget,
      reason: 'inline canvas hands off',
    );
    expect(
      find.text('3 points on screen · 2 edges'),
      findsWidgets,
      reason: 'same graph, no re-fetch',
    );
    expect(api.expands, 1, reason: 'state carried over, seed not re-expanded');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _pumpFrames(tester, 30);
    expect(find.text('close'), findsNothing, reason: 'escape closes');
    expect(
      find.text('open in the expanded view'),
      findsNothing,
      reason: 'inline canvas live again',
    );
    expect(find.text('expand'), findsOneWidget);
  });
}
