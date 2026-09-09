import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mss_portfolio/features/graph/graph_panel.dart';
import 'package:mss_portfolio/features/terminal/chat_controller.dart';
import 'package:mss_portfolio/features/terminal/terminal_page.dart';

void main() {
  testWidgets('a graph scrolls to its own top, not the transcript bottom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TerminalPage()),
      ),
    );
    await tester.pump();

    final chat = container.read(chatControllerProvider.notifier);
    // enough prior turns that the transcript is scrollable
    for (var i = 0; i < 6; i++) {
      chat.runCommand(
        '/help $i',
        'a reply that takes up a line or two\n\n' * 4,
      );
    }
    await tester.pumpAndSettle();

    chat.runGraph('/projects', 'projects');
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final panel = find.byType(GraphPanel);
    expect(panel, findsOneWidget);

    final list = find.byType(Scrollable).first;
    final viewportTop = tester.getTopLeft(list).dy;
    final panelTop = tester.getTopLeft(panel).dy;

    // the graph's own top should be at or just below the viewport top,
    // not pushed off the top by scrolling to the transcript's end
    expect(
      panelTop,
      greaterThanOrEqualTo(viewportTop - 2),
      reason: 'graph top is not scrolled off above the viewport',
    );
    expect(
      panelTop - viewportTop,
      lessThan(80),
      reason:
          'graph top is near the viewport top, got ${panelTop - viewportTop}',
    );
  });
}
