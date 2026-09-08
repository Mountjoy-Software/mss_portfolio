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
  'email': 'ross@example.com',
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

void main() {
  testWidgets('renders the profile on the home page', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(
            (ref) async => Profile.fromJson(_profileJson),
          ),
        ],
        child: const PortfolioApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ross Mountjoy'), findsOneWidget);
    expect(find.text('Builds web applications on AWS.'), findsOneWidget);
  });

  testWidgets('parses profile json into typed models', (tester) async {
    final profile = Profile.fromJson(_profileJson);

    expect(profile.experience.single.company, 'Acme');
    expect(profile.projects.single.slug, 'demo');
    expect(profile.skills['backend'], ['FastAPI']);
  });
}
