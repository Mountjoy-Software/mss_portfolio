import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mss_portfolio/core/api_client.dart';
import 'package:mss_portfolio/core/models.dart';
import 'package:mss_portfolio/main.dart';

const _profileJson = {
  'name': 'Ross Mountjoy',
  'business': 'Mountjoy Software Solutions',
  'tagline': 'Software development consulting',
  'summary': 'Builds web applications on AWS.',
  'email': 'ross.mountjoy.carr@pm.me',
  'location': 'Remote',
  'skills': {
    'backend': ['FastAPI'],
  },
  'experience': [
    {
      'company': 'Acme',
      'role': 'Engineer',
      'start': '2020-01',
      'end': 'present',
      'highlights': ['Shipped a thing'],
      'stack': ['Python'],
    },
  ],
  'projects': [
    {
      'slug': 'demo',
      'name': 'Demo',
      'blurb': 'A demo project',
      'details': '',
      'stack': ['Dart'],
    },
  ],
};

Widget _app() => ProviderScope(
  overrides: [
    profileProvider.overrideWith((ref) async => Profile.fromJson(_profileJson)),
  ],
  child: const PortfolioApp(),
);

void main() {
  testWidgets('renders the banner and the prompt', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Mountjoy Software Solutions'), findsOneWidget);
    expect(find.text('ross.mountjoy.carr@pm.me'), findsOneWidget);
    expect(find.text('mountjoy.io'), findsOneWidget);
    expect(find.text('Ask about my work'), findsOneWidget);
    expect(find.text('enter to send    shift+enter for newline'), findsOneWidget);
  });

  testWidgets('typing a suggestion moves it into the transcript', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('tell me about gem'), findsOneWidget);
    await tester.tap(find.text('tell me about gem'));
    await tester.pump();

    expect(find.text('>'), findsWidgets);
  });

  testWidgets('parses profile json into typed models', (tester) async {
    final profile = Profile.fromJson(_profileJson);

    expect(profile.experience.single.company, 'Acme');
    expect(profile.projects.single.slug, 'demo');
    expect(profile.skills['backend'], ['FastAPI']);
  });
}
